import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart'; // Для debugPrint

// Определяем тип коллбэка для синхронизации
typedef NoteDeletedCallback =
    void Function(String noteId, List<String> themeIds);

class NotesProvider with ChangeNotifier {
  List<Note> _notes = [];
  bool _loadingError = false;
  String _errorMessage = '';

  // Кэширование частых запросов
  final Map<String, List<Note>> _filteredNotesCache = {};
  final Map<String, Note> _noteCache = {};

  // Добавляем список подписчиков на удаление заметок
  final List<NoteDeletedCallback> _onDeleteCallbacks = [];

  // Сервисы
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Геттеры для состояния
  List<Note> get notes => List.unmodifiable(_notes);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Набор для блокировки повторных операций
  final Set<String> _operationLock = {};

  // Метод для регистрации коллбэка удаления
  void registerDeleteCallback(NoteDeletedCallback callback) {
    if (!_onDeleteCallbacks.contains(callback)) {
      _onDeleteCallbacks.add(callback);
    }
  }

  // Метод для удаления коллбэка
  void unregisterDeleteCallback(NoteDeletedCallback callback) {
    _onDeleteCallbacks.remove(callback);
  }

  // Инвалидирует кэш фильтрованных заметок и очищает кэш отдельных заметок
  void _invalidateCache() {
    debugPrint('Инвалидация кэша заметок [${DateTime.now()}]');
    try {
      // Полностью очищаем кэш фильтрованных списков
      _filteredNotesCache.clear();

      // Для каждой заметки в локальном списке
      for (final note in _notes) {
        // Если заметка есть в _noteCache, проверяем, нужно ли её удалить
        if (_noteCache.containsKey(note.id)) {
          // Если хотим удалить заметку из кэша по какому-то условию
          // Например, если заметка старше 1 часа, можно удалить её из кэша
          final now = DateTime.now();
          if (note.updatedAt.isBefore(now.subtract(Duration(hours: 1)))) {
            _noteCache.remove(note.id);
            debugPrint('Удалена устаревшая заметка из кэша: ${note.id}');
          }
        }
      }

      // Проверяем, если в кэше есть заметки, которых нет в основном списке
      final allNoteIds = _notes.map((n) => n.id).toSet();
      final cacheIdsToRemove =
          _noteCache.keys.where((id) => !allNoteIds.contains(id)).toList();

      // Удаляем их из кэша
      for (final id in cacheIdsToRemove) {
        _noteCache.remove(id);
        debugPrint('Удалена из кэша несуществующая заметка: $id');
      }

      debugPrint(
        'Кэш очищен. Осталось ${_filteredNotesCache.length} кэшированных списков и ${_noteCache.length} заметок в кэше',
      );
    } catch (e) {
      debugPrint('Ошибка при инвалидации кэша: $e');
      debugPrint('Стек вызовов: ${StackTrace.current}');
    }
  }

  // Получение избранных заметок с кэшированием
  List<Note> getFavoriteNotes() {
    const String cacheKey = 'favorites';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final favorites = _notes.where((note) => note.isFavorite == true).toList();
    _filteredNotesCache[cacheKey] = favorites;
    return favorites;
  }

  // Добавление/удаление заметки из избранного
  Future<bool> toggleFavorite(String id) async {
    // Находим индекс заметки в кэше
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final note = _notes[index];
    final updatedNote = note.copyWith(
      isFavorite: !note.isFavorite,
      updatedAt: DateTime.now(),
    );

    try {
      // Обновляем в базе данных
      await _databaseService.updateNote(updatedNote);

      // При успешном обновлении в БД, обновляем локальное состояние
      _notes[index] = updatedNote;

      // Обновляем кэш для конкретной заметки
      _noteCache[id] = updatedNote;

      // Инвалидируем кэш для избранных заметок
      _filteredNotesCache.remove('favorites');

      // Уведомляем слушателей об изменении
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Не удалось обновить статус избранного: ${e.toString()}";
      _loadingError = true;
      notifyListeners();
      return false;
    }
  }

  // Получить все заметки с улучшенной обработкой ошибок
  Future<void> loadNotes({bool force = false}) async {
    // Если уже идёт загрузка и не требуется принудительное обновление, выходим
    if (_isLoading && !force) {
      debugPrint('Загрузка заметок уже выполняется, новый запрос пропущен');
      return;
    }

    debugPrint('Начинаем загрузку заметок (force: $force)');

    try {
      // Устанавливаем флаг загрузки и уведомляем об изменении состояния
      _isLoading = true;
      _loadingError = false;
      _errorMessage = '';
      notifyListeners();

      // Запрашиваем заметки из базы данных
      debugPrint('Запрос заметок из базы данных...');
      List<Note> loadedNotes = await _databaseService.getNotes();
      debugPrint('Получено ${loadedNotes.length} заметок из базы данных');

      // Сортируем заметки по дате создания (от новых к старым)
      loadedNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('Заметки отсортированы');

      // Обновляем список заметок - используем clear() и addAll() вместо прямого присваивания
      _notes.clear();
      _notes.addAll(loadedNotes);
      debugPrint('Локальный список заметок обновлен');

      // Сбрасываем флаг загрузки
      _isLoading = false;

      // Очищаем кэш
      _invalidateCache();
      debugPrint('Кэш очищен');

      // Уведомляем слушателей об изменениях
      notifyListeners();
      debugPrint('Загрузка заметок успешно завершена');
    } catch (e, stackTrace) {
      // В случае ошибки сбрасываем флаг загрузки
      _isLoading = false;

      // Логируем ошибку
      debugPrint('ОШИБКА при загрузке заметок: $e');
      debugPrint('Стек вызовов: $stackTrace');

      // Устанавливаем флаг ошибки и сообщение
      _loadingError = true;
      _errorMessage = "Ошибка при загрузке заметок: ${e.toString()}";

      // Уведомляем слушателей о завершении загрузки с ошибкой
      notifyListeners();

      // Пробрасываем ошибку дальше для обработки на уровне UI
      rethrow;
    }
  }

  // Принудительное обновление данных
  Future<void> forceRefresh() async {
    _invalidateCache();
    await loadNotes(force: true);
  }

  // Получить заметки с дедлайном с кэшированием
  List<Note> getDeadlineNotes() {
    const String cacheKey = 'deadlines';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final deadlineNotes = _notes.where((note) => note.hasDeadline).toList();
    _filteredNotesCache[cacheKey] = deadlineNotes;
    return deadlineNotes;
  }

  // Получить заметки, привязанные к дате с кэшированием
  List<Note> getDateLinkedNotes() {
    const String cacheKey = 'dateLinked';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final linkedNotes = _notes.where((note) => note.hasDateLink).toList();
    _filteredNotesCache[cacheKey] = linkedNotes;
    return linkedNotes;
  }

  // Получить быстрые заметки с кэшированием
  List<Note> getQuickNotes() {
    const String cacheKey = 'quick';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final quickNotes = _notes.where((note) => note.isQuickNote).toList();
    _filteredNotesCache[cacheKey] = quickNotes;
    return quickNotes;
  }

  // Создать новую заметку с улучшенной обработкой ошибок
  Future<Note?> createNote({
    required String content, // Теперь это будет Delta JSON
    List<String>? themeIds,
    bool hasDeadline = false,
    DateTime? deadlineDate,
    bool hasDateLink = false,
    DateTime? linkedDate,
    List<String>? mediaUrls,
    String? emoji,
    List<DateTime>? reminderDates,
    String? reminderSound,
    ReminderType reminderType = ReminderType.exactTime,
    RelativeReminder? relativeReminder,
    RecurringReminder? recurringReminder,
  }) async {
    debugPrint('=== НАЧАЛО СОЗДАНИЯ ЗАМЕТКИ ===');
    _isLoading = true;
    notifyListeners();

    try {
      // Генерируем ID для заметки
      final noteId = const Uuid().v4();
      debugPrint('Сгенерирован ID: $noteId');

      // Обработка списка тем с защитой от null
      final safeThemeIds = themeIds ?? [];
      debugPrint('Темы: ${safeThemeIds.join(', ')}');

      // Проверка дедлайна
      if (hasDeadline && deadlineDate == null) {
        debugPrint('ОШИБКА: hasDeadline=true, но deadlineDate=null');
        throw Exception('Дедлайн указан, но дата не задана');
      }

      // Проверка связанной даты
      if (hasDateLink && linkedDate == null) {
        debugPrint('ОШИБКА: hasDateLink=true, но linkedDate=null');
        throw Exception('Связь с датой указана, но дата не задана');
      }

      // Проверяем и валидируем контент как JSON Delta
      String validatedContent;
      try {
        // Проверяем, является ли контент уже JSON
        final contentJson = json.decode(content);

        // Проверяем структуру и преобразуем в правильный формат с 'ops'
        if (contentJson is Map<String, dynamic> &&
            contentJson.containsKey('ops')) {
          // Контент уже в правильном формате с ключом 'ops'
          debugPrint('Контент уже в формате Delta с ключом "ops"');
          validatedContent = content;
        } else if (contentJson is List) {
          // Только массив операций - оборачиваем в структуру с 'ops'
          debugPrint(
            'Контент содержит только массив операций, добавляем ключ "ops"',
          );
          validatedContent = json.encode({'ops': contentJson});
        } else {
          // Неизвестный формат - создаем базовую структуру
          debugPrint('Неизвестный формат JSON, создаем базовый Delta контент');
          validatedContent = json.encode({
            'ops': [
              {'insert': 'Новая заметка\n'},
            ],
          });
        }
      } catch (e) {
        // Контент не является JSON - пробуем создать Delta из текста
        debugPrint('Контент не является JSON: $e');

        if (content.isNotEmpty) {
          // Пробуем интерпретировать контент как простой текст
          debugPrint('Создаем Delta из текста длиной ${content.length}');
          validatedContent = json.encode({
            'ops': [
              {'insert': content},
            ],
          });
        } else {
          // Пустой контент - создаем пустую заметку
          debugPrint('Контент пуст, создаем пустую заметку');
          validatedContent = json.encode({
            'ops': [
              {'insert': '\n'},
            ],
          });
        }
      }

      // Дополнительная проверка после всех конвертаций
      try {
        final finalCheck = json.decode(validatedContent);
        if (finalCheck is Map && finalCheck.containsKey('ops')) {
          debugPrint(
            'Финальная проверка пройдена: корректная структура Delta с полем ops',
          );
        } else {
          debugPrint(
            'ПРЕДУПРЕЖДЕНИЕ: После всех преобразований Delta все еще имеет неверный формат',
          );
          validatedContent = '{"ops":[{"insert":"\\n"}]}';
        }
      } catch (e) {
        debugPrint('Ошибка при финальной проверке JSON: $e');
        validatedContent = '{"ops":[{"insert":"\\n"}]}';
      }

      // Создаем объект заметки с безопасными значениями
      final note = Note(
        id: noteId,
        content: validatedContent, // Используем проверенный Delta JSON
        themeIds: safeThemeIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hasDeadline: hasDeadline,
        deadlineDate: deadlineDate,
        hasDateLink: hasDateLink,
        linkedDate: linkedDate,
        isCompleted: false,
        isFavorite: false,
        mediaUrls: mediaUrls?.where((url) => url.isNotEmpty).toList() ?? [],
        emoji: emoji,
        reminderDates: reminderDates,
        reminderSound: reminderSound,
        reminderType: reminderType,
        relativeReminder: relativeReminder,
        voiceNotes: [], // Инициализируем пустым списком
      );

      debugPrint('Заметка создана в памяти: ${note.id}');
      debugPrint(
        'Контент для сохранения в БД: ${note.content.substring(0, min(100, note.content.length))}...',
      );

      // Получаем текстовое содержимое для проверки
      String plainText = "";
      try {
        final parsedContent = json.decode(validatedContent);
        if (parsedContent is Map && parsedContent.containsKey('ops')) {
          final opsList = parsedContent['ops'] as List;
          // Извлекаем текст из операций
          for (var op in opsList) {
            if (op is Map && op.containsKey('insert')) {
              plainText += op['insert'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Ошибка при извлечении текста из Delta: $e');
      }

      // Проверяем, не пустая ли заметка (если контент пустой и нет связанных тем/дат/медиа)
      final bool isEmptyNote =
          (plainText.trim().isEmpty || plainText.trim() == '\n') &&
          safeThemeIds.isEmpty &&
          !hasDeadline &&
          !hasDateLink &&
          (mediaUrls == null || mediaUrls.isEmpty);

      if (isEmptyNote) {
        _isLoading = false;
        debugPrint('Попытка создать пустую заметку без атрибутов - отклонено');
        throw Exception('Нельзя создать пустую заметку без атрибутов');
      }

      // Сначала добавляем в БД
      try {
        debugPrint('Вставляем заметку в БД...');
        final insertedId = await _databaseService.insertNote(note);
        debugPrint('Заметка добавлена в БД с ID: $insertedId');

        // Если ID не совпадают, это странно
        if (insertedId != noteId) {
          debugPrint(
            'ПРЕДУПРЕЖДЕНИЕ: Возвращенный ID отличается от созданного',
          );
        }
      } catch (dbError) {
        debugPrint('ОШИБКА ПРИ ВСТАВКЕ В БД: $dbError');
        debugPrint('Стек вызовов для ошибки БД: ${StackTrace.current}');
        throw Exception('Ошибка при сохранении в базу данных: $dbError');
      }

      // Затем добавляем в локальный список и кэш
      _notes.add(note);
      _noteCache[note.id] = note;
      _invalidateCache(); // Инвалидируем фильтрованные списки
      debugPrint('Локальное состояние и кэш обновлены');

      // Планируем напоминания, если они есть
      if (hasDeadline && deadlineDate != null && note.hasReminders) {
        try {
          await _notificationService.scheduleNotificationsForNote(note);
          debugPrint('Напоминания запланированы для заметки ${note.id}');
        } catch (notifError) {
          debugPrint('Ошибка при планировании напоминаний: $notifError');
          // Не прерываем создание заметки из-за ошибки с напоминаниями
        }
      }

      _isLoading = false;
      _loadingError = false;
      notifyListeners();
      debugPrint('=== СОЗДАНИЕ ЗАМЕТКИ ЗАВЕРШЕНО УСПЕШНО ===');
      return note;
    } catch (e) {
      debugPrint('!!! ОШИБКА СОЗДАНИЯ ЗАМЕТКИ: $e !!!');
      debugPrint('Стек вызовов: ${StackTrace.current}');
      _isLoading = false;
      _loadingError = true;
      _errorMessage = "Ошибка создания заметки: ${e.toString()}";
      notifyListeners();
      return null;
    }
  }

  // Обновить существующую заметку с улучшенной обработкой ошибок
  Future<bool> updateNote(Note note) async {
    try {
      // Записываем в лог для отладки
      debugPrint('=== ОБНОВЛЕНИЕ ЗАМЕТКИ ===');
      debugPrint(
        'updateNote вызван для заметки ID: ${note.id}, длина контента: ${note.content.length}',
      );

      // Проверяем, является ли контент валидным JSON для Quill Delta
      try {
        // Декодируем контент из JSON
        final contentJson = json.decode(note.content);

        // Проверяем структуру JSON и преобразуем в правильный формат
        String validatedContent;

        if (contentJson is Map<String, dynamic> &&
            contentJson.containsKey('ops')) {
          // Стандартный формат с 'ops' - оставляем как есть
          debugPrint(
            'Контент содержит правильную структуру Delta с ключом "ops"',
          );
          validatedContent = note.content;
        } else if (contentJson is List) {
          // Формат без 'ops' - оборачиваем в правильную структуру
          debugPrint(
            'Контент содержит только массив операций, оборачиваем в {"ops": [...]}',
          );
          validatedContent = json.encode({'ops': contentJson});
        } else {
          debugPrint('Неожиданный формат JSON, создаем базовый Delta контент');
          // Создаем простой документ из текста
          validatedContent = json.encode({
            'ops': [
              {
                'insert':
                    'Контент заметки не может быть корректно обработан.\n',
              },
            ],
          });
        }

        // Создаем копию заметки с проверенным контентом
        final updatedNote = note.copyWith(content: validatedContent);

        // Сохраняем в базу данных
        await _databaseService.updateNote(updatedNote);

        // Находим индекс заметки в списке
        int index = _notes.indexWhere((n) => n.id == note.id);

        // Обновляем в памяти
        if (index != -1) {
          _notes[index] = updatedNote;
          debugPrint('Обновлена заметка в локальном списке на позиции $index');

          // Обновляем кэш
          _noteCache[note.id] = updatedNote;
          debugPrint('Обновлен кэш для заметки с ID ${note.id}');

          // Принудительно инвалидируем фильтрованный кэш после обновления
          _filteredNotesCache.clear();
          debugPrint('Очищен кэш фильтрованных заметок');
        } else {
          // Если заметки нет в списке, добавляем её
          debugPrint('Заметка с ID ${note.id} не найдена в списке, добавляем');
          _notes.add(updatedNote);
          _noteCache[note.id] = updatedNote;
          _invalidateCache();
        }

        notifyListeners();
        debugPrint('=== ОБНОВЛЕНИЕ ЗАМЕТКИ ЗАВЕРШЕНО УСПЕШНО ===');
        return true;
      } catch (jsonError) {
        // Проблема с форматом JSON
        debugPrint('Ошибка при обработке JSON: $jsonError');

        // Пытаемся спасти ситуацию, создав минимально валидный контент
        final fallbackContent = json.encode({
          'ops': [
            {
              'insert':
                  note.content.length > 0 ? note.content : 'Пустая заметка\n',
            },
          ],
        });

        final fallbackNote = note.copyWith(content: fallbackContent);
        await _databaseService.updateNote(fallbackNote);

        // Обновляем в памяти
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = fallbackNote;
          _noteCache[note.id] = fallbackNote;
        } else {
          _notes.add(fallbackNote);
          _noteCache[note.id] = fallbackNote;
        }

        _invalidateCache();
        notifyListeners();

        debugPrint('Заметка восстановлена с резервным контентом');
        return true;
      }
    } catch (e) {
      debugPrint('!!! КРИТИЧЕСКАЯ ОШИБКА ОБНОВЛЕНИЯ ЗАМЕТКИ: $e !!!');
      debugPrint('Стек вызовов: ${StackTrace.current}');
      _loadingError = true;
      _errorMessage = "Ошибка обновления заметки: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Проверка, изменились ли напоминания
  bool _haveRemindersChanged(Note? oldNote, Note newNote) {
    if (oldNote == null) return true;

    // Проверяем изменение статуса дедлайна
    if (oldNote.hasDeadline != newNote.hasDeadline) return true;

    // Проверяем изменение даты дедлайна
    if (oldNote.deadlineDate != newNote.deadlineDate) return true;

    // Проверяем изменение типа напоминания
    if (oldNote.reminderType != newNote.reminderType) return true;

    // Проверяем относительные напоминания
    if (oldNote.reminderType == ReminderType.relativeTime ||
        newNote.reminderType == ReminderType.relativeTime) {
      // Если у одной заметки есть относительное напоминание, а у другой нет
      if ((oldNote.relativeReminder == null) !=
          (newNote.relativeReminder == null))
        return true;

      // Если у обеих есть относительные напоминания, сравниваем их минуты
      if (oldNote.relativeReminder != null &&
          newNote.relativeReminder != null) {
        if (oldNote.relativeReminder!.minutes !=
            newNote.relativeReminder!.minutes)
          return true;
      }
    }

    // Проверяем наличие/отсутствие дат напоминаний (для точных напоминаний)
    if (oldNote.reminderType == ReminderType.exactTime ||
        newNote.reminderType == ReminderType.exactTime) {
      if ((oldNote.reminderDates == null) != (newNote.reminderDates == null))
        return true;

      // Если у обоих нет дат напоминаний, то изменений нет
      if (oldNote.reminderDates == null && newNote.reminderDates == null)
        return false;

      // Если количество дат напоминаний изменилось
      if (oldNote.reminderDates != null && newNote.reminderDates != null) {
        if (oldNote.reminderDates!.length != newNote.reminderDates!.length)
          return true;

        // Сравниваем каждую дату
        for (int i = 0; i < oldNote.reminderDates!.length; i++) {
          if (oldNote.reminderDates![i] != newNote.reminderDates![i])
            return true;
        }
      }
    }

    // Проверяем изменение звука
    if (oldNote.reminderSound != newNote.reminderSound) return true;

    // Если все проверки прошли, то напоминания не изменились
    return false;
  }

  // Отметить заметку как выполненную
  Future<void> completeNote(String noteId) async {
    try {
      // Блокируем повторные операции для одного ID
      if (_operationLock.contains(noteId)) {
        return;
      }

      _operationLock.add(noteId);

      // Находим заметку по ID
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        _operationLock.remove(noteId);
        throw Exception('Заметка не найдена');
      }

      // Проверяем наличие дедлайна
      if (!_notes[noteIndex].hasDeadline) {
        _operationLock.remove(noteId);
        throw Exception(
          'Можно отметить как выполненную только задачу с дедлайном',
        );
      }

      // Если уже выполнена, ничего не делаем
      if (_notes[noteIndex].isCompleted) {
        _operationLock.remove(noteId);
        return;
      }

      // Создаем обновленную копию заметки
      final updatedNote = _notes[noteIndex].copyWith(
        isCompleted: true,
        updatedAt: DateTime.now(),
      );

      // Сохраняем в базу данных
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальный список
      _notes[noteIndex] = updatedNote;

      // Инвалидируем кэш
      _noteCache[noteId] = updatedNote;
      _invalidateCache();

      // Отменяем напоминания для выполненной задачи
      await _notificationService.cancelNotificationsForNote(noteId);

      // Уведомляем слушателей
      notifyListeners();

      // Снимаем блокировку
      _operationLock.remove(noteId);
    } catch (e) {
      _operationLock.remove(noteId);
      debugPrint('Ошибка при отметке задачи как выполненной: $e');
      rethrow;
    }
  }

  // Метод для отметки задачи как невыполненной
  Future<void> uncompleteNote(String noteId) async {
    try {
      // Блокируем повторные операции для одного ID
      if (_operationLock.contains(noteId)) {
        return;
      }

      _operationLock.add(noteId);

      // Находим заметку по ID
      final noteIndex = _notes.indexWhere((note) => note.id == noteId);
      if (noteIndex == -1) {
        _operationLock.remove(noteId);
        throw Exception('Заметка не найдена');
      }

      // Проверяем наличие дедлайна
      if (!_notes[noteIndex].hasDeadline) {
        _operationLock.remove(noteId);
        throw Exception('Можно изменить статус только у задачи с дедлайном');
      }

      // Если уже не выполнена, ничего не делаем
      if (!_notes[noteIndex].isCompleted) {
        _operationLock.remove(noteId);
        return;
      }

      // Создаем обновленную копию заметки
      final updatedNote = _notes[noteIndex].copyWith(
        isCompleted: false,
        updatedAt: DateTime.now(),
      );

      // Сохраняем в базу данных
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальный список
      _notes[noteIndex] = updatedNote;

      // Инвалидируем кэш
      _noteCache[noteId] = updatedNote;
      _invalidateCache();

      // Если есть напоминания, планируем их снова
      if (updatedNote.hasReminders) {
        await _notificationService.scheduleNotificationsForNote(updatedNote);
      }

      // Уведомляем слушателей
      notifyListeners();

      // Снимаем блокировку
      _operationLock.remove(noteId);
    } catch (e) {
      _operationLock.remove(noteId);
      debugPrint('Ошибка при отметке задачи как невыполненной: $e');
      rethrow;
    }
  }

  // Продлить дедлайн заметки
  Future<bool> extendDeadline(String id, DateTime newDeadline) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final note = _notes[index];
    if (!note.hasDeadline) return false;

    final originalDeadline = note.deadlineDate!;
    final extension = DeadlineExtension(
      originalDate: originalDeadline,
      newDate: newDeadline,
      extendedAt: DateTime.now(),
    );

    final extensions = note.deadlineExtensions ?? [];
    extensions.add(extension);

    final updatedNote = note.copyWith(
      deadlineDate: newDeadline,
      deadlineExtensions: extensions,
      updatedAt: DateTime.now(),
    );

    try {
      // Обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      _notes[index] = updatedNote;

      // Обновляем кэш
      _noteCache[id] = updatedNote;
      _invalidateCache(); // Инвалидируем фильтрованные списки

      // Обновляем напоминания в зависимости от типа
      Note noteWithUpdatedReminders;

      if (updatedNote.reminderType == ReminderType.exactTime &&
          updatedNote.reminderDates != null &&
          updatedNote.reminderDates!.isNotEmpty) {
        // Обновляем даты напоминаний относительно нового дедлайна
        final List<DateTime> newReminderDates =
            _updateExactReminderDatesForDeadline(
              updatedNote.reminderDates!,
              originalDeadline,
              newDeadline,
            );

        noteWithUpdatedReminders = updatedNote.copyWith(
          reminderDates: newReminderDates,
        );
      } else if (updatedNote.reminderType == ReminderType.relativeTime &&
          updatedNote.relativeReminder != null) {
        // Для относительных напоминаний обновлять не нужно,
        // так как они привязаны к дедлайну
        noteWithUpdatedReminders = updatedNote;
      } else {
        noteWithUpdatedReminders = updatedNote;
      }

      // Обновляем заметку с новыми датами напоминаний, если были изменения
      if (noteWithUpdatedReminders != updatedNote) {
        await _databaseService.updateNote(noteWithUpdatedReminders);

        // Обновляем локальное состояние и кэш
        _notes[index] = noteWithUpdatedReminders;
        _noteCache[id] = noteWithUpdatedReminders;
      }

      // Перепланируем напоминания
      if (noteWithUpdatedReminders.hasReminders) {
        await _notificationService.cancelNotificationsForNote(id);
        await _notificationService.scheduleNotificationsForNote(
          noteWithUpdatedReminders,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка продления дедлайна: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Обновление точных дат напоминаний при переносе дедлайна
  List<DateTime> _updateExactReminderDatesForDeadline(
    List<DateTime> oldReminders,
    DateTime oldDeadline,
    DateTime newDeadline,
  ) {
    // Находим разницу между старым и новым дедлайном
    final difference = newDeadline.difference(oldDeadline);

    // Создаем новый список напоминаний
    List<DateTime> newReminders = [];

    for (final oldReminderDate in oldReminders) {
      // Если старое напоминание еще не наступило, переносим его на то же смещение
      if (oldReminderDate.isAfter(DateTime.now())) {
        newReminders.add(oldReminderDate.add(difference));
      }
    }

    // Если все старые напоминания уже прошли, создаем новое напоминание за день до дедлайна
    if (newReminders.isEmpty) {
      newReminders.add(newDeadline.subtract(const Duration(days: 1)));
    }

    return newReminders;
  }

  // Улучшенный метод deleteNote с синхронизацией
  Future<bool> deleteNote(String id) async {
    try {
      // Находим заметку перед удалением, чтобы получить её темы
      Note? noteToDelete;
      List<String> themeIds = [];

      int index = _notes.indexWhere((note) => note.id == id);
      if (index != -1) {
        noteToDelete = _notes[index];
        themeIds = List.from(noteToDelete.themeIds);
      }

      // Отменяем напоминания для заметки
      await _notificationService.cancelNotificationsForNote(id);

      // Удаляем из БД
      await _databaseService.deleteNote(id);

      // Удаляем из локального состояния
      _notes.removeWhere((n) => n.id == id);

      // Удаляем из кэшей
      _noteCache.remove(id);
      _invalidateCache();

      // Уведомляем слушателей
      notifyListeners();

      // Вызываем коллбэки для синхронизации с другими провайдерами
      for (final callback in _onDeleteCallbacks) {
        callback(id, themeIds);
      }

      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка удаления заметки: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Пакетное обновление заметок
  Future<bool> batchUpdateNotes(List<Note> notesToUpdate) async {
    if (notesToUpdate.isEmpty) return true;

    _isLoading = true;
    notifyListeners();

    bool success = true;

    try {
      for (final note in notesToUpdate) {
        final updatedNote = note.copyWith(updatedAt: DateTime.now());
        await _databaseService.updateNote(updatedNote);

        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = updatedNote;
          _noteCache[note.id] = updatedNote;
        }
      }

      // Инвалидируем фильтрованные списки после всех обновлений
      _invalidateCache();

      // Уведомляем слушателей один раз после всех обновлений
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      success = false;
      _loadingError = true;
      _errorMessage = "Ошибка массового обновления заметок: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
    }

    return success;
  }

  // Получить заметки для указанного периода с кэшированием
  List<Note> getNotesForPeriod(DateTime start, DateTime end) {
    final String cacheKey =
        'period_${start.toIso8601String()}_${end.toIso8601String()}';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final periodNotes =
        _notes.where((note) {
          // Проверяем дату создания
          if (note.createdAt.isAfter(start) && note.createdAt.isBefore(end)) {
            return true;
          }

          // Проверяем дату дедлайна
          if (note.hasDeadline &&
              note.deadlineDate != null &&
              note.deadlineDate!.isAfter(start) &&
              note.deadlineDate!.isBefore(end)) {
            return true;
          }

          // Проверяем связанную дату
          if (note.hasDateLink &&
              note.linkedDate != null &&
              note.linkedDate!.isAfter(start) &&
              note.linkedDate!.isBefore(end)) {
            return true;
          }

          return false;
        }).toList();

    _filteredNotesCache[cacheKey] = periodNotes;
    return periodNotes;
  }

  // Поиск заметок по содержимому
  List<Note> searchNotes(String query) {
    if (query.trim().isEmpty) return [];

    final String cacheKey = 'search_${query.toLowerCase()}';

    if (_filteredNotesCache.containsKey(cacheKey)) {
      return _filteredNotesCache[cacheKey]!;
    }

    final lowercaseQuery = query.toLowerCase();
    final searchResults =
        _notes
            .where(
              (note) => note.content.toLowerCase().contains(lowercaseQuery),
            )
            .toList();

    // Кэшируем только если запрос не очень специфичный (чтобы не засорять кэш)
    if (query.length > 2) {
      _filteredNotesCache[cacheKey] = searchResults;
    }

    return searchResults;
  }

  // Получить одну заметку по ID с кэшированием
  Future<Note?> getNoteById(String id) async {
    // Проверяем кэш сначала
    if (_noteCache.containsKey(id)) {
      return _noteCache[id];
    }

    // Проверяем локальный список
    final noteIndex = _notes.indexWhere((note) => note.id == id);
    if (noteIndex != -1) {
      final localNote = _notes[noteIndex];
      _noteCache[id] = localNote;
      return localNote;
    }

    // Запрашиваем из БД
    try {
      final note = await _databaseService.getNoteById(id);
      if (note != null) {
        _noteCache[id] = note;
      }
      return note;
    } catch (e) {
      _errorMessage = "Ошибка получения заметки: ${e.toString()}";
      return null;
    }
  }

  // Создать новое напоминание с точным временем
  Future<bool> addExactTimeReminderToNote(
    String noteId,
    DateTime reminderDate, {
    String? sound,
  }) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return false;

    final note = _notes[index];

    // Если у заметки нет дедлайна, невозможно добавить напоминание
    if (!note.hasDeadline || note.deadlineDate == null) return false;

    // Если заметка уже выполнена, не добавляем напоминание
    if (note.isCompleted) return false;

    // Если дата напоминания уже прошла, не добавляем
    if (reminderDate.isBefore(DateTime.now())) return false;

    // Получаем текущий список напоминаний или создаем новый
    List<DateTime> reminderDates = List<DateTime>.from(
      note.reminderDates ?? [],
    );

    // Добавляем новую дату напоминания
    reminderDates.add(reminderDate);

    // Сортируем даты напоминаний по времени
    reminderDates.sort();

    // Создаем обновленную копию заметки с типом точного времени
    final updatedNote = note.copyWith(
      reminderDates: reminderDates,
      reminderSound: sound ?? note.reminderSound,
      reminderType: ReminderType.exactTime, // Устанавливаем тип напоминания
      relativeReminder: null, // Сбрасываем относительное напоминание
      updatedAt: DateTime.now(),
    );

    try {
      // Обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      _notes[index] = updatedNote;

      // Обновляем кэш
      _noteCache[noteId] = updatedNote;
      _invalidateCache();

      // Планируем напоминание
      await _notificationService.scheduleNotificationsForNote(updatedNote);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка добавления напоминания: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Создать новое относительное напоминание
  Future<bool> setRelativeReminderToNote(
    String noteId,
    int minutes,
    String description, {
    String? sound,
  }) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return false;

    final note = _notes[index];

    // Если у заметки нет дедлайна, невозможно добавить напоминание
    if (!note.hasDeadline || note.deadlineDate == null) return false;

    // Если заметка уже выполнена, не добавляем напоминание
    if (note.isCompleted) return false;

    // Создаем объект относительного напоминания
    final relativeReminder = RelativeReminder(
      minutes: minutes,
      description: description,
    );

    // Рассчитываем фактическую дату напоминания
    final DateTime reminderDate = note.deadlineDate!.subtract(
      Duration(minutes: minutes),
    );

    // Если дата напоминания уже прошла, не добавляем
    if (reminderDate.isBefore(DateTime.now())) return false;

    // Создаем обновленную копию заметки с типом относительного времени
    final updatedNote = note.copyWith(
      reminderDates: [
        reminderDate,
      ], // Сохраняем фактическую дату для обратной совместимости
      reminderSound: sound ?? note.reminderSound,
      reminderType: ReminderType.relativeTime, // Устанавливаем тип напоминания
      relativeReminder:
          relativeReminder, // Устанавливаем данные о относительном напоминании
      updatedAt: DateTime.now(),
    );

    try {
      // Обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      _notes[index] = updatedNote;

      // Обновляем кэш
      _noteCache[noteId] = updatedNote;
      _invalidateCache();

      // Планируем напоминание
      await _notificationService.scheduleNotificationsForNote(updatedNote);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage =
          "Ошибка добавления относительного напоминания: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Удалить напоминание из заметки
  Future<bool> removeReminderFromNote(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return false;

    final note = _notes[index];

    // Если у заметки нет напоминаний, выходим
    if (!note.hasReminders) return false;

    // Создаем обновленную копию заметки без напоминаний
    final updatedNote = note.copyWith(
      reminderDates: null,
      reminderType:
          ReminderType.exactTime, // Сбрасываем на значение по умолчанию
      relativeReminder: null,
      updatedAt: DateTime.now(),
    );

    try {
      // Обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      _notes[index] = updatedNote;

      // Обновляем кэш
      _noteCache[noteId] = updatedNote;
      _invalidateCache();

      // Отменяем напоминания
      await _notificationService.cancelNotificationsForNote(noteId);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка удаления напоминания: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Сброс ошибок
  void resetErrors() {
    _loadingError = false;
    _errorMessage = '';
    notifyListeners();
  }
}

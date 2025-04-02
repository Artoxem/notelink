import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart'; // Добавляем импорт

// Определяем тип коллбэка для синхронизации
typedef NoteDeletedCallback = void Function(
    String noteId, List<String> themeIds);

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

  // Очистка кэша при изменении данных
  void _invalidateCache() {
    _filteredNotesCache.clear();
    _noteCache.clear();
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

      // Инвалидируем кэши, затронутые этим изменением
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
    if (_isLoading && !force) return;

    try {
      // Устанавливаем флаг загрузки и уведомляем об изменении состояния
      _isLoading = true;
      notifyListeners();

      // Запрашиваем заметки из базы данных
      List<Note> loadedNotes = await _databaseService.getNotes();

      // Сортируем заметки по дате создания (от новых к старым)
      loadedNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Обновляем список заметок - используем clear() и addAll() вместо прямого присваивания
      _notes.clear();
      _notes.addAll(loadedNotes);

      // Сбрасываем флаг загрузки
      _isLoading = false;

      // Очищаем кэши
      _invalidateCache();

      // Уведомляем слушателей об изменениях
      notifyListeners();
    } catch (e) {
      // В случае ошибки сбрасываем флаг загрузки
      _isLoading = false;

      // Логируем ошибку
      print('Ошибка при загрузке заметок: $e');

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
    required String content,
    List<String>? themeIds,
    bool hasDeadline = false,
    DateTime? deadlineDate,
    bool hasDateLink = false,
    DateTime? linkedDate,
    List<String>? mediaUrls,
    String? emoji,
    List<DateTime>? reminderDates,
    String? reminderSound,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final note = Note(
        id: const Uuid().v4(),
        content: content,
        themeIds: themeIds ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hasDeadline: hasDeadline,
        deadlineDate: deadlineDate,
        hasDateLink: hasDateLink,
        linkedDate: linkedDate,
        isCompleted: false,
        isFavorite: false,
        mediaUrls: mediaUrls ?? [],
        emoji: emoji,
        reminderDates: reminderDates,
        reminderSound: reminderSound,
        voiceNotes: [], // Инициализируем пустым списком
      );

      // Сначала добавляем в БД
      await _databaseService.insertNote(note);

      // Затем добавляем в локальный список
      _notes.add(note);

      // Обновляем кэш
      _noteCache[note.id] = note;
      _invalidateCache(); // Инвалидируем фильтрованные списки

      // Планируем напоминания, если они есть
      if (hasDeadline &&
          deadlineDate != null &&
          reminderDates != null &&
          reminderDates.isNotEmpty) {
        await _notificationService.scheduleNotificationsForNote(note);
      }

      _isLoading = false;
      _loadingError = false;
      notifyListeners();
      return note;
    } catch (e) {
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
      // Получаем старую версию заметки для сравнения напоминаний
      Note? oldNote;
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        oldNote = _notes[index];
      }

      // Проверяем, изменились ли напоминания
      bool remindersChanged = _haveRemindersChanged(oldNote, note);

      // Обновляем в БД
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      if (index != -1) {
        _notes[index] = updatedNote;

        // Обновляем кэш
        _noteCache[note.id] = updatedNote;
        _invalidateCache(); // Инвалидируем фильтрованные списки

        // Обновляем напоминания, если они изменились
        if (remindersChanged) {
          if (updatedNote.hasDeadline &&
              updatedNote.deadlineDate != null &&
              updatedNote.reminderDates != null &&
              updatedNote.reminderDates!.isNotEmpty) {
            // Планируем новые напоминания
            await _notificationService
                .scheduleNotificationsForNote(updatedNote);
          } else {
            // Отменяем существующие напоминания
            await _notificationService
                .cancelNotificationsForNote(updatedNote.id);
          }
        }

        notifyListeners();
      }
      return true;
    } catch (e) {
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

    // Проверяем наличие/отсутствие дат напоминаний
    if ((oldNote.reminderDates == null) != (newNote.reminderDates == null))
      return true;

    // Если у обоих нет дат напоминаний, то изменений нет
    if (oldNote.reminderDates == null && newNote.reminderDates == null)
      return false;

    // Если количество дат напоминаний изменилось
    if (oldNote.reminderDates!.length != newNote.reminderDates!.length)
      return true;

    // Сравниваем каждую дату
    for (int i = 0; i < oldNote.reminderDates!.length; i++) {
      if (oldNote.reminderDates![i] != newNote.reminderDates![i]) return true;
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
            'Можно отметить как выполненную только задачу с дедлайном');
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
      print('Ошибка при отметке задачи как выполненной: $e');
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
      if (updatedNote.reminderDates != null &&
          updatedNote.reminderDates!.isNotEmpty) {
        await _notificationService.scheduleNotificationsForNote(updatedNote);
      }

      // Уведомляем слушателей
      notifyListeners();

      // Снимаем блокировку
      _operationLock.remove(noteId);
    } catch (e) {
      _operationLock.remove(noteId);
      print('Ошибка при отметке задачи как невыполненной: $e');
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

      // Если есть напоминания, обновляем их
      if (updatedNote.reminderDates != null &&
          updatedNote.reminderDates!.isNotEmpty) {
        // Обновляем даты напоминаний относительно нового дедлайна
        final List<DateTime> newReminderDates = _updateReminderDatesForDeadline(
          updatedNote.reminderDates!,
          originalDeadline,
          newDeadline,
        );

        final noteWithUpdatedReminders = updatedNote.copyWith(
          reminderDates: newReminderDates,
        );

        // Обновляем заметку с новыми датами напоминаний
        await _databaseService.updateNote(noteWithUpdatedReminders);

        // Обновляем локальное состояние и кэш
        _notes[index] = noteWithUpdatedReminders;
        _noteCache[id] = noteWithUpdatedReminders;

        // Перепланируем напоминания
        await _notificationService
            .scheduleNotificationsForNote(noteWithUpdatedReminders);
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

  // Обновление дат напоминаний при переносе дедлайна
  List<DateTime> _updateReminderDatesForDeadline(
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

    final periodNotes = _notes.where((note) {
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
    final searchResults = _notes
        .where((note) => note.content.toLowerCase().contains(lowercaseQuery))
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
      final note = await _databaseService.getNote(id);
      if (note != null) {
        _noteCache[id] = note;
      }
      return note;
    } catch (e) {
      _errorMessage = "Ошибка получения заметки: ${e.toString()}";
      return null;
    }
  }

  // Создать новое напоминание к заметке
  Future<bool> addReminderToNote(String noteId, DateTime reminderDate,
      {String? sound}) async {
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
    List<DateTime> reminderDates =
        List<DateTime>.from(note.reminderDates ?? []);

    // Добавляем новую дату напоминания
    reminderDates.add(reminderDate);

    // Сортируем даты напоминаний по времени
    reminderDates.sort();

    // Создаем обновленную копию заметки
    final updatedNote = note.copyWith(
      reminderDates: reminderDates,
      reminderSound: sound ?? note.reminderSound,
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

  // Удалить напоминание из заметки
  Future<bool> removeReminderFromNote(
      String noteId, DateTime reminderDate) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return false;

    final note = _notes[index];

    // Если у заметки нет напоминаний, выходим
    if (note.reminderDates == null || note.reminderDates!.isEmpty) return false;

    // Получаем текущий список напоминаний
    List<DateTime> reminderDates = List<DateTime>.from(note.reminderDates!);

    // Находим и удаляем точное соответствие дате
    int removeIndex = -1;
    for (int i = 0; i < reminderDates.length; i++) {
      // Сравниваем даты с точностью до минуты
      if (_isSameMinute(reminderDates[i], reminderDate)) {
        removeIndex = i;
        break;
      }
    }

    // Если дата не найдена, выходим
    if (removeIndex == -1) return false;

    // Удаляем дату из списка
    reminderDates.removeAt(removeIndex);

    // Создаем обновленную копию заметки
    final updatedNote = note.copyWith(
      reminderDates: reminderDates,
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

      // Перепланируем напоминания
      await _notificationService.cancelNotificationsForNote(noteId);
      if (reminderDates.isNotEmpty) {
        await _notificationService.scheduleNotificationsForNote(updatedNote);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка удаления напоминания: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Вспомогательный метод для сравнения дат с точностью до минуты
  bool _isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  // Обновить все напоминания заметки
  Future<bool> updateNoteReminders(String noteId, List<DateTime> reminderDates,
      {String? sound}) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return false;

    final note = _notes[index];

    // Если у заметки нет дедлайна, невозможно обновить напоминания
    if (!note.hasDeadline || note.deadlineDate == null) return false;

    // Создаем обновленную копию заметки
    final updatedNote = note.copyWith(
      reminderDates: reminderDates,
      reminderSound: sound ?? note.reminderSound,
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

      // Перепланируем напоминания
      await _notificationService.cancelNotificationsForNote(noteId);
      if (reminderDates.isNotEmpty && !note.isCompleted) {
        await _notificationService.scheduleNotificationsForNote(updatedNote);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка обновления напоминаний: ${e.toString()}";
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

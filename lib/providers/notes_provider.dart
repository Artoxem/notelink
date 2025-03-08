import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class NotesProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Note> _notes = [];
  bool _isLoading = false;
  bool _loadingError = false;
  String _errorMessage = '';

  // Кэширование частых запросов
  final Map<String, List<Note>> _filteredNotesCache = {};
  final Map<String, Note> _noteCache = {};

  // Геттеры для состояния
  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  bool get hasError => _loadingError;
  String get errorMessage => _errorMessage;

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
  Future<void> loadNotes() async {
    // Если загрузка уже идет, не начинаем новую
    if (_isLoading) return;

    _isLoading = true;
    _loadingError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      _notes = await _databaseService.getNotes();

      // Обновляем кэш заметок
      for (var note in _notes) {
        _noteCache[note.id] = note;
      }

      _loadingError = false;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка загрузки заметок: ${e.toString()}";
      // Если у нас есть кэшированные заметки, используем их
      if (_notes.isEmpty) {
        // При первой загрузке создаем пустой список вместо null
        _notes = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      );

      // Сначала добавляем в БД
      await _databaseService.insertNote(note);

      // Затем добавляем в локальный список
      _notes.add(note);

      // Обновляем кэш
      _noteCache[note.id] = note;
      _invalidateCache(); // Инвалидируем фильтрованные списки

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
      // Обновляем в БД
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;

        // Обновляем кэш
        _noteCache[note.id] = updatedNote;
        _invalidateCache(); // Инвалидируем фильтрованные списки

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

  // Отметить заметку как выполненную
  Future<bool> completeNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) return false;

    final note = _notes[index];
    final updatedNote = note.copyWith(
      isCompleted: true,
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

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка выполнения заметки: ${e.toString()}";
      notifyListeners();
      return false;
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

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка продления дедлайна: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Удалить заметку
  Future<bool> deleteNote(String id) async {
    try {
      // Удаляем из БД
      await _databaseService.deleteNote(id);

      // Удаляем из локального состояния
      _notes.removeWhere((n) => n.id == id);

      // Удаляем из кэша
      _noteCache.remove(id);
      _invalidateCache(); // Инвалидируем фильтрованные списки

      notifyListeners();
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

  // Сброс ошибок
  void resetErrors() {
    _loadingError = false;
    _errorMessage = '';
    notifyListeners();
  }
}

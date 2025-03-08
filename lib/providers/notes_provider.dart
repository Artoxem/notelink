import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class NotesProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;

  // Получение избранных заметок
  List<Note> getFavoriteNotes() {
    print('Запрос избранных заметок: всего заметок ${_notes.length}');
    final favorites = _notes.where((note) => note.isFavorite == true).toList();
    print('Найдено ${favorites.length} избранных заметок');
    return favorites;
  }

  // Добавление/удаление заметки из избранного
  Future<bool> toggleFavorite(String id) async {
    // Находим заметку по ID
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      print('Заметка не найдена: id=$id');
      return false;
    }

    final note = _notes[index];
    final currentIsFavorite = note.isFavorite;

    // Создаем копию заметки с противоположным значением isFavorite
    final updatedNote = note.copyWith(
      isFavorite: !currentIsFavorite,
      updatedAt: DateTime.now(),
    );

    try {
      // 1. Сначала обновляем в базе данных
      await _databaseService.updateNote(updatedNote);

      // 2. При успешном обновлении в БД, меняем локальное состояние
      _notes[index] = updatedNote;

      // 3. Уведомляем слушателей об изменении
      notifyListeners();

      print(
          'Заметка ${note.id} обновлена: избранное = ${updatedNote.isFavorite}');
      return true;
    } catch (e) {
      print('Ошибка при обновлении заметки: $e');
      print(StackTrace.current);
      return false;
    }
  }

  // Получить все заметки
  Future<void> loadNotes() async {
    // Если загрузка уже идет, не начинаем новую
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    print('Загрузка заметок...');
    try {
      _notes = await _databaseService.getNotes();
      print('Загружено ${_notes.length} заметок');
    } catch (e) {
      print('Ошибка при загрузке заметок: $e');
      print(StackTrace.current);

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

  // Получить заметки с дедлайном
  List<Note> getDeadlineNotes() {
    return _notes.where((note) => note.hasDeadline).toList();
  }

  // Получить заметки, привязанные к дате
  List<Note> getDateLinkedNotes() {
    return _notes.where((note) => note.hasDateLink).toList();
  }

  // Получить быстрые заметки
  List<Note> getQuickNotes() {
    return _notes.where((note) => note.isQuickNote).toList();
  }

  // Создать новую заметку
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
    print('Создание новой заметки...');
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

      // 1. Сначала добавляем в БД
      await _databaseService.insertNote(note);

      // 2. Затем добавляем в локальный список
      _notes.add(note);

      // 3. Уведомляем об изменениях
      notifyListeners();

      print('Заметка успешно создана: ${note.id}');
      return note;
    } catch (e) {
      print('Ошибка при создании заметки: $e');
      print(StackTrace.current);
      return null;
    }
  }

  // Обновить существующую заметку
  Future<bool> updateNote(Note note) async {
    try {
      // 1. Сначала обновляем в БД
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateNote(updatedNote);

      // 2. Затем обновляем локальное состояние
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
        notifyListeners();
      }

      print('Заметка успешно обновлена: ${note.id}');
      return true;
    } catch (e) {
      print('Ошибка при обновлении заметки: $e');
      print(StackTrace.current);
      return false;
    }
  }

  // Отметить заметку как выполненную
  Future<bool> completeNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      print('Заметка не найдена: id=$id');
      return false;
    }

    final note = _notes[index];
    final updatedNote = note.copyWith(
      isCompleted: true,
      updatedAt: DateTime.now(),
    );

    try {
      // 1. Сначала обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // 2. Затем обновляем локальное состояние
      _notes[index] = updatedNote;
      notifyListeners();

      print('Заметка отмечена как выполненная: ${note.id}');
      return true;
    } catch (e) {
      print('Ошибка при обновлении статуса заметки: $e');
      print(StackTrace.current);
      return false;
    }
  }

  // Продлить дедлайн заметки
  Future<bool> extendDeadline(String id, DateTime newDeadline) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      print('Заметка не найдена: id=$id');
      return false;
    }

    final note = _notes[index];
    if (!note.hasDeadline) {
      print('Заметка не имеет дедлайна: id=$id');
      return false;
    }

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
      // 1. Сначала обновляем в БД
      await _databaseService.updateNote(updatedNote);

      // 2. Затем обновляем локальное состояние
      _notes[index] = updatedNote;
      notifyListeners();

      print('Дедлайн заметки продлен: ${note.id}');
      return true;
    } catch (e) {
      print('Ошибка при продлении дедлайна: $e');
      print(StackTrace.current);
      return false;
    }
  }

  // Удалить заметку
  Future<bool> deleteNote(String id) async {
    try {
      // 1. Сначала удаляем из БД
      await _databaseService.deleteNote(id);

      // 2. Затем удаляем из локального состояния
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();

      print('Заметка успешно удалена: $id');
      return true;
    } catch (e) {
      print('Ошибка при удалении заметки: $e');
      print(StackTrace.current);
      return false;
    }
  }
}

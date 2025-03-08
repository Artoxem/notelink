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
    return _notes.where((note) => note.isFavorite == true).toList();
  }

  // Добавление/удаление заметки из избранного
  Future<bool> toggleFavorite(String id) async {
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

      // Уведомляем слушателей об изменении
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  // Получить все заметки
  Future<void> loadNotes() async {
    // Если загрузка уже идет, не начинаем новую
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _notes = await _databaseService.getNotes();
    } catch (e) {
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

      // Уведомляем об изменениях
      notifyListeners();

      return note;
    } catch (e) {
      return null;
    }
  }

  // Обновить существующую заметку
  Future<bool> updateNote(Note note) async {
    try {
      // Обновляем в БД
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateNote(updatedNote);

      // Обновляем локальное состояние
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
        notifyListeners();
      }

      return true;
    } catch (e) {
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
      notifyListeners();

      return true;
    } catch (e) {
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
      notifyListeners();

      return true;
    } catch (e) {
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
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  // Пакетное обновление заметок
  Future<bool> batchUpdateNotes(List<Note> notesToUpdate) async {
    if (notesToUpdate.isEmpty) return true;

    bool success = true;

    try {
      for (final note in notesToUpdate) {
        final updatedNote = note.copyWith(updatedAt: DateTime.now());
        await _databaseService.updateNote(updatedNote);

        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = updatedNote;
        }
      }

      // Уведомляем слушателей один раз после всех обновлений
      notifyListeners();
    } catch (e) {
      success = false;
    }

    return success;
  }
}

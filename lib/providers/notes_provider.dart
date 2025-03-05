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
    return _notes.where((note) => note.isFavorite).toList();
  }

  // Добавление/удаление заметки из избранного
  Future<void> toggleFavorite(String id) async {
    print('📌 toggleFavorite начало: id=$id');

    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      final currentIsFavorite = note.isFavorite;
      print('📌 Найдена заметка: ${note.id}, isFavorite=$currentIsFavorite');

      final updatedNote = note.copyWith(
        isFavorite: !currentIsFavorite,
        updatedAt: DateTime.now(),
      );

      print('📌 Обновленная заметка: isFavorite=${updatedNote.isFavorite}');

      try {
        await _databaseService.updateNote(updatedNote);
        print('📌 Заметка успешно обновлена в БД');

        // Обновляем локальный кэш
        _notes[index] = updatedNote;

        // Принудительно перезагружаем заметку, чтобы убедиться в корректности данных
        await loadNotes();

        // Снова проверяем состояние заметки
        final refreshedIndex = _notes.indexWhere((n) => n.id == id);
        if (refreshedIndex != -1) {
          print(
              '📌 Состояние заметки после перезагрузки: isFavorite=${_notes[refreshedIndex].isFavorite}');
        } else {
          print('📌 Заметка не найдена после перезагрузки');
        }

        notifyListeners();
      } catch (e) {
        print('📌 Ошибка при обновлении заметки: $e');
        print(StackTrace.current);
      }
    } else {
      print('📌 Заметка не найдена: id=$id');
    }
  }

  // Получить все заметки
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    print('Загрузка заметок...');
    try {
      _notes = await _databaseService.getNotes();
      print('Загружено ${_notes.length} заметок');
    } catch (e) {
      print('Ошибка при загрузке заметок: $e');
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
  Future<Note> createNote({
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
    print(
        '📝 Создание заметки: ${content.substring(0, content.length > 30 ? 30 : content.length)}...');
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

      print('📝 Вставка заметки в БД: ${note.id}');
      await _databaseService.insertNote(note);
      _notes.add(note);
      print('✅ Заметка успешно создана и добавлена в список: ${note.id}');
      notifyListeners();
      return note;
    } catch (e) {
      print('❌ Ошибка при создании заметки: $e');
      // Получим стек ошибки для лучшей отладки
      print(StackTrace.current);
      throw e;
    }
  }

  // Обновить существующую заметку
  Future<void> updateNote(Note note) async {
    try {
      await _databaseService
          .updateNote(note.copyWith(updatedAt: DateTime.now()));
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
    } catch (e) {
      print('Ошибка при обновлении заметки: $e');
    }
  }

  // Отметить заметку как выполненную
  Future<void> completeNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index].copyWith(
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await updateNote(note);
    }
  }

  // Продлить дедлайн заметки
  Future<void> extendDeadline(String id, DateTime newDeadline) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      if (!note.hasDeadline) return;

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

      await updateNote(updatedNote);
    }
  }

  // Удалить заметку
  Future<void> deleteNote(String id) async {
    try {
      await _databaseService.deleteNote(id);
      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      print('Ошибка при удалении заметки: $e');
    }
  }
}

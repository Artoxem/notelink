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
    print('📌 getFavoriteNotes: всего заметок ${_notes.length}');
    final favorites = _notes.where((note) => note.isFavorite == true).toList();
    print(
        '📌 getFavoriteNotes: найдено ${favorites.length} избранных заметок:');

    // Печатаем отладочную информацию по избранным заметкам
    for (var note in favorites) {
      print('📌 Избранная заметка: ${note.id}');
    }

    return favorites;
  }

  // Добавление/удаление заметки из избранного
  Future<void> toggleFavorite(String id) async {
    print('📌 toggleFavorite начало: id=$id');

    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      print('📌 Заметка не найдена: id=$id');
      return;
    }

    final note = _notes[index];
    final currentIsFavorite = note.isFavorite;
    print(
        '📌 Найдена заметка: ${note.id}, текущий isFavorite=$currentIsFavorite');

    // Создаем копию заметки с противоположным значением isFavorite
    final updatedNote = note.copyWith(
      isFavorite: !currentIsFavorite,
      updatedAt: DateTime.now(),
    );

    print('📌 Обновленная заметка: новый isFavorite=${updatedNote.isFavorite}');

    try {
      // 1. Сначала обновляем локальный кэш для немедленной обратной связи
      _notes[index] = updatedNote;

      // 2. Сразу уведомляем слушателей об изменениях
      notifyListeners();

      // 3. Затем сохраняем изменения в базу данных
      await _databaseService.updateNote(updatedNote);
      print('📌 Заметка успешно обновлена в БД');
    } catch (e) {
      // В случае ошибки восстанавливаем предыдущее состояние
      print('📌 Ошибка при обновлении заметки: $e');
      _notes[index] = note; // Восстановление исходного состояния
      notifyListeners(); // Уведомление слушателей о восстановлении
      print(StackTrace.current);
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
      // Добавляем стек-трейс для улучшения отладки
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

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../services/database_service.dart';
import 'notes_provider.dart';

class ThemesProvider with ChangeNotifier {
  List<NoteTheme> _themes = [];
  bool _isLoading = false;
  bool _loadingError = false;
  String _errorMessage = '';

  // Кэширование частых запросов
  final Map<String, List<NoteTheme>> _filteredThemesCache = {};
  final Map<String, NoteTheme> _themeCache = {};
  final Map<String, List<Note>> _themeNoteCache = {};

  // Сервис для работы с базой данных
  final DatabaseService _databaseService = DatabaseService();

  // Геттеры
  List<NoteTheme> get themes => List.unmodifiable(_themes);
  bool get isLoading => _isLoading;
  bool get hasError => _loadingError;
  String get errorMessage => _errorMessage;

  // Очистка кэша при изменении данных
  void _invalidateCache() {
    _filteredThemesCache.clear();
    _themeCache.clear();
    _themeNoteCache.clear();
  }

  Future<bool> unlinkNoteFromTheme(String themeId, String noteId) async {
    // Просто вызываем существующий метод removeNoteFromTheme
    return await removeNoteFromTheme(themeId, noteId);
  }

  // Загрузка тем
  Future<void> loadThemes({bool force = false}) async {
    if (_isLoading && !force) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<NoteTheme> loadedThemes = await _databaseService.getThemes();

      // Сортируем темы по имени
      loadedThemes.sort((a, b) => a.name.compareTo(b.name));

      _themes.clear();
      _themes.addAll(loadedThemes);

      _isLoading = false;
      _loadingError = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _loadingError = true;
      _errorMessage = "Ошибка при загрузке тем: ${e.toString()}";
      notifyListeners();
      print('Ошибка при загрузке тем: $e');
    }
  }

  // Создание новой темы
  Future<NoteTheme?> createTheme(
    String name,
    String? description,
    String color,
    List<String> noteIds,
    ThemeLogoType logoType,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final theme = NoteTheme(
        id: const Uuid().v4(),
        name: name,
        description: description,
        color: color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteIds: noteIds,
        logoType: logoType,
      );

      // Сохраняем в БД
      await _databaseService.insertTheme(theme);

      // Добавляем в локальный список
      _themes.add(theme);

      // Обновляем кэш
      _themeCache[theme.id] = theme;
      _invalidateCache();

      _isLoading = false;
      _loadingError = false;
      notifyListeners();
      return theme;
    } catch (e) {
      _isLoading = false;
      _loadingError = true;
      _errorMessage = "Ошибка создания темы: ${e.toString()}";
      notifyListeners();
      return null;
    }
  }

  // Обновление темы
  Future<bool> updateTheme(NoteTheme theme) async {
    try {
      // Обновляем в БД
      await _databaseService.updateTheme(theme);

      // Обновляем локальное состояние
      final index = _themes.indexWhere((t) => t.id == theme.id);
      if (index != -1) {
        _themes[index] = theme;

        // Обновляем кэш
        _themeCache[theme.id] = theme;
        _invalidateCache();

        notifyListeners();
      }
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка обновления темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Удаление темы
  Future<bool> deleteTheme(String id) async {
    try {
      // Удаляем из БД
      await _databaseService.deleteTheme(id);

      // Удаляем из локального состояния
      _themes.removeWhere((t) => t.id == id);

      // Удаляем из кэша
      _themeCache.remove(id);
      _invalidateCache();

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = "Ошибка удаления темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Получение темы по ID с кэшированием
  NoteTheme? getThemeById(String id) {
    // Проверяем кэш
    if (_themeCache.containsKey(id)) {
      return _themeCache[id];
    }

    // Ищем в локальном списке
    try {
      final theme = _themes.firstWhere((theme) => theme.id == id);
      _themeCache[id] = theme;
      return theme;
    } catch (e) {
      return null;
    }
  }

  // Получение заметок для темы с кэшированием
  Future<List<Note>> getNotesForTheme(String themeId) async {
    // Проверяем кэш
    if (_themeNoteCache.containsKey(themeId)) {
      return _themeNoteCache[themeId]!;
    }

    try {
      final notes = await _databaseService.getNotesForTheme(themeId);

      // Сохраняем в кэш
      _themeNoteCache[themeId] = notes;

      return notes;
    } catch (e) {
      print('Ошибка при получении заметок для темы: $e');
      return [];
    }
  }

  // Добавление заметки в тему
  Future<bool> addNoteToTheme(String themeId, String noteId) async {
    // Находим тему
    final themeIndex = _themes.indexWhere((t) => t.id == themeId);
    if (themeIndex == -1) return false;

    final theme = _themes[themeIndex];

    // Проверяем, не добавлена ли уже заметка
    if (theme.noteIds.contains(noteId)) return true;

    // Создаем новый список для связи заметок с темой
    final updatedNoteIds = [...theme.noteIds, noteId];

    // Обновляем тему
    final updatedTheme = theme.copyWith(
      noteIds: updatedNoteIds,
      updatedAt: DateTime.now(),
    );

    // Обновляем в БД
    final success = await updateTheme(updatedTheme);

    // Очищаем кэш для этой темы
    _themeNoteCache.remove(themeId);

    return success;
  }

  // Удаление заметки из темы
  Future<bool> removeNoteFromTheme(String themeId, String noteId) async {
    // Находим тему
    final themeIndex = _themes.indexWhere((t) => t.id == themeId);
    if (themeIndex == -1) return false;

    final theme = _themes[themeIndex];

    // Проверяем, есть ли заметка в теме
    if (!theme.noteIds.contains(noteId)) return true;

    // Создаем новый список без удаляемой заметки
    final updatedNoteIds = theme.noteIds.where((id) => id != noteId).toList();

    // Обновляем тему
    final updatedTheme = theme.copyWith(
      noteIds: updatedNoteIds,
      updatedAt: DateTime.now(),
    );

    // Обновляем в БД
    final success = await updateTheme(updatedTheme);

    // Очищаем кэш для этой темы
    _themeNoteCache.remove(themeId);

    return success;
  }

  // Принудительное обновление данных
  Future<void> forceRefresh() async {
    _invalidateCache();
    await loadThemes(force: true);
  }

  // Обработчик удаления заметок в ThemesProvider
  void handleNoteDeleted(String noteId, List<String> themeIds) async {
    bool needsUpdate = false;

    // Проходим по всем темам, связанным с удаленной заметкой
    for (int i = 0; i < _themes.length; i++) {
      final theme = _themes[i];

      // Проверяем, содержится ли ID заметки в этой теме
      if (theme.noteIds.contains(noteId)) {
        // Удаляем ID заметки из связей темы
        final updatedNoteIds =
            theme.noteIds.where((id) => id != noteId).toList();

        // Обновляем тему локально
        _themes[i] = theme.copyWith(
          noteIds: updatedNoteIds,
          updatedAt: DateTime.now(),
        );

        needsUpdate = true;

        // Обновляем в базе данных асинхронно
        _updateThemeNotesInDb(theme.id, updatedNoteIds);
      }
    }

    // Очищаем кэши для обеспечения актуальности данных
    if (needsUpdate) {
      _themeNoteCache.clear();
      _filteredThemesCache.clear();

      // Уведомляем слушателей об изменениях
      notifyListeners();
    }
  }

  // Вспомогательный метод для обновления связей в БД
  Future<void> _updateThemeNotesInDb(
      String themeId, List<String> noteIds) async {
    try {
      // Получаем текущую тему из БД
      final currentTheme = await _databaseService.getTheme(themeId);
      if (currentTheme == null) return;

      // Обновляем связи
      final updatedTheme =
          currentTheme.copyWith(noteIds: noteIds, updatedAt: DateTime.now());

      // Сохраняем в БД
      await _databaseService.updateTheme(updatedTheme);
    } catch (e) {
      print('Ошибка при обновлении связей темы в БД: $e');
    }
  }

  // Метод для инициализации синхронизации с NotesProvider
  void initSync(NotesProvider notesProvider) {
    // Регистрируем обработчик удаления заметок
    notesProvider.registerDeleteCallback(handleNoteDeleted);
  }

  // Обновление связей между заметками и темами
  Future<void> updateNoteThemeRelations(
      String noteId, List<String> newThemeIds) async {
    try {
      // Получаем текущие связи заметки с темами
      final currentThemeIds = await _databaseService.getThemeIdsForNote(noteId);

      // Определяем изменения
      final toAdd = Set<String>.from(newThemeIds)
          .difference(Set<String>.from(currentThemeIds));
      final toRemove = Set<String>.from(currentThemeIds)
          .difference(Set<String>.from(newThemeIds));

      // Применяем изменения в транзакции
      final db = await _databaseService.database;
      await db.transaction((txn) async {
        // Удаляем ненужные связи
        for (final themeId in toRemove) {
          await txn.delete(
            'note_theme',
            where: 'noteId = ? AND themeId = ?',
            whereArgs: [noteId, themeId],
          );
        }

        // Добавляем новые связи
        for (final themeId in toAdd) {
          await txn.insert(
            'note_theme',
            {'noteId': noteId, 'themeId': themeId},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      // Обновляем локальное состояние
      for (int i = 0; i < _themes.length; i++) {
        final theme = _themes[i];

        if (toRemove.contains(theme.id)) {
          // Удаляем ID заметки из связей темы
          _themes[i] = theme.copyWith(
            noteIds: theme.noteIds.where((id) => id != noteId).toList(),
          );
        } else if (toAdd.contains(theme.id)) {
          // Добавляем ID заметки к связям темы
          _themes[i] = theme.copyWith(
            noteIds: [...theme.noteIds, noteId],
          );
        }
      }

      // Очищаем кэши
      _themeNoteCache.clear();
      _filteredThemesCache.clear();

      // Уведомляем слушателей
      notifyListeners();
    } catch (e) {
      print('Ошибка при обновлении связей между заметкой и темами: $e');
      throw e;
    }
  }

  // Сброс ошибок
  void resetErrors() {
    _loadingError = false;
    _errorMessage = '';
    notifyListeners();
  }
}

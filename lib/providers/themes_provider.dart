import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Добавлен импорт для Color
import 'package:uuid/uuid.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class ThemesProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<NoteTheme> _themes = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Структурированное кэширование для оптимизации производительности
  final Map<String, List<Note>> _notesForThemeCache = {};
  final Map<String, NoteTheme> _themeCache = {};

  // Геттеры
  List<NoteTheme> get themes => _themes;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  // Загрузка тем с улучшенной обработкой ошибок
  Future<void> loadThemes() async {
    if (_isLoading) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      _themes = await _databaseService.getThemes();

      // Обновляем кэш тем
      for (var theme in _themes) {
        _themeCache[theme.id] = theme;
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка загрузки тем: ${e.toString()}";
      // В случае ошибки сохраняем текущее состояние
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Создание новой темы
  Future<NoteTheme?> createTheme(
      String name, String? description, String color, List<String> noteIds,
      [ThemeLogoType logoType = ThemeLogoType
          .book] // Добавлен опциональный параметр с дефолтным значением
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
        logoType: logoType, // Используем переданный тип логотипа
      );

      await _databaseService.insertTheme(theme);
      _themes.add(theme);

      // Обновляем кэш
      _themeCache[theme.id] = theme;
      _invalidateNotesCache(noteIds);

      _isLoading = false;
      notifyListeners();
      return theme;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка создания темы: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Обновление существующей темы
  Future<bool> updateTheme(NoteTheme theme) async {
    try {
      final updatedTheme = theme.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateTheme(updatedTheme);

      final index = _themes.indexWhere((t) => t.id == theme.id);
      if (index != -1) {
        // Сохраняем старые noteIds для инвалидации кэша
        final oldNoteIds = List<String>.from(_themes[index].noteIds);

        _themes[index] = updatedTheme;

        // Обновляем кэш
        _themeCache[theme.id] = updatedTheme;

        // Инвалидируем кэш для всех затронутых заметок (старых и новых)
        _invalidateNotesCache([...oldNoteIds, ...updatedTheme.noteIds]);

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка обновления темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Удаление темы
  Future<bool> deleteTheme(String id) async {
    try {
      final index = _themes.indexWhere((t) => t.id == id);
      if (index == -1) return false;

      // Запоминаем noteIds перед удалением для инвалидации кэша
      final themeNoteIds = List<String>.from(_themes[index].noteIds);

      await _databaseService.deleteTheme(id);
      _themes.removeAt(index);

      // Обновляем кэш
      _themeCache.remove(id);
      _invalidateNotesCache(themeNoteIds);

      notifyListeners();
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка удаления темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Привязка заметок к теме
  Future<bool> linkNotesToTheme(String themeId, List<String> noteIds) async {
    if (noteIds.isEmpty) return true;

    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index == -1) return false;

    try {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];

      // Добавляем только новые noteIds
      bool changed = false;
      for (final noteId in noteIds) {
        if (!updatedNoteIds.contains(noteId)) {
          updatedNoteIds.add(noteId);
          changed = true;
        }
      }

      // Если нет изменений, возвращаем успех
      if (!changed) return true;

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Обновляем кэш
      _themeCache[themeId] = updatedTheme;
      _invalidateNotesCache(noteIds);

      notifyListeners();
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка привязки заметок к теме: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Отвязка заметки от темы
  Future<bool> unlinkNoteFromTheme(String themeId, String noteId) async {
    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index == -1) return false;

    try {
      final theme = _themes[index];
      if (!theme.noteIds.contains(noteId)) return true; // Уже отвязана

      final updatedNoteIds = [...theme.noteIds];
      updatedNoteIds.remove(noteId);

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Обновляем кэш
      _themeCache[themeId] = updatedTheme;
      _invalidateNotesCache([noteId]);

      notifyListeners();
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка отвязки заметки от темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Получение заметок для темы с улучшенным кэшированием
  Future<List<Note>> getNotesForTheme(String themeId) async {
    // Всегда очищаем кэш для этой темы перед запросом новых данных
    _notesForThemeCache.remove(themeId);

    try {
      final notes = await _databaseService.getNotesForTheme(themeId);
      // Сохраняем результат в кэш
      _notesForThemeCache[themeId] = notes;
      return notes;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка получения заметок для темы: ${e.toString()}";
      notifyListeners();
      return [];
    }
  }

  // Инвалидация кэша только для затронутых заметок
  void _invalidateNotesCache(List<String> noteIds) {
    if (noteIds.isEmpty) return;

    // Полностью очищаем кэш заметок для обновления данных
    _notesForThemeCache.clear();
  }

  // Полная очистка кэша заметок
  void clearNotesCache() {
    _notesForThemeCache.clear();
    notifyListeners();
  }

  // Получение всех тем для заметки
  List<NoteTheme> getThemesForNote(String noteId) {
    return _themes.where((theme) => theme.noteIds.contains(noteId)).toList();
  }

  // Получение темы по ID с оптимизированным кэшированием
  NoteTheme? getThemeById(String id) {
    // Сначала проверяем кэш
    if (_themeCache.containsKey(id)) {
      return _themeCache[id];
    }

    // Затем проверяем локальный список
    try {
      final themeIndex = _themes.indexWhere((theme) => theme.id == id);
      if (themeIndex != -1) {
        final theme = _themes[themeIndex];
        _themeCache[id] = theme; // Сохраняем в кэш
        return theme;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Пакетное добавление/удаление заметок из темы с оптимизацией
  Future<bool> batchUpdateThemeNotes(String themeId,
      {List<String> addNoteIds = const [],
      List<String> removeNoteIds = const []}) async {
    if (addNoteIds.isEmpty && removeNoteIds.isEmpty) return true;

    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index == -1) return false;

    try {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];

      // Добавляем новые ID
      bool changed = false;
      for (final noteId in addNoteIds) {
        if (!updatedNoteIds.contains(noteId)) {
          updatedNoteIds.add(noteId);
          changed = true;
        }
      }

      // Удаляем указанные ID
      for (final noteId in removeNoteIds) {
        if (updatedNoteIds.contains(noteId)) {
          updatedNoteIds.remove(noteId);
          changed = true;
        }
      }

      // Если изменений нет, возвращаем true
      if (!changed) {
        return true;
      }

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Обновляем кэш
      _themeCache[themeId] = updatedTheme;

      // Инвалидируем кэш для всех затронутых заметок
      _invalidateNotesCache([...addNoteIds, ...removeNoteIds]);

      notifyListeners();
      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage =
          "Ошибка пакетного обновления заметок темы: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Сброс ошибок
  void resetError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }

  // Проверка, есть ли данная заметка в теме
  bool isNoteInTheme(String themeId, String noteId) {
    final theme = getThemeById(themeId);
    return theme != null && theme.noteIds.contains(noteId);
  }

  // Получение цвета темы по ID
  Color? getThemeColor(String themeId, {Color? defaultColor}) {
    final theme = getThemeById(themeId);
    if (theme == null) return defaultColor;

    try {
      return Color(int.parse(theme.color));
    } catch (e) {
      return defaultColor;
    }
  }
}

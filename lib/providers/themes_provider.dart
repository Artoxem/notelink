import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class ThemesProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<NoteTheme> _themes = [];
  bool _isLoading = false;

  // Кэширование для быстрого доступа
  final Map<String, List<Note>> _notesCache = {};

  List<NoteTheme> get themes => _themes;
  bool get isLoading => _isLoading;

  Future<void> loadThemes() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _themes = await _databaseService.getThemes();
      // Очищаем кэш при загрузке новых данных
      _notesCache.clear();
    } catch (e) {
      // Тихая обработка ошибок с сохранением текущего состояния
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<NoteTheme> createTheme(String name, String? description, String color,
      List<String> noteIds) async {
    try {
      final theme = NoteTheme(
        id: const Uuid().v4(),
        name: name,
        description: description,
        color: color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteIds: noteIds,
      );

      await _databaseService.insertTheme(theme);
      _themes.add(theme);

      // Очищаем кэш для затронутых заметок
      _clearCacheForNotes(noteIds);

      notifyListeners();
      return theme;
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateTheme(NoteTheme theme) async {
    try {
      final updatedTheme = theme.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateTheme(updatedTheme);

      final index = _themes.indexWhere((t) => t.id == theme.id);
      if (index != -1) {
        // Сохраняем старые noteIds для очистки кэша
        final oldNoteIds = List<String>.from(_themes[index].noteIds);

        _themes[index] = updatedTheme;

        // Очищаем кэш для всех затронутых заметок (старых и новых)
        _clearCacheForNotes([...oldNoteIds, ...updatedTheme.noteIds]);

        notifyListeners();
      }
    } catch (e) {
      // В случае ошибки просто логируем её, но не изменяем состояние
    }
  }

  Future<void> deleteTheme(String id) async {
    try {
      final index = _themes.indexWhere((t) => t.id == id);
      if (index == -1) return;

      // Запоминаем noteIds перед удалением
      final themeNoteIds = List<String>.from(_themes[index].noteIds);

      await _databaseService.deleteTheme(id);
      _themes.removeAt(index);

      // Очищаем кэш для затронутых заметок
      _clearCacheForNotes(themeNoteIds);

      notifyListeners();
    } catch (e) {
      // В случае ошибки просто логируем её, но не изменяем состояние
    }
  }

  Future<void> linkNotesToTheme(String themeId, List<String> noteIds) async {
    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index == -1) return;

    try {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];

      // Добавляем только новые noteIds
      for (final noteId in noteIds) {
        if (!updatedNoteIds.contains(noteId)) {
          updatedNoteIds.add(noteId);
        }
      }

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Очищаем кэш для затронутых заметок
      _clearCacheForNotes(noteIds);

      notifyListeners();
    } catch (e) {
      // В случае ошибки просто логируем её, но не изменяем состояние
    }
  }

  Future<void> unlinkNoteFromTheme(String themeId, String noteId) async {
    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index == -1) return;

    try {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];
      updatedNoteIds.remove(noteId);

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Очищаем кэш для отвязанной заметки
      _clearCacheForNotes([noteId]);

      notifyListeners();
    } catch (e) {
      // В случае ошибки просто логируем её, но не изменяем состояние
    }
  }

  Future<List<Note>> getNotesForTheme(String themeId) async {
    // Проверяем кэш первым делом
    if (_notesCache.containsKey(themeId)) {
      return _notesCache[themeId]!;
    }

    try {
      final notes = await _databaseService.getNotesForTheme(themeId);
      // Сохраняем результат в кэш
      _notesCache[themeId] = notes;
      return notes;
    } catch (e) {
      return [];
    }
  }

  // Очистка кэша для указанных заметок
  void _clearCacheForNotes(List<String> noteIds) {
    if (noteIds.isEmpty) return;

    // Удаляем кэшированные списки заметок для всех тем,
    // которые могли содержать какую-либо из указанных заметок
    _notesCache.clear();
  }

  // Получение всех примененных тем для заметки
  List<NoteTheme> getThemesForNote(String noteId) {
    return _themes.where((theme) => theme.noteIds.contains(noteId)).toList();
  }

  // Получение темы по её ID с оптимизированным поиском
  NoteTheme? getThemeById(String id) {
    try {
      return _themes.firstWhere((theme) => theme.id == id);
    } catch (e) {
      return null;
    }
  }

  // Пакетное добавление/удаление заметок из темы
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
      for (final noteId in addNoteIds) {
        if (!updatedNoteIds.contains(noteId)) {
          updatedNoteIds.add(noteId);
        }
      }

      // Удаляем указанные ID
      for (final noteId in removeNoteIds) {
        updatedNoteIds.remove(noteId);
      }

      // Если изменений нет, возвращаем true
      if (listEquals(updatedNoteIds, theme.noteIds)) {
        return true;
      }

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateTheme(updatedTheme);
      _themes[index] = updatedTheme;

      // Очищаем кэш для всех затронутых заметок
      _clearCacheForNotes([...addNoteIds, ...removeNoteIds]);

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}

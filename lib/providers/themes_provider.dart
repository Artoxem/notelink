import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class ThemesProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<NoteTheme> _themes = [];
  bool _isLoading = false;

  List<NoteTheme> get themes => _themes;
  bool get isLoading => _isLoading;

  Future<void> loadThemes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _themes = await _databaseService.getThemes();
    } catch (e) {
      print('Error loading themes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<NoteTheme> createTheme(String name, String? description, String color,
      List<String> noteIds) async {
    print('🏷️ Создание темы: $name, цвет: $color');
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

      print('🏷️ Вставка темы в БД: ${theme.id}');
      await _databaseService.insertTheme(theme);
      _themes.add(theme);
      print('✅ Тема успешно создана и добавлена в список: ${theme.id}');
      notifyListeners();
      return theme;
    } catch (e) {
      print('❌ Ошибка при создании темы: $e');
      // Получим стек ошибки для лучшей отладки
      print(StackTrace.current);
      throw e;
    }
  }

  Future<void> updateTheme(NoteTheme theme) async {
    try {
      await _databaseService
          .updateTheme(theme.copyWith(updatedAt: DateTime.now()));
      final index = _themes.indexWhere((t) => t.id == theme.id);
      if (index != -1) {
        _themes[index] = theme.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
    } catch (e) {
      print('Error updating theme: $e');
    }
  }

  Future<void> deleteTheme(String id) async {
    try {
      await _databaseService.deleteTheme(id);
      _themes.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting theme: $e');
    }
  }

  Future<void> linkNotesToTheme(String themeId, List<String> noteIds) async {
    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index != -1) {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];

      for (final noteId in noteIds) {
        if (!updatedNoteIds.contains(noteId)) {
          updatedNoteIds.add(noteId);
        }
      }

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await updateTheme(updatedTheme);
    }
  }

  Future<void> unlinkNoteFromTheme(String themeId, String noteId) async {
    final index = _themes.indexWhere((t) => t.id == themeId);
    if (index != -1) {
      final theme = _themes[index];
      final updatedNoteIds = [...theme.noteIds];
      updatedNoteIds.remove(noteId);

      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      await updateTheme(updatedTheme);
    }
  }

  Future<List<Note>> getNotesForTheme(String themeId) async {
    try {
      return await _databaseService.getNotesForTheme(themeId);
    } catch (e) {
      print('Error loading notes for theme: $e');
      return [];
    }
  }
}

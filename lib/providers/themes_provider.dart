import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../services/database_service.dart';
import 'notes_provider.dart';

class ThemesProvider with ChangeNotifier {
  List<NoteTheme> _themes = [];
  bool _isLoading = false;
  bool _loadingError = false;
  String _errorMessage = '';

  // Кэши для оптимизации доступа
  final Map<String, NoteTheme> _themesByIdCache = {};
  final Map<String, List<Note>> _notesByThemeCache = {};

  // Ссылка на провайдер заметок для синхронизации
  NotesProvider? _notesProvider;

  // Сервис базы данных
  final DatabaseService _databaseService = DatabaseService();

  // Геттеры для состояния
  List<NoteTheme> get themes => List.unmodifiable(_themes);
  bool get isLoading => _isLoading;
  bool get hasError => _loadingError;
  String get errorMessage => _errorMessage;

  // Инициализация синхронизации с NotesProvider
  void initSync(NotesProvider notesProvider) {
    _notesProvider = notesProvider;
    // Регистрируем колбэк для обработки удаления заметок
    notesProvider.registerDeleteCallback(_handleNoteDeleted);
  }

  // Обработчик события удаления заметки
  void _handleNoteDeleted(String noteId, List<String> themeIds) {
    // Если заметка не привязана к темам, ничего не делаем
    if (themeIds.isEmpty) return;

    // Для каждой темы, связанной с удаленной заметкой
    for (final themeId in themeIds) {
      // Находим тему в списке
      final themeIndex = _themes.indexWhere((theme) => theme.id == themeId);
      if (themeIndex != -1) {
        // Обновляем список идентификаторов заметок у темы
        final theme = _themes[themeIndex];
        final updatedNoteIds = List<String>.from(theme.noteIds);
        updatedNoteIds.remove(noteId);

        // Создаем обновленную тему
        final updatedTheme = theme.copyWith(
          noteIds: updatedNoteIds,
          updatedAt: DateTime.now(),
        );

        // Обновляем в локальном списке
        _themes[themeIndex] = updatedTheme;

        // Обновляем кэши
        _themesByIdCache[themeId] = updatedTheme;
        _notesByThemeCache.remove(themeId);

        // Сохраняем изменения в базе данных асинхронно
        _databaseService
            .updateTheme(updatedTheme)
            .then((_) {
              debugPrint(
                'Тема $themeId обновлена после удаления заметки $noteId',
              );
            })
            .catchError((error) {
              debugPrint('Ошибка при обновлении темы $themeId: $error');
            });
      }
    }

    // Уведомляем слушателей об изменениях
    notifyListeners();
  }

  // Загрузка тем из базы данных
  Future<void> loadThemes({bool force = false}) async {
    // Если уже идёт загрузка и не требуется принудительное обновление, выходим
    if (_isLoading && !force) return;

    _isLoading = true;
    _loadingError = false;
    notifyListeners();

    try {
      // Загружаем темы из базы данных
      final List<NoteTheme> loadedThemes = await _databaseService.getThemes();

      // Обновляем локальный список
      _themes = loadedThemes;

      // Очищаем кэши
      _themesByIdCache.clear();
      _notesByThemeCache.clear();

      // Заполняем кэш ID тем для быстрого доступа
      for (final theme in _themes) {
        _themesByIdCache[theme.id] = theme;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при загрузке тем: $e');
      _isLoading = false;
      _loadingError = true;
      _errorMessage = 'Не удалось загрузить темы: ${e.toString()}';
      notifyListeners();
    }
  }

  // Принудительное обновление данных
  Future<void> forceRefresh() async {
    // Сбрасываем кэши
    _themesByIdCache.clear();
    _notesByThemeCache.clear();

    // Загружаем темы заново
    await loadThemes(force: true);
  }

  // Получение темы по ID с использованием кэша
  NoteTheme? getThemeById(String id) {
    // Проверяем кэш
    if (_themesByIdCache.containsKey(id)) {
      return _themesByIdCache[id];
    }

    // Ищем в основном списке
    final theme = _themes.firstWhere(
      (theme) => theme.id == id,
      orElse:
          () => NoteTheme(
            id: '',
            name: 'Unknown',
            color: '0xFF000000',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            noteIds: [],
          ),
    );

    // Если нашли действительную тему, кэшируем её
    if (theme.id.isNotEmpty) {
      _themesByIdCache[id] = theme;
      return theme;
    }

    return null;
  }

  // Получение заметок для темы с возможностью принудительного обновления
  Future<List<Note>> getNotesForTheme(
    String themeId, {
    bool forceRefresh = false,
  }) async {
    // Если не требуется принудительное обновление и есть кэш, возвращаем его
    if (!forceRefresh && _notesByThemeCache.containsKey(themeId)) {
      return _notesByThemeCache[themeId]!;
    }

    try {
      // Получаем тему по ID
      final theme = getThemeById(themeId);
      if (theme == null || theme.id.isEmpty) {
        return [];
      }

      // Если нет NotesProvider, возвращаем пустой список
      if (_notesProvider == null) {
        return [];
      }

      // Получаем все заметки
      final allNotes = _notesProvider!.notes;

      // Фильтруем только те, которые связаны с темой
      final themeNotes =
          allNotes.where((note) => note.themeIds.contains(themeId)).toList();

      // Кэшируем результат
      _notesByThemeCache[themeId] = themeNotes;

      return themeNotes;
    } catch (e) {
      debugPrint('Ошибка при получении заметок для темы: $e');
      return [];
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
      final newTheme = NoteTheme(
        id: const Uuid().v4(),
        name: name,
        description: description,
        color: color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        noteIds: noteIds,
        logoType: logoType,
      );

      // Сохраняем в базе данных
      await _databaseService.insertTheme(newTheme);

      // Добавляем в локальный список
      _themes.add(newTheme);

      // Обновляем кэши
      _themesByIdCache[newTheme.id] = newTheme;

      // Если есть связанные заметки, инвалидируем кэш для новой темы
      if (noteIds.isNotEmpty) {
        _notesByThemeCache.remove(newTheme.id);
      }

      _isLoading = false;
      notifyListeners();
      return newTheme;
    } catch (e) {
      _isLoading = false;
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Обновление существующей темы
  Future<bool> updateTheme(NoteTheme theme) async {
    try {
      // Создаем копию с обновленной датой
      final updatedTheme = theme.copyWith(updatedAt: DateTime.now());

      // Сохраняем в базу данных
      await _databaseService.updateTheme(updatedTheme);

      // Обновляем локальный список
      final index = _themes.indexWhere((t) => t.id == theme.id);
      if (index != -1) {
        _themes[index] = updatedTheme;
      } else {
        _themes.add(updatedTheme);
      }

      // Обновляем кэши
      _themesByIdCache[updatedTheme.id] = updatedTheme;
      _notesByThemeCache.remove(updatedTheme.id);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Удаление темы
  Future<bool> deleteTheme(String id) async {
    try {
      // Находим тему перед удалением для кэширования
      final themeToDelete = getThemeById(id);

      if (themeToDelete != null) {
        // Удаляем из базы данных
        await _databaseService.deleteTheme(id);

        // Удаляем из локального списка
        _themes.removeWhere((theme) => theme.id == id);

        // Очищаем кэши
        _themesByIdCache.remove(id);
        _notesByThemeCache.remove(id);

        // Дополнительная логика по необходимости (например, обновление заметок)
        if (_notesProvider != null && themeToDelete.noteIds.isNotEmpty) {
          // Здесь можно реализовать обновление заметок, связанных с удаленной темой
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Добавление заметки к теме
  Future<bool> addNoteToTheme(String noteId, String themeId) async {
    try {
      // Получаем тему
      final theme = getThemeById(themeId);
      if (theme == null) return false;

      // Проверяем, содержит ли тема уже эту заметку
      if (theme.noteIds.contains(noteId)) return true;

      // Создаем обновленный список ID заметок
      final updatedNoteIds = List<String>.from(theme.noteIds)..add(noteId);

      // Создаем обновленную тему
      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      // Сохраняем в базу данных
      await _databaseService.updateTheme(updatedTheme);

      // Обновляем локальное состояние
      final index = _themes.indexWhere((t) => t.id == themeId);
      if (index != -1) {
        _themes[index] = updatedTheme;
      }

      // Обновляем кэши
      _themesByIdCache[themeId] = updatedTheme;
      _notesByThemeCache.remove(themeId);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Удаление заметки из темы
  Future<bool> removeNoteFromTheme(String noteId, String themeId) async {
    try {
      // Получаем тему
      final theme = getThemeById(themeId);
      if (theme == null) return false;

      // Проверяем, содержит ли тема эту заметку
      if (!theme.noteIds.contains(noteId)) return true;

      // Создаем обновленный список ID заметок
      final updatedNoteIds = List<String>.from(theme.noteIds)..remove(noteId);

      // Создаем обновленную тему
      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      // Сохраняем в базу данных
      await _databaseService.updateTheme(updatedTheme);

      // Обновляем локальное состояние
      final index = _themes.indexWhere((t) => t.id == themeId);
      if (index != -1) {
        _themes[index] = updatedTheme;
      }

      // Обновляем кэши
      _themesByIdCache[themeId] = updatedTheme;
      _notesByThemeCache.remove(themeId);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

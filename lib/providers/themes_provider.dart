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

  // Геттеры для состояния
  List<NoteTheme> get themes => List.unmodifiable(_themes);
  bool get isLoading => _isLoading;
  bool get hasError => _loadingError;
  String get errorMessage => _errorMessage;

  // Сервис для работы с базой данных
  final DatabaseService _databaseService = DatabaseService();

  // Инициализация синхронизации с NotesProvider
  void initSync(NotesProvider notesProvider) {
    _notesProvider = notesProvider;
    // Регистрируем колбэк для обработки удаления заметок
    notesProvider.registerDeleteCallback(_handleNoteDeleted);
  }

  // Обработка события удаления заметки
  void _handleNoteDeleted(String noteId, List<String> themeIds) {
    // Обрабатываем удаление заметки из всех связанных тем
    for (final themeId in themeIds) {
      _unlinkNoteFromThemeInternal(themeId, noteId);
    }
  }

  // Загрузка тем из базы данных
  Future<void> loadThemes({bool force = false}) async {
    // Если уже идёт загрузка и не требуется принудительное обновление, выходим
    if (_isLoading && !force) return;

    _isLoading = true;
    _loadingError = false;
    notifyListeners();

    try {
      final loadedThemes = await _databaseService.getThemes();

      // Очищаем текущий список и добавляем загруженные темы
      _themes.clear();
      _themes.addAll(loadedThemes);

      // Обновляем кэш по ID
      _themesByIdCache.clear();
      for (final theme in _themes) {
        _themesByIdCache[theme.id] = theme;
      }

      // Очищаем кэш заметок по темам, так как данные могли измениться
      _notesByThemeCache.clear();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _loadingError = true;
      _errorMessage = e.toString();
      print('Ошибка при загрузке тем: $e');
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
      orElse: () => NoteTheme(
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
  Future<List<Note>> getNotesForTheme(String themeId,
      {bool forceRefresh = false}) async {
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
      print('Ошибка при получении заметок для темы: $e');
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

      // Сохраняем в БД
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

      // Обновляем в БД
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

      // Удаляем из БД
      await _databaseService.deleteTheme(id);

      // Удаляем из локального списка
      _themes.removeWhere((t) => t.id == id);

      // Очищаем кэши
      _themesByIdCache.remove(id);
      _notesByThemeCache.remove(id);

      notifyListeners();
      return true;
    } catch (e) {
      _loadingError = true;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Привязка заметки к теме
  Future<bool> linkNoteToTheme(String themeId, String noteId) async {
    try {
      // Получаем тему по ID
      final theme = getThemeById(themeId);
      if (theme == null || theme.id.isEmpty) {
        return false;
      }

      // Проверяем, не привязана ли уже заметка
      if (theme.noteIds.contains(noteId)) {
        return true; // Заметка уже привязана, считаем успехом
      }

      // Создаем копию списка с добавленной заметкой
      final updatedNoteIds = List<String>.from(theme.noteIds)..add(noteId);

      // Создаем обновленную тему
      final updatedTheme = theme.copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      // Обновляем в БД
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
      print('Ошибка при привязке заметки к теме: $e');
      return false;
    }
  }

  // Публичный метод отвязки заметки от темы
  Future<bool> unlinkNoteFromTheme(String themeId, String noteId) async {
    try {
      await _unlinkNoteFromThemeInternal(themeId, noteId);
      return true;
    } catch (e) {
      print('Ошибка при отвязке заметки от темы: $e');
      return false;
    }
  }

  // Внутренний метод отвязки заметки от темы
  Future<void> _unlinkNoteFromThemeInternal(
      String themeId, String noteId) async {
    try {
      // Находим тему по ID
      final themeIndex = _themes.indexWhere((t) => t.id == themeId);
      if (themeIndex == -1) return;

      // Создаем копию списка noteIds без удаляемой заметки
      final updatedNoteIds = List<String>.from(_themes[themeIndex].noteIds)
        ..remove(noteId);

      // Создаем обновленную тему
      final updatedTheme = _themes[themeIndex].copyWith(
        noteIds: updatedNoteIds,
        updatedAt: DateTime.now(),
      );

      // Обновляем в БД
      await _databaseService.updateTheme(updatedTheme);

      // Обновляем локальный список
      _themes[themeIndex] = updatedTheme;

      // Инвалидируем кэши
      _themesByIdCache[themeId] = updatedTheme;
      _notesByThemeCache.remove(themeId);

      // Уведомляем слушателей
      notifyListeners();
    } catch (e) {
      print('Ошибка при отвязке заметки от темы: $e');
    }
  }

  // Сброс флагов ошибок
  void resetErrors() {
    _loadingError = false;
    _errorMessage = '';
    notifyListeners();
  }
}

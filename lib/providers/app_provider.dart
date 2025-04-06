import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AppProvider with ChangeNotifier {
  // Настройки темы
  AppThemeMode _themeMode = AppThemeMode.dark;

  // Настройки уведомлений
  bool _notificationsEnabled = true;
  String _notificationSound = 'default';
  bool _showOnLockScreen = true;
  String _activeNotificationSound = 'default';
  String _deadlineNotificationSound = 'urgent';
  int _deadlineWarningDays = 3;

  // Настройки внешнего вида
  double _lineThickness = 2.0;
  bool _showThemeLines = true;
  NoteViewMode _noteViewMode = NoteViewMode.card;
  NoteSortMode _noteSortMode = NoteSortMode.dateDesc;
  bool _showCalendarHeatmap = true;
  bool _showNoteLinkPreviews = true;

  // Настройки поиска
  bool _showSearchHistory = true;
  List<String> _searchHistory = [];
  int _maxSearchHistoryItems = 10;

  // Режим фокусировки
  bool _enableFocusMode = false;

  // Состояние загрузки
  bool _isLoading = false;
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Геттеры для настроек
  AppThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  String get notificationSound => _notificationSound;
  bool get showOnLockScreen => _showOnLockScreen;
  double get lineThickness => _lineThickness;
  bool get showThemeLines => _showThemeLines;
  NoteViewMode get noteViewMode => _noteViewMode;
  NoteSortMode get noteSortMode => _noteSortMode;
  bool get showSearchHistory => _showSearchHistory;
  List<String> get searchHistory => _searchHistory;
  int get maxSearchHistoryItems => _maxSearchHistoryItems;
  bool get enableFocusMode => _enableFocusMode;
  bool get showNoteLinkPreviews => _showNoteLinkPreviews;
  bool get showCalendarHeatmap => _showCalendarHeatmap;
  String get activeNotificationSound => _activeNotificationSound;
  String get deadlineNotificationSound => _deadlineNotificationSound;
  int get deadlineWarningDays => _deadlineWarningDays;

  // Геттеры для состояния
  bool get initialized => _initialized;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  // Инициализация настроек из SharedPreferences
  Future<void> initSettings() async {
    if (_initialized || _isLoading) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Загрузка темы
      final themeModeStr = prefs.getString('themeMode') ?? 'dark';
      _themeMode = _getThemeModeFromString(themeModeStr);

      // Загрузка настроек уведомлений
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _notificationSound = prefs.getString('notificationSound') ?? 'default';
      _showOnLockScreen = prefs.getBool('showOnLockScreen') ?? true;
      _activeNotificationSound =
          prefs.getString('activeNotificationSound') ?? 'default';
      _deadlineNotificationSound =
          prefs.getString('deadlineNotificationSound') ?? 'urgent';
      _deadlineWarningDays = prefs.getInt('deadlineWarningDays') ?? 3;

      // Загрузка настроек внешнего вида
      _lineThickness = prefs.getDouble('lineThickness') ?? 2.0;
      _showThemeLines = prefs.getBool('showThemeLines') ?? true;
      final noteViewModeStr = prefs.getString('noteViewMode') ?? 'card';
      _noteViewMode =
          noteViewModeStr == 'card' ? NoteViewMode.card : NoteViewMode.list;
      final noteSortModeStr = prefs.getString('noteSortMode') ?? 'dateDesc';
      _noteSortMode = _getNoteSortModeFromString(noteSortModeStr);
      _showCalendarHeatmap = prefs.getBool('showCalendarHeatmap') ?? true;
      _showNoteLinkPreviews = prefs.getBool('showNoteLinkPreviews') ?? true;

      // Загрузка настроек поиска
      _showSearchHistory = prefs.getBool('showSearchHistory') ?? true;
      final searchHistoryJson = prefs.getStringList('searchHistory') ?? [];
      _searchHistory = searchHistoryJson;
      _maxSearchHistoryItems = prefs.getInt('maxSearchHistoryItems') ?? 10;

      // Загрузка режима фокусировки
      _enableFocusMode = prefs.getBool('enableFocusMode') ?? false;

      _initialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Если произошла ошибка при загрузке настроек, используем значения по умолчанию
      _hasError = true;
      _errorMessage = "Ошибка загрузки настроек: ${e.toString()}";
      _initialized = true; // Все равно считаем инициализированным, но с ошибкой
      _isLoading = false;
      notifyListeners();
    }
  }

  // Сохранение конкретной настройки
  Future<bool> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List<String>) {
        await prefs.setStringList(key, value);
      } else {
        return false; // Неподдерживаемый тип
      }

      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка сохранения настройки $key: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Проверка темной темы
  bool isDarkMode(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  // Методы для изменения настроек с оптимизацией сохранения
  Future<bool> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return true;

    _themeMode = mode;
    bool success = await _saveSetting('themeMode', _getThemeModeString(mode));
    notifyListeners();
    return success;
  }

  Future<bool> toggleNotifications(bool enabled) async {
    if (_notificationsEnabled == enabled) return true;

    _notificationsEnabled = enabled;
    bool success = await _saveSetting('notificationsEnabled', enabled);
    notifyListeners();
    return success;
  }

  Future<bool> setNotificationSound(String sound) async {
    if (_notificationSound == sound) return true;

    _notificationSound = sound;
    bool success = await _saveSetting('notificationSound', sound);
    notifyListeners();
    return success;
  }

  Future<bool> toggleLockScreenNotifications(bool show) async {
    if (_showOnLockScreen == show) return true;

    _showOnLockScreen = show;
    bool success = await _saveSetting('showOnLockScreen', show);
    notifyListeners();
    return success;
  }

  Future<bool> setLineThickness(double thickness) async {
    if (_lineThickness == thickness) return true;

    _lineThickness = thickness;
    bool success = await _saveSetting('lineThickness', thickness);
    notifyListeners();
    return success;
  }

  Future<bool> toggleThemeLines(bool show) async {
    if (_showThemeLines == show) return true;

    _showThemeLines = show;
    bool success = await _saveSetting('showThemeLines', show);
    notifyListeners();
    return success;
  }

  // Методы для новых настроек
  Future<bool> setNoteViewMode(NoteViewMode mode) async {
    if (_noteViewMode == mode) return true;

    _noteViewMode = mode;
    bool success = await _saveSetting(
      'noteViewMode',
      mode == NoteViewMode.card ? 'card' : 'list',
    );
    notifyListeners();
    return success;
  }

  Future<bool> toggleNoteViewMode() async {
    _noteViewMode =
        _noteViewMode == NoteViewMode.card
            ? NoteViewMode.list
            : NoteViewMode.card;
    bool success = await _saveSetting(
      'noteViewMode',
      _noteViewMode == NoteViewMode.card ? 'card' : 'list',
    );
    notifyListeners();
    return success;
  }

  Future<bool> setNoteSortMode(NoteSortMode mode) async {
    if (_noteSortMode == mode) return true;

    _noteSortMode = mode;
    bool success = await _saveSetting(
      'noteSortMode',
      _getNoteSortModeString(mode),
    );
    notifyListeners();
    return success;
  }

  Future<bool> toggleSearchHistory(bool show) async {
    if (_showSearchHistory == show) return true;

    _showSearchHistory = show;
    bool success = await _saveSetting('showSearchHistory', show);
    notifyListeners();
    return success;
  }

  // Добавление поискового запроса в историю
  Future<bool> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return true;

    // Избегаем дублирования: удаляем существующий запрос
    _searchHistory.remove(query);

    // Добавляем запрос в начало списка
    _searchHistory.insert(0, query);

    // Обрезаем список до заданного максимума
    if (_searchHistory.length > _maxSearchHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxSearchHistoryItems);
    }

    bool success = await _saveSetting('searchHistory', _searchHistory);
    notifyListeners();
    return success;
  }

  // Очистка истории поиска
  Future<bool> clearSearchHistory() async {
    if (_searchHistory.isEmpty) return true;

    _searchHistory.clear();
    bool success = await _saveSetting('searchHistory', _searchHistory);
    notifyListeners();
    return success;
  }

  // Удаление конкретного запроса из истории
  Future<bool> removeFromSearchHistory(String query) async {
    final bool removed = _searchHistory.remove(query);
    if (!removed) return true; // Уже удалено, считаем успехом

    bool success = await _saveSetting('searchHistory', _searchHistory);
    notifyListeners();
    return success;
  }

  Future<bool> setMaxSearchHistoryItems(int max) async {
    if (_maxSearchHistoryItems == max) return true;

    _maxSearchHistoryItems = max;

    // Обрезаем существующую историю, если она превышает новый лимит
    if (_searchHistory.length > max) {
      _searchHistory = _searchHistory.sublist(0, max);
      await _saveSetting('searchHistory', _searchHistory);
    }

    bool success = await _saveSetting('maxSearchHistoryItems', max);
    notifyListeners();
    return success;
  }

  Future<bool> toggleFocusMode(bool enable) async {
    if (_enableFocusMode == enable) return true;

    _enableFocusMode = enable;
    bool success = await _saveSetting('enableFocusMode', enable);
    notifyListeners();
    return success;
  }

  Future<bool> toggleNoteLinkPreviews(bool show) async {
    if (_showNoteLinkPreviews == show) return true;

    _showNoteLinkPreviews = show;
    bool success = await _saveSetting('showNoteLinkPreviews', show);
    notifyListeners();
    return success;
  }

  Future<bool> toggleCalendarHeatmap(bool show) async {
    if (_showCalendarHeatmap == show) return true;

    _showCalendarHeatmap = show;
    bool success = await _saveSetting('showCalendarHeatmap', show);
    notifyListeners();
    return success;
  }

  Future<bool> setActiveNotificationSound(String sound) async {
    if (_activeNotificationSound == sound) return true;

    _activeNotificationSound = sound;
    bool success = await _saveSetting('activeNotificationSound', sound);
    notifyListeners();
    return success;
  }

  Future<bool> setDeadlineNotificationSound(String sound) async {
    if (_deadlineNotificationSound == sound) return true;

    _deadlineNotificationSound = sound;
    bool success = await _saveSetting('deadlineNotificationSound', sound);
    notifyListeners();
    return success;
  }

  Future<bool> setDeadlineWarningDays(int days) async {
    if (_deadlineWarningDays == days) return true;

    _deadlineWarningDays = days;
    bool success = await _saveSetting('deadlineWarningDays', days);
    notifyListeners();
    return success;
  }

  // Вспомогательные методы для преобразования типов в строки и обратно
  AppThemeMode _getThemeModeFromString(String themeModeStr) {
    switch (themeModeStr) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.dark;
    }
  }

  String _getThemeModeString(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.system:
        return 'system';
    }
  }

  NoteSortMode _getNoteSortModeFromString(String sortModeStr) {
    switch (sortModeStr) {
      case 'dateAsc':
        return NoteSortMode.dateAsc;
      case 'alphabetical':
        return NoteSortMode.alphabetical;
      case 'dateDesc':
      default:
        return NoteSortMode.dateDesc;
    }
  }

  String _getNoteSortModeString(NoteSortMode sortMode) {
    switch (sortMode) {
      case NoteSortMode.dateAsc:
        return 'dateAsc';
      case NoteSortMode.alphabetical:
        return 'alphabetical';
      case NoteSortMode.dateDesc:
        return 'dateDesc';
    }
  }

  // Применить все настройки по умолчанию
  Future<bool> resetToDefaults() async {
    _themeMode = AppThemeMode.dark;
    _notificationsEnabled = true;
    _notificationSound = 'default';
    _showOnLockScreen = true;
    _lineThickness = 2.0;
    _showThemeLines = true;
    _noteViewMode = NoteViewMode.card;
    _noteSortMode = NoteSortMode.dateDesc;
    _showSearchHistory = true;
    _searchHistory = [];
    _maxSearchHistoryItems = 10;
    _enableFocusMode = false;
    _showNoteLinkPreviews = true;
    _showCalendarHeatmap = true;
    _activeNotificationSound = 'default';
    _deadlineNotificationSound = 'urgent';
    _deadlineWarningDays = 3;

    bool success = await _saveAllSettings();
    notifyListeners();
    return success;
  }

  // Сохранение всех настроек сразу
  Future<bool> _saveAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Сохранение темы
      await prefs.setString('themeMode', _getThemeModeString(_themeMode));

      // Сохранение настроек уведомлений
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      await prefs.setString('notificationSound', _notificationSound);
      await prefs.setBool('showOnLockScreen', _showOnLockScreen);
      await prefs.setString(
        'activeNotificationSound',
        _activeNotificationSound,
      );
      await prefs.setString(
        'deadlineNotificationSound',
        _deadlineNotificationSound,
      );
      await prefs.setInt('deadlineWarningDays', _deadlineWarningDays);

      // Сохранение настроек внешнего вида
      await prefs.setDouble('lineThickness', _lineThickness);
      await prefs.setBool('showThemeLines', _showThemeLines);
      await prefs.setString(
        'noteViewMode',
        _noteViewMode == NoteViewMode.card ? 'card' : 'list',
      );
      await prefs.setString(
        'noteSortMode',
        _getNoteSortModeString(_noteSortMode),
      );
      await prefs.setBool('showCalendarHeatmap', _showCalendarHeatmap);
      await prefs.setBool('showNoteLinkPreviews', _showNoteLinkPreviews);

      // Сохранение настроек поиска
      await prefs.setBool('showSearchHistory', _showSearchHistory);
      await prefs.setStringList('searchHistory', _searchHistory);
      await prefs.setInt('maxSearchHistoryItems', _maxSearchHistoryItems);

      // Сохранение режима фокусировки
      await prefs.setBool('enableFocusMode', _enableFocusMode);

      return true;
    } catch (e) {
      _hasError = true;
      _errorMessage = "Ошибка сохранения настроек: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Сброс состояния ошибки
  void resetError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}

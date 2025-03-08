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
  bool _enableMarkdownFormatting = true;
  bool _showNoteLinkPreviews = true;

  // Настройки поиска
  bool _showSearchHistory = true;
  List<String> _searchHistory = [];
  int _maxSearchHistoryItems = 10;

  // Режим фокусировки
  bool _enableFocusMode = false;

  // Флаг, который указывает, загружены ли настройки из SharedPreferences
  bool _initialized = false;

  // Геттеры
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
  bool get enableMarkdownFormatting => _enableMarkdownFormatting;
  bool get enableFocusMode => _enableFocusMode;
  bool get showNoteLinkPreviews => _showNoteLinkPreviews;
  bool get showCalendarHeatmap => _showCalendarHeatmap;
  String get activeNotificationSound => _activeNotificationSound;
  String get deadlineNotificationSound => _deadlineNotificationSound;
  int get deadlineWarningDays => _deadlineWarningDays;
  bool get initialized => _initialized;

  // Инициализация настроек из SharedPreferences
  Future<void> initSettings() async {
    if (_initialized) return;

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
      _enableMarkdownFormatting =
          prefs.getBool('enableMarkdownFormatting') ?? true;
      _showNoteLinkPreviews = prefs.getBool('showNoteLinkPreviews') ?? true;

      // Загрузка настроек поиска
      _showSearchHistory = prefs.getBool('showSearchHistory') ?? true;
      final searchHistoryJson = prefs.getStringList('searchHistory') ?? [];
      _searchHistory = searchHistoryJson;
      _maxSearchHistoryItems = prefs.getInt('maxSearchHistoryItems') ?? 10;

      // Загрузка режима фокусировки
      _enableFocusMode = prefs.getBool('enableFocusMode') ?? false;

      _initialized = true;
      notifyListeners();
    } catch (e) {
      // Если произошла ошибка при загрузке настроек, используем значения по умолчанию
      _initialized = true;
    }
  }

  // Сохранение всех настроек
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Сохранение темы
    await prefs.setString('themeMode', _getThemeModeString(_themeMode));

    // Сохранение настроек уведомлений
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setString('notificationSound', _notificationSound);
    await prefs.setBool('showOnLockScreen', _showOnLockScreen);
    await prefs.setString('activeNotificationSound', _activeNotificationSound);
    await prefs.setString(
        'deadlineNotificationSound', _deadlineNotificationSound);
    await prefs.setInt('deadlineWarningDays', _deadlineWarningDays);

    // Сохранение настроек внешнего вида
    await prefs.setDouble('lineThickness', _lineThickness);
    await prefs.setBool('showThemeLines', _showThemeLines);
    await prefs.setString(
        'noteViewMode', _noteViewMode == NoteViewMode.card ? 'card' : 'list');
    await prefs.setString(
        'noteSortMode', _getNoteSortModeString(_noteSortMode));
    await prefs.setBool('showCalendarHeatmap', _showCalendarHeatmap);
    await prefs.setBool('enableMarkdownFormatting', _enableMarkdownFormatting);
    await prefs.setBool('showNoteLinkPreviews', _showNoteLinkPreviews);

    // Сохранение настроек поиска
    await prefs.setBool('showSearchHistory', _showSearchHistory);
    await prefs.setStringList('searchHistory', _searchHistory);
    await prefs.setInt('maxSearchHistoryItems', _maxSearchHistoryItems);

    // Сохранение режима фокусировки
    await prefs.setBool('enableFocusMode', _enableFocusMode);
  }

  // Проверка темной темы
  bool isDarkMode(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  // Изменение настроек
  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    _saveSettings();
    notifyListeners();
  }

  void setNotificationSound(String sound) {
    if (_notificationSound == sound) return;
    _notificationSound = sound;
    _saveSettings();
    notifyListeners();
  }

  void toggleLockScreenNotifications(bool show) {
    if (_showOnLockScreen == show) return;
    _showOnLockScreen = show;
    _saveSettings();
    notifyListeners();
  }

  void setLineThickness(double thickness) {
    if (_lineThickness == thickness) return;
    _lineThickness = thickness;
    _saveSettings();
    notifyListeners();
  }

  void toggleThemeLines(bool show) {
    if (_showThemeLines == show) return;
    _showThemeLines = show;
    _saveSettings();
    notifyListeners();
  }

  // Методы для новых настроек
  void setNoteViewMode(NoteViewMode mode) {
    if (_noteViewMode == mode) return;
    _noteViewMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggleNoteViewMode() {
    _noteViewMode = _noteViewMode == NoteViewMode.card
        ? NoteViewMode.list
        : NoteViewMode.card;
    _saveSettings();
    notifyListeners();
  }

  void setNoteSortMode(NoteSortMode mode) {
    if (_noteSortMode == mode) return;
    _noteSortMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggleSearchHistory(bool show) {
    if (_showSearchHistory == show) return;
    _showSearchHistory = show;
    _saveSettings();
    notifyListeners();
  }

  // Добавление поискового запроса в историю
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    // Избегаем дублирования: удаляем существующий запрос
    _searchHistory.remove(query);

    // Добавляем запрос в начало списка
    _searchHistory.insert(0, query);

    // Обрезаем список до заданного максимума
    if (_searchHistory.length > _maxSearchHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxSearchHistoryItems);
    }

    _saveSettings();
    notifyListeners();
  }

  // Очистка истории поиска
  void clearSearchHistory() {
    if (_searchHistory.isEmpty) return;
    _searchHistory.clear();
    _saveSettings();
    notifyListeners();
  }

  // Удаление конкретного запроса из истории
  void removeFromSearchHistory(String query) {
    final removed = _searchHistory.remove(query);
    if (removed) {
      _saveSettings();
      notifyListeners();
    }
  }

  void setMaxSearchHistoryItems(int max) {
    if (_maxSearchHistoryItems == max) return;
    _maxSearchHistoryItems = max;

    // Обрезаем существующую историю, если она превышает новый лимит
    if (_searchHistory.length > max) {
      _searchHistory = _searchHistory.sublist(0, max);
    }

    _saveSettings();
    notifyListeners();
  }

  void toggleMarkdownFormatting(bool enable) {
    if (_enableMarkdownFormatting == enable) return;
    _enableMarkdownFormatting = enable;
    _saveSettings();
    notifyListeners();
  }

  void toggleFocusMode(bool enable) {
    if (_enableFocusMode == enable) return;
    _enableFocusMode = enable;
    _saveSettings();
    notifyListeners();
  }

  void toggleNoteLinkPreviews(bool show) {
    if (_showNoteLinkPreviews == show) return;
    _showNoteLinkPreviews = show;
    _saveSettings();
    notifyListeners();
  }

  void toggleCalendarHeatmap(bool show) {
    if (_showCalendarHeatmap == show) return;
    _showCalendarHeatmap = show;
    _saveSettings();
    notifyListeners();
  }

  void setActiveNotificationSound(String sound) {
    if (_activeNotificationSound == sound) return;
    _activeNotificationSound = sound;
    _saveSettings();
    notifyListeners();
  }

  void setDeadlineNotificationSound(String sound) {
    if (_deadlineNotificationSound == sound) return;
    _deadlineNotificationSound = sound;
    _saveSettings();
    notifyListeners();
  }

  void setDeadlineWarningDays(int days) {
    if (_deadlineWarningDays == days) return;
    _deadlineWarningDays = days;
    _saveSettings();
    notifyListeners();
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
  void resetToDefaults() {
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
    _enableMarkdownFormatting = true;
    _enableFocusMode = false;
    _showNoteLinkPreviews = true;
    _showCalendarHeatmap = true;
    _activeNotificationSound = 'default';
    _deadlineNotificationSound = 'urgent';
    _deadlineWarningDays = 3;

    _saveSettings();
    notifyListeners();
  }
}

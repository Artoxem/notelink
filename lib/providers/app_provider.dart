import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AppProvider with ChangeNotifier {
  AppThemeMode _themeMode =
      AppThemeMode.dark; // По умолчанию выбираем темную тему
  bool _notificationsEnabled = true;
  String _notificationSound = 'default';
  bool _showOnLockScreen = true;
  double _lineThickness = 2.0;
  bool _showThemeLines = true;

  // Новые параметры
  NoteViewMode _noteViewMode =
      NoteViewMode.card; // Режим просмотра заметок по умолчанию - карточки
  NoteSortMode _noteSortMode = NoteSortMode
      .dateDesc; // Сортировка заметок по умолчанию - от новых к старым
  bool _showSearchHistory = true; // Показывать историю поиска
  List<String> _searchHistory = []; // История поисковых запросов
  int _maxSearchHistoryItems = 10; // Максимальное количество запросов в истории
  bool _enableMarkdownFormatting = true; // Включить Markdown-форматирование
  bool _enableFocusMode = false; // Режим фокусировки по умолчанию выключен
  bool _showNoteLinkPreviews = true; // Показывать превью ссылок между заметками
  bool _showCalendarHeatmap = true; // Показывать тепловую карту в календаре
  String _activeNotificationSound =
      'default'; // Звук уведомления для активных заметок
  String _deadlineNotificationSound =
      'urgent'; // Звук уведомления для дедлайнов
  int _deadlineWarningDays =
      3; // За сколько дней предупреждать о приближающемся дедлайне

  // Геттеры
  AppThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  String get notificationSound => _notificationSound;
  bool get showOnLockScreen => _showOnLockScreen;
  double get lineThickness => _lineThickness;
  bool get showThemeLines => _showThemeLines;

  // Геттеры для новых параметров
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

  // Проверка темной темы
  bool isDarkMode(BuildContext context) {
    if (_themeMode == AppThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  // Изменение настроек
  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  void setNotificationSound(String sound) {
    _notificationSound = sound;
    notifyListeners();
  }

  void toggleLockScreenNotifications(bool show) {
    _showOnLockScreen = show;
    notifyListeners();
  }

  void setLineThickness(double thickness) {
    _lineThickness = thickness;
    notifyListeners();
  }

   void toggleThemeLines(bool show) {
    _showThemeLines = show;
    notifyListeners();
  }

  // Методы для новых настроек
  void setNoteViewMode(NoteViewMode mode) {
    _noteViewMode = mode;
    notifyListeners();
  }

  void toggleNoteViewMode() {
    _noteViewMode = _noteViewMode == NoteViewMode.card
        ? NoteViewMode.list
        : NoteViewMode.card;
    notifyListeners();
  }

  void setNoteSortMode(NoteSortMode mode) {
    _noteSortMode = mode;
    notifyListeners();
  }

  void toggleSearchHistory(bool show) {
    _showSearchHistory = show;
    notifyListeners();
  }

  // Добавление поискового запроса в историю
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    // Удаляем этот запрос, если он уже есть (чтобы переместить его в начало)
    _searchHistory.remove(query);

    // Добавляем запрос в начало списка
    _searchHistory.insert(0, query);

    // Обрезаем список до заданного максимума
    if (_searchHistory.length > _maxSearchHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxSearchHistoryItems);
    }

    notifyListeners();
  }

  // Очистка истории поиска
  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  // Удаление конкретного запроса из истории
  void removeFromSearchHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  void setMaxSearchHistoryItems(int max) {
    _maxSearchHistoryItems = max;
    // Обрезаем существующую историю, если она превышает новый лимит
    if (_searchHistory.length > max) {
      _searchHistory = _searchHistory.sublist(0, max);
    }
    notifyListeners();
  }

  void toggleMarkdownFormatting(bool enable) {
    _enableMarkdownFormatting = enable;
    notifyListeners();
  }

  void toggleFocusMode(bool enable) {
    _enableFocusMode = enable;
    notifyListeners();
  }

  void toggleNoteLinkPreviews(bool show) {
    _showNoteLinkPreviews = show;
    notifyListeners();
  }

  void toggleCalendarHeatmap(bool show) {
    _showCalendarHeatmap = show;
    notifyListeners();
  }

  void setActiveNotificationSound(String sound) {
    _activeNotificationSound = sound;
    notifyListeners();
  }

  void setDeadlineNotificationSound(String sound) {
    _deadlineNotificationSound = sound;
    notifyListeners();
  }

  void setDeadlineWarningDays(int days) {
    _deadlineWarningDays = days;
    notifyListeners();
  }
}
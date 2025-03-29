import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import '../widgets/note_list.dart';
import 'note_detail_screen.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({Key? key}) : super(key: key);

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

// Перечисление для типов сортировки
enum SortType {
  deadlineAsc, // По ближайшему дедлайну (сначала ближайшие)
  deadlineDesc, // По дальнему дедлайну (сначала дальние)
  creationAsc, // По дате создания (сначала старые)
  creationDesc // По дате создания (сначала новые)
}

// Перечисление для режимов фильтрации
enum FilterMode {
  active, // Только активные (невыполненные)
  completed, // Только выполненные
  all // Все заметки с дедлайнами
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  bool _isLoading = true;
  List<Note> _deadlineNotes = [];

  // Настройки фильтрации и сортировки с значениями по умолчанию
  FilterMode _filterMode = FilterMode.active;
  SortType _sortType = SortType.deadlineAsc;

  // Ключи для сохранения настроек
  static const String _keyFilterMode = 'deadlines_filter_mode';
  static const String _keySortType = 'deadlines_sort_type';

  @override
  void initState() {
    super.initState();
    // Загружаем сохраненные настройки и данные при инициализации
    _loadSettings().then((_) => _loadDeadlines());
  }

  // Загрузка настроек из SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Загружаем режим фильтрации
      final filterModeIndex = prefs.getInt(_keyFilterMode);
      if (filterModeIndex != null &&
          filterModeIndex < FilterMode.values.length) {
        _filterMode = FilterMode.values[filterModeIndex];
      }

      // Загружаем тип сортировки
      final sortTypeIndex = prefs.getInt(_keySortType);
      if (sortTypeIndex != null && sortTypeIndex < SortType.values.length) {
        _sortType = SortType.values[sortTypeIndex];
      }

      if (mounted) {
        setState(() {
          // Обновляем UI с загруженными настройками
        });
      }
    } catch (e) {
      print('Ошибка при загрузке настроек: $e');
      // В случае ошибки используем значения по умолчанию
    }
  }

  // Сохранение настроек в SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyFilterMode, _filterMode.index);
      await prefs.setInt(_keySortType, _sortType.index);
    } catch (e) {
      print('Ошибка при сохранении настроек: $e');
    }
  }

  // Переключение режима фильтрации
  Future<void> _setFilterMode(FilterMode mode) async {
    if (!mounted || _filterMode == mode) return;

    setState(() {
      _filterMode = mode;
      _isLoading = true; // Показываем индикатор загрузки при смене режима
    });

    // Сохраняем настройки и перезагружаем данные
    await _saveSettings();
    await _loadDeadlines();
  }

  // Переключение типа сортировки
  Future<void> _setSortType(SortType type) async {
    if (!mounted || _sortType == type) return;

    setState(() {
      _sortType = type;
      _isLoading = true; // Показываем индикатор загрузки при смене сортировки
    });

    // Сохраняем настройки и перезагружаем данные
    await _saveSettings();
    await _loadDeadlines();
  }

  // Загрузка заметок с дедлайнами с применением фильтра и сортировки
  Future<void> _loadDeadlines() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Принудительно загружаем актуальные заметки из базы данных
      await notesProvider.loadNotes(force: true);

      // Фильтруем заметки с дедлайнами
      List<Note> allDeadlineNotes =
          notesProvider.notes.where((note) => note.hasDeadline).toList();

      // Применяем фильтр в зависимости от режима
      List<Note> filteredNotes;
      switch (_filterMode) {
        case FilterMode.active:
          filteredNotes =
              allDeadlineNotes.where((note) => !note.isCompleted).toList();
          break;
        case FilterMode.completed:
          filteredNotes =
              allDeadlineNotes.where((note) => note.isCompleted).toList();
          break;
        case FilterMode.all:
          filteredNotes = allDeadlineNotes;
          break;
      }

      // Применяем сортировку
      _applySorting(filteredNotes);

      if (mounted) {
        setState(() {
          _deadlineNotes = filteredNotes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке задач: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке задач: $e')),
        );
      }
    }
  }

  // Применение выбранной сортировки к списку заметок
  void _applySorting(List<Note> notes) {
    switch (_sortType) {
      case SortType.deadlineAsc:
        // Сортировка по дате дедлайна (сначала ближайшие)
        notes.sort((a, b) {
          if (a.deadlineDate == null && b.deadlineDate == null) return 0;
          if (a.deadlineDate == null) return 1;
          if (b.deadlineDate == null) return -1;

          // Сначала сортируем по статусу выполнения (невыполненные в начале)
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Затем по дате дедлайна (от ближайших к дальним)
          return a.deadlineDate!.compareTo(b.deadlineDate!);
        });
        break;

      case SortType.deadlineDesc:
        // Сортировка по дате дедлайна (сначала дальние)
        notes.sort((a, b) {
          if (a.deadlineDate == null && b.deadlineDate == null) return 0;
          if (a.deadlineDate == null) return 1;
          if (b.deadlineDate == null) return -1;

          // Сначала сортируем по статусу выполнения (невыполненные в начале)
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Затем по дате дедлайна (от дальних к ближайшим)
          return b.deadlineDate!.compareTo(a.deadlineDate!);
        });
        break;

      case SortType.creationAsc:
        // Сортировка по дате создания (сначала старые)
        notes.sort((a, b) {
          // Сначала сортируем по статусу выполнения (невыполненные в начале)
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Затем по дате создания (от старых к новым)
          return a.createdAt.compareTo(b.createdAt);
        });
        break;

      case SortType.creationDesc:
        // Сортировка по дате создания (сначала новые)
        notes.sort((a, b) {
          // Сначала сортируем по статусу выполнения (невыполненные в начале)
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Затем по дате создания (от новых к старым)
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  // Получение иконки сортировки в зависимости от текущего режима
  IconData _getSortIcon() {
    switch (_sortType) {
      case SortType.deadlineAsc:
        return Icons.arrow_upward;
      case SortType.deadlineDesc:
        return Icons.arrow_downward;
      case SortType.creationAsc:
        return Icons.calendar_today;
      case SortType.creationDesc:
        return Icons.calendar_view_day;
    }
  }

  // Получение текста подсказки для кнопки сортировки
  String _getSortTooltip() {
    switch (_sortType) {
      case SortType.deadlineAsc:
        return 'Сначала ближайшие дедлайны';
      case SortType.deadlineDesc:
        return 'Сначала дальние дедлайны';
      case SortType.creationAsc:
        return 'Сначала старые заметки';
      case SortType.creationDesc:
        return 'Сначала новые заметки';
    }
  }

  // Получение цвета для кнопки фильтра в зависимости от режима
  Color _getFilterColor() {
    switch (_filterMode) {
      case FilterMode.active:
        return const Color.fromARGB(
            255, 164, 50, 24); // Оранжевый для активных задач
      case FilterMode.completed:
        return AppColors.completed; // Зеленый для выполненных задач
      case FilterMode.all:
        return Colors.purpleAccent; // Фиолетовый для всех задач
    }
  }

  // Получение текста для кнопки фильтра
  String _getFilterText() {
    switch (_filterMode) {
      case FilterMode.active:
        return 'Активные';
      case FilterMode.completed:
        return 'Выполненные';
      case FilterMode.all:
        return 'Все задачи';
    }
  }

  // Получение иконки для кнопки фильтра
  IconData _getFilterIcon() {
    switch (_filterMode) {
      case FilterMode.active:
        return Icons.radio_button_unchecked;
      case FilterMode.completed:
        return Icons.check_circle;
      case FilterMode.all:
        return Icons.list;
    }
  }

  // Обработчик для действий над задачами
  Future<void> _handleNoteAction(Note note, NoteListAction action) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _loadDeadlines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deadlines'),
        actions: [
          // Стильная кнопка фильтра, открывающая контекстное меню
          PopupMenuButton<FilterMode>(
            tooltip: 'Фильтр задач',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getFilterColor().withOpacity(0.8),
                borderRadius:
                    BorderRadius.circular(8), // Менее скругленные углы
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFilterIcon(),
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getFilterText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (FilterMode filterMode) async {
              await _setFilterMode(filterMode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<FilterMode>>[
              PopupMenuItem<FilterMode>(
                value: FilterMode.active,
                child: ListTile(
                  leading: Icon(
                    Icons.radio_button_unchecked,
                    color: _filterMode == FilterMode.active
                        ? const Color.fromARGB(255, 164, 50, 24)
                        : null,
                  ),
                  title: Text(
                    'Активные',
                    style: TextStyle(
                      color: _filterMode == FilterMode.active
                          ? const Color.fromARGB(255, 164, 50, 24)
                          : null,
                      fontWeight: _filterMode == FilterMode.active
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<FilterMode>(
                value: FilterMode.completed,
                child: ListTile(
                  leading: Icon(
                    Icons.check_circle,
                    color: _filterMode == FilterMode.completed
                        ? AppColors.completed
                        : null,
                  ),
                  title: Text(
                    'Выполненные',
                    style: TextStyle(
                      color: _filterMode == FilterMode.completed
                          ? AppColors.completed
                          : null,
                      fontWeight: _filterMode == FilterMode.completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<FilterMode>(
                value: FilterMode.all,
                child: ListTile(
                  leading: Icon(
                    Icons.list,
                    color: _filterMode == FilterMode.all
                        ? Colors.purpleAccent
                        : null,
                  ),
                  title: Text(
                    'Все задачи',
                    style: TextStyle(
                      color: _filterMode == FilterMode.all
                          ? Colors.purpleAccent
                          : null,
                      fontWeight: _filterMode == FilterMode.all
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          // Стильная кнопка сортировки, в том же стиле, но меньше
          PopupMenuButton<SortType>(
            tooltip: 'Сортировка задач',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.accentSecondary.withOpacity(0.8),
                borderRadius:
                    BorderRadius.circular(8), // Менее скругленные углы
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                _getSortIcon(),
                color: Colors.white,
                size: 18,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (SortType sortType) async {
              await _setSortType(sortType);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
              PopupMenuItem<SortType>(
                value: SortType.deadlineAsc,
                child: ListTile(
                  leading: Icon(
                    Icons.arrow_upward,
                    color: _sortType == SortType.deadlineAsc
                        ? AppColors.accentSecondary
                        : null,
                  ),
                  title: Text(
                    'Сначала ближайшие дедлайны',
                    style: TextStyle(
                      color: _sortType == SortType.deadlineAsc
                          ? AppColors.accentSecondary
                          : null,
                      fontWeight: _sortType == SortType.deadlineAsc
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<SortType>(
                value: SortType.deadlineDesc,
                child: ListTile(
                  leading: Icon(
                    Icons.arrow_downward,
                    color: _sortType == SortType.deadlineDesc
                        ? AppColors.accentSecondary
                        : null,
                  ),
                  title: Text(
                    'Сначала дальние дедлайны',
                    style: TextStyle(
                      color: _sortType == SortType.deadlineDesc
                          ? AppColors.accentSecondary
                          : null,
                      fontWeight: _sortType == SortType.deadlineDesc
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<SortType>(
                value: SortType.creationDesc,
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_view_day,
                    color: _sortType == SortType.creationDesc
                        ? AppColors.accentSecondary
                        : null,
                  ),
                  title: Text(
                    'Сначала новые заметки',
                    style: TextStyle(
                      color: _sortType == SortType.creationDesc
                          ? AppColors.accentSecondary
                          : null,
                      fontWeight: _sortType == SortType.creationDesc
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<SortType>(
                value: SortType.creationAsc,
                child: ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    color: _sortType == SortType.creationAsc
                        ? AppColors.accentSecondary
                        : null,
                  ),
                  title: Text(
                    'Сначала старые заметки',
                    style: TextStyle(
                      color: _sortType == SortType.creationAsc
                          ? AppColors.accentSecondary
                          : null,
                      fontWeight: _sortType == SortType.creationAsc
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeadlines,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _deadlineNotes.isEmpty
                ? _buildEmptyState()
                : NoteListWidget(
                    key: ValueKey(
                        'deadline_notes_${_filterMode.toString()}_${_sortType.toString()}'),
                    notes: _deadlineNotes,
                    emptyMessage: 'Нет задач с дедлайном',
                    showThemeBadges: true,
                    swipeDirection: SwipeDirection.both,
                    useCachedAnimation: true,
                    // Доступные действия для задач с дедлайном
                    availableActions: [
                      NoteListAction.edit,
                      NoteListAction.favorite,
                      NoteListAction.complete,
                      NoteListAction.delete,
                    ],
                    onNoteTap: (note) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteDetailScreen(note: note),
                        ),
                      ).then((_) => _loadDeadlines());
                    },
                    onNoteDeleted: (note) async {
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      await notesProvider.deleteNote(note.id);
                      if (mounted) {
                        _handleNoteAction(note, NoteListAction.delete);
                      }
                    },
                    onNoteFavoriteToggled: (note) async {
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      await notesProvider.toggleFavorite(note.id);
                      if (mounted) {
                        _handleNoteAction(note, NoteListAction.favorite);
                      }
                    },
                    onActionSelected: (note, action) async {
                      if (action == NoteListAction.complete) {
                        // Если изменили статус выполнения, перезагружаем список
                        // (особенно важно, если фильтр показывает только активные или выполненные)
                        _handleNoteAction(note, action);
                      } else {
                        // Для других действий тоже обновляем список
                        _handleNoteAction(note, action);
                      }
                    },
                  ),
      ),
    );
  }

  // Виджет для отображения пустого состояния
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateMessage(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте новую задачу с дедлайном',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Получение сообщения для пустого состояния в зависимости от режима фильтрации
  String _getEmptyStateMessage() {
    switch (_filterMode) {
      case FilterMode.active:
        return 'Нет активных задач';
      case FilterMode.completed:
        return 'Нет выполненных задач';
      case FilterMode.all:
        return 'Нет задач с дедлайном';
    }
  }
}

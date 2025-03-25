import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  byDeadline, // По близости дедлайна
  byCreation // По дате создания
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  bool _isLoading = false;
  List<Note> _deadlineNotes = [];
  bool _showCompleted = false;
  // Тип сортировки (по умолчанию - по близости дедлайна)
  SortType _sortType = SortType.byDeadline;
  // Флаг для отслеживания, происходит ли в данный момент операция переключения фильтра
  bool _isFilterChanging = false;
  // Флаг для отслеживания уничтожения виджета
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // Устанавливаем начальные значения
    _isLoading = true;
    _isFilterChanging = false;
    _deadlineNotes = [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Загружаем данные при первой инициализации и при изменении зависимостей
    if (_isLoading && !_isFilterChanging) {
      // Используем Future.microtask для безопасного вызова после построения виджета
      Future.microtask(() => _loadDeadlines());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Оптимизированный метод загрузки заметок с дедлайнами
  Future<void> _loadDeadlines() async {
    // Защита от повторного вызова во время загрузки
    if (_isLoading && !_isFilterChanging) return;

    // Отмечаем начало загрузки
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Небольшая задержка для обеспечения обновления UI
      await Future.delayed(const Duration(milliseconds: 50));

      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Принудительно загружаем актуальные заметки из базы данных
      await notesProvider.loadNotes(force: true);

      // Фильтруем только заметки с дедлайнами
      List<Note> allDeadlineNotes =
          notesProvider.notes.where((note) => note.hasDeadline).toList();

      // Применяем фильтр по статусу выполнения
      List<Note> filteredNotes;
      if (_showCompleted) {
        // Показываем все задачи с дедлайнами
        filteredNotes = allDeadlineNotes;
      } else {
        // Только невыполненные
        filteredNotes =
            allDeadlineNotes.where((note) => !note.isCompleted).toList();
      }

      // Применяем сортировку в зависимости от выбранного типа
      _applySorting(filteredNotes);

      // Обновляем состояние только если виджет все еще в дереве и не уничтожен
      if (mounted && !_isDisposed) {
        setState(() {
          _deadlineNotes = filteredNotes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке задач: $e');
      // Обрабатываем ошибки загрузки
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке задач: $e')),
        );
      }
    }
  }

  // Применение сортировки в зависимости от выбранного типа
  void _applySorting(List<Note> notes) {
    switch (_sortType) {
      case SortType.byDeadline:
        // Сортировка по дате дедлайна (сначала ближайшие)
        notes.sort((a, b) {
          if (a.deadlineDate == null && b.deadlineDate == null) return 0;
          if (a.deadlineDate == null) return 1;
          if (b.deadlineDate == null) return -1;

          // Выполненные задачи идут в конце списка
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Для задач с одинаковым статусом сортируем по дате
          return a.deadlineDate!.compareTo(b.deadlineDate!);
        });
        break;

      case SortType.byCreation:
        // Сортировка по дате создания (от новых к старым)
        notes.sort((a, b) {
          // Сначала по статусу выполнения (невыполненные в начале)
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;

          // Затем по дате создания
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
  }

  // Переключение типа сортировки
  void _toggleSortType() {
    setState(() {
      _sortType = _sortType == SortType.byDeadline
          ? SortType.byCreation
          : SortType.byDeadline;
    });

    // Перезагружаем данные с новой сортировкой
    _loadDeadlines();
  }

  // Безопасный метод переключения фильтра отображения выполненных задач
  void _toggleCompletedFilter() async {
    // Проверяем, не выполняется ли уже операция переключения
    if (_isFilterChanging) return;

    // Устанавливаем флаг
    _isFilterChanging = true;

    try {
      // Обновляем состояние фильтра
      setState(() {
        _showCompleted = !_showCompleted;
        // Сразу установим состояние загрузки, чтобы показать индикатор
        _isLoading = true;
      });

      // Загружаем актуальный список заметок, не используя обрабатывающие методы
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      await notesProvider.loadNotes();

      // Применяем фильтр напрямую
      List<Note> allDeadlineNotes =
          notesProvider.notes.where((note) => note.hasDeadline).toList();

      List<Note> filteredNotes = _showCompleted
          ? allDeadlineNotes // Показываем все задачи с дедлайнами
          : allDeadlineNotes.where((note) => !note.isCompleted).toList();

      // Применяем выбранную сортировку
      _applySorting(filteredNotes);

      // Обновляем состояние только если виджет все еще в дереве и не уничтожен
      if (mounted && !_isDisposed) {
        setState(() {
          _deadlineNotes = filteredNotes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Ошибка при переключении фильтра: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false; // Важно! Сбрасываем состояние загрузки при ошибке
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при применении фильтра: $e')),
        );
      }
    } finally {
      // Снимаем флаг операции переключения
      _isFilterChanging = false;
    }
  }

  // Обработчик для действий над задачами
  Future<void> _handleNoteAction(Note note, NoteListAction action) async {
    // Добавляем небольшую задержку перед обновлением списка
    // чтобы анимации успели завершиться
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted && !_isDisposed) {
      // Перезагружаем список задач
      _loadDeadlines();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи с дедлайном'),
        actions: [
          // Кнопка сортировки
          IconButton(
            icon: Icon(
              _sortType == SortType.byDeadline ? Icons.event : Icons.schedule,
              color: Colors.white,
            ),
            tooltip: _sortType == SortType.byDeadline
                ? 'Сортировка по близости дедлайна'
                : 'Сортировка по дате создания',
            onPressed: _toggleSortType,
          ),

          // Кнопка фильтра выполненных задач с изменяемым цветом
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 16.0),
            child: TextButton.icon(
              icon: Icon(
                _showCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: Colors.white,
              ),
              label: Text(
                _showCompleted ? 'Все задачи' : 'Активные',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _showCompleted
                    ? AppColors.completed
                        .withOpacity(0.7) // Зеленый для выполненных
                    : AppColors.accentSecondary
                        .withOpacity(0.7), // Оранжевый для активных
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _toggleCompletedFilter,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeadlines,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _deadlineNotes.isEmpty
                ? Center(
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
                          _showCompleted
                              ? 'Нет задач с дедлайном'
                              : 'Нет активных задач с дедлайном',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте новую задачу с дедлайном',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                : NoteListWidget(
                    // Уникальный ключ, зависящий от текущего состояния фильтра, сортировки и времени
                    key: ValueKey(
                        'deadline_notes_${_showCompleted ? 'all' : 'active'}_${_sortType.toString()}_${DateTime.now().millisecondsSinceEpoch}'),
                    notes: _deadlineNotes,
                    emptyMessage: _showCompleted
                        ? 'Нет задач с дедлайном'
                        : 'Нет активных задач с дедлайном',
                    showThemeBadges: true,
                    swipeDirection: SwipeDirection.both,
                    useCachedAnimation: true,
                    // Добавляем доступные действия для задач с дедлайном
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
                      // Важно! Добавляем проверку, что виджет все еще в дереве
                      if (mounted && !_isDisposed) {
                        _handleNoteAction(note, NoteListAction.delete);
                      }
                    },
                    onNoteFavoriteToggled: (note) async {
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      await notesProvider.toggleFavorite(note.id);
                      // Важно! Добавляем проверку, что виджет все еще в дереве
                      if (mounted && !_isDisposed) {
                        _handleNoteAction(note, NoteListAction.favorite);
                      }
                    },
                    // Добавляем общий обработчик для всех действий
                    onActionSelected: (note, action) async {
                      if (action == NoteListAction.complete) {
                        // При изменении статуса выполнения нам может потребоваться
                        // скрыть элемент из списка, если фильтр не показывает выполненные задачи
                        if (!_showCompleted && !note.isCompleted) {
                          // Задача отмечена как выполненная, и мы не отображаем выполненные,
                          // поэтому нужно обновить список
                          _handleNoteAction(note, action);
                        } else {
                          // В остальных случаях просто обновляем список
                          _handleNoteAction(note, action);
                        }
                      } else {
                        // Для других действий просто обновляем список
                        _handleNoteAction(note, action);
                      }
                    },
                  ),
      ),
    );
  }
}

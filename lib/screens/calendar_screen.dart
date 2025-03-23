import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/app_provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import 'note_detail_screen.dart';
import 'dart:math' as math;
import '../widgets/note_list.dart';
import 'package:flutter/services.dart';
import '../widgets/media_badge.dart';
import 'deadlines_screen.dart';

// Класс для рисования треугольника
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();
    // Рисуем треугольник, повернутый вершиной влево
    path.moveTo(size.width, 0); // Правый верхний угол
    path.lineTo(0, size.height / 2); // Левая середина
    path.lineTo(size.width, size.height); // Правый нижний угол
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Кастомный Painter для отрисовки ячейки календаря в стиле "тетрадь в клеточку"
class GridCellPainter extends CustomPainter {
  final bool isSelected;
  final bool isToday;
  final bool isOutside;
  final Color heatmapColor;

  GridCellPainter({
    this.isSelected = false,
    this.isToday = false,
    this.isOutside = false,
    required this.heatmapColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Определяем цвет фона
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = AppColors.accentSecondary;
    } else if (isToday) {
      backgroundColor = AppColors.accentPrimary;
    } else if (isOutside) {
      backgroundColor = AppColors.primary.withOpacity(0.3);
    } else {
      backgroundColor = AppColors.primary;
    }

    // Рисуем основной фон ячейки
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), backgroundPaint);

    // Рисуем тепловую карту поверх основного фона
    if (heatmapColor != Colors.transparent) {
      final Paint heatmapPaint = Paint()
        ..color = heatmapColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), heatmapPaint);
    }

    // Рисуем границы ячейки
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.0;

    // Если это выбранная ячейка или сегодняшний день, делаем границы более яркими
    if (isSelected || isToday) {
      borderPaint.color = Colors.white.withOpacity(0.7);
      borderPaint.strokeWidth = 1.5;
    }

    // Внешние границы ячейки
    canvas.drawLine(Offset(0, 0), Offset(width, 0), borderPaint); // Верхняя
    canvas.drawLine(
        Offset(0, height), Offset(width, height), borderPaint); // Нижняя
    canvas.drawLine(Offset(0, 0), Offset(0, height), borderPaint); // Левая
    canvas.drawLine(
        Offset(width, 0), Offset(width, height), borderPaint); // Правая
  }

  @override
  bool shouldRepaint(GridCellPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.isToday != isToday ||
        oldDelegate.isOutside != isOutside ||
        oldDelegate.heatmapColor != heatmapColor;
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  static void showAddNoteWithDate(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteDetailScreen(initialDate: date),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeOutQuint;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppAnimations.mediumDuration,
      ),
    );
  }

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  bool _isCalendarExpanded = true;

  Map<DateTime, List<Note>> _events = {};
  List<Note> _selectedEvents = [];

  // Анимация для перехода между месяцами
  late AnimationController _pageChangeController;
  late Animation<double> _pageChangeAnimation;

  @override
  void initState() {
    super.initState();

    // Инициализация контроллера анимации для переключения страниц
    _pageChangeController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _pageChangeAnimation = CurvedAnimation(
      parent: _pageChangeController,
      curve: Curves.easeInOut,
    );

    _pageChangeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Когда анимация завершена, сбрасываем контроллер
        _pageChangeController.reset();
      }
    });

    // Загружаем данные при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _pageChangeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return; // Предотвращаем параллельную загрузку

    _isLoading = true;

    try {
      // Загружаем заметки и темы
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);

      await Future.wait([
        notesProvider.loadNotes(),
        themesProvider.loadThemes(),
      ]);

      if (!mounted) return;

      // Обновляем только события, без вызова setState()
      _processEventsWithoutUpdate(notesProvider.notes);

      _isLoading = false;
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  // Добавьте новый метод для обработки событий без обновления UI
  void _processEventsWithoutUpdate(List<Note> notes) {
    if (!mounted) return;

    final Map<DateTime, List<Note>> events = {};

    for (final note in notes) {
      // Заметки с дедлайном
      if (note.hasDeadline && note.deadlineDate != null) {
        final normalizedDate = DateTime(
          note.deadlineDate!.year,
          note.deadlineDate!.month,
          note.deadlineDate!.day,
        );

        events[normalizedDate] ??= [];
        if (!events[normalizedDate]!.any((n) => n.id == note.id)) {
          events[normalizedDate]!.add(note);
        }
      }

      // Заметки, привязанные к дате
      if (note.hasDateLink && note.linkedDate != null) {
        final normalizedDate = DateTime(
          note.linkedDate!.year,
          note.linkedDate!.month,
          note.linkedDate!.day,
        );

        events[normalizedDate] ??= [];
        if (!events[normalizedDate]!.any((n) => n.id == note.id)) {
          events[normalizedDate]!.add(note);
        }
      } else {
        // Если заметка НЕ привязана к дате и НЕ имеет дедлайн,
        // только тогда добавляем её по дате создания
        final creationDate = DateTime(
          note.createdAt.year,
          note.createdAt.month,
          note.createdAt.day,
        );

        events[creationDate] ??= [];
        if (!events[creationDate]!.any((n) => n.id == note.id)) {
          events[creationDate]!.add(note);
        }
      }
    }

    // Сортировка заметок для каждого дня (от новых к старым)
    events.forEach((date, dateNotes) {
      dateNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    // Обновляем данные без вызова setState
    _events = events;
    _selectedEvents = _getEventsForDay(_selectedDay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final notesProvider = Provider.of<NotesProvider>(context);
    if (!notesProvider.isLoading && notesProvider.notes.isNotEmpty) {
      _processEvents(notesProvider.notes);
    }
  }

  void _processEvents(List<Note> notes) {
    if (!mounted) return;

    final Map<DateTime, List<Note>> events = {};

    for (final note in notes) {
      // Заметки с дедлайном
      if (note.hasDeadline && note.deadlineDate != null) {
        final normalizedDate = DateTime(
          note.deadlineDate!.year,
          note.deadlineDate!.month,
          note.deadlineDate!.day,
        );

        events[normalizedDate] ??= [];
        if (!events[normalizedDate]!.any((n) => n.id == note.id)) {
          events[normalizedDate]!.add(note);
        }
      }

      // Заметки, привязанные к дате
      if (note.hasDateLink && note.linkedDate != null) {
        final normalizedDate = DateTime(
          note.linkedDate!.year,
          note.linkedDate!.month,
          note.linkedDate!.day,
        );

        events[normalizedDate] ??= [];
        if (!events[normalizedDate]!.any((n) => n.id == note.id)) {
          events[normalizedDate]!.add(note);
        }
      } else {
        // Если заметка НЕ привязана к дате и НЕ имеет дедлайн,
        // только тогда добавляем её по дате создания
        final creationDate = DateTime(
          note.createdAt.year,
          note.createdAt.month,
          note.createdAt.day,
        );

        events[creationDate] ??= [];
        if (!events[creationDate]!.any((n) => n.id == note.id)) {
          events[creationDate]!.add(note);
        }
      }
    }

    // Сортировка заметок для каждого дня (от новых к старым)
    events.forEach((date, dateNotes) {
      dateNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    setState(() {
      _events = events;
      _selectedEvents = _getEventsForDay(_selectedDay);
    });
  }

  List<Note> _getEventsForDay(DateTime day) {
    // Нормализуем дату (без времени) для корректного сравнения
    final normalizedDay = DateTime(day.year, day.month, day.day);

    // Используем текущий кэш событий
    return _events[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  // Вычисляем интенсивность цвета тепловой карты в зависимости от количества заметок
  Color _getHeatmapColor(DateTime day, int eventsCount) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (!appProvider.showCalendarHeatmap || eventsCount == 0) {
      return Colors.transparent;
    }

    // Максимальное количество заметок для насыщенного цвета
    const maxEvents = 5;
    final intensity = math.min(1.0, eventsCount / maxEvents);

    // Базовый цвет тепловой карты
    final baseColor = AppColors.accentSecondary;

    // Возвращаем цвет с нужной непрозрачностью
    return baseColor.withOpacity(intensity * 0.3);
  }

  // Группировка заметок по темам для отображения индикаторов
  Map<String, List<Note>> _groupNotesByTheme(
      BuildContext context, List<Note> dayNotes) {
    Map<String, List<Note>> themeGroups = {};

    // Сначала обрабатываем заметки с темами
    for (final note in dayNotes) {
      if (note.themeIds.isNotEmpty) {
        // Берем первую тему заметки для группировки
        final themeId = note.themeIds.first;
        themeGroups[themeId] ??= [];
        themeGroups[themeId]!.add(note);
      }
    }

    // Отдельно группируем заметки без тем с ключом "no_theme"
    List<Note> notesWithoutThemes =
        dayNotes.where((note) => note.themeIds.isEmpty).toList();
    if (notesWithoutThemes.isNotEmpty) {
      themeGroups["no_theme"] = notesWithoutThemes;
    }

    return themeGroups;
  }

  // Отображение индикаторов по темам
  Widget _buildDayIndicatorsGroupedByThemes(
      BuildContext context, List<Note> dayNotes) {
    // Группируем заметки по темам
    final themeGroups = _groupNotesByTheme(context, dayNotes);

    // Распределяем группы по строкам
    // Каждая строка содержит индикаторы для одной темы
    List<Widget> themeRows = [];

    // Обработка каждой группы тем
    themeGroups.forEach((themeId, notes) {
      // Определяем цвет индикаторов для этой темы
      Color indicatorColor;

      if (themeId == "no_theme") {
        // Черный цвет для заметок без темы
        indicatorColor = Colors.black;
      } else {
        // Получаем цвет из темы
        final themesProvider =
            Provider.of<ThemesProvider>(context, listen: false);
        final theme = themesProvider.themes.firstWhere(
          (t) => t.id == themeId,
          orElse: () => NoteTheme(
            id: '',
            name: '',
            color: AppColors.themeColors[0].value.toString(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            noteIds: [],
          ),
        );

        try {
          indicatorColor = Color(int.parse(theme.color));
        } catch (e) {
          indicatorColor = AppColors.themeColors[0];
        }
      }

      // Создаем индикаторы для этой темы
      List<Widget> indicators = [];

      // Если больше 3 заметок, показываем 2 точки и треугольник
      if (notes.length > 3) {
        // Две точки
        for (int i = 0; i < 2; i++) {
          indicators.add(
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: indicatorColor == Colors.black
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 0.5,
                      )
                    : null,
              ),
            ),
          );
        }

        // Треугольник
        indicators.add(
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 2),
            child: CustomPaint(
              painter: TrianglePainter(color: indicatorColor),
            ),
          ),
        );
      } else {
        // Если 3 или меньше заметок, по точке для каждой
        for (int i = 0; i < notes.length; i++) {
          indicators.add(
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: indicatorColor == Colors.black
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 0.5,
                      )
                    : null,
              ),
            ),
          );
        }
      }

      // Добавляем строку индикаторов для этой темы
      themeRows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: indicators,
        ),
      );
    });

    // Компактно размещаем строки индикаторов
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: themeRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Получаем размер экрана
    final screenHeight = MediaQuery.of(context).size.height;
    // Рассчитываем высоту календаря в зависимости от состояния
    final calendarHeight = _isCalendarExpanded ? screenHeight * 0.45 : 0.0;
    // Рассчитываем высоту статистики
    final statsHeight = _isCalendarExpanded ? 50.0 : 0.0;

    return Scaffold(
      body: Column(
        children: [
          // Раздел с календарем (динамическая высота)
          AnimatedContainer(
            duration: AppAnimations.mediumDuration,
            height: calendarHeight,
            child: _isCalendarExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Заголовок месяца
                      _buildMonthHeader(),
                      // Календарь
                      Expanded(
                        child: Consumer<NotesProvider>(
                          builder: (context, notesProvider, _) {
                            return _buildGridCalendar(notesProvider);
                          },
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Счетчики месяца - с анимированной высотой
          AnimatedContainer(
            duration: AppAnimations.mediumDuration,
            height: statsHeight,
            child: _isCalendarExpanded
                ? _buildMonthStats()
                : const SizedBox.shrink(),
          ),

          // Кнопка свернуть/развернуть
          _buildExpandCollapseButton(),

          // Заголовок с заметками для выбранного дня
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Заметки на ${DateFormat('d MMMM').format(_selectedDay)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedEvents.length}',
                    style: const TextStyle(
                      color: AppColors.accentSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Список заметок - занимает всё оставшееся пространство
          Expanded(
            child: _selectedEvents.isEmpty
                ? _buildEmptyDateView()
                : NoteListWidget(
                    key: PageStorageKey<String>(
                        'notes_for_${_selectedDay.toString()}'),
                    notes: _selectedEvents,
                    emptyMessage: 'Нет заметок на выбранный день',
                    showThemeBadges: true,
                    useCachedAnimation: false,
                    swipeDirection: SwipeDirection.both,
                    onNoteTap: _viewNoteDetails,
                    onNoteDeleted: (note) async {
                      final notesProvider =
                          Provider.of<NotesProvider>(context, listen: false);
                      await notesProvider.deleteNote(note.id);
                      _loadData();
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildAddNoteButton(),
    );
  }

  // Новый метод для кнопки сворачивания/разворачивания календаря
  Widget _buildExpandCollapseButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _isCalendarExpanded = !_isCalendarExpanded;
        });
      },
      child: Container(
        width: double.infinity,
        height: 24,
        color: AppColors.accentSecondary.withOpacity(0.2),
        child: Center(
          child: Icon(
            _isCalendarExpanded
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: AppColors.accentSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка предыдущего месяца
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month - 1,
                  _focusedDay.day,
                );

                // Запускаем анимацию смены страницы
                _pageChangeController.forward(from: 0.0);
              });
            },
          ),

          // Название месяца и год - улучшенная версия с анимацией
          AnimatedBuilder(
            animation: _pageChangeAnimation,
            builder: (context, child) {
              // Используем Transform.scale вместо Opacity
              return Transform.scale(
                scale: 1.0 - (_pageChangeAnimation.value * 0.1),
                child: AnimatedOpacity(
                  // Используем AnimatedOpacity вместо Opacity
                  opacity: 1.0 -
                      (_pageChangeAnimation.value *
                          0.5), // Ограничиваем минимальную прозрачность до 0.5
                  duration: const Duration(milliseconds: 100),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedDay),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF213E60),
                    ),
                  ),
                ),
              );
            },
          ),

          // Кнопка следующего месяца
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 28),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month + 1,
                  _focusedDay.day,
                );

                // Запускаем анимацию смены страницы
                _pageChangeController.forward(from: 0.0);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridCalendar(NotesProvider notesProvider) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,

      // Устанавливаем понедельник первым днем недели
      startingDayOfWeek: StartingDayOfWeek.monday,

      availableCalendarFormats: const {
        CalendarFormat.month: 'Месяц',
      },
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: _onDaySelected,
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          // Запускаем анимацию смены страницы
          _pageChangeController.forward(from: 0.0);
        });
      },
      eventLoader: _getEventsForDay,

      // Стилизация календаря под "тетрадь в клеточку"
      calendarStyle: const CalendarStyle(
        // Убираем стандартные маркеры
        markersMaxCount: 0,
        cellMargin: EdgeInsets.all(0),
        cellPadding: EdgeInsets.all(5),
        defaultTextStyle: AppTextStyles.bodyMedium,
        weekendTextStyle: TextStyle(color: AppColors.accentPrimary),
        selectedTextStyle: TextStyle(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.bold,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.accentSecondary,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.bold,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.accentPrimary,
          shape: BoxShape.circle,
        ),
      ),

      // Стилизация заголовков дней недели
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.bold,
        ),
        weekendStyle: TextStyle(
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Полностью скрываем встроенный заголовок календаря
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: false,
        leftChevronVisible: false,
        rightChevronVisible: false,
        titleTextStyle: TextStyle(fontSize: 0),
        headerPadding: EdgeInsets.zero,
        headerMargin: EdgeInsets.zero,
      ),

      // Кастомный билдер для ячеек календаря
      calendarBuilders: CalendarBuilders(
        // Скрываем заголовок встроенного календаря
        headerTitleBuilder: (context, day) {
          return const SizedBox.shrink();
        },

        defaultBuilder: (context, day, focusedDay) {
          return _buildCalendarCell(day, notesProvider, isSelected: false);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildCalendarCell(day, notesProvider, isSelected: true);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildCalendarCell(day, notesProvider, isToday: true);
        },
        outsideBuilder: (context, day, focusedDay) {
          return _buildCalendarCell(day, notesProvider, isOutside: true);
        },
      ),
    );
  }

  Widget _buildCalendarCell(
    DateTime day,
    NotesProvider notesProvider, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    // Нормализуем дату (без времени)
    final normalizedDay = DateTime(day.year, day.month, day.day);

    // Получаем список заметок для этого дня
    final events = _getEventsForDay(normalizedDay);

    // Определяем цвет фона ячейки в зависимости от количества заметок (тепловая карта)
    final heatmapColor = _getHeatmapColor(normalizedDay, events.length);

    // Проверяем, является ли день выходным (суббота = 6, воскресенье = 7 или 0)
    final isWeekend = day.weekday == 6 || day.weekday == 7 || day.weekday == 0;

    // Определяем цвет текста для дня
    final dayTextColor = isOutside
        ? Colors.grey.withOpacity(0.5)
        : isSelected
            ? Colors.white
            : isToday
                ? Colors.white
                : isWeekend
                    ? Colors.white
                    : isWeekend
                        ? AppColors.accentPrimary // Рыжий цвет для выходных
                        : AppColors.textOnDark;

    return Stack(
      children: [
        // Фон ячейки
        CustomPaint(
          painter: GridCellPainter(
            isSelected: isSelected,
            isToday: isToday,
            isOutside: isOutside,
            heatmapColor: heatmapColor,
          ),
          child: Container(),
        ),

        // L-образный уголок с числом дня в правом верхнем углу
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 23, // Размер L-образного уголка
            height: 20,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isOutside
                      ? Colors.grey.withOpacity(0.4)
                      : isSelected || isToday
                          ? Colors.white.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                  width: isSelected || isToday ? 1.0 : 0.5,
                ),
                bottom: BorderSide(
                  color: isOutside
                      ? Colors.grey.withOpacity(0.4)
                      : isSelected || isToday
                          ? Colors.white.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                  width: isSelected || isToday ? 1.0 : 0.5,
                ),
              ),
            ),
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, top: 2),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                color: dayTextColor,
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),

        // Отображение индикаторов заметок (сгруппированных по темам)
        if (events.isNotEmpty)
          Positioned(
            bottom: 4,
            left: 4,
            child: _buildDayIndicatorsGroupedByThemes(context, events),
          ),
      ],
    );
  }

  // счетчики под календарем - уменьшены на 60% (35% + 25%) по высоте
  Widget _buildMonthStats() {
    final notesProvider = Provider.of<NotesProvider>(context);
    final notes = notesProvider.notes;

    // Фильтруем заметки по текущему месяцу
    final currentMonthNotes = notes.where((note) {
      return note.createdAt.year == _focusedDay.year &&
          note.createdAt.month == _focusedDay.month;
    }).toList();

    // Считаем количество задач с дедлайнами
    final tasksNotes =
        currentMonthNotes.where((note) => note.hasDeadline).toList();

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 2), // Уменьшено с 4 до 2
      height: 48, // Явно задаем высоту контейнера
      child: Row(
        children: [
          // Все заметки месяца - стильная карточка (уменьшенная на 60% по высоте)
          Expanded(
            child: Card(
              margin: EdgeInsets.zero, // Убираем отступ карточки
              elevation: 2, // Уменьшена тень
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12), // Уменьшен радиус скругления
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 6), // Уменьшено с 10,8 до 6,6
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentSecondary.withOpacity(0.8),
                      AppColors.accentSecondary.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(12), // Уменьшен радиус скругления
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20, // Уменьшено с 26 до 20
                      height: 20, // Уменьшено с 26 до 20
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.note_alt,
                        color: Colors.white,
                        size: 12, // Уменьшено с 14 до 12
                      ),
                    ),
                    SizedBox(width: 6), // Уменьшено с 8 до 6
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentMonthNotes.length.toString(),
                          style: TextStyle(
                            fontSize: 14, // Уменьшено с 16 до 14
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'in this month',
                          style: TextStyle(
                            fontSize: 10, // Уменьшено с 12 до 10
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(width: 6), // Уменьшено с 8 до 6

          // Задачи с дедлайном - стильная карточка (уменьшенная на 60% по высоте)
          Expanded(
            child: InkWell(
              onTap: () {
                // Переход на экран со списком задач с дедлайнами
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeadlinesScreen(),
                  ),
                ).then((_) {
                  // Обновляем данные после возврата
                  if (mounted) {
                    _loadData();
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                margin: EdgeInsets.zero, // Убираем отступ карточки
                elevation: 2, // Уменьшена тень
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12), // Уменьшен радиус скругления
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6, horizontal: 6), // Уменьшено с 10,8 до 6,6
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 121, 158, 73).withOpacity(0.8),
                        Color.fromARGB(255, 121, 158, 73).withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(12), // Уменьшен радиус скругления
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20, // Уменьшено с 26 до 20
                        height: 20, // Уменьшено с 26 до 20
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: 12, // Уменьшено с 14 до 12
                        ),
                      ),
                      SizedBox(width: 6), // Уменьшено с 8 до 6
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tasksNotes.length.toString(),
                            style: TextStyle(
                              fontSize: 14, // Уменьшено с 16 до 14
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Deadlines',
                            style: TextStyle(
                              fontSize: 10, // Уменьшено с 12 до 10
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Виджет для отображения "пустого" состояния выбранной даты
  Widget _buildEmptyDateView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_note,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет заметок на ${DateFormat('d MMMM yyyy').format(_selectedDay)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте заметку, чтобы она появилась здесь',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF213E60),
            ),
            textAlign: TextAlign.center,
          ),
          // Кнопка "Создать заметку" удалена, т.к. дублирует функционал кнопки "+"
        ],
      ),
    );
  }

  // метод для открытия деталей заметки
  void _viewNoteDetails(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) {
      _loadData();
    });
  }

  // Плавающая кнопка добавления заметки
  Widget _buildAddNoteButton() {
    return FloatingActionButton(
      heroTag: 'calendarAddNote',
      backgroundColor: AppColors.accentSecondary,
      onPressed: () {
        _showAddNoteWithDate(_selectedDay);
      },
      child: const Icon(
        Icons.add,
        color: Colors.white,
      ),
    );
  }

  // Метод для показа диалога добавления заметки
  void _showAddNoteWithDate(DateTime date) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteDetailScreen(initialDate: date),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeOutQuint;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppAnimations.mediumDuration,
      ),
    ).then((_) {
      // После возврата с экрана добавления заметки, обновляем события
      if (mounted) {
        final notesProvider =
            Provider.of<NotesProvider>(context, listen: false);
        // Загружаем заметки без обновления UI
        notesProvider.loadNotes().then((_) {
          if (mounted) {
            _processEventsWithoutUpdate(notesProvider.notes);
            setState(() {
              _selectedEvents = _getEventsForDay(_selectedDay);
            });
          }
        });
      }
    });
  }
}

class SelectedDayNotesList extends StatefulWidget {
  final DateTime selectedDay;
  final List<Note> notes;

  const SelectedDayNotesList({
    Key? key,
    required this.selectedDay,
    required this.notes,
  }) : super(key: key);

  @override
  State<SelectedDayNotesList> createState() => _SelectedDayNotesListState();
}

class _SelectedDayNotesListState extends State<SelectedDayNotesList> {
  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) {
      // Оставляем существующую реализацию для пустого состояния
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_note,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет заметок на ${DateFormat('d MMMM yyyy').format(widget.selectedDay)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Создайте заметку, чтобы она появилась здесь',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF213E60),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с количеством заметок
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Заметки на ${DateFormat('d MMMM').format(widget.selectedDay)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.notes.length}',
                  style: const TextStyle(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Используем обновленный NoteListWidget
        Expanded(
          child: NoteListWidget(
            key: PageStorageKey<String>(
                'notes_for_${widget.selectedDay.toString()}'),
            notes: widget.notes,
            emptyMessage: 'Нет заметок на выбранный день',
            showThemeBadges: true,
            useCachedAnimation: false,
            onNoteTap: (note) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(note: note),
              ),
            ),
            // Убираем вызов полного обновления
            onNoteDeleted: (note) async {
              final notesProvider =
                  Provider.of<NotesProvider>(context, listen: false);
              await notesProvider.deleteNote(note.id);
              // Не вызываем метод _refreshNotes(), так как обновление происходит локально
            },
            onNoteFavoriteToggled: (note) async {
              // Обработка переключения избранного теперь происходит внутри NoteListWidget
              // и не требует внешнего обновления
            },
          ),
        ),
      ],
    );
  }
}

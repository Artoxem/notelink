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
import 'unthemed_notes_screen.dart';

// Класс для адаптивных размеров в зависимости от размера экрана
class ResponsiveValues {
  final BuildContext context;

  ResponsiveValues(this.context);

  // Проверка на маленький экран
  bool get isSmallScreen {
    final height = MediaQuery.of(context).size.height;
    return height < 600;
  }

  // Высота календаря
  double get calendarHeight => isSmallScreen ? 320.0 : 360.0;

  // Высота статистики
  double get statsHeight => isSmallScreen ? 40.0 : 50.0;

  // Высота переключателя сворачивания
  double get toggleHeight => 24.0;

  // Отступы
  double get horizontalPadding => MediaQuery.of(context).size.width * 0.04;
  double get itemSpacing => MediaQuery.of(context).size.width * 0.015;

  // Размеры шрифтов
  double get primaryFontSize => isSmallScreen ? 12.0 : 14.0;
  double get secondaryFontSize => isSmallScreen ? 9.0 : 10.0;

  // Вертикальные отступы
  double get verticalPadding => isSmallScreen ? 4.0 : 6.0;
  double get horizontalPadding2 => isSmallScreen ? 4.0 : 6.0;

  // Размеры иконок
  double get iconSize => isSmallScreen ? 16.0 : 20.0;
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
  // Переменные состояния
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

    // Добавляем слушателя для обновления данных при изменении NotesProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      notesProvider.addListener(_onNotesChanged);
    });
  }

  @override
  void dispose() {
    // Отписываемся от слушателя NotesProvider
    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      notesProvider.removeListener(_onNotesChanged);
    } catch (e) {
      // Игнорируем ошибки при закрытии экрана
    }

    _pageChangeController.dispose();
    super.dispose();
  }

  // Обработчик изменений в NotesProvider
  void _onNotesChanged() {
    if (mounted) {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      setState(() {
        _processEvents(notesProvider.notes);
        _selectedEvents = _getEventsForDay(_selectedDay);
      });
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем заметки и темы
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);

      // Принудительно загружаем данные из базы данных
      await notesProvider.loadNotes(force: true);
      await themesProvider.loadThemes();

      if (!mounted) return;

      setState(() {
        _processEvents(notesProvider.notes);
        _selectedEvents = _getEventsForDay(_selectedDay);
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Показываем сообщение об ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _loadData,
            ),
          ),
        );
      }
    }
  }

  void _processEvents(List<Note> notes) {
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

    _events = events;
    _selectedEvents = _getEventsForDay(_selectedDay);
  }

  // Вынесем метод получения событий для дня в отдельную функцию с обработкой ошибок
  List<Note> _getEventsForDay(DateTime day) {
    try {
      // Нормализуем дату (без времени) для корректного сравнения
      final normalizedDay = DateTime(day.year, day.month, day.day);

      // Безопасно возвращаем события или пустой список, если их нет
      final events = _events[normalizedDay];
      if (events == null) {
        return [];
      }

      // Возвращаем копию списка для предотвращения случайных модификаций
      return List<Note>.from(events);
    } catch (e) {
      print('Ошибка при получении событий для дня: $e');
      return []; // Возвращаем пустой список в случае ошибки
    }
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
    // Получаем адаптивные значения
    final responsive = ResponsiveValues(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Анимируемый контейнер с календарем и статистикой
                AnimatedContainer(
                  duration: AppAnimations.mediumDuration,
                  curve: Curves.easeInOut,
                  height: _isCalendarExpanded
                      ? responsive.calendarHeight + responsive.statsHeight
                      : 0,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Календарь
                        SizedBox(
                          height: responsive.calendarHeight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Заголовок месяца
                              _buildMonthHeader(),
                              // Календарь с автоматическим обновлением
                              Expanded(
                                child: Consumer<NotesProvider>(
                                  builder: (context, notesProvider, _) {
                                    // Обновляем события при изменении данных в провайдере
                                    _processEvents(notesProvider.notes);
                                    _selectedEvents =
                                        _getEventsForDay(_selectedDay);
                                    return _buildGridCalendar(notesProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Счетчики месяца
                        SizedBox(
                          height: responsive.statsHeight,
                          child: _buildMonthStats(responsive),
                        ),
                      ],
                    ),
                  ),
                ),

                // Кнопка свертывания/развертывания
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCalendarExpanded = !_isCalendarExpanded;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: responsive.toggleHeight,
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
                ),

                // Заголовок с заметками для выбранного дня
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.horizontalPadding,
                    vertical: responsive.verticalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Заметки на ${DateFormat('d MMMM').format(_selectedDay)}',
                        style: TextStyle(
                            fontSize: responsive.isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: responsive.isSmallScreen ? 6 : 8,
                            vertical: responsive.isSmallScreen ? 1 : 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedEvents.length}',
                          style: TextStyle(
                            fontSize: responsive.isSmallScreen ? 12 : 14,
                            color: AppColors.accentSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Список заметок для выбранного дня
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Consumer<NotesProvider>(
                          builder: (context, notesProvider, _) {
                            // Обновляем выбранные события при изменении данных
                            _selectedEvents = _getEventsForDay(_selectedDay);
                            final noteListKey = ValueKey<String>(
                                'notes_for_${_selectedDay.toString()}_${notesProvider.notes.length}');

                            return _selectedEvents.isEmpty
                                ? _buildEmptyDateView()
                                : NoteListWidget(
                                    key: noteListKey,
                                    notes: _selectedEvents,
                                    emptyMessage:
                                        'Нет заметок на выбранный день',
                                    showThemeBadges: true,
                                    useCachedAnimation: false,
                                    swipeDirection: SwipeDirection.both,
                                    onNoteTap: _viewNoteDetails,
                                    onNoteDeleted: (note) async {
                                      await notesProvider.deleteNote(note.id);

                                      if (mounted) {
                                        setState(() {
                                          _processEvents(notesProvider.notes);
                                          _selectedEvents =
                                              _getEventsForDay(_selectedDay);
                                        });
                                      }
                                    },
                                  );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildAddNoteButton(),
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF213E60),
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

  // Адаптивные счетчики под календарем
  Widget _buildMonthStats(ResponsiveValues responsive) {
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

    // Считаем количество заметок без темы
    final unthemedNotes =
        currentMonthNotes.where((note) => note.themeIds.isEmpty).toList();

    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: responsive.horizontalPadding,
          vertical: responsive.isSmallScreen ? 1.0 : 2.0),
      height: responsive.isSmallScreen ? 35.0 : 40.0, // Фиксированная высота
      child: Row(
        children: [
          // Все заметки месяца - стильная карточка с адаптивными размерами
          Expanded(
            child: Card(
              margin: EdgeInsets.zero, // Убираем отступ карточки
              elevation: 2, // Уменьшена тень
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                    vertical: responsive.verticalPadding,
                    horizontal: responsive.horizontalPadding2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentSecondary.withOpacity(0.8),
                      AppColors.accentSecondary.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: responsive.iconSize,
                      height: responsive.iconSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.note_alt,
                        color: Colors.white,
                        size: responsive.iconSize * 0.6,
                      ),
                    ),
                    SizedBox(width: responsive.itemSpacing),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentMonthNotes.length.toString(),
                          style: TextStyle(
                            fontSize: responsive.primaryFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'в этом месяце',
                          style: TextStyle(
                            fontSize: responsive.secondaryFontSize,
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

          SizedBox(width: responsive.itemSpacing),

          // Заметки без темы - адаптивная карточка
          Expanded(
            child: InkWell(
              onTap: () {
                // Переходим на экран заметок без темы
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnthemedNotesScreen(),
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
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      vertical: responsive.verticalPadding,
                      horizontal: responsive.horizontalPadding2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 150, 150, 150).withOpacity(0.8),
                        Color.fromARGB(255, 150, 150, 150).withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: responsive.iconSize,
                        height: responsive.iconSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.layers_clear,
                          color: Colors.white,
                          size: responsive.iconSize * 0.6,
                        ),
                      ),
                      SizedBox(width: responsive.itemSpacing),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            unthemedNotes.length.toString(),
                            style: TextStyle(
                              fontSize: responsive.primaryFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Без темы',
                            style: TextStyle(
                              fontSize: responsive.secondaryFontSize,
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

          SizedBox(width: responsive.itemSpacing),

          // Задачи с дедлайном - адаптивная карточка
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
                margin: EdgeInsets.zero,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      vertical: responsive.verticalPadding,
                      horizontal: responsive.horizontalPadding2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 121, 158, 73).withOpacity(0.8),
                        Color.fromARGB(255, 121, 158, 73).withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: responsive.iconSize,
                        height: responsive.iconSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timer,
                          color: Colors.white,
                          size: responsive.iconSize * 0.6,
                        ),
                      ),
                      SizedBox(width: responsive.itemSpacing),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tasksNotes.length.toString(),
                            style: TextStyle(
                              fontSize: responsive.primaryFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Дедлайны',
                            style: TextStyle(
                              fontSize: responsive.secondaryFontSize,
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
      // После возврата принудительно обновляем данные
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
    ).then((_) async {
      // После возврата с экрана создания заметки, обновляем данные
      if (mounted) {
        // Сначала перезагружаем данные
        await _loadData();

        // Добавляем небольшую задержку для гарантии получения данных из БД
        await Future.delayed(const Duration(milliseconds: 100));

        // Затем обновляем UI и список выбранных заметок
        setState(() {
          // Обновляем список выбранных заметок для текущей даты
          final notesProvider =
              Provider.of<NotesProvider>(context, listen: false);
          _processEvents(notesProvider.notes);
          _selectedEvents = _getEventsForDay(_selectedDay);
        });
      }
    });
  }
}

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

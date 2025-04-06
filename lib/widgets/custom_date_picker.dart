import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import 'package:intl/intl.dart';

/// Кастомный виджет для выбора даты
class CustomDatePicker extends StatefulWidget {
  /// Начальная дата
  final DateTime initialDate;

  /// Callback при выборе даты
  final ValueChanged<DateTime>? onDateChanged;

  /// Минимальная дата для выбора
  final DateTime? firstDate;

  /// Максимальная дата для выбора
  final DateTime? lastDate;

  /// Формат отображения даты
  final DateFormat? dateFormat;

  /// Показывать ли быстрые кнопки выбора
  final bool showQuickButtons;

  const CustomDatePicker({
    Key? key,
    required this.initialDate,
    this.onDateChanged,
    this.firstDate,
    this.lastDate,
    this.dateFormat,
    this.showQuickButtons = true,
  }) : super(key: key);

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  late DateTime _selectedDate;
  late DateFormat _dateFormat;

  // Список дней недели для российской локализации
  final List<String> _weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  // Список месяцев для российской локализации
  final List<String> _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь'
  ];

  // Номер месяца в году (1-12)
  int _currentMonth = 0;

  // Текущий год
  int _currentYear = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _dateFormat = widget.dateFormat ?? DateFormat('dd.MM.yyyy');

    _currentMonth = _selectedDate.month;
    _currentYear = _selectedDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        boxShadow: [AppShadows.small],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _showPreviousMonth,
                ),
                GestureDetector(
                  onTap: () => _showYearPicker(context),
                  child: Text(
                    '${_monthNames[_currentMonth - 1]} $_currentYear',
                    style: AppTextStyles.heading3,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _showNextMonth,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Дни недели
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                // Выделяем выходные дни
                final isWeekend = index >= 5;

                return SizedBox(
                  width: 36,
                  child: Text(
                    _weekdayNames[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isWeekend
                          ? AppColors.accentSecondary
                          : AppColors.textOnLight,
                    ),
                  ),
                );
              }),
            ),
          ),

          // Календарь
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildCalendarGrid(),
          ),

          // Быстрые кнопки выбора даты
          if (widget.showQuickButtons) _buildQuickDateButtons(),

          const Divider(height: 1),

          // Кнопки управления
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Отмена',
                    style: TextStyle(color: AppColors.textOnLight),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (widget.onDateChanged != null) {
                      widget.onDateChanged!(_selectedDate);
                    }
                    Navigator.of(context).pop(_selectedDate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                  ),
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Строит сетку календаря для текущего месяца
  Widget _buildCalendarGrid() {
    // Получаем первый день месяца
    final firstDayOfMonth = DateTime(_currentYear, _currentMonth, 1);

    // День недели первого дня месяца (0 - понедельник, 6 - воскресенье)
    int firstWeekday = firstDayOfMonth.weekday - 1;

    // Количество дней в текущем месяце
    final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;

    // Количество строк в сетке календаря
    final numRows = ((daysInMonth + firstWeekday) / 7).ceil();

    return Table(
      children: List.generate(numRows, (row) {
        return TableRow(
          children: List.generate(7, (col) {
            final index = row * 7 + col;
            final dayOffset = index - firstWeekday;

            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              // Пустая ячейка (предыдущий/следующий месяц)
              return const SizedBox(height: 36);
            }

            final day = dayOffset + 1;
            final date = DateTime(_currentYear, _currentMonth, day);

            // Проверяем ограничения на минимальную и максимальную даты
            final bool disabled = (widget.firstDate != null &&
                    date.isBefore(widget.firstDate!)) ||
                (widget.lastDate != null && date.isAfter(widget.lastDate!));

            // Проверяем выбрана ли текущая дата
            final bool isSelected = date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;

            // Проверяем является ли текущая дата сегодняшней
            final bool isToday = date.isToday;

            return _buildCalendarCell(day, isSelected, isToday, disabled, date);
          }),
        );
      }),
    );
  }

  /// Строит ячейку календаря для конкретного дня
  Widget _buildCalendarCell(
      int day, bool isSelected, bool isToday, bool disabled, DateTime date) {
    // Выходной день (суббота или воскресенье)
    final bool isWeekend = date.weekday >= 6;

    // Определяем цвета в зависимости от состояния
    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = AppColors.accentPrimary;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = AppColors.accentPrimary.withOpacity(0.1);
      textColor = AppColors.accentPrimary;
    } else if (disabled) {
      backgroundColor = Colors.transparent;
      textColor = AppColors.textOnLight.withOpacity(0.3);
    } else if (isWeekend) {
      backgroundColor = Colors.transparent;
      textColor = AppColors.accentSecondary;
    } else {
      backgroundColor = Colors.transparent;
      textColor = AppColors.textOnLight;
    }

    return InkWell(
      onTap: disabled ? null : () => _selectDate(date),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          day.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight:
                isSelected || isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Строит кнопки быстрого выбора дат
  Widget _buildQuickDateButtons() {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          _buildQuickDateButton('Сегодня', now),
          _buildQuickDateButton('Завтра', now.add(const Duration(days: 1))),
          _buildQuickDateButton(
              'Через неделю', now.add(const Duration(days: 7))),
          _buildQuickDateButton(
              'Через месяц', DateTime(now.year, now.month + 1, now.day)),
        ],
      ),
    );
  }

  /// Строит кнопку быстрого выбора даты
  Widget _buildQuickDateButton(String label, DateTime date) {
    // Проверяем ограничения на минимальную и максимальную даты
    final bool disabled =
        (widget.firstDate != null && date.isBefore(widget.firstDate!)) ||
            (widget.lastDate != null && date.isAfter(widget.lastDate!));

    return InkWell(
      onTap: disabled ? null : () => _selectDate(date),
      borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.withOpacity(0.1)
              : AppColors.accentPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
          border: Border.all(
            color: disabled
                ? Colors.grey.withOpacity(0.3)
                : AppColors.accentPrimary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled ? Colors.grey : AppColors.accentPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Показывает диалог выбора года
  void _showYearPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите год'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 16, // показываем 16 лет (4x4)
              itemBuilder: (context, index) {
                final int year = DateTime.now().year - 3 + index;
                final bool isSelected = year == _currentYear;

                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _currentYear = year;
                    });
                  },
                  borderRadius:
                      BorderRadius.circular(AppDimens.smallBorderRadius),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.accentPrimary.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimens.smallBorderRadius),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      year.toString(),
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textOnLight,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Выбирает конкретную дату
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _currentMonth = date.month;
      _currentYear = date.year;
    });

    if (widget.onDateChanged != null) {
      widget.onDateChanged!(_selectedDate);
    }
  }

  /// Показывает предыдущий месяц
  void _showPreviousMonth() {
    setState(() {
      if (_currentMonth > 1) {
        _currentMonth--;
      } else {
        _currentMonth = 12;
        _currentYear--;
      }
    });
  }

  /// Показывает следующий месяц
  void _showNextMonth() {
    setState(() {
      if (_currentMonth < 12) {
        _currentMonth++;
      } else {
        _currentMonth = 1;
        _currentYear++;
      }
    });
  }
}

/// Статический класс для показа диалога выбора даты
class DatePickerDialog {
  /// Показывает диалог выбора даты
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    DateFormat? dateFormat,
    bool showQuickButtons = true,
  }) async {
    initialDate ??= DateTime.now();
    firstDate ??= DateTime(2020);
    lastDate ??= DateTime(2030);

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
          ),
          child: CustomDatePicker(
            initialDate: initialDate!,
            firstDate: firstDate,
            lastDate: lastDate,
            dateFormat: dateFormat,
            showQuickButtons: showQuickButtons,
          ),
        );
      },
    );
  }
}

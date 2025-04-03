import 'package:flutter/material.dart';
import '../models/note.dart';
import 'enhanced_reminder_widget.dart';
import '../utils/constants.dart';

class ReminderSettingsSection extends StatefulWidget {
  final List<DateTime>? reminderDates;
  final String? reminderSound;
  final DateTime deadlineDate;
  final bool hasReminders;
  final Function(bool hasReminders, List<DateTime> dates, String sound,
      {bool isRelativeTimeActive,
      int? relativeMinutes,
      String? relativeDescription}) onRemindersChanged;

  const ReminderSettingsSection({
    Key? key,
    this.reminderDates,
    this.reminderSound,
    required this.deadlineDate,
    required this.hasReminders,
    required this.onRemindersChanged,
  }) : super(key: key);

  @override
  State<ReminderSettingsSection> createState() =>
      _ReminderSettingsSectionState();
}

class _ReminderSettingsSectionState extends State<ReminderSettingsSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.hasReminders;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Переключатель напоминаний
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Напоминания',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          value: widget.hasReminders,
          activeColor: AppColors.accentSecondary,
          onChanged: (value) {
            if (!value) {
              // Если отключаем напоминания
              widget.onRemindersChanged(false, [], 'default');
            } else {
              // Если включаем напоминания - разворачиваем панель
              setState(() {
                _expanded = true;
              });
              if (widget.reminderDates == null ||
                  widget.reminderDates!.isEmpty) {
                // Создаем напоминание по умолчанию
                final defaultDate =
                    widget.deadlineDate.subtract(const Duration(days: 1));
                final now = DateTime.now();
                final reminderDate = defaultDate.isAfter(now)
                    ? defaultDate
                    : now.add(const Duration(hours: 1));

                widget.onRemindersChanged(true, [reminderDate], 'default');
              } else {
                widget.onRemindersChanged(true, widget.reminderDates!,
                    widget.reminderSound ?? 'default');
              }
            }
          },
          subtitle: !_expanded && widget.hasReminders
              ? _buildReminderSummary()
              : null,
        ),

        // Виджет расширенных настроек (появляется после активации)
        if (widget.hasReminders && _expanded)
          Column(
            children: [
              const SizedBox(height: 8),
              EnhancedReminderWidget(
                reminderDates: widget.reminderDates ?? [],
                reminderSound: widget.reminderSound,
                deadlineDate: widget.deadlineDate,
                onRemindersChanged: (
                  dates,
                  sound, {
                  isRelativeTimeActive = false,
                  relativeMinutes,
                  relativeDescription,
                }) {
                  widget.onRemindersChanged(
                    true,
                    dates,
                    sound,
                    isRelativeTimeActive: isRelativeTimeActive,
                    relativeMinutes: relativeMinutes,
                    relativeDescription: relativeDescription,
                  );
                },
              ),

              // Кнопка сворачивания панели
              TextButton(
                onPressed: () {
                  setState(() {
                    _expanded = false;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_upward, size: 14),
                    SizedBox(width: 4),
                    Text('Свернуть', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

        // Кнопка развертывания панели
        if (widget.hasReminders && !_expanded)
          TextButton(
            onPressed: () {
              setState(() {
                _expanded = true;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_downward, size: 14),
                SizedBox(width: 4),
                Text('Настроить', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  // Виджет для краткого отображения настроек напоминаний
  Widget _buildReminderSummary() {
    if (widget.reminderDates == null || widget.reminderDates!.isEmpty) {
      return const Text('Нет активных напоминаний',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));
    }

    final DateTime reminderDate = widget.reminderDates!.first;

    if (reminderDate.isBefore(DateTime.now())) {
      return const Text('Время напоминания уже прошло',
          style: TextStyle(fontSize: 12, color: Colors.red));
    }

    // Определяем, относительное это напоминание или точное
    final Duration difference = widget.deadlineDate.difference(reminderDate);
    final int minutesBeforeDeadline = difference.inMinutes;

    if (minutesBeforeDeadline == 5) return const Text('За 5 минут до дедлайна');
    if (minutesBeforeDeadline == 15)
      return const Text('За 15 минут до дедлайна');
    if (minutesBeforeDeadline == 30)
      return const Text('За 30 минут до дедлайна');
    if (minutesBeforeDeadline == 60) return const Text('За 1 час до дедлайна');
    if (minutesBeforeDeadline == 180)
      return const Text('За 3 часа до дедлайна');
    if (minutesBeforeDeadline == 1440)
      return const Text('За 1 день до дедлайна');
    if (minutesBeforeDeadline == 2880)
      return const Text('За 2 дня до дедлайна');
    if (minutesBeforeDeadline == 10080)
      return const Text('За 1 неделю до дедлайна');

    // Если не подходит ни один предустановленный интервал, отображаем точную дату
    return Text('${_formatDate(reminderDate)} (${_formatTime(reminderDate)})',
        style: const TextStyle(fontSize: 12));
  }

  // Форматирование даты
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Форматирование времени
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';

class ReminderSettingsWidget extends StatefulWidget {
  final List<DateTime> reminderDates;
  final String? reminderSound;
  final DateTime deadlineDate;
  final Function(List<DateTime> dates, String sound) onRemindersChanged;

  const ReminderSettingsWidget({
    Key? key,
    required this.reminderDates,
    this.reminderSound,
    required this.deadlineDate,
    required this.onRemindersChanged,
  }) : super(key: key);

  @override
  State<ReminderSettingsWidget> createState() => _ReminderSettingsWidgetState();
}

class _ReminderSettingsWidgetState extends State<ReminderSettingsWidget> {
  late List<DateTime> _reminderDates;
  String _selectedSound = 'default';
  final NotificationService _notificationService = NotificationService();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _reminderDates = List<DateTime>.from(widget.reminderDates);
    _selectedSound = widget.reminderSound ?? 'default';

    // Если список пуст, добавим одно напоминание по умолчанию за день до дедлайна
    if (_reminderDates.isEmpty) {
      _addDefaultReminder();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Безопасное обновление состояния с проверкой
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  // Добавление напоминания по умолчанию
  void _addDefaultReminder() {
    // Создаем напоминание за день до дедлайна
    final defaultReminderDate =
        widget.deadlineDate.subtract(const Duration(days: 1));
    // Если дата уже прошла, создаем напоминание на час после текущего времени
    final now = DateTime.now();
    final reminderDate = defaultReminderDate.isAfter(now)
        ? defaultReminderDate
        : now.add(const Duration(hours: 1));

    _safeSetState(() {
      _reminderDates.add(reminderDate);
    });

    // Уведомляем родительский виджет
    widget.onRemindersChanged(_reminderDates, _selectedSound);
  }

  // Добавление нового напоминания
  void _addReminder() async {
    // Получаем текущую дату и время
    final now = DateTime.now();

    // Выбираем подходящую начальную дату
    DateTime initialDate = now.add(const Duration(hours: 1));
    if (initialDate.isAfter(widget.deadlineDate)) {
      initialDate = now;
    }

    // Показываем диалог выбора даты
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: widget.deadlineDate,
      locale: const Locale('ru', 'RU'),
    );

    if (selectedDate == null || !mounted) return;

    // Показываем диалог выбора времени
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (selectedTime == null || !mounted) return;

    // Комбинируем дату и время
    final DateTime reminderDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Проверяем, что выбранная дата находится в будущем
    if (reminderDateTime.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дата напоминания должна быть в будущем')),
      );
      return;
    }

    // Добавляем напоминание в список
    _safeSetState(() {
      _reminderDates.add(reminderDateTime);
      // Сортируем по времени
      _reminderDates.sort();
    });

    // Уведомляем родительский виджет
    if (mounted) {
      widget.onRemindersChanged(_reminderDates, _selectedSound);
    }
  }

  // Удаление напоминания
  void _removeReminder(int index) {
    if (index >= 0 && index < _reminderDates.length) {
      _safeSetState(() {
        _reminderDates.removeAt(index);
      });

      // Уведомляем родительский виджет
      widget.onRemindersChanged(_reminderDates, _selectedSound);
    }
  }

  // Изменение звука напоминания
  void _changeSound(String sound) {
    _safeSetState(() {
      _selectedSound = sound;
    });

    // Уведомляем родительский виджет
    widget.onRemindersChanged(_reminderDates, _selectedSound);
  }

  // Форматирование даты напоминания
  String _formatReminderDate(DateTime date) {
    // Получаем текущую дату
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOfReminder = DateTime(date.year, date.month, date.day);

    String dateFormat;
    if (dateOfReminder.isAtSameMomentAs(today)) {
      dateFormat = 'Сегодня';
    } else if (dateOfReminder.isAtSameMomentAs(tomorrow)) {
      dateFormat = 'Завтра';
    } else {
      dateFormat = DateFormat('dd.MM.yyyy').format(date);
    }

    // Добавляем время
    final timeFormat = DateFormat('HH:mm').format(date);

    return '$dateFormat, $timeFormat';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> availableSounds =
        _notificationService.getAvailableSounds();

    // Словарь с локализованными названиями звуков
    final soundNames = {
      'default': 'По умолчанию',
      'alert': 'Сигнал',
      'bell': 'Колокольчик',
      'chime': 'Мелодия',
      'urgent': 'Срочный',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        const Text(
          'Напоминания:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),

        // Список существующих напоминаний
        if (_reminderDates.isNotEmpty)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              _reminderDates.length,
              (index) {
                if (index >= _reminderDates.length) {
                  return const SizedBox.shrink(); // Защита от ошибок индексации
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: AppColors.textBackground.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatReminderDate(_reminderDates[index]),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          InkWell(
                            onTap: () => _removeReminder(index),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Кнопка добавления нового напоминания
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Добавить напоминание'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 30),
          ),
          onPressed: _addReminder,
        ),

        const SizedBox(height: 8),

        // Выбор звука для напоминаний
        Row(
          children: [
            const Text('Звук:', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedSound,
                isExpanded: true,
                underline: Container(
                  height: 1,
                  color: AppColors.secondary.withOpacity(0.5),
                ),
                onChanged: (newValue) {
                  if (newValue != null && mounted) {
                    _changeSound(newValue);
                  }
                },
                items: availableSounds
                    .map<DropdownMenuItem<String>>((String sound) {
                  return DropdownMenuItem<String>(
                    value: sound,
                    child: Text(
                      soundNames[sound] ?? sound,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

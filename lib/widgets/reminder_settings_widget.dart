import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReminderSettingsWidget extends StatefulWidget {
  final List<DateTime> reminderDates;
  final String? reminderSound;
  final DateTime deadlineDate;
  final Function(List<DateTime> dates, String sound,
      {bool isRelativeTimeActive,
      int? relativeMinutes,
      String? relativeDescription}) onRemindersChanged;

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

  // Добавляем новые поля для определения активного типа напоминания
  bool _isExactTimeActive = true; // По умолчанию активно точное время
  bool _isRelativeTimeActive = false;

  // Аудиоплеер для прослушивания мелодий
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Относительные варианты напоминаний (названия и значения)
  final List<Map<String, dynamic>> _relativeOptions = [
    {'title': 'За 5 минут', 'minutes': 5},
    {'title': 'За 30 минут', 'minutes': 30},
    {'title': 'За 1 час', 'minutes': 60},
    {'title': 'За 3 часа', 'minutes': 180},
    {'title': 'За 1 день', 'minutes': 1440},
    {'title': 'За 2 дня', 'minutes': 2880},
    {'title': 'За 1 неделю', 'minutes': 10080},
  ];

  // Выбранный относительный вариант
  int _selectedRelativeOptionIndex = 2; // По умолчанию "За 1 час"

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
    _audioPlayer.dispose();
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

  // Добавление нового напоминания с точным временем
  void _addExactTimeReminder() async {
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

    // Активируем режим точного времени
    _safeSetState(() {
      _isExactTimeActive = true;
      _isRelativeTimeActive = false;
      _reminderDates.add(reminderDateTime);
      // Сортируем по времени
      _reminderDates.sort();
    });

    // Уведомляем родительский виджет с указанием, что это точное время
    if (mounted) {
      widget.onRemindersChanged(_reminderDates, _selectedSound,
          isRelativeTimeActive: false);
    }
  }

  // Активация относительного напоминания
  void _activateRelativeReminder(int index) {
    if (index < 0 || index >= _relativeOptions.length) return;

    final relativeOption = _relativeOptions[index];
    final minutes = relativeOption['minutes'] as int;
    final description = relativeOption['title'] as String;

    // Расчитываем дату напоминания относительно дедлайна
    final reminderDateTime =
        widget.deadlineDate.subtract(Duration(minutes: minutes));

    // Проверяем, что напоминание в будущем
    if (reminderDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание должно быть в будущем')),
      );
      return;
    }

    _safeSetState(() {
      _isExactTimeActive = false;
      _isRelativeTimeActive = true;
      _selectedRelativeOptionIndex = index;
      _reminderDates = [
        reminderDateTime
      ]; // Заменяем все напоминания одним относительным
    });

    // Уведомляем родительский виджет с указанием, что это относительное время
    widget.onRemindersChanged(_reminderDates, _selectedSound,
        isRelativeTimeActive: true,
        relativeMinutes: minutes,
        relativeDescription: description);
  }

  // Удаление напоминания
  void _removeReminder(int index) {
    if (index >= 0 && index < _reminderDates.length) {
      _safeSetState(() {
        _reminderDates.removeAt(index);
      });

      // Уведомляем родительский виджет
      widget.onRemindersChanged(_reminderDates, _selectedSound,
          isRelativeTimeActive: _isRelativeTimeActive);
    }
  }

  // Изменение звука напоминания
  void _changeSound(String sound) async {
    _safeSetState(() {
      _selectedSound = sound;
    });

    // Воспроизводим звук, если он не default
    if (sound != 'default') {
      await _playSound(sound);
    }

    // Уведомляем родительский виджет
    if (_isRelativeTimeActive &&
        _selectedRelativeOptionIndex >= 0 &&
        _selectedRelativeOptionIndex < _relativeOptions.length) {
      final relativeOption = _relativeOptions[_selectedRelativeOptionIndex];
      widget.onRemindersChanged(_reminderDates, _selectedSound,
          isRelativeTimeActive: true,
          relativeMinutes: relativeOption['minutes'] as int,
          relativeDescription: relativeOption['title'] as String);
    } else {
      widget.onRemindersChanged(_reminderDates, _selectedSound,
          isRelativeTimeActive: false);
    }
  }

  // Воспроизведение звука
  Future<void> _playSound(String soundName) async {
    try {
      await _audioPlayer.stop();

      // Формируем путь к файлу звука
      String assetPath = 'assets/sounds/reminder/$soundName.m4a';
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.play();
    } catch (e) {
      print('Ошибка при воспроизведении звука: $e');
    }
  }

  // Форматирование даты напоминания
  String _formatReminderDate(DateTime date) {
    // Получаем день недели на русском
    List<String> weekdays = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье'
    ];
    int weekdayIndex =
        date.weekday - 1; // В Dart индексация с 1, поэтому вычитаем 1
    String weekday = weekdays[weekdayIndex];

    // Формируем строку в формате "DD.MM (день недели)"
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ($weekday), ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Получение названия относительного напоминания
  String _getRelativeReminderDescription(DateTime reminderDate) {
    if (_isRelativeTimeActive &&
        _selectedRelativeOptionIndex >= 0 &&
        _selectedRelativeOptionIndex < _relativeOptions.length) {
      return _relativeOptions[_selectedRelativeOptionIndex]['title'];
    }
    return _formatReminderDate(reminderDate);
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
      'clock': 'Clock',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Две колонки для точного и относительного времени
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Левая колонка - точное время
            Expanded(
              child: Opacity(
                opacity: _isExactTimeActive ? 1.0 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок "Точное время"
                    const Text(
                      'Точное время',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Список существующих напоминаний (только при активном режиме точного времени)
                    if (_isExactTimeActive && _reminderDates.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _reminderDates.length,
                          (index) {
                            if (index >= _reminderDates.length) {
                              return const SizedBox
                                  .shrink(); // Защита от ошибок индексации
                            }

                            return GestureDetector(
                              onTap: () {
                                // Активируем режим точного времени при нажатии
                                _safeSetState(() {
                                  _isExactTimeActive = true;
                                  _isRelativeTimeActive = false;
                                });

                                // Уведомляем об изменении типа
                                widget.onRemindersChanged(
                                    _reminderDates, _selectedSound,
                                    isRelativeTimeActive: false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color:
                                      AppColors.textBackground.withOpacity(0.7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.notifications_active,
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatReminderDate(
                                                _reminderDates[index]),
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _removeReminder(index),
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                              ),
                            );
                          },
                        ),
                      ),

                    // Кнопка добавления нового напоминания
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить время'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () {
                        _addExactTimeReminder();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Разделитель между колонками
            const SizedBox(width: 8),

            // Правая колонка - относительное время
            Expanded(
              child: Opacity(
                opacity: _isRelativeTimeActive ? 1.0 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок "Относительное время"
                    const Text(
                      'Относительное время',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Список вариантов относительных напоминаний
                    Column(
                      children: List.generate(
                        _relativeOptions.length,
                        (index) => GestureDetector(
                          onTap: () {
                            _activateRelativeReminder(index);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _isRelativeTimeActive &&
                                      _selectedRelativeOptionIndex == index
                                  ? AppColors.accentSecondary.withOpacity(0.2)
                                  : AppColors.textBackground.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: _isRelativeTimeActive &&
                                      _selectedRelativeOptionIndex == index
                                  ? Border.all(color: AppColors.accentSecondary)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: _isRelativeTimeActive &&
                                          _selectedRelativeOptionIndex == index
                                      ? AppColors.accentSecondary
                                      : AppColors.textOnLight,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _relativeOptions[index]['title'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _isRelativeTimeActive &&
                                            _selectedRelativeOptionIndex ==
                                                index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _isRelativeTimeActive &&
                                            _selectedRelativeOptionIndex ==
                                                index
                                        ? AppColors.accentSecondary
                                        : AppColors.textOnLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

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
                    child: Row(
                      children: [
                        Text(
                          soundNames[sound] ?? sound,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        if (sound != 'default')
                          IconButton(
                            icon:
                                const Icon(Icons.play_circle_outline, size: 20),
                            onPressed: () => _playSound(sound),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                      ],
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

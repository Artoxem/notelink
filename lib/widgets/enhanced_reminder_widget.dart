import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../models/note.dart';
import '../services/notification_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

class EnhancedReminderWidget extends StatefulWidget {
  final List<DateTime> reminderDates;
  final String? reminderSound;
  final DateTime deadlineDate;
  final Function(List<DateTime> dates, String sound,
      {bool isRelativeTimeActive,
      int? relativeMinutes,
      String? relativeDescription}) onRemindersChanged;

  const EnhancedReminderWidget({
    Key? key,
    required this.reminderDates,
    this.reminderSound,
    required this.deadlineDate,
    required this.onRemindersChanged,
  }) : super(key: key);

  @override
  State<EnhancedReminderWidget> createState() => _EnhancedReminderWidgetState();
}

class _EnhancedReminderWidgetState extends State<EnhancedReminderWidget>
    with SingleTickerProviderStateMixin {
  late List<DateTime> _reminderDates;
  String _selectedSound = 'default';
  final NotificationService _notificationService = NotificationService();
  bool _isDisposed = false;

  // Выбранный тип напоминания
  ReminderType _selectedType = ReminderType.exactTime;

  // Точное время
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));

  // Относительное время
  int _selectedRelativeMinutes = 60; // По умолчанию 1 час

  // Повторяющееся напоминание
  int _repeatInterval = 1; // Интервал повторения (в днях)
  bool _isMonday = false;
  bool _isTuesday = false;
  bool _isWednesday = false;
  bool _isThursday = false;
  bool _isFriday = false;
  bool _isSaturday = false;
  bool _isSunday = false;
  RepeatType _repeatType = RepeatType.daily;
  DateTime? _repeatEndDate;

  // Контроллеры для анимации
  late TabController _tabController;
  late TextEditingController _customRelativeController;

  // Относительные варианты напоминаний
  final List<Map<String, dynamic>> _relativeOptions = [
    {'title': 'За 5 минут', 'minutes': 5},
    {'title': 'За 15 минут', 'minutes': 15},
    {'title': 'За 30 минут', 'minutes': 30},
    {'title': 'За 1 час', 'minutes': 60},
    {'title': 'За 3 часа', 'minutes': 180},
    {'title': 'За 1 день', 'minutes': 1440},
    {'title': 'За 2 дня', 'minutes': 2880},
    {'title': 'За 1 неделю', 'minutes': 10080},
    {'title': 'Другое...', 'minutes': -1}, // Для пользовательского ввода
  ];

  // Аудиоплеер для прослушивания звуков
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _reminderDates = List<DateTime>.from(widget.reminderDates);
    _selectedSound = widget.reminderSound ?? 'default';
    _tabController = TabController(length: 3, vsync: this);
    _customRelativeController = TextEditingController(text: '60');

    // Если список пуст, добавляем одно напоминание по умолчанию
    if (_reminderDates.isEmpty) {
      _addDefaultReminder();
    } else {
      // Определяем тип напоминания на основе существующих данных
      _initializeFromExistingReminders();
    }

    // Слушаем изменения вкладок
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedType = ReminderType.exactTime;
              break;
            case 1:
              _selectedType = ReminderType.relativeTime;
              break;
            case 2:
              _selectedType = ReminderType.recurring;
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
    _tabController.dispose();
    _customRelativeController.dispose();
    super.dispose();
  }

  // Безопасное обновление состояния
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  // Инициализация из существующих напоминаний
  void _initializeFromExistingReminders() {
    // Если есть хотя бы одно напоминание
    if (_reminderDates.isNotEmpty) {
      _selectedDateTime = _reminderDates.first;
    }

    // Проверяем тип напоминания
    if (widget.reminderDates.isNotEmpty) {
      if (_selectedType == ReminderType.relativeTime) {
        // Это относительное напоминание
        _tabController.animateTo(1);

        // Ищем соответствующий вариант в предустановленных
        bool found = false;
        for (int i = 0; i < _relativeOptions.length; i++) {
          if (_relativeOptions[i]['minutes'] == _selectedRelativeMinutes) {
            found = true;
            break;
          }
        }

        if (!found && _selectedRelativeMinutes > 0) {
          // Пользовательское значение
          _customRelativeController.text = _selectedRelativeMinutes.toString();
        }
      }
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
      _reminderDates = [reminderDate];
      _selectedDateTime = reminderDate;
    });

    // Уведомляем родительский виджет
    widget.onRemindersChanged(_reminderDates, _selectedSound);
  }

  // Добавление точного напоминания
  void _addExactTimeReminder() async {
    final DateTime currentDateTime = _selectedDateTime;

    // Проверяем, что выбранная дата находится в будущем
    final now = DateTime.now();
    if (currentDateTime.isBefore(now)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дата напоминания должна быть в будущем')),
      );
      return;
    }

    // Проверяем, что выбранная дата не позже дедлайна
    if (currentDateTime.isAfter(widget.deadlineDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напоминание должно быть до дедлайна')),
      );
      return;
    }

    _safeSetState(() {
      _selectedType = ReminderType.exactTime;
      _reminderDates = [currentDateTime];
    });

    // Уведомляем родительский виджет
    if (mounted) {
      widget.onRemindersChanged(_reminderDates, _selectedSound,
          isRelativeTimeActive: false);
    }
  }

  // Добавление относительного напоминания
  void _addRelativeReminder() {
    int minutes = _selectedRelativeMinutes;

    if (minutes <= 0) {
      // Пытаемся получить из пользовательского ввода
      try {
        minutes = int.parse(_customRelativeController.text);
        if (minutes <= 0)
          throw FormatException('Должно быть положительное число');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Введите корректное значение в минутах')),
        );
        return;
      }
    }

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
      _selectedType = ReminderType.relativeTime;
      _selectedRelativeMinutes = minutes;
      _reminderDates = [reminderDateTime];
    });

    // Определяем описание
    String description = 'За $minutes мин';
    if (minutes == 60)
      description = 'За 1 час';
    else if (minutes == 1440)
      description = 'За 1 день';
    else if (minutes == 2880)
      description = 'За 2 дня';
    else if (minutes == 10080) description = 'За 1 неделю';

    // Уведомляем родительский виджет
    widget.onRemindersChanged(_reminderDates, _selectedSound,
        isRelativeTimeActive: true,
        relativeMinutes: minutes,
        relativeDescription: description);
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
    widget.onRemindersChanged(_reminderDates, _selectedSound,
        isRelativeTimeActive: _selectedType == ReminderType.relativeTime,
        relativeMinutes: _selectedRelativeMinutes,
        relativeDescription: _getRelativeDescription());
  }

  // Получение описания относительного напоминания
  String _getRelativeDescription() {
    int minutes = _selectedRelativeMinutes;

    if (minutes == 5) return 'За 5 минут';
    if (minutes == 15) return 'За 15 минут';
    if (minutes == 30) return 'За 30 минут';
    if (minutes == 60) return 'За 1 час';
    if (minutes == 180) return 'За 3 часа';
    if (minutes == 1440) return 'За 1 день';
    if (minutes == 2880) return 'За 2 дня';
    if (minutes == 10080) return 'За 1 неделю';

    return 'За $minutes мин';
  }

  // Воспроизведение звука напоминания
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

  // Открытие диалога выбора даты
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: widget.deadlineDate,
      locale: const Locale('ru', 'RU'),
    );

    if (pickedDate != null && mounted) {
      _selectTime(pickedDate);
    }
  }

  // Открытие диалога выбора времени
  Future<void> _selectTime(DateTime date) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      _safeSetState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });

      // Добавляем напоминание, если оно валидное
      _addExactTimeReminder();
    }
  }

  // Форматирование даты для отображения
  String _formatDateTimeForDisplay(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
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
      'clock': 'Часы',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Табы для выбора типа напоминания
        TabBar(
          controller: _tabController,
          labelColor: AppColors.accentSecondary,
          unselectedLabelColor: AppColors.textOnLight.withOpacity(0.7),
          indicatorColor: AppColors.accentSecondary,
          tabs: const [
            Tab(text: 'Точное время'),
            Tab(text: 'Относительное'),
            Tab(text: 'Повторяющееся'),
          ],
        ),

        const SizedBox(height: 16),

        // Содержимое в зависимости от выбранного таба
        SizedBox(
          height: 250,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Таб точного времени
              _buildExactTimeTab(),

              // Таб относительного времени
              _buildRelativeTimeTab(),

              // Таб повторяющихся напоминаний
              _buildRecurringTab(),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Выбор звука
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

  // Виджет для вкладки точного времени
  Widget _buildExactTimeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Информация о выбранной дате и времени
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.textBackground.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy', 'ru_RU')
                          .format(_selectedDateTime),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm', 'ru_RU').format(_selectedDateTime),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _selectDate,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Кнопки для выбора времени через числовые счетчики
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Часы
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up, size: 36),
                  onPressed: () {
                    _safeSetState(() {
                      _selectedDateTime =
                          _selectedDateTime.add(const Duration(hours: 1));
                    });
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.secondary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedDateTime.hour.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_down, size: 36),
                  onPressed: () {
                    _safeSetState(() {
                      _selectedDateTime =
                          _selectedDateTime.subtract(const Duration(hours: 1));
                    });
                  },
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(':', style: TextStyle(fontSize: 24)),
            ),

            // Минуты
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up, size: 36),
                  onPressed: () {
                    _safeSetState(() {
                      _selectedDateTime =
                          _selectedDateTime.add(const Duration(minutes: 1));
                    });
                  },
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.secondary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedDateTime.minute.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_down, size: 36),
                  onPressed: () {
                    _safeSetState(() {
                      _selectedDateTime = _selectedDateTime
                          .subtract(const Duration(minutes: 1));
                    });
                  },
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Кнопка применения
        Center(
          child: ElevatedButton(
            onPressed: _addExactTimeReminder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Применить'),
          ),
        ),
      ],
    );
  }

  // Виджет для вкладки относительного времени
  Widget _buildRelativeTimeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Выберите, за сколько напомнить до дедлайна:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),

        const SizedBox(height: 8),

        // Сетка вариантов относительного времени
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 3,
            ),
            itemCount: _relativeOptions.length - 1, // Без опции "Другое"
            itemBuilder: (context, index) {
              final option = _relativeOptions[index];
              final bool isSelected =
                  _selectedRelativeMinutes == option['minutes'];

              return GestureDetector(
                onTap: () {
                  _safeSetState(() {
                    _selectedRelativeMinutes = option['minutes'];
                  });
                  _addRelativeReminder();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentSecondary.withOpacity(0.2)
                        : AppColors.textBackground.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: AppColors.accentSecondary)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isSelected
                            ? AppColors.accentSecondary
                            : AppColors.textOnLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        option['title'],
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.accentSecondary
                              : AppColors.textOnLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Поле для ввода пользовательского значения
        Row(
          children: [
            const Text('Другое: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextField(
                controller: _customRelativeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Введите минуты',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                try {
                  final minutes = int.parse(_customRelativeController.text);
                  if (minutes <= 0) throw FormatException('Must be positive');

                  _safeSetState(() {
                    _selectedRelativeMinutes = minutes;
                  });
                  _addRelativeReminder();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Введите корректное число минут')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Применить', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  // Виджет для вкладки повторяющихся напоминаний
  Widget _buildRecurringTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Настройки повторения:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),

        const SizedBox(height: 8),

        // Выбор типа повторения
        Row(
          children: [
            const Text('Частота: ', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<RepeatType>(
                value: _repeatType,
                isExpanded: true,
                onChanged: (newValue) {
                  if (newValue != null) {
                    _safeSetState(() {
                      _repeatType = newValue;
                    });
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: RepeatType.daily,
                    child: Text('Ежедневно'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.weekdays,
                    child: Text('По будням'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.weekly,
                    child: Text('Еженедельно'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.monthly,
                    child: Text('Ежемесячно'),
                  ),
                  DropdownMenuItem(
                    value: RepeatType.custom,
                    child: Text('Другое'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Дополнительные настройки в зависимости от типа повторения
        if (_repeatType == RepeatType.weekly) _buildWeekdaySelector(),

        if (_repeatType == RepeatType.custom) _buildCustomRepeatSettings(),

        const SizedBox(height: 16),

        // Выбор даты окончания повторений
        Row(
          children: [
            const Text('До даты: ', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _repeatEndDate ?? widget.deadlineDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );

                  if (pickedDate != null && mounted) {
                    _safeSetState(() {
                      _repeatEndDate = pickedDate;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: AppColors.secondary.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _repeatEndDate != null
                        ? DateFormat('dd.MM.yyyy').format(_repeatEndDate!)
                        : 'Без ограничения',
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                _safeSetState(() {
                  _repeatEndDate = null;
                });
              },
            ),
          ],
        ),

        const Spacer(),

        // Кнопка применения
        Center(
          child: ElevatedButton(
            onPressed: _saveRecurringReminder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Применить'),
          ),
        ),
      ],
    );
  }

  // Виджет выбора дней недели
  Widget _buildWeekdaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите дни недели:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildWeekdayChip('Пн', _isMonday, (value) => _isMonday = value),
            _buildWeekdayChip('Вт', _isTuesday, (value) => _isTuesday = value),
            _buildWeekdayChip(
                'Ср', _isWednesday, (value) => _isWednesday = value),
            _buildWeekdayChip(
                'Чт', _isThursday, (value) => _isThursday = value),
            _buildWeekdayChip('Пт', _isFriday, (value) => _isFriday = value),
            _buildWeekdayChip(
                'Сб', _isSaturday, (value) => _isSaturday = value),
            _buildWeekdayChip('Вс', _isSunday, (value) => _isSunday = value),
          ],
        ),
      ],
    );
  }

  // Виджет для выбора дня недели
  Widget _buildWeekdayChip(
      String label, bool isSelected, Function(bool) onToggle) {
    return GestureDetector(
      onTap: () {
        _safeSetState(() {
          onToggle(!isSelected);
        });
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSecondary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? AppColors.accentSecondary
                : AppColors.secondary.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textOnLight,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Виджет для настройки произвольных повторений
  Widget _buildCustomRepeatSettings() {
    return Row(
      children: [
        const Text('Каждые ', style: TextStyle(fontSize: 14)),
        SizedBox(
          width: 50,
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (value) {
              try {
                _repeatInterval = int.parse(value);
              } catch (e) {
                // ignore
              }
            },
            controller: TextEditingController(text: _repeatInterval.toString()),
          ),
        ),
        const SizedBox(width: 8),
        const Text(' дней', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  // Сохранение настроек повторяющегося напоминания
  void _saveRecurringReminder() {
    // Создаем первое напоминание
    DateTime firstReminder = DateTime.now().add(const Duration(hours: 1));

    // Проверяем, что оно до дедлайна
    if (firstReminder.isAfter(widget.deadlineDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Первое напоминание должно быть до дедлайна')),
      );
      return;
    }

    _safeSetState(() {
      _selectedType = ReminderType.recurring;
      _reminderDates = [firstReminder];
    });

    // Здесь нужна дополнительная обработка для создания серии напоминаний
    // В данной реализации мы просто уведомляем родительский виджет о
    // первом напоминании, а логика повторения будет в сервисе уведомлений

    // Уведомляем родительский виджет
    widget.onRemindersChanged(_reminderDates, _selectedSound,
        isRelativeTimeActive: false);

    // В реальном приложении здесь также должна быть логика для сохранения
    // настроек повторения
  }
}

// Перечисление для типов повторений
enum RepeatType {
  daily,
  weekdays,
  weekly,
  monthly,
  custom,
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import 'dart:io';
import 'dart:async';
import '../models/note.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Константы для идентификации каналов уведомлений
  static const String _channelId = 'note_link_reminders';
  static const String _channelName = 'Напоминания';
  static const String _channelDescription =
      'Уведомления о приближающихся дедлайнах и задачах';

  // Константы для идентификации типов напоминаний в ID
  static const String _reminderId = 'reminder';
  static const String _deadlineId = 'deadline';

  // Максимальное количество секунд для отложенных уведомлений
  static const int _maxNotificationDelay =
      7 * 24 * 60 * 60; // 7 дней в секундах

  // Доступные звуки для уведомлений
  final List<String> _availableSounds = [
    'default',
    'alert',
    'bell',
    'chime',
    'urgent',
    'clock'
  ];

  // Инициализация сервиса уведомлений
  Future<void> init() async {
    if (_isInitialized) return;

    // Инициализируем данные временных зон
    tz_init.initializeTimeZones();

    // Настройки для Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Настройки для iOS
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    // Объединяем настройки
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Инициализируем плагин
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Запрашиваем разрешения на показ уведомлений
    await _requestPermissions();

    // Копируем звуки в директорию приложения
    await _prepareSounds();

    _isInitialized = true;
  }

  // Обработчик нажатия на уведомление в iOS
  Future<void> _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // В iOS 10+ эта функция не будет вызываться
  }

  // Обработчик действия пользователя по уведомлению
  void _onNotificationResponse(NotificationResponse response) {
    // Здесь можно обрабатывать действия пользователя
    print('Нажато на уведомление: ${response.payload}');
  }

  // Запрос разрешений для показа уведомлений
  Future<void> _requestPermissions() async {
    // Запрос для Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Проверяем, что реализация найдена, перед вызовом метода
      await androidImplementation?.requestNotificationsPermission();
    }

    // Запрос для iOS
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  // Подготовка звуковых файлов
  Future<void> _prepareSounds() async {
    // Получаем директорию приложения
    final directory = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${directory.path}/sounds');

    // Создаем директорию, если ее нет
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }

    // Копируем звуки из ассетов
    for (final sound in _availableSounds) {
      if (sound == 'default') continue; // Стандартный звук не нужно копировать

      final soundFile = File('${soundsDir.path}/$sound.wav');
      if (!await soundFile.exists()) {
        try {
          final data = await rootBundle.load('assets/sounds/$sound.wav');
          final buffer = data.buffer.asUint8List();
          await soundFile.writeAsBytes(buffer);
        } catch (e) {
          print('Ошибка при копировании звука $sound: $e');
        }
      }
    }
  }

  // Получение списка доступных звуков
  List<String> getAvailableSounds() => List.from(_availableSounds);

  // Планирование уведомлений для заметки
  Future<void> scheduleNotificationsForNote(Note note) async {
    if (!_isInitialized) await init();

    // Проверяем, что заметка имеет дедлайн и напоминания
    if (!note.hasDeadline || note.deadlineDate == null || !note.hasReminders) {
      return;
    }

    // Сначала отменяем существующие уведомления для этой заметки
    await cancelNotificationsForNote(note.id);

    // Устанавливаем параметры уведомлений в зависимости от типа напоминания
    if (note.reminderType == ReminderType.exactTime) {
      await _scheduleExactTimeReminders(note);
    } else if (note.reminderType == ReminderType.relativeTime) {
      await _scheduleRelativeTimeReminder(note);
    }

    // Планируем уведомление о дедлайне, если до него осталось не более 7 дней
    await _scheduleDeadlineNotification(note);
  }

  // Планирование напоминаний с точным временем
  Future<void> _scheduleExactTimeReminders(Note note) async {
    if (note.reminderDates == null || note.reminderDates!.isEmpty) return;

    for (int i = 0; i < note.reminderDates!.length; i++) {
      final reminderDate = note.reminderDates![i];

      // Проверяем, что дата в будущем
      if (reminderDate.isBefore(DateTime.now())) continue;

      // Рассчитываем задержку в секундах
      final delayInSeconds = reminderDate.difference(DateTime.now()).inSeconds;

      // Планируем только если задержка не превышает максимальную
      if (delayInSeconds <= _maxNotificationDelay) {
        await _scheduleReminderNotification(
          note,
          reminderDate,
          i, // Используем индекс для создания уникального ID
          note.reminderSound ?? 'default',
        );
      }
    }
  }

  // Планирование относительного напоминания
  Future<void> _scheduleRelativeTimeReminder(Note note) async {
    if (note.relativeReminder == null || note.deadlineDate == null) return;

    // Рассчитываем дату напоминания на основе дедлайна и смещения в минутах
    final reminderDate = note.deadlineDate!.subtract(
      Duration(minutes: note.relativeReminder!.minutes),
    );

    // Проверяем, что дата в будущем
    if (reminderDate.isBefore(DateTime.now())) return;

    // Рассчитываем задержку в секундах
    final delayInSeconds = reminderDate.difference(DateTime.now()).inSeconds;

    // Планируем только если задержка не превышает максимальную
    if (delayInSeconds <= _maxNotificationDelay) {
      await _scheduleReminderNotification(
        note,
        reminderDate,
        0, // Для относительного напоминания используем индекс 0
        note.reminderSound ?? 'default',
        isRelative: true, // Указываем, что это относительное напоминание
      );
    }
  }

  // Планирование уведомления о дедлайне
  Future<void> _scheduleDeadlineNotification(Note note) async {
    if (note.deadlineDate == null) return;

    // Не планируем уведомление для выполненных задач
    if (note.isCompleted) return;

    // Проверяем, что дедлайн в будущем и не более чем через 7 дней
    final now = DateTime.now();
    final deadline = note.deadlineDate!;

    if (deadline.isBefore(now)) return;

    final delayInSeconds = deadline.difference(now).inSeconds;
    if (delayInSeconds > _maxNotificationDelay) return;

    // Создаем идентификатор для уведомления о дедлайне
    final int notificationId = _generateNotificationId(
      note.id,
      _deadlineId,
      0, // Для дедлайна используем индекс 0
    );

    // Получаем текст заголовка и содержимого
    final String title = 'Дедлайн: ${_getPreviewText(note.content)}';
    final String body =
        'Срок выполнения заканчивается ${_formatDate(deadline)}';

    // Настройки для Android
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(
          'urgent'), // Используем звук 'urgent' для дедлайнов
      styleInformation: BigTextStyleInformation(body),
    );

    // Настройки для iOS
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'urgent.wav',
    );

    // Объединяем настройки
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Планируем уведомление
    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(deadline, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: note.id,
    );
  }

  // Планирование конкретного напоминания
  Future<void> _scheduleReminderNotification(
    Note note,
    DateTime reminderTime,
    int index,
    String sound, {
    bool isRelative = false,
  }) async {
    // Создаем идентификатор для уведомления
    final int notificationId = _generateNotificationId(
      note.id,
      _reminderId,
      index,
    );

    // Формируем текст заголовка и содержимого
    String title;
    String body;

    if (isRelative) {
      // Текст для относительного напоминания
      title = 'Напоминание: ${_getPreviewText(note.content)}';
      body =
          'Осталось ${note.relativeReminder!.description} до дедлайна (${_formatDate(note.deadlineDate!)})';
    } else {
      // Текст для напоминания с точным временем
      title = 'Напоминание: ${_getPreviewText(note.content)}';

      if (note.hasDeadline && note.deadlineDate != null) {
        final int daysUntilDeadline =
            note.deadlineDate!.difference(reminderTime).inDays;
        if (daysUntilDeadline == 0) {
          body =
              'Дедлайн сегодня в ${DateFormat('HH:mm').format(note.deadlineDate!)}';
        } else if (daysUntilDeadline == 1) {
          body =
              'Дедлайн завтра в ${DateFormat('HH:mm').format(note.deadlineDate!)}';
        } else {
          body = 'Срок выполнения: ${_formatDate(note.deadlineDate!)}';
        }
      } else {
        body = 'Не забудьте выполнить эту задачу';
      }
    }

    // Получаем имя файла звука
    final String soundFileName = sound == 'default' ? 'default' : '$sound.wav';

    // Настройки для Android
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      sound: sound == 'default'
          ? null
          : RawResourceAndroidNotificationSound(sound),
      styleInformation: BigTextStyleInformation(body),
    );

    // Настройки для iOS
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: sound == 'default' ? null : soundFileName,
    );

    // Объединяем настройки
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Планируем уведомление
    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(reminderTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: note.id,
    );
  }

  // Отмена всех уведомлений для заметки
  Future<void> cancelNotificationsForNote(String noteId) async {
    if (!_isInitialized) await init();

    try {
      // Отменяем напоминания
      for (int i = 0; i < 10; i++) {
        // Предполагаем, что может быть до 10 напоминаний
        final int reminderNotificationId = _generateNotificationId(
          noteId,
          _reminderId,
          i,
        );
        await _notifications.cancel(reminderNotificationId);
      }

      // Отменяем уведомление о дедлайне
      final int deadlineNotificationId = _generateNotificationId(
        noteId,
        _deadlineId,
        0,
      );
      await _notifications.cancel(deadlineNotificationId);
    } catch (e) {
      print('Ошибка при отмене уведомлений: $e');
    }
  }

  // Генерация уникального ID для уведомления
  int _generateNotificationId(String noteId, String type, int index) {
    // Хешируем ID заметки для получения базового числа
    final int noteIdHash = noteId.hashCode;

    // Хешируем тип уведомления
    final int typeHash = type.hashCode;

    // Комбинируем их с индексом для создания уникального ID
    // Используем побитовые операции для минимизации коллизий
    return ((noteIdHash & 0xFFFF) << 16) |
        ((typeHash & 0xFF) << 8) |
        (index & 0xFF);
  }

  // Получение короткого текста для предпросмотра
  String _getPreviewText(String content) {
    // Ограничиваем длину текста для предпросмотра
    const int maxPreviewLength = 30;

    // Удаляем маркировку Markdown, если она есть
    final String plainText = content
        .replaceAll(RegExp(r'#{1,3}\s+'), '') // Заголовки
        .replaceAll(RegExp(r'\*\*|\*|__'), '') // Жирный, курсив
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // Ссылки
        .replaceAll(
            RegExp(r'!\[voice\]\(voice:[^)]+\)'), '') // Голосовые заметки
        .trim();

    // Получаем первую строку
    final String firstLine = plainText.split('\n').first.trim();

    // Ограничиваем длину
    if (firstLine.length <= maxPreviewLength) {
      return firstLine;
    } else {
      return '${firstLine.substring(0, maxPreviewLength)}...';
    }
  }

  // Форматирование даты для отображения
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'сегодня в ${DateFormat('HH:mm').format(date)}';
    } else if (dateOnly == tomorrow) {
      return 'завтра в ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd.MM.yyyy в HH:mm').format(date);
    }
  }
}

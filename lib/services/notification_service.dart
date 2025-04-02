import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../models/note.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;

  // Для хранения всех запланированных напоминаний по конкретной заметке
  final Map<String, List<int>> _noteReminders = {};

  // Инициализация сервиса
  Future<void> init() async {
    if (_initialized) return;

    // Инициализация часовых поясов
    tz_data.initializeTimeZones();

    // Настройки для Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Настройки для iOS
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false, // Запросим позже
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Не делаем ничего особенного на старых версиях iOS
        debugPrint('Получено уведомление: $id, $title, $body, $payload');
      },
    );

    // Объединяем настройки для разных платформ
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Инициализируем плагин
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;

    // Запрашиваем разрешения для iOS и новых версий Android
    await requestPermissions();
  }

  // Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      debugPrint('Нажатие на уведомление с payload: ${response.payload}');
      // Здесь можно добавить навигацию к заметке
      // Например, сохранить обработчик или использовать глобальный навигатор
    }
  }

  // Регистрация обработчика нажатия на уведомление
  void registerNotificationTapCallback(Function(String) callback) {
    // Здесь можно добавить хранение внешнего обработчика
  }

  // Запрос разрешений
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _permissionGranted = result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Для Android 13+ (API 33+) - нужен правильный метод для запроса разрешений
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        _permissionGranted = granted ?? false;
      } else {
        _permissionGranted = true; // Для старых версий Android
      }
    }

    return _permissionGranted;
  }

  // Проверка, даны ли разрешения
  Future<bool> checkPermissions() async {
    if (!_initialized) await init();
    return _permissionGranted;
  }

  // Генерация уникального ID для уведомления на основе ID заметки и времени
  int _generateNotificationId(String noteId, DateTime scheduledDateTime) {
    // Комбинируем ID заметки со временем, чтобы получить уникальный ID
    final String timeStr = scheduledDateTime.millisecondsSinceEpoch.toString();
    final String uniqueStr = noteId + timeStr;

    // Превращаем строку в число с ограничением максимального значения для int
    int id = uniqueStr.hashCode % 2147483647; // Max value for 32-bit integer
    if (id < 0) id = -id; // Убедимся, что ID положительный

    return id;
  }

  // Отмена всех напоминаний для заметки
  Future<void> cancelNotificationsForNote(String noteId) async {
    if (!_initialized) await init();

    // Если у нас есть сохраненные ID для этой заметки, отменяем их
    if (_noteReminders.containsKey(noteId)) {
      for (final id in _noteReminders[noteId]!) {
        await _flutterLocalNotificationsPlugin.cancel(id);
      }
      _noteReminders.remove(noteId);
    }
  }

  // Создание нового напоминания
  Future<void> scheduleNotification({
    required String noteId,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
    String? sound,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) await init();
    if (!_permissionGranted) {
      _permissionGranted = await requestPermissions();
      if (!_permissionGranted) return;
    }

    // Генерируем уникальный ID для уведомления
    final int notificationId =
        _generateNotificationId(noteId, scheduledDateTime);

    // Добавляем ID в список напоминаний для этой заметки
    _noteReminders[noteId] ??= [];
    _noteReminders[noteId]!.add(notificationId);

    // Преобразуем payload в строку
    final String notificationPayload =
        payload != null ? '${noteId}|${payload.toString()}' : noteId;

    // Настройки для Android
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'note_reminders',
      'Напоминания о заметках',
      channelDescription: 'Уведомления о дедлайнах и задачах',
      importance: Importance.high,
      priority: Priority.high,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
    );

    // Настройки для iOS
    DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: sound,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Общие настройки
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Запланировать уведомление
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: notificationPayload,
    );
  }

  // Запланировать все напоминания для заметки
  Future<void> scheduleNotificationsForNote(Note note) async {
    if (!note.hasDeadline || note.deadlineDate == null) return;
    if (note.reminderDates == null || note.reminderDates!.isEmpty) return;

    // Отменяем существующие напоминания для этой заметки
    await cancelNotificationsForNote(note.id);

    // Создаем заголовок и текст уведомления
    final String title = note.emoji != null
        ? '${note.emoji} Напоминание'
        : 'Напоминание о задаче';

    // Получаем первые 50 символов контента заметки
    final String content = note.content.length > 50
        ? '${note.content.substring(0, 47)}...'
        : note.content;

    final String body =
        'Дедлайн: ${_formatDeadlineDate(note.deadlineDate!)}. $content';

    // Планируем новые напоминания
    for (final reminderDate in note.reminderDates!) {
      // Пропускаем прошедшие даты
      if (reminderDate.isBefore(DateTime.now())) continue;

      await scheduleNotification(
        noteId: note.id,
        title: title,
        body: body,
        scheduledDateTime: reminderDate,
        sound: note.reminderSound,
        payload: {
          'type': 'reminder',
          'noteId': note.id,
        },
      );
    }
  }

  // Форматирование даты дедлайна для отображения в уведомлении
  String _formatDeadlineDate(DateTime date) {
    final now = DateTime.now();

    // Сегодня
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Сегодня';
    }

    // Завтра
    final tomorrow = now.add(const Duration(days: 1));
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Завтра';
    }

    // Форматируем дату
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Получить список доступных звуков уведомлений
  List<String> getAvailableSounds() {
    // В реальности этот список должен формироваться на основе доступных ресурсов
    return [
      'default',
      'alert',
      'bell',
      'chime',
      'urgent',
    ];
  }

  // Отмена всех запланированных уведомлений
  Future<void> cancelAllNotifications() async {
    if (!_initialized) await init();
    await _flutterLocalNotificationsPlugin.cancelAll();
    _noteReminders.clear();
  }
}

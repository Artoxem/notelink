// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/note.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';

class NotificationService {
  // Синглтон
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Идентификаторы для различных типов уведомлений
  static const String _channelId = 'notelink_reminders';
  static const String _channelName = 'Напоминания';
  static const String _channelDescription =
      'Уведомления о напоминаниях в заметках';

  // Плагин для работы с уведомлениями
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Флаг инициализации
  bool _isInitialized = false;

  // Мапа для хранения запланированных напоминаний
  // ключ - ID заметки, значение - список ID уведомлений
  final Map<String, List<int>> _scheduledNotifications = {};

  // Счетчик для генерации уникальных ID уведомлений
  int _notificationIdCounter = 0;

  // Хранилище настроек звуков
  final Map<String, String> _soundPaths = {
    'default': 'notification_default.wav',
    'alert': 'notification_alert.wav',
    'bell': 'notification_bell.wav',
    'chime': 'notification_chime.wav',
    'urgent': 'notification_urgent.wav',
    'clock': 'notification_clock.wav',
  };

  NotificationService._internal();

  // Инициализация сервиса
  Future<void> init() async {
    if (_isInitialized) return;

    // Инициализация временных зон
    tz_data.initializeTimeZones();

    // Настройка для Android
    const androidSettings = AndroidInitializationSettings('app_icon');

    // Настройка для iOS
    final iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    // Объединение настроек
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Инициализация плагина
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Создание канала уведомлений для Android
    await _createNotificationChannel();

    // Запрос необходимых разрешений
    await _requestPermissions();

    _isInitialized = true;
  }

  // Создание канала уведомлений (для Android)
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Запрос разрешений
  Future<void> _requestPermissions() async {
    // Для iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Для Android:
    // Примечание: В различных версиях flutter_local_notifications
    // разрешения обрабатываются по-разному:
    // - В старых версиях разрешения запрашиваются автоматически при показе уведомления
    // - В новых версиях (post-API 33/Android 13) требуется явный запрос
    //   через определенные методы, которые могут различаться
    //
    // Поскольку методы для запроса разрешений могут меняться,
    // мы рассчитываем на то, что разрешения будут запрошены
    // при первом показе уведомления

    // Проверяем возможность показа немедленного тестового уведомления
    // для запроса разрешений (опционально)
    // await showTestNotification("Тест разрешений", "Тестовое уведомление для проверки разрешений");
  }

  // Обработка получения уведомления на iOS
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    // Здесь можно добавить дополнительную логику
    print('Получено уведомление: $id, $title, $body, $payload');
  }

  // Обработка нажатия на уведомление
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Получаем данные из payload
    final String? payload = response.payload;

    if (payload != null && payload.isNotEmpty) {
      // Формат payload: noteId|actionType
      // где actionType может быть 'open', 'complete', etc.
      final parts = payload.split('|');
      if (parts.length >= 2) {
        final noteId = parts[0];
        final actionType = parts[1];

        // Обработка действий
        _handleNotificationAction(noteId, actionType);
      }
    }
  }

  // Обработка действий по уведомлению
  void _handleNotificationAction(String noteId, String actionType) {
    // В реальном приложении здесь будет навигация к заметке
    // или выполнение других действий
    print('Обработка действия: $actionType для заметки $noteId');

    // TODO: Добавить логику навигации к экрану заметки
  }

  // Получение доступных звуков
  List<String> getAvailableSounds() {
    return _soundPaths.keys.toList();
  }

  // Генерация уникального ID для уведомления
  int _generateNotificationId() {
    _notificationIdCounter = (_notificationIdCounter + 1) % 2147483647;
    return _notificationIdCounter;
  }

  // Планирование одиночного уведомления
  Future<int> _scheduleNotification(
    String noteId,
    String title,
    String body,
    DateTime scheduledDate,
    String sound,
  ) async {
    // Проверка, что дата в будущем
    if (scheduledDate.isBefore(DateTime.now())) {
      print('Дата напоминания в прошлом, пропускаем: $scheduledDate');
      return -1;
    }

    // Генерация ID
    final notificationId = _generateNotificationId();

    // Преобразование в tz.TZDateTime
    final scheduledTzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Настройка Android-специфичных деталей
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // Звуковой файл
    String soundFile = _soundPaths[sound] ?? _soundPaths['default']!;

    // Настройка iOS-специфичных деталей
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundFile.replaceAll('.wav', ''),
    );

    // Общие детали
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Формирование payload
    final payload = '$noteId|open';

    // Планирование
    await _notificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledTzDate,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    // Регистрация в карте запланированных
    _scheduledNotifications[noteId] ??= [];
    _scheduledNotifications[noteId]!.add(notificationId);

    return notificationId;
  }

  // Метод для планирования напоминаний для заметки
  Future<void> scheduleNotificationsForNote(Note note) async {
    // Отменяем существующие напоминания
    await cancelNotificationsForNote(note.id);

    // Если нет дедлайна или заметка выполнена, выходим
    if (!note.hasDeadline || note.deadlineDate == null || note.isCompleted) {
      return;
    }

    // Если нет напоминаний, выходим
    if (!note.hasReminders) {
      return;
    }

    // Получаем звук или используем дефолтный
    final sound = note.reminderSound ?? 'default';

    // Формируем заголовок и тело уведомления
    final title = 'Напоминание: дедлайн ${_formatDate(note.deadlineDate!)}';
    final body = _getNotificationBodyFromNote(note);

    // В зависимости от типа напоминания, планируем соответствующие уведомления
    switch (note.reminderType) {
      case ReminderType.exactTime:
        if (note.reminderDates != null && note.reminderDates!.isNotEmpty) {
          for (final date in note.reminderDates!) {
            await _scheduleNotification(note.id, title, body, date, sound);
          }
        }
        break;

      case ReminderType.relativeTime:
        if (note.relativeReminder != null) {
          final reminderDate = note.deadlineDate!.subtract(
            Duration(minutes: note.relativeReminder!.minutes),
          );

          await _scheduleNotification(
              note.id, title, body, reminderDate, sound);
        }
        break;

      case ReminderType.recurring:
        if (note.recurringReminder != null) {
          // Получаем следующие несколько напоминаний
          final nextDates = note.getNextRecurringDates(5);

          for (final date in nextDates) {
            await _scheduleNotification(note.id, title, body, date, sound);
          }
        }
        break;
    }
  }

  // Отмена всех напоминаний для заметки
  Future<void> cancelNotificationsForNote(String noteId) async {
    final notificationIds = _scheduledNotifications[noteId] ?? [];

    // Отменяем каждое уведомление
    for (final id in notificationIds) {
      await _notificationsPlugin.cancel(id);
    }

    // Очищаем список
    _scheduledNotifications.remove(noteId);
  }

  // Отмена всех напоминаний
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    _scheduledNotifications.clear();
  }

  // Проверка активных напоминаний
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  // Обновление всех напоминаний (например, после изменения настроек)
  Future<void> updateAllNotifications(List<Note> notes) async {
    // Сначала отменяем все
    await cancelAllNotifications();

    // Затем планируем новые для каждой заметки
    for (final note in notes) {
      if (note.hasReminders && note.hasDeadline && !note.isCompleted) {
        await scheduleNotificationsForNote(note);
      }
    }
  }

  // Форматирование даты для отображения
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Получение текста уведомления из заметки
  String _getNotificationBodyFromNote(Note note) {
    // Если есть контент, берем первые 100 символов
    if (note.content.isNotEmpty) {
      final preview = note.content.length <= 100
          ? note.content
          : '${note.content.substring(0, 97)}...';
      return preview;
    }

    return 'Нажмите, чтобы открыть заметку';
  }

  // Показать тестовое уведомление
  Future<void> showTestNotification(String title, String body) async {
    // Android-специфичные детали
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS-специфичные детали
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Общие детали
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Показ немедленного уведомления
    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  // Перепланирование напоминаний после изменения дедлайна
  Future<void> rescheduleForDeadlineChange(
      Note note, DateTime oldDeadline) async {
    // Если нет напоминаний или заметка выполнена, просто отменяем существующие
    if (!note.hasReminders || note.isCompleted) {
      await cancelNotificationsForNote(note.id);
      return;
    }

    // Для точных напоминаний не нужно перепланировать - просто используем существующие даты
    if (note.reminderType == ReminderType.exactTime) {
      await scheduleNotificationsForNote(note);
      return;
    }

    // Для относительных напоминаний нужно пересчитать время относительно нового дедлайна
    if (note.reminderType == ReminderType.relativeTime &&
        note.relativeReminder != null &&
        note.deadlineDate != null) {
      await scheduleNotificationsForNote(note);
      return;
    }

    // Для повторяющихся напоминаний также перепланируем
    if (note.reminderType == ReminderType.recurring &&
        note.recurringReminder != null &&
        note.deadlineDate != null) {
      await scheduleNotificationsForNote(note);
      return;
    }
  }

  // Проверка просроченных заметок и отправка уведомлений
  Future<void> checkOverdueNotes(List<Note> notes) async {
    final now = DateTime.now();

    // Фильтруем только невыполненные заметки с дедлайном
    final overdueNotes = notes
        .where((note) =>
            note.hasDeadline &&
            !note.isCompleted &&
            note.deadlineDate != null &&
            note.deadlineDate!.isBefore(now))
        .toList();

    // Если есть просроченные заметки, показываем уведомление
    if (overdueNotes.isEmpty) return;

    // Определяем заголовок
    final title = overdueNotes.length == 1
        ? 'Просрочена 1 заметка'
        : 'Просрочено ${overdueNotes.length} заметок';

    // Определяем текст
    String body;
    if (overdueNotes.length == 1) {
      body = _getNotificationBodyFromNote(overdueNotes.first);
    } else {
      body = 'Нажмите, чтобы просмотреть просроченные заметки';
    }

    // Показываем уведомление
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Генерируем случайный ID, чтобы не конфликтовать с другими уведомлениями
    final notificationId = Random().nextInt(1000000);

    // Показываем уведомление
    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: 'overdue|open',
    );
  }
}

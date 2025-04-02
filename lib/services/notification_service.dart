import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Список доступных звуков (будет заполнен при инициализации)
  List<String> _availableSounds = ['default'];

  // Инициализация сервиса уведомлений
  Future<void> init() async {
    tz_data.initializeTimeZones();

    // Инициализация плагина уведомлений
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        // Обработка нажатия на уведомление в iOS
      },
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Обработка нажатия на уведомление
      },
    );

    // Загружаем список доступных звуков
    await _loadAvailableSounds();
  }

  // Загрузка списка доступных звуков из ресурсов
  Future<void> _loadAvailableSounds() async {
    try {
      // Начинаем с базового списка
      _availableSounds = ['default'];

      // Список предустановленных звуков (находим эти файлы в assets/sounds/reminder)
      // В реальном случае можно использовать rootBundle.loadString('AssetManifest.json')
      // для динамического получения списка, но для упрощения я использую жесткий список
      final predefinedSounds = ['clock'];

      _availableSounds.addAll(predefinedSounds);
    } catch (e) {
      print('Ошибка при загрузке доступных звуков: $e');
    }
  }

  // Получение списка доступных звуков
  List<String> getAvailableSounds() {
    return _availableSounds;
  }

  // Запланировать уведомления для заметки
  Future<void> scheduleNotificationsForNote(Note note) async {
    // Отменяем существующие уведомления для этой заметки
    await cancelNotificationsForNote(note.id);

    // Проверяем, есть ли даты напоминаний
    if (!note.hasDeadline ||
        note.reminderDates == null ||
        note.reminderDates!.isEmpty) {
      return;
    }

    // Название заметки для уведомления (первые слова или "Напоминание")
    String title = note.content.isNotEmpty
        ? (note.content.length > 30
            ? '${note.content.substring(0, 30)}...'
            : note.content)
        : 'Напоминание';

    // Текст уведомления
    String body = note.hasDeadline && note.deadlineDate != null
        ? 'Дедлайн: ${_formatDate(note.deadlineDate!)}'
        : 'Новое напоминание';

    // Выбираем звук уведомления
    String soundName = note.reminderSound ?? 'default';

    // Создаем уведомление для каждой даты напоминания
    for (var reminderDate in note.reminderDates!) {
      // Пропускаем прошедшие даты
      if (reminderDate.isBefore(DateTime.now())) {
        continue;
      }

      // Генерируем уникальный ID для уведомления на основе ID заметки и даты
      final int notificationId = _generateNotificationId(note.id, reminderDate);

      // Планируем уведомление
      await _scheduleNotification(
        id: notificationId,
        title: title,
        body: body,
        time: reminderDate,
        payload: note.id,
        soundName: soundName,
      );
    }
  }

  // Генерация уникального ID для уведомления
  int _generateNotificationId(String noteId, DateTime date) {
    // Используем хеш строки noteId и timestamp даты для генерации ID
    final String idString = '$noteId-${date.millisecondsSinceEpoch}';
    final int hash = idString.hashCode;

    // Ограничиваем до 31 бита (максимальный размер для Android)
    return hash.abs() % 2147483647;
  }

  // Запланировать уведомление
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    required String payload,
    required String soundName,
  }) async {
    // Настройки Android
    AndroidNotificationDetails androidDetails;

    // Если звук не "default", используем кастомный звук
    if (soundName != 'default' && _availableSounds.contains(soundName)) {
      // Подготавливаем звуковой файл (копируем из ресурсов если нужно)
      final String soundPath = await _prepareSoundFile(soundName);

      androidDetails = AndroidNotificationDetails(
        'reminder_channel_id',
        'Напоминания',
        channelDescription: 'Уведомления о напоминаниях',
        importance: Importance.high,
        priority: Priority.high,
        sound: soundPath.isNotEmpty
            ? RawResourceAndroidNotificationSound(soundPath)
            : null,
        playSound: true,
      );
    } else {
      // Используем звук по умолчанию
      androidDetails = const AndroidNotificationDetails(
        'reminder_channel_id',
        'Напоминания',
        channelDescription: 'Уведомления о напоминаниях',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    // Настройки iOS
    DarwinNotificationDetails iosDetails;

    if (soundName != 'default' && _availableSounds.contains(soundName)) {
      iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: '$soundName.m4a',
      );
    } else {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    }

    // Настройки для всех платформ
    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Запланировать уведомление с использованием timezone
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(time, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  // Подготовка звукового файла для уведомления на Android
  Future<String> _prepareSoundFile(String soundName) async {
    try {
      // На Android мы не можем напрямую использовать звуки из assets,
      // поэтому копируем их во временный каталог или используем raw ресурсы
      // В этой реализации будем просто возвращать имя файла без расширения
      // предполагая, что файл есть в res/raw директории Android проекта
      return soundName;
    } catch (e) {
      print('Ошибка при подготовке звукового файла: $e');
      return '';
    }
  }

  // Отмена всех уведомлений для заметки
  Future<void> cancelNotificationsForNote(String noteId) async {
    // В идеале, мы должны хранить все ID уведомлений для каждой заметки
    // Но для простоты мы можем отменить диапазон уведомлений

    // Создаем хеш из ID заметки
    final int baseId = noteId.hashCode.abs() % 100000000;

    // Отменяем уведомления в диапазоне baseId до baseId + 100
    // Это позволит отменить до 100 уведомлений для одной заметки
    for (int i = 0; i < 100; i++) {
      await _flutterLocalNotificationsPlugin.cancel(baseId + i);
    }
  }

  // Форматирование даты
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // Получение пути к файлу звука для предварительного прослушивания
  Future<String> getSoundFilePath(String soundName) async {
    if (soundName == 'default' || !_availableSounds.contains(soundName)) {
      return '';
    }

    try {
      // В реальном приложении здесь будет логика для получения пути к файлу
      // в зависимости от платформы

      // Для Flutter это может быть копирование asset файла во временный каталог
      final ByteData data =
          await rootBundle.load('assets/sounds/reminder/$soundName.m4a');
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/$soundName.m4a';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));

      return tempPath;
    } catch (e) {
      print('Ошибка при получении пути к звуковому файлу: $e');
      return '';
    }
  }
}

// lib/models/note.dart
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart'
    as quill; // Возвращаем импорт с префиксом
import 'package:flutter_quill/quill_delta.dart'; // Оставляем для Delta
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

// Перечисление для типа напоминания
enum ReminderType {
  exactTime, // Точное время
  relativeTime, // Относительно дедлайна
  recurring, // Повторяющееся напоминание
}

// Класс для хранения относительного напоминания
@immutable
class RelativeReminder {
  final int minutes; // За сколько минут до дедлайна
  final String description; // Описание (например, "За 1 час до")

  const RelativeReminder({required this.minutes, required this.description});

  // Методы fromMap и toMap
  factory RelativeReminder.fromMap(Map<String, dynamic> map) {
    return RelativeReminder(
      minutes: map['minutes'] as int,
      description: map['description'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'minutes': minutes, 'description': description};
  }
}

// Перечисление для периода повторения напоминания
enum RecurringPeriod {
  daily, // Ежедневно
  weekly, // Еженедельно
  monthly, // Ежемесячно
  custom, // Пользовательский период (в днях)
}

// Класс для хранения повторяющегося напоминания
@immutable
class RecurringReminder {
  final RecurringPeriod period;
  final int
  customDays; // Используется только при period == RecurringPeriod.custom
  final TimeOfDay timeOfDay;
  final DateTime startDate;
  final DateTime? endDate; // Опционально, до какой даты повторять

  const RecurringReminder({
    required this.period,
    this.customDays = 1,
    required this.timeOfDay,
    required this.startDate,
    this.endDate,
  });

  // Методы fromMap и toMap
  factory RecurringReminder.fromMap(Map<String, dynamic> map) {
    return RecurringReminder(
      period: RecurringPeriod.values[map['period'] as int],
      customDays: map['customDays'] as int? ?? 1,
      timeOfDay: TimeOfDay(
        hour: map['hour'] as int,
        minute: map['minute'] as int,
      ),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate:
          map['endDate'] != null
              ? DateTime.parse(map['endDate'] as String)
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'period': period.index,
      'customDays': customDays,
      'hour': timeOfDay.hour,
      'minute': timeOfDay.minute,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}

// Класс для хранения истории продления дедлайна
@immutable
class DeadlineExtension {
  final DateTime originalDate;
  final DateTime newDate;
  final DateTime extendedAt;

  const DeadlineExtension({
    required this.originalDate,
    required this.newDate,
    required this.extendedAt,
  });

  factory DeadlineExtension.fromMap(Map<String, dynamic> map) {
    return DeadlineExtension(
      originalDate: DateTime.parse(map['originalDate'] as String),
      newDate: DateTime.parse(map['newDate'] as String),
      extendedAt: DateTime.parse(map['extendedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalDate': originalDate.toIso8601String(),
      'newDate': newDate.toIso8601String(),
      'extendedAt': extendedAt.toIso8601String(),
    };
  }
}

@immutable
class Note {
  final String id;
  final String content; // Содержимое в формате JSON Delta
  final List<String> themeIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasDeadline;
  final DateTime? deadlineDate;
  final bool hasDateLink;
  final DateTime? linkedDate;
  final bool isCompleted;
  final bool isFavorite;
  final List<String> mediaUrls;
  final String? emoji;
  final List<DateTime>? reminderDates;
  final String? reminderSound;
  final ReminderType reminderType;
  final RelativeReminder? relativeReminder;
  final RecurringReminder? recurringReminder;
  final List<DeadlineExtension>? deadlineExtensions;
  final List<String> voiceNotes; // Список ID голосовых заметок

  // Геттер для проверки наличия напоминаний
  bool get hasReminders =>
      (reminderDates != null && reminderDates!.isNotEmpty) ||
      relativeReminder != null ||
      recurringReminder != null;

  // Геттер для определения быстрой заметки (без тем и связанных дат)
  bool get isQuickNote => themeIds.isEmpty && !hasDateLink && !hasDeadline;

  // Геттеры для проверки типов медиа
  bool get hasImages => mediaUrls.any(
    (url) =>
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png'),
  );

  bool get hasAudio => mediaUrls.any(
    (url) =>
        url.toLowerCase().endsWith('.mp3') ||
        url.toLowerCase().endsWith('.wav') ||
        url.toLowerCase().endsWith('.m4a'),
  );

  bool get hasFiles => mediaUrls.any(
    (url) =>
        !url.toLowerCase().endsWith('.jpg') &&
        !url.toLowerCase().endsWith('.jpeg') &&
        !url.toLowerCase().endsWith('.png') &&
        !url.toLowerCase().endsWith('.mp3') &&
        !url.toLowerCase().endsWith('.wav') &&
        !url.toLowerCase().endsWith('.m4a'),
  );

  // Проверка наличия голосовых заметок
  bool get hasVoiceNotes => voiceNotes.isNotEmpty;

  // Общий флаг наличия медиа
  bool get hasMedia => mediaUrls.isNotEmpty || hasVoiceNotes;

  // Заменяем геттер на исправленную версию
  String get plainTextContent {
    if (content.isEmpty) {
      return '';
    }

    try {
      // Стандартизируем формат Delta JSON
      final dynamic decodedJson = json.decode(content);
      dynamic deltaOps;

      // Обработка разных форматов
      if (decodedJson is Map<String, dynamic>) {
        if (decodedJson.containsKey('ops')) {
          // Стандартный формат с ключом 'ops'
          deltaOps = decodedJson['ops'];
        } else {
          // Map без 'ops' - не можем интерпретировать как Delta
          return content.trim();
        }
      } else if (decodedJson is List) {
        // Список операций без обертки 'ops'
        deltaOps = decodedJson;
      } else if (decodedJson is String) {
        // JSON декодирован как строка - возвращаем как есть
        return decodedJson.trim();
      } else {
        // Неизвестный формат
        return content.trim();
      }

      // Проверяем, что deltaOps - список
      if (deltaOps is! List) {
        return content.trim();
      }

      // Создаем Delta из операций
      final delta = Delta.fromJson(deltaOps);

      // Используем Document для получения текста
      final doc = quill.Document.fromDelta(delta);
      final plainText = doc.toPlainText().trim();

      return (plainText.isEmpty || plainText == '\n') ? '' : plainText;
    } catch (e) {
      // Обработка ошибок - пытаемся извлечь текст напрямую
      try {
        // Проверяем, это может быть пустая Delta
        const emptyDeltaJson = '{"ops":[{"insert":"\\n"}]}';
        const emptyDeltaJsonWithoutNewline = '{"ops":[{"insert":""}]}';
        if (content == emptyDeltaJson ||
            content == emptyDeltaJsonWithoutNewline) {
          return '';
        }

        // Если это просто текст, возвращаем его
        if (!content.contains('{') && !content.contains('[')) {
          return content.trim();
        }

        // Пытаемся вручную извлечь текст из операций
        final decodedContent = json.decode(content);
        if (decodedContent is Map && decodedContent.containsKey('ops')) {
          final ops = decodedContent['ops'];
          if (ops is List) {
            return ops.fold<String>('', (text, op) {
              if (op is Map &&
                  op.containsKey('insert') &&
                  op['insert'] is String) {
                return text + op['insert'];
              }
              return text;
            }).trim();
          }
        }

        return '';
      } catch (innerError) {
        // При любой другой ошибке возвращаем пустую строку
        return '';
      }
    }
  }

  // Сокращенная версия для превью с ограничением длины
  String get previewText {
    final text = plainTextContent.trim();
    if (text.isEmpty) return '';

    // Берем только первую строку текста
    final firstLineBreak = text.indexOf('\n');
    if (firstLineBreak > 0) {
      return text.substring(0, firstLineBreak);
    }

    // Ограничиваем длину превью
    if (text.length > 100) {
      return '${text.substring(0, 100)}...';
    }

    return text;
  }

  // Метод для получения следующих дат повторяющегося напоминания
  List<DateTime> getNextRecurringDates(int count) {
    if (recurringReminder == null) return [];

    final result = <DateTime>[];
    final reminder = recurringReminder!;
    DateTime currentDate = reminder.startDate;

    // Проверяем, не превысила ли startDate текущую дату
    if (currentDate.isBefore(DateTime.now())) {
      // Рассчитываем следующую дату после текущей
      final now = DateTime.now();

      switch (reminder.period) {
        case RecurringPeriod.daily:
          // Рассчитываем количество дней, прошедших с начала
          final daysDiff = now.difference(currentDate).inDays;
          currentDate = currentDate.add(Duration(days: daysDiff + 1));
          break;
        case RecurringPeriod.weekly:
          // Рассчитываем количество недель, прошедших с начала
          final weeksDiff = now.difference(currentDate).inDays ~/ 7;
          currentDate = currentDate.add(Duration(days: (weeksDiff + 1) * 7));
          break;
        case RecurringPeriod.monthly:
          // Прибавляем месяцы к исходной дате, пока не получим будущую дату
          var months = 0;
          while (currentDate.isBefore(now)) {
            months++;
            currentDate = DateTime(
              currentDate.year + (currentDate.month + months) ~/ 12,
              (currentDate.month + months) % 12 == 0
                  ? 12
                  : (currentDate.month + months) % 12,
              currentDate.day,
            );
          }
          break;
        case RecurringPeriod.custom:
          // Рассчитываем количество кастомных периодов
          final customPeriodsDiff =
              now.difference(currentDate).inDays ~/ reminder.customDays;
          currentDate = currentDate.add(
            Duration(days: (customPeriodsDiff + 1) * reminder.customDays),
          );
          break;
      }
    }

    // Установить правильное время дня
    currentDate = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
      reminder.timeOfDay.hour,
      reminder.timeOfDay.minute,
    );

    // Генерируем следующие даты
    for (var i = 0; i < count; i++) {
      if (reminder.endDate != null && currentDate.isAfter(reminder.endDate!)) {
        break; // Прекращаем, если достигли конечной даты
      }

      result.add(currentDate);

      // Вычисляем следующую дату
      switch (reminder.period) {
        case RecurringPeriod.daily:
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case RecurringPeriod.weekly:
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case RecurringPeriod.monthly:
          // Переходим к следующему месяцу, сохраняя тот же день
          var nextMonth = currentDate.month + 1;
          var nextYear = currentDate.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }

          // Проверяем количество дней в следующем месяце
          var daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
          var day = currentDate.day;
          if (day > daysInNextMonth) {
            day = daysInNextMonth; // Устанавливаем последний день месяца
          }

          currentDate = DateTime(
            nextYear,
            nextMonth,
            day,
            reminder.timeOfDay.hour,
            reminder.timeOfDay.minute,
          );
          break;
        case RecurringPeriod.custom:
          currentDate = currentDate.add(Duration(days: reminder.customDays));
          break;
      }
    }

    return result;
  }

  const Note({
    required this.id,
    required this.content,
    required this.themeIds,
    required this.createdAt,
    required this.updatedAt,
    this.hasDeadline = false,
    this.deadlineDate,
    this.hasDateLink = false,
    this.linkedDate,
    this.isCompleted = false,
    this.isFavorite = false,
    this.mediaUrls = const [],
    this.emoji,
    this.reminderDates,
    this.reminderSound,
    this.reminderType = ReminderType.exactTime,
    this.relativeReminder,
    this.recurringReminder,
    this.deadlineExtensions,
    this.voiceNotes = const [],
  });

  Note copyWith({
    String? id,
    String? content,
    List<String>? themeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasDeadline,
    DateTime? deadlineDate,
    bool? hasDateLink,
    DateTime? linkedDate,
    bool? isCompleted,
    bool? isFavorite,
    List<String>? mediaUrls,
    String? emoji,
    List<DateTime>? reminderDates,
    String? reminderSound,
    ReminderType? reminderType,
    RelativeReminder? relativeReminder,
    RecurringReminder? recurringReminder,
    List<DeadlineExtension>? deadlineExtensions,
    List<String>? voiceNotes,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      themeIds: themeIds ?? this.themeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasDeadline: hasDeadline ?? this.hasDeadline,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      hasDateLink: hasDateLink ?? this.hasDateLink,
      linkedDate: linkedDate ?? this.linkedDate,
      isCompleted: isCompleted ?? this.isCompleted,
      isFavorite: isFavorite ?? this.isFavorite,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      emoji: emoji ?? this.emoji,
      reminderDates: reminderDates ?? this.reminderDates,
      reminderSound: reminderSound ?? this.reminderSound,
      reminderType: reminderType ?? this.reminderType,
      relativeReminder: relativeReminder ?? this.relativeReminder,
      recurringReminder: recurringReminder ?? this.recurringReminder,
      deadlineExtensions: deadlineExtensions ?? this.deadlineExtensions,
      voiceNotes: voiceNotes ?? this.voiceNotes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Note &&
        other.id == id &&
        other.content == content &&
        listEquals(other.themeIds, themeIds) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.hasDeadline == hasDeadline &&
        other.deadlineDate == deadlineDate &&
        other.hasDateLink == hasDateLink &&
        other.linkedDate == linkedDate &&
        other.isCompleted == isCompleted &&
        other.isFavorite == isFavorite &&
        listEquals(other.mediaUrls, mediaUrls) &&
        other.emoji == emoji &&
        listEquals(other.reminderDates, reminderDates) &&
        other.reminderSound == reminderSound &&
        other.reminderType == reminderType &&
        other.relativeReminder == relativeReminder &&
        other.recurringReminder == recurringReminder &&
        listEquals(other.deadlineExtensions, deadlineExtensions) &&
        listEquals(other.voiceNotes, voiceNotes);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        themeIds.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        hasDeadline.hashCode ^
        deadlineDate.hashCode ^
        hasDateLink.hashCode ^
        linkedDate.hashCode ^
        isCompleted.hashCode ^
        isFavorite.hashCode ^
        mediaUrls.hashCode ^
        emoji.hashCode ^
        reminderDates.hashCode ^
        reminderSound.hashCode ^
        reminderType.hashCode ^
        relativeReminder.hashCode ^
        recurringReminder.hashCode ^
        deadlineExtensions.hashCode ^
        voiceNotes.hashCode;
  }

  @override
  String toString() {
    return 'Note(id: $id, content: ${content.substring(0, 20)}..., themes: ${themeIds.length}, deadline: $hasDeadline, linked: $hasDateLink, fav: $isFavorite)';
  }

  // Методы fromMap и toMap
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      content: map['content'] as String,
      themeIds: List<String>.from(
        (map['themeIds'] as List<dynamic>? ?? []).cast<String>(),
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      hasDeadline: (map['hasDeadline'] as int? ?? 0) == 1,
      deadlineDate:
          map['deadlineDate'] != null
              ? DateTime.parse(map['deadlineDate'] as String)
              : null,
      hasDateLink: (map['hasDateLink'] as int? ?? 0) == 1,
      linkedDate:
          map['linkedDate'] != null
              ? DateTime.parse(map['linkedDate'] as String)
              : null,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      isFavorite: (map['isFavorite'] as int? ?? 0) == 1,
      mediaUrls: List<String>.from(
        (map['mediaUrls'] as List<dynamic>? ?? []).cast<String>(),
      ),
      emoji: map['emoji'] as String?,
      reminderDates:
          (map['reminderDates'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList(),
      reminderSound: map['reminderSound'] as String?,
      reminderType:
          ReminderType.values[map['reminderType'] as int? ??
              ReminderType.exactTime.index],
      relativeReminder:
          map['relativeReminder'] != null
              ? RelativeReminder.fromMap(
                Map<String, dynamic>.from(
                  json.decode(map['relativeReminder'] as String),
                ),
              )
              : null,
      recurringReminder:
          map['recurringReminder'] != null
              ? RecurringReminder.fromMap(
                Map<String, dynamic>.from(
                  json.decode(map['recurringReminder'] as String),
                ),
              )
              : null,
      deadlineExtensions:
          (map['deadlineExtensions'] as List<dynamic>?)
              ?.map(
                (e) => DeadlineExtension.fromMap(
                  Map<String, dynamic>.from(json.decode(e as String)),
                ),
              )
              .toList(),
      voiceNotes: List<String>.from(
        (map['voiceNotes'] as List<dynamic>? ?? []).cast<String>(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'themeIds': themeIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasDeadline': hasDeadline ? 1 : 0,
      'deadlineDate': deadlineDate?.toIso8601String(),
      'hasDateLink': hasDateLink ? 1 : 0,
      'linkedDate': linkedDate?.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'mediaUrls': mediaUrls,
      'emoji': emoji,
      'reminderDates': reminderDates?.map((e) => e.toIso8601String()).toList(),
      'reminderSound': reminderSound,
      'reminderType': reminderType.index,
      'relativeReminder':
          relativeReminder != null
              ? json.encode(relativeReminder!.toMap())
              : null,
      'recurringReminder':
          recurringReminder != null
              ? json.encode(recurringReminder!.toMap())
              : null,
      'deadlineExtensions':
          deadlineExtensions?.map((e) => json.encode(e.toMap())).toList(),
      'voiceNotes': voiceNotes,
    };
  }
}

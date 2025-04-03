// lib/models/note.dart
import 'dart:convert';

// Перечисление для типа напоминания
enum ReminderType {
  exactTime, // Точное время
  relativeTime, // Относительное время (до дедлайна)
  recurring // Повторяющееся
}

// Перечисление для типа повторения
enum RepeatType {
  daily, // Ежедневно
  weekdays, // По будням
  weekly, // Еженедельно
  monthly, // Ежемесячно
  custom // Пользовательское (каждые N дней)
}

// Класс для относительного напоминания
class RelativeReminder {
  final int minutes; // количество минут до дедлайна
  final String description; // описание, например "За 1 час"

  RelativeReminder({
    required this.minutes,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'minutes': minutes,
      'description': description,
    };
  }

  factory RelativeReminder.fromMap(Map<String, dynamic> map) {
    return RelativeReminder(
      minutes: map['minutes'] as int,
      description: map['description'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory RelativeReminder.fromJson(String source) =>
      RelativeReminder.fromMap(json.decode(source));
}

// Класс для повторяющегося напоминания
class RecurringReminder {
  final RepeatType repeatType; // Тип повторения
  final int interval; // Интервал (для custom)
  final List<bool> weekdays; // Дни недели (для weekly)
  final DateTime? endDate; // Дата окончания повторений

  RecurringReminder({
    required this.repeatType,
    this.interval = 1,
    this.weekdays = const [false, false, false, false, false, false, false],
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'repeatType': repeatType.index,
      'interval': interval,
      'weekdays': weekdays,
      'endDate': endDate?.millisecondsSinceEpoch,
    };
  }

  factory RecurringReminder.fromMap(Map<String, dynamic> map) {
    return RecurringReminder(
      repeatType: RepeatType.values[map['repeatType'] as int],
      interval: map['interval'] as int,
      weekdays: List<bool>.from(map['weekdays']),
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecurringReminder.fromJson(String source) =>
      RecurringReminder.fromMap(json.decode(source));
}

class Note {
  final String id;
  String content;
  List<String> themeIds;
  DateTime createdAt;
  DateTime updatedAt;
  bool hasDeadline;
  DateTime? deadlineDate;
  bool hasDateLink;
  DateTime? linkedDate;
  bool isCompleted;
  List<String> mediaUrls;
  String? emoji;

  // Поля для напоминаний
  List<DateTime>? reminderDates; // Сохраняем для обратной совместимости
  String? reminderSound;

  // Тип напоминания
  ReminderType reminderType = ReminderType.exactTime;

  // Данные для разных типов напоминаний
  RelativeReminder? relativeReminder; // Для относительного типа
  RecurringReminder? recurringReminder; // Для повторяющегося типа

  List<DeadlineExtension>? deadlineExtensions;
  bool isFavorite;
  List<String> voiceNotes;

  Note({
    required this.id,
    required this.content,
    required this.themeIds,
    required this.createdAt,
    required this.updatedAt,
    required this.hasDeadline,
    this.deadlineDate,
    required this.hasDateLink,
    this.linkedDate,
    required this.isCompleted,
    this.isFavorite = false,
    required this.mediaUrls,
    this.emoji,
    this.reminderDates,
    this.reminderSound,
    this.reminderType = ReminderType.exactTime,
    this.relativeReminder,
    this.recurringReminder,
    this.deadlineExtensions,
    this.voiceNotes = const [],
  });

  bool get isQuickNote => !hasDeadline && !hasDateLink;

  // Хелперы для определения типов контента в заметке
  bool get hasImages => mediaUrls.any((url) =>
      url.endsWith('.jpg') || url.endsWith('.png') || url.endsWith('.jpeg'));
  bool get hasAudio => mediaUrls.any((url) =>
      url.endsWith('.mp3') || url.endsWith('.wav') || url.endsWith('.m4a'));
  bool get hasFiles => mediaUrls.any((url) =>
      url.endsWith('.pdf') || url.endsWith('.doc') || url.endsWith('.txt'));
  bool get hasVoiceNotes => voiceNotes.isNotEmpty;

  // Хелпер для проверки наличия напоминаний
  bool get hasReminders =>
      (reminderDates != null && reminderDates!.isNotEmpty) ||
      relativeReminder != null ||
      recurringReminder != null;

  // Хелпер для получения "заголовка" из контента
  String get previewText {
    if (content.isEmpty) return "Empty note";
    final preview =
        content.length <= 50 ? content : '${content.substring(0, 47)}...';
    return preview;
  }

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'themeIds': themeIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'hasDeadline': hasDeadline ? 1 : 0,
      'deadlineDate': deadlineDate?.millisecondsSinceEpoch,
      'hasDateLink': hasDateLink ? 1 : 0,
      'linkedDate': linkedDate?.millisecondsSinceEpoch,
      'isCompleted': isCompleted ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'mediaUrls': json.encode(mediaUrls),
      'emoji': emoji,
      'reminderDates':
          reminderDates?.map((x) => x.millisecondsSinceEpoch).toList(),
      'reminderSound': reminderSound,
      'reminderType': reminderType.index,
      'relativeReminder': relativeReminder?.toMap(),
      'recurringReminder': recurringReminder?.toMap(),
      'deadlineExtensions': deadlineExtensions?.map((x) => x.toMap()).toList(),
      'voiceNotes': json.encode(voiceNotes),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    // Обработка типа напоминания
    ReminderType reminderType = ReminderType.exactTime; // По умолчанию
    if (map['reminderType'] != null) {
      final int typeIndex = map['reminderType'] as int;
      if (typeIndex >= 0 && typeIndex < ReminderType.values.length) {
        reminderType = ReminderType.values[typeIndex];
      }
    }

    // Обработка относительного напоминания
    RelativeReminder? relativeReminder;
    if (map['relativeReminder'] != null) {
      try {
        final Map<String, dynamic> reminderMap =
            map['relativeReminder'] is String
                ? json.decode(map['relativeReminder'] as String)
                : Map<String, dynamic>.from(map['relativeReminder'] as Map);
        relativeReminder = RelativeReminder.fromMap(reminderMap);
      } catch (e) {
        print('Ошибка при десериализации relativeReminder: $e');
      }
    }

    // Обработка повторяющегося напоминания
    RecurringReminder? recurringReminder;
    if (map['recurringReminder'] != null) {
      try {
        final Map<String, dynamic> reminderMap =
            map['recurringReminder'] is String
                ? json.decode(map['recurringReminder'] as String)
                : Map<String, dynamic>.from(map['recurringReminder'] as Map);
        recurringReminder = RecurringReminder.fromMap(reminderMap);
      } catch (e) {
        print('Ошибка при десериализации recurringReminder: $e');
      }
    }

    return Note(
      id: map['id'],
      content: map['content'],
      themeIds: List<String>.from(map['themeIds'] is List
          ? map['themeIds']
          : json.decode(map['themeIds'])),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      hasDeadline: map['hasDeadline'] == 1,
      deadlineDate: map['deadlineDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadlineDate'])
          : null,
      hasDateLink: map['hasDateLink'] == 1,
      linkedDate: map['linkedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['linkedDate'])
          : null,
      isCompleted: map['isCompleted'] == 1,
      isFavorite: map['isFavorite'] == 1,
      mediaUrls: List<String>.from(json.decode(map['mediaUrls'])),
      emoji: map['emoji'],
      reminderDates: map['reminderDates'] != null
          ? List<DateTime>.from((map['reminderDates'] is String
                  ? json.decode(map['reminderDates'])
                  : map['reminderDates'])
              .map((x) => DateTime.fromMillisecondsSinceEpoch(x)))
          : null,
      reminderSound: map['reminderSound'],
      reminderType: reminderType,
      relativeReminder: relativeReminder,
      recurringReminder: recurringReminder,
      deadlineExtensions: map['deadlineExtensions'] != null
          ? List<DeadlineExtension>.from((map['deadlineExtensions'] is String
                  ? json.decode(map['deadlineExtensions'])
                  : map['deadlineExtensions'])
              .map((x) =>
                  DeadlineExtension.fromMap(Map<String, dynamic>.from(x))))
          : null,
      voiceNotes: map['voiceNotes'] != null
          ? List<String>.from(json.decode(map['voiceNotes']))
          : [],
    );
  }

  String toJson() => json.encode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(json.decode(source));

  // Метод для получения актуального времени напоминания
  // с учетом типа напоминания и дедлайна
  DateTime? getActualReminderDateTime() {
    if (!hasDeadline || deadlineDate == null) {
      return null;
    }

    if (reminderType == ReminderType.exactTime) {
      // Для точного времени возвращаем первую дату из списка
      if (reminderDates == null || reminderDates!.isEmpty) {
        return null;
      }
      return reminderDates!.first;
    } else if (reminderType == ReminderType.relativeTime) {
      // Для относительного времени рассчитываем от дедлайна
      if (relativeReminder == null) {
        return null;
      }

      return deadlineDate!
          .subtract(Duration(minutes: relativeReminder!.minutes));
    } else {
      // Для повторяющегося возвращаем ближайшую дату (за пределами метода)
      return null;
    }
  }

  // Метод для определения, является ли напоминание повторяющимся
  bool get isRecurring =>
      reminderType == ReminderType.recurring && recurringReminder != null;

  // Метод для получения списка дат следующих напоминаний для повторяющегося типа
  List<DateTime> getNextRecurringDates(int maxCount) {
    if (!isRecurring ||
        recurringReminder == null ||
        !hasDeadline ||
        deadlineDate == null) {
      return [];
    }

    List<DateTime> dates = [];
    DateTime startDate = DateTime.now();

    // Определяем дату окончания повторений
    final DateTime endDate = recurringReminder!.endDate ?? deadlineDate!;

    // Если дата окончания уже прошла, возвращаем пустой список
    if (endDate.isBefore(startDate)) {
      return [];
    }

    switch (recurringReminder!.repeatType) {
      case RepeatType.daily:
        // Ежедневные напоминания
        DateTime current = startDate;
        while (dates.length < maxCount && current.isBefore(endDate)) {
          dates.add(current);
          current = current.add(const Duration(days: 1));
        }
        break;

      case RepeatType.weekdays:
        // Напоминания по будням (Пн-Пт)
        DateTime current = startDate;
        while (dates.length < maxCount && current.isBefore(endDate)) {
          // Если день недели 1-5 (Пн-Пт)
          if (current.weekday >= 1 && current.weekday <= 5) {
            dates.add(current);
          }
          current = current.add(const Duration(days: 1));
        }
        break;

      case RepeatType.weekly:
        // Еженедельные напоминания с выбранными днями недели
        DateTime current = startDate;
        while (dates.length < maxCount && current.isBefore(endDate)) {
          // Проверяем день недели (0 - понедельник, 6 - воскресенье)
          int dayOfWeek = current.weekday - 1; // Преобразуем к индексу 0-6
          if (dayOfWeek >= 0 &&
              dayOfWeek < recurringReminder!.weekdays.length &&
              recurringReminder!.weekdays[dayOfWeek]) {
            dates.add(current);
          }
          current = current.add(const Duration(days: 1));
        }
        break;

      case RepeatType.monthly:
        // Ежемесячные напоминания (в тот же день месяца)
        DateTime current = startDate;
        int dayOfMonth = startDate.day;

        while (dates.length < maxCount && current.isBefore(endDate)) {
          // Добавляем месяц и устанавливаем то же число
          DateTime nextMonth = DateTime(current.year, current.month + 1, 1);
          // Определяем последний день следующего месяца
          int lastDayOfMonth =
              DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
          // Выбираем день (с учетом, что в месяце может быть меньше дней)
          int actualDay =
              dayOfMonth <= lastDayOfMonth ? dayOfMonth : lastDayOfMonth;

          current = DateTime(nextMonth.year, nextMonth.month, actualDay);

          if (current.isAfter(startDate) && current.isBefore(endDate)) {
            dates.add(current);
          }
        }
        break;

      case RepeatType.custom:
        // Пользовательский интервал (каждые N дней)
        DateTime current = startDate;
        int interval = recurringReminder!.interval;

        while (dates.length < maxCount && current.isBefore(endDate)) {
          dates.add(current);
          current = current.add(Duration(days: interval));
        }
        break;
    }

    return dates;
  }
}

class DeadlineExtension {
  final DateTime originalDate;
  final DateTime newDate;
  final DateTime extendedAt;

  DeadlineExtension({
    required this.originalDate,
    required this.newDate,
    required this.extendedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalDate': originalDate.millisecondsSinceEpoch,
      'newDate': newDate.millisecondsSinceEpoch,
      'extendedAt': extendedAt.millisecondsSinceEpoch,
    };
  }

  factory DeadlineExtension.fromMap(Map<String, dynamic> map) {
    return DeadlineExtension(
      originalDate: DateTime.fromMillisecondsSinceEpoch(map['originalDate']),
      newDate: DateTime.fromMillisecondsSinceEpoch(map['newDate']),
      extendedAt: DateTime.fromMillisecondsSinceEpoch(map['extendedAt']),
    );
  }
}

enum ReminderType {
  exactTime, // Конкретные даты и время
  relativeTime, // Относительно дедлайна
  recurring, // Повторяющиеся
}

class RelativeReminder {
  final int minutes;

  RelativeReminder({required this.minutes});

  Map<String, dynamic> toJson() {
    return {
      'minutes': minutes,
    };
  }

  factory RelativeReminder.fromJson(Map<String, dynamic> json) {
    return RelativeReminder(
      minutes: json['minutes'] as int,
    );
  }
}

class RecurringReminder {
  final int intervalHours;
  final DateTime startDate;

  RecurringReminder({
    required this.intervalHours,
    required this.startDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'intervalHours': intervalHours,
      'startDate': startDate.toIso8601String(),
    };
  }

  factory RecurringReminder.fromJson(Map<String, dynamic> json) {
    return RecurringReminder(
      intervalHours: json['intervalHours'] as int,
      startDate: DateTime.parse(json['startDate'] as String),
    );
  }
}

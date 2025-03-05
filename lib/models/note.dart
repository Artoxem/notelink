import 'dart:convert';

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
  List<DateTime>? reminderDates;
  String? reminderSound;
  List<DeadlineExtension>? deadlineExtensions;
  bool isFavorite;

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
    this.isFavorite = false, // Новый параметр с значением по умолчанию
    required this.mediaUrls,
    this.emoji,
    this.reminderDates,
    this.reminderSound,
    this.deadlineExtensions,
  });

  bool get isQuickNote => !hasDeadline && !hasDateLink;

  // Хелперы для определения типов контента в заметке
  bool get hasImages => mediaUrls.any((url) =>
      url.endsWith('.jpg') || url.endsWith('.png') || url.endsWith('.jpeg'));
  bool get hasAudio => mediaUrls.any((url) =>
      url.endsWith('.mp3') || url.endsWith('.wav') || url.endsWith('.m4a'));
  bool get hasFiles => mediaUrls.any((url) =>
      url.endsWith('.pdf') || url.endsWith('.doc') || url.endsWith('.txt'));

  // Хелпер для получения "заголовка" из контента - первые несколько слов
  String get previewText {
    if (content.isEmpty) return "Empty note";

    // Возвращаем первые 50 символов или меньше, если контент короче
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
    List<DeadlineExtension>? deadlineExtensions,
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
      deadlineExtensions: deadlineExtensions ?? this.deadlineExtensions,
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
      'deadlineExtensions': deadlineExtensions?.map((x) => x.toMap()).toList(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      isFavorite: map['isFavorite'] == 1,
      content: map['content'],
      themeIds: List<String>.from(map['themeIds']),
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
      mediaUrls: List<String>.from(json.decode(map['mediaUrls'])),
      emoji: map['emoji'],
      reminderDates: map['reminderDates'] != null
          ? List<DateTime>.from(map['reminderDates']
              .map((x) => DateTime.fromMillisecondsSinceEpoch(x)))
          : null,
      reminderSound: map['reminderSound'],
      deadlineExtensions: map['deadlineExtensions'] != null
          ? List<DeadlineExtension>.from(map['deadlineExtensions']
              .map((x) => DeadlineExtension.fromMap(x)))
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Note.fromJson(String source) => Note.fromMap(json.decode(source));
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

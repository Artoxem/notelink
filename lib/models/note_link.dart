import 'dart:convert';

/// Модель для представления связи между заметками
class NoteLink {
  final String id;
  final String sourceNoteId; // ID исходной заметки
  final String targetNoteId; // ID целевой заметки
  final String? themeId; // ID темы (если связь тематическая)
  final LinkType linkType; // Тип связи
  final DateTime createdAt; // Когда была создана связь
  final String? description; // Опциональное описание связи

  NoteLink({
    required this.id,
    required this.sourceNoteId,
    required this.targetNoteId,
    this.themeId,
    required this.linkType,
    required this.createdAt,
    this.description,
  });

  // Проверка, является ли связь тематической
  bool get isThemeLink => themeId != null && linkType == LinkType.theme;

  // Проверка, является ли связь прямой
  bool get isDirectLink => linkType == LinkType.direct;

  // Хелперы для получения цвета линии связи и т.д. могут быть добавлены здесь

  NoteLink copyWith({
    String? id,
    String? sourceNoteId,
    String? targetNoteId,
    String? themeId,
    LinkType? linkType,
    DateTime? createdAt,
    String? description,
  }) {
    return NoteLink(
      id: id ?? this.id,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
      targetNoteId: targetNoteId ?? this.targetNoteId,
      themeId: themeId ?? this.themeId,
      linkType: linkType ?? this.linkType,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceNoteId': sourceNoteId,
      'targetNoteId': targetNoteId,
      'themeId': themeId,
      'linkType': linkType.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'description': description,
    };
  }

  factory NoteLink.fromMap(Map<String, dynamic> map) {
    return NoteLink(
      id: map['id'],
      sourceNoteId: map['sourceNoteId'],
      targetNoteId: map['targetNoteId'],
      themeId: map['themeId'],
      linkType: LinkType.values[map['linkType']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      description: map['description'],
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteLink.fromJson(String source) =>
      NoteLink.fromMap(json.decode(source));

  @override
  String toString() {
    return 'NoteLink(id: $id, sourceNoteId: $sourceNoteId, targetNoteId: $targetNoteId, themeId: $themeId, linkType: $linkType, createdAt: $createdAt, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NoteLink &&
        other.id == id &&
        other.sourceNoteId == sourceNoteId &&
        other.targetNoteId == targetNoteId &&
        other.themeId == themeId &&
        other.linkType == linkType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        sourceNoteId.hashCode ^
        targetNoteId.hashCode ^
        themeId.hashCode ^
        linkType.hashCode;
  }
}

/// Типы связей между заметками
enum LinkType {
  direct, // Прямая ссылка, созданная пользователем
  theme, // Связь через общую тему
  deadline, // Связь по дедлайну
  reference // Автоматическая ссылка (по тексту)
}

import 'dart:convert';

class NoteTheme {
  final String id;
  String name;
  String? description;
  String color;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> noteIds;

  NoteTheme({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.noteIds,
  });

  NoteTheme copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? noteIds,
  }) {
    return NoteTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteIds: noteIds ?? this.noteIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'noteIds': noteIds,
    };
  }

  factory NoteTheme.fromMap(Map<String, dynamic> map) {
    return NoteTheme(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      color: map['color'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      noteIds: List<String>.from(map['noteIds']),
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteTheme.fromJson(String source) =>
      NoteTheme.fromMap(json.decode(source));
}

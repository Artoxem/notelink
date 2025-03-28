// lib/models/theme.dart - использование только ацтекских иконок

import 'dart:convert';

// Перечисление только для ацтекских иконок
enum ThemeLogoType {
  // Сохраняем старые названия для совместимости с базой данных
  // но все они будут отображаться как ацтекские иконки
  book, // будет отображаться как aztec01
  shapes, // будет отображаться как aztec02
  feather, // будет отображаться как aztec03
  scroll, // будет отображаться как aztec04
  microphone, // будет отображаться как aztec05
  code, // будет отображаться как aztec06
  graduation, // будет отображаться как aztec07
  beach, // будет отображаться как aztec08
  party, // будет отображаться как aztec09
  home, // будет отображаться как aztec10
  business, // будет отображаться как aztec11
  fitness, // будет отображаться как aztec12

  // Дополнительные ацтекские иконки
  aztec13,
  aztec14,
  aztec15,
  aztec16,
  aztec17,
  aztec18,
}

class NoteTheme {
  final String id;
  String name;
  String? description;
  String color;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> noteIds;
  ThemeLogoType logoType;

  NoteTheme({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.noteIds,
    this.logoType = ThemeLogoType.book,
  });

  NoteTheme copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? noteIds,
    ThemeLogoType? logoType,
  }) {
    return NoteTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteIds: noteIds ?? this.noteIds,
      logoType: logoType ?? this.logoType,
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
      'logoType': logoType.index,
    };
  }

  factory NoteTheme.fromMap(Map<String, dynamic> map) {
    ThemeLogoType parsedLogoType;
    try {
      if (map['logoType'] != null &&
          map['logoType'] is int &&
          map['logoType'] >= 0 &&
          map['logoType'] < ThemeLogoType.values.length) {
        parsedLogoType = ThemeLogoType.values[map['logoType']];
      } else {
        parsedLogoType = ThemeLogoType.book;
      }
    } catch (e) {
      parsedLogoType = ThemeLogoType.book;
    }

    return NoteTheme(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      color: map['color'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      noteIds: List<String>.from(map['noteIds']),
      logoType: parsedLogoType,
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteTheme.fromJson(String source) =>
      NoteTheme.fromMap(json.decode(source));
}

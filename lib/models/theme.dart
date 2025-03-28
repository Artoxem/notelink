import 'dart:convert';

// Перечисление для всех 55 доступных иконок
enum ThemeLogoType {
  icon01,
  icon02,
  icon03,
  icon04,
  icon05,
  icon06,
  icon07,
  icon08,
  icon09,
  icon10,
  icon11,
  icon12,
  icon13,
  icon14,
  icon15,
  icon16,
  icon17,
  icon18,
  icon19,
  icon20,
  icon21,
  icon22,
  icon23,
  icon24,
  icon25,
  icon26,
  icon27,
  icon28,
  icon29,
  icon30,
  icon31,
  icon32,
  icon33,
  icon34,
  icon35,
  icon36,
  icon37,
  icon38,
  icon39,
  icon40,
  icon41,
  icon42,
  icon43,
  icon44,
  icon45,
  icon46,
  icon47,
  icon48,
  icon49,
  icon50,
  icon51,
  icon52,
  icon53,
  icon54,
  icon55,
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
    this.logoType = ThemeLogoType.icon01,
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
        parsedLogoType = ThemeLogoType.icon01;
      }
    } catch (e) {
      parsedLogoType = ThemeLogoType.icon01;
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

import 'dart:convert';

// Перечисление для типов логотипов тем
enum ThemeLogoType {
  book, // Существующая константа - книга
  shapes, // Существующая константа - фигуры
  feather, // Существующая константа - перо
  scroll, // Существующая константа - свиток
  microphone, // Аудио контент (микрофон)
  code, // IT/Программирование
  graduation, // Образование (шапка магистра)
  beach, // Отдых/Релаксация
  party, // Вечеринки/События
  home, // Домашние дела
  business, // Бизнес/Работа
  fitness // Здоровье/Спорт
}

class NoteTheme {
  final String id;
  String name;
  String? description;
  String color;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> noteIds;
  ThemeLogoType logoType; // Добавлено новое поле

  NoteTheme({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.noteIds,
    this.logoType = ThemeLogoType.book, // По умолчанию книга
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
      'logoType': logoType.index, // Сохраняем индекс перечисления
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
      logoType: map['logoType'] != null
          ? ThemeLogoType.values[map['logoType']]
          : ThemeLogoType.book, // Обработка случая, когда поле отсутствует
    );
  }

  String toJson() => json.encode(toMap());

  factory NoteTheme.fromJson(String source) =>
      NoteTheme.fromMap(json.decode(source));
}

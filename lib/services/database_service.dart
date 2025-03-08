import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import '../models/note.dart';
import 'dart:convert';
import '../models/theme.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'note_link.db');
    print('Путь к базе данных: $path');

    // ⚠️Принудительно удаляем БД при каждом запуске для отладки⚠️
    //print('⚠️ Удаление существующей базы данных для отладки');
    // await deleteDatabase(path);
    //print('✅ База данных очищена');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onOpen: (db) async {
        // Выведем информацию о созданных таблицах
        final tables = await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        print(
            '📋 Таблицы в базе данных: ${tables.map((t) => t['name']).join(', ')}');

        // Проверим структуру таблицы notes
        final notesColumns = await db.rawQuery('PRAGMA table_info(notes)');
        print(
            '📋 Структура таблицы notes: ${notesColumns.map((c) => c['name']).join(', ')}');

        // Проверим структуру таблицы themes
        final themesColumns = await db.rawQuery('PRAGMA table_info(themes)');
        print(
            '📋 Структура таблицы themes: ${themesColumns.map((c) => c['name']).join(', ')}');
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    print('🔧 Создание таблиц базы данных...');

    // ВАЖНО: Следите за пунктуацией и синтаксисом SQL
    // Создаем таблицу заметок
    await db.execute('''
  CREATE TABLE notes(
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL,
    hasDeadline INTEGER NOT NULL,
    deadlineDate INTEGER,
    hasDateLink INTEGER NOT NULL,
    linkedDate INTEGER,
    isCompleted INTEGER NOT NULL,
    isFavorite INTEGER NOT NULL,
    mediaUrls TEXT NOT NULL,
    emoji TEXT,
    reminderDates TEXT,
    reminderSound TEXT,
    deadlineExtensions TEXT
  )
  ''');
    print('✅ Создана таблица notes');

    // Создаем таблицу тем
    await db.execute('''
  CREATE TABLE themes(
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT NOT NULL,
    createdAt INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL
  )
  ''');
    print('✅ Создана таблица themes');

    // Создаем таблицу для связей заметок с темами
    await db.execute('''
  CREATE TABLE note_theme(
    noteId TEXT,
    themeId TEXT,
    PRIMARY KEY (noteId, themeId),
    FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE CASCADE,
    FOREIGN KEY (themeId) REFERENCES themes(id) ON DELETE CASCADE
  )
  ''');
    print('✅ Создана таблица note_theme');
   
    // Таблица для истории поиска
    await db.execute('''
  CREATE TABLE search_history(
    id TEXT PRIMARY KEY,
    query TEXT NOT NULL,
    createdAt INTEGER NOT NULL
  )
  ''');
    print('✅ Создана таблица search_history');
  }

  // CRUD операции для Note
  Future<String> insertNote(Note note) async {
    final db = await database;
    print('💾 Вставка заметки в БД: ${note.id}');

    try {
      await db.insert('notes', {
        'id': note.id,
        'content': note.content,
        'createdAt': note.createdAt.millisecondsSinceEpoch,
        'updatedAt': note.updatedAt.millisecondsSinceEpoch,
        'hasDeadline': note.hasDeadline ? 1 : 0,
        'deadlineDate': note.deadlineDate?.millisecondsSinceEpoch,
        'hasDateLink': note.hasDateLink ? 1 : 0,
        'linkedDate': note.linkedDate?.millisecondsSinceEpoch,
        'isCompleted': note.isCompleted ? 1 : 0,
        'isFavorite': note.isFavorite ? 1 : 0,
        'mediaUrls': json.encode(note.mediaUrls),
        'emoji': note.emoji,
        'reminderDates': note.reminderDates != null
            ? json.encode(note.reminderDates!
                .map((x) => x.millisecondsSinceEpoch)
                .toList())
            : null,
        'reminderSound': note.reminderSound,
        'deadlineExtensions': note.deadlineExtensions != null
            ? json
                .encode(note.deadlineExtensions!.map((x) => x.toMap()).toList())
            : null,
      });

      print('✅ SQL: Заметка успешно вставлена в БД');

      // Добавляем связи с темами
      for (final themeId in note.themeIds) {
        await db.insert('note_theme', {
          'noteId': note.id,
          'themeId': themeId,
        });
      }

      return note.id;
    } catch (e) {
      print('❌ Ошибка при вставке заметки в БД: $e');
      throw e;
    }
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('notes');

    return Future.wait(maps.map((map) async {
      // Получаем темы для заметки
      final themeIds = await getThemeIdsForNote(map['id'] as String);

      return Note(
        id: map['id'] as String,
        content: map['content'] as String,
        themeIds: themeIds,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        hasDeadline: (map['hasDeadline'] as int) == 1,
        deadlineDate: map['deadlineDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deadlineDate'] as int)
            : null,
        hasDateLink: (map['hasDateLink'] as int) == 1,
        linkedDate: map['linkedDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['linkedDate'] as int)
            : null,
        isCompleted: (map['isCompleted'] as int) == 1,
        isFavorite: (map['isFavorite'] as int) ==
            1, // Добавляем загрузку флага избранного!
        mediaUrls: List<String>.from(json.decode(map['mediaUrls'] as String)),
        emoji: map['emoji'] as String?,
        reminderDates: map['reminderDates'] != null
            ? List<DateTime>.from(
                (json.decode(map['reminderDates'] as String) as List)
                    .map((x) => DateTime.fromMillisecondsSinceEpoch(x as int)))
            : null,
        reminderSound: map['reminderSound'] as String?,
        deadlineExtensions: map['deadlineExtensions'] != null
            ? List<DeadlineExtension>.from(
                (json.decode(map['deadlineExtensions'] as String) as List).map(
                    (x) => DeadlineExtension.fromMap(
                        Map<String, dynamic>.from(x as Map))))
            : null,
      );
    }).toList());
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    print(
        '📊 SELECT * FROM notes WHERE id = $id'); // Добавляем логирование SQL-запроса

    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    // Выводим все поля заметки для отладки
    print('📊 Данные из БД: ${map.toString()}');

    final themeIds = await getThemeIdsForNote(id);

    return Note(
      id: map['id'] as String,
      content: map['content'] as String,
      themeIds: themeIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      hasDeadline: (map['hasDeadline'] as int) == 1,
      deadlineDate: map['deadlineDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadlineDate'] as int)
          : null,
      hasDateLink: (map['hasDateLink'] as int) == 1,
      linkedDate: map['linkedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['linkedDate'] as int)
          : null,
      isCompleted: (map['isCompleted'] as int) == 1,
      isFavorite:
          (map['isFavorite'] as int) == 1, // Убедимся, что поле загружается
      mediaUrls: List<String>.from(json.decode(map['mediaUrls'] as String)),
      emoji: map['emoji'] as String?,
      reminderDates: map['reminderDates'] != null
          ? List<DateTime>.from(
              (json.decode(map['reminderDates'] as String) as List)
                  .map((x) => DateTime.fromMillisecondsSinceEpoch(x as int)))
          : null,
      reminderSound: map['reminderSound'] as String?,
      deadlineExtensions: map['deadlineExtensions'] != null
          ? List<DeadlineExtension>.from(
              (json.decode(map['deadlineExtensions'] as String) as List).map(
                  (x) => DeadlineExtension.fromMap(
                      Map<String, dynamic>.from(x as Map))))
          : null,
    );
  }

  Future<List<String>> getThemeIdsForNote(String noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_theme',
      columns: ['themeId'],
      where: 'noteId = ?',
      whereArgs: [noteId],
    );

    return List.generate(maps.length, (i) => maps[i]['themeId'] as String);
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    print('📊 Обновление заметки в БД: ${note.id}');
    print('📊 isFavorite = ${note.isFavorite}');

    final updateMap = {
      'content': note.content,
      'updatedAt': note.updatedAt.millisecondsSinceEpoch,
      'hasDeadline': note.hasDeadline ? 1 : 0,
      'deadlineDate': note.deadlineDate?.millisecondsSinceEpoch,
      'hasDateLink': note.hasDateLink ? 1 : 0,
      'linkedDate': note.linkedDate?.millisecondsSinceEpoch,
      'isCompleted': note.isCompleted ? 1 : 0,
      'isFavorite':
          note.isFavorite ? 1 : 0, // Убедимся что это поле точно передается
      'mediaUrls': json.encode(note.mediaUrls),
      'emoji': note.emoji,
      'reminderDates': note.reminderDates != null
          ? json.encode(
              note.reminderDates!.map((x) => x.millisecondsSinceEpoch).toList())
          : null,
      'reminderSound': note.reminderSound,
      'deadlineExtensions': note.deadlineExtensions != null
          ? json.encode(note.deadlineExtensions!.map((x) => x.toMap()).toList())
          : null,
    };

    print('📊 Полное содержимое для обновления: $updateMap');

    // Обновляем заметку
    final result = await db.update(
      'notes',
      updateMap,
      where: 'id = ?',
      whereArgs: [note.id],
    );

    print('📊 Результат обновления: $result строк затронуто');

    // Сразу проверяем, что данные сохранились корректно
    final check = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [note.id],
    );

    if (check.isNotEmpty) {
      print(
          '📊 Проверка после обновления: isFavorite = ${check.first['isFavorite']}');
    }

    return result;
  }

  Future<int> deleteNote(String id) async {
    final db = await database;

    // Удаляем связи с темами (каскадное удаление)
    await db.delete(
      'note_theme',
      where: 'noteId = ?',
      whereArgs: [id],
    );

    // Удаляем связи с другими заметками (если используется внешний ключ с ON DELETE CASCADE,
    // то этот шаг не обязателен, но для надежности оставляем)
    await db.delete(
      'note_links',
      where: 'sourceNoteId = ? OR targetNoteId = ?',
      whereArgs: [id, id],
    );

    // Удаляем саму заметку
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD операции для Theme

  Future<String> insertTheme(NoteTheme theme) async {
    final db = await database;

    // Вставляем тему
    await db.insert('themes', {
      'id': theme.id,
      'name': theme.name,
      'description': theme.description,
      'color': theme.color,
      'createdAt': theme.createdAt.millisecondsSinceEpoch,
      'updatedAt': theme.updatedAt.millisecondsSinceEpoch,
    });

    // Вставляем связи с заметками
    for (final noteId in theme.noteIds) {
      await db.insert('note_theme', {
        'noteId': noteId,
        'themeId': theme.id,
      });
    }

    return theme.id;
  }

  Future<List<NoteTheme>> getThemes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('themes');

    return Future.wait(maps.map((map) async {
      // Получаем заметки для темы
      final noteIds = await getNoteIdsForTheme(map['id'] as String);

      return NoteTheme(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        color: map['color'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        noteIds: noteIds,
      );
    }).toList());
  }

  Future<NoteTheme?> getTheme(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'themes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final noteIds = await getNoteIdsForTheme(id);

    return NoteTheme(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      color: map['color'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      noteIds: noteIds,
    );
  }

  Future<List<String>> getNoteIdsForTheme(String themeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_theme',
      columns: ['noteId'],
      where: 'themeId = ?',
      whereArgs: [themeId],
    );

    return List.generate(maps.length, (i) => maps[i]['noteId'] as String);
  }

  Future<int> updateTheme(NoteTheme theme) async {
    final db = await database;

    // Обновляем тему
    await db.update(
      'themes',
      {
        'name': theme.name,
        'description': theme.description,
        'color': theme.color,
        'updatedAt': theme.updatedAt.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [theme.id],
    );

    // Удаляем старые связи с заметками
    await db.delete(
      'note_theme',
      where: 'themeId = ?',
      whereArgs: [theme.id],
    );

    // Вставляем новые связи с заметками
    for (final noteId in theme.noteIds) {
      await db.insert('note_theme', {
        'noteId': noteId,
        'themeId': theme.id,
      });
    }

    return 1;
  }

  Future<int> deleteTheme(String id) async {
    final db = await database;

    // Удаляем связи с заметками
    await db.delete(
      'note_theme',
      where: 'themeId = ?',
      whereArgs: [id],
    );

    // Удаляем связи в таблице note_links, связанные с этой темой
    await db.update(
      'note_links',
      {'themeId': null},
      where: 'themeId = ?',
      whereArgs: [id],
    );

    // Удаляем саму тему
    return await db.delete(
      'themes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Note>> getNotesForTheme(String themeId) async {
    final db = await database;

    try {
      // Получаем ID заметок, связанных с темой
      final List<Map<String, dynamic>> noteIds = await db.query(
        'note_theme',
        columns: ['noteId'],
        where: 'themeId = ?',
        whereArgs: [themeId],
      );

      if (noteIds.isEmpty) return [];

      // Формируем параметры для безопасного запроса IN
      final List<String> idList =
          noteIds.map((map) => map['noteId'] as String).toList();
      final List<String> placeholders = List.filled(idList.length, '?');

      // Используем параметризованный запрос вместо строковой конкатенации
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT * FROM notes WHERE id IN (${placeholders.join(', ')})',
        idList,
      );

      return Future.wait(maps.map((map) async {
        // Получаем темы для заметки
        final themeIds = await getThemeIdsForNote(map['id'] as String);

        return Note(
          id: map['id'] as String,
          content: map['content'] as String,
          themeIds: themeIds,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
          updatedAt:
              DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
          hasDeadline: (map['hasDeadline'] as int) == 1,
          deadlineDate: map['deadlineDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['deadlineDate'] as int)
              : null,
          hasDateLink: (map['hasDateLink'] as int) == 1,
          linkedDate: map['linkedDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['linkedDate'] as int)
              : null,
          isCompleted: (map['isCompleted'] as int) == 1,
          isFavorite: (map['isFavorite'] as int) == 1,
          mediaUrls: List<String>.from(json.decode(map['mediaUrls'] as String)),
          emoji: map['emoji'] as String?,
          reminderDates: map['reminderDates'] != null
              ? List<DateTime>.from((json.decode(map['reminderDates'] as String)
                      as List)
                  .map((x) => DateTime.fromMillisecondsSinceEpoch(x as int)))
              : null,
          reminderSound: map['reminderSound'] as String?,
          deadlineExtensions: map['deadlineExtensions'] != null
              ? List<DeadlineExtension>.from(
                  (json.decode(map['deadlineExtensions'] as String) as List)
                      .map((x) => DeadlineExtension.fromMap(
                          Map<String, dynamic>.from(x as Map))))
              : null,
        );
      }).toList());
    } catch (e) {
      print('Ошибка при загрузке заметок для темы: $e');
      print(StackTrace.current);
      return [];
    }
  }

    Future<int> deleteNoteLink(String id) async {
    final db = await database;

    return await db.delete(
      'note_links',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNoteLinksByNoteId(String noteId) async {
    final db = await database;

    return await db.delete(
      'note_links',
      where: 'sourceNoteId = ? OR targetNoteId = ?',
      whereArgs: [noteId, noteId],
    );
  }

  // Методы для работы с историей поиска

  Future<void> insertSearchQuery(String id, String query) async {
    final db = await database;

    await db.insert('search_history', {
      'id': id,
      'query': query,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<String>> getSearchHistory(int limit) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) => maps[i]['query'] as String);
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  Future<void> deleteSearchQuery(String query) async {
    final db = await database;
    await db.delete(
      'search_history',
      where: 'query = ?',
      whereArgs: [query],
    );
  }
}

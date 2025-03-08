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

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      // Убираем onOpen с неиспользуемой переменной
    );
  }

  // Обновление БД до новой версии
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Создаем таблицу note_links если она не существует
      await db.execute('''
      CREATE TABLE IF NOT EXISTS note_links(
        id TEXT PRIMARY KEY,
        sourceNoteId TEXT,
        targetNoteId TEXT,
        themeId TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (sourceNoteId) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (targetNoteId) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (themeId) REFERENCES themes(id) ON DELETE SET NULL
      )
      ''');

      // Добавляем индексы для улучшения производительности
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notes_isFavorite ON notes(isFavorite);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notes_isCompleted ON notes(isCompleted);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notes_hasDeadline ON notes(hasDeadline);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_notes_createdAt ON notes(createdAt);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_note_theme_noteId ON note_theme(noteId);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_note_theme_themeId ON note_theme(themeId);');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
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

    // Создаем таблицу связей между заметками
    await db.execute('''
    CREATE TABLE note_links(
      id TEXT PRIMARY KEY,
      sourceNoteId TEXT,
      targetNoteId TEXT,
      themeId TEXT,
      createdAt INTEGER NOT NULL,
      FOREIGN KEY (sourceNoteId) REFERENCES notes(id) ON DELETE CASCADE,
      FOREIGN KEY (targetNoteId) REFERENCES notes(id) ON DELETE CASCADE,
      FOREIGN KEY (themeId) REFERENCES themes(id) ON DELETE SET NULL
    )
    ''');

    // Таблица для истории поиска
    await db.execute('''
    CREATE TABLE search_history(
      id TEXT PRIMARY KEY,
      query TEXT NOT NULL,
      createdAt INTEGER NOT NULL
    )
    ''');

    // Создаем индексы для улучшения производительности
    await db.execute('CREATE INDEX idx_notes_isFavorite ON notes(isFavorite);');
    await db
        .execute('CREATE INDEX idx_notes_isCompleted ON notes(isCompleted);');
    await db
        .execute('CREATE INDEX idx_notes_hasDeadline ON notes(hasDeadline);');
    await db.execute('CREATE INDEX idx_notes_createdAt ON notes(createdAt);');
    await db
        .execute('CREATE INDEX idx_note_theme_noteId ON note_theme(noteId);');
    await db
        .execute('CREATE INDEX idx_note_theme_themeId ON note_theme(themeId);');
  }

  // CRUD операции для Note
  Future<String> insertNote(Note note) async {
    final db = await database;

    try {
      await db.insert('notes', {
        'id': note.id,
        'content': note.content,
        'createdAt': note.createdAt.millisecondsSinceEpoch,
        // Другие поля...
      });

      // Добавляем связи с темами
      for (final themeId in note.themeIds) {
        await db.insert('note_theme', {
          'noteId': note.id,
          'themeId': themeId,
        });
      }

      return note.id;
    } catch (e) {
      // Используем rethrow вместо throw e
      rethrow;
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
        isFavorite: (map['isFavorite'] as int) == 1,
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

  // Оптимизированный вариант для получения заметок с фильтрацией
  Future<List<Note>> getFilteredNotes({
    bool? isFavorite,
    bool? isCompleted,
    bool? hasDeadline,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? themeIds,
  }) async {
    final db = await database;

    List<String> whereConditions = [];
    List<dynamic> whereArgs = [];

    if (isFavorite != null) {
      whereConditions.add('isFavorite = ?');
      whereArgs.add(isFavorite ? 1 : 0);
    }

    if (isCompleted != null) {
      whereConditions.add('isCompleted = ?');
      whereArgs.add(isCompleted ? 1 : 0);
    }

    if (hasDeadline != null) {
      whereConditions.add('hasDeadline = ?');
      whereArgs.add(hasDeadline ? 1 : 0);
    }

    if (fromDate != null) {
      whereConditions.add('createdAt >= ?');
      whereArgs.add(fromDate.millisecondsSinceEpoch);
    }

    if (toDate != null) {
      whereConditions.add('createdAt <= ?');
      whereArgs.add(toDate.millisecondsSinceEpoch);
    }

    String whereClause =
        whereConditions.isEmpty ? '' : 'WHERE ${whereConditions.join(' AND ')}';

    List<Map<String, dynamic>> maps;

    if (themeIds != null && themeIds.isNotEmpty) {
      // Создаем подзапрос для фильтрации по темам
      String query = '''
      SELECT notes.* FROM notes
      INNER JOIN note_theme ON notes.id = note_theme.noteId
      $whereClause
      ${whereClause.isEmpty ? 'WHERE' : 'AND'} note_theme.themeId IN (${List.filled(themeIds.length, '?').join(', ')})
      GROUP BY notes.id
      ORDER BY notes.createdAt DESC
      ''';

      maps = await db.rawQuery(query, [...whereArgs, ...themeIds]);
    } else {
      maps = await db.query(
        'notes',
        where: whereConditions.isEmpty ? null : whereConditions.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'createdAt DESC',
      );
    }

    return Future.wait(maps.map((map) async {
      final List<String> noteThemeIds =
          await getThemeIdsForNote(map['id'] as String);

      return Note(
        id: map['id'] as String,
        content: map['content'] as String,
        themeIds: noteThemeIds,
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
        isFavorite: (map['isFavorite'] as int) == 1,
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

    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
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
      isFavorite: (map['isFavorite'] as int) == 1,
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

    // Начинаем транзакцию для атомарного обновления
    return await db.transaction((txn) async {
      // Обновляем основную информацию о заметке
      final result = await txn.update(
        'notes',
        {
          'content': note.content,
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
              ? json.encode(
                  note.deadlineExtensions!.map((x) => x.toMap()).toList())
              : null,
        },
        where: 'id = ?',
        whereArgs: [note.id],
      );

      // Обновляем связи с темами
      await txn.delete(
        'note_theme',
        where: 'noteId = ?',
        whereArgs: [note.id],
      );

      for (final themeId in note.themeIds) {
        await txn.insert('note_theme', {
          'noteId': note.id,
          'themeId': themeId,
        });
      }

      return result;
    });
  }

  Future<int> deleteNote(String id) async {
    final db = await database;

    // Выполняем в транзакции для обеспечения целостности данных
    return await db.transaction((txn) async {
      // Удаляем связи с темами (каскадное удаление)
      await txn.delete(
        'note_theme',
        where: 'noteId = ?',
        whereArgs: [id],
      );

      // Удаляем связи с другими заметками
      await txn.delete(
        'note_links',
        where: 'sourceNoteId = ? OR targetNoteId = ?',
        whereArgs: [id, id],
      );

      // Удаляем саму заметку
      return await txn.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // CRUD операции для Theme
  Future<String> insertTheme(NoteTheme theme) async {
    final db = await database;

    await db.transaction((txn) async {
      // Вставляем тему
      await txn.insert('themes', {
        'id': theme.id,
        'name': theme.name,
        'description': theme.description,
        'color': theme.color,
        'createdAt': theme.createdAt.millisecondsSinceEpoch,
        'updatedAt': theme.updatedAt.millisecondsSinceEpoch,
      });

      // Вставляем связи с заметками
      for (final noteId in theme.noteIds) {
        await txn.insert('note_theme', {
          'noteId': noteId,
          'themeId': theme.id,
        });
      }
    });

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

    return await db.transaction((txn) async {
      // Обновляем тему
      final result = await txn.update(
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
      await txn.delete(
        'note_theme',
        where: 'themeId = ?',
        whereArgs: [theme.id],
      );

      // Вставляем новые связи с заметками
      for (final noteId in theme.noteIds) {
        await txn.insert('note_theme', {
          'noteId': noteId,
          'themeId': theme.id,
        });
      }

      // Возвращаем результат операции обновления
      return result;
    });
  }

  Future<int> deleteTheme(String id) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Удаляем связи с заметками
      await txn.delete(
        'note_theme',
        where: 'themeId = ?',
        whereArgs: [id],
      );

      // Удаляем связи в таблице note_links, связанные с этой темой
      await txn.update(
        'note_links',
        {'themeId': null},
        where: 'themeId = ?',
        whereArgs: [id],
      );

      // Удаляем саму тему
      return await txn.delete(
        'themes',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Note>> getNotesForTheme(String themeId) async {
    final db = await database;

    try {
      // Оптимизированный запрос с JOIN
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT n.* FROM notes n
        INNER JOIN note_theme nt ON n.id = nt.noteId
        WHERE nt.themeId = ?
        ORDER BY n.createdAt DESC
      ''', [themeId]);

      return Future.wait(maps.map((map) async {
        // Получаем темы для заметки
        final noteThemeIds = await getThemeIdsForNote(map['id'] as String);

        return Note(
          id: map['id'] as String,
          content: map['content'] as String,
          themeIds: noteThemeIds,
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
      return [];
    }
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

  // Метод для пакетного обновления заметок
  Future<void> batchUpdateNotes(List<Note> notes) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final note in notes) {
        await txn.update(
          'notes',
          note.toMap(),
          where: 'id = ?',
          whereArgs: [note.id],
        );
      }
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

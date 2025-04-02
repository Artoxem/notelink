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
  var _dbLock = Completer<void>()..complete(); // Семафор для доступа к БД

  // Стандартные размеры для пагинации
  static const int DEFAULT_PAGE_SIZE = 50;
  static const int MAX_BATCH_SIZE = 100;

  // Получение инстанса базы данных
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Защита от одновременной инициализации из нескольких потоков
    if (!_dbLock.isCompleted) {
      await _dbLock.future;
      if (_database != null) return _database!;
    }

    final newLock = Completer<void>();
    _dbLock = newLock;

    try {
      _database = await _initDatabase();
      // Проверяем и модифицируем таблицы при необходимости
      await ensureThemesTableHasLogoType();
      await ensureNotesTableHasVoiceNotes(); // Добавляем проверку колонки voiceNotes
      await ensureNotesTableHasReminderFields(); // Добавляем новую проверку для полей напоминаний
      newLock.complete();
    } catch (e) {
      print('Критическая ошибка при инициализации базы данных: $e');
      newLock.complete();
      rethrow;
    }

    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'note_link.db');

    return await openDatabase(
      path,
      version: 4, // Увеличиваем версию базы данных для поддержки новых полей
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  // Метод проверки и модификации таблицы notes для поддержки полей напоминаний
  Future<void> ensureNotesTableHasReminderFields() async {
    final db = await database;

    try {
      // Проверяем, есть ли колонка reminderType в таблице notes
      var tableInfo = await db.rawQuery("PRAGMA table_info(notes)");
      bool hasReminderType =
          tableInfo.any((column) => column['name'] == 'reminderType');
      bool hasRelativeReminder =
          tableInfo.any((column) => column['name'] == 'relativeReminder');

      if (!hasReminderType) {
        print('Добавление колонки reminderType в таблицу notes...');
        await db.execute(
            "ALTER TABLE notes ADD COLUMN reminderType INTEGER DEFAULT 0");
        print('Колонка reminderType успешно добавлена');
      }

      if (!hasRelativeReminder) {
        print('Добавление колонки relativeReminder в таблицу notes...');
        await db.execute(
            "ALTER TABLE notes ADD COLUMN relativeReminder TEXT DEFAULT NULL");
        print('Колонка relativeReminder успешно добавлена');
      }
    } catch (e) {
      print('Ошибка при проверке/добавлении колонок для напоминаний: $e');
    }
  }

  // Метод проверки и модификации таблицы notes
  Future<void> ensureNotesTableHasVoiceNotes() async {
    final db = await database;

    try {
      // Проверяем, есть ли колонка voiceNotes в таблице notes
      var tableInfo = await db.rawQuery("PRAGMA table_info(notes)");
      bool hasVoiceNotes =
          tableInfo.any((column) => column['name'] == 'voiceNotes');

      if (!hasVoiceNotes) {
        print('Добавление колонки voiceNotes в таблицу notes...');
        await db.execute(
            "ALTER TABLE notes ADD COLUMN voiceNotes TEXT DEFAULT '[]'");
        print('Колонка voiceNotes успешно добавлена');
      }
    } catch (e) {
      print('Ошибка при проверке/добавлении колонки voiceNotes: $e');
    }
  }

  // Обновление БД до новой версии с детальным логированием
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    try {
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

        // Добавляем индексы для улучшения поиска
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_notes_content ON notes(content);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_notes_deadlineDate ON notes(deadlineDate);');
      }

      // Добавляем поддержку для голосовых заметок, если обновляемся до версии 3
      if (oldVersion < 3) {
        // Проверяем, есть ли уже колонка voiceNotes
        var tableInfo = await db.rawQuery("PRAGMA table_info(notes)");
        bool hasVoiceNotes =
            tableInfo.any((column) => column['name'] == 'voiceNotes');

        if (!hasVoiceNotes) {
          await db.execute(
              "ALTER TABLE notes ADD COLUMN voiceNotes TEXT DEFAULT '[]'");
        }

        // Добавляем колонку logoType для таблицы themes
        var themesTableInfo = await db.rawQuery("PRAGMA table_info(themes)");
        bool hasLogoType =
            themesTableInfo.any((column) => column['name'] == 'logoType');

        if (!hasLogoType) {
          await db.execute(
              "ALTER TABLE themes ADD COLUMN logoType INTEGER DEFAULT 0");
        }

        // После добавления колонки logoType нужно проверить все существующие темы
        // Миграцию данных (из старого формата иконок в новый) лучше выполнить
        // в ThemesProvider после инициализации
        print(
            'База данных обновлена до версии 3. Требуется миграция логотипов тем.');
      }

      // Добавляем поддержку для типа напоминаний и относительных напоминаний
      if (oldVersion < 4) {
        // Проверяем, есть ли уже колонка reminderType
        var tableInfo = await db.rawQuery("PRAGMA table_info(notes)");
        bool hasReminderType =
            tableInfo.any((column) => column['name'] == 'reminderType');
        bool hasRelativeReminder =
            tableInfo.any((column) => column['name'] == 'relativeReminder');

        if (!hasReminderType) {
          print('Добавление колонки reminderType в таблицу notes...');
          await db.execute(
              "ALTER TABLE notes ADD COLUMN reminderType INTEGER DEFAULT 0");
          print('Колонка reminderType успешно добавлена');
        }

        if (!hasRelativeReminder) {
          print('Добавление колонки relativeReminder в таблицу notes...');
          await db.execute(
              "ALTER TABLE notes ADD COLUMN relativeReminder TEXT DEFAULT NULL");
          print('Колонка relativeReminder успешно добавлена');
        }

        print(
            'База данных обновлена до версии 4. Добавлена поддержка типов напоминаний.');
      }
    } catch (e) {
      print('Ошибка обновления базы данных: $e');
      rethrow;
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    try {
      // Создаем таблицу заметок с колонками для напоминаний
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
      deadlineExtensions TEXT,
      voiceNotes TEXT DEFAULT '[]',
      reminderType INTEGER DEFAULT 0,
      relativeReminder TEXT
    )
    ''');

      // Создаем таблицу тем с колонкой logoType
      await db.execute('''
    CREATE TABLE themes(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      color TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      logoType INTEGER DEFAULT 0
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

      // Таблица для истории поиска
      await db.execute('''
    CREATE TABLE search_history(
      id TEXT PRIMARY KEY,
      query TEXT NOT NULL,
      createdAt INTEGER NOT NULL
    )
    ''');

      // Создаем индексы для улучшения производительности
      await db
          .execute('CREATE INDEX idx_notes_isFavorite ON notes(isFavorite);');
      await db
          .execute('CREATE INDEX idx_notes_isCompleted ON notes(isCompleted);');
      await db
          .execute('CREATE INDEX idx_notes_hasDeadline ON notes(hasDeadline);');
      await db.execute('CREATE INDEX idx_notes_createdAt ON notes(createdAt);');
      await db
          .execute('CREATE INDEX idx_note_theme_noteId ON note_theme(noteId);');
      await db.execute(
          'CREATE INDEX idx_note_theme_themeId ON note_theme(themeId);');
      await db.execute('CREATE INDEX idx_notes_content ON notes(content);');
      await db.execute(
          'CREATE INDEX idx_notes_deadlineDate ON notes(deadlineDate);');
    } catch (e) {
      print('Ошибка создания базы данных: $e');
      rethrow;
    }
  }

  // Метод проверки и модификации таблицы themes
  Future<void> ensureThemesTableHasLogoType() async {
    final db = await database;

    try {
      // Проверяем, есть ли колонка logoType в таблице themes
      var tableInfo = await db.rawQuery("PRAGMA table_info(themes)");
      bool hasLogoType =
          tableInfo.any((column) => column['name'] == 'logoType');

      if (!hasLogoType) {
        print('Добавление колонки logoType в таблицу themes...');
        await db.execute(
            "ALTER TABLE themes ADD COLUMN logoType INTEGER DEFAULT 0");
        print('Колонка logoType успешно добавлена');
      }
    } catch (e) {
      print('Ошибка при проверке/добавлении колонки logoType: $e');
    }
  }

  // CRUD операции для Note с транзакциями и обработкой ошибок
  Future<String> insertNote(Note note) async {
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Вставляем заметку
        await txn.insert(
          'notes',
          {
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
                ? json.encode(
                    note.deadlineExtensions!.map((x) => x.toMap()).toList())
                : null,
            'voiceNotes': json.encode(note.voiceNotes),
            'reminderType': note.reminderType.index, // Сохраняем индекс enum
            'relativeReminder': note.relativeReminder != null
                ? json.encode(note.relativeReminder!.toMap())
                : null, // Сохраняем JSON представление
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Добавляем связи с темами в транзакции
        if (note.themeIds.isNotEmpty) {
          final batch = txn.batch();
          for (final themeId in note.themeIds) {
            batch.insert(
              'note_theme',
              {
                'noteId': note.id,
                'themeId': themeId,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        return note.id;
      });
    } catch (e) {
      print('Ошибка при вставке заметки: $e');
      rethrow;
    }
  }

  // Получение заметок с пагинацией
  Future<List<Note>> getNotes(
      {int limit = DEFAULT_PAGE_SIZE, int offset = 0}) async {
    final db = await database;

    try {
      // Сначала получаем основные данные заметок с пагинацией
      final List<Map<String, dynamic>> noteMaps = await db.query(
        'notes',
        limit: limit,
        offset: offset,
        orderBy: 'createdAt DESC',
      );

      if (noteMaps.isEmpty) {
        return [];
      }

      // Собираем все идентификаторы заметок для эффективной загрузки связей
      final List<String> noteIds =
          noteMaps.map<String>((map) => map['id'] as String).toList();

      // Получаем все связи с темами для этих заметок в одном запросе
      final List<Map<String, dynamic>> themeRelations = await db.query(
        'note_theme',
        where: 'noteId IN (${List.filled(noteIds.length, '?').join(', ')})',
        whereArgs: noteIds,
      );

      // Создаем Map для быстрого доступа к связям по ID заметки
      final Map<String, List<String>> noteThemeMap = {};
      for (final relation in themeRelations) {
        final noteId = relation['noteId'] as String;
        final themeId = relation['themeId'] as String;

        noteThemeMap[noteId] ??= [];
        noteThemeMap[noteId]!.add(themeId);
      }

      // Формируем список заметок со связями
      return noteMaps.map((map) {
        final noteId = map['id'] as String;
        final themeIds = noteThemeMap[noteId] ?? [];

        // Десериализация полей reminderType и relativeReminder
        ReminderType reminderType = ReminderType.exactTime; // По умолчанию
        if (map['reminderType'] != null) {
          final int typeIndex = map['reminderType'] as int;
          if (typeIndex >= 0 && typeIndex < ReminderType.values.length) {
            reminderType = ReminderType.values[typeIndex];
          }
        }

        RelativeReminder? relativeReminder;
        if (map['relativeReminder'] != null) {
          try {
            final Map<String, dynamic> reminderMap =
                json.decode(map['relativeReminder'] as String);
            relativeReminder = RelativeReminder.fromMap(reminderMap);
          } catch (e) {
            print('Ошибка при десериализации relativeReminder: $e');
          }
        }

        return Note(
          id: noteId,
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
          voiceNotes: map['voiceNotes'] != null
              ? List<String>.from(json.decode(map['voiceNotes'] as String))
              : [],
          // Добавляем поля для типов напоминаний
          reminderType: reminderType,
          relativeReminder: relativeReminder,
        );
      }).toList();
    } catch (e) {
      print('Ошибка при получении заметок: $e');
      rethrow;
    }
  }

  // Оптимизированный вариант для получения заметок с фильтрацией
  Future<List<Note>> getFilteredNotes({
    bool? isFavorite,
    bool? isCompleted,
    bool? hasDeadline,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? themeIds,
    String? searchQuery,
    int limit = DEFAULT_PAGE_SIZE,
    int offset = 0,
  }) async {
    final db = await database;

    try {
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

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereConditions.add('content LIKE ?');
        whereArgs.add('%$searchQuery%');
      }

      String whereClause = whereConditions.isEmpty
          ? ''
          : 'WHERE ${whereConditions.join(' AND ')}';

      List<Map<String, dynamic>> noteMaps;

      if (themeIds != null && themeIds.isNotEmpty) {
        // Создаем подзапрос для фильтрации по темам
        String query = '''
        SELECT notes.* FROM notes
        INNER JOIN note_theme ON notes.id = note_theme.noteId
        $whereClause
        ${whereClause.isEmpty ? 'WHERE' : 'AND'} note_theme.themeId IN (${List.filled(themeIds.length, '?').join(', ')})
        GROUP BY notes.id
        ORDER BY notes.createdAt DESC
        LIMIT ? OFFSET ?
        ''';

        noteMaps = await db
            .rawQuery(query, [...whereArgs, ...themeIds, limit, offset]);
      } else {
        noteMaps = await db.query(
          'notes',
          where: whereConditions.isEmpty ? null : whereConditions.join(' AND '),
          whereArgs: whereArgs.isEmpty ? null : whereArgs,
          orderBy: 'createdAt DESC',
          limit: limit,
          offset: offset,
        );
      }

      if (noteMaps.isEmpty) {
        return [];
      }

      // Собираем все идентификаторы заметок для эффективной загрузки связей
      final List<String> noteIds =
          noteMaps.map<String>((map) => map['id'] as String).toList();

      // Получаем все связи с темами для этих заметок в одном запросе
      final List<Map<String, dynamic>> themeRelations = await db.query(
        'note_theme',
        where: 'noteId IN (${List.filled(noteIds.length, '?').join(', ')})',
        whereArgs: noteIds,
      );

      // Создаем Map для быстрого доступа к связям по ID заметки
      final Map<String, List<String>> noteThemeMap = {};
      for (final relation in themeRelations) {
        final noteId = relation['noteId'] as String;
        final themeId = relation['themeId'] as String;

        noteThemeMap[noteId] ??= [];
        noteThemeMap[noteId]!.add(themeId);
      }

      // Формируем список заметок со связями
      return noteMaps.map((map) {
        final noteId = map['id'] as String;
        final themeIds = noteThemeMap[noteId] ?? [];

        // Десериализация полей reminderType и relativeReminder
        ReminderType reminderType = ReminderType.exactTime; // По умолчанию
        if (map['reminderType'] != null) {
          final int typeIndex = map['reminderType'] as int;
          if (typeIndex >= 0 && typeIndex < ReminderType.values.length) {
            reminderType = ReminderType.values[typeIndex];
          }
        }

        RelativeReminder? relativeReminder;
        if (map['relativeReminder'] != null) {
          try {
            final Map<String, dynamic> reminderMap =
                json.decode(map['relativeReminder'] as String);
            relativeReminder = RelativeReminder.fromMap(reminderMap);
          } catch (e) {
            print('Ошибка при десериализации relativeReminder: $e');
          }
        }

        return Note(
          id: noteId,
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
          voiceNotes: map['voiceNotes'] != null
              ? List<String>.from(json.decode(map['voiceNotes'] as String))
              : [],
          reminderType: reminderType,
          relativeReminder: relativeReminder,
        );
      }).toList();
    } catch (e) {
      print('Ошибка при получении фильтрованных заметок: $e');
      rethrow;
    }
  }

  // Получение одной заметки с эффективной загрузкой связей
  Future<Note?> getNote(String id) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> noteMaps = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (noteMaps.isEmpty) return null;

      final map = noteMaps.first;

      // Получаем связи с темами для конкретной заметки
      final List<String> themeIds = await getThemeIdsForNote(id);

      // Десериализация полей reminderType и relativeReminder
      ReminderType reminderType = ReminderType.exactTime; // По умолчанию
      if (map['reminderType'] != null) {
        final int typeIndex = map['reminderType'] as int;
        if (typeIndex >= 0 && typeIndex < ReminderType.values.length) {
          reminderType = ReminderType.values[typeIndex];
        }
      }

      RelativeReminder? relativeReminder;
      if (map['relativeReminder'] != null) {
        try {
          final Map<String, dynamic> reminderMap =
              json.decode(map['relativeReminder'] as String);
          relativeReminder = RelativeReminder.fromMap(reminderMap);
        } catch (e) {
          print('Ошибка при десериализации relativeReminder: $e');
        }
      }

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
        voiceNotes: map['voiceNotes'] != null
            ? List<String>.from(json.decode(map['voiceNotes'] as String))
            : [],
        reminderType: reminderType,
        relativeReminder: relativeReminder,
      );
    } catch (e) {
      print('Ошибка при получении заметки: $e');
      rethrow;
    }
  }

  // Оптимизированный метод для получения связей заметки с темами
  Future<List<String>> getThemeIdsForNote(String noteId) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'note_theme',
        columns: ['themeId'],
        where: 'noteId = ?',
        whereArgs: [noteId],
      );

      return List.generate(maps.length, (i) => maps[i]['themeId'] as String);
    } catch (e) {
      print('Ошибка при получении связей заметки с темами: $e');
      rethrow;
    }
  }

  // Оптимизированное обновление заметки
  Future<int> updateNote(Note note) async {
    final db = await database;

    try {
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
            'voiceNotes': json.encode(note.voiceNotes),
            'reminderType': note.reminderType.index, // Сохраняем индекс enum
            'relativeReminder': note.relativeReminder != null
                ? json.encode(note.relativeReminder!.toMap())
                : null, // Сохраняем JSON представление
          },
          where: 'id = ?',
          whereArgs: [note.id],
        );

        // Получаем текущие связи с темами
        final List<Map<String, dynamic>> currentRelations = await txn.query(
          'note_theme',
          columns: ['themeId'],
          where: 'noteId = ?',
          whereArgs: [note.id],
        );

        final List<String> currentThemeIds = currentRelations
            .map<String>((map) => map['themeId'] as String)
            .toList();

        // Определяем, какие связи нужно добавить, а какие удалить
        final Set<String> toAdd = Set<String>.from(note.themeIds)
            .difference(Set<String>.from(currentThemeIds));
        final Set<String> toRemove = Set<String>.from(currentThemeIds)
            .difference(Set<String>.from(note.themeIds));

        // Удаляем ненужные связи
        if (toRemove.isNotEmpty) {
          for (final themeId in toRemove) {
            await txn.delete(
              'note_theme',
              where: 'noteId = ? AND themeId = ?',
              whereArgs: [note.id, themeId],
            );
          }
        }

        // Добавляем новые связи
        if (toAdd.isNotEmpty) {
          final batch = txn.batch();
          for (final themeId in toAdd) {
            batch.insert(
              'note_theme',
              {
                'noteId': note.id,
                'themeId': themeId,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        return result;
      });
    } catch (e) {
      print('Ошибка при обновлении заметки: $e');
      rethrow;
    }
  }

  // Оптимизированное удаление заметки
  Future<int> deleteNote(String id) async {
    final db = await database;

    try {
      // Выполняем в транзакции для обеспечения целостности данных
      return await db.transaction((txn) async {
        // Удаляем связи с темами (каскадное удаление)
        await txn.delete(
          'note_theme',
          where: 'noteId = ?',
          whereArgs: [id],
        );

        // Удаляем саму заметку
        return await txn.delete(
          'notes',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      print('Ошибка при удалении заметки: $e');
      rethrow;
    }
  }

  // Вставка темы
  Future<String> insertTheme(NoteTheme theme) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Подготовка данных с безопасной обработкой logoType
        Map<String, dynamic> themeData = {
          'id': theme.id,
          'name': theme.name,
          'description': theme.description,
          'color': theme.color,
          'createdAt': theme.createdAt.millisecondsSinceEpoch,
          'updatedAt': theme.updatedAt.millisecondsSinceEpoch,
        };

        // Добавляем logoType, используя новое перечисление ThemeLogoType с icon01-icon55
        themeData['logoType'] = theme.logoType.index;

        // Вставляем тему
        await txn.insert(
          'themes',
          themeData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Вставляем связи с заметками пакетом для оптимизации
        if (theme.noteIds.isNotEmpty) {
          final batch = txn.batch();
          for (final noteId in theme.noteIds) {
            batch.insert(
              'note_theme',
              {
                'noteId': noteId,
                'themeId': theme.id,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }
      });

      return theme.id;
    } catch (e) {
      print('Критическая ошибка при вставке темы: $e');
      rethrow;
    }
  }

  // Получение тем с пагинацией
  Future<List<NoteTheme>> getThemes(
      {int limit = DEFAULT_PAGE_SIZE, int offset = 0}) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> themeMaps = await db.query(
        'themes',
        limit: limit,
        offset: offset,
        orderBy: 'name ASC',
      );

      if (themeMaps.isEmpty) {
        return [];
      }

      // Получаем идентификаторы тем для эффективной загрузки связей
      final List<String> themeIds =
          themeMaps.map<String>((map) => map['id'] as String).toList();

      // Получаем все связи с заметками для этих тем в одном запросе
      final List<Map<String, dynamic>> noteRelations = await db.query(
        'note_theme',
        where: 'themeId IN (${List.filled(themeIds.length, '?').join(', ')})',
        whereArgs: themeIds,
      );

      // Создаем Map для быстрого доступа к связям по ID темы
      final Map<String, List<String>> themeNoteMap = {};
      for (final relation in noteRelations) {
        final themeId = relation['themeId'] as String;
        final noteId = relation['noteId'] as String;

        themeNoteMap[themeId] ??= [];
        themeNoteMap[themeId]!.add(noteId);
      }

      // Формируем список тем со связями и учитываем logoType с новыми иконками
      return themeMaps.map((map) {
        final themeId = map['id'] as String;
        final noteIds = themeNoteMap[themeId] ?? [];

        // Проверяем и корректируем logoType, используя новое перечисление
        ThemeLogoType logoType;
        try {
          int logoTypeIndex = map['logoType'] as int? ?? 0;
          // Убедимся, что logoType в допустимом диапазоне
          if (logoTypeIndex >= 0 &&
              logoTypeIndex < ThemeLogoType.values.length) {
            logoType = ThemeLogoType.values[logoTypeIndex];
          } else {
            // Если значение вне диапазона, используем первую иконку
            logoType = ThemeLogoType.icon01;
          }
        } catch (e) {
          // В случае любой ошибки используем первую иконку
          logoType = ThemeLogoType.icon01;
        }

        return NoteTheme(
          id: themeId,
          name: map['name'] as String,
          description: map['description'] as String?,
          color: map['color'] as String,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
          updatedAt:
              DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
          noteIds: noteIds,
          logoType: logoType,
        );
      }).toList();
    } catch (e) {
      print('Ошибка при получении тем: $e');
      rethrow;
    }
  }

  // Получение одной темы с эффективной загрузкой связей
  Future<NoteTheme?> getTheme(String id) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'themes',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;

      final map = maps.first;

      // Получаем связи с заметками для конкретной темы
      final noteIds = await getNoteIdsForTheme(id);

      // Проверяем и корректируем logoType, используя новое перечисление
      ThemeLogoType logoType;
      try {
        int logoTypeIndex = map['logoType'] as int? ?? 0;
        // Убедимся, что logoType в допустимом диапазоне
        if (logoTypeIndex >= 0 && logoTypeIndex < ThemeLogoType.values.length) {
          logoType = ThemeLogoType.values[logoTypeIndex];
        } else {
          // Если значение вне диапазона, используем первую иконку
          logoType = ThemeLogoType.icon01;
        }
      } catch (e) {
        // В случае любой ошибки используем первую иконку
        logoType = ThemeLogoType.icon01;
      }

      return NoteTheme(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        color: map['color'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        noteIds: noteIds,
        logoType: logoType,
      );
    } catch (e) {
      print('Ошибка при получении темы: $e');
      rethrow;
    }
  }

  // Получение связей темы с заметками
  Future<List<String>> getNoteIdsForTheme(String themeId) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'note_theme',
        columns: ['noteId'],
        where: 'themeId = ?',
        whereArgs: [themeId],
      );

      return List.generate(maps.length, (i) => maps[i]['noteId'] as String);
    } catch (e) {
      print('Ошибка при получении связей темы с заметками: $e');
      rethrow;
    }
  }

  // Оптимизированное обновление темы
  Future<int> updateTheme(NoteTheme theme) async {
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Подготовка данных обновления
        Map<String, dynamic> themeData = {
          'name': theme.name,
          'description': theme.description,
          'color': theme.color,
          'updatedAt': theme.updatedAt.millisecondsSinceEpoch,
        };

        // Добавляем logoType, используя новое перечисление ThemeLogoType с icon01-icon55
        themeData['logoType'] = theme.logoType.index;

        // Обновляем тему
        final result = await txn.update(
          'themes',
          themeData,
          where: 'id = ?',
          whereArgs: [theme.id],
        );

        // Получаем текущие связи с заметками
        final List<Map<String, dynamic>> currentRelations = await txn.query(
          'note_theme',
          columns: ['noteId'],
          where: 'themeId = ?',
          whereArgs: [theme.id],
        );

        final List<String> currentNoteIds = currentRelations
            .map<String>((map) => map['noteId'] as String)
            .toList();

        // Определяем, какие связи нужно добавить, а какие удалить
        final Set<String> toAdd = Set<String>.from(theme.noteIds)
            .difference(Set<String>.from(currentNoteIds));
        final Set<String> toRemove = Set<String>.from(currentNoteIds)
            .difference(Set<String>.from(theme.noteIds));

        // Удаляем ненужные связи
        if (toRemove.isNotEmpty) {
          for (final noteId in toRemove) {
            await txn.delete(
              'note_theme',
              where: 'themeId = ? AND noteId = ?',
              whereArgs: [theme.id, noteId],
            );
          }
        }

        // Добавляем новые связи
        if (toAdd.isNotEmpty) {
          final batch = txn.batch();
          for (final noteId in toAdd) {
            batch.insert(
              'note_theme',
              {
                'noteId': noteId,
                'themeId': theme.id,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
        }

        return result;
      });
    } catch (e) {
      print('Критическая ошибка при обновлении темы: $e');
      rethrow;
    }
  }

  // Оптимизированное удаление темы
  Future<int> deleteTheme(String id) async {
    final db = await database;

    try {
      return await db.transaction((txn) async {
        // Удаляем связи с заметками
        await txn.delete(
          'note_theme',
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
    } catch (e) {
      print('Ошибка при удалении темы: $e');
      rethrow;
    }
  }

  // Оптимизированное получение заметок для темы
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

      if (maps.isEmpty) {
        return [];
      }

      // Получаем идентификаторы заметок для эффективной загрузки тем
      final List<String> noteIds =
          maps.map<String>((map) => map['id'] as String).toList();

      // Получаем все связи с темами для этих заметок в одном запросе
      final List<Map<String, dynamic>> themeRelations = await db.query(
        'note_theme',
        where: 'noteId IN (${List.filled(noteIds.length, '?').join(', ')})',
        whereArgs: noteIds,
      );

      // Создаем Map для быстрого доступа к связям по ID заметки
      final Map<String, List<String>> noteThemeMap = {};
      for (final relation in themeRelations) {
        final noteId = relation['noteId'] as String;
        final relThemeId = relation['themeId'] as String;

        noteThemeMap[noteId] ??= [];
        noteThemeMap[noteId]!.add(relThemeId);
      }

      return maps.map((map) {
        final noteId = map['id'] as String;
        final themeIds = noteThemeMap[noteId] ?? [];

        // Десериализация полей reminderType и relativeReminder
        ReminderType reminderType = ReminderType.exactTime; // По умолчанию
        if (map['reminderType'] != null) {
          final int typeIndex = map['reminderType'] as int;
          if (typeIndex >= 0 && typeIndex < ReminderType.values.length) {
            reminderType = ReminderType.values[typeIndex];
          }
        }

        RelativeReminder? relativeReminder;
        if (map['relativeReminder'] != null) {
          try {
            final Map<String, dynamic> reminderMap =
                json.decode(map['relativeReminder'] as String);
            relativeReminder = RelativeReminder.fromMap(reminderMap);
          } catch (e) {
            print('Ошибка при десериализации relativeReminder: $e');
          }
        }

        return Note(
          id: noteId,
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
          voiceNotes: map['voiceNotes'] != null
              ? List<String>.from(json.decode(map['voiceNotes'] as String))
              : [],
          reminderType: reminderType,
          relativeReminder: relativeReminder,
        );
      }).toList();
    } catch (e) {
      print('Ошибка при получении заметок для темы: $e');
      rethrow;
    }
  }

  // Метод для пакетного обновления заметок
  Future<void> batchUpdateNotes(List<Note> notes) async {
    if (notes.isEmpty) return;

    final db = await database;

    try {
      await db.transaction((txn) async {
        // Разбиваем на группы для избежания слишком длинных транзакций
        final int batchSize = MAX_BATCH_SIZE;
        for (int i = 0; i < notes.length; i += batchSize) {
          final int end =
              (i + batchSize < notes.length) ? i + batchSize : notes.length;
          final List<Note> batch = notes.sublist(i, end);

          // Обновляем каждую заметку
          for (final note in batch) {
            await txn.update(
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
                'voiceNotes': json.encode(note.voiceNotes),
                'reminderType': note.reminderType.index,
                'relativeReminder': note.relativeReminder != null
                    ? json.encode(note.relativeReminder!.toMap())
                    : null,
              },
              where: 'id = ?',
              whereArgs: [note.id],
            );
          }
        }
      });
    } catch (e) {
      print('Ошибка при пакетном обновлении заметок: $e');
      rethrow;
    }
  }

  // Сосчитать общее количество заметок
  Future<int> countNotes({
    bool? isFavorite,
    bool? isCompleted,
    bool? hasDeadline,
    DateTime? fromDate,
    DateTime? toDate,
    List<String>? themeIds,
    String? searchQuery,
  }) async {
    final db = await database;

    try {
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

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereConditions.add('content LIKE ?');
        whereArgs.add('%$searchQuery%');
      }

      String whereClause = whereConditions.isEmpty
          ? ''
          : 'WHERE ${whereConditions.join(' AND ')}';

      if (themeIds != null && themeIds.isNotEmpty) {
        // Создаем подзапрос для фильтрации по темам
        String query = '''
        SELECT COUNT(DISTINCT notes.id) as total FROM notes
        INNER JOIN note_theme ON notes.id = note_theme.noteId
        $whereClause
        ${whereClause.isEmpty ? 'WHERE' : 'AND'} note_theme.themeId IN (${List.filled(themeIds.length, '?').join(', ')})
        ''';

        final result = await db.rawQuery(query, [...whereArgs, ...themeIds]);

        return Sqflite.firstIntValue(result) ?? 0;
      } else {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as total FROM notes ${whereClause.isNotEmpty ? whereClause : ''}',
          whereArgs.isEmpty ? null : whereArgs,
        );

        return Sqflite.firstIntValue(result) ?? 0;
      }
    } catch (e) {
      print('Ошибка при подсчете заметок: $e');
      return 0;
    }
  }

  // Поиск заметок по содержимому с пагинацией
  Future<List<Note>> searchNotes(String query,
      {int limit = DEFAULT_PAGE_SIZE, int offset = 0}) async {
    return getFilteredNotes(
      searchQuery: query,
      limit: limit,
      offset: offset,
    );
  }

  // Оптимизированная проверка существования заметки с заданным ID
  Future<bool> noteExists(String id) async {
    final db = await database;

    try {
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM notes WHERE id = ?) as exists_flag',
        [id],
      );

      return (Sqflite.firstIntValue(result) ?? 0) == 1;
    } catch (e) {
      print('Ошибка при проверке существования заметки: $e');
      return false;
    }
  }

  // Оптимизированная проверка существования темы с заданным ID
  Future<bool> themeExists(String id) async {
    final db = await database;

    try {
      final result = await db.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM themes WHERE id = ?) as exists_flag',
        [id],
      );

      return (Sqflite.firstIntValue(result) ?? 0) == 1;
    } catch (e) {
      print('Ошибка при проверке существования темы: $e');
      return false;
    }
  }

  // Метод для удаления и пересоздания базы данных (используется для тестирования)
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final path = join(await getDatabasesPath(), 'note_link.db');
    await deleteDatabase(path);

    // Получаем новый экземпляр базы данных
    await database;
  }
}

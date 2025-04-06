import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';
import '../models/theme.dart';
import 'package:synchronized/synchronized.dart';

class DatabaseService {
  static const _databaseName = "note_link.db";
  static const _databaseVersion = 2;

  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Only have a single app-wide reference to the database
  static Database? _database;
  // Lock для синхронизации доступа к БД
  final Lock _dbLock = Lock();

  // Названия таблиц
  static const String noteTable = 'notes';
  static const String themeTable = 'themes';

  // Схема таблицы notes для отладки
  static const String noteTableSchema = '''
  CREATE TABLE $noteTable (
    id TEXT PRIMARY KEY,
    content TEXT NOT NULL,
    theme_ids TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    has_deadline INTEGER,
    deadline_date INTEGER,
    has_date_link INTEGER,
    linked_date INTEGER,
    is_completed INTEGER,
    is_favorite INTEGER,
    media_urls TEXT,
    emoji TEXT,
    reminder_dates TEXT,
    reminder_sound TEXT,
    reminder_type INTEGER,
    relative_reminder TEXT,
    recurring_reminder TEXT,
    deadline_extensions TEXT,
    voice_notes TEXT
  )
  ''';

  // Открываем и подготавливаем БД
  Future<Database> get _getDatabase async {
    debugPrint('Запрос соединения с БД');
    if (_database != null) {
      debugPrint('Возвращаем существующее соединение с БД');
      return _database!;
    }

    debugPrint('БД не инициализирована, инициализируем...');
    _database = await _initDatabase();
    return _database!;
  }

  // Инициализация БД
  Future<Database> _initDatabase() async {
    debugPrint('Инициализация БД...');
    // Получаем путь к базе данных
    final dbDirectory = await getDatabasesPath();
    final String dbPath = path.join(dbDirectory, _databaseName);
    debugPrint('Путь к БД: $dbPath');

    // Открываем базу данных
    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Проверка и вывод схемы таблицы
  Future<void> _checkTableSchema(Database db, String tableName) async {
    try {
      debugPrint('Проверка схемы таблицы $tableName...');
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      debugPrint('Схема таблицы $tableName:');
      for (var column in tableInfo) {
        debugPrint('  ${column['name']} (${column['type']})');
      }
    } catch (e) {
      debugPrint('Ошибка при проверке схемы таблицы $tableName: $e');
    }
  }

  // Создание схемы базы данных
  Future<void> _onCreate(Database db, int version) async {
    try {
      // Таблица для заметок
      await db.execute(noteTableSchema);

      // Таблица для тем
      await db.execute('''
        CREATE TABLE themes(
          id TEXT PRIMARY KEY,
          name TEXT,
          description TEXT,
          color TEXT,
          createdAt INTEGER,
          updatedAt INTEGER,
          noteIds TEXT,
          logoType INTEGER
        )
      ''');
    } catch (e) {
      debugPrint('Ошибка создания таблиц в базе данных: $e');
      rethrow;
    }
  }

  // Обновление БД при изменении схемы
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Обновление БД с версии $oldVersion до $newVersion');
    if (oldVersion < 2) {
      // Добавляем колонку theme_ids в таблицу notes
      try {
        debugPrint('Добавляем колонку theme_ids в таблицу notes...');
        await db.execute('ALTER TABLE $noteTable ADD COLUMN theme_ids TEXT;');
        debugPrint('Колонка theme_ids успешно добавлена.');
      } catch (e) {
        debugPrint('Ошибка при добавлении колонки theme_ids: $e');
        // Если колонка уже существует, ошибка будет проигнорирована,
        // но лучше обработать это явно, если возможно
      }
    }
    // Добавьте здесь код для будущих миграций, например:
    // if (oldVersion < 3) {
    //   // ... миграция на версию 3
    // }
  }

  // CRUD операции для заметок

  // Получить все заметки
  Future<List<Note>> getNotes() async {
    debugPrint('Получение всех заметок из БД');
    try {
      final db = await _getDatabase;
      final List<Map<String, dynamic>> maps = await db.query(noteTable);

      return List.generate(maps.length, (i) {
        return Note.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('Ошибка при получении заметок: $e');
      return []; // Возвращаем пустой список вместо исключения
    }
  }

  // Получить заметку по ID
  Future<Note?> getNoteById(String id) async {
    debugPrint('Получение заметки по ID: $id');
    try {
      final db = await _getDatabase;
      final List<Map<String, dynamic>> maps = await db.query(
        noteTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Note.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка при получении заметки по ID $id: $e');
      return null; // Возвращаем null вместо исключения
    }
  }

  // Вставить новую заметку в БД
  Future<String> insertNote(Note note) async {
    debugPrint('Database: Начало вставки заметки ${note.id}');
    try {
      final db = await _getDatabase;
      debugPrint('Database: Соединение с БД установлено');

      // Проверка на наличие таблицы
      try {
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$noteTable'",
        );
        debugPrint(
          'Database: Проверка таблицы $noteTable: ${tableCheck.isNotEmpty ? "существует" : "не существует!"}',
        );
        if (tableCheck.isEmpty) {
          throw Exception(
            'Таблица $noteTable не существует! Возможно, БД не инициализирована правильно.',
          );
        }
      } catch (e) {
        debugPrint('Database: Ошибка при проверке таблицы: $e');
      }

      // Логируем данные перед вставкой
      final noteMap = note.toMap();
      debugPrint(
        'Database: Подготовлен Map для вставки: ${noteMap.keys.join(", ")}',
      );

      // Проверка некоторых важных полей
      final content = noteMap['content'] as String?;
      debugPrint('Database: Размер контента: ${content?.length ?? 0} байт');
      debugPrint('Database: ID заметки: ${noteMap['id']}');
      debugPrint('Database: CreatedAt: ${noteMap['created_at']}');

      // Проверяем, валидный ли JSON
      try {
        if (content != null && content.isNotEmpty) {
          json.decode(content);
          debugPrint('Database: Контент является валидным JSON');
        }
      } catch (jsonError) {
        debugPrint('Database: ОШИБКА: Невалидный JSON контент: $jsonError');
      }

      final id = await db.insert(
        noteTable,
        noteMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('Database: Заметка успешно вставлена, результат: $id');
      return note.id;
    } catch (e) {
      debugPrint('Database: !!! КРИТИЧЕСКАЯ ОШИБКА ПРИ ВСТАВКЕ ЗАМЕТКИ: $e');
      debugPrint('Database: Стек вызовов: ${StackTrace.current}');
      throw Exception('Ошибка при вставке заметки в БД: $e');
    }
  }

  // Обновить существующую заметку
  Future<int> updateNote(Note note) async {
    return _dbLock.synchronized(() async {
      try {
        final db = await _getDatabase;

        return await db.update(
          noteTable,
          note.toMap(),
          where: 'id = ?',
          whereArgs: [note.id],
        );
      } catch (e) {
        debugPrint('Ошибка при обновлении заметки ${note.id}: $e');
        rethrow;
      }
    });
  }

  // Удалить заметку
  Future<int> deleteNote(String id) async {
    return _dbLock.synchronized(() async {
      try {
        final db = await _getDatabase;

        return await db.delete(noteTable, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Ошибка при удалении заметки $id: $e');
        rethrow;
      }
    });
  }

  // CRUD операции для тем

  // Получить все темы
  Future<List<NoteTheme>> getThemes() async {
    debugPrint('Получение всех тем из БД');
    try {
      final db = await _getDatabase;
      final List<Map<String, dynamic>> maps = await db.query(themeTable);

      return List.generate(maps.length, (i) {
        return NoteTheme.fromMap(maps[i]);
      });
    } catch (e) {
      debugPrint('Ошибка при получении всех тем: $e');
      return []; // Возвращаем пустой список вместо исключения
    }
  }

  // Получить тему по ID
  Future<NoteTheme?> getThemeById(String id) async {
    debugPrint('Получение темы по ID: $id');
    try {
      final db = await _getDatabase;
      final List<Map<String, dynamic>> maps = await db.query(
        themeTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return NoteTheme.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка при получении темы по ID $id: $e');
      return null; // Возвращаем null вместо исключения
    }
  }

  // Добавить новую тему
  Future<String> insertTheme(NoteTheme theme) async {
    return _dbLock.synchronized(() async {
      try {
        final db = await _getDatabase;

        await db.insert(
          themeTable,
          theme.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        return theme.id;
      } catch (e) {
        debugPrint('Ошибка при добавлении темы ${theme.id}: $e');
        rethrow;
      }
    });
  }

  // Обновить существующую тему
  Future<int> updateTheme(NoteTheme theme) async {
    return _dbLock.synchronized(() async {
      try {
        final db = await _getDatabase;

        return await db.update(
          themeTable,
          theme.toMap(),
          where: 'id = ?',
          whereArgs: [theme.id],
        );
      } catch (e) {
        debugPrint('Ошибка при обновлении темы ${theme.id}: $e');
        rethrow;
      }
    });
  }

  // Удалить тему
  Future<int> deleteTheme(String id) async {
    return _dbLock.synchronized(() async {
      try {
        final db = await _getDatabase;

        return await db.delete(themeTable, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint('Ошибка при удалении темы $id: $e');
        rethrow;
      }
    });
  }
}

// Вспомогательный класс для блокировки ресурсов
class Lock {
  Completer<void>? _completer;

  // Приобретение блокировки
  Future<T> synchronized<T>(Future<T> Function() criticalSection) async {
    // Ожидаем, если блокировка уже используется
    if (_completer != null) {
      await _completer!.future;
    }

    // Создаем новую блокировку
    _completer = Completer<void>();

    try {
      // Выполняем критическую секцию
      final result = await criticalSection();
      return result;
    } finally {
      // Освобождаем блокировку
      final completer = _completer;
      _completer = null;
      completer!.complete();
    }
  }
}

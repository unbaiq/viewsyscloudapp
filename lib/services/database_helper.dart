import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/media_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // In-memory fallback cache for Web and Test platform compatibility
  final List<MediaItem> _webDatabase = [];

  DatabaseHelper._init();

  /// Flag to determine if the local in-memory fallback cache should be used.
  bool get _useInMemory => kIsWeb || (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  Future<Database> get database async {
    if (_useInMemory) {
      throw UnsupportedError('SQLite database is not supported on the web or test platforms.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('playlist.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE media_items (
        id INTEGER PRIMARY KEY,
        url TEXT NOT NULL,
        type TEXT NOT NULL,
        duration INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        local_path TEXT,
        schedule TEXT
      )
    ''');
  }

  /// Inserts or replaces all schedule items in the database cache.
  Future<void> savePlaylist(List<MediaItem> items) async {
    if (_useInMemory) {
      _webDatabase.clear();
      _webDatabase.addAll(items);
      return;
    }

    final db = await database;
    await db.transaction((txn) async {
      // Clear existing records before updating manifest database entries
      await txn.delete('media_items');
      for (final item in items) {
        await txn.insert(
          'media_items',
          {
            'id': item.id,
            'url': item.url,
            'type': item.type,
            'duration': item.duration,
            'sort_order': item.order,
            'local_path': item.localPath,
            'schedule': item.schedule != null ? jsonEncode(item.schedule!.toJson()) : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Fetches all stored media items from database cache, ordered by display sequence.
  Future<List<MediaItem>> getPlaylist() async {
    if (_useInMemory) {
      return List<MediaItem>.from(_webDatabase)..sort((a, b) => a.order.compareTo(b.order));
    }

    final db = await database;
    final result = await db.query('media_items', orderBy: 'sort_order ASC');

    return result.map((map) {
      final scheduleStr = map['schedule'] as String?;
      Map<String, dynamic>? scheduleJson;
      if (scheduleStr != null && scheduleStr.isNotEmpty) {
        scheduleJson = jsonDecode(scheduleStr) as Map<String, dynamic>;
      }

      return MediaItem(
        id: map['id'] as int,
        url: map['url'] as String,
        type: map['type'] as String,
        duration: map['duration'] as int,
        order: map['sort_order'] as int,
        localPath: map['local_path'] as String?,
        schedule: scheduleJson != null ? ScheduleConfig.fromJson(scheduleJson) : null,
      );
    }).toList();
  }

  /// Updates local cached file path for a downloaded media item.
  Future<void> updateLocalPath(int id, String? localPath) async {
    if (_useInMemory) {
      final idx = _webDatabase.indexWhere((item) => item.id == id);
      if (idx != -1) {
        _webDatabase[idx] = _webDatabase[idx].copyWith(localPath: localPath);
      }
      return;
    }

    final db = await database;
    await db.update(
      'media_items',
      {'local_path': localPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clears the playlist database.
  Future<void> clearPlaylist() async {
    if (_useInMemory) {
      _webDatabase.clear();
      return;
    }

    final db = await database;
    await db.delete('media_items');
  }
}

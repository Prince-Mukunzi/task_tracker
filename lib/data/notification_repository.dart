import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_notification.dart';


class NotificationRepository {
  static const _table = 'notifications';


  static Database? _db;

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<Database> _database() async {
    if (_db != null) return _db!;

    final folder = await getDatabasesPath();
    _db = await openDatabase(
      p.join(folder, 'notifications.db'),
      version: 1,
      // onCreate only runs the first time, when the file doesn't exist yet.
      // SQLite has no true/false, so is_read stores 0 (unread) or 1 (read).
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            title      TEXT NOT NULL,
            body       TEXT NOT NULL,
            type       TEXT NOT NULL,
            task_id    TEXT,
            is_read    INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }


  Future<void> notify({
    required NotificationType type,
    required String title,
    required String body,
    String? taskId,
  }) async {


    final db = await _database();
    final notification = AppNotification(
      type: type,
      title: title,
      body: body,
      taskId: taskId,
      createdAt: DateTime.now(),
    );
    await db.insert(_table, notification.toMap());
    await refreshUnreadCount();
  }

  // All notifications, newest first.
  Future<List<AppNotification>> getAll() async {
    final db = await _database();
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map((row) => AppNotification.fromMap(row)).toList();
  }

  Future<void> markAsRead(int id) async {
    final db = await _database();
    await db.update(
      _table,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await refreshUnreadCount();
  }

  Future<void> markAllAsRead() async {
    final db = await _database();
    await db.update(_table, {'is_read': 1}, where: 'is_read = 0');
    await refreshUnreadCount();
  }

  Future<void> delete(int id) async {
    final db = await _database();
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await refreshUnreadCount();
  }

  /// Deletes every notification
  Future<void> clearAll() async {
    final db = await _database();
    await db.delete(_table);
    await refreshUnreadCount();
  }

  /// Counts the unread notifications and updates [unreadCount].
  Future<void> refreshUnreadCount() async {
    final db = await _database();
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $_table WHERE is_read = 0',
    );
    unreadCount.value = Sqflite.firstIntValue(result) ?? 0;
  }
}

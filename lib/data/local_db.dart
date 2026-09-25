import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'minacalc_offline.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE records(
            collection TEXT NOT NULL,
            record_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            version INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT,
            deleted INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(collection, record_id)
          )
        ''');
        await database.execute('''
          CREATE TABLE queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mutation_id TEXT NOT NULL UNIQUE,
            kind TEXT NOT NULL,
            payload TEXT NOT NULL,
            base_version INTEGER,
            status TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE meta(
            meta_key TEXT PRIMARY KEY,
            meta_value TEXT
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> setMeta(String key, String value) async {
    final d = await db;
    await d.insert('meta', {'meta_key': key, 'meta_value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getMeta(String key) async {
    final d = await db;
    final rows = await d.query('meta', where: 'meta_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['meta_value'] as String?;
  }

  Future<void> applySnapshot(Map<String, dynamic> snapshot) async {
    final d = await db;
    final collections = Map<String, dynamic>.from(snapshot['collections'] as Map? ?? {});
    await d.transaction((txn) async {
      for (final entry in collections.entries) {
        if (entry.value is! List) continue;
        await txn.delete('records', where: 'collection = ?', whereArgs: [entry.key]);
        for (final raw in entry.value as List) {
          if (raw is! Map) continue;
          final record = Map<String, dynamic>.from(raw);
          final id = (record['id'] ?? '').toString();
          if (id.isEmpty) continue;
          await txn.insert('records', {
            'collection': entry.key,
            'record_id': id,
            'payload': jsonEncode(record),
            'version': (record['_sync_version'] as num?)?.toInt() ?? 0,
            'updated_at': (record['updated_at'] ?? record['created_at'] ?? '').toString(),
            'deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (snapshot['cursor'] != null) {
        await txn.insert('meta', {'meta_key': 'sync_cursor', 'meta_value': '${snapshot['cursor']}'}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (snapshot['settings'] != null) {
        await txn.insert('meta', {'meta_key': 'server_settings', 'meta_value': jsonEncode(snapshot['settings'])}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> applySyncEvent(Map<String, dynamic> event) async {
    final collection = (event['table'] ?? '').toString();
    final id = (event['record_id'] ?? '').toString();
    if (collection.isEmpty || id.isEmpty) return;
    final d = await db;
    if (event['op'] == 'delete') {
      await d.delete('records', where: 'collection = ? AND record_id = ?', whereArgs: [collection, id]);
      return;
    }
    final payload = event['payload'];
    if (payload is! Map) return;
    final record = Map<String, dynamic>.from(payload);
    await d.insert('records', {
      'collection': collection,
      'record_id': id,
      'payload': jsonEncode(record),
      'version': (event['version'] as num?)?.toInt() ?? (record['_sync_version'] as num?)?.toInt() ?? 0,
      'updated_at': (event['changed_at'] ?? '').toString(),
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<void> replaceCollection(String collection, List<Map<String, dynamic>> records) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('records', where: 'collection = ?', whereArgs: [collection]);
      for (final record in records) {
        final id = (record['id'] ?? '').toString();
        if (id.isEmpty) continue;
        await txn.insert('records', {
          'collection': collection,
          'record_id': id,
          'payload': jsonEncode(record),
          'version': (record['_sync_version'] as num?)?.toInt() ?? 0,
          'updated_at': (record['updated_at'] ?? record['created_at'] ?? '').toString(),
          'deleted': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearCollection(String collection) async {
    final d = await db;
    await d.delete('records', where: 'collection = ?', whereArgs: [collection]);
  }

  Future<List<Map<String, dynamic>>> all(String collection) async {
    final d = await db;
    final rows = await d.query('records', where: 'collection = ? AND deleted = 0', whereArgs: [collection]);
    return rows.map((row) => Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map)).toList();
  }

  Future<Map<String, dynamic>?> one(String collection, String id) async {
    final d = await db;
    final rows = await d.query('records', where: 'collection = ? AND record_id = ? AND deleted = 0', whereArgs: [collection, id], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['payload'] as String) as Map);
  }

  Future<int> recordVersion(String collection, String id) async {
    final d = await db;
    final rows = await d.query('records', columns: ['version'], where: 'collection = ? AND record_id = ?', whereArgs: [collection, id], limit: 1);
    return rows.isEmpty ? 0 : (rows.first['version'] as int? ?? 0);
  }

  Future<void> putLocal(String collection, String id, Map<String, dynamic> payload, {int version = 0}) async {
    final d = await db;
    await d.insert('records', {
      'collection': collection,
      'record_id': id,
      'payload': jsonEncode(payload),
      'version': version,
      'updated_at': DateTime.now().toIso8601String(),
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLocal(String collection, String id) async {
    final d = await db;
    await d.delete('records', where: 'collection = ? AND record_id = ?', whereArgs: [collection, id]);
  }

  Future<void> enqueue({
    required String mutationId,
    required String kind,
    required Map<String, dynamic> payload,
    int? baseVersion,
  }) async {
    final d = await db;
    await d.insert('queue', {
      'mutation_id': mutationId,
      'kind': kind,
      'payload': jsonEncode(payload),
      'base_version': baseVersion,
      'status': 'pending',
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> pendingQueue({int limit = 100}) async {
    final d = await db;
    final rows = await d.query('queue', where: "status IN ('pending','retry')", orderBy: 'id ASC', limit: limit);
    return rows.map((row) {
      final out = Map<String, dynamic>.from(row);
      out['payload'] = Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map);
      return out;
    }).toList();
  }

  Future<int> pendingCount() async {
    final d = await db;
    final result = Sqflite.firstIntValue(await d.rawQuery("SELECT COUNT(*) FROM queue WHERE status IN ('pending','retry')"));
    return result ?? 0;
  }

  Future<int> conflictCount() async {
    final d = await db;
    final result = Sqflite.firstIntValue(await d.rawQuery("SELECT COUNT(*) FROM queue WHERE status = 'conflict'"));
    return result ?? 0;
  }

  Future<List<Map<String, dynamic>>> conflicts() async {
    final d = await db;
    final rows = await d.query('queue', where: "status = 'conflict'", orderBy: 'id ASC');
    return rows.map((row) {
      final out = Map<String, dynamic>.from(row);
      out['payload'] = Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map);
      return out;
    }).toList();
  }

  Future<void> queueDone(int id) async {
    final d = await db;
    await d.delete('queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> queueError(int id, String message) async {
    final d = await db;
    await d.rawUpdate('UPDATE queue SET status = ?, attempts = attempts + 1, last_error = ? WHERE id = ?', ['retry', message, id]);
  }

  Future<void> queueConflict(int id, String message) async {
    final d = await db;
    await d.rawUpdate('UPDATE queue SET status = ?, attempts = attempts + 1, last_error = ? WHERE id = ?', ['conflict', message, id]);
  }

  Future<void> clearSyncedData() async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('records');
      await txn.delete('queue');
      await txn.delete('meta');
    });
  }
}

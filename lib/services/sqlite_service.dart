import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import 'database_service.dart';

class SqliteSyncItem {
  final int id;
  final String entityType; // 'kunjungan' or 'users'
  final String entityId;
  final String action; // 'INSERT', 'UPDATE', 'DELETE'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  SqliteSyncItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.createdAt,
  });

  factory SqliteSyncItem.fromMap(Map<String, dynamic> map) {
    return SqliteSyncItem(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
      entityType: map['entity_type']?.toString() ?? 'kunjungan',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action']?.toString() ?? 'INSERT',
      payload: map['payload'] != null && map['payload'].toString().isNotEmpty
          ? jsonDecode(map['payload'].toString()) as Map<String, dynamic>
          : {},
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SqliteService {
  static final SqliteService instance = SqliteService._();
  SqliteService._();

  sqflite.Database? _db;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // In-memory fallback for web and headless unit tests
  final List<Map<String, dynamic>> _memUsers = [];
  final List<Map<String, dynamic>> _memVisits = [];
  final List<Map<String, dynamic>> _memSyncQueue = [];

  bool get _canUseNativeSqlite {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
    } catch (_) {}
    return true;
  }

  /// Inisialisasi SQLite database (membuat file sikunjung.db dan tabel-tabelnya)
  Future<void> init() async {
    if (_isInitialized) return;

    if (_canUseNativeSqlite) {
      try {
        final databasesPath = await sqflite.getDatabasesPath();
        final path = p.join(databasesPath, 'sikunjung.db');

        _db = await sqflite.openDatabase(
          path,
          version: 1,
          onCreate: (db, version) async {
            // Tabel users lokal untuk autentikasi offline
            await db.execute('''
              CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                full_name TEXT NOT NULL,
                nip TEXT NOT NULL,
                salt TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                role TEXT DEFAULT 'officer',
                created_at TEXT
              )
            ''');

            // Tabel kunjungan lokal untuk simpan data saat tidak ada jaringan
            await db.execute('''
              CREATE TABLE IF NOT EXISTS kunjungan (
                id TEXT PRIMARY KEY,
                user_id INTEGER,
                outlet_name TEXT NOT NULL,
                customer_name TEXT,
                category TEXT,
                address TEXT,
                visit_time TEXT,
                priority TEXT,
                status TEXT NOT NULL,
                notes TEXT,
                coordinates TEXT,
                phone TEXT,
                task TEXT,
                distance TEXT,
                eta TEXT,
                created_at TEXT,
                updated_at TEXT,
                sync_status TEXT DEFAULT 'synced'
              )
            ''');

            // Tabel antrean sinkronisasi (offline sync queue)
            await db.execute('''
              CREATE TABLE IF NOT EXISTS sync_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                action TEXT NOT NULL,
                payload TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');

            debugPrint('SqliteService: Database SQLite sikunjung.db dan tabel berhasil dibuat.');
          },
        );
        debugPrint('SqliteService: Database SQLite berhasil dibuka di $path');
      } catch (e) {
        debugPrint('SqliteService: Native SQLite tidak dapat diakses, beralih ke in-memory mode: $e');
        _db = null;
      }
    }

    _isInitialized = true;
  }

  // ==========================================
  // USERS TABLE (SQLITE)
  // ==========================================

  Future<List<UserModel>> getUsers() async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        final List<Map<String, dynamic>> maps = await _db!.query('users');
        return maps.map((m) => UserModel.fromMap(m)).toList();
      } catch (e) {
        debugPrint('SqliteService: getUsers error: $e');
      }
    }

    return _memUsers.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<UserModel?> getUserByUsername(String username) async {
    if (!_isInitialized) await init();
    final clean = username.trim().toLowerCase();

    if (_db != null) {
      try {
        final List<Map<String, dynamic>> maps = await _db!.query(
          'users',
          where: 'LOWER(username) = ?',
          whereArgs: [clean],
          limit: 1,
        );
        if (maps.isNotEmpty) {
          return UserModel.fromMap(maps.first);
        }
      } catch (e) {
        debugPrint('SqliteService: getUserByUsername error: $e');
      }
    }

    final mem = _memUsers.where((u) => u['username']?.toString().toLowerCase() == clean).firstOrNull;
    if (mem != null) return UserModel.fromMap(mem);
    return null;
  }

  Future<bool> insertUser(UserModel user) async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        await _db!.insert(
          'users',
          user.toMap(),
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
        return true;
      } catch (e) {
        debugPrint('SqliteService: insertUser error: $e');
      }
    }

    _memUsers.removeWhere((u) => u['username'] == user.username);
    _memUsers.add(user.toMap());
    return true;
  }

  // ==========================================
  // KUNJUNGAN TABLE (SQLITE)
  // ==========================================

  Future<List<Map<String, dynamic>>> getVisits() async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        final List<Map<String, dynamic>> maps = await _db!.query(
          'kunjungan',
          orderBy: 'created_at DESC, id DESC',
        );
        return maps.map((m) => Map<String, dynamic>.from(m)).toList();
      } catch (e) {
        debugPrint('SqliteService: getVisits error: $e');
      }
    }

    return List<Map<String, dynamic>>.from(_memVisits);
  }

  Future<bool> insertVisit(Map<String, dynamic> visit, {bool isOffline = false}) async {
    if (!_isInitialized) await init();

    final data = Map<String, dynamic>.from(visit);
    final id = data['id']?.toString() ?? '#KUN-${DateTime.now().millisecondsSinceEpoch % 10000}';
    data['id'] = id;
    data['sync_status'] = isOffline ? 'pending_sync' : 'synced';
    data['created_at'] ??= DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();

    if (_db != null) {
      try {
        await _db!.insert(
          'kunjungan',
          data,
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );

        if (isOffline) {
          await _enqueueSyncItem('kunjungan', id, 'INSERT', data);
        }
        return true;
      } catch (e) {
        debugPrint('SqliteService: insertVisit error: $e');
      }
    }

    _memVisits.removeWhere((v) => v['id'] == id);
    _memVisits.insert(0, data);
    if (isOffline) {
      _memSyncQueue.add({
        'id': _memSyncQueue.length + 1,
        'entity_type': 'kunjungan',
        'entity_id': id,
        'action': 'INSERT',
        'payload': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    return true;
  }

  Future<bool> updateVisitStatus(String id, String status, {bool isOffline = false}) async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        final Map<String, dynamic> updateData = {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (isOffline) {
          updateData['sync_status'] = 'pending_sync';
        }

        await _db!.update(
          'kunjungan',
          updateData,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (isOffline) {
          await _enqueueSyncItem('kunjungan', id, 'UPDATE', {'status': status});
        }
        return true;
      } catch (e) {
        debugPrint('SqliteService: updateVisitStatus error: $e');
      }
    }

    final index = _memVisits.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      _memVisits[index]['status'] = status;
      _memVisits[index]['updated_at'] = DateTime.now().toIso8601String();
      if (isOffline) {
        _memVisits[index]['sync_status'] = 'pending_sync';
        _memSyncQueue.add({
          'id': _memSyncQueue.length + 1,
          'entity_type': 'kunjungan',
          'entity_id': id,
          'action': 'UPDATE',
          'payload': jsonEncode({'status': status}),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    return true;
  }

  Future<bool> updateVisitDetails(
    String id, {
    String? notes,
    String? task,
    String? status,
    bool isOffline = false,
  }) async {
    if (!_isInitialized) await init();

    final Map<String, dynamic> updates = {
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) updates['notes'] = notes;
    if (task != null) updates['task'] = task;
    if (status != null) updates['status'] = status;
    if (isOffline) updates['sync_status'] = 'pending_sync';

    if (_db != null) {
      try {
        await _db!.update(
          'kunjungan',
          updates,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (isOffline) {
          await _enqueueSyncItem('kunjungan', id, 'UPDATE', updates);
        }
        return true;
      } catch (e) {
        debugPrint('SqliteService: updateVisitDetails error: $e');
      }
    }

    final index = _memVisits.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      if (notes != null) _memVisits[index]['notes'] = notes;
      if (task != null) _memVisits[index]['task'] = task;
      if (status != null) _memVisits[index]['status'] = status;
      _memVisits[index]['updated_at'] = DateTime.now().toIso8601String();
      if (isOffline) {
        _memVisits[index]['sync_status'] = 'pending_sync';
        _memSyncQueue.add({
          'id': _memSyncQueue.length + 1,
          'entity_type': 'kunjungan',
          'entity_id': id,
          'action': 'UPDATE',
          'payload': jsonEncode(updates),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    return true;
  }

  Future<bool> deleteVisit(String id, {bool isOffline = false}) async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        await _db!.delete(
          'kunjungan',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (isOffline) {
          await _enqueueSyncItem('kunjungan', id, 'DELETE', {'id': id});
        }
        return true;
      } catch (e) {
        debugPrint('SqliteService: deleteVisit error: $e');
      }
    }

    _memVisits.removeWhere((v) => v['id'] == id);
    if (isOffline) {
      _memSyncQueue.add({
        'id': _memSyncQueue.length + 1,
        'entity_type': 'kunjungan',
        'entity_id': id,
        'action': 'DELETE',
        'payload': jsonEncode({'id': id}),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    return true;
  }

  // ==========================================
  // OFFLINE SYNC QUEUE OPERATIONS
  // ==========================================

  Future<void> _enqueueSyncItem(
    String entityType,
    String entityId,
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (_db == null) return;
    try {
      await _db!.insert('sync_queue', {
        'entity_type': entityType,
        'entity_id': entityId,
        'action': action,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('SqliteService: Antrean sinkronisasi offline ditambahkan [$action $entityType: $entityId]');
    } catch (e) {
      debugPrint('SqliteService: Error enqueue sync: $e');
    }
  }

  Future<List<SqliteSyncItem>> getPendingSyncQueue() async {
    if (!_isInitialized) await init();

    if (_db != null) {
      try {
        final List<Map<String, dynamic>> maps = await _db!.query('sync_queue', orderBy: 'id ASC');
        return maps.map((m) => SqliteSyncItem.fromMap(m)).toList();
      } catch (e) {
        debugPrint('SqliteService: getPendingSyncQueue error: $e');
      }
    }

    return _memSyncQueue.map((m) => SqliteSyncItem.fromMap(m)).toList();
  }

  Future<void> markQueueItemProcessed(int queueId) async {
    if (_db != null) {
      try {
        await _db!.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
        return;
      } catch (_) {}
    }
    _memSyncQueue.removeWhere((q) => q['id'] == queueId);
  }

  Future<void> clearSyncQueue() async {
    if (_db != null) {
      try {
        await _db!.delete('sync_queue');
        return;
      } catch (_) {}
    }
    _memSyncQueue.clear();
  }

  Future<int> getPendingSyncCount() async {
    final queue = await getPendingSyncQueue();
    return queue.length;
  }
}

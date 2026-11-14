import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mysql_service.dart';
import 'sqlite_service.dart';

class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String nip;
  final String salt;
  final String passwordHash;
  final String role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.nip,
    required this.salt,
    required this.passwordHash,
    this.role = 'officer',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'nip': nip,
      'salt': salt,
      'password_hash': passwordHash,
      'role': role,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 1,
      username: map['username']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      nip: map['nip']?.toString() ?? '',
      salt: map['salt']?.toString() ?? '',
      passwordHash: map['password_hash']?.toString() ?? '',
      role: map['role']?.toString() ?? 'officer',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Local in-memory caches synchronized with MySQL / storage
  final List<UserModel> _users = [];
  final List<Map<String, dynamic>> _kunjunganList = [];

  bool get isTestEnvironment {
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    try {
      return WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    } catch (_) {
      return false;
    }
  }

  bool get _isTestEnvironment => isTestEnvironment;

  /// Generate cryptographic random salt
  static String generateRandomSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash password with salt using SHA-256
  static String hashPasswordWithSalt(String password, String salt) {
    final bytes = utf8.encode('$password$salt');
    return sha256.convert(bytes).toString();
  }

  /// Membuka dan menginisialisasi database sebelum runApp dipanggil di lib/main.dart
  Future<void> init() async {
    if (_isInitialized) return;

    debugPrint('DatabaseService: Menginisialisasi koneksi database & tabel...');

    // 1. Inisialisasi data lokal terlebih dahulu agar halaman langsung siap
    await _loadFromLocal();

    // 2. Coba koneksi ke MySQL jika bukan di environment pengujian atau web
    if (!kIsWeb && !_isTestEnvironment) {
      try {
        final connected = await MySqlService.instance.connect();
        if (connected) {
          await _createMySqlTables();
          await _syncFromMySql();
        }
      } catch (e) {
        debugPrint('DatabaseService: MySQL connection fallback to local storage: $e');
      }
    }

    // 3. Buat akun contoh jika belum ada atau saat mode debug/test
    if (kDebugMode || _isTestEnvironment || _users.isEmpty || !_users.any((u) => u.username == 'officer.andi')) {
      await _seedDebugDemoAccountIfNeeded();
    }

    _isInitialized = true;
    debugPrint('DatabaseService: Database siap digunakan (Total Users: ${_users.length}, Total Kunjungan: ${_kunjunganList.length}).');
  }

  /// Membuat tabel users dan kunjungan di MySQL jika belum ada
  Future<void> _createMySqlTables() async {
    try {
      // Tabel users menyimpan identitas petugas dan hash password beserta salt; tidak menyimpan password asli
      await MySqlService.instance.query('''
        CREATE TABLE IF NOT EXISTS users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          username VARCHAR(50) NOT NULL UNIQUE,
          full_name VARCHAR(100) NOT NULL,
          nip VARCHAR(30) NOT NULL,
          salt VARCHAR(64) NOT NULL,
          password_hash VARCHAR(128) NOT NULL,
          role VARCHAR(20) DEFAULT 'officer',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // Tabel kunjungan memuat data pelanggan, waktu, status, catatan, koordinat GPS, dan user_id
      await MySqlService.instance.query('''
        CREATE TABLE IF NOT EXISTS kunjungan (
          id VARCHAR(30) PRIMARY KEY,
          user_id INT,
          outlet_name VARCHAR(100) NOT NULL,
          customer_name VARCHAR(100),
          category VARCHAR(50),
          address TEXT,
          visit_time VARCHAR(50),
          priority VARCHAR(30),
          status VARCHAR(30) NOT NULL,
          notes TEXT,
          latitude DOUBLE,
          longitude DOUBLE,
          coordinates VARCHAR(60),
          phone VARCHAR(30),
          task TEXT,
          distance VARCHAR(30),
          eta VARCHAR(30),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_user_id (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      debugPrint('DatabaseService: Tabel users & kunjungan berhasil diverifikasi di MySQL.');
    } catch (e) {
      debugPrint('DatabaseService: Error saat membuat tabel MySQL: $e');
    }
  }

  /// Sinkronisasi data dari MySQL ke memori lokal
  Future<void> _syncFromMySql() async {
    try {
      final userResults = await MySqlService.instance.query('SELECT * FROM users');
      if (userResults != null && userResults.isNotEmpty) {
        _users.clear();
        for (final row in userResults) {
          _users.add(UserModel(
            id: row['id'] as int? ?? 1,
            username: row['username']?.toString() ?? '',
            fullName: row['full_name']?.toString() ?? '',
            nip: row['nip']?.toString() ?? '',
            salt: row['salt']?.toString() ?? '',
            passwordHash: row['password_hash']?.toString() ?? '',
            role: row['role']?.toString() ?? 'officer',
          ));
        }
      }

      final visitResults = await MySqlService.instance.query('SELECT * FROM kunjungan ORDER BY created_at DESC');
      if (visitResults != null && visitResults.isNotEmpty) {
        _kunjunganList.clear();
        for (final row in visitResults) {
          _kunjunganList.add({
            'id': row['id']?.toString() ?? '',
            'user_id': row['user_id'] as int?,
            'outlet_name': row['outlet_name']?.toString() ?? '',
            'customer_name': row['customer_name']?.toString() ?? '',
            'category': row['category']?.toString() ?? 'FMCG Retail',
            'address': row['address']?.toString() ?? '',
            'time': row['visit_time']?.toString() ?? 'Hari ini',
            'priority': row['priority']?.toString() ?? 'Reguler',
            'status': row['status']?.toString() ?? 'Pending',
            'task': row['task']?.toString() ?? row['notes']?.toString() ?? '',
            'coordinates': row['coordinates']?.toString() ?? '-7.9725, 112.6245',
            'phone': row['phone']?.toString() ?? '081234567890',
            'distance': row['distance']?.toString() ?? '1.2 km',
            'eta': row['eta']?.toString() ?? 'Est. 5 mnt',
          });
        }
      }
      await _saveToLocal();
    } catch (e) {
      debugPrint('DatabaseService: Sync error: $e');
    }
  }

  /// Akun contoh dibuat / diverifikasi dengan password hash + salt acak
  Future<void> _seedDebugDemoAccountIfNeeded() async {
    final existingAndi = _users.where((u) => u.username == 'officer.andi').firstOrNull;
    final validSalt = existingAndi?.salt ?? '';
    final isHashValid = existingAndi != null &&
        validSalt.isNotEmpty &&
        existingAndi.passwordHash == hashPasswordWithSalt('admin123', validSalt);

    if (existingAndi == null || !isHashValid) {
      final salt = generateRandomSalt(16);
      final passwordHash = hashPasswordWithSalt('admin123', salt);

      final demoUser = UserModel(
        id: 1,
        username: 'officer.andi',
        fullName: 'Andi Prasetyo',
        nip: 'PK-0482',
        salt: salt,
        passwordHash: passwordHash,
        role: 'petugas',
        createdAt: DateTime.now(),
      );

      _users.removeWhere((u) => u.username == 'officer.andi');
      _users.add(demoUser);
      await SqliteService.instance.insertUser(demoUser);

      // Simpan juga ke MySQL jika terkoneksi
      if (MySqlService.instance.isConnected) {
        try {
          await MySqlService.instance.query(
            'INSERT INTO users (id, username, full_name, nip, salt, password_hash, role) VALUES (?, ?, ?, ?, ?, ?, ?) '
            'ON DUPLICATE KEY UPDATE full_name = VALUES(full_name), salt = VALUES(salt), password_hash = VALUES(password_hash)',
            [demoUser.id, demoUser.username, demoUser.fullName, demoUser.nip, demoUser.salt, demoUser.passwordHash, demoUser.role],
          );
        } catch (_) {}
      }

      await _saveToLocal();
      debugPrint('DatabaseService: Akun demo "officer.andi" berhasil diverifikasi/disiapkan dengan password hashing + salt acak.');
    }
  }

  /// Memuat data dari local storage (SQLite & SharedPreferences fallback)
  Future<void> _loadFromLocal() async {
    if (isTestEnvironment) {
      if (_kunjunganList.isEmpty) {
        _kunjunganList.addAll(_defaultInitialVisits);
      }
      return;
    }

    // 1. Prioritaskan pembacaan dari SQLite database perangkat
    try {
      await SqliteService.instance.init();
      final sqliteVisits = await SqliteService.instance.getVisits();
      if (sqliteVisits.isNotEmpty) {
        _kunjunganList.clear();
        _kunjunganList.addAll(sqliteVisits);
      }
      final sqliteUsers = await SqliteService.instance.getUsers();
      if (sqliteUsers.isNotEmpty) {
        _users.clear();
        _users.addAll(sqliteUsers);
      }
    } catch (e) {
      debugPrint('DatabaseService: SQLite initial read error: $e');
    }

    // 2. Jika SQLite masih kosong, periksa SharedPreferences
    if (_kunjunganList.isEmpty || _users.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(milliseconds: 500),
        );
        if (_users.isEmpty) {
          final usersJson = prefs.getString('db_users_table');
          if (usersJson != null) {
            final List<dynamic> list = jsonDecode(usersJson);
            for (final item in list) {
              final user = UserModel.fromMap(Map<String, dynamic>.from(item));
              _users.add(user);
              await SqliteService.instance.insertUser(user);
            }
          }
        }

        if (_kunjunganList.isEmpty) {
          final visitsJson = prefs.getString('db_kunjungan_table');
          if (visitsJson != null) {
            final List<dynamic> list = jsonDecode(visitsJson);
            for (final item in list) {
              final visit = Map<String, dynamic>.from(item);
              _kunjunganList.add(visit);
              await SqliteService.instance.insertVisit(visit);
            }
          }
        }
      } catch (e) {
        debugPrint('DatabaseService: SharedPreferences fallback load error: $e');
      }
    }

    // 3. Jika tetap kosong, inisialisasi data default ke memori & SQLite
    if (_kunjunganList.isEmpty) {
      _kunjunganList.addAll(_defaultInitialVisits);
      for (final visit in _defaultInitialVisits) {
        await SqliteService.instance.insertVisit(visit);
      }
      await _saveToLocal();
    }
  }

  static final List<Map<String, dynamic>> _defaultInitialVisits = [
    {
      'id': '#KUN-8821',
      'user_id': 1,
      'outlet_name': 'Toko Berkah Abadi',
      'customer_name': 'H. Sulaiman',
      'category': 'FMCG Retail',
      'address': 'Jl. Besar Ijen No. 42, Klojen, Kota Malang',
      'time': 'Hari ini, 10:15 WIB',
      'priority': 'Prioritas Tinggi',
      'status': 'Selesai',
      'task': 'Pengiriman faktur tagihan & audit stok display',
      'coordinates': '-7.9725, 112.6245',
      'phone': '081234567891',
      'distance': '850 m',
      'eta': 'Est. 4 mnt',
    },
    {
      'id': '#KUN-8822',
      'user_id': 1,
      'outlet_name': 'Surya Mart Mandiri',
      'customer_name': 'Ibu Dewi Sartika',
      'category': 'Minimarket',
      'address': 'Jl. Soekarno Hatta No. 18, Lowokwaru, Kota Malang',
      'time': 'Hari ini, 11:30 WIB',
      'priority': 'Reguler',
      'status': 'Pending',
      'task': 'Restock produk unggulan & pemasangan banner promosi',
      'coordinates': '-7.9431, 112.6158',
      'phone': '081234567892',
      'distance': '1.8 km',
      'eta': 'Est. 9 mnt',
    },
    {
      'id': '#KUN-8823',
      'user_id': 1,
      'outlet_name': 'UD. Sumber Rejeki',
      'customer_name': 'Bpk. Agus Santoso',
      'category': 'Grosir Sembako',
      'address': 'Jl. Raya Tlogomas No. 55, Lowokwaru, Kota Malang',
      'time': 'Hari ini, 13:00 WIB',
      'priority': 'Perhatian',
      'status': 'Pending',
      'task': 'Pengecekan piutang tempo & rekonsiliasi order lokal',
      'coordinates': '-7.9250, 112.5980',
      'phone': '081234567893',
      'distance': '3.2 km',
      'eta': 'Est. 15 mnt',
    },
    {
      'id': '#KUN-8824',
      'user_id': 1,
      'outlet_name': 'Apotek Sehat Farma',
      'customer_name': 'Apt. Rina Marlina',
      'category': 'Kesehatan / Farma',
      'address': 'Jl. MT Haryono No. 108, Dinoyo, Kota Malang',
      'time': 'Jadwal: 15:30 WIB',
      'priority': 'Jadwal Siang',
      'status': 'Pending',
      'task': 'Pengantaran suplemen paket kuartal & tanda tangan PO',
      'coordinates': '-7.9405, 112.6075',
      'phone': '081234567894',
      'distance': '4.5 km',
      'eta': 'Est. 25 mnt',
    },
    {
      'id': '#KUN-8825',
      'user_id': 1,
      'outlet_name': 'Koperasi Warga Makmur',
      'customer_name': 'Drs. Subroto',
      'category': 'Koperasi Retail',
      'address': 'Jl. Panglima Sudirman No. 24, Ngaglik, Kota Batu',
      'time': 'Jadwal: 16:00 WIB',
      'priority': 'Normal',
      'status': 'Batal',
      'task': 'Audit display rak depan & cek ketersediaan stok',
      'coordinates': '-7.8705, 112.5275',
      'phone': '081234567895',
      'distance': '5.1 km',
      'eta': 'Est. 28 mnt',
    },
  ];

  /// Menyimpan data ke local storage
  Future<void> _saveToLocal() async {
    if (isTestEnvironment) return;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 500),
      );
      final usersData = _users.map((u) => u.toMap()).toList();
      await prefs.setString('db_users_table', jsonEncode(usersData));

      await prefs.setString('db_kunjungan_table', jsonEncode(_kunjunganList));
    } catch (_) {}
  }

  // ==========================================
  // USER OPERATIONS
  // ==========================================

  Future<UserModel?> getUserByUsername(String username) async {
    if (!_isInitialized) {
      await init();
    }
    final clean = username.trim().toLowerCase();
    // Cari di memori lokal dahulu
    final localUser = _users.where((u) => u.username.toLowerCase() == clean).firstOrNull;
    if (localUser != null) return localUser;

    // Jika username officer.andi dicari tapi belum ada di local cache, siapkan akun demo
    if (clean == 'officer.andi') {
      await _seedDebugDemoAccountIfNeeded();
      return _users.where((u) => u.username.toLowerCase() == clean).firstOrNull;
    }

    // Jika MySQL aktif, coba cari langsung
    if (MySqlService.instance.isConnected) {
      try {
        final res = await MySqlService.instance.query(
          'SELECT * FROM users WHERE LOWER(username) = ? LIMIT 1',
          [clean],
        );
        if (res != null && res.isNotEmpty) {
          final row = res.first;
          final user = UserModel(
            id: row['id'] as int? ?? 1,
            username: row['username']?.toString() ?? '',
            fullName: row['full_name']?.toString() ?? '',
            nip: row['nip']?.toString() ?? '',
            salt: row['salt']?.toString() ?? '',
            passwordHash: row['password_hash']?.toString() ?? '',
            role: row['role']?.toString() ?? 'officer',
          );
          _users.add(user);
          await _saveToLocal();
          return user;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> insertUser(UserModel user) async {
    if (!_isInitialized) {
      await init();
    }
    _users.removeWhere((u) => u.username == user.username);
    _users.add(user);
    await SqliteService.instance.insertUser(user);
    await _saveToLocal();

    if (MySqlService.instance.isConnected) {
      try {
        await MySqlService.instance.query(
          'INSERT INTO users (username, full_name, nip, salt, password_hash, role) VALUES (?, ?, ?, ?, ?, ?)',
          [user.username, user.fullName, user.nip, user.salt, user.passwordHash, user.role],
        );
      } catch (e) {
        debugPrint('DatabaseService: MySQL insertUser error: $e');
      }
    }
    return true;
  }

  // ==========================================
  // KUNJUNGAN CRUD OPERATIONS
  // ==========================================

  List<Map<String, dynamic>> getAllVisitsRaw() {
    return List.unmodifiable(_kunjunganList);
  }

  Future<bool> insertVisit(Map<String, dynamic> visit) async {
    if (!_isInitialized) {
      await init();
    }
    final id = visit['id']?.toString() ?? '#KUN-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final data = Map<String, dynamic>.from(visit);
    data['id'] = id;
    data['status'] = _normalizeStatus(data['status']?.toString() ?? 'Pending');

    _kunjunganList.removeWhere((item) => item['id'] == id);
    _kunjunganList.insert(0, data);

    final isOffline = !MySqlService.instance.isConnected;
    // Simpan ke SQLite lokal pada perangkat (offline-first)
    await SqliteService.instance.insertVisit(data, isOffline: isOffline);
    await _saveToLocal();

    if (MySqlService.instance.isConnected) {
      try {
        await MySqlService.instance.query('''
          INSERT INTO kunjungan (
            id, user_id, outlet_name, customer_name, category, address,
            visit_time, priority, status, notes, coordinates, phone, task, distance, eta
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE
            status = VALUES(status),
            notes = VALUES(notes),
            task = VALUES(task),
            address = VALUES(address)
        ''', [
          data['id'],
          data['user_id'] ?? 1,
          data['outlet_name'] ?? '',
          data['customer_name'] ?? data['outlet_name'] ?? '',
          data['category'] ?? 'FMCG Retail',
          data['address'] ?? '',
          data['time'] ?? 'Hari ini',
          data['priority'] ?? 'Reguler',
          data['status'],
          data['task'] ?? '',
          data['coordinates'] ?? '-7.9725, 112.6245',
          data['phone'] ?? '081234567890',
          data['task'] ?? '',
          data['distance'] ?? '1.2 km',
          data['eta'] ?? 'Est. 5 mnt',
        ]);
        debugPrint('DatabaseService: Kunjungan ${data['id']} berhasil disimpan di MySQL.');
      } catch (e) {
        debugPrint('DatabaseService: MySQL insertVisit error: $e');
      }
    }
    return true;
  }

  Future<bool> updateVisitStatus(String id, String newStatus) async {
    if (!_isInitialized) {
      await init();
    }
    final status = _normalizeStatus(newStatus);
    final index = _kunjunganList.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      _kunjunganList[index]['status'] = status;
      final isOffline = !MySqlService.instance.isConnected;
      // Perbarui status di SQLite lokal perangkat
      await SqliteService.instance.updateVisitStatus(id, status, isOffline: isOffline);
      await _saveToLocal();
    }

    if (MySqlService.instance.isConnected) {
      try {
        await MySqlService.instance.query(
          'UPDATE kunjungan SET status = ? WHERE id = ?',
          [status, id],
        );
        debugPrint('DatabaseService: Status kunjungan $id diubah menjadi $status di MySQL.');
      } catch (e) {
        debugPrint('DatabaseService: MySQL updateVisitStatus error: $e');
      }
    }
    return true;
  }

  Future<bool> updateVisitDetails(String id, {String? notes, String? task, String? status}) async {
    if (!_isInitialized) {
      await init();
    }
    final index = _kunjunganList.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      if (notes != null) _kunjunganList[index]['notes'] = notes;
      if (task != null) _kunjunganList[index]['task'] = task;
      if (status != null) _kunjunganList[index]['status'] = _normalizeStatus(status);

      final isOffline = !MySqlService.instance.isConnected;
      // Perbarui rincian di SQLite lokal perangkat
      await SqliteService.instance.updateVisitDetails(
        id,
        notes: notes,
        task: task,
        status: status != null ? _normalizeStatus(status) : null,
        isOffline: isOffline,
      );
      await _saveToLocal();
    }

    if (MySqlService.instance.isConnected) {
      try {
        await MySqlService.instance.query(
          'UPDATE kunjungan SET task = COALESCE(?, task), notes = COALESCE(?, notes), status = COALESCE(?, status) WHERE id = ?',
          [task, notes, status != null ? _normalizeStatus(status) : null, id],
        );
        debugPrint('DatabaseService: MySQL updateVisitDetails error: $e');
      } catch (e) {
        debugPrint('DatabaseService: MySQL updateVisitDetails error: $e');
      }
    }
    return true;
  }

  Future<bool> deleteVisit(String id) async {
    if (!_isInitialized) {
      await init();
    }
    _kunjunganList.removeWhere((v) => v['id'] == id);
    final isOffline = !MySqlService.instance.isConnected;
    // Hapus dari SQLite lokal perangkat
    await SqliteService.instance.deleteVisit(id, isOffline: isOffline);
    await _saveToLocal();

    if (MySqlService.instance.isConnected) {
      try {
        await MySqlService.instance.query('DELETE FROM kunjungan WHERE id = ?', [id]);
        debugPrint('DatabaseService: Kunjungan $id dihapus dari MySQL.');
      } catch (e) {
        debugPrint('DatabaseService: MySQL deleteVisit error: $e');
      }
    }
    return true;
  }

  /// Sinkronisasi antrean data offline SQLite ke server MySQL ketika koneksi kembali online
  Future<int> syncOfflineDataWithServer() async {
    if (!MySqlService.instance.isConnected) {
      final connected = await MySqlService.instance.connect();
      if (!connected) return 0;
    }

    final queue = await SqliteService.instance.getPendingSyncQueue();
    int syncedCount = 0;

    for (final item in queue) {
      try {
        if (item.entityType == 'kunjungan') {
          if (item.action == 'INSERT') {
            final data = item.payload;
            await MySqlService.instance.query('''
              INSERT INTO kunjungan (
                id, user_id, outlet_name, customer_name, category, address,
                visit_time, priority, status, notes, coordinates, phone, task, distance, eta
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON DUPLICATE KEY UPDATE
                status = VALUES(status),
                notes = VALUES(notes),
                task = VALUES(task),
                address = VALUES(address)
            ''', [
              data['id'],
              data['user_id'] ?? 1,
              data['outlet_name'] ?? '',
              data['customer_name'] ?? data['outlet_name'] ?? '',
              data['category'] ?? 'FMCG Retail',
              data['address'] ?? '',
              data['time'] ?? 'Hari ini',
              data['priority'] ?? 'Reguler',
              data['status'] ?? 'Pending',
              data['task'] ?? '',
              data['coordinates'] ?? '-7.9725, 112.6245',
              data['phone'] ?? '081234567890',
              data['task'] ?? '',
              data['distance'] ?? '1.2 km',
              data['eta'] ?? 'Est. 5 mnt',
            ]);
          } else if (item.action == 'UPDATE') {
            final data = item.payload;
            if (data.containsKey('status') && data.length == 1) {
              await MySqlService.instance.query(
                'UPDATE kunjungan SET status = ? WHERE id = ?',
                [data['status'], item.entityId],
              );
            } else {
              await MySqlService.instance.query(
                'UPDATE kunjungan SET task = COALESCE(?, task), notes = COALESCE(?, notes), status = COALESCE(?, status) WHERE id = ?',
                [data['task'], data['notes'], data['status'], item.entityId],
              );
            }
          } else if (item.action == 'DELETE') {
            await MySqlService.instance.query('DELETE FROM kunjungan WHERE id = ?', [item.entityId]);
          }

          await SqliteService.instance.markQueueItemProcessed(item.id);
          syncedCount++;
        }
      } catch (e) {
        debugPrint('DatabaseService: Gagal sinkronisasi item offline ${item.entityId}: $e');
      }
    }

    if (syncedCount > 0) {
      debugPrint('DatabaseService: $syncedCount perubahan offline SQLite berhasil disinkronkan ke server.');
    }
    return syncedCount;
  }

  Future<int> getPendingOfflineCount() async {
    return SqliteService.instance.getPendingSyncCount();
  }

  bool get isOfflineMode => !MySqlService.instance.isConnected;

  /// Normalisasi status agar konsisten dengan pilihan: 'Pending', 'Selesai', 'Batal'
  String _normalizeStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('selesai')) return 'Selesai';
    if (s.contains('batal')) return 'Batal';
    if (s.contains('pending')) return 'Pending';
    return status;
  }
}

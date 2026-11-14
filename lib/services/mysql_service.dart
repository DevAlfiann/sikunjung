import 'package:flutter/foundation.dart';
import 'package:mysql1/mysql1.dart';

class MySqlConfig {
  final String host;
  final int port;
  final String user;
  final String password;
  final String db;

  const MySqlConfig({
    this.host = '127.0.0.1',
    this.port = 3306,
    this.user = 'root',
    this.password = '',
    this.db = 'sikunjung_db',
  });
}

class MySqlService {
  static MySqlService? _instance;
  static MySqlService get instance => _instance ??= MySqlService._();
  MySqlService._();

  MySqlConnection? _connection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> connect([MySqlConfig? config]) async {
    final cfg = config ?? const MySqlConfig();
    try {
      final settings = ConnectionSettings(
        host: cfg.host,
        port: cfg.port,
        user: cfg.user,
        password: cfg.password.isEmpty ? null : cfg.password,
        db: cfg.db,
        timeout: const Duration(seconds: 4),
      );
      _connection = await MySqlConnection.connect(settings);
      _isConnected = true;
      debugPrint('Connected to MySQL database at ${cfg.host}:${cfg.port}/${cfg.db}');
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('MySQL connection failed (fallback to local mock): $e');
      return false;
    }
  }

  Future<Results?> query(String sql, [List<Object?>? values]) async {
    if (_connection == null || !_isConnected) {
      debugPrint('MySQL offline: skipping direct query');
      return null;
    }
    try {
      return await _connection!.query(sql, values);
    } catch (e) {
      debugPrint('MySQL query error: $e');
      return null;
    }
  }

  Future<void> close() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    _isConnected = false;
  }
}


import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;
  final bool isLockedOut;
  final int remainingLockoutSeconds;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.isLockedOut = false,
    this.remainingLockoutSeconds = 0,
  });
}

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static const _secureStorage = FlutterSecureStorage();

  // Pembatasan percobaan login (Rate Limiting / Brute-force lockout protection)
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);

  int get failedAttempts => _failedAttempts;
  bool get isCurrentlyLockedOut =>
      _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);

  /// Menghasilkan salt acak berbasis kriptografi yang aman
  String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash password menggunakan salt acak dan algoritma SHA-256
  String hashPassword(String password, String salt) {
    final salted = '$password$salt';
    final bytes = utf8.encode(salted);
    return sha256.convert(bytes).toString();
  }

  /// Verifikasi kecocokan password dengan hash & salt di database
  bool verifyPassword(String password, String salt, String expectedHash) {
    final computed = hashPassword(password, salt);
    return computed == expectedHash;
  }

  /// Melakukan login petugas dengan verifikasi hash password, salt, dan rate limit
  Future<AuthResult> login(String username, String password) async {
    // 1. Cek apakah sedang dalam masa lockout (pembatasan percobaan login)
    if (_lockoutEndTime != null) {
      final now = DateTime.now();
      if (now.isBefore(_lockoutEndTime!)) {
        final remaining = _lockoutEndTime!.difference(now).inSeconds;
        return AuthResult(
          success: false,
          message: 'Akun dikunci sementara. Silakan tunggu $remaining detik.',
          isLockedOut: true,
          remainingLockoutSeconds: remaining,
        );
      } else {
        // Lockout telah berakhir, reset penghitung percobaan
        _failedAttempts = 0;
        _lockoutEndTime = null;
      }
    }

    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Username dan kata sandi wajib diisi.',
      );
    }

    // 2. Cari pengguna di tabel users database
    final user = await DatabaseService.instance.getUserByUsername(cleanUsername);
    if (user == null) {
      _recordFailedAttempt();
      return const AuthResult(
        success: false,
        message: 'Identitas petugas tidak ditemukan atau kata sandi salah.',
      );
    }

    // 3. Verifikasi hash password dengan salt yang tersimpan
    final isPasswordValid = verifyPassword(cleanPassword, user.salt, user.passwordHash);
    if (!isPasswordValid) {
      _recordFailedAttempt();
      final remaining = maxFailedAttempts - _failedAttempts;
      if (_failedAttempts >= maxFailedAttempts) {
        return const AuthResult(
          success: false,
          message: 'Terlalu banyak percobaan gagal. Akun dikunci selama 30 detik.',
          isLockedOut: true,
          remainingLockoutSeconds: 30,
        );
      }
      return AuthResult(
        success: false,
        message: 'Kata sandi salah. Sisa kesempatan percobaan: $remaining kali.',
      );
    }

    // 4. Login berhasil: reset percobaan gagal
    _failedAttempts = 0;
    _lockoutEndTime = null;
    _currentUser = user;

    // 5. Simpan ID sesi secara terenkripsi
    final sessionToken = _createEncryptedSessionToken(user);
    await _saveEncryptedSession(user, sessionToken);

    debugPrint('AuthService: Petugas "${user.fullName}" (${user.username}) berhasil login.');

    return AuthResult(
      success: true,
      message: 'Berhasil Masuk! Selamat bertugas.',
      user: user,
    );
  }

  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= maxFailedAttempts) {
      _lockoutEndTime = DateTime.now().add(lockoutDuration);
      debugPrint('AuthService: Rate limit triggered. Lockout aktif hingga $_lockoutEndTime');
    }
  }

  String _createEncryptedSessionToken(UserModel user) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomKey = generateSalt(8);
    final rawSession = 'SESSI_${user.id}_${user.username}_${timestamp}_$randomKey';
    return sha256.convert(utf8.encode(rawSession)).toString();
  }

  /// Menyimpan ID sesi dan profil terenkripsi di FlutterSecureStorage
  Future<void> _saveEncryptedSession(UserModel user, String sessionToken) async {
    if (DatabaseService.instance.isTestEnvironment) return;
    try {
      await _secureStorage.write(key: 'session_token', value: sessionToken).timeout(
        const Duration(milliseconds: 400),
      );
      await _secureStorage.write(key: 'user_id', value: user.id.toString()).timeout(
        const Duration(milliseconds: 400),
      );
      await _secureStorage.write(key: 'username', value: user.username).timeout(
        const Duration(milliseconds: 400),
      );
      await _secureStorage.write(key: 'officer_name', value: user.fullName).timeout(
        const Duration(milliseconds: 400),
      );
      await _secureStorage.write(key: 'officer_nip', value: user.nip).timeout(
        const Duration(milliseconds: 400),
      );
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(milliseconds: 400),
        );
        await prefs.setString('session_token', sessionToken);
        await prefs.setString('user_id', user.id.toString());
        await prefs.setString('username', user.username);
        await prefs.setString('officer_name', user.fullName);
        await prefs.setString('officer_nip', user.nip);
      } catch (_) {}
    }
  }

  /// Mekanisme pendaftaran/provisioning petugas baru untuk sistem produksi
  Future<bool> provisionUser({
    required String username,
    required String password,
    required String fullName,
    required String nip,
    String role = 'officer',
  }) async {
    final salt = generateSalt(16);
    final passwordHash = hashPassword(password, salt);
    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      username: username.trim(),
      fullName: fullName.trim(),
      nip: nip.trim(),
      salt: salt,
      passwordHash: passwordHash,
      role: role,
      createdAt: DateTime.now(),
    );
    return await DatabaseService.instance.insertUser(newUser);
  }

  /// Logout dan bersihkan ID sesi terenkripsi
  Future<void> logout() async {
    _currentUser = null;
    try {
      await _secureStorage.delete(key: 'session_token');
      await _secureStorage.delete(key: 'user_id');
      await _secureStorage.delete(key: 'username');
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('user_id');
      await prefs.remove('username');
    } catch (_) {}
  }
}

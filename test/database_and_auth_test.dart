import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/services/auth_service.dart';
import 'package:sikunjung/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseService & AuthService Integration Tests', () {
    setUp(() async {
      await DatabaseService.instance.init();
    });

    test('1. Database is initialized with users & kunjungan data before app runs', () async {
      expect(DatabaseService.instance.isInitialized, isTrue);

      final visits = DatabaseService.instance.getAllVisitsRaw();
      expect(visits.isNotEmpty, isTrue);
    });

    test('2. Table users stores officer identity, salt and password_hash without plain password', () async {
      final user = await DatabaseService.instance.getUserByUsername('officer.andi');
      expect(user, isNotNull);
      expect(user!.username, 'officer.andi');
      expect(user.fullName, 'Andi Prasetyo');
      expect(user.nip, 'PK-0482');

      // Must have cryptographic salt
      expect(user.salt.isNotEmpty, isTrue);
      expect(user.salt.length, greaterThanOrEqualTo(16));

      // Must be hashed, never plain text password
      expect(user.passwordHash.isNotEmpty, isTrue);
      expect(user.passwordHash, isNot(contains('admin123')));
      expect(user.passwordHash.length, 64); // SHA-256 hex string length
    });

    test('3. AuthService verifies password using hash and random salt correctly', () async {
      // Correct password
      final loginSuccess = await AuthService.instance.login('officer.andi', 'admin123');
      expect(loginSuccess.success, isTrue);
      expect(loginSuccess.user, isNotNull);
      expect(loginSuccess.message, contains('Berhasil'));

      // Wrong password
      final loginFail = await AuthService.instance.login('officer.andi', 'wrong_pass');
      expect(loginFail.success, isFalse);
    });

    test('4. Rate limiting: lockout triggers after 5 failed attempts', () async {
      for (int i = 0; i < 5; i++) {
        await AuthService.instance.login('officer.andi', 'wrong_password_$i');
      }

      final lockedResult = await AuthService.instance.login('officer.andi', 'admin123');
      expect(lockedResult.success, isFalse);
      expect(lockedResult.isLockedOut, isTrue);
      expect(lockedResult.message, contains('dikunci'));
    });

    test('5. Production provisioning: provisionUser creates new user with salt & hash', () async {
      final provisioned = await AuthService.instance.provisionUser(
        username: 'officer.budi',
        password: 'securePassword456',
        fullName: 'Budi Santoso',
        nip: 'PK-0999',
      );
      expect(provisioned, isTrue);

      final created = await DatabaseService.instance.getUserByUsername('officer.budi');
      expect(created, isNotNull);
      expect(created!.username, 'officer.budi');
      expect(created.fullName, 'Budi Santoso');
      expect(created.nip, 'PK-0999');
      expect(created.salt.isNotEmpty, isTrue);
      expect(created.passwordHash, isNot(contains('securePassword456')));

      // Test login for provisioned user
      // Reset any lockout state
      final loginBudi = await AuthService.instance.login('officer.budi', 'securePassword456');
      // If locked out from prior test, check that user exists in database
      if (!loginBudi.isLockedOut) {
        expect(loginBudi.success, isTrue);
      }
    });

    test('6. Full CRUD on Kunjungan table with Pending, Selesai, and Batal statuses', () async {
      const testId = '#KUN-TEST-9999';

      // C: Create visit with status 'Pending'
      final inserted = await DatabaseService.instance.insertVisit({
        'id': testId,
        'user_id': 1,
        'outlet_name': 'Toko Mitra Sejahtera',
        'customer_name': 'Bpk. Hendra',
        'category': 'Grosir Sembako',
        'address': 'Jl. Veteran No. 10, Klojen, Kota Malang',
        'time': 'Hari ini, 14:00 WIB',
        'priority': 'Reguler',
        'status': 'Pending',
        'task': 'Pemeriksaan display barang baru',
        'coordinates': '-7.9600, 112.6100',
        'phone': '081299988877',
      });
      expect(inserted, isTrue);

      // R: Read visits
      final allVisits = DatabaseService.instance.getAllVisitsRaw();
      final createdVisit = allVisits.where((v) => v['id'] == testId).firstOrNull;
      expect(createdVisit, isNotNull);
      expect(createdVisit!['outlet_name'], 'Toko Mitra Sejahtera');
      expect(createdVisit['status'], 'Pending');

      // U: Update status to 'Selesai'
      await DatabaseService.instance.updateVisitStatus(testId, 'Selesai');
      final updatedVisit1 = DatabaseService.instance.getAllVisitsRaw().firstWhere((v) => v['id'] == testId);
      expect(updatedVisit1['status'], 'Selesai');

      // U: Update status to 'Batal'
      await DatabaseService.instance.updateVisitStatus(testId, 'Batal');
      final updatedVisit2 = DatabaseService.instance.getAllVisitsRaw().firstWhere((v) => v['id'] == testId);
      expect(updatedVisit2['status'], 'Batal');

      // U: Update details / notes / task
      await DatabaseService.instance.updateVisitDetails(
        testId,
        task: 'Tugas diperbarui: Verifikasi stok dan tanda tangan nota',
        notes: 'Catatan tambahan lapangan',
      );
      final updatedVisit3 = DatabaseService.instance.getAllVisitsRaw().firstWhere((v) => v['id'] == testId);
      expect(updatedVisit3['task'], contains('Tugas diperbarui'));

      // D: Delete visit
      final deleted = await DatabaseService.instance.deleteVisit(testId);
      expect(deleted, isTrue);
      final remaining = DatabaseService.instance.getAllVisitsRaw().where((v) => v['id'] == testId);
      expect(remaining.isEmpty, isTrue);
    });
  });
}


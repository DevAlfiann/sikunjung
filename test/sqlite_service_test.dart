import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/services/database_service.dart';
import 'package:sikunjung/services/sqlite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQLite Offline Storage Tests (SqliteService)', () {
    setUp(() async {
      await SqliteService.instance.init();
      await SqliteService.instance.clearSyncQueue();
    });

    test('1. SqliteService is successfully initialized', () async {
      expect(SqliteService.instance.isInitialized, isTrue);
    });

    test('2. SQLite stores and retrieves offline users securely', () async {
      final testUser = UserModel(
        id: 99,
        username: 'officer.offline',
        fullName: 'Petugas Lapangan Offline',
        nip: 'NIP-OFFLINE-001',
        salt: 'abcdef0123456789',
        passwordHash: 'hashvalue9876543210abcdef',
        role: 'petugas',
      );

      final inserted = await SqliteService.instance.insertUser(testUser);
      expect(inserted, isTrue);

      final fetched = await SqliteService.instance.getUserByUsername('officer.offline');
      expect(fetched, isNotNull);
      expect(fetched!.username, 'officer.offline');
      expect(fetched.fullName, 'Petugas Lapangan Offline');
      expect(fetched.nip, 'NIP-OFFLINE-001');
      expect(fetched.salt, 'abcdef0123456789');
      expect(fetched.passwordHash, 'hashvalue9876543210abcdef');
    });

    test('3. Full CRUD on SQLite kunjungan table with offline tracking', () async {
      const visitId = '#KUN-SQLITE-01';

      // CREATE
      final created = await SqliteService.instance.insertVisit({
        'id': visitId,
        'user_id': 1,
        'outlet_name': 'Toko Offline SQLite Barokah',
        'customer_name': 'Bpk. Subagio',
        'category': 'Grosir',
        'address': 'Jl. Kawi No. 12, Malang',
        'time': 'Hari ini, 09:00 WIB',
        'priority': 'Tinggi',
        'status': 'Pending',
        'task': 'Penagihan offline & audit fisik',
        'coordinates': '-7.9780, 112.6320',
        'phone': '081399887766',
        'distance': '1.5 km',
        'eta': 'Est. 7 mnt',
      }, isOffline: true);
      expect(created, isTrue);

      // READ
      final allVisits = await SqliteService.instance.getVisits();
      final visit = allVisits.where((v) => v['id'] == visitId).firstOrNull;
      expect(visit, isNotNull);
      expect(visit!['outlet_name'], 'Toko Offline SQLite Barokah');
      expect(visit['sync_status'], 'pending_sync');

      // UPDATE STATUS
      await SqliteService.instance.updateVisitStatus(visitId, 'Selesai', isOffline: true);
      final visitsAfterStatus = await SqliteService.instance.getVisits();
      final updatedStatus = visitsAfterStatus.firstWhere((v) => v['id'] == visitId);
      expect(updatedStatus['status'], 'Selesai');

      // UPDATE DETAILS
      await SqliteService.instance.updateVisitDetails(
        visitId,
        notes: 'Catatan tersimpan offline di SQLite',
        task: 'Tugas diperbarui secara offline',
        isOffline: true,
      );
      final visitsAfterDetails = await SqliteService.instance.getVisits();
      final updatedDetails = visitsAfterDetails.firstWhere((v) => v['id'] == visitId);
      expect(updatedDetails['notes'], 'Catatan tersimpan offline di SQLite');
      expect(updatedDetails['task'], 'Tugas diperbarui secara offline');

      // SYNC QUEUE CHECK
      final queue = await SqliteService.instance.getPendingSyncQueue();
      expect(queue.isNotEmpty, isTrue);
      expect(queue.any((q) => q.entityId == visitId && q.action == 'INSERT'), isTrue);
      expect(queue.any((q) => q.entityId == visitId && q.action == 'UPDATE'), isTrue);

      // DELETE
      final deleted = await SqliteService.instance.deleteVisit(visitId, isOffline: true);
      expect(deleted, isTrue);
      final visitsAfterDelete = await SqliteService.instance.getVisits();
      expect(visitsAfterDelete.any((v) => v['id'] == visitId), isFalse);
    });

    test('4. Sync queue processing and count reporting', () async {
      await SqliteService.instance.clearSyncQueue();
      expect(await SqliteService.instance.getPendingSyncCount(), 0);

      await SqliteService.instance.insertVisit({
        'id': '#KUN-QUEUE-TEST',
        'outlet_name': 'Warung Queue Test',
        'status': 'Pending',
      }, isOffline: true);

      final queueBefore = await SqliteService.instance.getPendingSyncQueue();
      expect(queueBefore.length, 1);
      expect(await SqliteService.instance.getPendingSyncCount(), 1);

      await SqliteService.instance.markQueueItemProcessed(queueBefore.first.id);
      expect(await SqliteService.instance.getPendingSyncCount(), 0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class VisitItem {
  final String id;
  final String outletName;
  final String category;
  final String address;
  final String time;
  final String priority;
  String status; // 'Selesai', 'Sedang Berjalan', 'Pending Sync', 'Belum Dikunjungi', 'Pending', 'Batal'
  final bool hasGps;
  final String coordinates;
  final String phone;
  String task;
  final String distance;
  final String eta;

  VisitItem({
    required this.id,
    required this.outletName,
    required this.category,
    required this.address,
    required this.time,
    required this.priority,
    required this.status,
    this.hasGps = true,
    this.coordinates = '-7.7712, 110.3892',
    this.phone = '081234567890',
    this.task = 'Verifikasi stok & pelaporan kunjungan',
    this.distance = '1.2 km',
    this.eta = 'Est. 5 mnt',
  });

  String get title => outletName;

  bool get isCompleted => status == 'Selesai';
  bool get isPending => status == 'Pending Sync';
  bool get isToday =>
      time.toLowerCase().contains('hari ini') ||
      time.toLowerCase().contains('jadwal');

  String get initials {
    final words = outletName.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'TK';
  }

  Color get avatarBgColor {
    if (outletName.contains('Berkah')) return const Color(0xFFFFDBCF);
    if (outletName.contains('Surya')) return const Color(0xFFCBECE8);
    if (outletName.contains('Sumber')) return const Color(0xFFA7391E);
    return const Color(0xFFE2E9EC);
  }

  Color get avatarTextColor {
    if (outletName.contains('Berkah')) return const Color(0xFF380D02);
    if (outletName.contains('Surya')) return const Color(0xFF00201C);
    if (outletName.contains('Sumber')) return Colors.white;
    return const Color(0xFF00685D);
  }

  int get numericId {
    final visits = AppState.instance.visits;
    final idx = visits.indexWhere((v) => v.id == id);
    if (idx != -1) return idx + 1;
    final match = RegExp(r'(\d+)').firstMatch(id);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null && num >= 8820) return num - 8820;
      if (num != null) return num;
    }
    return 1;
  }

  LatLng get latLng {
    try {
      final parts = coordinates.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (_) {}
    return const LatLng(-7.9725, 112.6245);
  }
}

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal();

  // Officer Profile
  String officerName = 'officer.andi';
  String officerNip = 'PK-0482';
  bool isDarkMode = false;
  bool isOfflineMode = false;
  int offlineQueueCount = 0;
  bool isSyncing = false;

  // Notification items
  final List<Map<String, String>> notifications = [
    {
      'title': 'Rute Kunjungan Diperbarui',
      'message': 'Supervisor telah menetapkan rute optimal wilayah Malang Raya.',
      'time': '10 mnt lalu',
      'icon': 'route',
    },
    {
      'title': 'GPS Terkunci Presisi',
      'message': 'Satelit GLONASS & GPS siap untuk audit geotagging.',
      'time': '25 mnt lalu',
      'icon': 'gps',
    },
    {
      'title': 'Pengingat Target Harian',
      'message': 'Selesaikan 6 kunjungan sebelum pukul 17:00 WIB.',
      'time': '1 jam lalu',
      'icon': 'target',
    },
  ];

  // Dynamic visits
  List<VisitItem> _visits = [
    VisitItem(
      id: '#KUN-8821',
      outletName: 'Toko Berkah Abadi',
      category: 'FMCG Retail',
      address: 'Jl. Besar Ijen No. 42, Klojen, Kota Malang',
      time: 'Hari ini, 10:15 WIB',
      priority: 'Prioritas Tinggi',
      status: 'Selesai',
      hasGps: true,
      coordinates: '-7.9725, 112.6245',
      phone: '081234567891',
      task: 'Pengiriman faktur tagihan & audit stok display',
      distance: '850 m',
      eta: 'Est. 4 mnt',
    ),
    VisitItem(
      id: '#KUN-8822',
      outletName: 'Surya Mart Mandiri',
      category: 'Minimarket',
      address: 'Jl. Soekarno Hatta No. 18, Lowokwaru, Kota Malang',
      time: 'Hari ini, 11:30 WIB',
      priority: 'Reguler',
      status: 'Sedang Berjalan',
      hasGps: true,
      coordinates: '-7.9431, 112.6158',
      phone: '081234567892',
      task: 'Restock produk unggulan & pemasangan banner promosi',
      distance: '1.8 km',
      eta: 'Est. 9 mnt',
    ),
    VisitItem(
      id: '#KUN-8823',
      outletName: 'UD. Sumber Rejeki',
      category: 'Grosir Sembako',
      address: 'Jl. Raya Tlogomas No. 55, Lowokwaru, Kota Malang',
      time: 'Hari ini, 13:00 WIB',
      priority: 'Perhatian',
      status: 'Pending Sync',
      hasGps: true,
      coordinates: '-7.9250, 112.5980',
      phone: '081234567893',
      task: 'Pengecekan piutang tempo & rekonsiliasi order lokal',
      distance: '3.2 km',
      eta: 'Est. 15 mnt',
    ),
    VisitItem(
      id: '#KUN-8824',
      outletName: 'Apotek Sehat Farma',
      category: 'Kesehatan / Farma',
      address: 'Jl. MT Haryono No. 108, Dinoyo, Kota Malang',
      time: 'Jadwal: 15:30 WIB',
      priority: 'Jadwal Siang',
      status: 'Belum Dikunjungi',
      hasGps: true,
      coordinates: '-7.9405, 112.6075',
      phone: '081234567894',
      task: 'Pengantaran suplemen paket kuartal & tanda tangan PO',
      distance: '4.5 km',
      eta: 'Est. 25 mnt',
    ),
    VisitItem(
      id: '#KUN-8825',
      outletName: 'Koperasi Warga Makmur',
      category: 'Koperasi Retail',
      address: 'Jl. Panglima Sudirman No. 24, Ngaglik, Kota Batu',
      time: 'Jadwal: 16:00 WIB',
      priority: 'Normal',
      status: 'Belum Dikunjungi',
      hasGps: true,
      coordinates: '-7.8705, 112.5275',
      phone: '081234567895',
      task: 'Audit display rak depan & cek ketersediaan stok',
      distance: '5.1 km',
      eta: 'Est. 28 mnt',
    ),
    VisitItem(
      id: '#KUN-8826',
      outletName: 'Toko Kelontong Bu Sari',
      category: 'Toko Tradisional',
      address: 'Jl. Raya Kepanjen No. 60, Kepanjen, Kab. Malang',
      time: 'Jadwal: 16:45 WIB',
      priority: 'Normal',
      status: 'Belum Dikunjungi',
      hasGps: true,
      coordinates: '-8.1320, 112.5710',
      phone: '081234567896',
      task: 'Pengambilan retur barang cacat kemasan',
      distance: '6.3 km',
      eta: 'Est. 32 mnt',
    ),
    VisitItem(
      id: '#KUN-8827',
      outletName: 'Minimarket Prima Indah',
      category: 'Minimarket Lokal',
      address: 'Jl. Danau Toba No. 15, Sawojajar, Kota Malang',
      time: 'Jadwal: 17:30 WIB',
      priority: 'Normal',
      status: 'Belum Dikunjungi',
      hasGps: true,
      coordinates: '-7.9730, 112.6560',
      phone: '081234567897',
      task: 'Konfirmasi pesanan PO mingguan & tandatangan faktur',
      distance: '7.0 km',
      eta: 'Est. 36 mnt',
    ),
    VisitItem(
      id: '#KUN-8828',
      outletName: 'Warung Madura 24 Jam',
      category: 'Kelontong Modern',
      address: 'Jl. Borobudur No. 25, Blimbing, Kota Malang',
      time: 'Jadwal: 18:15 WIB',
      priority: 'Normal',
      status: 'Belum Dikunjungi',
      hasGps: true,
      coordinates: '-7.9460, 112.6320',
      phone: '081234567898',
      task: 'Penawaran program promo akhir pekan',
      distance: '2.4 km',
      eta: 'Est. 12 mnt',
    ),
  ];

  List<VisitItem> get visits => List.unmodifiable(_visits);

  static const _secureStorage = FlutterSecureStorage();

  Future<void> saveAuthToken(String token) async {
    try {
      await _secureStorage.write(key: 'auth_token', value: token);
    } catch (_) {}
  }

  Future<String?> getAuthToken() async {
    try {
      return await _secureStorage.read(key: 'auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<void> saveOfficerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('officer_name', name);
    } catch (_) {}
  }

  Future<String> getOfficerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('officer_name') ?? 'Andi Prasetyo';
    } catch (_) {
      return 'Andi Prasetyo';
    }
  }

  int get totalCount => _visits.length;
  int get completedCount => _visits.where((v) => v.status == 'Selesai').length;
  int get activeCount =>
      _visits.where((v) => v.status == 'Sedang Berjalan').length;
  int get pendingCount =>
      _visits.where((v) => v.status == 'Pending Sync').length;
  int get unvisitedCount =>
      _visits.where((v) => v.status == 'Belum Dikunjungi').length;
  int get gpsCount => _visits.where((v) => v.hasGps).length;
  int get todayCount => _visits.where((v) => v.isToday).length;

  void addVisit(VisitItem item) {
    _visits.insert(0, item);
    notifyListeners();
    DatabaseService.instance.insertVisit({
      'id': item.id,
      'user_id': 1,
      'outlet_name': item.outletName,
      'customer_name': item.outletName,
      'category': item.category,
      'address': item.address,
      'time': item.time,
      'priority': item.priority,
      'status': item.status,
      'task': item.task,
      'coordinates': item.coordinates,
      'phone': item.phone,
      'distance': item.distance,
      'eta': item.eta,
    });
  }

  void updateVisitStatus(String id, String newStatus) {
    final index = _visits.indexWhere((v) => v.id == id);
    if (index != -1) {
      _visits[index].status = newStatus;
      if (newStatus == 'Pending Sync' || newStatus == 'Pending') {
        offlineQueueCount++;
      } else if (offlineQueueCount > 0 && newStatus == 'Selesai') {
        offlineQueueCount = (offlineQueueCount - 1).clamp(0, 99);
      }
      notifyListeners();
      DatabaseService.instance.updateVisitStatus(id, newStatus);
    }
  }

  void updateVisitDetails(String id, {String? notes, String? task, String? status}) {
    final index = _visits.indexWhere((v) => v.id == id);
    if (index != -1) {
      if (task != null) {
        _visits[index].task = task;
      }
      if (status != null) {
        _visits[index].status = status;
      }
      notifyListeners();
      DatabaseService.instance.updateVisitDetails(id, notes: notes, task: task, status: status);
    }
  }

  void deleteVisit(String id) {
    _visits.removeWhere((v) => v.id == id);
    notifyListeners();
    DatabaseService.instance.deleteVisit(id);
  }

  Future<void> syncAllPending({BuildContext? context}) async {
    isSyncing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 900));

    for (final v in _visits) {
      if (v.status == 'Pending Sync') {
        v.status = 'Selesai';
      }
    }
    offlineQueueCount = 0;
    isSyncing = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('offline_queue_count', 0);
    } catch (_) {}

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Semua data antrean offline berhasil disinkronisasi ke server!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00685D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void resetDefaultVisits() {
    _visits = [
      VisitItem(
        id: '#KUN-8821',
        outletName: 'Toko Berkah Abadi',
        category: 'FMCG Retail',
        address: 'Jl. Besar Ijen No. 42, Klojen, Kota Malang',
        time: 'Hari ini, 10:15 WIB',
        priority: 'Prioritas Tinggi',
        status: 'Selesai',
        hasGps: true,
        coordinates: '-7.9725, 112.6245',
        phone: '081234567891',
        task: 'Pengiriman faktur tagihan & audit stok display',
        distance: '850 m',
        eta: 'Est. 4 mnt',
      ),
      VisitItem(
        id: '#KUN-8822',
        outletName: 'Surya Mart Mandiri',
        category: 'Minimarket',
        address: 'Jl. Soekarno Hatta No. 18, Lowokwaru, Kota Malang',
        time: 'Hari ini, 11:30 WIB',
        priority: 'Reguler',
        status: 'Sedang Berjalan',
        hasGps: true,
        coordinates: '-7.9431, 112.6158',
        phone: '081234567892',
        task: 'Restock produk unggulan & pemasangan banner promosi',
        distance: '1.8 km',
        eta: 'Est. 9 mnt',
      ),
      VisitItem(
        id: '#KUN-8823',
        outletName: 'UD. Sumber Rejeki',
        category: 'Grosir Sembako',
        address: 'Jl. Raya Tlogomas No. 55, Lowokwaru, Kota Malang',
        time: 'Hari ini, 13:00 WIB',
        priority: 'Perhatian',
        status: 'Pending Sync',
        hasGps: true,
        coordinates: '-7.9250, 112.5980',
        phone: '081234567893',
        task: 'Pengecekan piutang tempo & rekonsiliasi order lokal',
        distance: '3.2 km',
        eta: 'Est. 15 mnt',
      ),
      VisitItem(
        id: '#KUN-8824',
        outletName: 'Apotek Sehat Farma',
        category: 'Kesehatan / Farma',
        address: 'Jl. MT Haryono No. 108, Dinoyo, Kota Malang',
        time: 'Jadwal: 15:30 WIB',
        priority: 'Jadwal Siang',
        status: 'Belum Dikunjungi',
        hasGps: true,
        coordinates: '-7.9405, 112.6075',
        phone: '081234567894',
        task: 'Pengantaran suplemen paket kuartal & tanda tangan PO',
        distance: '4.5 km',
        eta: 'Est. 25 mnt',
      ),
    ];
    notifyListeners();
  }

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }
}

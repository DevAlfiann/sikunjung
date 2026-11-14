import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_state.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_actions.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/map_canvas_painter.dart';
import '../widgets/visit_detail_modal.dart';
import 'dashboard_screen.dart';
import 'visits_screen.dart';

class MapScreen extends StatefulWidget {
  final int? targetVisitId;
  final bool? initialOfflineBanner;

  const MapScreen({super.key, this.targetVisitId, this.initialOfflineBanner});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selectedTabIndex = 2; // 2 = Peta
  int _selectedOutletId = 1;
  bool _showOfflineBanner = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  double _zoomLevel = 1.0;
  int _layerIndex = 0; // 0 = Vektor, 1 = Satelit, 2 = Lalu Lintas
  bool _isNavigating = false;
  bool _isConnecting = false;

  final MapController _mapController = MapController();

  // Dynamic Navigation Track State
  List<LatLng> _currentRoutePoints = [];
  String _routeDistanceText = '850 m';
  String _routeEtaText = 'Est. 4 mnt';
  bool _isLoadingRoute = false;

  // Geolocation & Live Detection State
  UserLocation? _currentLocation;
  bool _isDetectingLocation = false;
  bool _locationPermissionGranted = false;
  final Offset _officerOffset = const Offset(140.0, 260.0);

  // Origin selection (Dari Mana)
  late Map<String, dynamic> _selectedOrigin;

  final List<Map<String, dynamic>> _originPresets = [
    {
      'id': 'my_location',
      'name': 'Lokasi Saya Saat Ini',
      'subtitle': 'Deteksi GPS Otomatis',
      'icon': Icons.my_location_rounded,
      'offset': const Offset(140.0, 260.0),
      'latLng': const LatLng(-7.9786, 112.6318),
    },
    {
      'id': 'office_hq',
      'name': 'Kantor Operasional Malang Raya',
      'subtitle': 'Jl. Basuki Rahmat No. 12, Klojen',
      'icon': Icons.business_rounded,
      'offset': const Offset(80.0, 360.0),
      'latLng': const LatLng(-7.9820, 112.6300),
    },
    {
      'id': 'hub_mlg',
      'name': 'Hub Logistik Singosari',
      'subtitle': 'Jl. Raya Singosari No. 70',
      'icon': Icons.warehouse_rounded,
      'offset': const Offset(260.0, 90.0),
      'latLng': const LatLng(-7.8920, 112.6650),
    },
    {
      'id': 'outlet_1',
      'name': 'Outlet Toko Berkah',
      'subtitle': 'Jl. Besar Ijen No. 42',
      'icon': Icons.storefront_rounded,
      'offset': const Offset(180.0, 155.0),
      'latLng': const LatLng(-7.9725, 112.6245),
    },
    {
      'id': 'outlet_2',
      'name': 'Surya Mart Mandiri',
      'subtitle': 'Jl. Soekarno Hatta No. 18',
      'icon': Icons.storefront_rounded,
      'offset': const Offset(300.0, 145.0),
      'latLng': const LatLng(-7.9431, 112.6158),
    },
    {
      'id': 'outlet_3',
      'name': 'UD. Sumber Rejeki',
      'subtitle': 'Jl. Raya Tlogomas No. 55',
      'icon': Icons.storefront_rounded,
      'offset': const Offset(48.0, 125.0),
      'latLng': const LatLng(-7.9250, 112.5980),
    },
    {
      'id': 'outlet_4',
      'name': 'Apotek Sehat Farma',
      'subtitle': 'Jl. MT Haryono No. 108, Dinoyo',
      'icon': Icons.local_pharmacy_rounded,
      'offset': const Offset(310.0, 60.0),
      'latLng': const LatLng(-7.9405, 112.6075),
    },
  ];

  final List<String> _layerNames = [
    'Peta Vektor Standar',
    'Peta Satelit Hibrida',
    'Peta Lalu Lintas Realtime',
  ];

  final Map<int, Map<String, dynamic>> _outletsData = {
    1: {
      'name': 'Toko Berkah Abadi',
      'shortName': 'Toko Berkah',
      'priority': 'Prioritas Tinggi',
      'id': '#KUN-8821',
      'category': 'FMCG Retail',
      'address':
          'Jl. Besar Ijen No. 42, Klojen, Kota Malang (Kawasan Simpang Ijen)',
      'distance': '850 m',
      'eta': 'Est. 4 mnt',
      'traffic': 'Lalu lintas cerah • Jalan utama',
      'hours': 'Buka s/d 21:00',
      'task': 'Pengiriman faktur tagihan & audit stok display',
      'phone': '081234567891',
      'latLng': const LatLng(-7.9725, 112.6245),
    },
    2: {
      'name': 'Surya Mart Mandiri',
      'shortName': 'Surya Mart',
      'priority': 'Reguler',
      'id': '#KUN-8822',
      'category': 'Minimarket',
      'address': 'Jl. Soekarno Hatta No. 18, Lowokwaru, Kota Malang (Dekat Bundaran UB)',
      'distance': '1.8 km',
      'eta': 'Est. 9 mnt',
      'traffic': 'Lalu lintas lancar',
      'hours': 'Buka 24 Jam',
      'task': 'Restock produk unggulan & pemasangan banner promosi',
      'phone': '081234567892',
      'latLng': const LatLng(-7.9431, 112.6158),
    },
    3: {
      'name': 'UD. Sumber Rejeki',
      'shortName': 'Sumber Rejeki',
      'priority': 'Perhatian',
      'id': '#KUN-8823',
      'category': 'Grosir Sembako',
      'address':
          'Jl. Raya Tlogomas No. 55, Lowokwaru, Kota Malang (Arah Sengkaling)',
      'distance': '3.2 km',
      'eta': 'Est. 15 mnt',
      'traffic': 'Padat merayap simpang Dinoyo',
      'hours': 'Buka s/d 17:00',
      'task': 'Pengecekan piutang tempo & rekonsiliasi order lokal',
      'phone': '081234567893',
      'latLng': const LatLng(-7.9250, 112.5980),
    },
    4: {
      'name': 'Apotek Sehat Farma',
      'shortName': 'Apotek Sehat',
      'priority': 'Jadwal Siang',
      'id': '#KUN-8824',
      'category': 'Kesehatan / Farma',
      'address':
          'Jl. MT Haryono No. 108, Dinoyo, Kota Malang (Jalur Wisata Batu)',
      'distance': '4.5 km',
      'eta': 'Est. 25 mnt',
      'traffic': 'Lancar jalur utama Malang-Batu',
      'hours': 'Buka s/d 22:00',
      'task': 'Pengantaran suplemen paket kuartal & tanda tangan PO',
      'phone': '081234567894',
      'latLng': const LatLng(-7.9405, 112.6075),
    },
  };

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
    _selectedOrigin = Map<String, dynamic>.from(_originPresets[0]);
    _syncOutletsFromAppState();
    if (widget.targetVisitId != null) {
      if (_outletsData.containsKey(widget.targetVisitId)) {
        _selectedOutletId = widget.targetVisitId!;
      }
    }

    if (widget.initialOfflineBanner != null) {
      _showOfflineBanner = widget.initialOfflineBanner!;
    } else {
      _showOfflineBanner = AppState.instance.isOfflineMode;
      _checkInitialConnectivity();
    }

    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      if (!mounted) return;
      if (widget.initialOfflineBanner != null) return;
      final isOnline = await _verifyConnection();
      setState(() {
        _showOfflineBanner = !isOnline;
      });
    });

    // Attempt automatic live location detection after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAndDetectLocation(showMessage: false);
      _updateRouteTrack(autoFrameCamera: true);
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {
      _syncOutletsFromAppState();
    });
  }

  void _syncOutletsFromAppState() {
    final visits = AppState.instance.visits;
    for (int i = 0; i < visits.length; i++) {
      final visit = visits[i];
      final id = i + 1; // 1-based index matching numericId
      final latLng = visit.latLng;

      if (_outletsData.containsKey(id)) {
        _outletsData[id]!['name'] = visit.outletName;
        _outletsData[id]!['shortName'] =
            visit.outletName.split(' ').take(2).join(' ');
        _outletsData[id]!['priority'] = visit.priority;
        _outletsData[id]!['id'] = visit.id;
        _outletsData[id]!['category'] = visit.category;
        _outletsData[id]!['address'] = visit.address;
        _outletsData[id]!['distance'] = visit.distance;
        _outletsData[id]!['eta'] = visit.eta;
        _outletsData[id]!['latLng'] = latLng;
        _outletsData[id]!['task'] = visit.task;
        _outletsData[id]!['phone'] = visit.phone;
      } else if (i >= 8 || widget.targetVisitId == id) {
        _outletsData[id] = {
          'name': visit.outletName,
          'shortName': visit.outletName.split(' ').take(2).join(' '),
          'priority': visit.priority,
          'id': visit.id,
          'category': visit.category,
          'address': visit.address,
          'distance': visit.distance,
          'eta': visit.eta,
          'traffic': 'Lalu lintas terpantau lancar',
          'hours': 'Jadwal Kunjungan Baru',
          'task': visit.task,
          'phone': visit.phone,
          'latLng': latLng,
        };
      }
    }
  }

  Future<bool> _verifyConnection() async {
    if (kIsWeb) {
      try {
        final res = await http
            .get(Uri.parse(Uri.base.origin))
            .timeout(const Duration(seconds: 2));
        return res.statusCode >= 200 && res.statusCode < 500;
      } catch (_) {}
    }
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet) ||
          results.contains(ConnectivityResult.other);
    } catch (_) {
      return true;
    }
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final isOnline = await _verifyConnection();
      if (!mounted) return;
      setState(() {
        _showOfflineBanner = !isOnline;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppStateChanged);
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _selectMarker(int id) {
    setState(() {
      _selectedOutletId = id;
    });
    _updateRouteTrack(autoFrameCamera: true);
    final outlet = _outletsData[id];
    if (outlet != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lokasi rute dipilih: ${outlet['name']}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  LatLng _getOutletLatLng(int id) {
    final outlet = _outletsData[id];
    if (outlet != null && outlet['latLng'] is LatLng) {
      return outlet['latLng'] as LatLng;
    }
    final visits = AppState.instance.visits;
    if (id >= 1 && id <= visits.length) {
      return visits[id - 1].latLng;
    }
    switch (id) {
      case 1:
        return const LatLng(-7.9725, 112.6245);
      case 2:
        return const LatLng(-7.9431, 112.6158);
      case 3:
        return const LatLng(-7.9250, 112.5980);
      case 4:
        return const LatLng(-7.9405, 112.6075);
      default:
        return const LatLng(-7.9725, 112.6245);
    }
  }

  LatLng _getOriginLatLng() {
    if (_selectedOrigin['id'] == 'my_location') {
      if (_currentLocation != null) {
        return LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
      }
      return const LatLng(-7.9786, 112.6318);
    }
    if (_selectedOrigin['latLng'] != null) {
      return _selectedOrigin['latLng'] as LatLng;
    }
    return const LatLng(-7.9786, 112.6318);
  }

  LatLng _getOfficerLatLng() {
    if (_currentLocation != null) {
      return LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
    }
    return const LatLng(-7.9786, 112.6318);
  }

  List<LatLng> _getRouteCoordinates() {
    if (_currentRoutePoints.isNotEmpty) {
      return _currentRoutePoints;
    }
    final start = _getOriginLatLng();
    final end = _getOutletLatLng(_selectedOutletId);
    return [start, end];
  }

  /// Updates navigation track between current origin and target outlet.
  /// Automatically frames the map viewport so both start & end points are visible.
  Future<void> _updateRouteTrack({bool autoFrameCamera = true}) async {
    final start = _getOriginLatLng();
    final end = _getOutletLatLng(_selectedOutletId);

    if (_currentRoutePoints.isEmpty) {
      _currentRoutePoints = [start, end];
    }

    if (autoFrameCamera) {
      _fitRouteBounds(start, end);
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final route = await RoutingService.getRoute(start, end);
      if (mounted) {
        setState(() {
          _currentRoutePoints = route.points;
          _routeDistanceText = route.formattedDistance;
          _routeEtaText = route.formattedDuration;
          _isLoadingRoute = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  /// Calculates proper center and zoom level to frame both start & end locations
  void _fitRouteBounds(LatLng start, LatLng end) {
    final centerLat = (start.latitude + end.latitude) / 2;
    final centerLng = (start.longitude + end.longitude) / 2;

    final latDiff = (start.latitude - end.latitude).abs();
    final lngDiff = (start.longitude - end.longitude).abs();
    final maxDiff = math.max(latDiff, lngDiff);

    double targetZoom;
    if (maxDiff > 0.08) {
      targetZoom = 11.8;
    } else if (maxDiff > 0.04) {
      targetZoom = 12.8;
    } else if (maxDiff > 0.02) {
      targetZoom = 13.8;
    } else if (maxDiff > 0.01) {
      targetZoom = 14.6;
    } else {
      targetZoom = 15.5;
    }

    try {
      _mapController.move(LatLng(centerLat, centerLng), targetZoom);
    } catch (_) {}
  }

  String _getTileUrlTemplate() {
    switch (_layerIndex) {
      case 1:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 2:
        return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
      case 0:
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Offset _getOutletOffset(int id) {
    switch (id) {
      case 1:
        return const Offset(180.0, 155.0);
      case 2:
        return const Offset(300.0, 145.0);
      case 3:
        return const Offset(48.0, 125.0);
      case 4:
        return const Offset(310.0, 60.0);
      default:
        return const Offset(180.0, 155.0);
    }
  }

  String _calculateDynamicDistance() {
    if (_routeDistanceText.isNotEmpty) {
      return _routeDistanceText;
    }
    return _outletsData[_selectedOutletId]?['distance'] ?? '850 m';
  }

  String _calculateDynamicEta() {
    if (_routeEtaText.isNotEmpty) {
      return _routeEtaText;
    }
    return _outletsData[_selectedOutletId]?['eta'] ?? 'Est. 4 mnt';
  }

  List<Marker> _buildOpenStreetMapMarkers() {
    final markers = <Marker>[];

    // Outlets
    _outletsData.forEach((id, outlet) {
      final isSelected = id == _selectedOutletId;
      final latLng = _getOutletLatLng(id);

      markers.add(
        Marker(
          point: latLng,
          width: isSelected ? 160 : 44,
          height: isSelected ? 76 : 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _selectMarker(id),
            child: isSelected
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          (outlet['shortName'] ?? outlet['name']) as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerLowest,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
          ),
        ),
      );
    });

    // Origin Pin
    final originLatLng = _getOriginLatLng();
    markers.add(
      Marker(
        point: originLatLng,
        width: 130,
        height: 76,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2B000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Titik Berangkat',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _selectedOrigin['icon'] as IconData? ??
                    Icons.location_on_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );

    // Live Officer Pin
    final officerLatLng = _getOfficerLatLng();
    markers.add(
      Marker(
        point: officerLatLng,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );

    return markers;
  }

  Future<void> _requestAndDetectLocation({
    bool showMessage = true,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final loc = await LocationService.getCurrentLocation(forceRefresh: forceRefresh);
      if (!mounted) return;

      if (loc != null) {
        setState(() {
          _currentLocation = loc;
          _locationPermissionGranted = true;
          _isDetectingLocation = false;
          _zoomLevel = 1.0;
          if (_selectedOrigin['id'] == 'my_location') {
            _selectedOrigin['subtitle'] = loc.addressName;
            _selectedOrigin['latLng'] = LatLng(loc.latitude, loc.longitude);
            _selectedOrigin['lat'] = loc.latitude;
            _selectedOrigin['lng'] = loc.longitude;
          }
        });

        try {
          _mapController.move(LatLng(loc.latitude, loc.longitude), 16.0);
        } catch (_) {}

        if (_selectedOrigin['id'] == 'my_location') {
          _updateRouteTrack(autoFrameCamera: true);
        }

        if (showMessage) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS Presisi Terkunci: ${loc.addressName} (±${loc.accuracy.toStringAsFixed(0)}m)',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _isDetectingLocation = false;
        });
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pusat peta dialihkan ke posisi Anda (GPS Akurat)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  void _showOriginPickerSheet() {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.toLowerCase();
            final filteredPresets = _originPresets.where((p) {
              final name = (p['name'] as String).toLowerCase();
              final subtitle = (p['subtitle'] as String).toLowerCase();
              return name.contains(query) || subtitle.contains(query);
            }).toList();

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 16,
                left: 16,
                right: 16,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.trip_origin_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pilih Titik Keberangkatan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Tentukan titik awal perjalanan (Dari Mana)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari titik awal atau ketik alamat lain...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Presets List
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredPresets.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filteredPresets[index];
                        final isSelected = item['id'] == _selectedOrigin['id'];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primaryContainer.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                          title: Text(
                            item['name'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            item['subtitle'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedOrigin = Map<String, dynamic>.from(item);
                            });
                            _updateRouteTrack(autoFrameCamera: true);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Titik awal rute: ${item['name']}',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Custom location button if query has custom text
                  if (query.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        final text = searchController.text.trim();
                        LatLng customCoord = const LatLng(-7.9786, 112.6318);
                        final lowerText = text.toLowerCase();
                        if (lowerText.contains('alun') ||
                            lowerText.contains('tugu')) {
                          customCoord = const LatLng(-7.9772, 112.6340);
                        } else if (lowerText.contains('ub') ||
                            lowerText.contains('um') ||
                            lowerText.contains('kampus')) {
                          customCoord = const LatLng(-7.9525, 112.6145);
                        } else if (lowerText.contains('bandara') ||
                            lowerText.contains('abdulrachman')) {
                          customCoord = const LatLng(-7.9380, 112.7140);
                        } else if (lowerText.contains('batu')) {
                          customCoord = const LatLng(-7.8705, 112.5275);
                        } else if (lowerText.contains('singosari') ||
                            lowerText.contains('lawang')) {
                          customCoord = const LatLng(-7.8920, 112.6650);
                        } else if (lowerText.contains('kepanjen')) {
                          customCoord = const LatLng(-8.1300, 112.5700);
                        }

                        setState(() {
                          _selectedOrigin = {
                            'id':
                                'custom_${DateTime.now().millisecondsSinceEpoch}',
                            'name': text,
                            'subtitle': 'Lokasi Kustom Pilihan',
                            'icon': Icons.location_on_rounded,
                            'offset': const Offset(90.0, 320.0),
                            'latLng': customCoord,
                          };
                        });
                        _updateRouteTrack(autoFrameCamera: true);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Titik awal kustom rute: ${_selectedOrigin['name']}',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: Text('Gunakan "${searchController.text.trim()}"'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _centerToMyLocation() {
    setState(() {
      _selectedOrigin = Map<String, dynamic>.from(_originPresets[0]);
    });
    final officer = _getOfficerLatLng();
    try {
      _mapController.move(officer, 16.0);
    } catch (_) {}
    _requestAndDetectLocation(showMessage: true, forceRefresh: true);
    _updateRouteTrack(autoFrameCamera: true);
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _currentLocation = UserLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        accuracy: 3.0,
        addressName:
            'Titik Pilihan (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
        isMock: false,
      );
      if (_selectedOrigin['id'] == 'my_location') {
        _selectedOrigin['latLng'] = point;
        _selectedOrigin['lat'] = point.latitude;
        _selectedOrigin['lng'] = point.longitude;
        _selectedOrigin['subtitle'] = 'Titik Disesuaikan di Peta';
      }
    });

    _updateRouteTrack(autoFrameCamera: false);

    LocationService.reverseGeocode(point.latitude, point.longitude).then((name) {
      if (name != null && mounted) {
        setState(() {
          _currentLocation = _currentLocation?.copyWith(addressName: name);
          if (_selectedOrigin['id'] == 'my_location') {
            _selectedOrigin['subtitle'] = name;
          }
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Titik GPS disesuaikan ke: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _cycleMapLayer() {
    setState(() {
      _layerIndex = (_layerIndex + 1) % _layerNames.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.layers_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Lapisan Peta: ${_layerNames[_layerIndex]}'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleNavigation(String outletName) {
    setState(() {
      _isNavigating = !_isNavigating;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isNavigating ? Icons.turn_right_rounded : Icons.cancel_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isNavigating
                    ? 'Memulai panduan navigasi ke $outletName...'
                    : 'Panduan navigasi dihentikan.',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: _isNavigating
            ? AppColors.primary
            : AppColors.onSurfaceVariant,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openDetails(Map<String, dynamic> outlet) {
    // Find or create matching VisitItem
    final appState = AppState.instance;
    VisitItem? found;
    try {
      found = appState.visits.firstWhere(
        (v) => v.numericId == _selectedOutletId,
      );
    } catch (_) {
      found = VisitItem(
        id: '#KUN-882$_selectedOutletId',
        outletName: outlet['name'] as String,
        category: outlet['category'] as String,
        address: outlet['address'] as String,
        time: 'Hari ini, 10:15 WIB',
        priority: outlet['priority'] as String,
        status: 'Belum Dikunjungi',
        distance: outlet['distance'] as String,
        eta: outlet['eta'] as String,
        task: outlet['task'] as String,
        phone: outlet['phone'] as String,
      );
    }
    showVisitDetailSheet(context, found);
  }

  void _showCallDialog(Map<String, dynamic> outlet) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'Panggil Kontak?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apakah Anda ingin menghubungi nomor operasional outlet ini?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outlet['name'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          outlet['phone'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final phone = outlet['phone'] as String;
                final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
                final uri = Uri.parse('tel:$cleanPhone');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Menghubungi $phone...'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Menghubungi $phone...'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Panggil'),
            ),
          ],
        );
      },
    );
  }

  void _handleReconnect() async {
    setState(() {
      _isConnecting = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _isConnecting = false;
      _showOfflineBanner = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Peta online terhubung kembali. Rute real-time aktif.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOutlet = _outletsData[_selectedOutletId] ?? _outletsData[1]!;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Map Canvas Viewport Container
            SizedBox(
              height: 520,
              width: double.infinity,
              child: Stack(
                children: [
                  // 1. Real Interactive OpenStreetMap Container powered by flutter_map
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _getOutletLatLng(_selectedOutletId),
                        initialZoom: 14.5,
                        minZoom: 10.0,
                        maxZoom: 19.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                        onTap: (tapPosition, point) {
                          _handleMapTap(point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _getTileUrlTemplate(),
                          userAgentPackageName: 'com.example.sikunjung',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _getRouteCoordinates(),
                              strokeWidth: _isNavigating ? 5.5 : 3.8,
                              color: _isNavigating
                                  ? AppColors.primary
                                  : const Color(0xFF00685D)
                                        .withValues(alpha: 0.85),
                              borderColor: Colors.white,
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                        MarkerLayer(markers: _buildOpenStreetMapMarkers()),
                      ],
                    ),
                  ),

                  // Active Navigation Turn-by-Turn HUD Banner
                  if (_isNavigating)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.base),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              child: const Icon(
                                Icons.turn_right_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '150 m • Belok Kanan ke Jl. Besar Ijen',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Kecepatan 34 km/j • Sisa ${currentOutlet['distance']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _toggleNavigation(
                                currentOutlet['name'] as String,
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top Overlays: Scope Pill & Offline Banner (when not actively navigating)
                  if (!_isNavigating)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildScopePill(),
                          if (_showOfflineBanner) ...[
                            const SizedBox(height: 8),
                            _buildOfflineNoticeBanner(),
                          ],
                        ],
                      ),
                    ),

                  // Right Side Floating HUD Controls
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _buildFloatingControls(),
                  ),
                ],
              ),
            ),

            // Bottom Customer Information Sheet
            _buildBottomCustomerSheet(currentOutlet),
            const SizedBox(height: 70),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const VisitsScreen()),
            );
          } else {
            setState(() {
              _selectedTabIndex = index;
            });
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(66),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.lg),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D003830),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 66,
                child: Row(
                  children: [
                    // App Logo Pin with glass glow
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryContainer,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12003830),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.pin_drop_rounded,
                        size: 20,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Title and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIKUNJUNG MOBILE',
                            maxLines: 1,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Sikunjung',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Liquid Glass GPS Accuracy Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _locationPermissionGranted
                                ? Icons.my_location_rounded
                                : Icons.sensors_rounded,
                            size: 13,
                            color: _locationPermissionGranted
                                ? AppColors.primary
                                : AppColors.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentLocation != null
                                ? 'GPS: ${_currentLocation!.accuracy.toStringAsFixed(0)}m'
                                : 'GPS Akurat - 3m',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Glass Search Icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pencarian titik lokasi peta dibuka...',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Glass Notification Icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => showNotificationsSheet(context),
                        icon: const Icon(
                          Icons.notifications_outlined,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreetLabels() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 90,
              left: 30,
              child: Text(
                'JL. SOEKARNO HATTA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.outline,
                ),
              ),
            ),
            Positioned(
              top: 170,
              left: 170,
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  'JL. BESAR IJEN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 165,
              left: 215,
              child: Text(
                'JL. KAUMAN',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              left: 12,
              child: Text(
                'JL. KAWI',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                ),
              ),
            ),
            Positioned(
              top: 118,
              left: 45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4EDDA),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'SIMPANG BALAPAN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF006947),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapMarkers() {
    return Stack(
      children: [
        // Pin 4: Apotek Sehat Farma
        Positioned(
          top: 60,
          right: 32,
          child: _buildPinMarker(
            id: 4,
            distance: '4.5 km',
            label: 'Apotek Farma',
            icon: Icons.local_pharmacy_rounded,
          ),
        ),

        // Pin 3: UD. Sumber Rejeki
        Positioned(
          top: 125,
          left: 48,
          child: _buildPinMarker(
            id: 3,
            distance: '3.2 km',
            label: 'UD. Sumber Rejeki',
            icon: Icons.warehouse_rounded,
          ),
        ),

        // Pin 2: Surya Mart Mandiri
        Positioned(
          top: 145,
          right: 42,
          child: _buildPinMarker(
            id: 2,
            distance: '1.8 km',
            label: 'Surya Mart',
            icon: Icons.storefront_rounded,
          ),
        ),

        // Pin 1: Toko Berkah Abadi
        Positioned(
          top: 155,
          left: 180,
          child: _buildPinMarker(
            id: 1,
            distance: '850 m',
            label: 'Toko Berkah',
            icon: Icons.shopping_bag_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildPinMarker({
    required int id,
    required String distance,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedOutletId == id;

    if (isSelected) {
      return GestureDetector(
        onTap: () => _selectMarker(id),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33A7391E),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryFixed,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distance,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '• $label',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59A7391E),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _selectMarker(id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              distance,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHighest,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginPin() {
    if (_selectedOrigin['id'] == 'my_location') return const SizedBox.shrink();

    final offset = _selectedOrigin['offset'] as Offset;
    return Positioned(
      top: offset.dy - 12,
      left: offset.dx - 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'DARI: ${_selectedOrigin['name']}',
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3300685D),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.trip_origin_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerPin() {
    return Positioned(
      top: _officerOffset.dy,
      left: _officerOffset.dx,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (_isDetectingLocation)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixedDim.withValues(alpha: 0.35),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.3),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4000685D),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.inverseSurface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              _currentLocation != null
                  ? 'POSISI ANDA (GPS TERDETEKSI)'
                  : 'POSISI ANDA',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopePill() {
    final currentOutlet = _outletsData[_selectedOutletId] ?? _outletsData[1]!;
    final dynamicDistance = _calculateDynamicDistance();
    final dynamicEta = _calculateDynamicEta();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.base),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141E293B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Malang Raya (Kota & Batu)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_outletsData.length} Titik Kunjungan Aktif',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Jangkauan peta: Wilayah Malang Raya & Sekitarnya',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Routing Origin (Dari Mana) & Destination Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.base),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Origin Row (Dari Mana) - Interactive Picker
                InkWell(
                  onTap: _showOriginPickerSheet,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Dari:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedOrigin['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Pilih',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Destination Row (Ke Mana)
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ke  :',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Outlet: ${currentOutlet['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$dynamicDistance • $dynamicEta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.base),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26FD7958),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mode Offline Aktif',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Koneksi terputus. Peta menggunakan memori lokal Malang Raya. Rute realtime terbatas.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton(
                      onPressed: _isConnecting ? null : _handleReconnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.onSecondaryContainer,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: const Size(60, 28),
                        elevation: 0,
                      ),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Coba Hubungkan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    Text(
                      'Sinkron: 10 mnt lalu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showOfflineBanner = false;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Traffic status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1E293B),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Lalu Lintas Lancar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Layer Toggle
        _buildHudCircleButton(
          icon: Icons.layers_rounded,
          onTap: _cycleMapLayer,
        ),
        const SizedBox(height: 8),

        // Zoom Controls
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.base),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1E293B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  try {
                    final curZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (curZoom + 1.0).clamp(10.0, 19.0),
                    );
                  } catch (_) {
                    setState(() {
                      _zoomLevel = (_zoomLevel + 0.25).clamp(0.7, 2.5);
                    });
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
              ),
              Container(
                width: 32,
                height: 1,
                color: AppColors.surfaceContainer,
              ),
              IconButton(
                onPressed: () {
                  try {
                    final curZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      (curZoom - 1.0).clamp(10.0, 19.0),
                    );
                  } catch (_) {
                    setState(() {
                      _zoomLevel = (_zoomLevel - 0.25).clamp(0.7, 2.5);
                    });
                  }
                },
                icon: const Icon(Icons.remove_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Relocate to GPS button
        _buildHudCircleButton(
          icon: Icons.my_location_rounded,
          iconColor: AppColors.primary,
          onTap: _centerToMyLocation,
        ),
      ],
    );
  }

  Widget _buildHudCircleButton({
    required IconData icon,
    Color iconColor = AppColors.onSurfaceVariant,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceContainerLowest,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A1E293B),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildBottomCustomerSheet(Map<String, dynamic> outlet) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F0B1C30),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Outlet Switcher Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _outletsData.entries.map((entry) {
                final id = entry.key;
                final out = entry.value;
                final isSel = id == _selectedOutletId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                  child: InkWell(
                    onTap: () => _selectMarker(id),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: isSel
                              ? AppColors.primary
                              : AppColors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: isSel
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            (out['shortName'] ?? out['name']) as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Sheet Header: Name + Priority + Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            outlet['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            outlet['priority'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSecondaryFixedVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          'ID Kunjungan: ${outlet['id']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Text(
                          '•',
                          style: TextStyle(color: AppColors.outline),
                        ),
                        Text(
                          outlet['category'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openDetails(outlet),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outlet['address'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metric Card: Distance & ETA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.base),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.two_wheeler_rounded,
                    size: 20,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            'Jarak: ${_calculateDynamicDistance()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Text(
                            '•',
                            style: TextStyle(color: AppColors.outline),
                          ),
                          Text(
                            _calculateDynamicEta(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        outlet['traffic'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        outlet['hours'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Operational Agenda Memo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tugas: ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(
                          text: outlet['task'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Navigasi, Rincian, Call
          Row(
            children: [
              // Primary CTA: Navigasi
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _toggleNavigation(outlet['name'] as String),
                    icon: Icon(
                      _isNavigating
                          ? Icons.stop_circle_rounded
                          : Icons.turn_right_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _isNavigating ? 'Hentikan' : 'Navigasi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isNavigating
                          ? AppColors.error
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Secondary CTA: Rincian
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _openDetails(outlet),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerLow,
                      foregroundColor: AppColors.onSurface,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Rincian',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Direct Phone CTA
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showCallDialog(outlet),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryContainer,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      size: 20,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

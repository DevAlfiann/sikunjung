import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../screens/map_screen.dart';
import '../services/app_state.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';

Future<bool?> showAddVisitModal(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddVisitSheet(),
  );
}

class _AddVisitSheet extends StatefulWidget {
  const _AddVisitSheet();

  @override
  State<_AddVisitSheet> createState() => _AddVisitSheetState();
}

class _AddVisitSheetState extends State<_AddVisitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController(text: '0812');
  final _taskController = TextEditingController(
      text: 'Audit stok display & pengantaran faktur');

  String _selectedCategory = 'FMCG Retail';
  String _selectedPriority = 'Prioritas Tinggi';
  String _selectedStatus = 'Pending';
  final List<String> _statusOptions = ['Pending', 'Selesai', 'Batal'];
  bool _isAutoGps = true;
  bool _isSubmitting = false;

  // Selected map location (defaults to central Malang Raya)
  LatLng _selectedLocation = const LatLng(-7.9725, 112.6245);
  bool _hasSelectedLocation = true;
  final MapController _mapController = MapController();

  final List<String> _categories = [
    'FMCG Retail',
    'Minimarket',
    'Grosir Sembako',
    'Kesehatan / Farma',
    'Kelontong',
  ];

  final List<String> _priorities = [
    'Prioritas Tinggi',
    'Reguler',
    'Perhatian',
    'Jadwal Siang',
  ];

  @override
  void initState() {
    super.initState();
    _detectInitialLocation();
  }

  void _detectInitialLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() {
        _selectedLocation = LatLng(loc.latitude, loc.longitude);
      });
      try {
        _mapController.move(_selectedLocation, 14.5);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _selectedLocation = point;
      _hasSelectedLocation = true;
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = _suggestMalangAddress(point);
      }
    });
    try {
      _mapController.move(point, _mapController.camera.zoom);
    } catch (_) {}
  }

  String _suggestMalangAddress(LatLng point) {
    final lat = point.latitude;
    final lng = point.longitude;

    if (lat > -7.935) {
      return 'Jl. Raya Tlogomas, Lowokwaru, Kota Malang';
    } else if (lat > -7.955 && lng < 112.618) {
      return 'Jl. Soekarno Hatta, Lowokwaru, Kota Malang';
    } else if (lat > -7.955 && lng >= 112.618) {
      return 'Jl. Borobudur, Blimbing, Kota Malang';
    } else if (lat <= -7.975 && lng <= 112.625) {
      return 'Jl. Besar Ijen / Kawi, Klojen, Kota Malang';
    } else if (lat <= -7.975 && lng > 112.625) {
      return 'Jl. Basuki Rahmat / Alun-alun, Klojen, Kota Malang';
    } else {
      return 'Wilayah Malang Raya (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
    }
  }

  Future<void> _openFullscreenMapPicker() async {
    final picked = await showDialog<LatLng>(
      context: context,
      builder: (ctx) {
        LatLng tempLoc = _selectedLocation;
        final dialogMapCtrl = MapController();
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  width: double.infinity,
                  height: 460,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: dialogMapCtrl,
                        options: MapOptions(
                          initialCenter: tempLoc,
                          initialZoom: 15.0,
                          minZoom: 10.0,
                          maxZoom: 18.5,
                          onTap: (_, latLng) {
                            setDialogState(() {
                              tempLoc = latLng;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.sikunjung',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: tempLoc,
                                width: 140,
                                height: 75,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBA1A1A),
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.full),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _nameController.text.trim().isNotEmpty
                                            ? _nameController.text.trim()
                                            : 'Titik Tujuan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFFBA1A1A),
                                      size: 34,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(AppRadius.base),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ketuk peta untuk menandai titik tujuan',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 28, minHeight: 28),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.base),
                                ),
                                child: Text(
                                  '${tempLoc.latitude.toStringAsFixed(4)}, ${tempLoc.longitude.toStringAsFixed(4)}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(ctx, tempLoc),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Pilih Titik'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      _onMapTapped(picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasSelectedLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Harap tentukan titik tujuan pada peta terlebih dahulu!'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final newId = '#KUN-${8820 + AppState.instance.totalCount + 1}';
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    // Calculate real road distance & ETA from officer location in Malang
    const officerLatLng = LatLng(-7.9786, 112.6318);
    const distCalc = Distance();
    final directDistMeters =
        distCalc.as(LengthUnit.Meter, officerLatLng, _selectedLocation);
    final roadDistMeters = directDistMeters * 1.25;
    final distStr = RoutingService.formatDistance(roadDistMeters);
    final etaStr = RoutingService.formatDuration(roadDistMeters / 6.94);

    final newVisit = VisitItem(
      id: newId,
      outletName: _nameController.text.trim(),
      category: _selectedCategory,
      address: _addressController.text.trim(),
      time: 'Hari ini, $hour:$minute WIB',
      priority: _selectedPriority,
      status: _selectedStatus,
      hasGps: _isAutoGps,
      coordinates:
          '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
      phone: _phoneController.text.trim(),
      task: _taskController.text.trim(),
      distance: distStr,
      eta: etaStr,
    );

    AppState.instance.addVisit(newVisit);

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kunjungan ke "${newVisit.outletName}" berhasil ditambahkan!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Lihat di Peta',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MapScreen(targetVisitId: newVisit.numericId),
              ),
            );
          },
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildQuickPresetChip(String label, LatLng latLng, String address) {
    final isSelected = _hasSelectedLocation &&
        (_selectedLocation.latitude - latLng.latitude).abs() < 0.001 &&
        (_selectedLocation.longitude - latLng.longitude).abs() < 0.001;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLocation = latLng;
          _hasSelectedLocation = true;
          if (_addressController.text.trim().isEmpty) {
            _addressController.text = address;
          }
        });
        try {
          _mapController.move(latLng, 14.5);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title & Close Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tambah Kunjungan Baru',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih titik di peta & lengkapi data kunjungan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field 1: Nama Outlet
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Nama Outlet / Toko *',
                  hintText: 'Contoh: Toko Barokah Abadi',
                  prefixIcon: const Icon(Icons.storefront_outlined, size: 20),
                  filled: true,
                  isDense: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama outlet wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Interactive Map Selection Card (WAJIB PILIH TITIK DI PETA)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  border: Border.all(
                    color: _hasSelectedLocation
                        ? AppColors.primary
                        : AppColors.error,
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pin_drop_rounded,
                                color: _hasSelectedLocation
                                    ? AppColors.primary
                                    : AppColors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Titik Lokasi di Peta *',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _hasSelectedLocation
                                ? const Color(0xFFCBECE8)
                                : const Color(0xFFFFDAD6),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            _hasSelectedLocation
                                ? '✓ Terpilih'
                                : 'Wajib Ketuk Peta',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _hasSelectedLocation
                                  ? const Color(0xFF005047)
                                  : const Color(0xFF93000A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ketuk peta Malang Raya untuk menandai lokasi tujuan:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Interactive FlutterMap Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.base),
                      child: SizedBox(
                        height: 110,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _selectedLocation,
                                initialZoom: 14.0,
                                minZoom: 10.0,
                                maxZoom: 18.0,
                                onTap: (_, latLng) {
                                  _onMapTapped(latLng);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.sikunjung',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation,
                                      width: 120,
                                      height: 60,
                                      alignment: Alignment.topCenter,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFBA1A1A),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.full),
                                            ),
                                            child: Text(
                                              _nameController.text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? _nameController.text.trim()
                                                  : 'Titik Tujuan',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFFBA1A1A),
                                            size: 26,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Top overlay HUD
                            Positioned(
                              top: 6,
                              left: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.touch_app_rounded,
                                        size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _openFullscreenMapPicker,
                                      child: Text(
                                        'Peta Besar',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Quick Location Preset Chips
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildQuickPresetChip(
                          '📍 Ijen',
                          const LatLng(-7.9725, 112.6245),
                          'Jl. Besar Ijen No. 42, Klojen, Kota Malang',
                        ),
                        _buildQuickPresetChip(
                          '📍 Suhat',
                          const LatLng(-7.9431, 112.6158),
                          'Jl. Soekarno Hatta No. 18, Lowokwaru, Kota Malang',
                        ),
                        _buildQuickPresetChip(
                          '📍 Dinoyo',
                          const LatLng(-7.9405, 112.6075),
                          'Jl. MT Haryono No. 108, Dinoyo, Kota Malang',
                        ),
                        _buildQuickPresetChip(
                          '📍 Tlogomas',
                          const LatLng(-7.9250, 112.5980),
                          'Jl. Raya Tlogomas No. 55, Lowokwaru, Kota Malang',
                        ),
                        _buildQuickPresetChip(
                          '📍 Blimbing',
                          const LatLng(-7.9400, 112.6450),
                          'Jl. Borobudur No. 20, Blimbing, Kota Malang',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Field 2: Alamat Lengkap
              TextFormField(
                controller: _addressController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Alamat Lokasi Kunjungan *',
                  hintText: 'Contoh: Jl. Soekarno Hatta No. 45, Malang',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  filled: true,
                  isDense: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alamat lokasi wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Field 3: Kategori Dropdown / Chips
              Text(
                'Kategori Outlet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        selectedColor: AppColors.primaryContainer,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.onPrimaryContainer
                              : AppColors.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Field 4: Prioritas Kunjungan
              Text(
                'Tingkat Prioritas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _priorities.map((p) {
                    final isSelected = _selectedPriority == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedPriority = p;
                          });
                        },
                        selectedColor: p == 'Prioritas Tinggi'
                            ? const Color(0xFFFFDAD6)
                            : AppColors.surfaceContainerHigh,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (p == 'Prioritas Tinggi'
                                  ? const Color(0xFF93000A)
                                  : AppColors.primary)
                              : AppColors.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Field 5: Auto-captured GPS toggle & badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Geotagging GPS Lapangan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)} (Akurasi ±3m)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isAutoGps,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _isAutoGps = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Field: Status Kunjungan (Pending, Selesai, Batal)
              Text(
                'Status Kunjungan *',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: _statusOptions.map((st) {
                  final isSelected = _selectedStatus == st;
                  Color activeColor;
                  Color activeBg;
                  IconData icon;
                  if (st == 'Selesai') {
                    activeColor = const Color(0xFF006C4C);
                    activeBg = const Color(0xFFC4EED0);
                    icon = Icons.check_circle_rounded;
                  } else if (st == 'Batal') {
                    activeColor = const Color(0xFFBA1A1A);
                    activeBg = const Color(0xFFFFDAD6);
                    icon = Icons.cancel_rounded;
                  } else {
                    activeColor = const Color(0xFF8A5100);
                    activeBg = const Color(0xFFFFEECC);
                    icon = Icons.schedule_rounded;
                  }
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedStatus = st;
                          });
                        },
                        borderRadius: BorderRadius.circular(AppRadius.base),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? activeBg : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                            border: Border.all(
                              color: isSelected ? activeColor : AppColors.outlineVariant,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 14,
                                color: isSelected ? activeColor : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                st,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? activeColor : AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Field 6: Tugas / Catatan
              TextFormField(
                controller: _taskController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Instruksi / Catatan Tugas',
                  prefixIcon: const Icon(Icons.task_alt_outlined, size: 20),
                  filled: true,
                  isDense: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    borderSide: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Submit Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 1,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_task_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Simpan Kunjungan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

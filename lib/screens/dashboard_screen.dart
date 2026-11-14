import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/add_visit_modal.dart';
import '../widgets/app_bar_actions.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/menu_tile.dart';
import '../widgets/stat_card.dart';
import '../widgets/visit_card.dart';
import '../widgets/visit_detail_modal.dart';
import 'device_info_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'network_screen.dart';
import 'sensors_screen.dart';
import 'visits_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String agentName;

  const DashboardScreen({
    super.key,
    this.agentName = 'admin',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;
  bool _isDarkMode = false;
  bool _isOnline = true;
  bool _isCheckingSignal = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppStateChanged);
    _checkInitialConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      if (!mounted) return;
      final isOnline = await _verifyConnection();
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          AppState.instance.isOfflineMode = !isOnline;
        });
      }
    });
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
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          AppState.instance.isOfflineMode = !isOnline;
        });
      }
    } catch (_) {}
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.ethernet) &&
        !results.contains(ConnectivityResult.other);
    final isOnline = !isOffline;
    setState(() {
      _isOnline = isOnline;
      AppState.instance.isOfflineMode = !isOnline;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    AppState.instance.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkSignal() async {
    if (_isCheckingSignal) return;
    setState(() => _isCheckingSignal = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final isOnline = await _verifyConnection();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        AppState.instance.isOfflineMode = !isOnline;
        _isCheckingSignal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Sinyal terhubung! Koneksi internet aktif.'
                      : 'Koneksi terputus. Mode offline tetap aktif.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isOnline ? AppColors.primary : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    AppState.instance.syncAllPending();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Data beranda & antrean kunjungan berhasil diperbarui!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Text(
            'Keluar Akun?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari sesi petugas lapangan saat ini?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
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
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                minimumSize: const Size(100, 42),
              ),
              child: Text(
                'Keluar',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Agent Greeting & GPS Status Banner
              _buildGreetingBanner(),
              const SizedBox(height: 16),

              // 2. Row of 3 Stat Cards
              _buildStatsRow(),
              const SizedBox(height: 20),

              // 3. Offline Warning Banner (Otomatis Sembunyi jika online & antrean 0)
              _buildOfflineWarningBanner(),

              // 4. Menu Utama Section
              _buildMenuSection(),
              const SizedBox(height: 24),

              // 5. Kunjungan Terbaru Section
              _buildRecentVisitsSection(),
              const SizedBox(height: 16),

              // 6. Target Harian Motivator Banner
              _buildTargetHarianBanner(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VisitsScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MapScreen()),
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
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg),
        ),
      ),
      flexibleSpace: ClipRRect(
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
          ),
        ),
      ),
      title: Row(
        children: [
          // Logo verified badge
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
              Icons.verified_rounded,
              size: 20,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SIKUNJUNG MOBILE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Beranda',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Glassmorphic Notification Button
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
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
          child: IconButton(
            onPressed: () => showNotificationsSheet(context),
            icon: const Icon(
              Icons.notifications_outlined,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Glassmorphic User Profile Avatar
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: InkWell(
            onTap: () => showOfficerProfileDialog(context),
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryContainer,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A003830),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreetingBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryContainer,
            AppColors.tertiary,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3800685D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            // Ambient Orbs
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixed.withValues(alpha: 0.20),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 60,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryFixed.withValues(alpha: 0.20),
                ),
              ),
            ),

            // Content Column
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Sub-bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Halo, ${widget.agentName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('👋', style: TextStyle(fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('EEEE, d MMM yyyy').format(DateTime.now())} • ID: PK-0482',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryFixed,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBannerCircleButton(
                            icon: _isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            onTap: () {
                              setState(() {
                                _isDarkMode = !_isDarkMode;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildBannerCircleButton(
                            icon: Icons.logout_rounded,
                            onTap: _confirmLogout,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real-time GPS Accuracy Strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.tertiaryFixed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.tertiaryFixed,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'GPS Aktif • Akurasi 3m',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.satellite_alt_rounded,
                              size: 14,
                              color: AppColors.primaryFixed,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '11 Satelit',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryFixed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          child: Icon(
            icon,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final appState = AppState.instance;

    return Row(
      children: [
        // Stat 1: Total
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisitsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: StatCard(
              title: 'Total',
              value: '128',
              subtitleText: 'Bulan ini',
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.primary,
              iconBackgroundColor: AppColors.surfaceContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Stat 2: Hari ini
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisitsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: StatCard(
              title: 'Hari ini',
              value: '${appState.totalCount}',
              subtitleWidget: const _TodayStatPill(),
              icon: Icons.calendar_today_outlined,
              iconColor: AppColors.onSecondaryFixed,
              iconBackgroundColor: AppColors.secondaryFixed,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Stat 3: Ada GPS
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisitsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: StatCard(
              title: 'Ada GPS',
              value: '124',
              subtitleWidget: const _GpsValidText(),
              icon: Icons.location_on_outlined,
              iconColor: AppColors.tertiary,
              iconBackgroundColor: AppColors.surfaceContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineWarningBanner() {
    // Otomatis Sembunyi: Jika perangkat terhubung ke internet (online), banner HILANG sepenuhnya.
    // Banner HANYA muncul jika internet terputus (offline).
    if (_isOnline) {
      return const SizedBox.shrink();
    }

    final queue = AppState.instance.offlineQueueCount;
    const String bannerTitle = 'Mode Offline Aktif';
    final String bannerBody = queue > 0
        ? 'Koneksi internet terputus. Terdapat $queue data kunjungan baru disimpan lokal & disinkronkan otomatis saat online.'
        : 'Koneksi internet terputus. Data kunjungan baru disimpan lokal & disinkronkan otomatis saat online.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: const Color(0xFFFFB4AB).withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0CBA1A1A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5449),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                bannerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF410002),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              queue > 0 ? '$queue Antrean' : 'Offline',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8C1D18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bannerBody,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color:
                                const Color(0xFF410002).withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isCheckingSignal ? null : _checkSignal,
                    icon: _isCheckingSignal
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(
                      'Cek Sinyal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8C1D18),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(100, 36),
                      maximumSize: const Size(140, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Disimpan di SQLite',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF410002).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Utama',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Akses cepat tugas operasional & utilitas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // 3x2 Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 20) / 3;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // 1. Tambah Kunjungan
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Tambah Kunjungan',
                    subtitle: 'Form Cepat',
                    icon: Icons.add_location_alt_outlined,
                    iconColor: AppColors.primary,
                    iconBackgroundColor: const Color(0x1A00685D),
                    subtitleColor: AppColors.primary,
                    badgeText: 'Baru',
                    onTap: () => showAddVisitModal(context),
                  ),
                ),

                // 2. Daftar Kunjungan
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Daftar Kunjungan',
                    subtitle: '8 Tugas Aktif',
                    icon: Icons.checklist_rounded,
                    iconColor: AppColors.primary,
                    iconBackgroundColor: AppColors.surfaceContainerHigh,
                    subtitleColor: AppColors.onSurfaceVariant,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VisitsScreen()),
                      );
                    },
                  ),
                ),

                // 3. Peta Lokasi
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Peta Lokasi',
                    subtitle: 'Rute Terdekat',
                    icon: Icons.explore_outlined,
                    iconColor: AppColors.tertiary,
                    iconBackgroundColor: const Color(0x1A006947),
                    subtitleColor: AppColors.tertiary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    },
                  ),
                ),

                // 4. Kompas & Sensor
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Kompas & Sensor',
                    subtitle: 'Arah & Gyro',
                    icon: Icons.explore_rounded,
                    iconColor: AppColors.primary,
                    iconBackgroundColor: const Color(0x1A00685D),
                    subtitleColor: AppColors.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SensorsScreen()),
                      );
                    },
                  ),
                ),

                // 5. Status Jaringan
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Status Jaringan',
                    subtitle: 'Mode Lokal',
                    icon: Icons.signal_cellular_alt_rounded,
                    iconColor: AppColors.onSecondaryFixed,
                    iconBackgroundColor: AppColors.secondaryFixed,
                    subtitleColor: AppColors.secondary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NetworkScreen()),
                      );
                    },
                  ),
                ),

                // 6. Info Perangkat
                SizedBox(
                  width: cardWidth,
                  child: MenuTile(
                    title: 'Info Perangkat',
                    subtitle: 'Android 14',
                    icon: Icons.devices_rounded,
                    iconColor: AppColors.onSurface,
                    iconBackgroundColor: AppColors.surfaceContainerHighest,
                    subtitleColor: AppColors.onSurfaceVariant,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const DeviceInfoScreen()),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentVisitsSection() {
    final recentVisits = AppState.instance.visits.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunjungan Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Histori laporan hari ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VisitsScreen()),
                );
              },
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ...recentVisits.map((v) {
          final isCompleted = v.status == 'Selesai';
          final isPending = v.status == 'Pending Sync';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: VisitCard(
              initials: v.initials,
              avatarBgColor: isCompleted
                  ? AppColors.secondaryFixed
                  : (isPending
                      ? AppColors.secondaryContainer
                      : AppColors.primaryFixed),
              avatarTextColor: isCompleted
                  ? AppColors.onSecondaryFixedVariant
                  : (isPending
                      ? Colors.white
                      : AppColors.onPrimaryFixedVariant),
              title: v.outletName,
              address: v.address,
              statusText: v.status,
              statusBgColor: isCompleted
                  ? AppColors.tertiaryContainer
                  : (isPending
                      ? AppColors.secondaryFixed
                      : const Color(0xFFD8E7FF)),
              statusTextColor: isCompleted
                  ? Colors.white
                  : (isPending
                      ? AppColors.onSecondaryFixedVariant
                      : AppColors.primary),
              timeText: v.time,
              detailText: isCompleted
                  ? 'Tervalidasi GPS'
                  : (isPending ? 'Pending Sync' : v.coordinates),
              detailIcon: isCompleted
                  ? Icons.verified_rounded
                  : (isPending
                      ? Icons.history_rounded
                      : Icons.my_location_rounded),
              detailColor: isCompleted
                  ? AppColors.tertiary
                  : (isPending ? AppColors.secondary : AppColors.primary),
              onTap: () => showVisitDetailSheet(context, v),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTargetHarianBanner() {
    final remaining =
        AppState.instance.totalCount - AppState.instance.completedCount;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Harian',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        remaining > 0
                            ? 'Tersisa $remaining kunjungan lagi hari ini'
                            : 'Semua target hari ini selesai! Hebat!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Memulai rute target harian ke kunjungan terdekat!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(64, 38),
            ),
            child: Text(
              'Mulai',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayStatPill extends StatelessWidget {
  const _TodayStatPill();

  @override
  Widget build(BuildContext context) {
    final completed = AppState.instance.completedCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '+$completed selesai',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _GpsValidText extends StatelessWidget {
  const _GpsValidText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '96.8% valid',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.tertiary,
      ),
    );
  }
}

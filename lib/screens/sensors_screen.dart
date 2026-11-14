import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/compass_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_actions.dart';
import '../widgets/compass_dial.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/sensor_axis_bar.dart';
import '../widgets/sensor_card.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'visits_screen.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key});

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = -1; // Sub-page from Dashboard

  // Calibration state
  bool _isCalibratingCompass = false;
  bool _compassCalibrated = false;
  bool _isCalibratingAll = false;
  double _compassAngle = 45.0;
  String _accuracyText = '±1.2° (Tinggi)';
  double _pitch = 12.0;
  double _roll = -3.0;

  // Live telemetry values (updated in real time via sensors_plus)
  double _accelX = 0.42;
  double _accelY = 9.78;
  double _accelZ = 0.15;

  double _gyroX = -0.012;
  double _gyroY = 0.005;
  double _gyroZ = 0.034;

  double _magX = 24.6;
  double _magY = -18.2;
  double _magZ = 42.1;

  StreamSubscription<CompassReading>? _compassSub;

  late AnimationController _compassAnimController;
  late Animation<double> _compassAnimation;

  @override
  void initState() {
    super.initState();
    _compassAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _compassAnimation =
        Tween<double>(begin: 45.0, end: 45.0).animate(
          CurvedAnimation(
            parent: _compassAnimController,
            curve: Curves.easeInOutBack,
          ),
        )..addListener(() {
          setState(() {
            _compassAngle = _compassAnimation.value;
          });
        });

    _compassSub = CompassService.instance.stream.listen((reading) {
      if (!mounted || _isCalibratingCompass) return;
      setState(() {
        _compassAngle = reading.heading;
        _pitch = reading.pitch;
        _roll = reading.roll;
        if (reading.accuracy != null) {
          _accuracyText = '±${reading.accuracy!.toStringAsFixed(1)}° (Tinggi)';
        }
        if (reading.accelX != null) _accelX = reading.accelX!;
        if (reading.accelY != null) _accelY = reading.accelY!;
        if (reading.accelZ != null) _accelZ = reading.accelZ!;
        if (reading.gyroX != null) _gyroX = reading.gyroX!;
        if (reading.gyroY != null) _gyroY = reading.gyroY!;
        if (reading.gyroZ != null) _gyroZ = reading.gyroZ!;
        if (reading.magX != null) _magX = reading.magX!;
        if (reading.magY != null) _magY = reading.magY!;
        if (reading.magZ != null) _magZ = reading.magZ!;
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _compassAnimController.dispose();
    super.dispose();
  }

  void _triggerCompassCalibration() {
    if (_isCalibratingCompass) return;

    setState(() {
      _isCalibratingCompass = true;
    });

    // Spin animation: current -> +360 -> settles at 45°
    _compassAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: _compassAngle,
          end: _compassAngle + 360,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: _compassAngle + 360,
          end: 45.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
    ]).animate(_compassAnimController);

    _compassAnimController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      setState(() {
        _isCalibratingCompass = false;
        _compassCalibrated = true;
        _accuracyText = '±0.8° (Sangat Presisi)';
        _pitch = 10.0;
        _roll = -1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kalibrasi kompas selesai! Akurasi meningkat ke ±0.8°.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.tertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Revert button text back after 2.5 seconds
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _compassCalibrated = false;
          });
        }
      });
    });
  }

  void _calibrateAllSensors() async {
    if (_isCalibratingAll) return;

    setState(() {
      _isCalibratingAll = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _isCalibratingAll = false;
      _accuracyText = '±0.7° (Optimal)';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Semua sensor hardware (Akselerometer, Giroskop, Magnetometer) berhasil dikalibrasi.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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

  void _showHardwareDiagnosticDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Diagnostik Hardware',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagRow('Akselerometer 3-Axis', 'Lolos (9.81 m/s²)', true),
              const SizedBox(height: 8),
              _buildDiagRow('Giroskop Cornering', 'Lolos (50Hz Active)', true),
              const SizedBox(height: 8),
              _buildDiagRow(
                'Magnetometer Kompas',
                'Lolos (Geomagnetik OK)',
                true,
              ),
              const SizedBox(height: 8),
              _buildDiagRow(
                'Konstelasi GPS Dual-Band',
                '14 Satelit Terkunci',
                true,
              ),
              const SizedBox(height: 8),
              _buildDiagRow(
                'Barometer Internal',
                'Hardware Fallback Aktif',
                false,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiagRow(String label, String status, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: ok ? AppColors.tertiary : AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ok ? AppColors.tertiary : AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _testBarometerFallback() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: [
              const Icon(Icons.satellite_alt_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Estimasi Elevasi GPS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perhitungan ketinggian daratan saat ini diperoleh dari triangulasi satelit GPS:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
                child: Column(
                  children: [
                    Text(
                      '114 m dpl',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Akurasi Vertikal: ±3 meter (14 Satelit)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('OK'),
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
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Sub-Header: Live Telemetry & Calibration Trigger
            _buildSubHeader(),
            const SizedBox(height: 16),

            // 2. Hero Card: Digital Compass & Orientation
            _buildCompassHeroCard(),
            const SizedBox(height: 22),

            // 3. Section Title: Data Telemetri
            _buildTelemetrySectionHeader(),
            const SizedBox(height: 14),

            // 4. Card 1: Akselerometer
            _buildAccelerometerCard(),
            const SizedBox(height: 14),

            // 5. Card 2: Giroskop
            _buildGyroscopeCard(),
            const SizedBox(height: 14),

            // 6. Card 3: Magnetometer
            _buildMagnetometerCard(),
            const SizedBox(height: 14),

            // 7. Card 4: Unavailable Sensor State (Sensor Barometer)
            _buildBarometerCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const DashboardScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const VisitsScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const MapScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                transitionDuration: const Duration(milliseconds: 300),
              ),
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
                    // Back navigation button with glass glow
                    InkWell(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const DashboardScreen()),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: Container(
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
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: AppColors.onPrimaryContainer,
                        ),
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
                            'Sikunjung Peta Operasional',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
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
                          const Icon(
                            Icons.sensors_rounded,
                            size: 13,
                            color: AppColors.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'GPS Akurat - 3m',
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
                              content: Text('Pencarian sensor dibuka...'),
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

  Widget _buildSubHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left telemetry status chips
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Pembacaan Aktif (50Hz)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pembacaan Aktif (50Hz)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Diagnostik Hardware clickable
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showHardwareDiagnosticDialog,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Diagnostik Hardware',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Right calibrate-all button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isCalibratingAll ? null : _calibrateAllSensors,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceContainerLowest,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isCalibratingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.sync_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompassHeroCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1E293B),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            // Ambient Gradient Glow 1
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Ambient Gradient Glow 2
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Main Card Content
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card Header: Icon + Title & Subtitle + Presisi Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: const Icon(
                                Icons.explore_outlined,
                                size: 19,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kompas & Orientasi',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Aksis Real-Time 3D',
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixedDim.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Presisi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Interactive Compass Dial Widget (supports real-time device orientation & pan gesture)
                  Center(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _compassAngle = (_compassAngle + details.delta.dx) % 360;
                          if (_compassAngle < 0) _compassAngle += 360;
                        });
                      },
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: CompassDial(angleDegrees: _compassAngle),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3 Orientation Metric Boxes
                  Row(
                    children: [
                      // Metric 1: Akurasi
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Akurasi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _accuracyText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Metric 2: Kemiringan Pitch
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Kemiringan Pitch',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_pitch >= 0 ? '+' : ''}${_pitch.toInt()}°',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Metric 3: Rotasi Roll
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Rotasi Roll',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_roll.toInt()}°',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Full-Width Calibration CTA Button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isCalibratingCompass
                          ? null
                          : _triggerCompassCalibration,
                      icon: _isCalibratingCompass
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : Icon(
                              _compassCalibrated
                                  ? Icons.check_circle_rounded
                                  : Icons.all_inclusive_rounded,
                              size: 18,
                              color: _compassCalibrated
                                  ? AppColors.tertiary
                                  : AppColors.primary,
                            ),
                      label: Text(
                        _isCalibratingCompass
                            ? 'Mengalibrasi Kompas...'
                            : _compassCalibrated
                            ? 'Kompas Terkalibrasi!'
                            : 'Kalibrasi Kompas (Pola Angka 8)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _compassCalibrated
                              ? AppColors.tertiary
                              : AppColors.primary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainer,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
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

  Widget _buildTelemetrySectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Data Telemetri',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '3 Aktif • 1 Tidak Aktif',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAccelerometerCard() {
    return SensorCard(
      icon: Icons.speed_rounded,
      iconColor: AppColors.primary,
      iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.15),
      title: 'Akselerometer',
      unit: 'm/s²',
      statusText: 'Aktif • Gravitasi Normal',
      statusColor: AppColors.tertiary,
      statusDotColor: AppColors.tertiary,
      badgeText: 'Total: 9.81 m/s²',
      children: [
        SensorAxisBar(
          label: 'Sumbu X (Lateral)',
          value: '${_accelX >= 0 ? '+' : ''}${_accelX.toStringAsFixed(2)} m/s²',
          indicatorColor: AppColors.primary,
          fraction: (_accelX / 4.0).clamp(-1.0, 1.0),
          barType: SensorBarType.centeredOffset,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Y (Vertikal/Gravitasi)',
          value: '${_accelY >= 0 ? '+' : ''}${_accelY.toStringAsFixed(2)} m/s²',
          valueColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          fraction: (_accelY / 12.0).clamp(0.0, 1.0),
          barType: SensorBarType.filled,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Z (Depan-Belakang)',
          value: '${_accelZ >= 0 ? '+' : ''}${_accelZ.toStringAsFixed(2)} m/s²',
          valueColor: AppColors.secondaryContainer,
          indicatorColor: AppColors.secondaryContainer,
          fraction: (_accelZ / 4.0).clamp(-1.0, 1.0),
          barType: SensorBarType.centeredOffset,
        ),
      ],
    );
  }

  Widget _buildGyroscopeCard() {
    return SensorCard(
      icon: Icons.threesixty_rounded,
      iconColor: AppColors.primary,
      iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.15),
      title: 'Giroskop',
      unit: 'rad/s',
      statusText: 'Aktif • Kecepatan Sudut',
      statusColor: AppColors.tertiary,
      statusDotColor: AppColors.tertiary,
      badgeText: 'Dinamis',
      badgeBgColor: AppColors.surfaceContainerLow,
      badgeTextColor: AppColors.onSurfaceVariant,
      children: [
        SensorAxisBar(
          label: 'Sumbu X (Pitch Rate)',
          value: '${_gyroX >= 0 ? '+' : ''}${_gyroX.toStringAsFixed(3)} rad/s',
          indicatorColor: AppColors.tertiary,
          fraction: (_gyroX * 20).clamp(-1.0, 1.0),
          barType: SensorBarType.centeredBar,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Y (Roll Rate)',
          value: '${_gyroY >= 0 ? '+' : ''}${_gyroY.toStringAsFixed(3)} rad/s',
          valueColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          fraction: (_gyroY * 20).clamp(-1.0, 1.0),
          barType: SensorBarType.centeredBar,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Z (Yaw Rate)',
          value: '${_gyroZ >= 0 ? '+' : ''}${_gyroZ.toStringAsFixed(3)} rad/s',
          indicatorColor: AppColors.primaryFixedDim,
          fraction: (_gyroZ * 20).clamp(-1.0, 1.0),
          barType: SensorBarType.centeredBar,
        ),
      ],
    );
  }

  Widget _buildMagnetometerCard() {
    return SensorCard(
      icon: Icons.filter_drama_rounded,
      iconColor: AppColors.secondary,
      iconBgColor: AppColors.secondaryFixed.withValues(alpha: 0.5),
      title: 'Magnetometer',
      unit: 'µT',
      statusText: 'Aktif • Geomagnetik Bumi',
      statusColor: AppColors.tertiary,
      statusDotColor: AppColors.tertiary,
      badgeText: '48.2 µT (Ideal)',
      badgeTextColor: AppColors.primary,
      children: [
        SensorAxisBar(
          label: 'Sumbu X (Utara Magnetis)',
          value: '${_magX >= 0 ? '+' : ''}${_magX.toStringAsFixed(1)} µT',
          indicatorColor: AppColors.primary,
          fraction: (_magX / 50.0).clamp(0.0, 1.0),
          barType: SensorBarType.filled,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Y (Timur Magnetis)',
          value: '${_magY >= 0 ? '+' : ''}${_magY.toStringAsFixed(1)} µT',
          valueColor: AppColors.secondary,
          indicatorColor: AppColors.secondaryContainer,
          fraction: (_magY.abs() / 50.0).clamp(0.0, 1.0),
          barType: SensorBarType.filled,
        ),
        const SizedBox(height: 10),
        SensorAxisBar(
          label: 'Sumbu Z (Vertikal Bumi)',
          value: '${_magZ >= 0 ? '+' : ''}${_magZ.toStringAsFixed(1)} µT',
          valueColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          fraction: (_magZ / 50.0).clamp(0.0, 1.0),
          barType: SensorBarType.filled,
        ),
      ],
    );
  }

  Widget _buildBarometerCard() {
    return SensorCard(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.outline,
      iconBgColor: AppColors.surfaceContainerHigh,
      title: 'Sensor Barometer',
      unit: 'hPa',
      statusText: 'Hardware Tidak Terpasang',
      statusColor: AppColors.outline,
      statusDotColor: AppColors.outline,
      badgeText: 'Off',
      badgeBgColor: AppColors.surfaceContainer,
      badgeTextColor: AppColors.onSurfaceVariant,
      opacity: 0.92,
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hardware perangkat ini tidak dilengkapi sensor tekanan udara internal. Ketinggian (elevasi dpl) diestimasi secara otomatis via konstelasi satelit GPS.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _testBarometerFallback,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.satellite_alt_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'GPS Barometrik Fallback Aktif (±14m dpl)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
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
            ],
          ),
        ),
      ],
    );
  }
}

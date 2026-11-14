import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import '../widgets/dual_orbit_loader.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onInitializationComplete;
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.onInitializationComplete,
    this.autoNavigate = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _fallbackTimer;
  bool _hasNavigated = false;

  late final AnimationController _mapPinController;
  late final AnimationController _textController;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textScale;
  late final Animation<double> _subFade;

  @override
  void initState() {
    super.initState();

    // Map pin Lottie controller: tracks completion to hold splash until done
    _mapPinController = AnimationController(vsync: this);
    _mapPinController.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.autoNavigate) {
        // Natural brief pause (350ms) after the pin animation unfolds before transitioning
        _timer = Timer(const Duration(milliseconds: 350), _proceedToNext);
      }
    });

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smooth organic spring curve for non-rigid entrance
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.10, 0.70, curve: Curves.easeOutCubic),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.10, 0.85, curve: Curves.easeOutCubic),
          ),
        );

    _textScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.10, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _subFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _textController.forward();

    if (widget.autoNavigate) {
      // Safety fallback: in case asset fails to load in isolated environments
      _fallbackTimer = Timer(const Duration(milliseconds: 4500), () {
        if (mounted && !_hasNavigated) {
          _proceedToNext();
        }
      });
    }
  }

  void _proceedToNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _timer?.cancel();
    _fallbackTimer?.cancel();
    if (widget.onInitializationComplete != null) {
      widget.onInitializationComplete!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fallbackTimer?.cancel();
    _textController.dispose();
    _mapPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: _proceedToNext,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Base Rich Teal Gradient
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.splashGradientTop,
                    AppColors.splashGradientMid,
                    AppColors.splashGradientBottom,
                  ],
                ),
              ),
            ),

            // 2. Subtle, Elegant Centered Ambient Radial Glow (Behind Hero)
            Align(
              alignment: const Alignment(0, -0.15),
              child: Container(
                width: screenSize.width * 0.85,
                height: screenSize.width * 0.85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.splashGlow2.withValues(alpha: 0.18),
                      AppColors.splashGlow1.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Center Hero Branding: Optical Center Placement
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -0.15),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Map Pin Lottie Animation (Clean & Balanced Proportion)
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: Lottie.asset(
                          'assets/animations/map_pin.json',
                          controller: _mapPinController,
                          fit: BoxFit.contain,
                          repeat: false,
                          onLoaded: (composition) {
                            _mapPinController.duration = composition.duration;
                            _mapPinController.forward();
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 84,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Smooth Entrance: Slide + Scale + Fade
                      FadeTransition(
                        opacity: _textFade,
                        child: SlideTransition(
                          position: _textSlide,
                          child: ScaleTransition(
                            scale: _textScale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title: "Si Kunjung"
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Si Kunjung',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x3D000000),
                                          blurRadius: 16,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle: "Sistem Informasi Kunjungan Lapangan"
                                FadeTransition(
                                  opacity: _subFade,
                                  child: Text(
                                    'Sistem Informasi Kunjungan Lapangan',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      letterSpacing: 0.2,
                                      height: 1.35,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x26000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
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
              ),
            ),

            // 4. Elegant Bottom Status & Loader
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 28.0,
                    left: 24.0,
                    right: 24.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smooth Lottie Loader
                      SizedBox(
                        width: 52,
                        height: 38,
                        child: Lottie.asset(
                          'assets/animations/loading.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const DualOrbitLoader(size: 28);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // GPS & Status Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.satellite_alt_rounded,
                            size: 14,
                            color: AppColors.primaryFixed,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Terhubung dengan GPS & Cloud Presensi',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Elegant App Version/Brand Tagline
                      Text(
                        'SIKUNJUNG MOBILE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: Colors.white.withValues(alpha: 0.40),
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
    );
  }
}

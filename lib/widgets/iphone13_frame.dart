import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps any screen or the entire app inside a realistic iPhone 13 mockup frame
/// for web and desktop presentation, while passing through untouched on mobile.
class IPhone13Wrapper extends StatefulWidget {
  final Widget child;
  final bool enableFrameOnWeb;

  const IPhone13Wrapper({
    super.key,
    required this.child,
    this.enableFrameOnWeb = true,
  });

  @override
  State<IPhone13Wrapper> createState() => _IPhone13WrapperState();
}

class _IPhone13WrapperState extends State<IPhone13Wrapper> {
  bool _isFramed = true;
  String _currentTime = '09:41';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _currentTime = '$hour:$minute';
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    // If not on web or frame toggled off on narrow mobile screen, render full
    if (!kIsWeb || !widget.enableFrameOnWeb) {
      return widget.child;
    }

    final screenSize = MediaQuery.of(context).size;
    final isMobileBrowser = screenSize.width <= 480;

    if (isMobileBrowser || !_isFramed) {
      return widget.child;
    }

    // Standard iPhone 13 Screen Specs
    const double screenWidth = 390.0;
    const double screenHeight = 844.0;
    const double bezelThickness = 12.0;
    const double outerRadius = 54.0;
    const double innerRadius = 46.0;

    final double deviceWidth = screenWidth + (bezelThickness * 2);
    final double deviceHeight = screenHeight + (bezelThickness * 2);

    return Material(
      color: const Color(0xFF0F172A), // Dark slate canvas
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Presentation Toolbar
              _buildTopToolbar(context),

              // Canvas Center: Centered iPhone 13 Mockup
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left side buttons (Mute switch, Volume Up, Volume Down)
                          _buildLeftSideButtons(),

                          // Main Phone Chassis
                          Container(
                            width: deviceWidth,
                            height: deviceHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1E21), // Midnight chassis
                              borderRadius:
                                  BorderRadius.circular(outerRadius),
                              border: Border.all(
                                color: const Color(0xFF33383F),
                                width: 3.5,
                              ),
                              boxShadow: [
                                // Deep ambient shadow
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  blurRadius: 45,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 24),
                                ),
                                // Teal brand halo
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 70,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 10),
                                ),
                                // Sharp contact shadow
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(bezelThickness),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(innerRadius),
                              child: SizedBox(
                                width: screenWidth,
                                height: screenHeight,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          size: const Size(
                                              screenWidth, screenHeight),
                                          padding: const EdgeInsets.only(
                                            top: 47,
                                            bottom: 34,
                                          ),
                                          viewPadding: const EdgeInsets.only(
                                            top: 47,
                                            bottom: 34,
                                          ),
                                          devicePixelRatio: 3.0,
                                        ),
                                        child: widget.child,
                                      ),
                                    ),

                                  // iPhone 13 Top Status Bar Overlay
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 44,
                                    child: IgnorePointer(
                                      child: _buildIPhoneStatusBar(),
                                    ),
                                  ),

                                  // iPhone 13 Hardware Notch
                                  Positioned(
                                    top: 0,
                                    left: (screenWidth - 156) / 2,
                                    child: IgnorePointer(
                                      child: _buildIPhone13Notch(),
                                    ),
                                  ),

                                  // iPhone 13 Bottom Home Indicator
                                  Positioned(
                                    bottom: 8,
                                    left: (screenWidth - 134) / 2,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 134,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 4,
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

                        // Right side button (Power / Sleep)
                        _buildRightSideButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Phone Mockup Area completed
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_iphone_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SiKunjung Mobile — iPhone 13 Web Simulator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '390 × 844 pt • iOS 15+ Safe Area • Super Retina XDR',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildToolbarAction(
                icon: _isFramed ? Icons.fullscreen_rounded : Icons.phone_iphone_rounded,
                label: _isFramed ? 'Layar Penuh' : 'Mode Bingkai',
                onTap: () {
                  setState(() {
                    _isFramed = !_isFramed;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSideButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ring/Silent switch
        Container(
          width: 3.5,
          height: 26,
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3F47),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              bottomLeft: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(-1, 0),
              ),
            ],
          ),
        ),
        // Volume Up
        Container(
          width: 3.5,
          height: 52,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3F47),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              bottomLeft: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(-1, 0),
              ),
            ],
          ),
        ),
        // Volume Down
        Container(
          width: 3.5,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3F47),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              bottomLeft: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(-1, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightSideButton() {
    return Container(
      width: 3.5,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3F47),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildIPhone13Notch() {
    return Container(
      width: 156,
      height: 29,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ear speaker pill
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2327),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFF33383F),
                    width: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Front camera lens with blue/cyan antireflective ring
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF080D1A),
                  border: Border.all(
                    color: const Color(0xFF1E3A5F),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2C5E8A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIPhoneStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Time (Left of notch)
          Text(
            _currentTime,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),

          // Icons (Right of notch: Signal, 5G/WiFi, Battery)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 4 Cellular Bars
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(4, (i) {
                  return Container(
                    width: 2.8,
                    height: 4.0 + (i * 2.2),
                    margin: const EdgeInsets.symmetric(horizontal: 0.6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 5),
              // WiFi
              const Icon(
                Icons.wifi_rounded,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 5),
              // Battery icon with fill
              Container(
                width: 22,
                height: 11,
                padding: const EdgeInsets.all(1.2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 1.1),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.5),
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

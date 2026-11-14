import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 112.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Coral ambient glow
          Container(
            width: size * 0.95,
            height: size * 0.95,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // Outer Plaque
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.23),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF00685D),
                  Color(0xFF004D40),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.19),
              child: Stack(
                children: [
                  // Inner plaque gradient
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF00796B),
                          Color(0xFF005E53),
                        ],
                      ),
                    ),
                  ),
                  // Gloss highlight
                  Positioned(
                    top: -size * 0.35,
                    left: -size * 0.35,
                    child: Transform.rotate(
                      angle: 12 * math.pi / 180,
                      child: Container(
                        width: size * 0.9,
                        height: size * 0.75,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(size),
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                  // Pin & Checkmark
                  Center(
                    child: SizedBox(
                      width: size * 0.58,
                      height: size * 0.72,
                      child: const _MapPinWithCheck(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPinWithCheck extends StatelessWidget {
  const _MapPinWithCheck();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          alignment: Alignment.center,
          children: [
            // White location pin shape
            CustomPaint(
              size: Size(w, h),
              painter: _PinPainter(color: Colors.white),
            ),
            // Coral circular checkmark container
            Positioned(
              top: h * 0.14,
              child: Container(
                width: w * 0.48,
                height: w * 0.48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: w * 0.32,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;

  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final radius = w / 2;
    final centerCircleY = radius * 0.95;

    final path = Path();
    // Arc of top circle
    path.arcTo(
      Rect.fromCircle(center: Offset(w / 2, centerCircleY), radius: radius),
      math.pi * 0.80,
      math.pi * 1.40,
      false,
    );

    // Right curve down to tip
    path.quadraticBezierTo(
      w * 0.95,
      h * 0.65,
      w / 2,
      h * 0.98,
    );

    // Left curve up from tip to circle arc start
    path.quadraticBezierTo(
      w * 0.05,
      h * 0.65,
      w / 2 - radius * math.cos(math.pi * 0.20),
      centerCircleY + radius * math.sin(math.pi * 0.20),
    );

    path.close();

    // Drop shadow under pin
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

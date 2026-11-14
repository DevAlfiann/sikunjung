import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CompassDial extends StatelessWidget {
  final double angleDegrees; // in degrees, e.g. 45.0

  const CompassDial({
    super.key,
    this.angleDegrees = 45.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      height: 224,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Vector dial background with degree marks & cardinals
          CustomPaint(
            size: const Size(224, 224),
            painter: _CompassDialPainter(),
          ),

          // 2. Rotating needle
          Transform.rotate(
            angle: angleDegrees * (math.pi / 180.0),
            child: SizedBox(
              width: 224,
              height: 224,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // North Needle (Warm Coral)
                  Positioned(
                    top: 28,
                    child: Container(
                      width: 12,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.full),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33FD7958),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // South Needle (Teal dim / Surface Variant)
                  Positioned(
                    bottom: 28,
                    child: Container(
                      width: 12,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ),

                  // Center Pivot Cap
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerLowest,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Center Numerical & Direction Label Overlay
          Positioned(
            bottom: 42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${angleDegrees.round() % 360}°',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getDirectionLabel(angleDegrees),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDirectionLabel(double deg) {
    final normalized = (deg % 360 + 360) % 360;
    if (normalized >= 22.5 && normalized < 67.5) {
      return 'Timur Laut (NE)';
    } else if (normalized >= 67.5 && normalized < 112.5) {
      return 'Timur (E)';
    } else if (normalized >= 112.5 && normalized < 157.5) {
      return 'Tenggara (SE)';
    } else if (normalized >= 157.5 && normalized < 202.5) {
      return 'Selatan (S)';
    } else if (normalized >= 202.5 && normalized < 247.5) {
      return 'Barat Daya (SW)';
    } else if (normalized >= 247.5 && normalized < 292.5) {
      return 'Barat (W)';
    } else if (normalized >= 292.5 && normalized < 337.5) {
      return 'Barat Laut (NW)';
    } else {
      return 'Utara (N)';
    }
  }
}

class _CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 8;
    final innerRadius = outerRadius - 12;

    // Dotted outer track
    final trackPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw dashed circle
    const totalDashes = 72;
    const dashArc = (2 * math.pi) / totalDashes;
    for (int i = 0; i < totalDashes; i++) {
      if (i % 2 == 0) {
        final startAngle = i * dashArc;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          startAngle,
          dashArc * 0.6,
          false,
          trackPaint,
        );
      }
    }

    // Inner subtle circle
    final innerTrackPaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, innerTrackPaint);

    // Degree tick marks every 30 degrees
    final tickPaint = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final rad = i * 30.0 * (math.pi / 180.0);
      final tickStart = Offset(
        center.dx + (outerRadius - 2) * math.sin(rad),
        center.dy - (outerRadius - 2) * math.cos(rad),
      );
      final tickEnd = Offset(
        center.dx + (outerRadius - 8) * math.sin(rad),
        center.dy - (outerRadius - 8) * math.cos(rad),
      );
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }

    // Text Painter for Cardinals and Intercardinals
    _drawText(canvas, 'U', Offset(center.dx, center.dy - outerRadius + 18),
        AppColors.secondary, 12, FontWeight.w800);
    _drawText(canvas, 'T', Offset(center.dx + outerRadius - 16, center.dy),
        AppColors.onSurfaceVariant, 11, FontWeight.w700);
    _drawText(canvas, 'S', Offset(center.dx, center.dy + outerRadius - 16),
        AppColors.onSurfaceVariant, 11, FontWeight.w700);
    _drawText(canvas, 'B', Offset(center.dx - outerRadius + 16, center.dy),
        AppColors.onSurfaceVariant, 11, FontWeight.w700);

    // Intercardinals (TL, TG, BD, BL)
    final dRadius = outerRadius - 24;
    final sin45 = math.sin(math.pi / 4);

    _drawText(
      canvas,
      'TL',
      Offset(center.dx + dRadius * sin45, center.dy - dRadius * sin45),
      AppColors.primary,
      9,
      FontWeight.w700,
    );
    _drawText(
      canvas,
      'TG',
      Offset(center.dx + dRadius * sin45, center.dy + dRadius * sin45),
      AppColors.outline,
      9,
      FontWeight.w600,
    );
    _drawText(
      canvas,
      'BD',
      Offset(center.dx - dRadius * sin45, center.dy + dRadius * sin45),
      AppColors.outline,
      9,
      FontWeight.w600,
    );
    _drawText(
      canvas,
      'BL',
      Offset(center.dx - dRadius * sin45, center.dy - dRadius * sin45),
      AppColors.outline,
      9,
      FontWeight.w600,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
    FontWeight fontWeight,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: GoogleFonts.plusJakartaSans(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


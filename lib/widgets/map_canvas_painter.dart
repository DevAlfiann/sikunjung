import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MapCanvasPainter extends CustomPainter {
  final double radarAngle;
  final Offset? startPoint;
  final Offset? endPoint;
  final bool isNavigating;

  MapCanvasPainter({
    this.radarAngle = 0.0,
    this.startPoint,
    this.endPoint,
    this.isNavigating = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Background Land Area
    final bgPaint = Paint()..color = const Color(0xFFEFF4FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Green Spaces (Parks: Kraton & UGM Areas)
    final greenPaint = Paint()
      ..color = const Color(0xFFD4EDDA).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;

    final park1 = Path()
      ..moveTo(0, h * 0.25)
      ..quadraticBezierTo(w * 0.2, h * 0.22, w * 0.35, h * 0.30)
      ..lineTo(w * 0.1, h * 0.45)
      ..lineTo(0, h * 0.40)
      ..close();
    canvas.drawPath(park1, greenPaint);

    final park2 = Path()
      ..moveTo(w * 0.65, h * 0.10)
      ..quadraticBezierTo(w * 0.85, h * 0.08, w, h * 0.15)
      ..lineTo(w, h * 0.32)
      ..lineTo(w * 0.72, h * 0.28)
      ..close();
    canvas.drawPath(park2, greenPaint);

    final park3 = Path()
      ..moveTo(w * 0.55, h * 0.58)
      ..quadraticBezierTo(w * 0.80, h * 0.56, w * 0.90, h * 0.68)
      ..lineTo(w * 0.70, h * 0.80)
      ..lineTo(w * 0.50, h * 0.72)
      ..close();
    canvas.drawPath(park3, greenPaint);

    // 3. River (Kali Code representation)
    final riverPaint = Paint()
      ..color = const Color(0xFFCBDDF5).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(w * 0.75, 0)
      ..cubicTo(w * 0.70, h * 0.20, w * 0.80, h * 0.35, w * 0.68, h * 0.52)
      ..cubicTo(w * 0.58, h * 0.68, w * 0.66, h * 0.85, w * 0.60, h);
    canvas.drawPath(riverPath, riverPaint);

    final riverCenter = Paint()
      ..color = const Color(0xFFA0C2ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(riverPath, riverCenter);

    // 4. Urban Blocks / Subdivisions
    final blockPaint = Paint()
      ..color = const Color(0xFFE2EBFA).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final blockBorder = Paint()
      ..color = const Color(0xFFD5E3F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void drawBlock(double l, double t, double width, double height) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(l, t, width, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(r, blockPaint);
      canvas.drawRRect(r, blockBorder);
    }

    drawBlock(w * 0.08, h * 0.10, w * 0.18, h * 0.07);
    drawBlock(w * 0.30, h * 0.08, w * 0.22, h * 0.09);
    drawBlock(w * 0.08, h * 0.20, w * 0.16, h * 0.06);
    drawBlock(w * 0.56, h * 0.22, w * 0.12, h * 0.07);
    drawBlock(w * 0.05, h * 0.55, w * 0.20, h * 0.10);
    drawBlock(w * 0.30, h * 0.56, w * 0.15, h * 0.07);
    drawBlock(w * 0.75, h * 0.44, w * 0.18, h * 0.09);
    drawBlock(w * 0.28, h * 0.38, w * 0.16, h * 0.08);

    // 5. Secondary Road Grid
    final secRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(Offset(0, h * 0.35), Offset(w, h * 0.35), secRoadPaint);
    canvas.drawLine(Offset(0, h * 0.54), Offset(w, h * 0.52), secRoadPaint);
    canvas.drawLine(Offset(w * 0.28, 0), Offset(w * 0.28, h), secRoadPaint);
    canvas.drawLine(Offset(w * 0.50, 0), Offset(w * 0.50, h), secRoadPaint);
    canvas.drawLine(Offset(w * 0.75, h * 0.16), Offset(w, h * 0.16), secRoadPaint);
    canvas.drawLine(Offset(0, h * 0.70), Offset(w * 0.65, h * 0.70), secRoadPaint);

    // 6. Primary Arterial Roads (Besar Ijen & Soekarno Hatta corridors)
    final mainRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(Offset(0, h * 0.18), Offset(w, h * 0.18), mainRoadPaint);
    canvas.drawLine(Offset(w * 0.40, 0), Offset(w * 0.40, h), mainRoadPaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.28), Offset(w, h * 0.48), mainRoadPaint);

    // Road dashed centerlines
    final dashPaint = Paint()
      ..color = const Color(0xFFDCE9FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, Offset(0, h * 0.18), Offset(w, h * 0.18), dashPaint, 8, 6);
    _drawDashedLine(canvas, Offset(w * 0.40, 0), Offset(w * 0.40, h), dashPaint, 8, 6);

    // 7. Dynamic Navigation Route from startPoint to endPoint
    final startRoute = startPoint ?? Offset(w * 0.40, h * 0.52);
    final destRoute = endPoint ?? Offset(w * 0.51, h * 0.34);

    final midY = (startRoute.dy + destRoute.dy) / 2;
    final routePath = Path()
      ..moveTo(startRoute.dx, startRoute.dy)
      ..lineTo(startRoute.dx, midY)
      ..lineTo(destRoute.dx, midY)
      ..lineTo(destRoute.dx, destRoute.dy);

    final routeGlow = Paint()
      ..color = (isNavigating ? AppColors.tertiary : AppColors.primaryFixedDim)
          .withValues(alpha: 0.5)
      ..strokeWidth = isNavigating ? 12 : 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(routePath, routeGlow);

    final routeLine = Paint()
      ..color = isNavigating ? AppColors.tertiary : AppColors.primary
      ..strokeWidth = isNavigating ? 5 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawDashedPath(canvas, routePath, routeLine, 6, 6);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final totalDist = math.sqrt(dx * dx + dy * dy);
    final count = (totalDist / (dashWidth + dashSpace)).floor();
    final unitX = dx / totalDist;
    final unitY = dy / totalDist;

    for (int i = 0; i < count; i++) {
      final start = Offset(
        p1.dx + unitX * (i * (dashWidth + dashSpace)),
        p1.dy + unitY * (i * (dashWidth + dashSpace)),
      );
      final end = Offset(
        start.dx + unitX * dashWidth,
        start.dy + unitY * dashWidth,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


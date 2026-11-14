import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum SensorBarType {
  filled, // Fills from left (e.g. 0% to 100%)
  centeredOffset, // A centered pill slightly offset left/right
  centeredBar, // Grows from the center to the left (negative) or right (positive)
}

class SensorAxisBar extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color indicatorColor;
  final double fraction; // 0.0 to 1.0 (or -1.0 to 1.0 for centered)
  final SensorBarType barType;

  const SensorAxisBar({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    required this.indicatorColor,
    required this.fraction,
    this.barType = SensorBarType.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label + Value Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),

        // Visual Progress Track
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              if (barType == SensorBarType.filled) {
                final barWidth = (width * fraction.clamp(0.0, 1.0));
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: barWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                );
              } else if (barType == SensorBarType.centeredOffset) {
                // Centered pill with small offset
                final center = width / 2;
                const pillWidth = 28.0;
                final offset = (fraction * (width / 4)).clamp(-center + pillWidth / 2, center - pillWidth / 2);
                final leftPos = (center - pillWidth / 2 + offset).clamp(0.0, width - pillWidth);

                return Stack(
                  children: [
                    Positioned(
                      left: leftPos,
                      child: Container(
                        width: pillWidth,
                        height: 8,
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // centeredBar: grows from center to left or right
                final center = width / 2;
                final barWidth = (width / 2 * fraction.abs()).clamp(4.0, width / 2);

                if (fraction >= 0) {
                  return Stack(
                    children: [
                      Positioned(
                        left: center,
                        child: Container(
                          width: barWidth,
                          height: 8,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Stack(
                    children: [
                      Positioned(
                        left: center - barWidth,
                        child: Container(
                          width: barWidth,
                          height: 8,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}


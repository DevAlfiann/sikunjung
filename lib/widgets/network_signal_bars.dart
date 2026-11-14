import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NetworkSignalBars extends StatelessWidget {
  final int activeBars; // 1 to 4
  final Color activeColor;
  final Color inactiveColor;

  const NetworkSignalBars({
    super.key,
    this.activeBars = 4,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.surfaceContainerHigh,
  });

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 9.0, 12.0, 15.0];

    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final isActive = index < activeBars;
          return Padding(
            padding: const EdgeInsets.only(right: 2.5),
            child: Container(
              width: 3.5,
              height: heights[index],
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }),
      ),
    );
  }
}


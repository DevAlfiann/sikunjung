import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Next-Generation "iOS 26 Liquid Glass" Navigation Bar.
/// Features optical frosted-glass refraction, floating capsule geometry,
/// luminous specular rim lighting, and fluid active tab morphing.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 6,
        bottom: bottomPadding > 0 ? bottomPadding + 4 : 14,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            // Ambient depth shadow with subtle chromatic refraction
            BoxShadow(
              color: const Color(0xFF003830).withValues(alpha: 0.14),
              blurRadius: 28,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
            // Top ambient illumination
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                // Liquid glass refraction gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.58),
                    Colors.white.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
                // Liquid glass specular reflection perimeter
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Specular light edge highlight across top bevel
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    height: 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Navigation Items Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildNavItem(
                          index: 0,
                          label: 'Beranda',
                          icon: Icons.home_rounded,
                          unselectedIcon: Icons.home_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          index: 1,
                          label: 'Kunjungan',
                          icon: Icons.assignment_rounded,
                          unselectedIcon: Icons.assignment_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildNavItem(
                          index: 2,
                          label: 'Peta',
                          icon: Icons.map_rounded,
                          unselectedIcon: Icons.map_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData unselectedIcon,
  }) {
    final isSelected = currentIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(28),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Liquid Capsule for active state
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.primaryContainer.withValues(alpha: 0.38),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          width: 1.2,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? icon : unselectedIcon,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : const Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              // Subtle glowing liquid bead indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

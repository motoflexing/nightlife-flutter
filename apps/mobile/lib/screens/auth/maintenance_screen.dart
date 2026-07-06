import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/nocturne_monogram.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NocturneMonogram(size: 72, innerRing: true),
              const SizedBox(height: 32),
              // Tracked uppercase gold eyebrow.
              Text(
                'Under Maintenance'.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.3 * 10,
                  color: AppColors.champagne,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We'll be right back.",
                textAlign: TextAlign.center,
                // Playfair heading.
                style: AppTypography.displayMedium.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 14),
              Text(
                'The app is currently undergoing maintenance. '
                'Please check back shortly.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textBodyDim,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

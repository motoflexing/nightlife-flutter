import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/nocturne_monogram.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.updateUrl,
    this.isForced = true,
  });

  final String updateUrl;
  final bool isForced;

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
                (isForced ? 'Update Required' : 'Update Available')
                    .toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.3 * 10,
                  color: AppColors.champagne,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isForced ? 'A new version\nawaits.' : 'A new version\nis ready.',
                textAlign: TextAlign.center,
                // Playfair heading.
                style: AppTypography.displayMedium.copyWith(
                  fontSize: 32,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isForced
                    ? 'This version of the app is no longer supported. '
                          'Please update to continue.'
                    : 'A new version is available with improvements '
                          'and bug fixes.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textBodyDim,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openStore,
                  child: const Text('UPDATE NOW'),
                ),
              ),
              if (!isForced) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Maybe later'.toUpperCase(),
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.tryParse(updateUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

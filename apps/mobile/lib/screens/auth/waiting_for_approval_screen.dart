import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';

class WaitingForApprovalScreen extends StatelessWidget {
  const WaitingForApprovalScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    const roleLabel = 'venue admin';
    return NeonScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              borderRadius: 8,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gold-ring hourglass medallion (design "Under review").
                  Container(
                    width: 92,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.champagne.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.hourglass_top,
                      color: AppColors.champagne,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tracked uppercase gold eyebrow.
                  Text(
                    'Under Review'.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.3 * 10,
                      color: AppColors.champagne,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "We're reviewing\nyour house.",
                    textAlign: TextAlign.center,
                    // Playfair heading (design awaiting approval).
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 32,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your $roleLabel profile has been submitted. Our team is '
                    'confirming your details, and we will unlock dashboard '
                    'access after manual review.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textBodyDim,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Real status, read straight off the profile — no fabricated
                  // timeline or fake progress.
                  _StatusRow(
                    label: 'Verification',
                    value: currentUser.verificationStatus.isEmpty
                        ? 'pending_review'
                        : currentUser.verificationStatus,
                  ),
                  const _RowHairline(),
                  _StatusRow(
                    label: 'Document upload',
                    value: currentUser.documentUploadStatus,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService.instance.signOut();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('LOGOUT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                letterSpacing: 0.2 * 10,
                color: AppColors.textCaption,
              ),
            ),
          ),
          Text(
            value.replaceAll('_', ' ').toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              fontSize: 10,
              color: AppColors.champagne,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowHairline extends StatelessWidget {
  const _RowHairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.goldBorder);
  }
}

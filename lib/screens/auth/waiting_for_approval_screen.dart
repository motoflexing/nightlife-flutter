import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_scaffold.dart';

class WaitingForApprovalScreen extends StatelessWidget {
  const WaitingForApprovalScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final roleLabel = currentUser.isClubAdmin ? 'venue' : 'promoter';
    return NeonScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              borderRadius: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.premiumGradient,
                    ),
                    child: const Icon(Icons.hourglass_top, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for admin approval',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your $roleLabel profile has been submitted. We will unlock dashboard access after manual review.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  _StatusRow(
                    label: 'Verification',
                    value: currentUser.verificationStatus.isEmpty
                        ? 'pending_review'
                        : currentUser.verificationStatus,
                  ),
                  _StatusRow(
                    label: 'Document upload',
                    value: currentUser.documentUploadStatus,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: AuthService.instance.signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
          Text(
            value.replaceAll('_', ' '),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

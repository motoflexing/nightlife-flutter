import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_outlined,
                size: 72,
                color: AppTheme.paidAccent,
              ),
              const SizedBox(height: 24),
              Text(
                isForced ? 'Update Required' : 'Update Available',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isForced
                    ? 'This version of the app is no longer supported. '
                        'Please update to continue.'
                    : 'A new version is available with improvements '
                        'and bug fixes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openStore,
                  child: const Text('Update Now'),
                ),
              ),
              if (!isForced) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Maybe Later'),
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

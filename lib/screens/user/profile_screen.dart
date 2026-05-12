import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.neonPink.withValues(alpha: 0.16),
                  child: Text(
                    currentUser.name.isEmpty ? '?' : currentUser.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  currentUser.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(currentUser.email, style: const TextStyle(color: AppTheme.textMuted)),
                Text(currentUser.phone, style: const TextStyle(color: AppTheme.textMuted)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Role: ${currentUser.role}')),
                    Chip(label: Text('Status: ${currentUser.status}')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: AuthService.instance.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

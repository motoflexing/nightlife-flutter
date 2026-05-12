import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/promoter/promoter_dashboard_screen.dart';
import '../../screens/user/user_shell_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';
import 'login_screen.dart';

class RoleRouterScreen extends StatelessWidget {
  const RoleRouterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const NeonScaffold(child: LoadingView());
        }
        final user = authSnapshot.data;
        if (user == null) return const LoginScreen();
        return StreamBuilder<AppUser?>(
          stream: AuthService.instance.profileStream(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const NeonScaffold(child: LoadingView(message: 'Loading profile'));
            }
            if (profileSnapshot.hasError) {
              return NeonScaffold(
                child: ErrorStateView(message: profileSnapshot.error.toString()),
              );
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              return _BlockedState(
                title: 'Profile missing',
                message: 'Your auth account exists, but the Firestore profile was not found.',
              );
            }
            if (!profile.isActive) {
              return const _BlockedState(
                title: 'Account inactive',
                message: 'Please contact the admin team to reactivate this account.',
              );
            }
            switch (profile.role) {
              case 'admin':
                return AdminDashboardScreen(currentUser: profile);
              case 'promoter':
                return PromoterDashboardScreen(currentUser: profile);
              default:
                return UserShellScreen(currentUser: profile);
            }
          },
        );
      },
    );
  }
}

class _BlockedState extends StatelessWidget {
  const _BlockedState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, color: AppTheme.neonPink, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
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

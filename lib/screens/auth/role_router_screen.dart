import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/club/club_admin_dashboard_screen.dart';
import '../../screens/promoter/promoter_dashboard_screen.dart';
import '../../screens/user/user_shell_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';
import 'access_state_screen.dart';
import 'club_onboarding_screen.dart';
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
              return FutureBuilder<AppUser>(
                future: AuthService.instance.ensureSafeProfile(user),
                builder: (context, safeSnapshot) {
                  if (safeSnapshot.connectionState == ConnectionState.waiting) {
                    return const NeonScaffold(
                      child: LoadingView(message: 'Creating safe profile'),
                    );
                  }
                  if (safeSnapshot.hasError) {
                    return NeonScaffold(
                      child: ErrorStateView(message: safeSnapshot.error.toString()),
                    );
                  }
                  return const NeonScaffold(
                    child: LoadingView(message: 'Loading profile'),
                  );
                },
              );
            }
            final requestedRole = AuthService.instance.requestedRole;
            if (requestedRole != null && requestedRole != profile.role) {
              return AccessStateScreen(
                title: 'Access denied',
                message:
                    'You selected ${_roleLabel(requestedRole)}, but this account is approved as ${_roleLabel(profile.role)}.',
                icon: Icons.lock_outline,
              );
            }
            if (profile.isRejected || !profile.isActive) {
              return const AccessStateScreen(
                title: 'Account rejected',
                message: 'This account is not approved for dashboard access.',
                icon: Icons.block_outlined,
              );
            }
            if (profile.isClubAdmin && profile.clubId == null) {
              return ClubOnboardingScreen(currentUser: profile);
            }
            if (profile.isClubAdmin && profile.isPending) {
              return AccessStateScreen(
                title: 'Pending approval',
                message:
                    '${_roleLabel(profile.role)} access is waiting for Super Admin approval.',
                icon: Icons.hourglass_top_outlined,
              );
            }
            switch (profile.role) {
              case 'superAdmin':
                return AdminDashboardScreen(currentUser: profile);
              case 'promoter':
                return PromoterDashboardScreen(currentUser: profile);
              case 'clubAdmin':
                return ClubAdminDashboardScreen(currentUser: profile);
              default:
                return UserShellScreen(currentUser: profile);
            }
          },
        );
      },
    );
  }
}

String _roleLabel(String role) {
  return switch (role) {
    'promoter' => 'Promoter',
    'clubAdmin' => 'Club Admin',
    'superAdmin' => 'Super Admin',
    _ => 'User',
  };
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../screens/club/club_admin_dashboard_screen.dart';
import '../../screens/promoter/promoter_dashboard_screen.dart';
import '../../screens/user/user_shell_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/state_views.dart';
import 'access_state_screen.dart';
import 'verification_details_screen.dart';
import 'waiting_for_approval_screen.dart';
import 'welcome_screen.dart';

class RoleRouterScreen extends StatelessWidget {
  const RoleRouterScreen({super.key});

  String _normalizeRole(String? role) {
    return (role ?? '').trim().toLowerCase().replaceAll('_', '');
  }

  bool _isClubAdminRole(String? role) {
    return _normalizeRole(role) == 'clubadmin';
  }

  bool _isPromoterRole(String? role) {
    return _normalizeRole(role) == 'promoter';
  }

  bool _isSameRole(String? selectedRole, String? profileRole) {
    return _normalizeRole(selectedRole) == _normalizeRole(profileRole);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const NeonScaffold(child: LoadingView());
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const WelcomeScreen();
        }

        return StreamBuilder<AppUser?>(
          stream: AuthService.instance.profileStream(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const NeonScaffold(
                child: LoadingView(message: 'Loading profile'),
              );
            }

            if (profileSnapshot.hasError) {
              return NeonScaffold(
                child: ErrorStateView(
                  message: profileSnapshot.error.toString(),
                ),
              );
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return FutureBuilder<AppUser>(
                future: AuthService.instance.ensureSafeProfile(firebaseUser),
                builder: (context, safeSnapshot) {
                  if (safeSnapshot.connectionState == ConnectionState.waiting) {
                    return const NeonScaffold(
                      child: LoadingView(message: 'Creating safe profile'),
                    );
                  }

                  if (safeSnapshot.hasError) {
                    return NeonScaffold(
                      child: ErrorStateView(
                        message: safeSnapshot.error.toString(),
                      ),
                    );
                  }

                  return const NeonScaffold(
                    child: LoadingView(message: 'Loading profile'),
                  );
                },
              );
            }

            final requestedRole = AuthService.instance.requestedRole;

            if (requestedRole != null &&
                !_isSameRole(requestedRole, profile.role)) {
              return AccessStateScreen(
                title: 'Access denied',
                message:
                    'You selected ${_roleLabel(requestedRole)}, but this account is approved as ${_roleLabel(profile.role)}.',
                icon: Icons.lock_outline,
              );
            }

            if (profile.isRejected || !profile.isActive) {
              return AccessStateScreen(
                title: 'Account rejected',
                message: profile.rejectionReason.isEmpty
                    ? 'This account is not approved for dashboard access.'
                    : profile.rejectionReason,
                icon: Icons.block_outlined,
              );
            }

            if (_isClubAdminRole(profile.role) &&
                !profile.onboardingCompleted) {
              return VerificationDetailsScreen(currentUser: profile);
            }

            if (_isClubAdminRole(profile.role) && !profile.isApproved) {
              return WaitingForApprovalScreen(currentUser: profile);
            }

            if (_isPromoterRole(profile.role)) {
              return PromoterDashboardScreen(currentUser: profile);
            }

            if (_isClubAdminRole(profile.role)) {
              return ClubAdminDashboardScreen(currentUser: profile);
            }

            return UserShellScreen(currentUser: profile);
          },
        );
      },
    );
  }
}

String _roleLabel(String? role) {
  final normalized = (role ?? '').trim().toLowerCase().replaceAll('_', '');

  return switch (normalized) {
    'promoter' => 'Promoter',
    'clubadmin' => 'Venue Admin',
    _ => 'User',
  };
}

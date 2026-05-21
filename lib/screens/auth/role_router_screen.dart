import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../screens/club/club_admin_dashboard_screen.dart';
import '../../screens/promoter/promoter_dashboard_screen.dart';
import '../../screens/super_admin/super_admin_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const NeonScaffold(child: LoadingView());
        }
        final user = authSnapshot.data;
        if (user == null) return const WelcomeScreen();
        return StreamBuilder<AppUser?>(
          stream: AuthService.instance.profileStream(user.uid),
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
                future: AuthService.instance.ensureSafeProfile(user),
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
            if (requestedRole != null && requestedRole != profile.role) {
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
            if ((profile.isPromoter || profile.isClubAdmin) &&
                !profile.onboardingCompleted) {
              return VerificationDetailsScreen(currentUser: profile);
            }
            if ((profile.isPromoter || profile.isClubAdmin) &&
                !profile.isApproved) {
              return WaitingForApprovalScreen(currentUser: profile);
            }
            switch (profile.role) {
              case 'superAdmin':
                if (!AuthService.instance.isSuperAdminUnlockArmed) {
                  return const AccessStateScreen(
                    title: 'Access denied',
                    message:
                        'Super Admin access requires an active secure unlock.',
                    icon: Icons.lock_outline,
                  );
                }
                return FutureBuilder<bool>(
                  future: AuthService.instance.verifyCurrentUserIsSuperAdmin(),
                  builder: (context, superAdminSnapshot) {
                    if (superAdminSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const NeonScaffold(
                        child: LoadingView(message: 'Verifying role'),
                      );
                    }
                    if (superAdminSnapshot.data != true) {
                      return const AccessStateScreen(
                        title: 'Access denied',
                        message: 'This account is not a Super Admin.',
                        icon: Icons.lock_outline,
                      );
                    }
                    return SuperAdminScreen(currentUser: profile);
                  },
                );
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

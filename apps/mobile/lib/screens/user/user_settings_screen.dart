import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/delete_account_dialogs.dart';
import '../../widgets/state_views.dart';
import 'change_password_screen.dart';

/// Real user Settings surface. Rendered inside the user shell's content area
/// (the shell supplies the NeonScaffold + top bar), so this is a plain
/// scrollable body rather than its own Scaffold.
class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  bool _updatingPush = false;
  bool _deleting = false;

  Future<void> _togglePush(bool enabled) async {
    if (_updatingPush) return;
    setState(() => _updatingPush = true);
    try {
      await FirestoreService.instance.setPushNotificationsEnabled(
        userId: widget.currentUser.uid,
        enabled: enabled,
      );
    } catch (error) {
      if (mounted) _snack(ErrorStateView.friendlyError(error));
    } finally {
      if (mounted) setState(() => _updatingPush = false);
    }
  }

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    var launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }
    if (!launched && mounted) _snack("Couldn't open the link");
  }

  Future<void> _changePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final password = await confirmAndRequestDeletePassword(context);
    if (password == null || !mounted) return;

    final navigator = Navigator.of(context);
    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteCurrentAccount(password: password);
      // Leave the settings surface, then sign out so RoleRouterScreen rebuilds
      // to WelcomeScreen with no stale screen on top.
      navigator.popUntil((route) => route.isFirst);
      try {
        await AuthService.instance.signOut();
      } catch (_) {
        // Auth user is already deleted; RoleRouterScreen rebuilds on its own.
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(ErrorStateView.friendlyError(error));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Reflect the persisted flag live so the toggle mirrors Firestore.
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.profileStream(widget.currentUser.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? widget.currentUser;
        final pushEnabled = profile.pushNotificationsEnabled;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Text(
              'Settings',
              style: AppTypography.displayMedium.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 28),

            // ── Notifications ──────────────────────────────────────────────
            const _GroupLabel('Notifications'),
            SwitchListTile(
              value: pushEnabled,
              onChanged: _updatingPush ? null : _togglePush,
              activeThumbColor: AppColors.obsidian,
              activeTrackColor: AppColors.champagne,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceEspresso,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Push notifications',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textHigh,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'New nights, RSVPs, and door reminders.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textCaption,
                  height: 1.25,
                ),
              ),
            ),
            const _RowHairline(),
            const SizedBox(height: 26),

            // ── Account ────────────────────────────────────────────────────
            const _GroupLabel('Account'),
            _SettingsTile(
              title: 'Change password',
              onTap: _changePassword,
            ),
            const _RowHairline(),
            _SettingsTile(
              title: 'Delete account',
              destructive: true,
              trailing: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.destructive,
                      ),
                    )
                  : null,
              onTap: _deleting ? null : _deleteAccount,
            ),
            const _RowHairline(),
            const SizedBox(height: 26),

            // ── Legal ──────────────────────────────────────────────────────
            const _GroupLabel('Legal'),
            _SettingsTile(
              title: 'Privacy Policy',
              trailingIcon: Icons.north_east,
              onTap: () => _openLegalUrl(AppConstants.privacyPolicyUrl),
            ),
            const _RowHairline(),
            _SettingsTile(
              title: 'Terms of Service',
              trailingIcon: Icons.north_east,
              onTap: () => _openLegalUrl(AppConstants.termsOfServiceUrl),
            ),
            const _RowHairline(),
            const SizedBox(height: 32),
            const _AboutFooter(),
          ],
        );
      },
    );
  }
}

// ─── Tracked uppercase group label ─────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          letterSpacing: 0.26 * 10,
          color: AppColors.textCaption,
        ),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.onTap,
    this.destructive = false,
    this.trailing,
    this.trailingIcon,
  });

  final String title;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.textBody;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(color: color),
      ),
      trailing:
          trailing ??
          Icon(
            trailingIcon ?? Icons.chevron_right,
            color: destructive ? AppColors.destructive : AppColors.textSecondary,
            size: trailingIcon == null ? 20 : 18,
          ),
      onTap: onTap,
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? ''
                : 'Version ${info.version} (${info.buildNumber})';
            return Text(
              version.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(fontSize: 10),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Made with ❤️ for nightlife',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textCaption,
          ),
        ),
      ],
    );
  }
}

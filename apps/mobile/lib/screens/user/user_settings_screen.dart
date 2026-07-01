import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _SettingsSection(
              title: 'NOTIFICATIONS',
              children: [
                SwitchListTile(
                  value: pushEnabled,
                  onChanged: _updatingPush ? null : _togglePush,
                  activeThumbColor: AppTheme.neonLime,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  secondary: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.accentPink,
                  ),
                  title: const Text(
                    'Push notifications',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Event reminders, RSVP confirmations, and drop alerts.',
                    style: TextStyle(color: AppTheme.textMuted, height: 1.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'LEGAL',
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _openLegalUrl(AppConstants.privacyPolicyUrl),
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => _openLegalUrl(AppConstants.termsOfServiceUrl),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'ACCOUNT',
              children: [
                _SettingsTile(
                  icon: Icons.password_outlined,
                  title: 'Change password',
                  onTap: _changePassword,
                ),
                const _SettingsDivider(),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Delete account',
                  destructive: true,
                  trailing: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _deleting ? null : _deleteAccount,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _AboutFooter(),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.neonLime,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 14,
      color: AppTheme.glassBorder.withValues(alpha: 0.75),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.error : AppTheme.accentPink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: destructive ? AppTheme.error : null,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
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
              version,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const Text(
          'Made with ❤️ for nightlife',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

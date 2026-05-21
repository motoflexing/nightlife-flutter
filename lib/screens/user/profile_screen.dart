import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/rsvp.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Rsvp>>(
      stream: FirestoreService.instance.userRsvpsStream(currentUser.uid),
      builder: (context, snapshot) {
        final rsvps = snapshot.data ?? [];
        final upcoming = rsvps
            .where((rsvp) => rsvp.status.toLowerCase() != 'cancelled')
            .length;
        final city = currentUser.lastKnownCity.trim().isEmpty
            ? 'City not set'
            : currentUser.lastKnownCity.trim();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _ProfileHero(
              currentUser: currentUser,
              city: city,
              upcoming: upcoming,
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Upcoming RSVPs',
              child: rsvps.isEmpty
                  ? const _EmptyPanel(
                      icon: Icons.confirmation_number_outlined,
                      text:
                          'Your RSVPs will appear here once you join a guestlist.',
                    )
                  : Column(
                      children: rsvps
                          .take(3)
                          .map((rsvp) => _RsvpTile(rsvp: rsvp))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            const _Section(
              title: 'Saved Events',
              child: _EmptyPanel(
                icon: Icons.favorite_border,
                text: 'Favorite clubs and events will live here.',
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Account',
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.security_outlined,
                    title: 'Privacy and settings',
                    onTap: () {},
                  ),
                  _ActionTile(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {},
                  ),
                  _ActionTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    destructive: true,
                    onTap: AuthService.instance.signOut,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.currentUser,
    required this.city,
    required this.upcoming,
  });

  final AppUser currentUser;
  final String city;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: AppTheme.neonPink.withValues(alpha: 0.18),
                child: Text(
                  _initials(currentUser.name),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name.isEmpty
                          ? 'Nightlife Member'
                          : currentUser.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: _roleLabel(currentUser.role)),
                        _Badge(
                          label: currentUser.isApproved
                              ? 'Verified'
                              : currentUser.status,
                          highlighted: currentUser.isApproved,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoTile(icon: Icons.location_on_outlined, label: city),
          _InfoTile(icon: Icons.mail_outline, label: currentUser.email),
          if (currentUser.phone.trim().isNotEmpty)
            _InfoTile(icon: Icons.call_outlined, label: currentUser.phone),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Upcoming', value: upcoming.toString()),
              const _Stat(label: 'Saved', value: '0'),
              const _Stat(label: 'Attended', value: '0'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Settings',
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  String _roleLabel(String role) {
    return switch (role) {
      'promoter' => 'Promoter',
      'clubAdmin' => 'Venue',
      'superAdmin' => 'Admin',
      _ => 'Member',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.neonLime.withValues(alpha: 0.14)
            : AppTheme.primaryViolet.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? AppTheme.neonLime.withValues(alpha: 0.36)
              : AppTheme.accentPink.withValues(alpha: 0.34),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpTile extends StatelessWidget {
  const _RsvpTile({required this.rsvp});

  final Rsvp rsvp;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: AppTheme.elevated,
        child: Icon(Icons.local_activity_outlined, color: AppTheme.accentPink),
      ),
      title: Text(
        rsvp.eventTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        rsvp.status,
        style: const TextStyle(color: AppTheme.textMuted),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentPink),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.accentPink : Colors.white;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      trailing: destructive ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

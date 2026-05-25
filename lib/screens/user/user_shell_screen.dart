import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'my_rsvps_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class UserShellScreen extends StatefulWidget {
  const UserShellScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends State<UserShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.profileStream(widget.currentUser.uid),
      builder: (context, snapshot) {
        final currentUser = snapshot.data ?? widget.currentUser;

        final pages = [
          HomeScreen(currentUser: currentUser),
          ExploreScreen(currentUser: currentUser),
          SearchScreen(currentUser: currentUser),
          MyRsvpsScreen(currentUser: currentUser),
          FavoritesScreen(onExplore: () => setState(() => _index = 1)),
          ProfileScreen(currentUser: currentUser),
          const _PlaceholderScreen(
            icon: Icons.settings_outlined,
            title: 'Settings',
            message:
                'Fine-tune notifications, discovery, privacy, and account preferences.',
          ),
          const _PlaceholderScreen(
            icon: Icons.support_agent_outlined,
            title: 'Help & Support',
            message:
                'Get fast answers, contact support, and report event issues.',
          ),
        ];

        return NeonScaffold(
          appBar: AppBar(
            title: Text(_titleFor(_index)),
            leading: Builder(
              builder: (context) => IconButton.filledTonal(
                tooltip: 'Open menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Profile',
                onPressed: () => setState(() => _index = 5),
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
          drawer: MenuScreen(
            currentUser: currentUser,
            selectedIndex: _index,
            onSelect: (value) => setState(() => _index = value),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
          ),
        );
      },
    );
  }

  String _titleFor(int index) {
    return switch (index) {
      1 => 'Explore Events',
      2 => 'Search',
      3 => 'My RSVPs',
      4 => 'Favorites',
      5 => 'Profile',
      6 => 'Settings',
      7 => 'Help & Support',
      _ => 'Nightlife',
    };
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isSettings = title == 'Settings';
    final sections = isSettings ? _settingsSections : _supportSections;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.glassSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonViolet.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < sections.length; i++) ...[
          _PreferenceSection(section: sections[i], delayMs: 80 + (i * 45)),
          if (i != sections.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({required this.section, required this.delayMs});

  final _PreferenceGroup section;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
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
                section.title,
                style: const TextStyle(
                  color: AppTheme.neonLime,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (var i = 0; i < section.items.length; i++) ...[
              _InteractiveListTile(item: section.items[i]),
              if (i != section.items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 14,
                  color: AppTheme.glassBorder.withValues(alpha: 0.75),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InteractiveListTile extends StatefulWidget {
  const _InteractiveListTile({required this.item});

  final _PreferenceItem item;

  @override
  State<_InteractiveListTile> createState() => _InteractiveListTileState();
}

class _InteractiveListTileState extends State<_InteractiveListTile> {
  bool _pressed = false;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        onTap: item.trailing == _TileTrailing.toggle
            ? () => setState(() => _enabled = !_enabled)
            : () {},
        child: ListTile(
          minLeadingWidth: 28,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: Icon(item.icon, color: AppTheme.accentPink),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, height: 1.25),
          ),
          trailing: _trailing(item),
        ),
      ),
    );
  }

  Widget _trailing(_PreferenceItem item) {
    return switch (item.trailing) {
      _TileTrailing.toggle => Switch(
        value: _enabled,
        activeThumbColor: AppTheme.neonLime,
        onChanged: (value) => setState(() => _enabled = value),
      ),
      _TileTrailing.badge => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryViolet.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppTheme.accentPink.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          item.badge ?? 'New',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
      _TileTrailing.chevron => const Icon(Icons.chevron_right),
    };
  }
}

enum _TileTrailing { chevron, toggle, badge }

class _PreferenceGroup {
  const _PreferenceGroup({required this.title, required this.items});

  final String title;
  final List<_PreferenceItem> items;
}

class _PreferenceItem {
  const _PreferenceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing = _TileTrailing.chevron,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _TileTrailing trailing;
  final String? badge;
}

const _settingsSections = [
  _PreferenceGroup(
    title: 'DISCOVERY',
    items: [
      _PreferenceItem(
        icon: Icons.location_on_outlined,
        title: 'Location-aware feed',
        subtitle: 'Prioritize nearby events and same-city nightlife drops.',
        trailing: _TileTrailing.toggle,
      ),
      _PreferenceItem(
        icon: Icons.music_note_outlined,
        title: 'Music preferences',
        subtitle: 'Tune discovery for techno, Bollywood, hip-hop, live music.',
      ),
    ],
  ),
  _PreferenceGroup(
    title: 'NOTIFICATIONS',
    items: [
      _PreferenceItem(
        icon: Icons.notifications_active_outlined,
        title: 'Event reminders',
        subtitle: 'Get nudges before RSVP cutoffs and entry windows.',
        trailing: _TileTrailing.toggle,
      ),
      _PreferenceItem(
        icon: Icons.local_fire_department_outlined,
        title: 'Drop alerts',
        subtitle: 'Notify me when premium clubs publish new nights.',
        trailing: _TileTrailing.toggle,
      ),
    ],
  ),
  _PreferenceGroup(
    title: 'ACCOUNT',
    items: [
      _PreferenceItem(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy controls',
        subtitle: 'Manage profile visibility and contact preferences.',
      ),
      _PreferenceItem(
        icon: Icons.lock_outline,
        title: 'Security',
        subtitle: 'Review login sessions and authentication settings.',
      ),
    ],
  ),
];

const _supportSections = [
  _PreferenceGroup(
    title: 'GET HELP',
    items: [
      _PreferenceItem(
        icon: Icons.chat_bubble_outline,
        title: 'Contact support',
        subtitle: 'Reach the nightlife support team for account or RSVP help.',
        trailing: _TileTrailing.badge,
        badge: '24h',
      ),
      _PreferenceItem(
        icon: Icons.quiz_outlined,
        title: 'FAQs',
        subtitle: 'Answers about RSVPs, guestlists, payments, and entry rules.',
      ),
    ],
  ),
  _PreferenceGroup(
    title: 'EVENT ISSUES',
    items: [
      _PreferenceItem(
        icon: Icons.report_gmailerrorred_outlined,
        title: 'Report an event',
        subtitle: 'Flag inaccurate venue, timing, pricing, or entry details.',
      ),
      _PreferenceItem(
        icon: Icons.confirmation_number_outlined,
        title: 'RSVP problem',
        subtitle: 'Get help with pending, duplicate, or missing RSVPs.',
      ),
    ],
  ),
  _PreferenceGroup(
    title: 'LEARN',
    items: [
      _PreferenceItem(
        icon: Icons.verified_user_outlined,
        title: 'Safety guidelines',
        subtitle: 'Tips for safer nights, venue checks, and verified listings.',
      ),
      _PreferenceItem(
        icon: Icons.campaign_outlined,
        title: 'Promoter support',
        subtitle: 'Learn how referral tracking and boosted discovery work.',
      ),
    ],
  ),
];

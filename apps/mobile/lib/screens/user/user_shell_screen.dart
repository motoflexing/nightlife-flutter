import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/user_app_chrome.dart';
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
  late final PageController _topPanelController;
  int _index = 0;
  bool _isAnimatingToTopPanel = false;

  @override
  void initState() {
    super.initState();
    _topPanelController = PageController();
  }

  @override
  void dispose() {
    _topPanelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.profileStream(widget.currentUser.uid),
      builder: (context, snapshot) {
        final currentUser = snapshot.data ?? widget.currentUser;
        final panels = _buildPanelConfigs(currentUser);
        final selectedPanel = panels[_index];
        final topPanels = _primaryPanelConfigs(panels);
        final topTabs = topPanels
            .map((panel) => panel.navTab)
            .toList(growable: false);
        final topPanelIndex = _topPanelIndexForShellIndex(panels, _index);

        return NeonScaffold(
          appBar: UserShellTopBar(
            currentUser: currentUser,
            tabs: topTabs,
            selectedTabId: selectedPanel.showInTopNav ? selectedPanel.id : null,
            onSelectTab: (tab) => _selectPage(
              _shellIndexForTabId(panels, tab.id),
              swipeAware: true,
            ),
            onSearchTap: () => _selectPage(2),
          ),
          bottomNavigationBar: PremiumBottomNav(
            tabs: topTabs,
            selectedTabId: selectedPanel.showInTopNav ? selectedPanel.id : null,
            onSelectTab: (tab) => _selectPage(
              _shellIndexForTabId(panels, tab.id),
              swipeAware: true,
            ),
          ),
          drawer: MenuScreen(
            currentUser: currentUser,
            selectedIndex: _index,
            onSelect: _selectPage,
          ),
          child: topPanelIndex == null
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: selectedPanel.builder(currentUser),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final topPanels = _primaryPanelConfigs(panels);
                    final swipeEnabled = constraints.maxWidth < 700;
                    _syncTopPanelController(topPanelIndex);

                    return PageView.builder(
                      key: const PageStorageKey('user-main-top-panels'),
                      controller: _topPanelController,
                      allowImplicitScrolling: true,
                      clipBehavior: Clip.hardEdge,
                      dragStartBehavior: DragStartBehavior.down,
                      pageSnapping: true,
                      physics: swipeEnabled
                          ? const _PremiumPanelSwipePhysics()
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: (pageIndex) {
                        final shellIndex = topPanels[pageIndex].shellIndex;
                        if (_index == shellIndex) return;
                        HapticFeedback.selectionClick();
                        setState(() => _index = shellIndex);
                      },
                      itemCount: topPanels.length,
                      itemBuilder: (context, pageIndex) {
                        final panel = topPanels[pageIndex];
                        return KeyedSubtree(
                          key: ValueKey(panel.id),
                          child: panel.builder(currentUser),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  List<_ShellPanelConfig> _buildPanelConfigs(AppUser currentUser) {
    return [
      _ShellPanelConfig(
        id: 'home',
        label: 'Home',
        route: '/home',
        shellIndex: 0,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        enabled: true,
        showInTopNav: true,
        builder: (_) => HomeScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'explore',
        label: 'Explore',
        route: '/explore',
        shellIndex: 1,
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        enabled: true,
        showInTopNav: true,
        builder: (_) => ExploreScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'search',
        label: 'Search',
        route: '/search',
        shellIndex: 2,
        icon: Icons.search,
        selectedIcon: Icons.search,
        enabled: true,
        showInTopNav: false,
        builder: (_) => SearchScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'rsvp',
        label: 'RSVP',
        route: '/rsvps',
        shellIndex: 3,
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number,
        enabled: true,
        showInTopNav: true,
        builder: (_) => MyRsvpsScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'favorites',
        label: 'Favorites',
        route: '/favorites',
        shellIndex: 4,
        icon: Icons.favorite_border,
        selectedIcon: Icons.favorite,
        enabled: true,
        builder: (_) => FavoritesScreen(onExplore: () => _selectPage(1)),
      ),
      _ShellPanelConfig(
        id: 'profile',
        label: 'Profile',
        route: '/profile',
        shellIndex: 5,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        enabled: true,
        showInTopNav: true,
        builder: (_) => ProfileScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'settings',
        label: 'Settings',
        route: '/settings',
        shellIndex: 6,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        enabled: true,
        builder: (_) => const _PlaceholderScreen(
          icon: Icons.settings_outlined,
          title: 'Settings',
          message:
              'Fine-tune notifications, discovery, privacy, and account preferences.',
        ),
      ),
      _ShellPanelConfig(
        id: 'help',
        label: 'Help',
        route: '/help',
        shellIndex: 7,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        enabled: true,
        builder: (_) => const _PlaceholderScreen(
          icon: Icons.support_agent_outlined,
          title: 'Help & Support',
          message:
              'Get fast answers, contact support, and report event issues.',
        ),
      ),
    ];
  }

  void _selectPage(int index, {bool swipeAware = false}) {
    if (_index == index) return;
    setState(() => _index = index);
    if (swipeAware) _animateTopPanelToShellIndex(index);
  }

  int _shellIndexForTabId(List<_ShellPanelConfig> panels, String tabId) {
    return panels.firstWhere((panel) => panel.id == tabId).shellIndex;
  }

  List<_ShellPanelConfig> _primaryPanelConfigs(List<_ShellPanelConfig> panels) {
    const order = ['home', 'explore', 'rsvp', 'profile'];
    return order
        .map(
          (id) => panels.firstWhere((panel) => panel.id == id && panel.enabled),
        )
        .toList(growable: false);
  }

  int? _topPanelIndexForShellIndex(
    List<_ShellPanelConfig> panels,
    int shellIndex,
  ) {
    final topPanels = _primaryPanelConfigs(panels);
    for (var i = 0; i < topPanels.length; i++) {
      if (topPanels[i].shellIndex == shellIndex) return i;
    }
    return null;
  }

  void _animateTopPanelToShellIndex(int shellIndex) {
    final panels = _buildPanelConfigs(widget.currentUser);
    final topPanelIndex = _topPanelIndexForShellIndex(panels, shellIndex);
    if (topPanelIndex == null) return;
    _isAnimatingToTopPanel = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_topPanelController.hasClients) {
        _isAnimatingToTopPanel = false;
        return;
      }
      _topPanelController
          .animateToPage(
            topPanelIndex,
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
          )
          .whenComplete(() {
            _isAnimatingToTopPanel = false;
          });
    });
  }

  void _syncTopPanelController(int pageIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_topPanelController.hasClients) return;
      if (_isAnimatingToTopPanel) return;
      final currentPage = _topPanelController.page?.round();
      if (currentPage == pageIndex) return;
      _topPanelController.jumpToPage(pageIndex);
    });
  }
}

class _ShellPanelConfig {
  const _ShellPanelConfig({
    required this.id,
    required this.label,
    required this.route,
    required this.shellIndex,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.enabled = true,
    this.showInTopNav = false,
  });

  final String id;
  final String label;
  final String route;
  final int shellIndex;
  final IconData icon;
  final IconData selectedIcon;
  final bool enabled;
  final bool showInTopNav;
  final Widget Function(AppUser currentUser) builder;

  UserNavTabConfig get navTab {
    return UserNavTabConfig(
      id: id,
      label: label,
      icon: icon,
      selectedIcon: selectedIcon,
      route: route,
      enabled: enabled,
    );
  }
}

class _PremiumPanelSwipePhysics extends PageScrollPhysics {
  const _PremiumPanelSwipePhysics({super.parent});

  @override
  _PremiumPanelSwipePhysics applyTo(ScrollPhysics? ancestor) {
    return _PremiumPanelSwipePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring {
    return SpringDescription.withDampingRatio(
      mass: 0.72,
      stiffness: 420,
      ratio: 1.08,
    );
  }

  @override
  double get minFlingDistance => 36;

  @override
  double get minFlingVelocity => 420;

  @override
  double get maxFlingVelocity => 5200;

  @override
  double? get dragStartDistanceMotionThreshold => 10;

  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign *
        (0.00042 * existingVelocity.abs()).clamp(0.0, 2600.0);
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
  bool _hovered = false;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.accentPink.withValues(alpha: 0.10)
              : _hovered
              ? Colors.white.withValues(alpha: 0.045)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.white.withValues(alpha: 0.04),
          focusColor: AppTheme.neonViolet.withValues(alpha: 0.10),
          splashColor: AppTheme.accentPink.withValues(alpha: 0.12),
          highlightColor: AppTheme.accentPink.withValues(alpha: 0.08),
          onHover: (value) => setState(() => _hovered = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: item.trailing == _TileTrailing.toggle
              ? () => setState(() => _enabled = !_enabled)
              : () => _openPreferenceAction(context, item),
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

enum _PreferenceAction {
  music,
  privacy,
  security,
  contactSupport,
  faqs,
  reportEvent,
  rsvpProblem,
  safetyGuidelines,
  promoterSupport,
}

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
    this.action,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _TileTrailing trailing;
  final _PreferenceAction? action;
  final String? badge;
}

void _openPreferenceAction(BuildContext context, _PreferenceItem item) {
  switch (item.action) {
    case _PreferenceAction.music:
      _showMusicPreferencesSheet(context);
    case _PreferenceAction.privacy:
      _showPrivacyControlsSheet(context);
    case _PreferenceAction.security:
      _showSecuritySheet(context);
    case _PreferenceAction.contactSupport:
      _showContactSupportSheet(context);
    case _PreferenceAction.faqs:
      _showFaqSheet(context);
    case _PreferenceAction.reportEvent:
      _showReportEventSheet(context);
    case _PreferenceAction.rsvpProblem:
      _showRsvpProblemSheet(context);
    case _PreferenceAction.safetyGuidelines:
      _showSafetyGuidelinesSheet(context);
    case _PreferenceAction.promoterSupport:
      _showPromoterSupportSheet(context);
    case null:
      _showAccountInfoSheet(context, item);
  }
}

void _showMusicPreferencesSheet(BuildContext context) {
  const genres = [
    'Bollywood',
    'Hip-hop',
    'Techno',
    'House',
    'Live music',
    'EDM',
    'Afrobeats',
    'Pop',
    'Rock',
    'Sufi',
  ];
  final selected = <String>{'Bollywood', 'Hip-hop', 'Techno'};

  _showSettingsSheet(
    context: context,
    icon: Icons.music_note_outlined,
    title: 'Music preferences',
    subtitle: 'Choose the sounds that should shape your event discovery.',
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetSectionLabel('Favorite genres'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in genres)
                  FilterChip(
                    label: Text(genre),
                    selected: selected.contains(genre),
                    checkmarkColor: Colors.white,
                    selectedColor: AppTheme.primaryViolet.withValues(
                      alpha: 0.34,
                    ),
                    side: BorderSide(
                      color: selected.contains(genre)
                          ? AppTheme.accentPink
                          : AppTheme.glassBorder,
                    ),
                    onSelected: (value) {
                      setSheetState(() {
                        if (value) {
                          selected.add(genre);
                        } else {
                          selected.remove(genre);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _SheetSwitchRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Use genres for recommendations',
              subtitle: 'Prioritize events that match your selected genres.',
              initialValue: true,
            ),
            const SizedBox(height: 16),
            _SheetActions(
              primaryLabel: 'Save preferences',
              onPrimary: () => _saveSheet(context, 'Music preferences saved.'),
              secondaryLabel: 'Reset',
              onSecondary: () => setSheetState(() {
                selected
                  ..clear()
                  ..addAll({'Bollywood', 'Hip-hop', 'Techno'});
              }),
            ),
          ],
        ),
      );
    },
  );
}

void _showPrivacyControlsSheet(BuildContext context) {
  var visibility = 'Friends';
  var contact = 'In-app only';

  _showSettingsSheet(
    context: context,
    icon: Icons.privacy_tip_outlined,
    title: 'Privacy controls',
    subtitle: 'Control who can find you and how venues may contact you.',
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetSectionLabel('Profile visibility'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Public', label: Text('Public')),
                ButtonSegment(value: 'Friends', label: Text('Friends')),
                ButtonSegment(value: 'Private', label: Text('Private')),
              ],
              selected: {visibility},
              onSelectionChanged: (value) {
                setSheetState(() => visibility = value.first);
              },
            ),
            const SizedBox(height: 16),
            const _SheetSectionLabel('Contact preference'),
            DropdownButtonFormField<String>(
              initialValue: contact,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.contact_mail_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'In-app only',
                  child: Text('In-app only'),
                ),
                DropdownMenuItem(
                  value: 'Email allowed',
                  child: Text('Email allowed'),
                ),
                DropdownMenuItem(
                  value: 'Phone allowed',
                  child: Text('Phone allowed'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setSheetState(() => contact = value);
              },
            ),
            const SizedBox(height: 14),
            _SheetSwitchRow(
              icon: Icons.visibility_off_outlined,
              title: 'Hide RSVP activity',
              subtitle: 'Keep your RSVPs private from other users.',
              initialValue: true,
            ),
            _SheetSwitchRow(
              icon: Icons.location_off_outlined,
              title: 'Approximate location only',
              subtitle: 'Use city-level matching instead of precise location.',
              initialValue: false,
            ),
            const SizedBox(height: 16),
            _SheetActions(
              primaryLabel: 'Save controls',
              onPrimary: () => _saveSheet(context, 'Privacy controls saved.'),
            ),
          ],
        ),
      );
    },
  );
}

void _showSecuritySheet(BuildContext context) {
  _showSettingsSheet(
    context: context,
    icon: Icons.lock_outline,
    title: 'Security',
    subtitle: 'Review sessions, password access, and authentication safety.',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionLabel('Account protection'),
        const _SecurityActionRow(
          icon: Icons.password_outlined,
          title: 'Change password',
          subtitle: 'Send a secure password reset link to your email.',
        ),
        const SizedBox(height: 10),
        _SheetSwitchRow(
          icon: Icons.notifications_outlined,
          title: 'Security alerts',
          subtitle: 'Notify me about new logins or password changes.',
          initialValue: true,
        ),
        const SizedBox(height: 16),
        _SheetActions(
          primaryLabel: 'Done',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

void _showContactSupportSheet(BuildContext context) {
  const supportEmail = 'support@nightlife.app';

  _showSettingsSheet(
    context: context,
    icon: Icons.chat_bubble_outline,
    title: 'Contact support',
    subtitle: 'Reach the nightlife support team for account or RSVP help.',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionLabel('Support desk'),
        const _SupportInfoCard(
          icon: Icons.mail_outline,
          title: supportEmail,
          subtitle: 'Best for account, RSVP, guestlist, and event issues.',
        ),
        const SizedBox(height: 10),
        const _SupportInfoCard(
          icon: Icons.schedule_outlined,
          title: 'Response time',
          subtitle: 'Most requests receive a reply within 24 hours.',
        ),
        const SizedBox(height: 16),
        _SheetActions(
          primaryLabel: 'Copy Email',
          onPrimary: () async {
            await Clipboard.setData(const ClipboardData(text: supportEmail));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Support email copied.')),
            );
          },
          secondaryLabel: 'Done',
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

void _showFaqSheet(BuildContext context) {
  const faqs = [
    _FaqItem(
      question: 'My RSVP is missing. What should I do?',
      answer:
          'Check My RSVPs first, then search by the event name. If it still does not appear, send support your registered email and the event name.',
    ),
    _FaqItem(
      question: 'Can event timings change?',
      answer:
          'Yes. Venues can update doors-open, last-entry, or artist timings. The event detail page should show the latest available timing before you travel.',
    ),
    _FaqItem(
      question: 'How do payments work?',
      answer:
          'Most listed payments are handled by the venue or event partner. Always confirm the price, inclusions, and payment method on the event page before entry.',
    ),
    _FaqItem(
      question: 'What happens if an event is cancelled?',
      answer:
          'Cancelled or inactive events may disappear from discovery. If you already RSVP’d, contact support with the event name so the team can verify the update.',
    ),
    _FaqItem(
      question: 'How do guestlists work?',
      answer:
          'A guestlist RSVP helps venues identify you at entry, but final admission can still depend on age checks, capacity, dress code, and venue policy.',
    ),
    _FaqItem(
      question: 'Where can I see entry rules?',
      answer:
          'Open the event detail page and review entry notes, price, venue, and timing before you leave. Respect venue rules and carry valid ID when required.',
    ),
  ];

  _showSettingsSheet(
    context: context,
    icon: Icons.quiz_outlined,
    title: 'FAQs',
    subtitle: 'Answers about RSVPs, guestlists, payments, and entry rules.',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final faq in faqs) ...[
          _FaqTile(faq: faq),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}

void _showReportEventSheet(BuildContext context) {
  _showSettingsSheet(
    context: context,
    icon: Icons.report_gmailerrorred_outlined,
    title: 'Report an event',
    subtitle: 'Flag inaccurate venue, timing, pricing, or entry details.',
    builder: (context) => const _ReportEventForm(),
  );
}

void _showRsvpProblemSheet(BuildContext context) {
  _showSettingsSheet(
    context: context,
    icon: Icons.confirmation_number_outlined,
    title: 'RSVP problem',
    subtitle: 'Get help with pending, duplicate, or missing RSVPs.',
    builder: (context) => const _RsvpProblemForm(),
  );
}

void _showSafetyGuidelinesSheet(BuildContext context) {
  _showSettingsSheet(
    context: context,
    icon: Icons.verified_user_outlined,
    title: 'Safety guidelines',
    subtitle: 'Tips for safer nights, venue checks, and verified listings.',
    builder: (context) => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetSectionLabel('Before you go'),
        _GuidelineTile(
          icon: Icons.verified_outlined,
          title: 'Choose verified venues',
          subtitle:
              'Prefer events with clear venue, timing, pricing, and entry details.',
        ),
        _GuidelineTile(
          icon: Icons.local_taxi_outlined,
          title: 'Plan safe transportation',
          subtitle:
              'Keep your ride home planned before late-night entry windows.',
        ),
        _GuidelineTile(
          icon: Icons.shield_outlined,
          title: 'Avoid scams',
          subtitle:
              'Do not transfer money to unknown contacts outside trusted venue channels.',
        ),
        _GuidelineTile(
          icon: Icons.contact_emergency_outlined,
          title: 'Know emergency contacts',
          subtitle:
              'Keep local emergency numbers and a trusted contact easy to reach.',
        ),
        _GuidelineTile(
          icon: Icons.rule_outlined,
          title: 'Respect venue rules',
          subtitle:
              'Carry valid ID, follow age policies, and respect staff instructions.',
        ),
      ],
    ),
  );
}

void _showPromoterSupportSheet(BuildContext context) {
  _showSettingsSheet(
    context: context,
    icon: Icons.campaign_outlined,
    title: 'Promoter support',
    subtitle: 'Referral help, onboarding guidance, and payout support.',
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetSectionLabel('Promoter help'),
        const _SupportInfoCard(
          icon: Icons.link_outlined,
          title: 'Referral tracking',
          subtitle:
              'Use your referral code or event link consistently so RSVPs can be attributed correctly.',
        ),
        const SizedBox(height: 10),
        const _SupportInfoCard(
          icon: Icons.payments_outlined,
          title: 'Payout support',
          subtitle:
              'Payout workflows are handled by the admin team and will be surfaced here when enabled.',
          badge: 'Soon',
        ),
        const SizedBox(height: 10),
        const _SupportInfoCard(
          icon: Icons.rocket_launch_outlined,
          title: 'Promoter onboarding',
          subtitle:
              'New promoters should confirm profile approval, venue access, and referral setup before campaigns.',
        ),
        const SizedBox(height: 16),
        _SupportContactPanel(
          onCopy: () async {
            const email = 'promoters@nightlife.app';
            await Clipboard.setData(const ClipboardData(text: email));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Promoter support email copied.')),
            );
          },
        ),
      ],
    ),
  );
}

void _showAccountInfoSheet(BuildContext context, _PreferenceItem item) {
  _showSettingsSheet(
    context: context,
    icon: item.icon,
    title: item.title,
    subtitle: item.subtitle,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryViolet.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: const Text(
            'To reset your password, use "Forgot password?" on the sign-in screen. For anything else about your account, reach the team from Help & Support.',
            style: TextStyle(color: AppTheme.textMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 16),
        _SheetActions(
          primaryLabel: 'Got it',
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

void _showSettingsSheet({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required WidgetBuilder builder,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.42),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
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
                                subtitle,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    builder(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _saveSheet(BuildContext context, String message) {
  Navigator.of(context).pop();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.neonLime,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SheetSwitchRow extends StatefulWidget {
  const _SheetSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.initialValue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool initialValue;

  @override
  State<_SheetSwitchRow> createState() => _SheetSwitchRowState();
}

class _SheetSwitchRowState extends State<_SheetSwitchRow> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(widget.icon, color: AppTheme.accentPink),
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        widget.subtitle,
        style: const TextStyle(color: AppTheme.textMuted, height: 1.25),
      ),
      trailing: Switch(
        value: _enabled,
        activeThumbColor: AppTheme.neonLime,
        onChanged: (value) => setState(() => _enabled = value),
      ),
      onTap: () => setState(() => _enabled = !_enabled),
    );
  }
}

class _SecurityActionRow extends StatelessWidget {
  const _SecurityActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.accentPink),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textMuted, height: 1.25),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showAccountInfoSheet(
        context,
        _PreferenceItem(icon: icon, title: title, subtitle: subtitle),
      ),
    );
  }
}

class _SupportInfoCard extends StatelessWidget {
  const _SupportInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentPink),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryViolet.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.accentPink.withValues(alpha: 0.34),
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _FaqItem faq;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.elevated.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: AppTheme.accentPink,
          collapsedIconColor: AppTheme.textMuted,
          title: Text(
            faq.question,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineTile extends StatelessWidget {
  const _GuidelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _SupportInfoCard(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _SupportContactPanel extends StatelessWidget {
  const _SupportContactPanel({required this.onCopy});

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryViolet.withValues(alpha: 0.28),
            AppTheme.accentPink.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Promoter contact',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'promoters@nightlife.app',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('Copy promoter email'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportEventForm extends StatefulWidget {
  const _ReportEventForm();

  @override
  State<_ReportEventForm> createState() => _ReportEventFormState();
}

class _ReportEventFormState extends State<_ReportEventForm> {
  final _formKey = GlobalKey<FormState>();
  final _eventController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _issueType = 'Wrong event details';
  bool _submitted = false;

  @override
  void dispose() {
    _eventController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_submitted) ...[
            const _SupportSuccessCard(
              title: 'Report received',
              subtitle:
                  'Thanks. The event team will review the report and update the listing if needed.',
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            initialValue: _issueType,
            decoration: const InputDecoration(
              labelText: 'Issue type',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Wrong event details',
                child: Text('Wrong event details'),
              ),
              DropdownMenuItem(
                value: 'Incorrect venue or location',
                child: Text('Incorrect venue or location'),
              ),
              DropdownMenuItem(
                value: 'Pricing or payment issue',
                child: Text('Pricing or payment issue'),
              ),
              DropdownMenuItem(
                value: 'Entry rules unclear',
                child: Text('Entry rules unclear'),
              ),
              DropdownMenuItem(
                value: 'Event appears inactive',
                child: Text('Event appears inactive'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _issueType = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _eventController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Event name',
              prefixIcon: Icon(Icons.nightlife_outlined),
            ),
            validator: _requiredValidator('Enter the event name.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            validator: _requiredValidator('Describe what looks incorrect.'),
          ),
          const SizedBox(height: 16),
          _SheetActions(
            primaryLabel: 'Submit report',
            onPrimary: _submit,
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _submitted = false);
      return;
    }
    setState(() => _submitted = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Report submitted: $_issueType.')));
  }
}

class _RsvpProblemForm extends StatefulWidget {
  const _RsvpProblemForm();

  @override
  State<_RsvpProblemForm> createState() => _RsvpProblemFormState();
}

class _RsvpProblemFormState extends State<_RsvpProblemForm> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_submitted) ...[
            const _SupportSuccessCard(
              title: 'RSVP help request created',
              subtitle:
                  'Support will use your RSVP ID or event name to check the issue.',
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _referenceController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'RSVP ID or Event Name',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            validator: _requiredValidator('Enter an RSVP ID or event name.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Issue description',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.support_agent_outlined),
            ),
            validator: _requiredValidator('Tell us what went wrong.'),
          ),
          const SizedBox(height: 16),
          _SheetActions(
            primaryLabel: 'Submit request',
            onPrimary: _submit,
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() => _submitted = false);
      return;
    }
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('RSVP support request submitted.')),
    );
  }
}

class _SupportSuccessCard extends StatelessWidget {
  const _SupportSuccessCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.neonLime.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.neonLime.withValues(alpha: 0.36)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.neonLime),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

FormFieldValidator<String> _requiredValidator(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = this.secondaryLabel;
    return Row(
      children: [
        if (secondaryLabel != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
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
        action: _PreferenceAction.music,
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
        action: _PreferenceAction.privacy,
      ),
      _PreferenceItem(
        icon: Icons.lock_outline,
        title: 'Security',
        subtitle: 'Review login sessions and authentication settings.',
        action: _PreferenceAction.security,
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
        action: _PreferenceAction.contactSupport,
        badge: '24h',
      ),
      _PreferenceItem(
        icon: Icons.quiz_outlined,
        title: 'FAQs',
        subtitle: 'Answers about RSVPs, guestlists, payments, and entry rules.',
        action: _PreferenceAction.faqs,
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
        action: _PreferenceAction.reportEvent,
      ),
      _PreferenceItem(
        icon: Icons.confirmation_number_outlined,
        title: 'RSVP problem',
        subtitle: 'Get help with pending, duplicate, or missing RSVPs.',
        action: _PreferenceAction.rsvpProblem,
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
        action: _PreferenceAction.safetyGuidelines,
      ),
      _PreferenceItem(
        icon: Icons.campaign_outlined,
        title: 'Promoter support',
        subtitle: 'Learn how referral tracking and boosted discovery work.',
        action: _PreferenceAction.promoterSupport,
      ),
    ],
  ),
];

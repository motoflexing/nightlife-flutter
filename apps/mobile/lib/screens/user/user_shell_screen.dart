import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/user_app_chrome.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'help_support_screen.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
import 'my_rsvps_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'user_settings_screen.dart';

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
        builder: (_) => FavoritesScreen(
          currentUser: currentUser,
          onExplore: () => _selectPage(1),
        ),
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
        builder: (_) => UserSettingsScreen(currentUser: currentUser),
      ),
      _ShellPanelConfig(
        id: 'help',
        label: 'Help',
        route: '/help',
        shellIndex: 7,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        enabled: true,
        builder: (_) => const HelpSupportScreen(),
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

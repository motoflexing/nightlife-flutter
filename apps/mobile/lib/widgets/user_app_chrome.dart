import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/app_user.dart';

class UserShellTopBar extends StatelessWidget implements PreferredSizeWidget {
  const UserShellTopBar({
    super.key,
    required this.currentUser,
    required this.tabs,
    required this.selectedTabId,
    required this.onSelectTab,
    required this.onSearchTap,
  });

  final AppUser currentUser;
  final List<UserNavTabConfig> tabs;
  final String? selectedTabId;
  final ValueChanged<UserNavTabConfig> onSelectTab;
  final VoidCallback onSearchTap;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 58,
      titleSpacing: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const _ChromeBackdrop(),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            Builder(
              builder: (context) => _ChromeIconButton(
                tooltip: 'Open menu',
                icon: Icons.menu,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              // App name stays "Nightlife", set in the Playfair display voice.
              child: Text(
                'Nightlife',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineMedium.copyWith(fontSize: 20),
              ),
            ),
            _ChromeIconButton(
              tooltip: 'Search',
              icon: Icons.search,
              onPressed: onSearchTap,
            ),
            const SizedBox(width: 8),
            _TopAvatar(
              currentUser: currentUser,
              selected: selectedTabId == 'profile',
              onPressed: () {
                final profileTab = tabs.where((tab) => tab.id == 'profile');
                if (profileTab.isNotEmpty) onSelectTab(profileTab.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBottomNav extends StatelessWidget {
  const PremiumBottomNav({
    super.key,
    required this.tabs,
    required this.selectedTabId,
    required this.onSelectTab,
  });

  final List<UserNavTabConfig> tabs;
  final String? selectedTabId;
  final ValueChanged<UserNavTabConfig> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: const BoxDecoration(
        color: AppColors.obsidian,
        border: Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final tab in tabs)
              Expanded(
                child: _BottomNavItem(
                  tab: tab,
                  selected: selectedTabId == tab.id,
                  center: tab.id == 'explore',
                  onTap: () => onSelectTab(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.center,
    required this.onTap,
  });

  final UserNavTabConfig tab;
  final bool selected;
  final bool center;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Design nav (DESIGN_TOKENS.md §"Nav · tab bar"): thin icon over a tracked
    // uppercase label — champagne when selected, dim ivory otherwise. Uniform
    // items (no filled center pill).
    final color = selected ? AppColors.champagne : AppColors.textSecondary;
    final icon = selected ? widget.tab.selectedIcon : widget.tab.icon;

    return Tooltip(
      message: widget.tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 5),
              Text(
                widget.tab.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: color,
                  fontSize: 9,
                  letterSpacing: 0.16 * 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const UserBackAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 58,
      titleSpacing: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const _ChromeBackdrop(),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            _ChromeIconButton(
              tooltip: 'Back',
              icon: Icons.arrow_back,
              onPressed: onBack ?? () => _goBackOrHome(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineMedium.copyWith(fontSize: 20),
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }

  void _goBackOrHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }
}

class _ChromeBackdrop extends StatelessWidget {
  const _ChromeBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        border: Border(
          bottom: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _TopNavigationRail extends StatelessWidget {
  const _TopNavigationRail({
    required this.tabs,
    required this.selectedTabId,
    required this.onSelectTab,
  });

  final List<UserNavTabConfig> tabs;
  final String? selectedTabId;
  final ValueChanged<UserNavTabConfig> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels = constraints.maxWidth >= 360;
        final maxWidth = constraints.maxWidth >= 720 ? 680.0 : double.infinity;
        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  for (final tab in tabs.where((tab) => tab.enabled))
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _TopNavigationItem(
                          tab: tab,
                          selected: selectedTabId == tab.id,
                          showLabel: showLabels,
                          onTap: () => onSelectTab(tab),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopNavigationItem extends StatefulWidget {
  const _TopNavigationItem({
    required this.tab,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final UserNavTabConfig tab;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  State<_TopNavigationItem> createState() => _TopNavigationItemState();
}

class _TopNavigationItemState extends State<_TopNavigationItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected ? AppColors.champagne : AppColors.textSecondary;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.055)
              : _hovered
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.transparent,
          splashColor: AppColors.goldWash,
          highlightColor: AppColors.goldWash,
          onHover: (value) => setState(() => _hovered = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: SizedBox(
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? widget.tab.selectedIcon : widget.tab.icon,
                      color: color,
                      size: 20,
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.tab.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: selected
                                ? AppColors.champagne
                                : color,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.champagne
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopAvatar extends StatelessWidget {
  const _TopAvatar({
    required this.currentUser,
    required this.selected,
    required this.onPressed,
  });

  final AppUser currentUser;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final photoUrl = currentUser.profilePhotoUrl.trim();
    final initials = _initials(currentUser.name);
    return Tooltip(
      message: 'Profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: AppColors.goldWash,
        splashColor: AppColors.goldWash,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: photoUrl.isEmpty ? AppColors.surfaceEspresso : null,
            border: Border.all(
              color: selected ? AppColors.champagne : AppColors.goldBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _AvatarInitials(initials),
                )
              : _AvatarInitials(initials),
        ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.champagne,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textBody,
        hoverColor: AppColors.goldWash,
        highlightColor: Colors.transparent,
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: Icon(icon),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

class UserNavTabConfig {
  const UserNavTabConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final bool enabled;
}

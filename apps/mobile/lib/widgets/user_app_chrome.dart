import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../models/app_user.dart';

class UserShellTopBar extends StatelessWidget implements PreferredSizeWidget {
  const UserShellTopBar({
    super.key,
    required this.currentUser,
    required this.tabs,
    required this.selectedTabId,
    required this.onSelectTab,
  });

  final AppUser currentUser;
  final List<UserNavTabConfig> tabs;
  final String? selectedTabId;
  final ValueChanged<UserNavTabConfig> onSelectTab;

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
            const Expanded(
              child: Text(
                'Nightlife',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFFF5F5F0),
                ),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: const BoxDecoration(
        color: Color(0xF5080809),
        border: Border(
          top: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
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
    final center = widget.center;
    final iconColor = selected ? const Color(0xFFF59E0B) : const Color(0x40FFFFFF);
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
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  width: center ? 46 : 42,
                  height: center ? 46 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: center
                        ? const Color(0xFFF59E0B)
                        : selected
                        ? const Color(0x1AF59E0B)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    icon,
                    size: center ? 23 : 22,
                    color: center ? const Color(0xFF080809) : iconColor,
                  ),
                ),
                Positioned(
                  bottom: 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: selected && !center ? 3 : 0,
                    height: selected && !center ? 3 : 0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
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
        color: Color(0xF0080809),
        border: Border(
          bottom: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
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
    final color = selected ? AppTheme.accentPink : AppTheme.textMuted;
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
          splashColor: AppTheme.accentPink.withValues(alpha: 0.12),
          highlightColor: AppTheme.accentPink.withValues(alpha: 0.08),
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
                          widget.tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 11.5,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w700,
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
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.accentPink
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppTheme.accentPink.withValues(
                                  alpha: 0.44,
                                ),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
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
        hoverColor: Colors.white.withValues(alpha: 0.06),
        splashColor: const Color(0x1AF59E0B),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl.isEmpty ? AppTheme.premiumGradient : null,
            border: Border.all(
              color: selected
                  ? const Color(0xFFF59E0B)
                  : const Color(0x26FFFFFF),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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
        backgroundColor: const Color(0x0DFFFFFF),
        foregroundColor: Colors.white,
        hoverColor: const Color(0x1AF59E0B),
        highlightColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

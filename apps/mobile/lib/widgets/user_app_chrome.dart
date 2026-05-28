import 'dart:ui';

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
  Size get preferredSize => const Size.fromHeight(122);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const _ChromeBackdrop(),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            Builder(
              builder: (context) => _ChromeIconButton(
                tooltip: 'Open menu',
                icon: Icons.menu,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nightlife',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: _TopNavigationRail(
          tabs: tabs,
          selectedTabId: selectedTabId,
          onSelectTab: onSelectTab,
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
      toolbarHeight: 64,
      titleSpacing: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const _ChromeBackdrop(),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            _ChromeIconButton(
              tooltip: 'Back',
              icon: Icons.arrow_back,
              onPressed: onBack ?? () => _goBackOrHome(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE60D111B),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.glassBorder.withValues(alpha: 0.9),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
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
              ? AppTheme.primaryViolet.withValues(alpha: 0.18)
              : _hovered
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.accentPink.withValues(alpha: 0.48)
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
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? widget.tab.selectedIcon : widget.tab.icon,
                      color: color,
                      size: 21,
                    ),
                    if (widget.showLabel) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 12,
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
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
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
                                blurRadius: 10,
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
        splashColor: AppTheme.accentPink.withValues(alpha: 0.14),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: photoUrl.isEmpty ? AppTheme.premiumGradient : null,
            border: Border.all(
              color: selected
                  ? AppTheme.neonLime
                  : AppTheme.accentPink.withValues(alpha: 0.5),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
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
        backgroundColor: Colors.white.withValues(alpha: 0.035),
        foregroundColor: Colors.white,
        hoverColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: AppTheme.accentPink.withValues(alpha: 0.14),
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

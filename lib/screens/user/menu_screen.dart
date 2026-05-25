import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    super.key,
    required this.currentUser,
    required this.selectedIndex,
    required this.onSelect,
  });

  final AppUser currentUser;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MenuItem(Icons.home_outlined, 'Home', 0),
      _MenuItem(Icons.explore_outlined, 'Explore Events', 1),
      _MenuItem(Icons.search, 'Search', 2),
      _MenuItem(Icons.confirmation_number_outlined, 'My RSVPs', 3),
      _MenuItem(Icons.favorite_border, 'Favorites', 4),
      _MenuItem(Icons.person_outline, 'Profile', 5),
      _MenuItem(Icons.settings_outlined, 'Settings', 6),
      _MenuItem(Icons.support_agent_outlined, 'Help & Support', 7),
    ];

    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.glassSurface.withValues(alpha: 0.92),
              border: Border(
                right: BorderSide(
                  color: AppTheme.neonViolet.withValues(alpha: 0.26),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPink.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(10, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                children: [
                  _DrawerHeader(currentUser: currentUser),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.premiumGradient,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryViolet.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Guestlists, saved nights, and profile tools in one place.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DrawerItem(
                        item: item,
                        selected: selectedIndex == item.index,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(item.index);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DrawerItem(
                    item: const _MenuItem(Icons.logout, 'Logout', -1),
                    selected: false,
                    destructive: true,
                    onTap: () {
                      Navigator.of(context).pop();
                      AuthService.instance.signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          _DrawerAvatar(currentUser: currentUser),
          const SizedBox(width: 12),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(currentUser.role),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final photoUrl = currentUser.profilePhotoUrl.trim();
    const size = 56.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentPink.withValues(alpha: 0.22),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl.isNotEmpty
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _DrawerInitials(name: currentUser.name),
            )
          : _DrawerInitials(name: currentUser.name),
    );
  }
}

class _DrawerInitials extends StatelessWidget {
  const _DrawerInitials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.destructive = false,
  });

  final _MenuItem item;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? AppTheme.accentPink
        : selected
        ? Colors.white
        : AppTheme.textMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primaryViolet.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? AppTheme.accentPink.withValues(alpha: 0.48)
              : AppTheme.glassBorder,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(item.icon, color: color),
        title: Text(
          item.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        trailing: selected
            ? const Icon(Icons.circle, size: 8, color: AppTheme.neonLime)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return initials.isEmpty ? '?' : initials;
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.index);

  final IconData icon;
  final String label;
  final int index;
}

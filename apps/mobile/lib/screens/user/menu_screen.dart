import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
    const items = [
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
      backgroundColor: AppColors.obsidianDeep,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.obsidianDeep,
          border: Border(
            right: BorderSide(color: AppColors.goldBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: [
              _DrawerHeader(currentUser: currentUser),
              const SizedBox(height: 28),
              for (final item in items)
                _DrawerItem(
                  item: item,
                  selected: selectedIndex == item.index,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(item.index);
                  },
                ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.goldBorder),
              const SizedBox(height: 16),
              _DrawerItem(
                item: const _MenuItem(Icons.logout, 'Logout', -1),
                selected: false,
                destructive: true,
                onTap: () async {
                  // Capture the navigator before the async gap, close the drawer
                  // FIRST, then sign out so RoleRouterScreen's authStateChanges
                  // listener rebuilds to WelcomeScreen with no stale overlay on
                  // top.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  try {
                    await AuthService.instance.signOut();
                  } catch (_) {
                    // Sign-out errors are non-fatal; the auth listener still
                    // rebuilds the router on the next state change.
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DrawerAvatar(currentUser: currentUser),
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
                style: AppTypography.titleMedium.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                _roleLabel(currentUser.role).toUpperCase(),
                style: AppTypography.labelSmall.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _roleLabel(String role) {
    return switch (role) {
      'promoter' => 'Promoter',
      'clubAdmin' => 'Venue',
      _ => 'Member',
    };
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

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
        color: AppColors.surfaceEspresso,
        border: Border.all(color: AppColors.champagne, width: 1),
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
        // Playfair monogram.
        _initials(name),
        style: AppTypography.headlineMedium.copyWith(
          fontSize: 20,
          color: AppColors.champagne,
        ),
      ),
    );
  }
}

// ─── Nav item ─────────────────────────────────────────────────────────────────

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
    final Color itemColor;
    if (destructive) {
      itemColor = AppColors.destructive;
    } else if (selected) {
      itemColor = AppColors.champagne;
    } else {
      itemColor = AppColors.textBody;
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(item.icon, color: itemColor, size: 20),
      title: Text(
        item.label,
        style: AppTypography.bodyMedium.copyWith(color: itemColor),
      ),
      onTap: onTap,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

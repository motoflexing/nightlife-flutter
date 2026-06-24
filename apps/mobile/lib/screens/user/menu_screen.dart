import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFF0D0D0F),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0F),
          border: Border(
            right: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
          ),
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
                  color: const Color(0x1AF59E0B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0x33F59E0B),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFF59E0B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guestlists, saved nights, and profile tools in one place.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final item in items)
                Padding(
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
              const SizedBox(height: 8),
              _DrawerItem(
                item: const _MenuItem(Icons.logout, 'Logout', -1),
                selected: false,
                destructive: true,
                onTap: () async {
                  debugPrint('[LOGOUT] user drawer: TAP');
                  // Capture the navigator before the async gap, close the drawer
                  // FIRST, then sign out so RoleRouterScreen's authStateChanges
                  // listener rebuilds to WelcomeScreen with no stale overlay on
                  // top.
                  final navigator = Navigator.of(context);
                  debugPrint('[LOGOUT] user drawer: before pop');
                  navigator.pop();
                  debugPrint('[LOGOUT] user drawer: after pop');
                  try {
                    debugPrint('[LOGOUT] user drawer: before signOut');
                    await AuthService.instance.signOut();
                    debugPrint('[LOGOUT] user drawer: after signOut');
                  } catch (e) {
                    debugPrint('[LOGOUT] user drawer: signOut THREW: $e');
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFF5F5F0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(currentUser.role).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0x40FFFFFF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: const Color(0x1AF59E0B),
        border: Border.all(color: const Color(0xFFF59E0B)),
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
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF59E0B),
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
    final Color bgColor;
    final Color itemColor;

    if (destructive) {
      bgColor = const Color(0x0DFF5252);
      itemColor = Colors.redAccent;
    } else if (selected) {
      bgColor = const Color(0x1AF59E0B);
      itemColor = const Color(0xFFF59E0B);
    } else {
      bgColor = Colors.transparent;
      itemColor = const Color(0x66FFFFFF);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        color: bgColor,
        child: Stack(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2,
              ),
              leading: Icon(item.icon, color: itemColor, size: 20),
              title: Text(
                item.label,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              onTap: onTap,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: selected ? 2 : 0,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
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

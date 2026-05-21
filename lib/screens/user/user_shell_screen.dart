import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/neon_scaffold.dart';
import 'home_screen.dart';
import 'menu_screen.dart';
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
    final pages = [
      HomeScreen(currentUser: widget.currentUser),
      SearchScreen(currentUser: widget.currentUser),
      ProfileScreen(currentUser: widget.currentUser),
      MenuScreen(
        currentUser: widget.currentUser,
        onCreateEvent: () => _showCreateSheet(initial: 'event'),
        onCreateBrand: () => _showCreateSheet(initial: 'brand'),
      ),
    ];
    return NeonScaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accentPink,
        foregroundColor: Colors.white,
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index > 1 ? _index + 1 : _index,
        onDestinationSelected: (value) {
          if (value == 2) {
            _showCreateSheet();
            return;
          }
          setState(() => _index = value > 2 ? value - 1 : value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_activity_outlined),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
      child: pages[_index],
    );
  }

  void _showCreateSheet({String? initial}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              _CreateTile(
                icon: Icons.local_activity_outlined,
                title: 'Create Event',
                onTap: () => _handleCreate(context, event: true),
              ),
              _CreateTile(
                icon: Icons.storefront_outlined,
                title: 'Create Brand',
                onTap: () => _handleCreate(context, event: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCreate(BuildContext context, {required bool event}) {
    Navigator.of(context).pop();
    final allowed =
        widget.currentUser.isSuperAdmin || widget.currentUser.isClubAdmin;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? '${event ? 'Create Event' : 'Create Brand'} is available from the admin console.'
              : 'You don\'t have permission.',
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accentPink),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../widgets/neon_scaffold.dart';
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
    final pages = [
      HomeScreen(currentUser: widget.currentUser),
      SearchScreen(currentUser: widget.currentUser),
      MyRsvpsScreen(currentUser: widget.currentUser),
      ProfileScreen(currentUser: widget.currentUser),
      MenuScreen(currentUser: widget.currentUser),
    ];
    return NeonScaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_activity_outlined),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'RSVPs',
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
}

import 'package:flutter/material.dart';

import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import 'role_router_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const RoleRouterScreen();
    return const NeonScaffold(
      child: PremiumLoader(message: 'Curating your night...'),
    );
  }
}

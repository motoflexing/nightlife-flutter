import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/version_service.dart';
import 'force_update_screen.dart';
import 'maintenance_screen.dart';
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
    _initialize();
  }

  Future<void> _initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final versionResult = await VersionService.instance.checkVersion();

    if (versionResult.status == VersionStatus.maintenance) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
        );
      }
      return;
    }

    if (versionResult.status == VersionStatus.forceUpdate) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ForceUpdateScreen(
              updateUrl: versionResult.updateUrl,
              isForced: true,
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _ready = true);

    if (versionResult.status == VersionStatus.softUpdate && mounted) {
      showDialog(
        context: context,
        builder: (_) => ForceUpdateScreen(
          updateUrl: versionResult.updateUrl,
          isForced: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const RoleRouterScreen();
    return Scaffold(
      backgroundColor: const Color(0xFF080809),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Icon(
                Icons.nightlife,
                size: 28,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                letterSpacing: 4.0,
                color: Color(0x66FFFFFF),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

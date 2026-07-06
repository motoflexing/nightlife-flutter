import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/version_service.dart';
import '../../widgets/nocturne_monogram.dart';
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
    // Nocturne "logo reveal": obsidian canvas, the "N" monogram, the Nightlife
    // wordmark in wide-tracked ivory, a tracked "members only" eyebrow, and a
    // gold spinner. (App name stays "Nightlife" — the design's "Nocturne"
    // wordmark is the design tool's own brand, not this app's.)
    return Scaffold(
      backgroundColor: AppColors.obsidianDeep,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NocturneMonogram(size: 96, innerRing: true),
                const SizedBox(height: 34),
                // "Nightlife" wordmark — wide-tracked ivory (design wordmark).
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: AppTypography.labelMedium.copyWith(
                    fontSize: 13,
                    letterSpacing: 0.5 * 13,
                    color: AppColors.ivory,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.champagne,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 56,
            child: Text(
              'Members Only'.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 9,
                letterSpacing: 0.3 * 9,
                color: AppColors.textDisabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

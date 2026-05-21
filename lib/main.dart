import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/admin/super_admin_login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/user/event_link_screen.dart';
import 'services/referral_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ReferralService.instance.captureFromUri(Uri.base);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NightlifePlatformApp());
}

class NightlifePlatformApp extends StatelessWidget {
  const NightlifePlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri == null) return null;
    ReferralService.instance.captureFromUri(uri);

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'event') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => EventLinkScreen(
          eventId: Uri.decodeComponent(uri.pathSegments.last),
        ),
      );
    }

    if (uri.path == '/super-admin-login') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SuperAdminLoginScreen(),
      );
    }

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const SplashScreen(),
    );
  }
}

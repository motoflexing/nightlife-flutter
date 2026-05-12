import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/splash_screen.dart';
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
    );
  }
}

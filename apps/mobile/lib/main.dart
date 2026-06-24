import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/user/event_link_screen.dart';
import 'services/analytics_service.dart';
import 'services/connectivity_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/referral_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crashlytics is not supported on Flutter web. On web we keep the default
  // console reporting only; on native we forward to Crashlytics below (after
  // Firebase.initializeApp, since Crashlytics requires Firebase to be ready).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  ReferralService.instance.captureFromUri(Uri.base);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(true);
    }
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    runApp(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app. Please restart.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
    return;
  }

  StorageService.instance.configureRetryLimits();
  ConnectivityService.instance.initialize();
  runApp(const AppErrorBoundary(child: NightlifePlatformApp()));
}

class NightlifePlatformApp extends StatefulWidget {
  const NightlifePlatformApp({super.key});

  @override
  State<NightlifePlatformApp> createState() => _NightlifePlatformAppState();
}

class _NightlifePlatformAppState extends State<NightlifePlatformApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.initialize(_navigatorKey);
    NotificationService.instance.initialize();
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      navigatorKey: _navigatorKey,
      navigatorObservers: [AnalyticsService.instance.observer],
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

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const SplashScreen(),
    );
  }
}

class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please restart the app.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}

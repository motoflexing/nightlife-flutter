import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'referral_service.dart';

class DeepLinkService {
  DeepLinkService._();

  static final instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _handleInitialLink();
    _sub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleLink(uri);
    } catch (_) {}
  }

  void _handleLink(Uri uri) {
    ReferralService.instance.captureFromUri(uri);
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    if (uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'event') {
      final eventId = Uri.decodeComponent(uri.pathSegments.last);
      navigator.pushNamed('/event/$eventId');
    }
  }

  void dispose() => _sub?.cancel();
}

import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // Screen tracking
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // Auth events
  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  // Event discovery
  Future<void> logEventViewed({
    required String eventId,
    required String eventName,
    required String city,
  }) async {
    await _analytics.logEvent(
      name: 'event_viewed',
      parameters: {
        'event_id': eventId,
        'event_name': eventName,
        'city': city,
      },
    );
  }

  Future<void> logEventCardTapped({
    required String eventId,
    required String eventName,
  }) async {
    await _analytics.logEvent(
      name: 'event_card_tapped',
      parameters: {
        'event_id': eventId,
        'event_name': eventName,
      },
    );
  }

  // RSVP funnel
  Future<void> logRsvpStarted({
    required String eventId,
    required String eventName,
  }) async {
    await _analytics.logEvent(
      name: 'rsvp_started',
      parameters: {
        'event_id': eventId,
        'event_name': eventName,
      },
    );
  }

  Future<void> logRsvpCompleted({
    required String eventId,
    required String eventName,
    required String promoterId,
  }) async {
    await _analytics.logEvent(
      name: 'rsvp_completed',
      parameters: {
        'event_id': eventId,
        'event_name': eventName,
        'promoter_id': promoterId,
      },
    );
  }

  // Search and discovery
  Future<void> logSearch(String query) async {
    await _analytics.logSearch(searchTerm: query);
  }

  Future<void> logCitySelected(String city) async {
    await _analytics.logEvent(
      name: 'city_selected',
      parameters: {'city': city},
    );
  }

  Future<void> logVibeSelected(String vibe) async {
    await _analytics.logEvent(
      name: 'vibe_selected',
      parameters: {'vibe': vibe},
    );
  }

  // Promoter
  Future<void> logPromoterLinkShared({
    required String eventId,
    required String promoterId,
  }) async {
    await _analytics.logShare(
      contentType: 'event',
      itemId: eventId,
      method: 'promoter_link',
    );
  }
}

import 'package:flutter/foundation.dart';

/// A one-shot request to open Explore with a specific filter pre-applied.
///
/// The Favorites screen sets this when the user taps a saved collection, then
/// navigates to Explore. Explore reads (and clears) the pending request when it
/// builds, so the filter is applied exactly once and not re-applied on every
/// later visit.
class ExploreFilterRequest {
  ExploreFilterRequest._();

  static final ExploreFilterRequest instance = ExploreFilterRequest._();

  final ValueNotifier<ExploreFilter?> pending = ValueNotifier(null);

  void request(ExploreFilter filter) => pending.value = filter;

  /// Returns the pending filter and clears it so it applies only once.
  ExploreFilter? take() {
    final value = pending.value;
    pending.value = null;
    return value;
  }
}

class ExploreFilter {
  const ExploreFilter({this.genre, this.shortcut});

  /// Music genre to select (matches an Explore genre chip), or null.
  final String? genre;

  /// Shortcut id to select (matches an `_ExploreShortcut.name`), or null.
  final String? shortcut;
}

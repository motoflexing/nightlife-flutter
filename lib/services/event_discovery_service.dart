import '../models/event.dart';

class EventDiscoveryService {
  EventDiscoveryService._();

  static final instance = EventDiscoveryService._();

  List<NightlifeEvent> filterEvents({
    required List<NightlifeEvent> events,
    String query = '',
    String? category,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();

    return events.where((event) {
      final searchable = _searchableText(event);
      final matchesQuery =
          normalizedQuery.isEmpty || searchable.contains(normalizedQuery);
      final matchesCategory =
          normalizedCategory == null ||
          normalizedCategory.isEmpty ||
          searchable.contains(normalizedCategory);
      return matchesQuery && matchesCategory;
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  String _searchableText(NightlifeEvent event) {
    return [
      event.title,
      event.venueName,
      event.address,
      event.city,
      event.musicType,
      event.crowdType,
      event.entryRules,
      event.description,
      event.priceText,
    ].join(' ').toLowerCase();
  }
}

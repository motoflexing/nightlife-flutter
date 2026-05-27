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

    return uniqueEvents(events).where((event) {
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

  List<NightlifeEvent> uniqueEvents(Iterable<NightlifeEvent> events) {
    final seenIds = <String>{};
    final seenEventSignatures = <String>{};
    final unique = <NightlifeEvent>[];

    for (final event in events) {
      final id = event.id.trim();
      final signature = _eventSignature(event);

      if (id.isNotEmpty && !seenIds.add(id)) continue;
      if (signature.isNotEmpty && !seenEventSignatures.add(signature)) {
        continue;
      }

      unique.add(event);
    }

    return unique;
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

  String _eventSignature(NightlifeEvent event) {
    final title = _normalizeIdentityPart(event.title);
    final venue = _normalizeIdentityPart(event.venueName);
    if (title.isEmpty && venue.isEmpty) return '';

    return [
      title,
      event.dateTime.toUtc().toIso8601String(),
      venue,
    ].where((part) => part.isNotEmpty).join('|');
  }

  String _normalizeIdentityPart(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

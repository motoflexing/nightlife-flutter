import '../models/event.dart';

class EventDiscoveryService {
  EventDiscoveryService._();

  static final instance = EventDiscoveryService._();

  List<NightlifeEvent> filterEvents({
    required List<NightlifeEvent> events,
    String query = '',
    String? category,
  }) {
    final queryTerms = _searchTerms(query);
    final categoryTerms = _searchTerms(category ?? '');

    return uniqueEvents(events).where((event) {
      final searchable = _searchableText(event);
      final matchesQuery =
          queryTerms.isEmpty ||
          queryTerms.every((term) => searchable.contains(term));
      final matchesCategory =
          categoryTerms.isEmpty ||
          categoryTerms.every((term) => searchable.contains(term));
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
      event.artistText,
      event.fullAddress,
      event.googleMapsLink,
      ..._entryTypeTerms(event),
    ].join(' ').toLowerCase();
  }

  List<String> _entryTypeTerms(NightlifeEvent event) {
    final price = event.priceText.trim().toLowerCase();
    final entry = event.entryRules.trim().toLowerCase();
    final combined = '$price $entry';
    final free =
        price.isEmpty ||
        combined.contains('free') ||
        combined.contains('guestlist') ||
        combined.contains('guest list') ||
        combined.contains('guest') ||
        price == '0' ||
        combined.contains('rs 0') ||
        combined.contains('inr 0');

    return [
      free ? 'free guestlist guest list rsvp' : 'paid cover entry ticket',
    ];
  }

  List<String> _searchTerms(String value) {
    return value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
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

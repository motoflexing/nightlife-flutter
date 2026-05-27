import '../models/event.dart';

class EventImageService {
  EventImageService._();

  static final instance = EventImageService._();

  static const _nightlifeImages = [
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=85',
    'https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=1200&q=85',
    'https://images.unsplash.com/photo-1571266028243-d220c6a7edbf?auto=format&fit=crop&w=1200&q=85',
    'https://images.unsplash.com/photo-1540039155733-5bb30b53aa14?auto=format&fit=crop&w=1200&q=85',
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=85',
    'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=1200&q=85',
  ];

  String imageUrlFor(NightlifeEvent event) {
    final poster = event.posterUrl.trim();
    if (_isValidNetworkUrl(poster)) return poster;

    final key = [
      event.id,
      event.title,
      event.venueName,
      event.city,
    ].where((part) => part.trim().isNotEmpty).join('|');
    final hash = key.isEmpty ? 0 : key.codeUnits.fold<int>(0, _combineHash);
    return _nightlifeImages[hash.abs() % _nightlifeImages.length];
  }

  bool _isValidNetworkUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }

  int _combineHash(int value, int unit) => 0x1fffffff & (value + unit * 37);
}

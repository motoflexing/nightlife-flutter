import '../models/event.dart';

enum EventImageSourceType { asset, network, fallback }

class EventImageSource {
  const EventImageSource({required this.type, required this.path});

  final EventImageSourceType type;
  final String path;

  bool get isNetwork => type == EventImageSourceType.network;
  bool get isAsset => type == EventImageSourceType.asset;
  bool get isFallback => type == EventImageSourceType.fallback;
}

class EventImageService {
  EventImageService._();

  static final instance = EventImageService._();

  static const _assetPrefix = 'assets/images/nightlife/';

  EventImageSource imageSourceFor(NightlifeEvent event) {
    final poster = event.posterUrl.trim();
    if (_isValidNetworkUrl(poster)) {
      return EventImageSource(type: EventImageSourceType.network, path: poster);
    }
    final assetPath = _assetPathFrom(poster);
    if (assetPath != null) {
      return EventImageSource(
        type: EventImageSourceType.asset,
        path: assetPath,
      );
    }

    return const EventImageSource(
      type: EventImageSourceType.fallback,
      path: '',
    );
  }

  bool _isValidNetworkUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }

  String? _assetPathFrom(String value) {
    if (value.isEmpty) return null;
    final normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith(_assetPrefix)) return normalized;
    if (normalized.startsWith('assets/')) return normalized;
    if (normalized.contains('/')) return null;
    return '$_assetPrefix$normalized';
  }
}

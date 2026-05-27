import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  LocationService._();

  static final instance = LocationService._();

  static const defaultMapZoom = 15.0;

  Future<UserLocationSnapshot> getUserLocationSnapshot() async {
    final position = await getCurrentPosition();
    ReadableAddress? address;
    try {
      address = await reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      address = null;
    }

    return UserLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      city: address?.city ?? '',
      fullAddress: address?.fullAddress ?? '',
      capturedAt: DateTime.now(),
    );
  }

  Future<LocationPermissionResult> requestPermission() async {
    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return const LocationPermissionResult.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationPermissionResult.denied();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationPermissionResult.deniedForever();
      }

      return const LocationPermissionResult.granted();
    } catch (error) {
      return LocationPermissionResult.error(_readableLocationError(error));
    }
  }

  Future<bool> areLocationServicesEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<Position> getCurrentPosition() async {
    final permission = await requestPermission();
    if (!permission.isGranted) {
      throw LocationServiceException(permission.message);
    }

    try {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (error) {
      throw LocationServiceException(_readableLocationError(error));
    }
  }

  Future<ReadableAddress?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) return null;

    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) return null;
      return ReadableAddress.fromPlacemark(placemarks.first);
    } catch (error) {
      throw LocationServiceException(_readableLocationError(error));
    }
  }

  Future<LatLng?> geocodeAddress(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty || kIsWeb) return null;

    try {
      final locations = await geocoding.locationFromAddress(normalized);
      if (locations.isEmpty) return null;
      final first = locations.first;
      return LatLng(first.latitude, first.longitude);
    } catch (_) {
      return null;
    }
  }

  double distanceInKm({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    final meters = Geolocator.distanceBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
    return meters / 1000;
  }

  String googleMapsLink({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final query = label == null || label.trim().isEmpty
        ? '$latitude,$longitude'
        : '${label.trim()}@$latitude,$longitude';
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }).toString();
  }

  String googleMapsDirectionsLink({
    required double latitude,
    required double longitude,
  }) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    }).toString();
  }

  String formatDistance(double distanceKm) {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m away';
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  CameraPosition cameraFor({
    required double latitude,
    required double longitude,
    double zoom = defaultMapZoom,
  }) {
    return CameraPosition(target: LatLng(latitude, longitude), zoom: zoom);
  }

  Future<void> openGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
    String? fallbackUrl,
  }) async {
    final uri = Uri.parse(
      fallbackUrl == null || fallbackUrl.trim().isEmpty
          ? googleMapsLink(
              latitude: latitude,
              longitude: longitude,
              label: label,
            )
          : fallbackUrl.trim(),
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const LocationServiceException('Could not open Google Maps.');
    }
  }

  Future<void> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      googleMapsDirectionsLink(latitude: latitude, longitude: longitude),
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const LocationServiceException('Could not open directions.');
    }
  }

  String _readableLocationError(Object error) {
    final text = error.toString();
    if (text.contains('PERMISSION_DENIED')) {
      return 'Location permission was denied.';
    }
    if (text.contains('LOCATION_SERVICES_DISABLED')) {
      return 'Location services are disabled.';
    }
    if (text.contains('timeout')) {
      return 'Location request timed out. Please try again.';
    }
    return 'Location is unavailable right now.';
  }
}

class UserLocationSnapshot {
  const UserLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.fullAddress,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String fullAddress;
  final DateTime capturedAt;
}

class LocationPermissionResult {
  const LocationPermissionResult._({
    required this.isGranted,
    required this.message,
  });

  const LocationPermissionResult.granted()
    : this._(isGranted: true, message: 'Location permission granted.');

  const LocationPermissionResult.denied()
    : this._(isGranted: false, message: 'Location permission was denied.');

  const LocationPermissionResult.deniedForever()
    : this._(
        isGranted: false,
        message:
            'Location permission is permanently denied. Enable it in settings.',
      );

  const LocationPermissionResult.serviceDisabled()
    : this._(
        isGranted: false,
        message: 'Location services are disabled on this device.',
      );

  const LocationPermissionResult.error(String message)
    : this._(isGranted: false, message: message);

  final bool isGranted;
  final String message;
}

class ReadableAddress {
  const ReadableAddress({required this.city, required this.fullAddress});

  final String city;
  final String fullAddress;

  factory ReadableAddress.fromPlacemark(geocoding.Placemark placemark) {
    final city = _firstNonEmpty([
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
    ]);
    final parts = [
      placemark.name,
      placemark.street,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
      placemark.postalCode,
      placemark.country,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();

    return ReadableAddress(city: city, fullAddress: parts.toSet().join(', '));
  }

  static String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

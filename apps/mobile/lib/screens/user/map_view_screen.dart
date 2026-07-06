import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/location_service.dart';
import '../../services/maps_availability.dart';
import '../../widgets/location_permission_flow.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/user_app_chrome.dart';
import 'event_details_screen.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({
    super.key,
    required this.events,
    required this.currentUser,
    this.userLatitude,
    this.userLongitude,
  });

  final List<NightlifeEvent> events;
  final AppUser currentUser;
  final double? userLatitude;
  final double? userLongitude;

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  double? _userLatitude;
  double? _userLongitude;
  NightlifeEvent? _selectedEvent;
  bool _locating = false;
  bool _mapReady = false;

  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#11131B"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#B8B8D0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0B0D14"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#20232B"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2B2036"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0B0D14"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#101827"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _userLatitude = widget.userLatitude;
    _userLongitude = widget.userLongitude;
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initialCameraPosition();
    final mapsUnavailable = kIsWeb && !isGoogleMapsWebSdkReady;
    return NeonScaffold(
      appBar: const UserBackAppBar(title: 'Map View'),
      child: mapsUnavailable
          ? _UnavailableMapContent(
              events: widget.events,
              hasLocation: _userLatitude != null && _userLongitude != null,
              userLatitude: _userLatitude,
              userLongitude: _userLongitude,
              locating: _locating,
              distanceFor: _distanceFor,
              onLocate: _locating ? null : _locateMe,
              onOpenEvent: _openEvent,
              onDirections: _openDirections,
            )
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initial,
                  myLocationEnabled:
                      _userLatitude != null && _userLongitude != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: _darkMapStyle,
                  markers: _markers(),
                  onMapCreated: (controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                    }
                    if (mounted) setState(() => _mapReady = true);
                  },
                ),
                if (!_mapReady) const _MapLoadingCard(),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: _MapHeader(
                    eventCount: widget.events.length,
                    hasLocation:
                        _userLatitude != null && _userLongitude != null,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: _selectedEvent == null ? 24 : 168,
                  child: FloatingActionButton.small(
                    heroTag: 'locate_me',
                    backgroundColor: AppColors.champagne,
                    foregroundColor: AppColors.obsidian,
                    onPressed: _locating ? null : _locateMe,
                    child: _locating
                        ? const PremiumLoader.compact(size: 18)
                        : const Icon(Icons.my_location),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  bottom: _selectedEvent == null ? -180 : 18,
                  child: _selectedEvent == null
                      ? const SizedBox.shrink()
                      : _EventMapPreview(
                          event: _selectedEvent!,
                          distanceKm: _distanceFor(_selectedEvent!),
                          onOpen: () => _openEvent(_selectedEvent!),
                        ),
                ),
              ],
            ),
    );
  }

  CameraPosition _initialCameraPosition() {
    if (_userLatitude != null && _userLongitude != null) {
      return LocationService.instance.cameraFor(
        latitude: _userLatitude!,
        longitude: _userLongitude!,
        zoom: 13,
      );
    }

    final event = widget.events.isEmpty ? null : widget.events.first;
    return LocationService.instance.cameraFor(
      latitude: event?.latitude ?? 26.1445,
      longitude: event?.longitude ?? 91.7362,
      zoom: event == null ? 11 : 13,
    );
  }

  Set<Marker> _markers() {
    return {
      for (final event in widget.events)
        if (event.latitude != null && event.longitude != null)
          Marker(
            markerId: MarkerId(event.id),
            position: LatLng(event.latitude!, event.longitude!),
            infoWindow: InfoWindow(
              title: event.title,
              snippet: event.venueName,
            ),
            onTap: () => setState(() => _selectedEvent = event),
          ),
    };
  }

  double? _distanceFor(NightlifeEvent event) {
    if (_userLatitude == null ||
        _userLongitude == null ||
        event.latitude == null ||
        event.longitude == null) {
      return null;
    }

    return LocationService.instance.distanceInKm(
      fromLatitude: _userLatitude!,
      fromLongitude: _userLongitude!,
      toLatitude: event.latitude!,
      toLongitude: event.longitude!,
    );
  }

  Future<void> _locateMe() async {
    // Show the in-app location disclosure BEFORE the OS prompt (Google Play
    // foreground-location requirement). Already-granted users skip the dialog.
    final permissionResult = await ensureLocationPermissionWithRationale(
      context,
    );
    if (permissionResult != LocationRationaleResult.granted) {
      if (!mounted) return;
      final message = permissionResult == LocationRationaleResult.declined
          ? 'Location access is needed to center the map on you.'
          : 'Location permission was denied.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() => _locating = true);
    try {
      final snapshot = await LocationService.instance.getUserLocationSnapshot();
      _userLatitude = snapshot.latitude;
      _userLongitude = snapshot.longitude;
      if (_controller.isCompleted) {
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(snapshot.latitude, snapshot.longitude),
            14,
          ),
        );
      }
      if (mounted) setState(() {});
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _openEvent(NightlifeEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventDetailsScreen(event: event, currentUser: widget.currentUser),
      ),
    );
  }

  Future<void> _openDirections(NightlifeEvent event) async {
    final latitude = event.latitude;
    final longitude = event.longitude;
    if (latitude == null || longitude == null) return;

    try {
      await LocationService.instance.openDirections(
        latitude: latitude,
        longitude: longitude,
      );
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _MapLoadingCard extends StatelessWidget {
  const _MapLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: 86,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceEspresso,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const PremiumLoader.compact(size: 18),
              const SizedBox(width: 10),
              Text('Loading map...', style: AppTypography.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.eventCount, required this.hasLocation});

  final int eventCount;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.map_outlined,
              color: AppColors.champagne,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$eventCount venue markers',
                style: AppTypography.titleMedium.copyWith(fontSize: 15),
              ),
            ),
            _MapPill(label: hasLocation ? 'Live location' : 'City fallback'),
          ],
        ),
      ),
    );
  }
}

class _UnavailableMapContent extends StatelessWidget {
  const _UnavailableMapContent({
    required this.events,
    required this.hasLocation,
    required this.userLatitude,
    required this.userLongitude,
    required this.locating,
    required this.distanceFor,
    required this.onLocate,
    required this.onOpenEvent,
    required this.onDirections,
  });

  final List<NightlifeEvent> events;
  final bool hasLocation;
  final double? userLatitude;
  final double? userLongitude;
  final bool locating;
  final double? Function(NightlifeEvent event) distanceFor;
  final VoidCallback? onLocate;
  final ValueChanged<NightlifeEvent> onOpenEvent;
  final ValueChanged<NightlifeEvent> onDirections;

  @override
  Widget build(BuildContext context) {
    final sortedEvents = List<NightlifeEvent>.of(events)
      ..sort((a, b) {
        final distanceA = distanceFor(a);
        final distanceB = distanceFor(b);
        if (distanceA == null && distanceB == null) {
          return a.dateTime.compareTo(b.dateTime);
        }
        if (distanceA == null) return 1;
        if (distanceB == null) return -1;
        return distanceA.compareTo(distanceB);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MapHeader(eventCount: events.length, hasLocation: hasLocation),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceEspresso,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.goldWash,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.champagne,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maps unavailable',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'API key not configured',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textCaption,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Interactive map will be available after Google Maps API configuration',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBodyDim,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _CoordinateRow(
                label: hasLocation ? 'Your location' : 'Location status',
                value: hasLocation
                    ? '${userLatitude!.toStringAsFixed(5)}, ${userLongitude!.toStringAsFixed(5)}'
                    : 'City fallback active',
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onLocate,
                icon: locating
                    ? const PremiumLoader.compact(size: 16)
                    : const Icon(Icons.my_location),
                label: Text(locating ? 'Loading map...' : 'Update location'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Tracked uppercase gold eyebrow (design §11).
        Text(
          'Nearby Venues'.toUpperCase(),
          style: AppTypography.labelLarge.copyWith(color: AppColors.champagne),
        ),
        const SizedBox(height: 10),
        if (sortedEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceEspresso,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Text(
              'No venues with coordinates are available yet.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textCaption,
              ),
            ),
          )
        else
          ...sortedEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FallbackVenueCard(
                event: event,
                distanceKm: distanceFor(event),
                onOpen: () => onOpenEvent(event),
                onDirections: event.latitude == null || event.longitude == null
                    ? null
                    : () => onDirections(event),
              ),
            ),
          ),
      ],
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_drop_outlined, color: AppColors.champagne),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textCaption,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textHigh,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackVenueCard extends StatelessWidget {
  const _FallbackVenueCard({
    required this.event,
    required this.distanceKm,
    required this.onOpen,
    required this.onDirections,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final VoidCallback onOpen;
  final VoidCallback? onDirections;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = event.latitude != null && event.longitude != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Playfair title.
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              _MapPill(
                label: distanceKm == null
                    ? hasCoordinates
                          ? event.city
                          : 'Location not added'
                    : LocationService.instance.formatDistance(distanceKm!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${event.venueName} · ${event.city}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBodyDim,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasCoordinates
                ? '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}'
                : 'Coordinates unavailable',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textCaption,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.local_activity_outlined, size: 18),
                  label: const Text('DETAILS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('DIRECTIONS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventMapPreview extends StatelessWidget {
  const _EventMapPreview({
    required this.event,
    required this.distanceKm,
    required this.onOpen,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.goldWash,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: const Icon(Icons.nightlife, color: AppColors.champagne),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Playfair title.
                  style: AppTypography.titleMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  event.venueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBodyDim,
                  ),
                ),
                if (distanceKm != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    LocationService.instance.formatDistance(distanceKm!),
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 11,
                      color: AppColors.champagne,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: onOpen, child: const Text('OPEN')),
        ],
      ),
    );
  }
}

/// Small gold stadium pill for map status/distance chips (design filter pills).
class _MapPill extends StatelessWidget {
  const _MapPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 9,
          color: AppColors.champagne,
        ),
      ),
    );
  }
}

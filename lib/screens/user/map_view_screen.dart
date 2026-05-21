import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/location_service.dart';
import '../../widgets/neon_scaffold.dart';
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
    return NeonScaffold(
      appBar: AppBar(title: const Text('Map View')),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initial,
            myLocationEnabled: _userLatitude != null && _userLongitude != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkMapStyle,
            markers: _markers(),
            onMapCreated: (controller) {
              if (!_controller.isCompleted) _controller.complete(controller);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _MapHeader(
              eventCount: widget.events.length,
              hasLocation: _userLatitude != null && _userLongitude != null,
            ),
          ),
          Positioned(
            right: 16,
            bottom: _selectedEvent == null ? 24 : 168,
            child: FloatingActionButton.small(
              heroTag: 'locate_me',
              backgroundColor: AppTheme.accentPink,
              foregroundColor: Colors.white,
              onPressed: _locating ? null : _locateMe,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
    setState(() => _locating = true);
    try {
      final snapshot = await LocationService.instance.getUserLocationSnapshot();
      _userLatitude = snapshot.latitude;
      _userLongitude = snapshot.longitude;
      final controller = await _controller.future;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(snapshot.latitude, snapshot.longitude),
          14,
        ),
      );
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
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.eventCount, required this.hasLocation});

  final int eventCount;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: AppTheme.neonCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$eventCount venue markers',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Chip(label: Text(hasLocation ? 'Live location' : 'City fallback')),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.accentPink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.nightlife, color: AppTheme.accentPink),
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
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.venueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  if (distanceKm != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      LocationService.instance.formatDistance(distanceKm!),
                      style: const TextStyle(
                        color: AppTheme.neonLime,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: onOpen, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}

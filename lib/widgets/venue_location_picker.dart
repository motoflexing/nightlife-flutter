import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_theme.dart';
import '../models/event.dart';
import '../services/location_service.dart';
import '../services/maps_availability.dart';

class VenueLocationPicker extends StatefulWidget {
  const VenueLocationPicker({
    super.key,
    required this.event,
    required this.venueName,
    required this.onChanged,
    required this.onAddressResolved,
  });

  final NightlifeEvent event;
  final String venueName;
  final ValueChanged<NightlifeEvent> onChanged;
  final ValueChanged<String> onAddressResolved;

  @override
  State<VenueLocationPicker> createState() => _VenueLocationPickerState();
}

class _VenueLocationPickerState extends State<VenueLocationPicker> {
  GoogleMapController? _mapController;
  bool _fetchingLocation = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latitude = widget.event.latitude;
    final longitude = widget.event.longitude;
    final mapsUnavailable = kIsWeb && !isGoogleMapsWebSdkReady;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  latitude == null || longitude == null
                      ? 'No venue pin saved yet'
                      : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 190,
              child: mapsUnavailable
                  ? const _PickerMapUnavailable()
                  : GoogleMap(
                      initialCameraPosition: LocationService.instance.cameraFor(
                        latitude: latitude ?? 26.1445,
                        longitude: longitude ?? 91.7362,
                        zoom: latitude == null ? 11 : 15,
                      ),
                      markers: {
                        if (latitude != null && longitude != null)
                          Marker(
                            markerId: const MarkerId('venue_pin'),
                            position: LatLng(latitude, longitude),
                            draggable: true,
                            onDragEnd: _setPin,
                          ),
                      },
                      onTap: _setPin,
                      onMapCreated: (controller) => _mapController = controller,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _fetchingLocation ? null : _useCurrentLocation,
                  icon: _fetchingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed),
                  label: const Text('Use Current Location'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Open Map Picker'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: latitude == null || longitude == null
                ? null
                : () => _openMaps(latitude, longitude),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open in Google Maps'),
          ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final snapshot = await LocationService.instance.getUserLocationSnapshot();
      widget.onAddressResolved(snapshot.fullAddress);
      await _applyCoordinates(
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        fullAddress: snapshot.fullAddress,
        city: snapshot.city,
      );
    } on LocationServiceException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _setPin(LatLng position) async {
    ReadableAddress? readable;
    try {
      readable = await LocationService.instance.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      readable = null;
    }
    if (readable?.fullAddress.isNotEmpty == true) {
      widget.onAddressResolved(readable!.fullAddress);
    }
    await _applyCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
      fullAddress: readable?.fullAddress ?? widget.event.fullAddress,
      city: readable?.city ?? widget.event.city,
    );
  }

  Future<void> _openMapPicker() async {
    if (kIsWeb && !isGoogleMapsWebSdkReady) {
      _showError(
        'API key not configured. Use Current Location or enter coordinates manually.',
      );
      return;
    }

    var selected = LatLng(
      widget.event.latitude ?? 26.1445,
      widget.event.longitude ?? 91.7362,
    );
    final picked = await showDialog<LatLng>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 720,
                height: 520,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Open Map Picker',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: LocationService.instance
                            .cameraFor(
                              latitude: selected.latitude,
                              longitude: selected.longitude,
                              zoom: widget.event.latitude == null ? 11 : 15,
                            ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('picked_venue_pin'),
                            position: selected,
                            draggable: true,
                            onDragEnd: (position) =>
                                setDialogState(() => selected = position),
                          ),
                        },
                        onTap: (position) =>
                            setDialogState(() => selected = position),
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(selected),
                        icon: const Icon(Icons.check),
                        label: const Text('Use Selected Location'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (picked != null) await _setPin(picked);
  }

  Future<void> _applyCoordinates({
    required double latitude,
    required double longitude,
    required String fullAddress,
    required String city,
  }) async {
    final next = widget.event.copyWith(
      latitude: latitude,
      longitude: longitude,
      fullAddress: fullAddress,
      address: fullAddress.isEmpty ? widget.event.address : fullAddress,
      city: city.isEmpty ? widget.event.city : city,
      googleMapsLink: LocationService.instance.googleMapsLink(
        latitude: latitude,
        longitude: longitude,
        label: widget.venueName,
      ),
    );
    widget.onChanged(next);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15),
    );
  }

  Future<void> _openMaps(double latitude, double longitude) async {
    try {
      await LocationService.instance.openGoogleMaps(
        latitude: latitude,
        longitude: longitude,
        label: widget.venueName,
        fallbackUrl: widget.event.googleMapsLink,
      );
    } on LocationServiceException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PickerMapUnavailable extends StatelessWidget {
  const _PickerMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface.withValues(alpha: 0.9),
      padding: const EdgeInsets.all(16),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: AppTheme.neonCyan),
          SizedBox(height: 10),
          Text(
            'Maps unavailable',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Interactive map will be available after Google Maps API configuration',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

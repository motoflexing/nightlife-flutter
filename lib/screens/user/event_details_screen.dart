import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/referral_service.dart';
import '../../widgets/neon_scaffold.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    required this.event,
    required this.currentUser,
  });

  final NightlifeEvent event;
  final AppUser currentUser;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final TextEditingController _codeController;
  bool _submitting = false;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: ReferralService.instance.code ?? '',
    );
    _loadDistance();
  }

  Future<void> _loadDistance() async {
    final latitude = widget.event.latitude;
    final longitude = widget.event.longitude;
    if (latitude == null || longitude == null) return;

    final permission = await LocationService.instance.requestPermission();
    if (!permission.isGranted) return;

    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _distanceKm = LocationService.instance.distanceInKm(
          fromLatitude: position.latitude,
          fromLongitude: position.longitude,
          toLatitude: latitude,
          toLongitude: longitude,
        );
      });
    } catch (_) {
      // Details stay usable when location is unavailable.
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _rsvp() async {
    setState(() => _submitting = true);
    try {
      await FirestoreService.instance.createRsvp(
        event: widget.event,
        user: widget.currentUser,
        promoterCode: _codeController.text,
      );
      ReferralService.instance.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP created. Status is pending approval.'),
        ),
      );
      Navigator.of(context).pop();
    } on FirestoreAppException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return NeonScaffold(
      appBar: AppBar(title: const Text('Event details')),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 780;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _Poster(event: event)),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: _Details(
                              event: event,
                              currentUser: widget.currentUser,
                              codeController: _codeController,
                              submitting: _submitting,
                              distanceKm: _distanceKm,
                              onRsvp: _rsvp,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Poster(event: event),
                          const SizedBox(height: 18),
                          _Details(
                            event: event,
                            currentUser: widget.currentUser,
                            codeController: _codeController,
                            submitting: _submitting,
                            distanceKm: _distanceKm,
                            onRsvp: _rsvp,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: event.posterUrl.isEmpty
            ? Container(
                color: AppTheme.elevated,
                child: const Icon(
                  Icons.nightlife,
                  size: 80,
                  color: AppTheme.neonCyan,
                ),
              )
            : Image.network(event.posterUrl, fit: BoxFit.cover),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.event,
    required this.currentUser,
    required this.codeController,
    required this.submitting,
    required this.distanceKm,
    required this.onRsvp,
  });

  final NightlifeEvent event;
  final AppUser currentUser;
  final TextEditingController codeController;
  final bool submitting;
  final double? distanceKm;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(event.city)),
              ],
            ),
            const SizedBox(height: 14),
            _Info(
              icon: Icons.place_outlined,
              text: '${event.venueName}, ${event.address}',
            ),
            _Info(
              icon: Icons.schedule,
              text: Formatters.eventDate(event.dateTime),
            ),
            _Info(icon: Icons.music_note_outlined, text: event.musicType),
            _Info(icon: Icons.groups_2_outlined, text: event.crowdType),
            _Info(icon: Icons.rule_outlined, text: event.entryRules),
            _LocationSection(event: event, distanceKm: distanceKm),
            const SizedBox(height: 12),
            Text(event.description, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neonCyan.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                event.priceText.isEmpty
                    ? 'Entry details available at venue.'
                    : event.priceText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            if (currentUser.isUser && currentUser.isApproved) ...[
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Promoter code',
                  hintText: 'Optional referral code',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: submitting ? null : onRsvp,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_reg),
                label: const Text('RSVP now'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.event, required this.distanceKm});

  final NightlifeEvent event;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    final address = event.fullAddress.trim().isEmpty
        ? event.address
        : event.fullAddress;

    if (address.trim().isEmpty && (latitude == null || longitude == null)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Venue location',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (distanceKm != null)
                Text(
                  LocationService.instance.formatDistance(distanceKm!),
                  style: const TextStyle(
                    color: AppTheme.neonCyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (address.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              address,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
          ],
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 170,
                child: GoogleMap(
                  initialCameraPosition: LocationService.instance.cameraFor(
                    latitude: latitude,
                    longitude: longitude,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(event.id),
                      position: LatLng(latitude, longitude),
                      infoWindow: InfoWindow(
                        title: event.venueName,
                        snippet: event.title,
                      ),
                    ),
                  },
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMap(context, latitude, longitude),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open Maps'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openDirections(context, latitude, longitude),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openMap(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    try {
      await LocationService.instance.openGoogleMaps(
        latitude: latitude,
        longitude: longitude,
        label: event.venueName,
        fallbackUrl: event.googleMapsLink,
      );
    } on LocationServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openDirections(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    try {
      await LocationService.instance.openDirections(
        latitude: latitude,
        longitude: longitude,
      );
    } on LocationServiceException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

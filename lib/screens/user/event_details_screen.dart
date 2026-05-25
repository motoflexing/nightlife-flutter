import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/maps_availability.dart';
import '../../services/referral_service.dart';
import '../../widgets/compact_ui.dart';
import '../../widgets/event_poster.dart';
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
  bool _rsvpCreated = false;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: ReferralService.instance.code ?? '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openRsvpConfirmation() async {
    if (_submitting || _rsvpCreated) return;
    if (!_validateRsvpRequest()) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RsvpConfirmationSheet(
          event: widget.event,
          user: widget.currentUser,
          promoterCode: _codeController.text,
          onConfirm: _submitRsvp,
        );
      },
    );
  }

  bool _validateRsvpRequest() {
    final user = widget.currentUser;
    final event = widget.event;
    if (user.uid.trim().isEmpty) {
      _showError('Please sign in again to RSVP.');
      return false;
    }
    if (!user.isUser || !user.isApproved) {
      _showError('Only approved users can RSVP.');
      return false;
    }
    if (event.id.trim().isEmpty) {
      _showError('This event is not ready for RSVP yet.');
      return false;
    }
    if (event.title.trim().isEmpty) {
      _showError('This event is missing a title. Please try another event.');
      return false;
    }
    return true;
  }

  Future<bool> _submitRsvp() async {
    if (_submitting || _rsvpCreated) return false;
    if (!_validateRsvpRequest()) return false;

    final user = widget.currentUser;
    final event = widget.event;
    setState(() => _submitting = true);
    try {
      await FirestoreService.instance.createRsvp(
        event: event,
        user: user,
        promoterCode: _codeController.text,
      );
      ReferralService.instance.clear();
      if (!mounted) return true;
      setState(() => _rsvpCreated = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP confirmed. Please pay at the venue.'),
        ),
      );
      return true;
    } on FirestoreAppException catch (error) {
      debugPrint(
        'EventDetails RSVP failed: ${error.message} '
        'debug=${error.debugMessage ?? ''}',
      );
      final debugMessage = error.debugMessage?.trim();
      _showError(
        kDebugMode && debugMessage != null && debugMessage.isNotEmpty
            ? debugMessage
            : error.message,
      );
      return false;
    } catch (error) {
      debugPrint('EventDetails RSVP unexpected error: $error');
      _showError('Unable to create RSVP right now. Please try again.');
      return false;
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
          final wide = constraints.maxWidth >= 860;
          final content = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _HeroPoster(event: event, aspectRatio: 4 / 5),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 4,
                      child: _DetailsContent(
                        event: event,
                        currentUser: widget.currentUser,
                        codeController: _codeController,
                        submitting: _submitting,
                        rsvpCreated: _rsvpCreated,
                        distanceKm: _distanceKm,
                        onRsvp: _openRsvpConfirmation,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroPoster(event: event, aspectRatio: 16 / 9.6),
                    const SizedBox(height: 10),
                    _DetailsContent(
                      event: event,
                      currentUser: widget.currentUser,
                      codeController: _codeController,
                      submitting: _submitting,
                      rsvpCreated: _rsvpCreated,
                      distanceKm: _distanceKm,
                      onRsvp: _openRsvpConfirmation,
                    ),
                  ],
                );

          return SingleChildScrollView(
            padding: compactScreenPadding(context, bottom: 112),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RsvpConfirmationSheet extends StatefulWidget {
  const _RsvpConfirmationSheet({
    required this.event,
    required this.user,
    required this.promoterCode,
    required this.onConfirm,
  });

  final NightlifeEvent event;
  final AppUser user;
  final String promoterCode;
  final Future<bool> Function() onConfirm;

  @override
  State<_RsvpConfirmationSheet> createState() => _RsvpConfirmationSheetState();
}

class _RsvpConfirmationSheetState extends State<_RsvpConfirmationSheet> {
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final success = await widget.onConfirm();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final promoterCode = widget.promoterCode.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(top: BorderSide(color: AppTheme.glassBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.glassBorder,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Confirm RSVP',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ConfirmLine(
                      icon: Icons.storefront_outlined,
                      label: widget.event.venueName.trim().isEmpty
                          ? widget.event.city
                          : widget.event.venueName,
                    ),
                    _ConfirmLine(
                      icon: Icons.schedule,
                      label: Formatters.eventDate(widget.event.dateTime),
                    ),
                    _ConfirmLine(
                      icon: Icons.person_outline,
                      label: widget.user.name.trim().isEmpty
                          ? 'Guest'
                          : widget.user.name.trim(),
                    ),
                    _ConfirmLine(
                      icon: Icons.phone_outlined,
                      label: widget.user.phone.trim().isEmpty
                          ? 'Phone not added'
                          : widget.user.phone.trim(),
                    ),
                    if (promoterCode.isNotEmpty)
                      _ConfirmLine(
                        icon: Icons.qr_code_2,
                        label: 'Promoter code: ${promoterCode.toUpperCase()}',
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.elevated.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.neonLime.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.neonLime.withValues(
                                  alpha: 0.36,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              color: AppTheme.neonLime,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pay at Venue',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Payment will be collected at the venue.',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.neonLime,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _confirm,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.how_to_reg),
                        label: Text(
                          _submitting ? 'Confirming RSVP' : 'Confirm RSVP',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPoster extends StatelessWidget {
  const _HeroPoster({required this.event, required this.aspectRatio});

  final NightlifeEvent event;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentPink.withValues(alpha: 0.22),
              blurRadius: 34,
              spreadRadius: -12,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: EventPoster(event: event, borderRadius: 8, showTitle: true),
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({
    required this.event,
    required this.currentUser,
    required this.codeController,
    required this.submitting,
    required this.rsvpCreated,
    required this.distanceKm,
    required this.onRsvp,
  });

  final NightlifeEvent event;
  final AppUser currentUser;
  final TextEditingController codeController;
  final bool submitting;
  final bool rsvpCreated;
  final double? distanceKm;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    final canRsvp = currentUser.isUser && currentUser.isApproved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: event.city, icon: Icons.location_city_outlined),
                  if (distanceKm != null)
                    _Chip(
                      label: LocationService.instance.formatDistance(
                        distanceKm!,
                      ),
                      icon: Icons.near_me_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.title.isEmpty ? 'Nightlife Event' : event.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              _InfoLine(
                icon: Icons.storefront_outlined,
                title: event.venueName,
                subtitle: event.address,
              ),
              _InfoLine(
                icon: Icons.schedule,
                title: Formatters.eventDate(event.dateTime),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Column(
            children: [
              _InfoLine(
                icon: Icons.music_note_outlined,
                title: event.musicType,
              ),
              _InfoLine(icon: Icons.groups_2_outlined, title: event.crowdType),
              _InfoLine(icon: Icons.rule_outlined, title: event.entryRules),
              _InfoLine(
                icon: Icons.confirmation_number_outlined,
                title: event.priceText.isEmpty
                    ? 'Entry details available at venue'
                    : event.priceText,
              ),
              if (event.description.trim().isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  event.description,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LocationSection(event: event, distanceKm: distanceKm),
        if (canRsvp) ...[
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Promoter code',
                    hintText: 'Optional referral code',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: submitting || rsvpCreated ? null : onRsvp,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            rsvpCreated
                                ? Icons.check_circle_outline
                                : Icons.how_to_reg,
                          ),
                    label: Text(rsvpCreated ? 'RSVP confirmed' : 'Book spot'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
    final hasCoordinates = latitude != null && longitude != null;
    final address = event.fullAddress.trim().isEmpty
        ? event.address
        : event.fullAddress;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppTheme.neonCyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Venue location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (distanceKm != null)
                _Chip(
                  label: LocationService.instance.formatDistance(distanceKm!),
                  icon: Icons.near_me_outlined,
                ),
            ],
          ),
          if (address.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              address,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 14),
          if (!hasCoordinates)
            const _MapUnavailable(
              message:
                  'Location not added. Directions will be available after venue coordinates are saved.',
            )
          else ...[
            if (kIsWeb && !isGoogleMapsWebSdkReady)
              const _MapUnavailable(message: 'Map preview unavailable')
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 180,
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionButton(
                  icon: Icons.map_outlined,
                  label: 'Open Google Maps',
                  onPressed: () => _openMap(context, latitude, longitude),
                ),
                _ActionButton(
                  icon: Icons.directions,
                  label: 'Get Directions',
                  filled: true,
                  onPressed: () =>
                      _openDirections(context, latitude, longitude),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.all(mobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryViolet.withValues(alpha: 0.12),
            blurRadius: mobile ? 16 : 24,
            spreadRadius: -14,
            offset: Offset(0, mobile ? 8 : 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty && (subtitle ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.trim().isNotEmpty)
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryViolet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.neonLime),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return SizedBox(
      width: MediaQuery.sizeOf(context).width < 430 ? double.infinity : 210,
      height: 48,
      child: filled
          ? ElevatedButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.elevated.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, color: AppTheme.neonCyan),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

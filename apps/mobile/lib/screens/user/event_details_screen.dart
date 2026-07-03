import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../services/analytics_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/maps_availability.dart';
import '../../services/referral_service.dart';
import '../../widgets/event_poster.dart';
import '../../widgets/neon_scaffold.dart';
import '../../widgets/premium_loader.dart';
import '../../widgets/user_app_chrome.dart';

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
  final double? _distanceKm = null;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: ReferralService.instance.code ?? '',
    );
    AnalyticsService.instance.logEventViewed(
      eventId: widget.event.id,
      eventName: widget.event.title,
      city: widget.event.city,
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

    AnalyticsService.instance.logRsvpStarted(
      eventId: widget.event.id,
      eventName: widget.event.title,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
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
      AnalyticsService.instance.logRsvpCompleted(
        eventId: event.id,
        eventName: event.title,
        promoterId: _codeController.text,
      );
      if (!mounted) return true;
      setState(() => _rsvpCreated = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSVP confirmed. Please pay at the venue.'),
        ),
      );
      return true;
    } on FirestoreAppException catch (error) {
      final debugMessage = error.debugMessage?.trim();
      _showError(
        kDebugMode && debugMessage != null && debugMessage.isNotEmpty
            ? debugMessage
            : error.message,
      );
      return false;
    } catch (error) {
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
    final canRsvp = widget.currentUser.isUser && widget.currentUser.isApproved;

    return NeonScaffold(
      appBar: const UserBackAppBar(title: 'Event Details'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final horizontalPadding = wide ? 24.0 : 20.0;
          final bottomPadding = wide ? 40.0 : 128.0;

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  wide ? 16 : 8,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _EventDetailsBody(
                      event: event,
                      codeController: _codeController,
                      submitting: _submitting,
                      rsvpCreated: _rsvpCreated,
                      distanceKm: _distanceKm,
                      canRsvp: canRsvp,
                      onRsvp: _openRsvpConfirmation,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 12 + MediaQuery.paddingOf(context).bottom,
                child: _StickyRsvpBar(
                  canRsvp: canRsvp,
                  submitting: _submitting,
                  rsvpCreated: _rsvpCreated,
                  onRsvp: _openRsvpConfirmation,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Body: poster → meta → lineup → house rules → location ─────────────────────

class _EventDetailsBody extends StatelessWidget {
  const _EventDetailsBody({
    required this.event,
    required this.codeController,
    required this.submitting,
    required this.rsvpCreated,
    required this.distanceKm,
    required this.canRsvp,
    required this.onRsvp,
  });

  final NightlifeEvent event;
  final TextEditingController codeController;
  final bool submitting;
  final bool rsvpCreated;
  final double? distanceKm;
  final bool canRsvp;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    final lineup = event.artistText.trim();
    final rules = event.entryRules.trim();
    final description = event.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosterHero(event: event),
        const SizedBox(height: 24),
        _MetaSection(event: event, distanceKm: distanceKm),
        // Lineup — only when the event actually names artists.
        if (lineup.isNotEmpty) ...[
          const SizedBox(height: 32),
          _LineupSection(lineup: lineup),
        ],
        // House Rules — only from the event's real entry rules / description.
        if (rules.isNotEmpty || description.isNotEmpty) ...[
          const SizedBox(height: 32),
          _HouseRulesSection(rules: rules, description: description),
        ],
        const SizedBox(height: 32),
        _LocationSection(event: event, distanceKm: distanceKm),
        if (canRsvp) ...[
          const SizedBox(height: 32),
          _PromoterCodeSection(
            codeController: codeController,
            submitting: submitting,
            rsvpCreated: rsvpCreated,
            onRsvp: onRsvp,
          ),
        ],
      ],
    );
  }
}

// ─── Poster hero: full-bleed poster, obsidian scrim, eyebrow, Playfair title ───

class _PosterHero extends StatelessWidget {
  const _PosterHero({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Nightlife Event' : event.title;
    final music = event.musicType.trim();
    final date = Formatters.eventDate(event.dateTime);
    // Eyebrow: "genre · date" when a genre exists, else the date alone.
    final eyebrow = music.isEmpty ? date : '$music · $date';
    final venueLine = [
      event.venueName.trim(),
      event.city.trim(),
    ].where((v) => v.isNotEmpty).join(' · ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 0.82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            EventPoster(event: event, borderRadius: 8),
            // Bottom-up obsidian legibility scrim (design).
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.obsidianDeep,
                  ],
                  stops: [0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    eyebrow.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.24 * 9,
                      color: AppColors.champagne,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.displayMedium.copyWith(
                      fontSize: 32,
                      height: 1.02,
                    ),
                  ),
                  if (venueLine.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 15,
                          color: AppColors.textBodyDim,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            venueLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textBodyDim,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meta rows: date, venue/city, address (blank rows omitted) ─────────────────

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.event, required this.distanceKm});

  final NightlifeEvent event;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final venue = [
      event.venueName.trim(),
      event.city.trim(),
    ].where((v) => v.isNotEmpty).join(' · ');
    final address = event.fullAddress.trim().isEmpty
        ? event.address.trim()
        : event.fullAddress.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionEyebrow('Details'),
        _MetaRow(
          icon: Icons.schedule,
          text: Formatters.eventDate(event.dateTime),
        ),
        if (venue.isNotEmpty)
          _MetaRow(icon: Icons.storefront_outlined, text: venue),
        if (address.isNotEmpty)
          _MetaRow(icon: Icons.location_on_outlined, text: address),
        if (distanceKm != null)
          _MetaRow(
            icon: Icons.near_me_outlined,
            text: LocationService.instance.formatDistance(distanceKm!),
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.champagne),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lineup: real artistText only ──────────────────────────────────────────────

class _LineupSection extends StatelessWidget {
  const _LineupSection({required this.lineup});

  final String lineup;

  @override
  Widget build(BuildContext context) {
    // artistText may be a single string or a separated list; split on common
    // separators so multiple names render as individual rows, but never invent.
    final names = lineup
        .split(RegExp(r'[,\n·•/|]| and '))
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionEyebrow('Lineup'),
        if (names.length <= 1)
          Text(
            lineup,
            style: AppTypography.titleMedium.copyWith(fontSize: 18),
          )
        else
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.music_note,
                    size: 16,
                    color: AppColors.champagne,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: AppTypography.titleMedium.copyWith(fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ─── House Rules: real entryRules (+description) only ──────────────────────────

class _HouseRulesSection extends StatelessWidget {
  const _HouseRulesSection({required this.rules, required this.description});

  final String rules;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionEyebrow('House Rules'),
        if (rules.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.gavel_outlined,
                size: 18,
                color: AppColors.champagne,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rules,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textBody,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        if (description.isNotEmpty) ...[
          if (rules.isNotEmpty) const SizedBox(height: 16),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textBodyDim,
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Location: map + directions/maps (logic unchanged) ─────────────────────────

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionEyebrow('Location'),
        if (address.trim().isNotEmpty) ...[
          Text(
            address,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textBodyDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!hasCoordinates)
          const _MapUnavailable(
            message:
                'Location not added. Directions will be available after '
                'venue coordinates are saved.',
          )
        else if (kIsWeb && !isGoogleMapsWebSdkReady)
          const _MapUnavailable(message: 'Map preview unavailable')
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 200,
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
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
        if (hasCoordinates) ...[
          const SizedBox(height: 14),
          _GhostButton(
            icon: Icons.directions_outlined,
            label: 'Get Directions',
            onPressed: () => _getDirections(context, latitude, longitude),
          ),
          const SizedBox(height: 12),
          _GhostButton(
            icon: Icons.map_outlined,
            label: 'View on Maps',
            onPressed: () => _viewOnMaps(context, latitude, longitude),
          ),
        ],
      ],
    );
  }

  Future<void> _getDirections(
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

  Future<void> _viewOnMaps(
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
}

// ─── Promoter code + RSVP (referral passthrough unchanged) ─────────────────────

class _PromoterCodeSection extends StatelessWidget {
  const _PromoterCodeSection({
    required this.codeController,
    required this.submitting,
    required this.rsvpCreated,
    required this.onRsvp,
  });

  final TextEditingController codeController;
  final bool submitting;
  final bool rsvpCreated;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionEyebrow('Promoter Code'),
        Text(
          'Using a promoter code helps us track who invited you.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textCaption,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textHigh),
          decoration: const InputDecoration(
            labelText: 'Promoter code (optional)',
            hintText: 'Enter promoter code',
          ),
        ),
      ],
    );
  }
}

// ─── Sticky RSVP bar (design's prominent primary action) ───────────────────────

class _StickyRsvpBar extends StatelessWidget {
  const _StickyRsvpBar({
    required this.canRsvp,
    required this.submitting,
    required this.rsvpCreated,
    required this.onRsvp,
  });

  final bool canRsvp;
  final bool submitting;
  final bool rsvpCreated;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Free / pay-at-venue framing — no prices, no currency.
                  'Complimentary entry'.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.2 * 9,
                    color: AppColors.champagne,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canRsvp ? 'Settle at the door' : 'Approval required',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBodyDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 150,
            child: _RsvpPrimaryButton(
              submitting: submitting,
              rsvpCreated: rsvpCreated,
              onPressed: !canRsvp || submitting || rsvpCreated ? null : onRsvp,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ivory primary RSVP button (design §7). Confirmed state uses a gold outline.
class _RsvpPrimaryButton extends StatelessWidget {
  const _RsvpPrimaryButton({
    required this.submitting,
    required this.rsvpCreated,
    required this.onPressed,
  });

  final bool submitting;
  final bool rsvpCreated;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = submitting
        ? 'Confirming'
        : rsvpCreated
        ? 'Confirmed'
        : 'RSVP';

    if (rsvpCreated) {
      return SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(label.toUpperCase()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.champagne,
            disabledForegroundColor: AppColors.champagne,
            side: const BorderSide(color: AppColors.champagne, width: 1),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null
              ? AppColors.ivory.withValues(alpha: 0.5)
              : AppColors.ivory,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            splashColor: Colors.transparent,
            highlightColor: AppColors.obsidian.withValues(alpha: 0.08),
            onTap: onPressed,
            child: Center(
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.obsidian,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      label.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.obsidian,
                        letterSpacing: 0.16 * 12,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── RSVP confirmation sheet — "Confirm your place" (design bottom sheet) ───────

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
    final venue = widget.event.venueName.trim().isEmpty
        ? widget.event.city
        : widget.event.venueName;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              decoration: const BoxDecoration(
                color: AppColors.surfaceEspresso,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  top: BorderSide(color: AppColors.goldBorder, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle.
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textDisabled,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Playfair title.
                    Text(
                      'Confirm your place',
                      style: AppTypography.headlineMedium.copyWith(
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Complimentary / settle-at-the-door copy (no prices).
                    Text(
                      'Entry is complimentary — settle at the door. '
                      'Your RSVP holds your place for the night.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textBodyDim,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SheetLine(
                      icon: Icons.event_outlined,
                      label: widget.event.title,
                    ),
                    _SheetLine(
                      icon: Icons.storefront_outlined,
                      label: venue,
                    ),
                    _SheetLine(
                      icon: Icons.schedule,
                      label: Formatters.eventDate(widget.event.dateTime),
                    ),
                    _SheetLine(
                      icon: Icons.person_outline,
                      label: widget.user.name.trim().isEmpty
                          ? 'Guest'
                          : widget.user.name.trim(),
                    ),
                    if (promoterCode.isNotEmpty)
                      _SheetLine(
                        icon: Icons.qr_code_2,
                        label: 'Promoter code · ${promoterCode.toUpperCase()}',
                      ),
                    const SizedBox(height: 22),
                    // Full-width ivory "Confirm RSVP".
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _submitting
                              ? AppColors.ivory.withValues(alpha: 0.5)
                              : AppColors.ivory,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            splashColor: Colors.transparent,
                            highlightColor:
                                AppColors.obsidian.withValues(alpha: 0.08),
                            onTap: _submitting ? null : _confirm,
                            child: Center(
                              child: _submitting
                                  ? const PremiumLoader.compact(size: 18)
                                  : Text(
                                      'Confirm RSVP'.toUpperCase(),
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.obsidian,
                                        letterSpacing: 0.16 * 12,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
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

class _SheetLine extends StatelessWidget {
  const _SheetLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.champagne),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared bits ───────────────────────────────────────────────────────────────

/// Tracked uppercase section eyebrow + trailing gold hairline (design).
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.champagne,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.champagne.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ghost gold outline button (design "Get Directions" / "View on Maps").
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label.toUpperCase()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.champagne,
          side: const BorderSide(color: AppColors.champagne, width: 1),
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            color: AppColors.champagne.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textCaption,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

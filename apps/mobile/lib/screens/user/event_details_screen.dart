import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
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
  double? _distanceKm;

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
    final insights = EventInsights.fallbackFor(event);
    final canRsvp = widget.currentUser.isUser && widget.currentUser.isApproved;

    return NeonScaffold(
      appBar: const UserBackAppBar(title: 'Event Details'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final horizontalPadding = wide ? 18.0 : 12.0;
          final bottomPadding = wide ? 28.0 : 126.0;

          final content = _EventDetailsExperience(
            event: event,
            currentUser: widget.currentUser,
            insights: insights,
            codeController: _codeController,
            submitting: _submitting,
            rsvpCreated: _rsvpCreated,
            distanceKm: _distanceKm,
            onRsvp: _openRsvpConfirmation,
            wide: wide,
          );

          return Stack(
            children: [
              const Positioned.fill(child: _AliveNightBackdrop()),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  wide ? 16 : 10,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: content,
                  ),
                ),
              ),
              if (!wide)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  child: _StickyBookingBar(
                    event: event,
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
                            ? const PremiumLoader.compact(size: 18)
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

class EventInsights {
  const EventInsights({
    required this.expectedAttendance,
    required this.rsvpToday,
    required this.crowdEnergy,
    required this.trendingRank,
    required this.crowdTypes,
    required this.music,
    required this.mood,
    required this.bestFor,
    required this.vibeMatch,
  });

  final String expectedAttendance;
  final int rsvpToday;
  final String crowdEnergy;
  final String trendingRank;
  final List<CrowdTypeInsight> crowdTypes;
  final String music;
  final String mood;
  final List<String> bestFor;
  final int vibeMatch;

  factory EventInsights.fallbackFor(NightlifeEvent event) {
    return EventInsights(
      expectedAttendance: '450+',
      rsvpToday: 47,
      crowdEnergy: 'High',
      trendingRank: event.city.trim().isEmpty
          ? '#2 tonight'
          : '#2 in ${event.city.trim()}',
      crowdTypes: const [
        CrowdTypeInsight(label: 'Students', value: 58),
        CrowdTypeInsight(label: 'Professionals', value: 32),
        CrowdTypeInsight(label: 'Creators', value: 10),
      ],
      music: event.musicType.trim().isEmpty
          ? 'Bollywood x EDM'
          : event.musicType.trim(),
      mood: 'High Energy',
      bestFor: const ['Dancing', 'Music', 'Meeting People'],
      vibeMatch: 82,
    );
  }
}

class CrowdTypeInsight {
  const CrowdTypeInsight({required this.label, required this.value});

  final String label;
  final int value;
}

class _EventDetailsExperience extends StatelessWidget {
  const _EventDetailsExperience({
    required this.event,
    required this.currentUser,
    required this.insights,
    required this.codeController,
    required this.submitting,
    required this.rsvpCreated,
    required this.distanceKm,
    required this.onRsvp,
    required this.wide,
  });

  final NightlifeEvent event;
  final AppUser currentUser;
  final EventInsights insights;
  final TextEditingController codeController;
  final bool submitting;
  final bool rsvpCreated;
  final double? distanceKm;
  final VoidCallback onRsvp;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final canRsvp = currentUser.isUser && currentUser.isApproved;
    final details = _DetailsStack(
      event: event,
      insights: insights,
      codeController: codeController,
      submitting: submitting,
      rsvpCreated: rsvpCreated,
      distanceKm: distanceKm,
      onRsvp: onRsvp,
      canRsvp: canRsvp,
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CinematicHero(event: event, insights: insights, aspectRatio: 0.86),
          const SizedBox(height: 12),
          _LiveStatusStrip(insights: insights),
          const SizedBox(height: 12),
          details,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _CinematicHero(
                event: event,
                insights: insights,
                aspectRatio: 0.8,
              ),
              const SizedBox(height: 14),
              _LiveStatusStrip(insights: insights),
            ],
          ),
        ),
        const SizedBox(width: 22),
        Expanded(flex: 4, child: details),
      ],
    );
  }
}

class _DetailsStack extends StatelessWidget {
  const _DetailsStack({
    required this.event,
    required this.insights,
    required this.codeController,
    required this.submitting,
    required this.rsvpCreated,
    required this.distanceKm,
    required this.onRsvp,
    required this.canRsvp,
  });

  final NightlifeEvent event;
  final EventInsights insights;
  final TextEditingController codeController;
  final bool submitting;
  final bool rsvpCreated;
  final double? distanceKm;
  final VoidCallback onRsvp;
  final bool canRsvp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventSummaryCard(
          event: event,
          distanceKm: distanceKm,
          canRsvp: canRsvp,
        ),
        const SizedBox(height: 12),
        _EventFactsCard(event: event, canRsvp: canRsvp),
        const SizedBox(height: 12),
        _VibeMusicCard(event: event, insights: insights),
        const SizedBox(height: 12),
        _VisualGallerySection(
          title: 'Past Event Highlights',
          subtitle: 'A glimpse of the kind of memories this night can create.',
          images: _NightlifeGalleryData.pastEventHighlights,
        ),
        const SizedBox(height: 12),
        _VisualGallerySection(
          title: 'Venue Experience',
          subtitle:
              'Neon corners, photo spots, cocktails and after-dark energy.',
          images: _NightlifeGalleryData.venueExperience,
        ),
        const SizedBox(height: 12),
        _LocationSection(event: event, distanceKm: distanceKm),
        if (canRsvp) ...[
          const SizedBox(height: 12),
          _PromoterCodeCard(
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

class _CinematicHero extends StatelessWidget {
  const _CinematicHero({
    required this.event,
    required this.insights,
    required this.aspectRatio,
  });

  final NightlifeEvent event;
  final EventInsights insights;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Nightlife Event' : event.title;

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EventPoster(event: event, borderRadius: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _TrendingBadge(label: _detailBadgeLabel(event)),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF5F5F0),
                        fontSize: 26,
                        height: 1.02,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Formatters.eventDate(event.dateTime)} - ${event.venueName.trim().isEmpty ? event.city : event.venueName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStatusStrip extends StatelessWidget {
  const _LiveStatusStrip({required this.insights});

  final EventInsights insights;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (Icons.local_fire_department_outlined, 'Heating Up'),
      (Icons.trending_up, '+${insights.rsvpToday} RSVPs today'),
      (Icons.favorite_border, '${insights.vibeMatch}% vibe match'),
      (Icons.bolt_outlined, 'Crowd building fast'),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return _InsightChip(icon: chip.$1, label: chip.$2);
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: chips.length,
      ),
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.distanceKm,
    required this.canRsvp,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final bool canRsvp;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Nightlife Event' : event.title;
    final area = [
      event.venueName.trim(),
      event.city.trim(),
    ].where((value) => value.isNotEmpty).join(' - ');
    final entry = event.priceText.trim().isEmpty
        ? 'Entry details at venue'
        : event.priceText.trim();

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InsightChip(
                icon: Icons.location_city_outlined,
                label: event.city.trim().isEmpty ? 'Tonight' : event.city,
              ),
              if (distanceKm != null)
                _InsightChip(
                  icon: Icons.near_me_outlined,
                  label: LocationService.instance.formatDistance(distanceKm!),
                ),
              _InsightChip(
                icon: canRsvp ? Icons.lock_open_outlined : Icons.lock_outline,
                label: canRsvp ? 'Guestlist open' : 'Approval required',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          _PremiumInfoLine(
            icon: Icons.schedule,
            title: Formatters.eventDate(event.dateTime),
            subtitle: 'People are already locking their spots for tonight.',
          ),
          _PremiumInfoLine(
            icon: Icons.storefront_outlined,
            title: area.isEmpty ? 'Venue area available soon' : area,
            subtitle: event.address,
          ),
          _PremiumInfoLine(
            icon: Icons.confirmation_number_outlined,
            title: entry,
            subtitle: event.entryRules.trim().isEmpty
                ? 'Final admission follows venue policy.'
                : event.entryRules.trim(),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CrowdIntelligenceCard extends StatelessWidget {
  const _CrowdIntelligenceCard({required this.insights});

  final EventInsights insights;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulseDot(),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  "Tonight's Crowd",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TrendingBadge(label: insights.trendingRank),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CrowdMetric(
                  icon: Icons.groups_2_outlined,
                  label: 'Expected',
                  value: insights.expectedAttendance,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CrowdMetric(
                  icon: Icons.trending_up,
                  label: 'Momentum',
                  value: '+${insights.rsvpToday}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CrowdMetric(
                  icon: Icons.bolt_outlined,
                  label: 'Energy',
                  value: insights.crowdEnergy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnimatedProgressLine(
            label: 'Vibe match',
            value: insights.vibeMatch,
            color: AppTheme.neonViolet,
          ),
          const SizedBox(height: 12),
          for (final type in insights.crowdTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnimatedProgressLine(
                label: type.label,
                value: type.value,
                color: type.label == 'Students'
                    ? AppTheme.accentPink
                    : type.label == 'Professionals'
                    ? const Color(0xFF38BDF8)
                    : AppTheme.neonLime,
              ),
            ),
        ],
      ),
    );
  }
}

class _EventFactsCard extends StatelessWidget {
  const _EventFactsCard({required this.event, required this.canRsvp});

  final NightlifeEvent event;
  final bool canRsvp;

  @override
  Widget build(BuildContext context) {
    final entry = event.priceText.trim().isEmpty
        ? 'At venue'
        : event.priceText.trim();
    final ageLimit = _ageLimitFromRules(event.entryRules);
    final music = event.musicType.trim().isEmpty
        ? 'Music TBA'
        : event.musicType.trim();

    return _GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _FactItem(
              icon: Icons.groups_2_outlined,
              label: 'Entry',
              value: canRsvp ? 'Guestlist' : 'Approval',
            ),
          ),
          const _FactDivider(),
          Expanded(
            child: _FactItem(
              icon: Icons.verified_user_outlined,
              label: 'Age Limit',
              value: ageLimit,
            ),
          ),
          const _FactDivider(),
          Expanded(
            child: _FactItem(
              icon: Icons.local_activity_outlined,
              label: 'Type',
              value: entry,
            ),
          ),
          const _FactDivider(),
          Expanded(
            child: _FactItem(
              icon: Icons.music_note_outlined,
              label: 'Music',
              value: music,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0x12FFFFFF),
    );
  }
}

class _FactItem extends StatelessWidget {
  const _FactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.accentPink),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF5F5F0),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0x40FFFFFF),
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _VibeMusicCard extends StatelessWidget {
  const _VibeMusicCard({required this.event, required this.insights});

  final NightlifeEvent event;
  final EventInsights insights;

  @override
  Widget build(BuildContext context) {
    final music = event.musicType.trim().isEmpty
        ? 'Music details coming soon'
        : event.musicType.trim();
    final mood = event.crowdType.trim().isEmpty
        ? 'Crowd details coming soon'
        : event.crowdType.trim();
    final dressCode = event.entryRules.trim().isEmpty
        ? 'Venue rules apply'
        : event.entryRules.trim();
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vibe Check',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _PremiumInfoLine(
            icon: Icons.music_note_outlined,
            title: music,
            subtitle: 'Music',
          ),
          _PremiumInfoLine(
            icon: Icons.wb_twilight_outlined,
            title: mood,
            subtitle: 'Mood',
          ),
          _PremiumInfoLine(
            icon: Icons.style_outlined,
            title: dressCode,
            subtitle: 'Dress code',
          ),
          if (event.artistText.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _InsightChip(
              icon: Icons.graphic_eq,
              label: event.artistText.trim(),
            ),
          ],
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              event.description,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.42),
            ),
          ],
        ],
      ),
    );
  }
}

class GalleryVisual {
  const GalleryVisual({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.tag,
  });

  final String title;
  final String subtitle;
  final String assetPath;
  final String tag;
}

// ignore: unused_element
class _NightlifeGalleryData {
  // ignore: unused_field
  static const pastEventHighlights = [
    GalleryVisual(
      title: 'Crowd Moments',
      subtitle: 'People, music and memories from the night.',
      assetPath: 'assets/images/nightlife/girl.jpg.jpg',
      tag: 'Social',
    ),
    GalleryVisual(
      title: 'Cocktail Culture',
      subtitle: 'Slow drinks, warm lights and premium energy.',
      assetPath: 'assets/images/nightlife/vibe.jpg.jpg',
      tag: 'Drinks',
    ),
    GalleryVisual(
      title: 'Star Girl Energy',
      subtitle: 'The kind of night people take photos for.',
      assetPath: 'assets/images/nightlife/Stargirl.jpg.jpg',
      tag: 'Mood',
    ),
  ];

  // ignore: unused_field
  static const venueExperience = [
    GalleryVisual(
      title: 'Neon Nights',
      subtitle: 'Aesthetic corners built for after-dark memories.',
      assetPath: 'assets/images/nightlife/lips.jpg.jpg',
      tag: 'Venue',
    ),
    GalleryVisual(
      title: 'After Hours',
      subtitle: 'A bold, late-night vibe for adults only events.',
      assetPath: 'assets/images/nightlife/adults.jpg.jpg',
      tag: '18+',
    ),
    GalleryVisual(
      title: 'Feeling Zone',
      subtitle: 'Lights, colors and a mood that feels different.',
      assetPath: 'assets/images/nightlife/feelings.jpg.jpg',
      tag: 'Neon',
    ),
    GalleryVisual(
      title: 'Special Corners',
      subtitle: 'Photo-worthy details that make the venue memorable.',
      assetPath: 'assets/images/nightlife/fspecial.jpg.jpg',
      tag: 'Iconic',
    ),
  ];
}

// ignore: unused_element
class _VisualGallerySection extends StatelessWidget {
  const _VisualGallerySection({
    required this.title,
    required this.subtitle,
    required this.images,
  });

  final String title;
  final String subtitle;
  final List<GalleryVisual> images;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final cardWidth = mobile ? 214.0 : 236.0;
    final cardHeight = mobile ? 270.0 : 292.0;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulseDot(size: 9),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _TrendingBadge(label: 'VISUALS'),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final visual = images[index];
                return _GalleryImageCard(
                  visual: visual,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () => _openGalleryPreview(context, visual),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openGalleryPreview(BuildContext context, GalleryVisual visual) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      builder: (context) => _GalleryPreviewDialog(visual: visual),
    );
  }
}

class _GalleryImageCard extends StatelessWidget {
  const _GalleryImageCard({
    required this.visual,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final GalleryVisual visual;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onPressed: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: -8,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                visual.assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.elevated.withValues(alpha: 0.88),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.textMuted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Image not found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _MiniVisualTag(label: visual.tag),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visual.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visual.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryPreviewDialog extends StatelessWidget {
  const _GalleryPreviewDialog({required this.visual});

  final GalleryVisual visual;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.9,
              maxScale: 3,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width,
                    maxHeight: size.height,
                  ),
                  child: Image.asset(visual.assetPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.40),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.66),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 12,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.54),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 20,
            child: _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniVisualTag(label: visual.tag),
                  const SizedBox(height: 10),
                  Text(
                    visual.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    visual.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniVisualTag extends StatelessWidget {
  const _MiniVisualTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 13, color: AppTheme.neonLime),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoterCodeCard extends StatelessWidget {
  const _PromoterCodeCard({
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
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Have a promoter code?',
            style: TextStyle(
              color: Color(0xFFF5F5F0),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Using a promoter code helps us track who invited you.',
            style: TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Have a promoter code?',
              hintText: 'Enter promoter code',
              labelStyle: const TextStyle(color: Color(0x66FFFFFF)),
              hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
              prefixIcon: const Icon(Icons.qr_code_2, color: Color(0x66F59E0B)),
              filled: true,
              fillColor: const Color(0xFF141418),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0x12FFFFFF), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0x12FFFFFF), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFF59E0B)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _BookSpotButton(
            submitting: submitting,
            rsvpCreated: rsvpCreated,
            onPressed: submitting || rsvpCreated ? null : onRsvp,
          ),
        ],
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
    final hasCoordinates = latitude != null && longitude != null;
    final address = event.fullAddress.trim().isEmpty
        ? event.address
        : event.fullAddress;

    return _GlassCard(
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
                    color: Colors.white,
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
          else if (kIsWeb && !isGoogleMapsWebSdkReady)
            const _MapUnavailable(message: 'Map preview unavailable')
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StickyBookingBar extends StatelessWidget {
  const _StickyBookingBar({
    required this.event,
    required this.canRsvp,
    required this.submitting,
    required this.rsvpCreated,
    required this.onRsvp,
  });

  final NightlifeEvent event;
  final bool canRsvp;
  final bool submitting;
  final bool rsvpCreated;
  final VoidCallback onRsvp;

  @override
  Widget build(BuildContext context) {
    final entry = event.priceText.trim().isEmpty
        ? 'Entry details at venue'
        : event.priceText.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xF0141418),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF5F5F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canRsvp ? 'Limited spots tonight' : 'Approval required',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x40FFFFFF),
                    fontSize: 11,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: _BookSpotButton(
              compact: true,
              submitting: submitting,
              rsvpCreated: rsvpCreated,
              onPressed: !canRsvp || submitting || rsvpCreated
                  ? null
                  : onRsvp,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookSpotButton extends StatelessWidget {
  const _BookSpotButton({
    required this.submitting,
    required this.rsvpCreated,
    required this.onPressed,
    this.compact = false,
  });

  final bool submitting;
  final bool rsvpCreated;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onPressed: onPressed,
      child: SizedBox(
        height: compact ? 46 : 50,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Color(0xFF080809),
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  rsvpCreated ? Icons.check_circle_outline : Icons.how_to_reg,
                  size: 18,
                ),
          label: Text(
            submitting
                ? 'BOOKING...'
                : rsvpCreated
                ? 'CONFIRMED'
                : 'BOOK SPOT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: rsvpCreated
                ? const Color(0x1A22C55E)
                : const Color(0xFFF59E0B),
            foregroundColor: rsvpCreated
                ? const Color(0xFF22C55E)
                : const Color(0xFF080809),
            shadowColor: Colors.transparent,
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

String _detailBadgeLabel(NightlifeEvent event) {
  final now = DateTime.now();
  final eventDate = event.dateTime;
  final sameDay =
      eventDate.year == now.year &&
      eventDate.month == now.month &&
      eventDate.day == now.day;
  if (sameDay) return 'Tonight';

  final price = event.priceText.trim().toLowerCase();
  final free =
      price.isEmpty ||
      price.contains('free') ||
      price.contains('guest') ||
      price == '0' ||
      price.contains('rs 0') ||
      price.contains('inr 0');
  if (free && price.contains('free')) return 'Free Entry';
  if (free) return 'Guestlist';
  return 'Featured';
}

String _ageLimitFromRules(String rules) {
  final value = rules.toLowerCase();
  if (value.contains('21+')) return '21+';
  if (value.contains('18+')) return '18+';
  if (value.contains('adult')) return '18+';
  return 'Venue';
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return Container(
      padding: EdgeInsets.all(mobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

class _PremiumInfoLine extends StatelessWidget {
  const _PremiumInfoLine({
    required this.icon,
    required this.title,
    this.subtitle,
  });

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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x0DF59E0B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33F59E0B), width: 0.5),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFF59E0B)),
          ),
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
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

class _CrowdMetric extends StatelessWidget {
  const _CrowdMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppTheme.accentPink),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressLine extends StatelessWidget {
  const _AnimatedProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$value%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: normalized),
          duration: const Duration(milliseconds: 720),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                color: color,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryViolet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentPink.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.neonLime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LivePulseBadge extends StatelessWidget {
  const _LivePulseBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.neonLime.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(size: 8),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingBadge extends StatelessWidget {
  const _TrendingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1AF59E0B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x4DF59E0B), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFF59E0B),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({this.size = 10});

  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.neonLime,
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonLime.withValues(
                  alpha: 0.28 + (_controller.value * 0.24),
                ),
                blurRadius: 8 + (_controller.value * 9),
                spreadRadius: 1 + (_controller.value * 3),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _pressed = false),
      onTapUp: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _AliveNightBackdrop extends StatelessWidget {
  const _AliveNightBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ColoredBox(color: Color(0xFF080809)),
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

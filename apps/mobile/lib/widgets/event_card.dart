import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../models/event.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'event_poster.dart';

class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.onRsvp,
    this.compact = false,
    this.distanceKm,
  });

  final NightlifeEvent event;
  final VoidCallback onTap;
  final VoidCallback? onRsvp;
  final bool compact;
  final double? distanceKm;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _saved = false;
  bool _pressed = false;
  StreamSubscription<Set<String>>? _savedSub;

  @override
  void initState() {
    super.initState();
    // Reflect real persisted state and keep it in sync if the event is
    // saved/unsaved elsewhere (e.g. from the Saved screen).
    _savedSub = FirestoreService.instance.savedEventIdsStream().listen((ids) {
      final saved = ids.contains(widget.event.id);
      if (mounted && saved != _saved) setState(() => _saved = saved);
    });
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final mobile = width < 420 || screenWidth < 480;
        final horizontal = width < 560 || widget.compact;
        final card = horizontal
            ? _horizontalCard(context, mobile: mobile)
            : _verticalCard(context);

        return MouseRegion(
          onEnter: (_) => setState(() => _pressed = true),
          onExit: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.992 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget _horizontalCard(BuildContext context, {required bool mobile}) {
    final event = widget.event;
    final posterWidth = mobile ? 118.0 : (widget.compact ? 122.0 : 128.0);
    final minPosterHeight = mobile ? 164.0 : 170.0;

    return _CardShell(
      onTap: widget.onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: posterWidth,
                maxWidth: posterWidth,
                minHeight: minPosterHeight,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(_kCardRadius),
                ),
                child: _PosterStack(event: event, saved: _saved),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 13, 13, mobile ? 14 : 13),
                child: _CardDetails(
                  event: event,
                  distanceKm: widget.distanceKm,
                  saved: _saved,
                  dense: true,
                  mobile: mobile,
                  onSave: _toggleSaved,
                  onPrimary: widget.onRsvp ?? widget.onTap,
                  onDetails: widget.onTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalCard(BuildContext context) {
    final event = widget.event;

    return _CardShell(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8.6,
            child: _PosterStack(event: event, saved: _saved),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _CardDetails(
              event: event,
              distanceKm: widget.distanceKm,
              saved: _saved,
              dense: false,
              mobile: false,
              onSave: _toggleSaved,
              onPrimary: widget.onRsvp ?? widget.onTap,
              onDetails: widget.onTap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSaved() async {
    if (widget.event.id.trim().isEmpty) return;
    final wantSaved = !_saved;
    // Optimistic flip; the stream confirms (or the catch below reverts).
    setState(() => _saved = wantSaved);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(wantSaved ? 'Event saved' : 'Event removed from saves'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
    try {
      if (wantSaved) {
        await FirestoreService.instance.saveEvent(widget.event);
      } else {
        await FirestoreService.instance.unsaveEvent(widget.event.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = !wantSaved);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not update saved events. Please try again.'),
          duration: Duration(milliseconds: 1600),
        ),
      );
    }
  }
}

/// Crisp editorial radius (DESIGN_TOKENS.md §5 — cards are sharp, 2–8px).
const double _kCardRadius = 4;

// ─── Shell ────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kCardRadius),
        splashColor: Colors.transparent,
        highlightColor: AppColors.goldWash,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceEspresso,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: AppColors.goldBorder, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0xB3000000), // soft depth, per design card shadow
                blurRadius: 40,
                spreadRadius: -20,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Card details ─────────────────────────────────────────────────────────────

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.event,
    required this.distanceKm,
    required this.saved,
    required this.dense,
    required this.mobile,
    required this.onSave,
    required this.onPrimary,
    required this.onDetails,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final bool saved;
  final bool dense;
  final bool mobile;
  final VoidCallback onSave;
  final VoidCallback onPrimary;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Untitled Night' : event.title;
    final venue = event.venueName.trim().isEmpty ? event.city : event.venueName;
    final location = event.address.trim().isEmpty ? event.city : event.address;
    final primaryLabel = _isPaid(event) ? 'Buy Tickets' : 'RSVP';
    // Tracked uppercase eyebrow — genre · vibe (design "TECHNO · INTIMATE").
    final eyebrow = _eyebrowLabel(event);
    final tags = <_CardTagData>[
      _CardTagData(_safeLabel(event.priceText, fallback: 'Guestlist')),
      if (event.musicType.trim().isNotEmpty)
        _CardTagData(event.musicType.trim()),
      if (distanceKm != null)
        _CardTagData(
          LocationService.instance.formatDistance(distanceKm!),
          accent: true,
        ),
    ];
    final visibleTags = tags.take(2).toList();
    final hiddenTagCount = tags.length - visibleTags.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.champagne,
                      letterSpacing: 0.22 * 9,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Playfair title, bottom-anchored feel (design card title).
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMedium.copyWith(
                      fontSize: dense ? 18 : 20,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SaveButton(saved: saved, onTap: onSave),
          ],
        ),
        const SizedBox(height: 7),
        _IconLine(icon: Icons.place_outlined, text: '$venue · $location'),
        const SizedBox(height: 5),
        _IconLine(
          icon: Icons.schedule,
          text: Formatters.eventDate(event.dateTime),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in visibleTags)
              _Tag(
                label: tag.label,
                accent: tag.accent,
                maxWidth: mobile ? 96 : 112,
              ),
            if (hiddenTagCount > 0)
              _Tag(
                label: '+$hiddenTagCount',
                maxWidth: mobile ? 46 : 54,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _PrimaryActionButton(
                label: primaryLabel,
                onPressed: onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _GhostActionButton(
                label: 'Details',
                onPressed: onDetails,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _safeLabel(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

// ─── Poster + badge ───────────────────────────────────────────────────────────

class _PosterStack extends StatelessWidget {
  const _PosterStack({required this.event, required this.saved});

  final NightlifeEvent event;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EventPoster(event: event, borderRadius: 0),
        // Date pill — blurred obsidian chip, gold text + gold hairline.
        Positioned(
          left: 12,
          top: 12,
          child: _DatePill(label: _eventBadgeLabel(event)),
        ),
        // Favorite marker — mirrors the card's saved state (design top-right).
        Positioned(
          right: 12,
          top: 12,
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: saved ? AppColors.champagne : AppColors.ivory,
          ),
        ),
      ],
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(100), // full pill (design)
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.champagne,
            fontSize: 9,
            letterSpacing: 0.16 * 9,
          ),
        ),
      ),
    );
  }
}

// ─── Tag data ─────────────────────────────────────────────────────────────────

class _CardTagData {
  const _CardTagData(this.label, {this.accent = false});

  final String label;
  final bool accent;
}

// ─── Save button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: saved ? 'Saved' : 'Save event',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: saved ? AppColors.champagne : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Icon line ────────────────────────────────────────────────────────────────

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBodyDim,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tag pill ─────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    this.accent = false,
    this.maxWidth = 112,
    this.compact = false,
  });

  final String label;
  final bool accent;
  final double maxWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: accent ? AppColors.goldWash : Colors.transparent,
        borderRadius: BorderRadius.circular(100), // pill chips (design §5)
        border: Border.all(
          color: accent ? AppColors.champagne : AppColors.textDisabled,
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: accent ? AppColors.champagne : AppColors.textBody,
          fontSize: 10,
          letterSpacing: 0.14 * 10,
        ),
      ),
    );
  }
}

// ─── Primary action button (ivory fill) ────────────────────────────────────────

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.ivory.withValues(alpha: 0.7)
                : AppColors.ivory,
            borderRadius: BorderRadius.circular(2), // crisp button (design §7)
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(2),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: widget.onPressed,
              child: SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.obsidian,
                      fontSize: 11,
                      letterSpacing: 0.16 * 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Secondary action button (gold ghost outline) ──────────────────────────────

class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.champagne,
        side: const BorderSide(color: AppColors.champagne, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: AppTypography.labelMedium.copyWith(
          fontSize: 11,
          letterSpacing: 0.16 * 11,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Helpers (logic unchanged) ────────────────────────────────────────────────

bool _isPaid(NightlifeEvent event) {
  final value = event.priceText.trim().toLowerCase();
  if (value.isEmpty) return false;
  return !value.contains('free') &&
      !value.contains('guest') &&
      value != '0' &&
      !value.contains('rs 0') &&
      !value.contains('inr 0');
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Tracked uppercase eyebrow — genre · vibe, e.g. "TECHNO · INTIMATE".
/// Falls back to the badge label when the event has no music type.
String _eyebrowLabel(NightlifeEvent event) {
  final music = event.musicType.trim();
  final vibe = event.crowdType.trim();
  if (music.isNotEmpty && vibe.isNotEmpty) return '$music · $vibe';
  if (music.isNotEmpty) return music;
  if (vibe.isNotEmpty) return vibe;
  return _eventBadgeLabel(event);
}

String _eventBadgeLabel(NightlifeEvent event) {
  if (event.artistText.trim().isNotEmpty) return 'Featured';
  if (_isSameDay(event.dateTime, DateTime.now())) return 'Popular';
  final price = event.priceText.trim().toLowerCase();
  if (!_isPaid(event) && price.contains('free')) return 'Free Entry';
  if (!_isPaid(event)) return 'Guestlist';
  return 'Popular';
}

import 'dart:async';

import 'package:flutter/material.dart';

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
                  left: Radius.circular(12),
                ),
                child: _PosterStack(event: event),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 11, 11, mobile ? 12 : 11),
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
            child: _PosterStack(event: event),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
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
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
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
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF5F5F0),
                  letterSpacing: -0.2,
                  height: 1.08,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SaveButton(saved: saved, onTap: onSave),
          ],
        ),
        const SizedBox(height: 7),
        _IconLine(icon: Icons.place_outlined, text: '$venue - $location'),
        const SizedBox(height: 5),
        _IconLine(
          icon: Icons.schedule,
          text: Formatters.eventDate(event.dateTime),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
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
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _GradientActionButton(
                label: primaryLabel,
                onPressed: onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _SubtleActionButton(
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
  const _PosterStack({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EventPoster(event: event, borderRadius: 0),
        Positioned(
          left: 8,
          top: 8,
          child: _ProofBadge(label: _eventBadgeLabel(event)),
        ),
      ],
    );
  }
}

class _ProofBadge extends StatelessWidget {
  const _ProofBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
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
            color: saved
                ? const Color(0xFFF59E0B)
                : const Color(0x4DFFFFFF),
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
        Icon(icon, size: 11, color: const Color(0x4DFFFFFF)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0x66FFFFFF),
              fontSize: 11,
              letterSpacing: 0.1,
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
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0x1AF59E0B)
            : const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: accent
              ? const Color(0x4DF59E0B)
              : const Color(0x1AFFFFFF),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent
              ? const Color(0xFFF59E0B)
              : const Color(0x73FFFFFF),
          fontSize: 10,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Primary action button (solid gold) ───────────────────────────────────────

class _GradientActionButton extends StatefulWidget {
  const _GradientActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<_GradientActionButton> {
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
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: widget.onPressed,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF080809),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
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

// ─── Secondary action button (subtle outline) ─────────────────────────────────

class _SubtleActionButton extends StatelessWidget {
  const _SubtleActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0x80FFFFFF),
        side: const BorderSide(color: Color(0x26FFFFFF), width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
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

String _eventBadgeLabel(NightlifeEvent event) {
  if (event.artistText.trim().isNotEmpty) return 'Featured';
  if (_isSameDay(event.dateTime, DateTime.now())) return 'Popular';
  final price = event.priceText.trim().toLowerCase();
  if (!_isPaid(event) && price.contains('free')) return 'Free Entry';
  if (!_isPaid(event)) return 'Guestlist';
  return 'Popular';
}

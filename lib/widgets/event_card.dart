import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/event.dart';
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontal = width < 560 || widget.compact;
        final card = horizontal
            ? _horizontalCard(context)
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

  Widget _horizontalCard(BuildContext context) {
    final event = widget.event;
    final posterWidth = widget.compact ? 106.0 : 118.0;

    return _CardShell(
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.compact ? 146 : 158,
        child: Row(
          children: [
            SizedBox(
              width: posterWidth,
              height: double.infinity,
              child: EventPoster(event: event, borderRadius: 8),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: _CardDetails(
                  event: event,
                  distanceKm: widget.distanceKm,
                  saved: _saved,
                  dense: true,
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
            child: EventPoster(event: event, borderRadius: 8),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: _CardDetails(
              event: event,
              distanceKm: widget.distanceKm,
              saved: _saved,
              dense: false,
              onSave: _toggleSaved,
              onPrimary: widget.onRsvp ?? widget.onTap,
              onDetails: widget.onTap,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSaved() {
    setState(() => _saved = !_saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_saved ? 'Event saved' : 'Event removed from saves'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.glassSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.event,
    required this.distanceKm,
    required this.saved,
    required this.dense,
    required this.onSave,
    required this.onPrimary,
    required this.onDetails,
  });

  final NightlifeEvent event;
  final double? distanceKm;
  final bool saved;
  final bool dense;
  final VoidCallback onSave;
  final VoidCallback onPrimary;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Untitled Night' : event.title;
    final venue = event.venueName.trim().isEmpty ? event.city : event.venueName;
    final location = event.address.trim().isEmpty ? event.city : event.address;
    final primaryLabel = _isPaid(event) ? 'Book Spot' : 'RSVP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: dense ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dense ? 15 : 16,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SaveButton(saved: saved, onTap: onSave),
          ],
        ),
        const SizedBox(height: 6),
        _IconLine(icon: Icons.place_outlined, text: '$venue - $location'),
        const SizedBox(height: 4),
        _IconLine(
          icon: Icons.schedule,
          text: Formatters.eventDate(event.dateTime),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Tag(label: _safeLabel(event.priceText, fallback: 'Guestlist')),
            if (event.musicType.trim().isNotEmpty) _Tag(label: event.musicType),
            if (distanceKm != null)
              _Tag(
                label: LocationService.instance.formatDistance(distanceKm!),
                accent: true,
              ),
          ],
        ),
        SizedBox(height: dense ? 8 : 10),
        Row(
          children: [
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(primaryLabel),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: onDetails,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Details'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isPaid(NightlifeEvent event) {
    final value = event.priceText.trim().toLowerCase();
    if (value.isEmpty) return false;
    return !value.contains('free') &&
        !value.contains('guest') &&
        value != '0' &&
        !value.contains('rs 0') &&
        !value.contains('inr 0');
  }

  String _safeLabel(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

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
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: saved ? AppTheme.accentPink : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? AppTheme.accentPink.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppTheme.accentPink.withValues(alpha: 0.42)
              : AppTheme.glassBorder,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent ? Colors.white : AppTheme.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

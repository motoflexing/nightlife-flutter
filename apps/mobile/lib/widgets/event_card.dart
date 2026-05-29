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
              child: _PosterStack(event: event),
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
            color: AppTheme.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 12),
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
                maxLines: dense ? (mobile ? 2 : 1) : 1,
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

class _PosterStack extends StatelessWidget {
  const _PosterStack({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EventPoster(event: event, borderRadius: 8),
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
    final color = _badgeColor(label);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

Color _badgeColor(String label) {
  final value = label.toLowerCase();
  if (value.contains('featured')) return AppTheme.paidAccent;
  if (value.contains('tonight')) return const Color(0xFFEF233C);
  if (value.contains('free')) return AppTheme.success;
  if (value.contains('popular')) return AppTheme.neonViolet;
  return AppTheme.accentPink;
}

class _CardTagData {
  const _CardTagData(this.label, {this.accent = false});

  final String label;
  final bool accent;
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: saved ? AppTheme.accentPink : AppTheme.textMuted,
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
            ? AppTheme.accentPink.withValues(alpha: 0.13)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppTheme.accentPink.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.08),
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
            gradient: AppTheme.premiumGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentPink.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onPressed,
              child: SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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

class _SubtleActionButton extends StatelessWidget {
  const _SubtleActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _eventBadgeLabel(NightlifeEvent event) {
  if (_isSameDay(event.dateTime, DateTime.now())) return 'Tonight';
  final price = event.priceText.trim().toLowerCase();
  if (!_isPaid(event) && price.contains('free')) return 'Free Entry';
  if (!_isPaid(event)) return 'Guestlist';
  if (event.artistText.trim().isNotEmpty) return 'Featured';
  return 'Popular';
}

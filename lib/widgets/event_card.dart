import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/event.dart';
import '../services/location_service.dart';
import 'event_poster.dart';

class EventCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final hasEventLocation = event.latitude != null && event.longitude != null;
    final distanceLabel = hasEventLocation
        ? distanceKm == null
              ? event.city
              : LocationService.instance.formatDistance(distanceKm!)
        : 'Location not added';
    final dateText = [
      Formatters.eventDate(event.dateTime),
      if (!hasEventLocation)
        'Location not added'
      else if (distanceKm != null)
        LocationService.instance.formatDistance(distanceKm!),
    ].join(' - ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : width;
            final narrow = cardWidth < 270;
            final posterAspectRatio = narrow ? 16 / 10 : 16 / 9;
            final contentPadding = narrow
                ? const EdgeInsets.fromLTRB(11, 10, 11, 11)
                : const EdgeInsets.all(13);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: posterAspectRatio,
                  child: _Poster(event: event),
                ),
                Padding(
                  padding: contentPadding,
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) {
                      final metaMaxWidth = (contentConstraints.maxWidth - 8)
                          .clamp(96.0, 220.0);
                      final compactMetaMaxWidth =
                          ((contentConstraints.maxWidth - 7) / 2).clamp(
                            82.0,
                            150.0,
                          );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (narrow)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Title(event.title, maxLines: compact ? 1 : 2),
                                const SizedBox(height: 8),
                                _Pill(label: distanceLabel),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _Title(
                                    event.title,
                                    maxLines: compact ? 1 : 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(child: _Pill(label: distanceLabel)),
                              ],
                            ),
                          const SizedBox(height: 8),
                          _IconLine(
                            icon: Icons.place_outlined,
                            text: '${event.venueName} - ${event.address}',
                            maxLines: mobile && !compact ? 2 : 1,
                          ),
                          const SizedBox(height: 5),
                          _IconLine(icon: Icons.schedule, text: dateText),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _Meta(
                                label: event.musicType,
                                maxWidth: compact || narrow
                                    ? compactMetaMaxWidth
                                    : metaMaxWidth,
                              ),
                              _Meta(
                                label: event.priceText,
                                maxWidth: compact || narrow
                                    ? compactMetaMaxWidth
                                    : metaMaxWidth,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: ElevatedButton(
                                    onPressed: onRsvp ?? onTap,
                                    child: const Text(
                                      'RSVP',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: OutlinedButton(
                                    onPressed: onTap,
                                    child: Text(
                                      narrow ? 'Details' : 'Check-in',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {required this.maxLines});

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    return EventPoster(event: event);
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryViolet.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.neonViolet.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.maxWidth});

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.deepPurple.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}

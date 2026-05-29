import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/event.dart';
import '../services/event_image_service.dart';

class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.event,
    this.borderRadius = 8,
    this.showTitle = false,
  });

  final NightlifeEvent event;
  final double borderRadius;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final source = EventImageService.instance.imageSourceFor(event);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PosterImage(source: source, event: event, showTitle: showTitle),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99050509)],
                stops: [0.35, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          if (showTitle)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Text(
                event.title.isEmpty ? 'Nightlife Event' : event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 14),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({
    required this.source,
    required this.event,
    required this.showTitle,
  });

  final EventImageSource source;
  final NightlifeEvent event;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (source.isFallback) {
      return _FallbackPosterAsset(event: event);
    }

    if (source.isNetwork) {
      return Image.network(
        source.path,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const _ImageLoadingPlaceholder();
        },
        errorBuilder: (_, _, _) => _FallbackPosterAsset(event: event),
      );
    }

    return Image.asset(
      source.path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _FallbackPosterAsset(event: event),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface,
            AppTheme.elevated,
            AppTheme.deepPurple.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}

class _FallbackPosterAsset extends StatelessWidget {
  const _FallbackPosterAsset({required this.event});

  final NightlifeEvent event;

  @override
  Widget build(BuildContext context) {
    final path = EventImageService.instance.fallbackPosterFor(event);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14141D), Color(0xFF050509)],
          ),
        ),
      ),
    );
  }
}

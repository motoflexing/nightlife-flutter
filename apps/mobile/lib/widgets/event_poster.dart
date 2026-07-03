import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
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
          // Bottom-up obsidian legibility scrim (DESIGN_TOKENS.md §9).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.obsidianDeep.withValues(alpha: 0.6),
                  AppColors.obsidianDeep,
                ],
                stops: const [0.35, 0.75, 1],
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
                // Playfair title, bottom-anchored over the scrim (design card).
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ivory,
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
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceEspresso, AppColors.obsidian],
        ),
      ),
    );
  }
}

class _FallbackPosterAsset extends StatelessWidget {
  const _FallbackPosterAsset({required this.event});

  final NightlifeEvent event;

  /// The Nocturne card tint gradient (DESIGN_TOKENS.md §9): a tint ∈ {oxblood,
  /// espresso, emerald} fading into obsidian, plus a soft gold radial glow —
  /// used as the poster when there's no photo. The tint is chosen per-event
  /// (stable by id) so a grid of cards shows the design's colour variety.
  Color get _tint {
    const tints = [AppColors.oxblood, AppColors.espresso, AppColors.emerald];
    final index = event.id.hashCode.abs() % tints.length;
    return tints[index];
  }

  @override
  Widget build(BuildContext context) {
    final path = EventImageService.instance.fallbackPosterFor(event);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_tint, AppColors.obsidian],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.6),
              radius: 1.1,
              colors: [
                AppColors.champagne.withValues(alpha: 0.28),
                Colors.transparent,
              ],
              stops: const [0, 0.55],
            ),
          ),
        ),
      ),
    );
  }
}

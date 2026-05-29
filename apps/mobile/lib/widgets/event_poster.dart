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
    final url = EventImageService.instance.imageUrlFor(event);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return _FallbackPoster(event: event, showTitle: showTitle);
            },
            errorBuilder: (_, _, _) =>
                _FallbackPoster(event: event, showTitle: showTitle),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC050509)],
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
                  Colors.black.withValues(alpha: 0.42),
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

class _FallbackPoster extends StatelessWidget {
  const _FallbackPoster({required this.event, required this.showTitle});

  final NightlifeEvent event;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090A10),
            Color(0xFF16111F),
            Color(0xFF31152A),
            Color(0xFF050509),
          ],
          stops: [0, 0.38, 0.72, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PosterGlowPainter()),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: AppTheme.accentPink.withValues(alpha: 0.48),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPink.withValues(alpha: 0.14),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.nightlife,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  event.city.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                if (showTitle) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.title.isEmpty ? 'Nightlife Event' : event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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

class _PosterGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pink = Paint()
      ..color = AppTheme.accentPink.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 92, pink);

    final violet = Paint()
      ..color = AppTheme.neonViolet.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.78),
      118,
      violet,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/event.dart';

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
    final url = event.posterUrl.trim();
    final uri = Uri.tryParse(url);
    final canLoadNetworkImage =
        uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: canLoadNetworkImage
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _FallbackPoster(event: event, showTitle: showTitle),
            )
          : _FallbackPoster(event: event, showTitle: showTitle),
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
            AppTheme.deepPurple,
            AppTheme.primaryViolet,
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
                        color: AppTheme.accentPink.withValues(alpha: 0.28),
                        blurRadius: 24,
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
                    color: AppTheme.neonLime,
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
      ..color = AppTheme.accentPink.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 92, pink);

    final violet = Paint()
      ..color = AppTheme.neonViolet.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.78),
      118,
      violet,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

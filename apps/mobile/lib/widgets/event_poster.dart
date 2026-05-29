import 'dart:math' as math;

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
      return _FallbackPoster(event: event, showTitle: showTitle);
    }

    if (source.isNetwork) {
      return Image.network(
        source.path,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const _ImageLoadingPlaceholder();
        },
        errorBuilder: (_, _, _) =>
            _FallbackPoster(event: event, showTitle: showTitle),
      );
    }

    return Image.asset(
      source.path,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          _FallbackPoster(event: event, showTitle: showTitle),
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

class _FallbackPoster extends StatelessWidget {
  const _FallbackPoster({required this.event, required this.showTitle});

  final NightlifeEvent event;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isEmpty ? 'Nightlife Event' : event.title;
    final city = event.city.trim().isEmpty ? 'Tonight' : event.city.trim();
    final badge = _fallbackBadge(event);
    final style = _AutoPosterStyle.fromEvent(event);

    return Container(
      decoration: BoxDecoration(gradient: style.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _AutoPosterPainter(style: style)),
          Positioned(
            left: style.alignRight ? null : 10,
            right: style.alignRight ? 10 : null,
            top: 10,
            child: _FallbackBadge(label: badge, color: style.badgeColor),
          ),
          Positioned(
            left: style.alignRight ? null : -10,
            right: style.alignRight ? -10 : null,
            top: 38,
            child: Text(
              style.watermark,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.055),
                fontSize: showTitle ? 82 : 54,
                height: 0.9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: style.alignRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  city.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: showTitle ? 2 : 3,
                  textAlign: style.alignRight
                      ? TextAlign.right
                      : TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: showTitle ? 24 : 17,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
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
    );
  }
}

class _AutoPosterStyle {
  const _AutoPosterStyle({
    required this.hash,
    required this.template,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.badgeColor,
    required this.alignRight,
    required this.watermark,
    required this.backgroundGradient,
  });

  final int hash;
  final int template;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color badgeColor;
  final bool alignRight;
  final String watermark;
  final LinearGradient backgroundGradient;

  factory _AutoPosterStyle.fromEvent(NightlifeEvent event) {
    final seed = [
      event.id,
      event.title,
      event.city,
      event.venueName,
      event.musicType,
    ].where((value) => value.trim().isNotEmpty).join('|');
    final hash = seed.codeUnits.fold<int>(17, (value, unit) {
      return 0x1fffffff & (value + unit * 31);
    });
    const palettes = [
      [Color(0xFFFF2D8D), Color(0xFF8B5CF6), Color(0xFFEF233C)],
      [Color(0xFFEF233C), Color(0xFFFF2D8D), Color(0xFFF59E0B)],
      [Color(0xFF8B5CF6), Color(0xFF22D3EE), Color(0xFFFF2D8D)],
      [Color(0xFFF59E0B), Color(0xFFEF233C), Color(0xFF8B5CF6)],
      [Color(0xFF22C55E), Color(0xFF8B5CF6), Color(0xFFFF2D8D)],
    ];
    final palette = palettes[hash.abs() % palettes.length];
    final title = event.title.trim();
    final city = event.city.trim();
    final watermarkSource = title.isNotEmpty
        ? title
        : city.isNotEmpty
        ? city
        : 'Night';
    final words = watermarkSource
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    final watermark = words.isEmpty
        ? 'NL'
        : words.map((word) => word[0].toUpperCase()).join();

    return _AutoPosterStyle(
      hash: hash,
      template: hash.abs() % 5,
      primary: palette[0],
      secondary: palette[1],
      accent: palette[2],
      badgeColor: palette[(hash.abs() + 2) % palette.length],
      alignRight: hash.isEven,
      watermark: watermark,
      backgroundGradient: LinearGradient(
        begin: (hash % 3 == 0) ? Alignment.topRight : Alignment.topLeft,
        end: (hash % 3 == 0) ? Alignment.bottomLeft : Alignment.bottomRight,
        colors: [
          const Color(0xFF050509),
          Color.lerp(const Color(0xFF11111A), palette[1], 0.18)!,
          Color.lerp(const Color(0xFF050509), palette[0], 0.22)!,
          const Color(0xFF020204),
        ],
        stops: const [0, 0.38, 0.72, 1],
      ),
    );
  }
}

class _AutoPosterPainter extends CustomPainter {
  const _AutoPosterPainter({required this.style});

  final _AutoPosterStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGlows(canvas, size);
    switch (style.template) {
      case 0:
        _drawLaserFan(canvas, size);
      case 1:
        _drawDiagonalRibbons(canvas, size);
      case 2:
        _drawOrbitRings(canvas, size);
      case 3:
        _drawEqualizerStage(canvas, size);
      default:
        _drawAuroraWaves(canvas, size);
    }
    _drawParticles(canvas, size);
    _drawCrowd(canvas, size);
  }

  void _drawGlows(Canvas canvas, Size size) {
    final a = _unit(11);
    final b = _unit(29);
    final primaryGlow = Paint()
      ..color = style.primary.withValues(alpha: 0.23)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawCircle(
      Offset(size.width * (0.18 + a * 0.64), size.height * (0.12 + b * 0.28)),
      size.shortestSide * (0.42 + _unit(5) * 0.2),
      primaryGlow,
    );

    final secondaryGlow = Paint()
      ..color = style.secondary.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(
      Offset(size.width * (0.1 + b * 0.42), size.height * (0.58 + a * 0.25)),
      size.shortestSide * (0.5 + _unit(17) * 0.22),
      secondaryGlow,
    );
  }

  void _drawLaserFan(Canvas canvas, Size size) {
    final origin = Offset(
      size.width * (0.35 + _unit(2) * 0.3),
      size.height * 0.2,
    );
    for (var i = -4; i <= 4; i++) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = size.width * (0.01 + _unit(i + 40) * 0.012)
        ..color = (i.isEven ? style.primary : style.secondary).withValues(
          alpha: 0.16,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
      final end = Offset(
        size.width * (0.5 + i * 0.16),
        size.height * (0.86 + _unit(i + 8) * 0.18),
      );
      canvas.drawLine(origin, end, paint);
    }
  }

  void _drawDiagonalRibbons(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (0.12 + i * 0.16 + _unit(i + 5) * 0.05);
      path.moveTo(-size.width * 0.15, y);
      path.cubicTo(
        size.width * 0.25,
        y - size.height * 0.12,
        size.width * 0.65,
        y + size.height * 0.08,
        size.width * 1.15,
        y - size.height * 0.04,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.018 + _unit(i + 15) * 0.022)
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? style.primary : style.accent).withValues(
          alpha: 0.12,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, paint);
    }
  }

  void _drawOrbitRings(Canvas canvas, Size size) {
    final center = Offset(
      size.width * (0.4 + _unit(21) * 0.28),
      size.height * (0.28 + _unit(7) * 0.24),
    );
    for (var i = 0; i < 4; i++) {
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * (0.42 + i * 0.18),
        height: size.height * (0.16 + i * 0.07),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + i * 0.55
        ..color = (i.isEven ? style.secondary : style.primary).withValues(
          alpha: 0.2 - i * 0.025,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((-0.55 + i * 0.34) + _unit(i + 12) * 0.7);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(rect, paint);
      canvas.restore();
    }
  }

  void _drawEqualizerStage(Canvas canvas, Size size) {
    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.06 + i * 0.08);
      final h = size.height * (0.1 + _unit(i + 3) * 0.25);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height * 0.18, size.width * 0.025, h),
        const Radius.circular(20),
      );
      final paint = Paint()
        ..color = (i.isEven ? style.primary : style.secondary).withValues(
          alpha: 0.09 + _unit(i + 18) * 0.1,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawAuroraWaves(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final path = Path();
      final startY = size.height * (0.16 + i * 0.11);
      path.moveTo(0, startY);
      for (var step = 0; step <= 5; step++) {
        final x = size.width * (step / 5);
        final y =
            startY +
            math.sin((step + _unit(i + 24) * 4) * math.pi / 1.8) *
                size.height *
                (0.035 + i * 0.008);
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..strokeCap = StrokeCap.round
        ..color = (i.isEven ? style.accent : style.secondary).withValues(
          alpha: 0.14,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, paint);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (var i = 0; i < 24; i++) {
      final x = size.width * _unit(i + 60);
      final y = size.height * (0.05 + _unit(i + 90) * 0.62);
      final radius = 0.8 + _unit(i + 120) * 2.2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.08 + _unit(i + 130) * 0.1);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawCrowd(Canvas canvas, Size size) {
    final crowdPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    final count = 12 + (style.hash.abs() % 8);
    for (var i = 0; i < count; i++) {
      final x = size.width * (i / (count - 1));
      final height = size.height * (0.07 + _unit(i + 150) * 0.09);
      final rect = Rect.fromLTWH(
        x - size.width * 0.05,
        size.height - height,
        size.width * 0.1,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        crowdPaint,
      );
    }
  }

  double _unit(int salt) {
    final value = math.sin((style.hash + salt * 7919) * 0.00013);
    return (value + 1) / 2;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _fallbackBadge(NightlifeEvent event) {
  final now = DateTime.now();
  final sameDay =
      event.dateTime.year == now.year &&
      event.dateTime.month == now.month &&
      event.dateTime.day == now.day;
  if (sameDay) return 'Tonight';

  final price = event.priceText.trim().toLowerCase();
  final free =
      price.isEmpty ||
      price.contains('free') ||
      price.contains('guest') ||
      price == '0' ||
      price.contains('rs 0') ||
      price.contains('inr 0');
  if (free) return 'Guestlist';
  if (event.artistText.trim().isNotEmpty) return 'Featured';
  return 'Popular';
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class PremiumLoader extends StatefulWidget {
  const PremiumLoader({
    super.key,
    this.message = 'Curating your night...',
    this.compact = false,
    this.size = 58,
  });

  const PremiumLoader.compact({super.key, this.size = 18})
    : message = '',
      compact = true;

  final String message;
  final bool compact;
  final double size;

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.94 + (math.sin(_controller.value * math.pi * 2) * 0.04);
        return Transform.scale(
          scale: pulse,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _PremiumLoaderPainter(progress: _controller.value),
            child: SizedBox.square(dimension: widget.size, child: child),
          ),
        );
      },
      child: Center(
        child: Icon(
          Icons.nightlife,
          size: widget.size * 0.34,
          color: Colors.white,
        ),
      ),
    );

    if (widget.compact) {
      return SizedBox.square(dimension: widget.size, child: ring);
    }

    final message = widget.message.trim().isEmpty
        ? 'Curating your night...'
        : widget.message.trim();

    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppTheme.glassSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ring,
            const SizedBox(height: 14),
            const Text(
              'Nightlife',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumLoaderPainter extends CustomPainter {
  const _PremiumLoaderPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ringRect = Rect.fromCircle(center: center, radius: radius - 4);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          AppTheme.accentPink.withValues(alpha: 0),
          AppTheme.accentPink.withValues(alpha: 0.36),
          AppTheme.neonViolet.withValues(alpha: 0.28),
          AppTheme.accentPink.withValues(alpha: 0),
        ],
      ).createShader(ringRect);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.11);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(progress * math.pi * 2),
        colors: const [
          Colors.transparent,
          AppTheme.accentPink,
          AppTheme.neonViolet,
          Colors.transparent,
        ],
      ).createShader(ringRect);

    canvas.drawCircle(center, radius - 4, trackPaint);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 1.55, false, glowPaint);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 1.45, false, ringPaint);

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.accentPink.withValues(alpha: 0.18),
          AppTheme.neonViolet.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.76));
    canvas.drawCircle(center, radius * 0.62, corePaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

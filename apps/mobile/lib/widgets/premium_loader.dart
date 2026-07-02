import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// Nocturne loading indicator (DESIGN_TOKENS.md §"Feedback states"): a thin
/// champagne ring on a faint gold track — no neon glow. [PremiumLoader.compact]
/// is the inline spinner used inside buttons; the full form adds the espresso
/// card with a Playfair line + tracked caption.
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
      duration: const Duration(milliseconds: 1000),
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
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _PremiumLoaderPainter(progress: _controller.value),
        );
      },
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceEspresso,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ring,
            const SizedBox(height: 16),
            // Playfair brand line (app name stays "Nightlife").
            Text(
              'Nightlife',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              message.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textBodyDim,
                letterSpacing: 0.2 * 11,
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
    final stroke = (size.shortestSide * 0.09).clamp(1.5, 3.0);
    final ringRect = Rect.fromCircle(center: center, radius: radius - stroke);

    // Faint champagne track (design: 1.5px gold @ .3 alpha).
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.champagne.withValues(alpha: 0.3);

    // Solid champagne leading arc that sweeps (design: border-top-color gold).
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.champagne;

    canvas.drawCircle(center, radius - stroke, trackPaint);
    final start = progress * math.pi * 2 - math.pi / 2;
    canvas.drawArc(ringRect, start, math.pi * 0.55, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

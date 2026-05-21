import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<void> showFieryUnlockOverlay(BuildContext context) async {
  final overlay = Overlay.of(context);
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => FieryUnlockOverlay(
      onComplete: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class FieryUnlockOverlay extends StatefulWidget {
  const FieryUnlockOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<FieryUnlockOverlay> createState() => _FieryUnlockOverlayState();
}

class _FieryUnlockOverlayState extends State<FieryUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1450),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete();
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = Curves.easeOutCubic.transform(_controller.value);
            final shake =
                math.sin(progress * math.pi * 18) *
                (1 - progress).clamp(0.0, 1.0) *
                5;

            return Transform.translate(
              offset: Offset(shake, 0),
              child: CustomPaint(
                painter: _FieryUnlockPainter(progress),
                child: Center(
                  child: Opacity(
                    opacity: (1 - (progress - 0.72).clamp(0.0, 0.28) / 0.28)
                        .clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.88 + progress * 0.18,
                      child: Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFFFF6A00,
                            ).withValues(alpha: 0.72),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF2A00,
                              ).withValues(alpha: 0.55),
                              blurRadius: 48,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFFC266,
                              ).withValues(alpha: 0.22),
                              blurRadius: 88,
                              spreadRadius: 20,
                            ),
                          ],
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFFFFD18A),
                              Color(0xFFFF6A00),
                              Color(0xFF7A0F05),
                              Color(0x00100507),
                            ],
                            stops: [0.0, 0.34, 0.66, 1.0],
                          ),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.black,
                          size: 58,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieryUnlockPainter extends CustomPainter {
  const _FieryUnlockPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fadeOut = (1 - (progress - 0.78).clamp(0.0, 0.22) / 0.22).clamp(
      0.0,
      1.0,
    );
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color.lerp(
            const Color(0xE6050508),
            const Color(0xF2A61704),
            progress,
          )!,
          const Color(0xCC160506),
          const Color(0xE6000000),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      overlayPaint..color = overlayPaint.color,
    );

    final flameHeight = size.height * (0.34 + progress * 0.7);
    final flamePath = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * 0.16,
        size.height - flameHeight * 0.46,
        size.width * 0.24,
        size.height - flameHeight * 0.78,
        size.width * 0.43,
        size.height - flameHeight,
      )
      ..cubicTo(
        size.width * 0.58,
        size.height - flameHeight * 0.72,
        size.width * 0.78,
        size.height - flameHeight * 0.62,
        size.width,
        size.height - flameHeight * 0.92,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final flamePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF2508).withValues(alpha: 0.65 * fadeOut),
          const Color(0xFFFF7A00).withValues(alpha: 0.42 * fadeOut),
          const Color(0x00FFC266),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(flamePath, flamePaint);

    final linePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFF8A00).withValues(alpha: 0.24 * fadeOut);
    for (var i = 0; i < 10; i++) {
      final x = size.width * (i / 9);
      canvas.drawLine(
        Offset(x, 0),
        Offset(size.width - x, size.height),
        linePaint,
      );
    }

    for (var i = 0; i < 42; i++) {
      final seed = i * 37.0;
      final baseX = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final rise =
          (progress * (size.height + 120) + seed) % (size.height + 120);
      final y = size.height + 40 - rise;
      final drift = math.sin(progress * 8 + i) * 26;
      final radius = 1.8 + (i % 5) * 0.72;
      final emberPaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFF3B14),
          const Color(0xFFFFC266),
          (i % 7) / 6,
        )!.withValues(alpha: 0.18 + 0.56 * fadeOut);
      canvas.drawCircle(Offset(baseX + drift, y), radius, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FieryUnlockPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

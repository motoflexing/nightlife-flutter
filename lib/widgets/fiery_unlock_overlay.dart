import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

Future<void> showFieryUnlockOverlay(BuildContext context) async {
  final overlay = Overlay.of(context);
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => SuperAdminUnlockOverlay(
      onComplete: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class SuperAdminUnlockOverlay extends StatefulWidget {
  const SuperAdminUnlockOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SuperAdminUnlockOverlay> createState() =>
      _SuperAdminUnlockOverlayState();
}

class _SuperAdminUnlockOverlayState extends State<SuperAdminUnlockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1900),
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
            final value = _controller.value;
            final entrance = Curves.easeOutCubic.transform(
              (value / 0.62).clamp(0.0, 1.0),
            );
            final exit = ((value - 0.74) / 0.26).clamp(0.0, 1.0);
            final opacity = (1 - exit).clamp(0.0, 1.0);
            final glitch = math.sin(value * math.pi * 34) * (1 - value) * 3.5;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(glitch, 0),
                child: CustomPaint(
                  painter: _RestrictedAccessPainter(value),
                  child: Center(
                    child: Transform.scale(
                      scale: 0.92 + entrance * 0.08,
                      child: Opacity(
                        opacity: entrance,
                        child: Container(
                          width: 258,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.glassSurface.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.neonLime.withValues(alpha: 0.7),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPink.withValues(
                                  alpha: 0.34,
                                ),
                                blurRadius: 48,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: AppTheme.neonViolet.withValues(
                                  alpha: 0.26,
                                ),
                                blurRadius: 86,
                                spreadRadius: 18,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => AppTheme
                                    .premiumGradient
                                    .createShader(bounds),
                                child: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  color: Colors.white,
                                  size: 58,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'RESTRICTED ACCESS',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.neonLime,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'SUPER ADMIN',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentPink,
                                      AppTheme.neonViolet,
                                      AppTheme.neonLime.withValues(alpha: 0.86),
                                    ],
                                    stops: [0, entrance.clamp(0.05, 0.9), 1],
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _RestrictedAccessPainter extends CustomPainter {
  const _RestrictedAccessPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xE6000000),
          Color.lerp(
            const Color(0xCC090A10),
            const Color(0xE61E0526),
            progress,
          )!,
          const Color(0xF2050509),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final pulse = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final ringProgress = ((pulse + i * 0.18) % 1).clamp(0.0, 1.0);
      final radius = ringProgress * size.longestSide * 0.52;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppTheme.neonViolet.withValues(
          alpha: (1 - ringProgress) * 0.34,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, radius, paint);
    }

    final streakPaint = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 28; i++) {
      final seed = i * 19.7;
      final y = (math.sin(seed) * 0.5 + 0.5) * size.height;
      final travel =
          (progress * (size.width + 240) + seed * 7) % (size.width + 240);
      final x = travel - 120;
      streakPaint.shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppTheme.accentPink.withValues(alpha: 0.2),
          AppTheme.neonLime.withValues(alpha: 0.36),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(x, y, 120, 1));
      canvas.drawLine(Offset(x, y), Offset(x + 96, y - 18), streakPaint);
    }

    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    if (progress > 0.18 && progress < 0.58) {
      final glitchPaint = Paint()
        ..color = AppTheme.neonLime.withValues(alpha: 0.08);
      final bandY = size.height * (0.28 + math.sin(progress * 44) * 0.18);
      canvas.drawRect(Rect.fromLTWH(0, bandY, size.width, 14), glitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RestrictedAccessPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

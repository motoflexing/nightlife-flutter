import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class NeonScaffold extends StatelessWidget {
  const NeonScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.nightclubGradient),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _NightclubPainter())),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

class _NightclubPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final violetGlow = Paint()
      ..color = AppTheme.primaryViolet.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.34;
    canvas.drawLine(
      Offset(size.width * 0.92, -size.height * 0.08),
      Offset(size.width * 0.26, size.height * 0.92),
      violetGlow,
    );

    final pinkGlow = Paint()
      ..color = AppTheme.accentPink.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 56)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.22;
    canvas.drawLine(
      Offset(size.width * 0.04, size.height * 0.08),
      Offset(size.width * 0.56, size.height * 0.62),
      pinkGlow,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    for (var x = 0.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    final accentPaint = Paint()
      ..color = AppTheme.neonViolet.withValues(alpha: 0.11)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(size.width * 0.08, 0),
      Offset(size.width * 0.52, size.height),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

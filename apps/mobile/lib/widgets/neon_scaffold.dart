import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class NeonScaffold extends StatelessWidget {
  const NeonScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
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
    final topRightRect = Rect.fromCircle(
      center: Offset(size.width * 0.94, size.height * 0.02),
      radius: size.width * 0.68,
    );
    final topRightGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.accentPink.withValues(alpha: 0.14),
          AppTheme.neonViolet.withValues(alpha: 0.055),
          Colors.transparent,
        ],
      ).createShader(topRightRect);
    canvas.drawCircle(
      topRightRect.center,
      topRightRect.width / 2,
      topRightGlow,
    );

    final lowerLeftRect = Rect.fromCircle(
      center: Offset(size.width * 0.04, size.height * 0.58),
      radius: size.width * 0.58,
    );
    final lowerLeftGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.neonViolet.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(lowerLeftRect);
    canvas.drawCircle(
      lowerLeftRect.center,
      lowerLeftRect.width / 2,
      lowerLeftGlow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

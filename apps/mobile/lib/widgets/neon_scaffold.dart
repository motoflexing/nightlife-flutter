import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// App background chrome. Renamed intent for Nocturne: an obsidian canvas with
/// the design's faint corner vignettes — a warm oxblood glow top-right and a
/// cool emerald glow lower-left (DESIGN_TOKENS.md §11), no neon. The class name
/// is kept so existing screens keep compiling.
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
        decoration: const BoxDecoration(color: AppColors.obsidianDeep),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _VignettePainter())),
            SafeArea(child: child),
          ],
        ),
      ),
    );
  }
}

/// The Nocturne canvas vignettes — warm oxblood top-right, cool emerald
/// lower-left, both very faint, fading to transparent.
class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topRightRect = Rect.fromCircle(
      center: Offset(size.width * 0.94, size.height * 0.02),
      radius: size.width * 0.68,
    );
    final topRightGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.oxblood.withValues(alpha: 0.5),
          AppColors.oxblood.withValues(alpha: 0.12),
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
          AppColors.emerald.withValues(alpha: 0.4),
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

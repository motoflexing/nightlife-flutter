import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A raised surface panel. In Nocturne this is a flat espresso card with a gold
/// hairline (DESIGN_TOKENS.md §9) — no glass gradient, no neon glow. The name is
/// kept so existing call sites compile unchanged.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 8,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

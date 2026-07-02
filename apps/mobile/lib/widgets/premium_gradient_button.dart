import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import 'premium_loader.dart';

/// The app's primary call-to-action. In Nocturne this is the ivory-fill button
/// (DESIGN_TOKENS.md §7): warm-white fill, obsidian label, tracked uppercase,
/// crisp corners — no gradient, no glow. Public API is unchanged so existing
/// call sites keep working; [icon] now renders in obsidian alongside the label.
class PremiumGradientButton extends StatelessWidget {
  const PremiumGradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.height = 46,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.62,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2), // crisp CTA (design §7)
          color: enabled
              ? AppColors.ivory
              : const Color(0xFF878684), // disabled muted grey (design §7)
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(2),
            splashColor: Colors.transparent,
            highlightColor: AppColors.obsidian.withValues(alpha: 0.08),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: loading
                    ? const PremiumLoader.compact(
                        key: ValueKey('loading'),
                        size: 19,
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: AppColors.obsidian),
                          const SizedBox(width: 10),
                          Text(
                            label.toUpperCase(),
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.obsidian,
                              fontSize: 12,
                              letterSpacing: 0.16 * 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

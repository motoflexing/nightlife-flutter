import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'premium_loader.dart';

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
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? AppTheme.premiumGradient
              : LinearGradient(
                  colors: [
                    AppTheme.deepPurple.withValues(alpha: 0.75),
                    AppTheme.surface.withValues(alpha: 0.78),
                  ],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.neonViolet.withValues(alpha: 0.34),
                    blurRadius: 18,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppTheme.accentPink.withValues(alpha: 0.18),
                    blurRadius: 22,
                    spreadRadius: -14,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
                          Icon(icon, size: 20, color: Colors.white),
                          const SizedBox(width: 9),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
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

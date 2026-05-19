import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class PremiumGradientButton extends StatelessWidget {
  const PremiumGradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.height = 54,
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
                    blurRadius: 24,
                    spreadRadius: -6,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppTheme.accentPink.withValues(alpha: 0.18),
                    blurRadius: 32,
                    spreadRadius: -14,
                    offset: const Offset(0, 16),
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
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
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
                              fontSize: 15,
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

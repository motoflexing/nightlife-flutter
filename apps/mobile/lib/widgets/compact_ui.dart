import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

EdgeInsets compactScreenPadding(BuildContext context, {double bottom = 24}) {
  final mobile = MediaQuery.sizeOf(context).width < 640;
  return EdgeInsets.fromLTRB(
    mobile ? 12 : 16,
    mobile ? 10 : 16,
    mobile ? 12 : 16,
    bottom,
  );
}

class CompactPanel extends StatelessWidget {
  const CompactPanel({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final panel = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(mobile ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceEspresso,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        splashColor: Colors.transparent,
        highlightColor: AppColors.goldWash,
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

class CompactStatCard extends StatelessWidget {
  const CompactStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.accent = AppColors.champagne,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 640;
    return CompactPanel(
      padding: EdgeInsets.all(mobile ? 11 : 13),
      child: Row(
        children: [
          Container(
            width: mobile ? 30 : 34,
            height: mobile ? 30 : 34,
            decoration: BoxDecoration(
              color: AppColors.goldWash,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.goldBorder, width: 1),
            ),
            child: Icon(icon, color: accent, size: mobile ? 17 : 19),
          ),
          SizedBox(width: mobile ? 10 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Playfair figure — editorial stat value.
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: mobile ? 22 : 25,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                // Tracked uppercase micro-label.
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: mobile ? 10 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompactSectionHeader extends StatelessWidget {
  const CompactSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tracked uppercase eyebrow + trailing gold hairline (design §11).
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.champagne,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: _GoldHairline()),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    );
  }
}

/// The signature gold hairline that flanks section eyebrows — a champagne rule
/// that fades to transparent (design "linear-gradient(90deg, gold, transparent)").
class _GoldHairline extends StatelessWidget {
  const _GoldHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.champagne.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

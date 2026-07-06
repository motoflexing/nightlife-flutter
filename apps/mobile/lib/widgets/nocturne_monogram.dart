import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// The Nocturne "N" monogram medallion — a thin champagne ring around a
/// Playfair "N" (DESIGN_TOKENS.md §11, the brand mark).
///
/// This is the single source of truth for the mark; screens that used to carry
/// their own private `_Monogram` / `_MonogramMedallion` copies now reuse this.
/// The "N" scales with [size] (`fontSize = size * 0.5`), so the historical
/// call sites render identically: 40 → 20, 52 → 26.
///
/// Set [innerRing] for the larger, more ceremonial reveal (splash) — a second,
/// fainter concentric ring inside the outer one.
class NocturneMonogram extends StatelessWidget {
  const NocturneMonogram({
    super.key,
    this.size = 40,
    this.innerRing = false,
  });

  /// Outer diameter of the medallion in logical pixels.
  final double size;

  /// When true, draws a second fainter ring inset from the outer one.
  final bool innerRing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer champagne ring.
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.champagne, width: 1),
            ),
            child: SizedBox(width: size, height: size),
          ),
          if (innerRing)
            Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              ),
            ),
          // Playfair "N".
          Text(
            'N',
            style: AppTypography.headlineMedium.copyWith(
              fontSize: size * 0.5,
              color: AppColors.champagne,
            ),
          ),
        ],
      ),
    );
  }
}

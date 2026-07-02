import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Nocturne typography — Playfair Display for the editorial display/heading
/// voice and Inter for body/UI/labels (our cross-platform substitute for the
/// design's "Helvetica Neue"). Built to `DESIGN_TOKENS.md` §2–§4.
///
/// Rules baked in here:
/// - Only two weights are used: [_regular] (400) and [_medium] (500).
/// - Letter-spacing in the design is expressed in `em`; Flutter's
///   `letterSpacing` is logical px, so every tracked style computes
///   `px = em × fontSize` via [_tracking].
/// - Flutter has no true small-caps. The label styles are the *tracked* half of
///   small-caps; call sites apply `.toUpperCase()` (see [smallCaps]).
abstract final class AppTypography {
  AppTypography._();

  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;

  /// Converts a design `em` letter-spacing to Flutter's logical-px value.
  /// e.g. `.24em` at 14px → `3.36`.
  static double _tracking(double em, double fontSize) => em * fontSize;

  // ── Display / headings — Playfair Display (DESIGN_TOKENS.md §3) ───────────

  static TextStyle get displayLarge => GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: _regular,
        height: 1.05,
        letterSpacing: 0,
        color: AppColors.textHigh,
      );

  static TextStyle get displayMedium => GoogleFonts.playfairDisplay(
        fontSize: 34,
        fontWeight: _regular,
        height: 1.1,
        letterSpacing: 0,
        color: AppColors.textHigh,
      );

  static TextStyle get headlineLarge => GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: _medium,
        height: 1.15,
        letterSpacing: 0,
        color: AppColors.textHigh,
      );

  static TextStyle get headlineMedium => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: _medium,
        height: 1.2,
        letterSpacing: 0,
        color: AppColors.textHigh,
      );

  /// Italic Playfair — the hero voice ("After dark, *by invitation.*").
  /// Pass a base display style to italicize it, e.g.
  /// `AppTypography.italic(AppTypography.displayLarge)`.
  static TextStyle italic(TextStyle base) =>
      base.copyWith(fontStyle: FontStyle.italic);

  // ── Body / UI — Inter (DESIGN_TOKENS.md §3) ──────────────────────────────

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: _medium,
        height: 1.3,
        color: AppColors.textHigh,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: _medium,
        height: 1.35,
        color: AppColors.textHigh,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: _regular,
        height: 1.5,
        color: AppColors.textBody,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: _regular,
        height: 1.5,
        color: AppColors.textBody,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: _regular,
        height: 1.45,
        color: AppColors.textBodyDim,
      );

  // ── Labels — Inter, the signature tracked small-caps (DESIGN_TOKENS.md §4) ─
  // Uppercase intent (apply `.toUpperCase()` at call sites), weight 500, wide
  // tracking. Colors default to low-emphasis caption ivory.

  /// Standard micro-label / eyebrow — 14px, `.24em` tracking.
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: _medium,
        letterSpacing: _tracking(0.24, 14), // 3.36
        height: 1.2,
        color: AppColors.textCaption,
      );

  /// Buttons / denser labels — 12px, `.16em` tracking.
  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: _medium,
        letterSpacing: _tracking(0.16, 12), // 1.92
        height: 1.2,
        color: AppColors.textCaption,
      );

  /// Nav / smallest labels — 11px, `.14em` tracking.
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: _medium,
        letterSpacing: _tracking(0.14, 11), // 1.54
        height: 1.2,
        color: AppColors.textCaption,
      );

  /// Small-caps helper. Flutter has no real small-caps, so the look is
  /// "uppercase text + a tracked label style". This returns the label style;
  /// uppercase the string at the call site: `Text('reserve'.toUpperCase(),
  /// style: AppTypography.smallCaps())`.
  static TextStyle smallCaps([TextStyle? base]) => base ?? labelLarge;

  // ── Assembled TextTheme ──────────────────────────────────────────────────

  /// The full [TextTheme] wired into [ThemeData]. Playfair on the display/
  /// headline slots, Inter on title/body/label slots.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        // displaySmall intentionally maps to headlineLarge's Playfair face so
        // the M3 slot is populated with an on-brand style.
        displaySmall: headlineLarge,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}

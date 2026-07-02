import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Nocturne theme — assembles [AppColors] + [AppTypography] into the app-wide
/// [ThemeData] per `DESIGN_TOKENS.md` (§5 radii, §7 buttons, §8 inputs,
/// §9 cards, §10 sheets/dialogs, §12 icons).
///
/// LEGACY TOKENS: the old neon/glass color constants at the bottom of this
/// class are kept so existing screens compile unchanged during the reskin.
/// Each is `@Deprecated` and aliased to its nearest Nocturne token — migrate
/// call sites to [AppColors] in Phase 2, then delete the aliases.
class AppTheme {
  AppTheme._();

  // ── ThemeData ─────────────────────────────────────────────────────────────

  static ThemeData dark() {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.obsidian,
      canvasColor: AppColors.obsidian,
      textTheme: textTheme,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.champagne,
        onPrimary: AppColors.obsidian,
        secondary: AppColors.champagne,
        onSecondary: AppColors.obsidian,
        surface: AppColors.espresso,
        onSurface: AppColors.textHigh,
        error: AppColors.destructive,
        onError: AppColors.ivory,
      ),

      // AppBar — transparent over obsidian, Playfair title, no elevation.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHigh, size: 22),
        titleTextStyle: AppTypography.headlineMedium,
      ),

      // Cards — espresso-tinted surface, crisp r8, gold hairline border (§9).
      cardTheme: const CardThemeData(
        color: AppColors.surfaceEspresso,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),

      // Inputs — UNDERLINE ONLY (§8): no fill, no box.
      // enabled = ivory .25 · focused = champagne · error = destructive.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textDisabled, width: 1),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.textDisabled, width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.champagne, width: 1),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.destructive, width: 1),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.destructive, width: 1),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.textDisabled.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        labelStyle: AppTypography.labelMedium,
        floatingLabelStyle:
            AppTypography.labelMedium.copyWith(color: AppColors.champagne),
        hintStyle:
            AppTypography.bodyMedium.copyWith(color: AppColors.textDisabled),
        errorStyle:
            AppTypography.labelSmall.copyWith(color: AppColors.destructive),
      ),

      // Primary button — ivory fill, obsidian text, r6, tracked uppercase (§7).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.obsidian,
          disabledBackgroundColor: const Color(0xFF878684),
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // Ghost button — transparent, champagne 1px outline + champagne text (§7).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.champagne,
          side: const BorderSide(color: AppColors.champagne, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // Text button — the destructive/link family (§7). Screens use these for
      // "delete account"-class actions; links can override with champagne.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.destructive,
          textStyle: AppTypography.labelMedium,
        ),
      ),

      // Chips — full pill (r100), gold outline, gold wash when selected (§5).
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.goldWash,
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
        labelStyle:
            AppTypography.labelMedium.copyWith(color: AppColors.textBody),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),

      // Bottom sheet — espresso surface, top corners r22, strong scrim (§10).
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceEspresso,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      // Dialogs — same surface family, r14 (§10).
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceEspresso,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),

      // Dividers — champagne gold hairline (§11).
      dividerTheme: const DividerThemeData(
        color: AppColors.goldHairline,
        thickness: 1,
        space: 0,
      ),

      // Bottom navigation — obsidian bar, champagne selected, tracked labels.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.obsidian,
        selectedItemColor: AppColors.champagne,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.obsidian,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.goldWash,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.champagne
                : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.labelSmall.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.champagne
                : AppColors.textSecondary,
          ),
        ),
      ),

      // Icons — thin-line, low-emphasis by default (§12).
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.champagne,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.espresso,
        contentTextStyle:
            AppTypography.bodySmall.copyWith(color: AppColors.textHigh),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.goldBorder, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── LEGACY TOKENS — deprecated aliases onto the Nocturne palette ──────────
  // Kept so Phase 1 changes no screen files. Every value now points at
  // AppColors; migrate call sites in Phase 2, then delete this section.

  // Base backgrounds
  @Deprecated('Use AppColors.obsidian — Nocturne Phase 2')
  static const Color background = AppColors.obsidian;
  // TODO(nocturne-phase2): verify mapping (old mid-surface between bg and elevated).
  @Deprecated('Use AppColors.surfaceEspresso — Nocturne Phase 2')
  static const Color surface = AppColors.surfaceEspresso;
  @Deprecated('Use AppColors.espresso — Nocturne Phase 2')
  static const Color elevated = AppColors.espresso;
  // TODO(nocturne-phase2): verify mapping (old lightest card surface).
  @Deprecated('Use AppColors.espresso — Nocturne Phase 2')
  static const Color card = AppColors.espresso;

  // Gold accent
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color gold = AppColors.champagne;
  // TODO(nocturne-phase2): verify mapping (old darker gold; goldBright is the
  // gradient partner in Nocturne).
  @Deprecated('Use AppColors.goldBright — Nocturne Phase 2')
  static const Color goldDark = AppColors.goldBright;
  @Deprecated('Use AppColors.goldWash — Nocturne Phase 2')
  static const Color goldSubtle = AppColors.goldWash;
  @Deprecated('Use AppColors.goldBorder — Nocturne Phase 2')
  static const Color goldBorder = AppColors.goldBorder;

  // Text
  @Deprecated('Use AppColors.textHigh — Nocturne Phase 2')
  static const Color textHigh = AppColors.textHigh;
  // TODO(nocturne-phase2): verify mapping (old white .50 mid text).
  @Deprecated('Use AppColors.textBodyDim — Nocturne Phase 2')
  static const Color textMid = AppColors.textBodyDim;
  @Deprecated('Use AppColors.textDisabled — Nocturne Phase 2')
  static const Color textLow = AppColors.textDisabled;
  @Deprecated('Use AppColors.textCaption — Nocturne Phase 2')
  static const Color textMuted = AppColors.textCaption;

  // Borders
  @Deprecated('Use AppColors.goldBorder — Nocturne Phase 2')
  static const Color borderSubtle = AppColors.goldBorder;
  // TODO(nocturne-phase2): verify mapping (old stronger white border).
  @Deprecated('Use AppColors.goldHairline — Nocturne Phase 2')
  static const Color borderMid = AppColors.goldHairline;

  // Semantic
  // TODO(nocturne-phase2): verify mapping — Nocturne has no green status
  // color; the single-accent design renders positive states in champagne.
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color success = AppColors.champagne;
  @Deprecated('Use AppColors.destructive — Nocturne Phase 2')
  static const Color error = AppColors.destructive;
  // TODO(nocturne-phase2): verify mapping — no amber warning token in Nocturne.
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color warning = AppColors.champagne;

  // Legacy neon/glass aliases
  // TODO(nocturne-phase2): verify mapping (all neon accents collapse to gold).
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color primaryViolet = AppColors.champagne;
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color accentPink = AppColors.champagne;
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color neonViolet = AppColors.champagne;
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color paidAccent = AppColors.champagne;
  @Deprecated('Use AppColors.espresso — Nocturne Phase 2')
  static const Color glassSurface = AppColors.espresso;
  @Deprecated('Use AppColors.goldBorder — Nocturne Phase 2')
  static const Color glassBorder = AppColors.goldBorder;
  // TODO(nocturne-phase2): verify mapping (oxblood tint is the nearest
  // "purple" surface in the palette).
  @Deprecated('Use AppColors.surfaceOxblood — Nocturne Phase 2')
  static const Color deepPurple = AppColors.surfaceOxblood;
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color neonPink = AppColors.champagne;
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color neonCyan = AppColors.champagne;
  // TODO(nocturne-phase2): verify mapping (was success-green).
  @Deprecated('Use AppColors.champagne — Nocturne Phase 2')
  static const Color neonLime = AppColors.champagne;

  // Gradients
  /// The Nocturne gold-gradient accent (§7): goldBright → champagne at 135°.
  @Deprecated('Use the gold gradient from Nocturne components — Phase 2')
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [AppColors.goldBright, AppColors.champagne],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // TODO(nocturne-phase2): verify mapping (neutral dark vertical fade).
  @Deprecated('Use obsidian surfaces — Nocturne Phase 2')
  static const LinearGradient nightclubGradient = LinearGradient(
    colors: [AppColors.obsidianDeep, AppColors.obsidian],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @Deprecated('Use the gold gradient from Nocturne components — Phase 2')
  static const LinearGradient goldGradient = LinearGradient(
    colors: [AppColors.goldBright, AppColors.champagne],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

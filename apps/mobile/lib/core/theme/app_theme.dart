import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // --- Base backgrounds ---
  static const Color background     = Color(0xFF080809);
  static const Color surface        = Color(0xFF0D0D0F);
  static const Color elevated       = Color(0xFF141418);
  static const Color card           = Color(0xFF1C1C22);

  // --- Gold accent ---
  static const Color gold           = Color(0xFFF59E0B);
  static const Color goldDark       = Color(0xFFD97706);
  static const Color goldSubtle     = Color(0x1AF59E0B);
  static const Color goldBorder     = Color(0x4DF59E0B);

  // --- Text ---
  static const Color textHigh       = Color(0xFFF5F5F0);
  static const Color textMid        = Color(0x80FFFFFF);
  static const Color textLow        = Color(0x40FFFFFF);
  static const Color textMuted      = Color(0x66FFFFFF);

  // --- Borders ---
  static const Color borderSubtle   = Color(0x12FFFFFF);
  static const Color borderMid      = Color(0x1FFFFFFF);

  // --- Semantic ---
  static const Color success        = Color(0xFF22C55E);
  static const Color error          = Color(0xFFEF4444);
  static const Color warning        = Color(0xFFF59E0B);

  // --- Legacy aliases (keep for compatibility) ---
  static const Color primaryViolet  = gold;
  static const Color accentPink     = gold;
  static const Color neonViolet     = gold;
  static const Color paidAccent     = gold;
  static const Color glassSurface   = elevated;
  static const Color glassBorder    = borderSubtle;
  static const Color deepPurple     = surface;
  static const Color neonPink       = gold;
  static const Color neonCyan       = gold;
  static const Color neonLime       = success;

  // --- Gradients ---
  // Kept for any remaining references — neutral dark fade
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF1C1C22), Color(0xFF141418)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient nightclubGradient = LinearGradient(
    colors: [Color(0xFF080809), Color(0xFF0D0D0F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- ThemeData ---
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',

      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: gold,
        surface: surface,
        error: error,
        onPrimary: background,
        onSecondary: background,
        onSurface: textHigh,
        onError: textHigh,
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textHigh),
        titleTextStyle: TextStyle(
          color: textHigh,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.3,
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: background,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textHigh,
          side: const BorderSide(color: borderMid, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderSubtle, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderSubtle, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: gold, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        hintStyle: const TextStyle(
          color: textLow, fontSize: 14),
        errorStyle: const TextStyle(color: error, fontSize: 12),
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: gold,
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 0.5,
        space: 0,
      ),

      // Card
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: borderSubtle, width: 0.5),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: goldSubtle,
        side: const BorderSide(color: borderSubtle, width: 0.5),
        labelStyle: const TextStyle(
          color: textMid, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: textHigh, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

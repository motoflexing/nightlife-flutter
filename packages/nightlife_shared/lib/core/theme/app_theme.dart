import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0B0D14);
  static const Color surface = Color(0xFF181A20);
  static const Color elevated = Color(0xFF20232B);
  static const Color deepPurple = Color(0xFF1E1B4B);
  static const Color primaryViolet = Color(0xFFFF2D55);
  static const Color neonViolet = Color(0xFFA855F7);
  static const Color accentPink = Color(0xFFFF3D8B);
  static const Color textMuted = Color(0xFFB8B8D0);

  static const Color glassSurface = Color(0xCC111827);
  static const Color glassBorder = Color(0x33BFA3FF);

  static const Color neonPink = accentPink;
  static const Color neonCyan = neonViolet;
  static const Color neonLime = Color(0xFFB8FF5C);

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryViolet, accentPink, neonViolet],
  );

  static const LinearGradient nightclubGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [background, Color(0xFF11131B), Color(0xFF050509)],
    stops: [0, 0.54, 1],
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryViolet,
      brightness: Brightness.dark,
      primary: primaryViolet,
      secondary: accentPink,
      surface: surface,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        toolbarHeight: 48,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: glassSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: glassBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xB3171D2D),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: Color(0x99B8B8D0)),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIconConstraints: const BoxConstraints(minWidth: 42),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x332D2368)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: neonViolet, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x262D2368)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentPink),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentPink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryViolet,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: neonViolet.withValues(alpha: 0.45),
          disabledBackgroundColor: const Color(0xFF26213D),
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x66FF3D8B)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentPink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryViolet.withValues(alpha: 0.26);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return textMuted;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: accentPink);
            }
            return const BorderSide(color: Color(0x33FF3D8B));
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: Colors.white),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerBackgroundColor: deepPurple,
        headerForegroundColor: Colors.white,
        dayOverlayColor: WidgetStateProperty.all(
          neonViolet.withValues(alpha: 0.12),
        ),
        todayBorder: const BorderSide(color: neonViolet),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: const Color(0xF20F1118),
        indicatorColor: accentPink.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (_) => const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: neonViolet,
      ),
    );
  }
}

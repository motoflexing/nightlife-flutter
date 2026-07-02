import 'package:flutter/painting.dart';

/// Nocturne color tokens — the single source of truth for every color in the
/// app. Values are taken verbatim from `DESIGN_TOKENS.md` §1 (which was parsed
/// from the design's actual stylesheet). Do not introduce raw hex elsewhere;
/// reference these tokens so a palette change is one edit.
///
/// The system is "dark-first luxury Art Deco": near-black obsidian bases, warm
/// tinted surfaces, a single champagne gold as the primary accent, and ivory —
/// at varying opacity — as the entire text-color system.
abstract final class AppColors {
  AppColors._();

  // ── Core palette (DESIGN_TOKENS.md §1) ──────────────────────────────────

  /// Deepest app background / page base — the darkest surface in the system.
  static const Color obsidianDeep = Color(0xFF0B0B0D);

  /// Primary surface / base background for scaffolds.
  static const Color obsidian = Color(0xFF0E0E10);

  /// Raised card / warm dark surface (espresso brown-black).
  static const Color espresso = Color(0xFF1A1210);

  /// Deep accent + destructive family (oxblood maroon).
  static const Color oxblood = Color(0xFF3A1220);

  /// Secondary accent — deep emerald green.
  static const Color emerald = Color(0xFF12251C);

  /// PRIMARY GOLD — accent, borders, focus, active states, dividers.
  /// The signature color of the whole design language.
  static const Color champagne = Color(0xFFC9A96A);

  /// Brighter gold — used ONLY as the gradient partner for CTAs/highlights
  /// (`linear-gradient(135deg, goldBright, champagne)`), never as a flat fill.
  static const Color goldBright = Color(0xFFD4AF37);

  /// Warm white — primary text at full emphasis AND the primary-button fill.
  static const Color ivory = Color(0xFFF4EFE6);

  /// Destructive / error — text + outline color, offline/error icons.
  static const Color destructive = Color(0xFFC97A7A);

  // ── Tinted card-surface variants (DESIGN_TOKENS.md §1 / §9) ──────────────
  // Subtle oxblood/espresso/emerald-tinted obsidians used as card backgrounds
  // and as the near end of card tint gradients.

  /// Oxblood-tinted obsidian card surface.
  static const Color surfaceOxblood = Color(0xFF17121A);

  /// Espresso-tinted obsidian card surface.
  static const Color surfaceEspresso = Color(0xFF141013);

  /// Emerald-tinted obsidian card surface.
  static const Color surfaceEmerald = Color(0xFF0F1512);

  // ── Text emphasis = ivory at opacity (DESIGN_TOKENS.md §1) ───────────────
  // The entire text-color system is ivory (#F4EFE6) with alpha. Higher opacity
  // = higher emphasis.

  /// Headings / high-emphasis text — full-opacity ivory.
  static const Color textHigh = ivory;

  /// Default body text — ivory at 70%.
  static const Color textBody = Color(0xB3F4EFE6); // .70

  /// Dimmer body / supporting copy — ivory at 55%.
  static const Color textBodyDim = Color(0x8CF4EFE6); // .55

  /// Secondary text / inactive nav — ivory at 45%.
  static const Color textSecondary = Color(0x73F4EFE6); // .45

  /// Captions / meta labels — ivory at 40%.
  static const Color textCaption = Color(0x66F4EFE6); // .40

  /// Disabled text / lowest emphasis — ivory at 25%.
  static const Color textDisabled = Color(0x40F4EFE6); // .25

  // ── Gold at opacity — subtle fills, borders, washes (DESIGN_TOKENS.md §1) ─
  // Champagne (#C9A96A) with alpha, for hairlines and low-key gold surfaces.

  /// Default gold border on cards / ghost buttons — champagne at 22%.
  static const Color goldBorder = Color(0x38C9A96A); // .22

  /// Low-key gold fill / hover wash — champagne at 12%.
  static const Color goldWash = Color(0x1FC9A96A); // .12

  /// Gold hairline divider — champagne at 30%.
  static const Color goldHairline = Color(0x4DC9A96A); // .30

  // ── Overlays (DESIGN_TOKENS.md §10) ──────────────────────────────────────

  /// Modal scrim behind bottom sheets / dialogs — near-opaque black
  /// (`rgba(0,0,0,.95)`), paired with the global vignette.
  static const Color scrim = Color(0xF2000000); // .95
}

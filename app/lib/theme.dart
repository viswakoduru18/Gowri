import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour tokens from the Gowri design (plum, ivory, sage).
class G {
  static const plum = Color(0xFF5B2A4E);
  static const plumDark = Color(0xFF3E1A35);
  static const ink = Color(0xFF2B1F27);
  static const ivory = Color(0xFFFBF8F3);
  static const muted = Color(0xFF7A6C75);
  static const faint = Color(0xFF9A8C95);
  static const tabIdle = Color(0xFF8B7D86);
  static const body = Color(0xFF4D4048);
  static const line = Color(0xFFEFE8E0);
  static const lineStrong = Color(0xFFEAE3DA);
  static const lineInput = Color(0xFFE4DCD3);
  static const dashed = Color(0xFFD9CFC5);
  static const rowDivider = Color(0xFFF3EDE6);
  static const disabled = Color(0xFFC9BFC6);
  static const key = Color(0xFFF5F0EA);
  static const blush = Color(0xFFF1E6EE);
  static const blushText = Color(0xFFF1C6E4);
  static const green = Color(0xFF2E7D5B);
  static const greenDark = Color(0xFF1F4D3A);
  static const greenBg = Color(0xFFE6EFE9);
  static const rust = Color(0xFFB5563A);

  // Stock badges
  static const inStockBg = Color(0xFFE1F0E7);
  static const lowStockBg = Color(0xFFFBEBD2);
  static const lowStockFg = Color(0xFF8A5A12);
  static const outStockBg = Color(0xFFF3E3DE);
}

TextStyle outfit(double size, {FontWeight weight = FontWeight.w400, Color color = G.ink, double? height, double? letterSpacing, TextDecoration? decoration}) =>
    GoogleFonts.outfit(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing, decoration: decoration, decorationColor: color);

TextStyle playfair(double size, {Color color = G.ink, bool italic = false, FontWeight weight = FontWeight.w500, double? height}) =>
    GoogleFonts.playfairDisplay(fontSize: size, color: color, fontStyle: italic ? FontStyle.italic : FontStyle.normal, fontWeight: weight, height: height);

ThemeData gowriTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: G.ivory,
      colorScheme: ColorScheme.fromSeed(seedColor: G.plum, primary: G.plum, surface: G.ivory),
      textTheme: GoogleFonts.outfitTextTheme().apply(bodyColor: G.ink, displayColor: G.ink),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

/// Placeholder tint behind product photos, by category (from the design).
Color tintFor(String category, String sku) {
  const byCategory = {
    'Body': Color(0xFFE9DCE6),
    'Vitamins': Color(0xFFF3E7CF),
    'Herbal': Color(0xFFDCE7DD),
    'Skin': Color(0xFFF6DDD3),
    'Gut': Color(0xFFE4E6EE),
    'Hair': Color(0xFFE6E9D8),
  };
  const fallback = [Color(0xFFE9DCE6), Color(0xFFF3E7CF), Color(0xFFDCE7DD), Color(0xFFF6DDD3), Color(0xFFE4E6EE), Color(0xFFDDE4EC), Color(0xFFF7E9D2)];
  return byCategory[category] ?? fallback[sku.codeUnits.fold(0, (a, b) => a + b) % fallback.length];
}

/// Colours for "Shop by concern" tiles.
({Color bg, Color fg}) concernColors(String name, int index) {
  const known = {
    'Sleep & Stress': (bg: Color(0xFFE9DCE6), fg: Color(0xFF5B2A4E)),
    'Skin & Glow': (bg: Color(0xFFF6DDD3), fg: Color(0xFF8A3F2A)),
    'Immunity': (bg: Color(0xFFF3E7CF), fg: Color(0xFF7A5A16)),
    'Digestion': (bg: Color(0xFFDCE7DD), fg: Color(0xFF1F4D3A)),
  };
  return known[name] ?? known.values.elementAt(index % known.length);
}

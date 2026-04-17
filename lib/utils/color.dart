import 'package:flutter/material.dart';

/// Deterministic color utilities — exact port of webapp's color.js and
/// zaplab_design's npub_color.dart so that profile colors are pixel-identical
/// across all apps for the same npub / string.

/// Convert any string to a Color via a polynomial character-code hash → HSV.
/// Normalizes to uppercase before hashing, same as webapp stringToColor().
Color stringToColor(String value) {
  final normalized = value.trim().toUpperCase();
  if (normalized.isEmpty) return const Color(0xFF808080);

  var number = BigInt.zero;
  for (int i = 0; i < normalized.length; i++) {
    number +=
        BigInt.from(normalized.codeUnitAt(i)) * BigInt.from(256).pow(i);
  }

  final hue = (number % BigInt.from(360)).toInt();
  return _hsvToColor(
    hue,
    s: 0.70,
    vMid: 0.70, // same as color.js stringToColor
  );
}

/// Convert a hex pubkey string to a Color.
/// Matches hexToColor() in color.js and npub_color.dart exactly.
Color hexToColor(String hex) {
  if (hex.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    return const Color(0xFF808080);
  }
  final number = BigInt.parse(hex, radix: 16);
  final hue = (number % BigInt.from(360)).toInt();
  return _hsvToColor(
    hue,
    s: 0.70,
    vMid: 0.75, // same as color.js hexToColor (slightly brighter for hex)
  );
}

/// Shorthand for pubkey → Color. Pass the raw 64-char hex pubkey.
Color pubkeyToColor(String pubkey) => hexToColor(pubkey);

/// Brightens (dark) or darkens (light) a profile color for text readability.
/// Matches getProfileTextColor() in color.js:
///   dark  → factor 1.08 (+8% brightness)
///   light → factor 0.95 (−5% brightness)
Color profileTextColor(Color base, {bool isDark = true}) {
  final factor = isDark ? 1.08 : 0.95;
  return Color.fromARGB(
    255,
    (base.red * factor).round().clamp(0, 255),
    (base.green * factor).round().clamp(0, 255),
    (base.blue * factor).round().clamp(0, 255),
  );
}

/// Returns a low-opacity background color for a profile avatar / fallback.
/// alpha = 61 ≈ 24% (0x3D), matching the webapp's rgba(r, g, b, 0.24).
Color profileBgColor(Color base) =>
    Color.fromARGB(61, base.red, base.green, base.blue);

// ─── Internal HSV→RGB conversion ─────────────────────────────────────────────

Color _hsvToColor(int hue, {required double s, required double vMid}) {
  final v = (hue >= 32 && hue <= 204)
      ? vMid
      : (hue >= 216 && hue <= 273)
          ? 0.96
          : 0.90;

  final h = hue / 60.0;
  final c = v * s;
  final x = c * (1.0 - ((h % 2.0) - 1.0).abs());
  final m = v - c;

  double r, g, b;
  if (h < 1) {
    r = c; g = x; b = 0;
  } else if (h < 2) {
    r = x; g = c; b = 0;
  } else if (h < 3) {
    r = 0; g = c; b = x;
  } else if (h < 4) {
    r = 0; g = x; b = c;
  } else if (h < 5) {
    r = x; g = 0; b = c;
  } else {
    r = c; g = 0; b = x;
  }

  return Color.fromARGB(
    255,
    ((r + m) * 255).round(),
    ((g + m) * 255).round(),
    ((b + m) * 255).round(),
  );
}

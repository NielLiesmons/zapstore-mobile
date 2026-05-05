import 'package:flutter/material.dart';

/// App-wide typography.
///
/// Token names are design-level identifiers — the number in the name is the
/// nominal design size, not necessarily the exact rendered pixel value.
/// The "15" and "17" families render at 14.5 px and 16.5 px respectively so
/// they produce visually equivalent results to the webapp CSS counterparts.
///
/// Weight conventions (matching webapp naming):
///   semibold → FontVariation('wght', 700)
///   med      → FontWeight.w500
///   reg      → FontWeight.w400
///
/// Color is intentionally omitted — apply via `.copyWith(color: …)`.
abstract final class LabTextStyles {
  static const String _font = 'Inter';
  static const String _codeFont = 'JetBrains Mono';
  static const _leading = TextLeadingDistribution.even;

  // ── Headings — literal tokens (weight 700 throughout) ────────────────────

  /// Section/screen titles, modal headings, app name hero. Replaces [h1]/[h2].
  static const TextStyle semibold22 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 22,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  /// ALL-CAPS eyebrow label — 13px, wide tracking. Replaces [h3] / [eyebrow].
  static const TextStyle eyebrow13 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 13,
    height: 1.5,
    letterSpacing: 2.2,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  /// ALL-CAPS eyebrow label — compact 11px variant.
  static const TextStyle eyebrow11 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 11,
    height: 1.5,
    letterSpacing: 2.2,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 17 px (rendered at 16.5) ──────────────────────────────────────────────

  static const TextStyle semibold17 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 16.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med17 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 16.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg17 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 16.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 15 px (rendered at 14.5) ──────────────────────────────────────────────

  static const TextStyle semibold15 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 14.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med15 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 14.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg15 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 13 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold13 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med13 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg13 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 11 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold11 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med11 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg11 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 8 px (unchanged — smallest badge / timestamp label) ───────────────────

  static const TextStyle semibold8 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med8 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg8 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Link ──────────────────────────────────────────────────────────────────

  static const TextStyle link = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 14.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── One-off semibold sizes ─────────────────────────────────────────────────

  static const TextStyle semibold18 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 18,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Code ──────────────────────────────────────────────────────────────────

  static const TextStyle code = TextStyle(
    fontFamily: _codeFont,
    fontWeight: FontWeight.w400,
    fontSize: 14.5,
    height: 1.5,
    letterSpacing: 0,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Backward-compat aliases ────────────────────────────────────────────────
  // "bold" aliases kept so any remaining legacy references compile.

  static const TextStyle bold17 = semibold17;
  static const TextStyle bold15 = semibold15;
  static const TextStyle bold13 = semibold13;
  static const TextStyle bold11 = semibold11;
  static const TextStyle bold8 = semibold8;
}

import 'package:flutter/material.dart';

/// App-wide typography.
///
/// Names are literal — the number IS the font size used in the mobile app.
/// These differ slightly from webapp CSS values (which are 1-2px smaller) so
/// that the same design tokens produce visually equivalent results on-screen.
///
/// Weight conventions (matching webapp naming):
///   semibold → FontVariation('wght', 600)
///   med      → FontWeight.w500
///   reg      → FontWeight.w400
///
/// Color is intentionally omitted — apply via `.copyWith(color: …)`.
abstract final class LabTextStyles {
  static const String _font = 'Inter';
  static const String _codeFont = 'JetBrains Mono';
  static const _leading = TextLeadingDistribution.even;

  // ── Headings — literal tokens (weight 700 throughout) ────────────────────

  /// Large display — app name hero, major screen headings. Replaces [h1].
  static const TextStyle semibold24 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 24,
    height: 1.5,
    letterSpacing: 0.7,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  /// Section header — screen titles, modal headings. Replaces [h2].
  static const TextStyle semibold22 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 700)],
    fontSize: 22,
    height: 1.5,
    letterSpacing: 0.7,
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


  // ── 17 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold17 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 17,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med17 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 17,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg17 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 15 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold15 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med15 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg15 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 13 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold13 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med13 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg13 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 11 px ─────────────────────────────────────────────────────────────────

  static const TextStyle semibold11 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med11 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg11 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 11,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── 8 px (unchanged — smallest badge / timestamp label) ───────────────────

  static const TextStyle semibold8 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle med8 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  static const TextStyle reg8 = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w400,
    fontSize: 8,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Link ──────────────────────────────────────────────────────────────────

  static const TextStyle link = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── One-off semibold sizes ─────────────────────────────────────────────────

  static const TextStyle semibold18 = TextStyle(
    fontFamily: _font,
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 18,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Code ──────────────────────────────────────────────────────────────────

  static const TextStyle code = TextStyle(
    fontFamily: _codeFont,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.15,
    leadingDistribution: _leading,
    decoration: TextDecoration.none,
  );

  // ── Backward-compat aliases ────────────────────────────────────────────────
  // "bold" aliases kept so any remaining legacy references compile.

  static const TextStyle bold17 = semibold17;
  static const TextStyle bold15 = semibold15;
  static const TextStyle bold13 = semibold13;
  static const TextStyle bold11 = semibold11;
  static const TextStyle bold8  = semibold8;
}

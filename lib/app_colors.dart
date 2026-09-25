import 'package:flutter/material.dart';

/// Raw palette values from the Whistly theme spec (iteration 6). Seven
/// values total. Do not introduce colors outside this file — every other
/// widget must read [AppSemanticColors] via `AppTheme.of(context)` instead
/// of these raw constants (the two suit tokens are the only ones meant to
/// be used directly, and only for suit glyphs).
class AppColors {
  // ─── The seven spec values ──────────────────────────────────────────
  static const Color bgLight = Color(0xFFF5F1EA); // cream ground
  static const Color bgDark = Color(0xFF0E0E0E); // ink ground
  static const Color mutedLight = Color(0xFF6B6560); // secondary text on cream
  static const Color mutedDark = Color(0xFF918B85); // secondary text on ink
  static const Color suitRed = Color(0xFFD5001C); // hearts + diamonds, both modes
  static const Color suitInkLight = Color(0xFF000000); // spades + clubs, light mode
  static const Color suitInkDark = Color(0xFFFFFFFF); // spades + clubs, dark mode
  static const Color accent = Color(0xFFFF2D4F); // interface only, both modes

  // ─── The eighth value (ALTERATIONS.md round 2, D2) ─────────────────
  // Gold is off-palette on purpose: the Solo Slim crown is the only mark
  // in the app that's an achievement rather than a state, and `accent`
  // is already spoken for. Both ratios are computed against bgLight
  // #F5F1EA / bgDark #0E0E0E under WCAG 1.4.11 non-text contrast (3:1),
  // which both clear — the crown is never the only carrier of the
  // information (D3's popover states it in words too). Do not
  // substitute a brighter gold: every gold bright enough to please on
  // ink (#D4A017 and up) falls below 3:1 on cream.
  static const Color crownLight = Color(0xFFA17A00); // on cream — 3.52:1
  static const Color crownDark = Color(0xFFD4A017); // on ink — 8.13:1

  // ─── Fixed, mode-independent ─────────────────────────────────────────
  static const Color onAccent = Color(0xFF0E0E0E); // text on accent fill, both modes
  // ALTERATIONS.md (round 2) B1.3 — the Lead badge only, never onAccent
  // generally (the primary button, active tab, x2 badge and FAILED
  // result badge all stay black-on-red). White on accent measures
  // 3.66:1 — below WCAG AA's 4.5:1 for the badge's 9px text (the black
  // it replaces was 5.28:1) — a deliberate, accepted choice: the badge
  // is decorative emphasis, and the same information (who's leading) is
  // already carried by row position and the score itself. If this ratio
  // ever needs to pass, deepen the fill to suitRed #D5001C (5.46:1 for
  // white) rather than inventing a new colour.
  static const Color onAccentLead = Color(0xFFFFFFFF); // Lead badge text only
  static const Color transparent = Colors.transparent;
  static const List<Color> confetti = [
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.orange,
    Colors.purple,
  ];
}

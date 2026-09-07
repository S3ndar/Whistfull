import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
///
/// To re-theme the app, change ONLY [primary] and [secondary].
/// Suit colors are intentionally decoupled from the theme so that
/// Hearts/Diamonds always render red and Spades/Clubs always render black.
class AppColors {
  // ─── Theme Colors (change these two to re-skin the app) ───────────
  static const Color primary = Color(0xFF1A5C9B); // Cobalt Sapphire
  static const Color secondary = Color(0xFFE6C280); // Champagne Gold

  // ─── Neutral Palette ─────────────────────────────────────────────
  static const Color background = Color(0xFF080E1A); // Royal Obsidian Navy
  static const Color backgroundAlt = Color(0xFF04070D); // Darker Obsidian Navy
  static const Color surface = Color(0xFF121D33); // Deep Ocean Navy
  static const Color surfaceLight = Color(0xFF1B2C4C); // Lighter Ocean Navy
  static const Color surfaceDim = Color(0xFF0D1525); // Dimmer Ocean Navy
  static const Color darkPanel = Color(0xFF0A1221); // Dark blue banner bg

  // ─── Text Colors ─────────────────────────────────────────────────
  static const Color white = Colors.white;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white38 = Color(0x61FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white05 = Color(0x0DFFFFFF); // Very faint borders
  static const Color black = Colors.black;

  // ─── Semantic / Accent Colors ────────────────────────────────────
  static const Color success = Color(0xFF4CAF50); // Won / positive score
  static const Color error = Color(0xFFFF6B6B); // Lost / negative score / accent
  static const Color danger = Color(0xFFF85149); // Delete / danger zone
  static const Color accentGold = Color(0xFFF2B705); // Amber Gold
  static const Color favoriteGold = Color(0xFFF2B705); // Amber Gold
  static const Color selectedBg = Color(0xFF7A1E31); // Deep Wine Red selected bg
  static const Color infoBlue = Color(0xFF58A6FF); // Counter + button
  static const Color transparent = Colors.transparent;
  static const List<Color> confetti = [
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.orange,
    Colors.purple,
  ];

  // ─── Suit Colors (NEVER change these — game logic depends on them) ─
  static const Color suitRed = Color(0xFFFF0000);
  static const Color suitBlack = Colors.black;

  // ─── Light Mode Palette ───────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F0E8);   // Warm cream/parchment
  static const Color lightSurface = Color(0xFFFFFFFF);      // Pure white cards
  static const Color lightSurfaceAlt = Color(0xFFEDE8DF);   // Slightly warmer panels
  static const Color lightSurfaceDim = Color(0xFFD9D3C7);   // Dim panels/headers
  static const Color lightText = Color(0xFF1C1C1E);          // Near-black text
  static const Color lightTextSecondary = Color(0xFF6B6B6B); // Muted secondary text
  static const Color lightTextTertiary = Color(0xFFAAAAAA);  // Placeholder / disabled
  static const Color lightBorder = Color(0xFFE0D9CE);        // Subtle warm border
  static const Color lightIcon = Color(0xFF3A3A3A);          // Default icon color
  static const Color lightDarkPanel = Color(0xFFEEE9DE);     // Pass-round banner (light)
}

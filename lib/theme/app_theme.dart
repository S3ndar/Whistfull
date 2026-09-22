import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';

/// Semantic, theme-aware colours per the Whistly theme spec (iteration 6).
/// Read them with `AppTheme.of(context)`. There is deliberately no surface/
/// card/panel token — rule 4 of the spec: "No surface fills. Separation is
/// a rule in `line`, never a tint."
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color bg;
  final Color ink; // text, rules, borders
  final Color muted; // secondary text
  final Color line; // all rules/borders — same color as ink
  final Color accent; // interface-only: primary button, active tab, negative score, Lead badge
  final Color onAccent; // text on an accent fill — #0E0E0E in both modes
  final Color suitRed; // hearts + diamonds, both modes
  final Color suitInk; // spades + clubs — black in light, white in dark
  final Color crown; // Solo Slim achievement mark only (ALTERATIONS.md D2) — mode-dependent, off-palette

  const AppSemanticColors({
    required this.bg,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.suitRed,
    required this.suitInk,
    required this.crown,
  });

  static const AppSemanticColors light = AppSemanticColors(
    bg: AppColors.bgLight,
    ink: AppColors.bgDark,
    muted: AppColors.mutedLight,
    line: AppColors.bgDark,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    suitRed: AppColors.suitRed,
    suitInk: AppColors.suitInkLight,
    crown: AppColors.crownLight,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    bg: AppColors.bgDark,
    ink: AppColors.bgLight,
    muted: AppColors.mutedDark,
    line: AppColors.bgLight,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    suitRed: AppColors.suitRed,
    suitInk: AppColors.suitInkDark,
    crown: AppColors.crownDark,
  );

  @override
  AppSemanticColors copyWith({
    Color? bg,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? suitRed,
    Color? suitInk,
    Color? crown,
  }) {
    return AppSemanticColors(
      bg: bg ?? this.bg,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      suitRed: suitRed ?? this.suitRed,
      suitInk: suitInk ?? this.suitInk,
      crown: crown ?? this.crown,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      suitRed: Color.lerp(suitRed, other.suitRed, t)!,
      suitInk: Color.lerp(suitInk, other.suitInk, t)!,
      crown: Color.lerp(crown, other.crown, t)!,
    );
  }
}

/// Helper for reading the current theme's semantic colours.
class AppTheme {
  AppTheme._();

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ??
      AppSemanticColors.dark;
}

/// Convenience accessor.
extension AppThemeAccess on BuildContext {
  AppSemanticColors get appColors => AppTheme.of(this);
}

/// Monospace numeral style per spec §2 — "Monospace (ui-monospace, Menlo)
/// for numerals only: scores, deltas, round indices, records, trick
/// counts." `ui-monospace` isn't a real font family Flutter can resolve;
/// the platform default monospace fits the same brief.
const String kMonoFontFamily = 'monospace';

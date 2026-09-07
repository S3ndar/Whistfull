import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';

/// Semantic, theme-aware colours. Read them with `AppTheme.of(context)`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceDim;
  final Color panel; // was AppColors.darkPanel
  final Color textPrimary; // was AppColors.white
  final Color textSecondary; // was white70
  final Color textMuted; // was white54
  final Color textFaint; // was white38
  final Color textDisabled; // was white24
  final Color border; // was white12 / white10
  final Color borderFaint; // was white05
  final Color success;
  final Color error;
  final Color accentGold;
  final Color scrim; // subtle fill over a surface

  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceDim,
    required this.panel,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.textDisabled,
    required this.border,
    required this.borderFaint,
    required this.success,
    required this.error,
    required this.accentGold,
    required this.scrim,
  });

  static const AppSemanticColors dark = AppSemanticColors(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceLight,
    surfaceDim: AppColors.surfaceDim,
    panel: AppColors.darkPanel,
    textPrimary: AppColors.white,
    textSecondary: AppColors.white70,
    textMuted: AppColors.white54,
    textFaint: AppColors.white38,
    textDisabled: AppColors.white24,
    border: AppColors.white12,
    borderFaint: AppColors.white05,
    success: AppColors.success,
    error: AppColors.error,
    accentGold: AppColors.accentGold,
    scrim: AppColors.white05,
  );

  static const AppSemanticColors light = AppSemanticColors(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    surfaceDim: AppColors.lightSurfaceDim,
    panel: AppColors.lightDarkPanel,
    textPrimary: AppColors.lightText,
    textSecondary: AppColors.lightTextSecondary,
    textMuted: AppColors.lightTextSecondary,
    textFaint: AppColors.lightTextTertiary,
    textDisabled: AppColors.lightTextTertiary,
    border: AppColors.lightBorder,
    borderFaint: AppColors.lightBorder,
    success: AppColors.success,
    error: AppColors.danger,
    // The amber gold accent is illegible on the cream light background;
    // use a darker goldenrod instead for sufficient contrast.
    accentGold: Color(0xFFB8860B),
    scrim: Color(0x0A000000),
  );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceDim,
    Color? panel,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? textDisabled,
    Color? border,
    Color? borderFaint,
    Color? success,
    Color? error,
    Color? accentGold,
    Color? scrim,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      panel: panel ?? this.panel,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      borderFaint: borderFaint ?? this.borderFaint,
      success: success ?? this.success,
      error: error ?? this.error,
      accentGold: accentGold ?? this.accentGold,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderFaint: Color.lerp(borderFaint, other.borderFaint, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
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

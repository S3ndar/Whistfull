# Whistly — project context for Claude Code

Repo: `github.com/S3ndar/Whistfull` (private). Ordered work queue: `PLAN.md`.

A Flutter score tracker for **Colour Whist / Kleurenwiezen** (Belgian whist).
Local-only, no backend, no accounts. Goal: ship to Play Store + App Store with an ad ribbon.

## Stack
- Flutter / Dart, `provider` for state, **Hive** for local persistence (no server)
- Dart package name is **`whistly`** — imports are `package:whistly/...` even though the folder is `Whistfull`

## Layout
```
lib/
  models/       Player, Game, Round (+ Hive .g.dart adapters)
  providers/    GameProvider, PlayerProvider, ThemeProvider, LocalizationProvider
  screens/      active_game, players, history, game_history_detail, player_stats, hierarchy
  widgets/      round_setup_dialog.dart  (the 4-step round entry flow)
  theme/        app_theme.dart  (AppSemanticColors ThemeExtension)
  app_colors.dart, scoring_settings.dart, settings_page.dart, rules_page.dart
```

## Scoring engine
`GameProvider.addRound` is the heart of the app. Contracts: Ask & Join, Trull, Solo,
Abondance, Miserie, Open Miserie, Solo Slim, plus **Rondpas** (all pass → next contract
scores ×2, stacking). Do not "simplify" it without reading `test/game_provider_test.dart`.

`recomputeFromRounds()` is the single source of truth: totals, dealer index and the
pending multiplier are all *derived* from the round list. `undoLastRound()` and
`deleteRound()` rely on this. Never hand-maintain totals again.

## Conventions — follow these
1. **Colours go through the theme.** Use `AppTheme.of(context).<token>` from
   `lib/theme/app_theme.dart`. Tokens: `background, surface, surfaceAlt, surfaceDim,
   panel, textPrimary, textSecondary, textMuted, textFaint, textDisabled, border,
   borderFaint, success, error, accentGold, scrim`.
   Never add a raw `AppColors.white*` / `.surface` / `.background` / `.darkPanel` to a widget —
   those are dark-mode-only and broke light mode before. `AppColors.suitRed`, `suitBlack`,
   `primary`, `secondary`, `selectedBg`, `danger`, `confetti` are intentionally theme-independent
   and may be used directly.
2. **`const` and theme lookups don't mix.** `AppTheme.of(context)` is not a compile-time
   constant. If you put it inside a widget, remove `const` from that widget *and every
   enclosing one*. This is the most common way to break this codebase.
3. **Localisation keys must exist in BOTH maps.** `lib/providers/localization_provider.dart`
   has `_english` and `_dutch` const maps, currently 173 keys each, in parity.
   Duplicate keys in a Dart const map are a compile error. Adding a key to only one map
   silently falls back — always add to both.
4. **Hive schema changes need codegen.** Adding an `@HiveField` means running
   `dart run build_runner build --delete-conflicting-outputs`. Bump nothing by hand.
   New fields must be nullable or defaulted so existing users' data still loads.
5. Never call `Hive.deleteBoxFromDisk` outside `isUnrecoverableHiveError` in
   `lib/utils/hive_recovery.dart` — it destroys all of the user's games.

## Commands
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after any @HiveField change
flutter analyze
flutter test
flutter run
flutter build appbundle --release
```
`verify.ps1` in the repo root runs pub get -> build_runner -> analyze -> test in one
pass and writes everything to `verify_output.txt`.

## Context
`_backup_pre_claude/` holds pristine pre-refactor copies of every changed file — for
*reference only*. Do not restore from it; the current code is intentionally ahead.
Never commit `android/key.properties` or any `*.jks` / `*.keystore` — they are
gitignored and hold signing secrets.

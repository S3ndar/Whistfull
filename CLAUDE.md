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
  models/       Player, Game, GamePlayerRef, Round (+ Hive .g.dart adapters)
  providers/    GameProvider, PlayerProvider, ThemeProvider, LocalizationProvider
  screens/      active_game, players, history, game_history_detail, player_stats, hierarchy
  widgets/      round_setup_dialog.dart  (the 4-step round entry flow)
  theme/        app_theme.dart  (AppSemanticColors ThemeExtension)
  app_colors.dart, scoring_settings.dart, settings_page.dart, rules_page.dart
```

## `Game.players` is `GamePlayerRef`, not `Player`

A game's roster is an id+name snapshot taken at `GameProvider.startGame()` time —
`GamePlayerRef({id, name})`, nothing else. **Never add a mutable/live field to it** (a
favourite flag, `gamesPlayed`, anything from `PlayerProvider`) — that was exactly the bug
(PLAN.md B4): `Game` used to embed full `Player` objects, which Hive serializes as
independent copies (not a live reference), so renaming a player never updated their past
games, and calling `.save()` on one of those embedded copies was fragile (not bound to
`players_box`). Need something live about a player inside a game context (current
`gamesPlayed`, whether they're a favourite)? Look it up from `PlayerProvider`/`players_box`
by `GamePlayerRef.id` — never read it off the ref itself, because it isn't there.

`Game.players` is a *getter*, not a stored field: new games populate `playerRefs`
(`@HiveField(9)`); games saved before this migration have `playerRefs == null` and the
getter falls back to deriving id+name from the legacy embedded `Player` list, now renamed
to `legacyPlayers` (`@HiveField(2)`, nullable, write-only-by-old-code). Don't read
`legacyPlayers` directly — always go through `players`.

`PlayerProvider.incrementGamesPlayed` takes `List<String> playerIds` (not `Player`s) for
the same reason: it looks each one up fresh from `players_box` by id and mutates/saves
*that* instance, rather than trusting whatever was passed in.

## Scoring engine
`GameProvider.addRound` is the heart of the app. Contracts: Ask & Join, Trull, Solo,
Abondance, Miserie, Open Miserie, Solo Slim, plus **Rondpas** (all pass → next contract
scores ×2, stacking). Do not "simplify" it without reading `test/game_provider_test.dart`.

`recomputeFromRounds()` is the single source of truth: totals, dealer index and the
pending multiplier are all *derived* from the round list. `undoLastRound()` and
`deleteRound()` rely on this. Never hand-maintain totals again.

## Theme — spec iteration 6 (neo-brutalist cream/ink/red)

The app was fully re-themed away from the earlier warm gold/navy look. Palette,
type, and component rules live in `lib/theme/app_theme.dart` (tokens) and
`lib/theme/whistly_components.dart` (typography + reusable components:
`WhistlyPrimaryButton`, `WhistlySecondaryButton`, `WhistlyTextAction`,
`WhistlyLeadBadge`, `WhistlyResultBadge`, `WhistlyTabBar`, `WhistlyToggleRow`,
`WhistlyLogoMark`/`WhistlyLogoLockup`). Build new screens through those, not
hand-rolled styling.

- **Seven raw colours, `AppColors`**: `bgLight`/`bgDark`, `mutedLight`/`mutedDark`,
  `suitRed` (hearts+diamonds, both modes), `suitInkLight`/`suitInkDark`
  (spades+clubs), `accent` (`#FF2D4F`, interface-only — primary button, active
  tab, Lead badge, negative scores, text-action underline; never a suit colour).
- **Resolved tokens, `AppSemanticColors`** via `AppTheme.of(context)`: `bg, ink,
  muted, line, accent, onAccent, suitRed, suitInk`. `line` *is* `ink` — there is
  no separate border colour, and deliberately no surface/card/panel token:
  **radius is 0 everywhere, no shadows, no surface fills.** Separation between
  regions is always a 1-2px `line` rule, never a background tint.
- **Type**: Archivo, bundled as a single true variable font asset
  (`assets/fonts/Archivo-Variable.ttf`, `wght` axis 100-900, declared once in
  pubspec.yaml `fonts:`). Build text through `WhistlyText.*`
  (brand/sectionHead/rowTitle/buttonLabel/eyebrow/tabLabel/badge/body), never
  inline `TextStyle`s with a hardcoded family. Numerals (scores, deltas,
  round indices, records, trick counts) are monospace —
  `WhistlyText.screenNumeral`/`.mono`.
  **The 600/800 contrast comes from `fontVariations:
  [FontVariation('wght', ...)]` on each style, not from `fontWeight` alone**
  (PLAN.md B5) — pubspec used to declare this file twice, once per weight,
  which cannot work: `weight:` only picks which *file* answers a request
  when several are declared for one family, it never reaches into a file and
  sets its variable axis, so both "weights" resolved to the same bytes and
  rendered identically. If you add a new `WhistlyText` style, give it a
  `fontVariations` entry or it will silently render at the font's default
  instance (600) regardless of the `fontWeight` you set.
- **One accent per screen region.** A screen has one primary button; almost
  everything else is `ink`/`muted`. Don't recolour a whole row/badge with
  `accent` just for emphasis.

### A real rendering trap, now understood: `Row` + `CrossAxisAlignment.stretch`

`active_game_page.dart`'s bottom action row (`+ Round` / `End`) once used
`Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...])` and,
under headless-Chromium/CanvasKit testing, both buttons silently failed to
paint — zero analyzer or console error, not even a debug-mode overflow
warning. Removing `crossAxisAlignment: CrossAxisAlignment.stretch` (the Row's
default, `center`, is what every other Row in this codebase already uses)
fixed it completely. `stretch` forces every child to satisfy the Row's own
cross-axis (here: vertical) extent exactly; when that Row itself has no
externally-imposed height (this one sits as the last child of a `Column`
inside `SafeArea`/`Scaffold.body`), the forced-equal-height constraint on
children built from `Container`/`Padding` (no explicit height of their own)
can apparently resolve to something that paints nothing, without tripping
either the debug overflow assertion or a caught `FlutterError`. Before
adding `CrossAxisAlignment.stretch` to any `Row` in this codebase again,
verify the fix actually renders — a bespoke tab bar earlier in this same
redesign was misdiagnosed against SafeArea/Material for the same underlying
symptom before this cause was found; that fix (rebuilt on Flutter's
`BottomNavigationBar`) is a fine, more conventional choice regardless and is
not related to this specific `stretch` cause.

## Conventions — follow these
1. **`const` and theme lookups don't mix.** `AppTheme.of(context)` is not a compile-time
   constant. If you put it inside a widget, remove `const` from that widget *and every
   enclosing one*. This is the most common way to break this codebase.
2. **Localisation keys must exist in BOTH maps.** `lib/providers/localization_provider.dart`
   has `_english` and `_dutch` const maps, in parity. Duplicate keys in a Dart const map
   are a compile error. Adding a key to only one map silently falls back — always add to both.
3. **Hive schema changes need codegen.** Adding an `@HiveField` means running
   `dart run build_runner build --delete-conflicting-outputs`. Bump nothing by hand.
   New fields must be nullable or defaulted so existing users' data still loads.
4. Never call `Hive.deleteBoxFromDisk` outside `isUnrecoverableHiveError` in
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
Simulation tests (`test/simulation/`, see the header of each `*_test.dart`):
```
flutter test test/simulation/simulated_games_test.dart --dart-define=SIM_GAMES=500 --dart-define=SIM_SEEDS=10
flutter test test/simulation/ui_simulation_test.dart --dart-define=SIM_UI_GAMES=6 --dart-define=SIM_UI_SEEDS=5
flutter test test/simulation/ui_simulation_test.dart --dart-define=SIM_SEED=2003   # replay one seed
```
A seeded generator writes random scripts (players, favourites, games, rounds, undo/delete,
complete/abandon). `ExpectedWorld` tracks what every page should show, scored by an
independent `ScoringOracle`. `ProviderDriver` runs thousands of games against the
providers; `UiDriver` taps through the real screens and `page_validators.dart` checks what
is rendered. When scoring rules or a screen's layout change on purpose, update the
oracle / the matching view in `expected_state.dart` too.

`verify.ps1` in the repo root runs pub get -> build_runner -> analyze -> test in one
pass and writes everything to `verify_output.txt`.

## Context
`_backup_pre_claude/` holds pristine pre-refactor copies of every changed file — for
*reference only*. Do not restore from it; the current code is intentionally ahead.
Never commit `android/key.properties` or any `*.jks` / `*.keystore` — they are
gitignored and hold signing secrets.

# Whistly — execution plan

Work queue for a Claude Code agent with a working Flutter toolchain.
Repo: `github.com/S3ndar/Whistfull` (private).

`CLAUDE.md` holds the conventions. Read it before your first edit — it is the
authority on how this codebase is written, and this plan does not repeat it.

## What you are walking into

Five phases of changes were applied by an agent that had **no Dart toolchain**:
correctness fixes, a full light/dark theme refactor (~170 colour references), store
build config, AdMob + in-app-purchase integration, and a Hive schema change.

**None of it has ever been compiled.** It is careful hand-written code, doc-verified
where possible, and nothing more. Your first job is to find out what the compiler
thinks. Expect a real error list; that is the expected state, not a sign something
went badly wrong.

Do the steps in order. Each one names the condition that ends it — reach that
condition before moving on.

---

## Step 0 — Orient

Establish ground truth before changing anything. The description above was written
without seeing the repo; trust `git` over it.

```
git status
git log --oneline -20
ls lib/ads lib/billing lib/theme lib/utils
```

Then branch: `git checkout -b verify/compile-pass`

Work in logical commits — one per step below, message naming what it fixed. That
keeps the history reviewable and lets a bad step be dropped on its own.

**Done when:** you can state which of `lib/ads/`, `lib/billing/`, `lib/theme/app_theme.dart`
and `lib/utils/hive_recovery.dart` exist, and whether the working tree is clean.

---

## Step 1 — Green

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

`build_runner` runs **before** `analyze`: `Game` gained three `@HiveField`s (6, 7, 8)
that do not exist in the generated adapter until it runs, and analyze is noisy
without them.

Fix every error, re-running until clean. Four failure classes account for most of
what you will see:

1. **`const` around a runtime theme lookup** — `Const constructors can't evaluate...`.
   Remove `const` from that widget and any enclosing one. Fix forward: keep the theme
   token and drop the `const`. (Reverting to a hardcoded `AppColors.white*` re-breaks
   light mode, which is the bug this refactor exists to fix.)
2. **Missing import** — add `package:whistly/theme/app_theme.dart` or
   `package:whistly/app_colors.dart`.
3. **AdMob / IAP API mismatch.** `lib/ads/` and `lib/billing/` are the least-trusted
   code in the repo. Their symbols were checked against pub.dev docs, which catches
   wrong names and shapes but not wrong lifecycle or sequencing. When one is wrong,
   read the real API docs rather than guessing a signature.
4. **`use_build_context_synchronously`** — the ad and purchase paths touch `context`
   after `await`. Guard with `if (!mounted) return;`.

**Done when:** `flutter analyze` reports 0 errors. Note the remaining warning count.

---

## Step 2 — Tests

```
flutter test
```

`GameProvider` was refactored so `addRound` / `addPassRound` call
`recomputeFromRounds()` instead of hand-maintaining state. The derivation:

- totals = sum of every round's `scoreDeltas` (already stored post-multiplier — summing
  them again after re-applying the multiplier double-counts)
- `dealerIndex = rounds.length % players.length`
- pending multiplier = `2 ^ (trailing consecutive 'Pass' rounds)`

This should be behaviourally identical to the old code. **When a test fails, decide
which side is wrong before editing.** If the test encodes the correct whist rule, fix
the provider. If it encoded the old hand-maintained behaviour and the rule is
unchanged, update the test — and say which you chose and why.

Then add coverage for the new APIs in `test/game_provider_test.dart`:

- `undoLastRound()` restores the exact totals from before that round
- `undoLastRound()` on an empty round list returns `false` and mutates nothing
- undoing a Rondpas round restores the previous multiplier (2 passes → ×4; undo → ×2)
- `deleteRound(index)` on a middle round leaves the remaining totals correct
- `recomputeFromRounds()` is idempotent
- a `Game` with `scoringSnapshot == null` (legacy save) still loads and appears in
  `completedGames`

Replace the stub in `test/widget_test.dart` (`expect(true, isTrue)`) with a smoke test
that pumps the app against a temp-directory Hive and asserts the home screen renders.

**Done when:** `flutter test` is green and every bullet above has a test.

---

## Step 3 — Known-risk sweep

Four things the compiler will not catch. Each was identified during review and left
for someone who can run the code.

**`lib/ads/ad_config.dart` imports `dart:io`**, which breaks `flutter build web`.
`google_mobile_ads` has no web support, so this only matters if a web build is wanted.
Confirm the intent, then either switch to `defaultTargetPlatform` from
`flutter/foundation.dart`, or record that web is out of scope.

**Provider wiring in `main.dart`.** `PurchaseProvider` sets entitlement state on
`AdsProvider` through a shared Hive key plus an explicit setter. Verify the sequencing
actually holds at runtime: buying "Remove ads" must hide every banner without a
restart, and the entitlement must survive an app relaunch.

**Ad behaviour needs a device.** On a real Android device with test ads: the UMP
consent form appears before any ad loads; banners appear on Players, History, Rules and
the active-game list and nowhere else; the FAB never overlaps the banner; the
interstitial fires once per completed game, at most 3 per session, at least 3 minutes
apart. These placement rules exist because accidental ad clicks get small publishers
suspended from AdMob — treat them as constraints, not preferences.

**`completedGames` in `game_provider.dart`** has two branches that both `return true`,
so it reduces to "not the active game". That is deliberate (it preserves legacy games
that predate the `isComplete` field) but reads oddly. Simplify to the single condition
and keep the migration comment.

**Done when:** each of the four has been resolved or explicitly recorded as accepted.

---

## Step 4 — Icons and splash

The launcher icon is still the stock Flutter logo on both platforms; the iOS launch
image is blank. Config for both already sits in `pubspec.yaml`.

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Apple rejects iOS icons with an alpha channel; the config sets `remove_alpha_ios: true`,
so verify the generated 1024×1024 has none.

**Done when:** `flutter build appbundle --release` succeeds and the launcher icon is
the Whistly logo.

---

## Step 5 — CI

`.github/workflows/ci.yml` could not be written by the remote tooling that produced the
rest of this work, so create it:

```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
```

**Done when:** the workflow is committed, pushed, and its first run is green.

---

## Step 6 — Stop `Game` embedding `Player` objects

Deferred from the earlier phases because it needs a compiler and a migration test.

The same `Player` objects are persisted in `players_box` **and** inside every `Game` in
`games_box`. Renaming a player therefore does not update history, and calling
`player.save()` on an embedded object is fragile.

Store player IDs plus a name snapshot taken at game start. This is the largest change
in the plan — do it last, on a green build, and prove with a test that games saved by
the current schema still load afterwards.

**Done when:** `flutter test` is green, a migration test covers loading a pre-change
save, and renaming a player leaves historical games showing the original name.

---

## Human decisions — surface these, do not choose them

- **Final app name and package ID.** Currently `com.example.whistfull`, which Play
  rejects outright and which can never change after the first upload. Needs a trademark
  and store-name availability check. Once chosen it changes in
  `android/app/build.gradle.kts` (`namespace` + `applicationId`), `AndroidManifest.xml`,
  the Kotlin `MainActivity` package path, and the Xcode bundle ID.
- **Upload keystore.** `android/key.properties.example` carries the `keytool` command.
  `key.properties` and `*.jks` are gitignored and belong nowhere near a commit.
- **Privacy policy URL** — mandatory on both stores, doubly so with an ad SDK.
- **Real AdMob IDs and the `whistly_remove_ads` product**, once those accounts exist.
  Everything currently uses Google's official test IDs via `AdConfig.useTestAds`.
- **Play Data Safety form and Apple privacy labels** — must declare what the ad SDK
  collects (device identifiers, approximate location, usage data). Getting this wrong
  is a common takedown reason.
- **Closed testing.** New personal Play developer accounts need 12 testers for 14
  continuous days before production access unlocks. That is wall-clock time; it cannot
  be compressed.

---

## Reporting

After each step: what changed, what passed, what you deliberately left alone.

`_backup_pre_claude/` holds pristine pre-refactor copies for reference. The current code
is intentionally ahead of it — read it to understand what a file used to look like, and
fix forward rather than restoring from it.

Where this plan and the code disagree, the code wins: this was written without a
compiler. Say so when you find such a case.

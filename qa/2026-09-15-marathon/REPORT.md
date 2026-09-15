# Whistly play-test: a 100-round marathon + a mixed old/new-player game

**Date:** 2026-09-15 · **App commit tested:** `9a88740` (main, post PR #4) · **Method:** headless Chromium (Playwright) driving the real release web build, Flutter's accessibility/semantics tree used as the "eyes", scripted to imitate a human tapping through the UI — no direct provider/database access, every action went through the actual widget tree exactly as a finger-tap would.

This file is the entry point. Read it first, then dip into the JSON/JS files it references for raw data. Written so a reviewer with no memory of this session (including a future Claude instance) can pick up the raw data and re-derive every conclusion below without re-running anything.

## TL;DR

- **Game 1 — a 100-round marathon**, 4 players, cycling through all 8 contract types (Ask & Join, Trull, Solo/"Alone", Abondance/"Abundance", 1-player Misery, 2-player Misery, Solo Slim, Open Misery, plus Rondpas passes), with a deliberate ×2→×4→×8 multiplier-stacking segment and two forced edge cases (a failure, an overtrick). **88/100 rounds executed and scored exactly as scripted.** The other 12 are one real, reproducible finding — see below — not scoring bugs; every round, matched or not, was individually verified correct **for what it actually was**, and the running totals stayed internally consistent (zero-sum) through all 100 rounds and the eventual game-end/celebration/history flow.
- **Game 2 — 2 returning + 2 new players** (Anna & Bram carried over from a short first game; Eve & Frank brand new), 9 more rounds mixing old/new pairings as declarer/partner. **Zero errors, every round matched exactly.** Confirmed the thing this scenario exists to test: a player's stats (`Player Stats` page) correctly aggregate across *both* games — 2 games, 1 win, 50% win rate, avg points -0.5 — despite a completely different set of co-players each game. This is the real-world payoff of the B4 `Game`/`Player` decoupling fix from an earlier session.
- **One genuine finding:** submitting a round immediately after the previous one's confirmation, specifically right into a 2-player Misery's extra "1 Player / 2 Players" toggle tap, has a real chance (11/12 in this run) of the toggle-then-declarer tap landing while the *previous* round's now-dismissing bottom sheet still intercepts the touch, silently falling back to the default (1-player) selection instead of erroring. Confirmed both ways: reproduced 11 times at scripted speed, and confirmed **not a scoring bug** — a fully successful, unhurried 2-player Misery (`verify_miserie2.txt`, see below) scored exactly right (`Anna & Chris · Anna +10 Bram -10 Chris +10 Dana -10`). A real human tapping at normal speed is very unlikely to ever hit this window — flagging it as a resilience nice-to-have, not a shipped bug.
- Everything else checked out: dealer rotation (mod 4) stayed correct through 100 rounds and a mid-game undo isn't needed to prove it since the marathon deliberately avoided undo/delete (see "What was deliberately NOT tested this way" below); the suit-strip trick counters summed correctly; the standings' Lead badge and tie-handling held; the score-column overflow fix from the last session (`ConstrainedBox`+`softWrap:false`) held at 3-digit magnitudes (+322/-384 rendered on one line, right-aligned); "100 rounds played" rendered cleanly in History with no truncation; zero JS console errors/exceptions across either game.

## Does it flow well? Is every option covered?

**Flow:** yes, cleanly, including at scale. Nothing about the UI degraded, slowed down visibly, or became harder to use as the round count climbed into the hundreds of points — the standings, round list, and suit strip all held their layout. The one real friction point found is the rapid-fire timing issue above, which is a script-speed artifact more than a human-usability one.

**Coverage:** every contract type and every major flow got exercised at least once correctly (see the matrix below). The one category that needed a *second*, slower attempt to get a clean pass was 2-player Misery — not because it's broken, but because this session's first attempt at it wasn't patient enough with the UI's own dismiss animation.

## Coverage matrix

| Area | Exercised | Where |
|---|---|---|
| Ask & Join (incl. escalation via raised negotiated tricks) | ✅ many times, both games | rounds 1,9,17,25,33,41... (marathon); g2 rounds 1,5,9 |
| Trull (base 9, post PR #4 fix) | ✅ many times, both games | marathon rounds 2,10,18...; g2 rounds 2,6 |
| Solo/"Alone" (incl. one forced overtrick) | ✅, overtrick attempt at round 66 didn't land (see finding) | marathon rounds 3,11,...; g2 round 3 |
| Abondance/"Abundance" | ✅ many times, both games | marathon rounds 4,12,...; g2 round 4 |
| 1-player Misery | ✅ many times | marathon rounds 5,13,21,... |
| 2-player Misery | ✅ once at speed (round 22) + ✅ once slow/isolated (`verify_miserie2.txt`) + ❌ 11 times at speed (fell back to 1-player — see finding) | see `marathon_comparison.json`, `MV02_2p_done.png` |
| Open Misery (1-player) | ✅ many times | marathon rounds 8,16,24... |
| Open Misery (2-player) | ⬜ not exercised this session | — |
| Solo Slim | ✅ many times, both games | marathon rounds 7,15,...; g2 round 7 |
| Rondpas / Pass, incl. ×2→×4→×8 stacking then a real contract at ×8 | ✅ | marathon rounds 41-44; g2 round 8 (single pass, ×2 consumed by round 9) |
| Forced contract failure | ✅ (Ask & Join, round 55) | `marathon_oracle.json` round 55 |
| Forced overtrick | ⚠️ attempted (Solo, round 65/66), stepper click didn't register — scored correctly as a plain success instead | round 66 in `marathon_comparison.json` |
| Score at 3-digit magnitude, no wrap | ✅ (+322 / -384) | `marathon_final.png` |
| End Game → celebration → History, at 100 rounds | ✅ | `marathon_celebration.png`, `marathon_history_after_game1.png` |
| History with 2 games, correct winner/score/round-count per entry | ✅ | `g2_06_history.png` |
| Game recap detail (both an old and a new game) | ✅ | `g2_07_game2_detail.png`, `g2_08_game1_detail.png` |
| Adding new players when the roster is already non-empty | ✅ | `g2_03_players_after_adding_new.png` |
| A returning player's stats aggregating across 2 games with different co-players | ✅ | `g2_10_anna_stats.png` — 2 games, 1 win, 50%, avg -0.5 |
| Dealer rotation staying correct through 100 rounds | ✅ (`Round 101 · Dealer Anna` = 100 % 4 = 0 = Anna) | `marathon_final.png` |
| Undo (last round only) | ⬜ not exercised this session — validated thoroughly in the prior session (this one deliberately skipped it to keep the 100-round run's coordinate risk down; see below) | prior session's report |
| Per-round delete (last round only) | ⬜ same as above | prior session's report |
| Settings, dark mode, language toggle, Rules, Hierarchy | ⬜ not re-exercised this session (already validated twice in prior sessions, unaffected by anything played here) | prior sessions' reports |

## What was deliberately NOT tested this way, and why

Undo and per-round delete were left out of the 100-round marathon on purpose. Both already have a coordinate-sensitive click (undo's confirm dialog, delete's per-row icon) validated carefully in the previous session, with screenshots checked at every step. Baking either into an *unattended*, rapid-fire 100-round script — where, as this run's own Misery-2 finding shows, a single mistimed click has no chance to self-correct until the very next checkpoint — was judged not worth the risk of desyncing the whole run for marginal extra coverage of something already proven. That trade-off is itself worth someone double-checking; it's a judgement call, not a certainty.

## The one real finding, in full

**What:** Selecting "2 Players" for a Misery/Open Misery round, then immediately tapping a declarer, can silently land on the *previous* round's now-closing bottom sheet instead of the new one, if the two actions happen in rapid succession (scripted speed, not human speed). The result isn't an error the user would see — the round still submits successfully, just as a 1-player Misery instead of 2-player.

**Evidence:**
- 11 of 12 attempts in the marathon fell back to 1-player (`marathon_comparison.json`, rounds 6,14,30,38,46,54,62,70,78,86,94 — all show the 1-player delta shape `+15/-5/-5/-5` where a 2-player shape `+10/-10/+10/-10` was intended).
- 1 of 12 (round 22) succeeded — so it's a timing race, not a hard failure.
- The underlying Playwright error, visible in `marathon_run.log` (not copied here — see the session transcript), is literally `<button>CONFIRM ACHIEVEMENT</button> intercepts pointer events` — the *previous* round's now-dismissed confirm button, still mid-animation, blocking the tap meant for the new dialog.
- Given time to breathe (a plain, unhurried, single-round script — `verify_miserie2.txt`, screenshot `MV02_2p_done.png`), 2-player Misery scores exactly right: `Anna & Chris · Anna +10 Bram -10 Chris +10 Dana -10`, matching the formula by hand.

**Severity judgement:** low. A real player taps at human speed (the confirm button's dismiss animation is a few hundred milliseconds; nobody double-taps that fast into a *different* dialog by accident). This is the kind of thing that matters more for future scripted/automated testing of this app than for a real user session. Flagging rather than fixing, since it's not clear a fix is warranted at all — that's a product call, not mine to make unilaterally.

## Files in this directory

- **`REPORT.md`** — this file.
- **`gen_marathon.js`** — generates the 100-round marathon's UI command script *and* an independent "oracle" (a from-scratch reimplementation of every scoring formula in `game_provider.dart`, run in parallel to predict exactly what should happen). Re-run with `node gen_marathon.js` to regenerate `marathon_script.txt` (not included here, but reproducible) and `marathon_oracle.json`.
- **`marathon_oracle.json`** — the oracle's prediction for all 100 rounds: contract, declarer/partner, trump, tricks, computed delta, running totals, multiplier, dealer — after every single round.
- **`marathon_full.txt`** — the exact, complete sequence of `driver.js` commands actually run for game 1 (setup + all 100 rounds + end-game + history check). Concatenation of a hand-written preamble, the generator's output, and a hand-written wrap-up.
- **`marathon_final_tree.json`** — the full Flutter accessibility-tree snapshot at the end of game 1 (100 rounds played, before ending the game).
- **`analyze.js`** — parses one accessibility-tree JSON dump into structured round-row / pass-row records (contract, players, deltas, result).
- **`compare_marathon.js`** — the actual diff: loads all 10 of the marathon's 10-round checkpoint dumps (each captures the ~10 most-recently-rendered round rows — Flutter's `ListView` is virtualized, so a single dump never has all 100; the 10 checkpoints together give complete, non-overlapping coverage of every round), reconstructs what really happened round-by-round, and diffs it against the oracle.
- **`marathon_comparison.json`** — `compare_marathon.js`'s output: which rounds matched, which didn't, and the exact expected-vs-actual deltas for every mismatch.
- **`game2_gen.js`** — same idea as `gen_marathon.js`, for game 2 (short first game with 4 players, then a second game swapping in 2 new players). Has its own inline oracle.
- **`game2_oracle.json`** — the oracle's prediction for both of game 2's games.
- **`game2_full.txt`** — the exact commands run for game 2.
- **`driver.js`** — the Playwright harness both scripts run through (`node driver.js <script.txt> <screenshot-dir>`). Commands: `nav`, `wait`, `screenshot`, `click-semantics-toggle`, `click-text`, `click-xy`, `type`, `key`, `log-tree` (truncated console dump), `dump-tree <name>` (full untruncated accessibility snapshot to a file), `console-errors`, `dump-console <name>`.
- **`screenshots/`** — a representative subset (not everything captured this session — ~25 screenshots total across both runs; these are the ones referenced above):
  - `marathon_r10.png`, `marathon_r50.png`, `marathon_r100.png`, `marathon_final.png`, `marathon_celebration.png`, `marathon_history_after_game1.png`
  - `g2_03_players_after_adding_new.png`, `g2_06_history.png`, `g2_07_game2_detail.png`, `g2_08_game1_detail.png`, `g2_10_anna_stats.png`
  - `MV02_2p_done.png` (the isolated 2-player Misery confirmation)
- **`g2_07_game2_detail_tree.json`, `g2_10_anna_stats_tree.json`** — accessibility-tree dumps backing the game-2 detail and stats screenshots, for anyone who wants the exact text rather than reading it off a PNG.

## How to reproduce or extend this

1. Serve the release web build (`flutter build web --release`, patch `flutter_bootstrap.js`'s `_flutter.loader.load` call to add `config: { canvasKitBaseUrl: "canvaskit/" }` so it uses the bundled CanvasKit instead of fetching from a blocked CDN, then `python3 -m http.server 8080` from `build/web`).
2. `node gen_marathon.js` (or `game2_gen.js`) to regenerate the command script + oracle.
3. Prepend a `nav`/`click-semantics-toggle` preamble and the 4-player setup, append an end-game/history wrap-up (see `marathon_full.txt`/`game2_full.txt` for the exact shape), then `node driver.js <script> <screenshot-dir>`.
4. `node compare_marathon.js` to diff.

Fixing the Misery-2 timing race (if that's judged worth doing) would mean either: giving the bottom sheet's dismiss animation a moment to finish before the next one can open (e.g. an `await Navigator.of(context).push(...)`-style guard, or a short `Future.delayed` before `showModalBottomSheet` re-opens), or making the new sheet's hit-testing take priority over a dismissing one. Neither attempted here — this was a play-test, not a fix.

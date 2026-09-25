// Simulation framework — the runner, the provider-level driver and the
// state checker.
//
// A [SimDriver] knows how to make the app perform one [SimStep]; the
// [SimRunner] feeds every step to both the driver (the app) and the
// [ExpectedWorld] (the ledger), then calls an optional checkpoint so
// the caller can compare them — through provider state
// ([checkProviderState]) or through what is on screen (the UI driver
// plus page_validators.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/player.dart';

import 'expected_state.dart';
import 'sim_harness.dart';
import 'sim_model.dart';

abstract class SimDriver {
  Future<void> execute(SimStep step, ExpectedWorld world);
}

/// Called after every step, once the app and the ledger both applied it.
typedef SimCheckpoint = Future<void> Function(int index, SimStep step);

class SimRunner {
  final SimScript script;
  final ExpectedWorld world;
  final SimDriver driver;

  SimRunner({required this.script, required this.world, required this.driver});

  Future<void> run({SimCheckpoint? checkpoint}) async {
    for (var i = 0; i < script.steps.length; i++) {
      final step = script.steps[i];
      try {
        await driver.execute(step, world);
        world.apply(step);
        if (checkpoint != null) await checkpoint(i, step);
      } on TestFailure catch (e) {
        throw TestFailure('${_context(i)}\n${e.message}');
      }
    }
  }

  /// Everything needed to reproduce a failure: the seed and the steps
  /// leading up to the failing one.
  String _context(int i) {
    final from = i - 8 < 0 ? 0 : i - 8;
    final recent = [
      for (var j = from; j <= i; j++) '  ${j == i ? '>>' : '  '} #$j ${script.steps[j]}',
    ].join('\n');
    return 'Simulation failed at step #$i of ${script.steps.length} (seed ${script.seed}).\n'
        'Replay with --dart-define=SIM_SEED=${script.seed}\n'
        'Last steps:\n$recent';
  }
}

/// App ids are `DateTime.now().millisecondsSinceEpoch` (players, games).
/// Two creations in the same millisecond collide — a second player
/// silently overwrites the first in players_box, and games get out of
/// start order in games_box (keys sort as strings). No human taps that
/// fast; a simulation does, so every creating step waits for the clock
/// to tick first. Busy-wait, not a Future.delayed: it has to work inside
/// testWidgets' fake-async zone too, where timers don't advance on their
/// own.
void waitForNextMillisecond() {
  final start = DateTime.now().millisecondsSinceEpoch;
  while (DateTime.now().millisecondsSinceEpoch == start) {}
}

/// Drives the providers directly — no widgets. Fast enough for hundreds
/// of games per test; pair with [checkProviderState].
class ProviderDriver implements SimDriver {
  final SimHarness h;
  ProviderDriver(this.h);

  Player _player(ExpectedWorld world, String name) =>
      h.players.players.firstWhere((p) => p.id == world.idOf(name));

  @override
  Future<void> execute(SimStep step, ExpectedWorld world) async {
    switch (step) {
      case AddPlayerStep(:final name):
        waitForNextMillisecond();
        await h.players.addPlayer(name);
        world.bindId(name, h.players.players.firstWhere((p) => p.name == name).id);
      case ToggleFavoriteStep(:final name):
        await h.players.toggleFavorite(_player(world, name));
      case StartGameStep(:final seats):
        waitForNextMillisecond();
        h.games.startGame([for (final s in seats) _player(world, s)], settings: h.settings);
      case PlayRoundStep(:final round):
        if (round.contract == Contract.pass) {
          h.games.addPassRound();
        } else {
          h.games.addRound(
            contractType: round.contract.key,
            declarerId: world.idOf(round.declarer!),
            partnerId: round.partner == null ? null : world.idOf(round.partner!),
            tricksWon: round.tricksWon,
            agreedTricks: round.agreedTricks,
            miserieSuccess: round.declarerMiserieSuccess,
            partnerMiserieSuccess: round.partnerMiserieSuccess,
            settings: h.settings,
            trump: round.trump?.key,
          );
        }
      case UndoRoundStep():
        h.games.undoLastRound();
      case DeleteLastRoundStep():
        h.games.deleteRound(h.games.activeGame!.rounds.length - 1);
      case EndGameStep(:final ending):
        final game = h.games.activeGame!;
        if (ending == GameEnding.complete) {
          // Same order as the win dialog's "Back to home" handler.
          await h.players.incrementGamesPlayed(game.players.map((p) => p.id).toList());
          h.games.endGame();
        } else {
          h.games.abandonGame();
        }
    }
  }
}

// ─── Provider-state checker ──────────────────────────────────────────────

/// Compares every piece of provider state against the ledger and returns
/// a human-readable list of mismatches (empty = all good). Collects all
/// of them instead of stopping at the first, so one failure report shows
/// the full extent of a divergence.
List<String> diffProviderState(SimHarness h, ExpectedWorld world) {
  final errors = <String>[];
  void check(bool ok, String what) {
    if (!ok) errors.add(what);
  }

  // Roster.
  final appPlayers = {for (final p in h.players.players) p.name: p};
  check(appPlayers.length == world.players.length,
      'roster size: app ${appPlayers.length}, expected ${world.players.length}');
  for (final e in world.players.values) {
    final p = appPlayers[e.name];
    if (p == null) {
      errors.add('player ${e.name} missing from PlayerProvider');
      continue;
    }
    check(p.id == world.idOf(e.name), '${e.name}: id ${p.id}, expected ${world.idOf(e.name)}');
    check(p.isFavorite == e.isFavorite, '${e.name}: isFavorite ${p.isFavorite}, expected ${e.isFavorite}');
    check(p.gamesPlayed == e.gamesPlayed, '${e.name}: gamesPlayed ${p.gamesPlayed}, expected ${e.gamesPlayed}');
  }
  final appOrder = h.players.players.map((p) => p.name).toList();
  check(_listEq(appOrder, world.rosterOrder), 'roster order: app $appOrder, expected ${world.rosterOrder}');

  // Active game.
  final active = world.activeGame;
  final appActive = h.games.activeGame;
  if (active == null) {
    check(appActive == null, 'app has an active game, expected none');
  } else if (appActive == null) {
    errors.add('app has no active game, expected game #${active.index}');
  } else {
    _diffGame(appActive, active, world, errors, 'active game');
    check(h.games.dealerIndex == active.dealerIndex,
        'active game: dealerIndex ${h.games.dealerIndex}, expected ${active.dealerIndex}');
    check(h.games.currentDealer?.name == active.dealer,
        'active game: dealer ${h.games.currentDealer?.name}, expected ${active.dealer}');
    check(h.games.pointMultiplier == active.pendingMultiplier,
        'active game: multiplier ${h.games.pointMultiplier}, expected ${active.pendingMultiplier}');
  }

  // Ended games, in start order.
  final appEnded = h.games.completedGames;
  final ended = world.endedGames;
  check(appEnded.length == ended.length, 'ended games: app ${appEnded.length}, expected ${ended.length}');
  for (var i = 0; i < appEnded.length && i < ended.length; i++) {
    final g = appEnded[i];
    final e = ended[i];
    final label = 'ended game #${e.index}';
    _diffGame(g, e, world, errors, label);
    check(g.dateEnded != null, '$label: dateEnded is null');
    check(g.isComplete == (e.status == GameStatus.completed),
        '$label: isComplete ${g.isComplete}, expected ${e.status == GameStatus.completed}');
  }

  // Crowns.
  final slims = h.games.soloSlimsByPlayer;
  world.soloSlimCounts.forEach((name, n) {
    final got = slims[world.idOf(name)]?.length ?? 0;
    check(got == n, 'Solo Slim crowns for $name: app $got, expected $n');
  });
  final crownedIds = world.soloSlimCounts.keys.map(world.idOf).toSet();
  for (final id in slims.keys) {
    check(crownedIds.contains(id), 'unexpected Solo Slim crown for player id $id');
  }

  return errors;
}

void _diffGame(Game g, ExpectedGame e, ExpectedWorld world, List<String> errors, String label) {
  void check(bool ok, String what) {
    if (!ok) errors.add('$label: $what');
  }

  final seatNames = g.players.map((p) => p.name).toList();
  check(_listEq(seatNames, e.seats), 'seats $seatNames, expected ${e.seats}');
  check(_listEq(g.players.map((p) => p.id).toList(), e.seats.map(world.idOf).toList()), 'seat ids differ');
  check(g.rounds.length == e.rounds.length, 'round count ${g.rounds.length}, expected ${e.rounds.length}');

  for (var i = 0; i < g.rounds.length && i < e.rounds.length; i++) {
    final r = g.rounds[i];
    final x = e.rounds[i];
    final rl = 'round ${i + 1} (${x.sim})';
    check(r.contractType == x.contract.key, '$rl: contractType ${r.contractType}');
    check(r.dealerId == world.idOf(x.dealer), '$rl: dealerId ${r.dealerId}, expected ${world.idOf(x.dealer)}');
    // A Pass round stores the constructor default (1), not the multiplier
    // in force — harmless, its deltas are all 0 and nothing reads
    // Round.multiplier for display. Only contract rounds are checked.
    if (x.contract != Contract.pass) {
      check(r.multiplier == x.multiplier, '$rl: multiplier ${r.multiplier}, expected ${x.multiplier}');
    }
    check(r.success == x.success, '$rl: success ${r.success}, expected ${x.success}');
    if (x.contract == Contract.pass) {
      check(r.declarerId == world.idOf(x.dealer), '$rl: Pass declarerId should be the dealer');
    } else {
      check(r.declarerId == world.idOf(x.sim.declarer!), '$rl: declarerId ${r.declarerId}');
      check(r.partnerId == (x.sim.partner == null ? null : world.idOf(x.sim.partner!)), '$rl: partnerId ${r.partnerId}');
      check(r.tricksWon == x.sim.tricksWon, '$rl: tricksWon ${r.tricksWon}');
      check(r.agreedTricks == x.sim.agreedTricks, '$rl: agreedTricks ${r.agreedTricks}');
      check(r.trump == x.sim.trump?.key, '$rl: trump ${r.trump}');
    }
    var sum = 0;
    for (final name in e.seats) {
      final got = r.scoreDeltas[world.idOf(name)];
      final want = x.deltas[name];
      sum += got ?? 0;
      check(got == want, '$rl: delta for $name is $got, oracle says $want');
    }
    // Invariant, independent of the oracle: whist is zero-sum.
    check(sum == 0, '$rl: deltas sum to $sum, not 0');
  }

  final totals = e.totals;
  for (final name in e.seats) {
    final got = g.totalScores[world.idOf(name)];
    check(got == totals[name], 'total for $name is $got, expected ${totals[name]}');
  }
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// [diffProviderState] as a test assertion.
void expectProviderState(SimHarness h, ExpectedWorld world) {
  final errors = diffProviderState(h, world);
  if (errors.isNotEmpty) {
    throw TestFailure('Provider state diverged from the simulation ledger '
        '(${errors.length} mismatch${errors.length == 1 ? '' : 'es'}):\n  - ${errors.take(25).join('\n  - ')}');
  }
}

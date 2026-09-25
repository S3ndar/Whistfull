import 'package:whistly/models/game.dart';
import 'package:whistly/models/round.dart';

/// ALTERATIONS.md (round 2) C1 — the stats engine. Pure Dart, no
/// `package:flutter` import: every function here is a reader over
/// `Game`/`Round` and is testable without pumping a frame.
///
/// Three facts about the round log decide this whole file (see C1.1):
/// 1. `contractType == 'Pass'` is a Rondpas, not a contract — nobody
///    declared, every delta is 0. Excluded from every denominator here.
/// 2. In a Miserie, `partnerId` is not a partner — the second player is
///    scored independently against the defenders, and `round.success` is
///    `miserieSuccess && partnerMiserieSuccess`. So one player can have
///    made their Miserie while the round as a whole reads `success:
///    false`. `round.success` is therefore never used to judge an
///    individual player anywhere in this file.
/// 3. `scoreDeltas` carries the per-player truth: a participant who made
///    their contract has a positive delta, one who failed has a negative
///    one (`_applyTeam`/`_applySolo` in `game_provider.dart` guarantee
///    it). That's the only per-player outcome source used here.

/// One contract as declared, round-level. Emitted once per non-Pass
/// round. Answers "how often does this CONTRACT hold?" — as opposed to
/// [Declaration], which answers "how often is this PLAYER right?".
class ContractOutcome {
  final String contractType;
  final bool held; // round.success — the contract as a whole
  const ContractOutcome(this.contractType, this.held);
}

/// One player's stake in one round. Emitted once per participant: the
/// declarer, plus partnerId when non-null (which in a Miserie means a
/// second, independent declarer — exactly why this is per-player and
/// never reads `round.success`).
class Declaration {
  final String playerId;
  final String contractType;
  final bool made; // scoreDeltas[playerId] > 0
  const Declaration(this.playerId, this.contractType, this.made);
}

bool _isContract(Round round) => round.contractType != 'Pass';

/// C1.2 — one [ContractOutcome] per non-Pass round.
List<ContractOutcome> contractOutcomes(Iterable<Game> games) {
  final out = <ContractOutcome>[];
  for (final game in games) {
    for (final round in game.rounds) {
      if (!_isContract(round)) continue;
      out.add(ContractOutcome(round.contractType, round.success));
    }
  }
  return out;
}

/// C1.2 — one [Declaration] per participant of every non-Pass round: the
/// declarer, plus the partner when non-null. A participant whose delta is
/// exactly 0 (only possible if a scoring setting is itself 0) is skipped
/// — "neither right nor wrong" must not be counted as wrong.
List<Declaration> declarations(Iterable<Game> games) {
  final out = <Declaration>[];
  for (final game in games) {
    for (final round in game.rounds) {
      if (!_isContract(round)) continue;
      for (final playerId in [round.declarerId, if (round.partnerId != null) round.partnerId!]) {
        final delta = round.scoreDeltas[playerId];
        if (delta == null || delta == 0) continue;
        out.add(Declaration(playerId, round.contractType, delta > 0));
      }
    }
  }
  return out;
}

const List<String> _trumpSuits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

/// C1.3 / C4.1 — trump suits chosen across [games]. `counts` only ever
/// has the four suit keys; a round with a null `trump` (Miserie, Open
/// Miserie, Pass, or a round recorded before the field existed) is
/// reported separately via `untracked`, never coerced into a suit.
({Map<String, int> counts, int untracked}) trumpHistogram(Iterable<Game> games) {
  final counts = {for (final suit in _trumpSuits) suit: 0};
  var untracked = 0;
  for (final game in games) {
    for (final round in game.rounds) {
      if (!_isContract(round)) continue;
      final trump = round.trump;
      if (trump != null && counts.containsKey(trump)) {
        counts[trump] = counts[trump]! + 1;
      } else {
        untracked++;
      }
    }
  }
  return (counts: counts, untracked: untracked);
}

/// C1.3 / C4.2 — per contract type, how often the contract held.
/// `'Pass'` never appears as a key.
///
/// Caveat, deliberately kept out of the UI (ALTERATIONS.md C4.2 — Sander
/// asked for the explanation to be left out there): for a Miserie/Open
/// Miserie played by two, `held` (== `round.success`) is
/// `miserieSuccess && partnerMiserieSuccess` — the contract as a whole
/// counts as held only if BOTH players made it, even though one of them
/// individually succeeding is a per-player fact that `biddingAccuracy`
/// (below) does track. So this chart can show a two-player Miserie as
/// "failed" in a round where one of the two players actually made
/// their half.
Map<String, ({int made, int total})> contractSuccess(Iterable<Game> games) {
  final made = <String, int>{};
  final total = <String, int>{};
  for (final outcome in contractOutcomes(games)) {
    total[outcome.contractType] = (total[outcome.contractType] ?? 0) + 1;
    if (outcome.held) made[outcome.contractType] = (made[outcome.contractType] ?? 0) + 1;
  }
  return {
    for (final contractType in total.keys)
      contractType: (made: made[contractType] ?? 0, total: total[contractType]!),
  };
}

/// C1.3 / C4.3 — per player, of the contracts they declared (or
/// partnered in a Miserie), how many they made.
Map<String, ({int made, int total})> biddingAccuracy(Iterable<Game> games) {
  final made = <String, int>{};
  final total = <String, int>{};
  for (final decl in declarations(games)) {
    total[decl.playerId] = (total[decl.playerId] ?? 0) + 1;
    if (decl.made) made[decl.playerId] = (made[decl.playerId] ?? 0) + 1;
  }
  return {
    for (final playerId in total.keys)
      playerId: (made: made[playerId] ?? 0, total: total[playerId]!),
  };
}

/// C1.3 / C4.4 — per player, how often they were one of the contracting
/// players. `eligible` for a player is the non-Pass round count of only
/// the games THAT PLAYER PLAYED IN — never the whole scope, or a player
/// present in 2 of 50 games would read as near-zero risk. `tableAverage`
/// is the same ratio summed over everyone: total declarations / (total
/// non-Pass rounds x seats) — the reference line the bars are read
/// against, since the natural baseline isn't fixed (an Ask & Join
/// involves 2 of 4 seats, a Solo 1 of 4).
({Map<String, ({int taken, int eligible})> byPlayer, double tableAverage}) riskFactor(
  Iterable<Game> games,
) {
  final taken = <String, int>{};
  final eligible = <String, int>{};
  var totalDeclarations = 0;
  // Sum, per game, of (that game's non-Pass rounds x that game's seats) —
  // NOT (sum of rounds) x (sum of seats) across games, which would
  // over-count as soon as the scope has more than one game.
  var denominatorSum = 0;

  for (final game in games) {
    final contractRounds = game.rounds.where(_isContract).toList();
    final playerIds = game.players.map((p) => p.id).toList();

    for (final playerId in playerIds) {
      eligible[playerId] = (eligible[playerId] ?? 0) + contractRounds.length;
    }

    for (final round in contractRounds) {
      final participants = [round.declarerId, if (round.partnerId != null) round.partnerId!];
      for (final playerId in participants) {
        taken[playerId] = (taken[playerId] ?? 0) + 1;
      }
      totalDeclarations += participants.length;
    }

    denominatorSum += contractRounds.length * playerIds.length;
  }

  final byPlayer = {
    for (final playerId in eligible.keys)
      playerId: (taken: taken[playerId] ?? 0, eligible: eligible[playerId]!),
  };
  final tableAverage = denominatorSum == 0 ? 0.0 : totalDeclarations / denominatorSum;

  return (byPlayer: byPlayer, tableAverage: tableAverage);
}

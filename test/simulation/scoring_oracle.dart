// Simulation framework — the scoring oracle.
//
// An independent re-statement of the Colour Whist scoring rules, written
// from the rules (CLAUDE.md, ALTERATIONS.md A1-A3, the Rules page) rather
// than copied from `GameProvider.addRound`. The simulation compares the
// two after every round; a disagreement means one of them is wrong, and
// the failure message carries the seed + step so it can be replayed.
//
// It is deliberately table-shaped instead of mirroring the provider's
// switch: "how many points is this contract worth" and "who pays whom"
// are two separate questions here.

import 'package:whistly/scoring_settings.dart';

import 'sim_model.dart';

/// A round with players resolved to ids, ready to score.
class ResolvedRound {
  final Contract contract;
  final String? declarerId;
  final String? partnerId;
  final int agreedTricks;
  final int tricksWon;
  final bool declarerMiserieSuccess;
  final bool partnerMiserieSuccess;

  const ResolvedRound({
    required this.contract,
    this.declarerId,
    this.partnerId,
    required this.agreedTricks,
    required this.tricksWon,
    required this.declarerMiserieSuccess,
    required this.partnerMiserieSuccess,
  });
}

class OracleResult {
  /// Per player id, already multiplied by the Rondpas multiplier.
  final Map<String, int> deltas;

  /// Round-level success as `Round.success` stores it: for a two-player
  /// Miserie, only true when BOTH made it.
  final bool success;

  /// The Rondpas multiplier that applied to this round.
  final int multiplier;

  const OracleResult(this.deltas, this.success, this.multiplier);
}

class ScoringOracle {
  final ScoringSettings settings;
  const ScoringOracle(this.settings);

  /// Rondpas multiplier for the round about to be played: doubles per
  /// consecutive trailing Pass, capped at 2^10.
  static int multiplierAfter(List<Contract> previous) {
    var passes = 0;
    for (final c in previous.reversed) {
      if (c != Contract.pass) break;
      passes++;
    }
    return 1 << (passes > 10 ? 10 : passes);
  }

  /// Points a contract is worth *per opponent* before the multiplier.
  int contractValue(ResolvedRound r) {
    final won = r.tricksWon;
    final agreed = r.agreedTricks;
    final margin = (won - agreed).abs(); // A1: over- AND under-tricks count
    int value;
    switch (r.contract) {
      case Contract.askAndJoin:
        value = settings.askAndJoinBase + (agreed - 8) + margin;
      case Contract.trull:
        value = settings.trull + margin;
      case Contract.solo:
        value = settings.aloneBase + (agreed - 5) + margin;
      case Contract.abondance:
        value = settings.abundanceBase + (agreed - 9) + margin;
      case Contract.miserie:
        return settings.misere;
      case Contract.openMiserie:
        return settings.openMisere;
      case Contract.soloSlim:
        return settings.soloSlim; // the slim bonus never applies on top
      case Contract.pass:
        return 0;
    }
    // A3: all 13 tricks doubles the round (before the Rondpas multiplier).
    if (settings.slimBonusEnabled && won == 13) value *= 2;
    return value;
  }

  OracleResult score(ResolvedRound r, List<String> seatIds, int multiplier) {
    final deltas = {for (final id in seatIds) id: 0};
    if (r.contract == Contract.pass) return OracleResult(deltas, true, multiplier);

    final value = contractValue(r);

    // `side` wins or loses `value` from every player not on it, and every
    // player not on it pays/receives `value` for each member of `side`.
    void settle(List<String> side, bool made) {
      final sign = made ? 1 : -1;
      final others = seatIds.where((id) => !side.contains(id)).toList();
      if (side.length == 1) {
        deltas[side.single] = deltas[side.single]! + sign * value * others.length;
        for (final o in others) {
          deltas[o] = deltas[o]! - sign * value;
        }
      } else {
        // Team contract: each team member wins/loses `value` once, each
        // defender loses/wins `value` once (team of 2 vs 2 at a 4 table).
        for (final s in side) {
          deltas[s] = deltas[s]! + sign * value;
        }
        for (final o in others) {
          deltas[o] = deltas[o]! - sign * value;
        }
      }
    }

    bool success;
    switch (r.contract) {
      case Contract.askAndJoin:
      case Contract.trull:
        success = r.tricksWon >= r.agreedTricks;
        settle([r.declarerId!, r.partnerId!], success);
      case Contract.solo:
      case Contract.abondance:
        success = r.tricksWon >= r.agreedTricks;
        settle([r.declarerId!], success);
      case Contract.soloSlim:
        success = r.tricksWon >= 13;
        settle([r.declarerId!], success);
      case Contract.miserie:
      case Contract.openMiserie:
        if (r.partnerId == null) {
          success = r.declarerMiserieSuccess;
          settle([r.declarerId!], success);
        } else {
          // Two independent Miseries: each player settles alone against
          // the players who are NOT playing Miserie (not against each
          // other).
          final defenders =
              seatIds.where((id) => id != r.declarerId && id != r.partnerId).toList();
          for (final (id, made) in [
            (r.declarerId!, r.declarerMiserieSuccess),
            (r.partnerId!, r.partnerMiserieSuccess),
          ]) {
            final sign = made ? 1 : -1;
            deltas[id] = deltas[id]! + sign * value * defenders.length;
            for (final d in defenders) {
              deltas[d] = deltas[d]! - sign * value;
            }
          }
          success = r.declarerMiserieSuccess && r.partnerMiserieSuccess;
        }
      case Contract.pass:
        throw StateError('unreachable');
    }

    deltas.updateAll((_, v) => v * multiplier);
    return OracleResult(deltas, success, multiplier);
  }
}

import 'package:whistly/models/game.dart';

/// ALTERATIONS.md (round 2) D1 — Solo Slim detection: declaring you'll
/// take all 13 tricks alone, and doing it. The rarest result in the
/// game, and the only mark that's an achievement rather than a state.
class SoloSlim {
  final String gameId;
  final DateTime date; // game.dateEnded ?? game.dateStarted
  final int roundNumber; // 1-based, for the detail line
  const SoloSlim({required this.gameId, required this.date, required this.roundNumber});
}

/// A round qualifies when `contractType == 'Solo Slim'` and
/// `success == true`. Credit `declarerId` only — a Solo Slim has no
/// partner. Career-wide: pass it `[...completedGames, if (activeGame !=
/// null) activeGame!]` so an active game's slim shows its crown the
/// moment it's entered, before the game even ends. Each player's list is
/// sorted newest first (by date, then by round number as a tiebreak for
/// two slims in the same still-active game, which share a date).
Map<String, List<SoloSlim>> soloSlims(Iterable<Game> games) {
  final result = <String, List<SoloSlim>>{};
  for (final game in games) {
    final date = game.dateEnded ?? game.dateStarted;
    for (var i = 0; i < game.rounds.length; i++) {
      final round = game.rounds[i];
      if (round.contractType == 'Solo Slim' && round.success) {
        (result[round.declarerId] ??= []).add(
          SoloSlim(gameId: game.id, date: date, roundNumber: i + 1),
        );
      }
    }
  }
  for (final slims in result.values) {
    slims.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.roundNumber.compareTo(a.roundNumber);
    });
  }
  return result;
}

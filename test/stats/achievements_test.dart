// ALTERATIONS.md (round 2) D1 — Solo Slim detection tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/stats/achievements.dart';

void main() {
  final players = [
    GamePlayerRef(id: 'p1', name: 'Anke'),
    GamePlayerRef(id: 'p2', name: 'Bram'),
    GamePlayerRef(id: 'p3', name: 'Cato'),
    GamePlayerRef(id: 'p4', name: 'Dries'),
  ];

  Game buildGame(String id, DateTime dateStarted, List<Round> rounds, {DateTime? dateEnded}) {
    final game = Game(id: id, dateStarted: dateStarted, playerRefs: players);
    if (dateEnded != null) game.dateEnded = dateEnded;
    game.rounds.addAll(rounds);
    return game;
  }

  Round soloSlimRound({required bool success, String declarerId = 'p1'}) => Round(
        contractType: 'Solo Slim',
        declarerId: declarerId,
        tricksWon: success ? 13 : 10,
        agreedTricks: 13,
        success: success,
        scoreDeltas: success
            ? {declarerId: 45, for (final p in players.where((p) => p.id != declarerId)) p.id: -15}
            : {declarerId: -45, for (final p in players.where((p) => p.id != declarerId)) p.id: 15},
      );

  test('1: a successful Solo Slim credits the declarer; a failed one credits nobody', () {
    final game = buildGame('g1', DateTime(2026, 1, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
      soloSlimRound(success: false, declarerId: 'p2'),
    ]);

    final result = soloSlims([game]);
    expect(result['p1']?.length, 1);
    expect(result.containsKey('p2'), isFalse);
  });

  test('2: a Solo Slim in the active game is included', () {
    final completed = buildGame('g1', DateTime(2026, 1, 1), dateEnded: DateTime(2026, 1, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
    ]);
    final active = buildGame('g2', DateTime(2026, 1, 2), [
      soloSlimRound(success: true, declarerId: 'p2'),
    ]);

    final result = soloSlims([completed, active]);
    expect(result['p1']?.length, 1);
    expect(result['p2']?.length, 1);
  });

  test('3: two slims by one player come back newest first', () {
    final game = buildGame('g1', DateTime(2026, 1, 1), dateEnded: DateTime(2026, 1, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
      Round(
        contractType: 'Solo',
        declarerId: 'p2',
        tricksWon: 6,
        agreedTricks: 5,
        success: true,
        scoreDeltas: {'p2': 9, 'p1': -3, 'p3': -3, 'p4': -3},
      ),
      soloSlimRound(success: true, declarerId: 'p1'),
    ]);

    final result = soloSlims([game]);
    // Same game, same date — the second (round 3) must sort before the
    // first (round 1) via the round-number tiebreak.
    expect(result['p1']!.map((s) => s.roundNumber).toList(), [3, 1]);
  });

  test('4: a player with no slim renders no crown (empty result for that player)', () {
    final game = buildGame('g1', DateTime(2026, 1, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
    ]);

    final result = soloSlims([game]);
    expect(result.containsKey('p2'), isFalse);
    expect(result.containsKey('p3'), isFalse);
    expect(result.containsKey('p4'), isFalse);
  });

  // Not part of the plan's own numbering (its test 5 is about the crown
  // widget rendering "2x", covered in D3's widget tests) — an extra
  // pure-function regression for cross-game sort order.
  test('two slims across different games sort newest game first', () {
    final older = buildGame('g1', DateTime(2026, 1, 1), dateEnded: DateTime(2026, 1, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
    ]);
    final newer = buildGame('g2', DateTime(2026, 2, 1), dateEnded: DateTime(2026, 2, 1), [
      soloSlimRound(success: true, declarerId: 'p1'),
    ]);

    final result = soloSlims([older, newer]);
    expect(result['p1']!.length, 2);
    expect(result['p1']!.first.gameId, 'g2');
    expect(result['p1']!.last.gameId, 'g1');
  });
}

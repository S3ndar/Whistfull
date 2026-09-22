// ALTERATIONS.md (round 2) C1 — stats engine tests. Pure Dart, no
// pumpWidget anywhere in this file.
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/stats/game_stats.dart';

void main() {
  Game buildGame(String id, List<GamePlayerRef> players, List<Round> rounds) {
    final game = Game(id: id, dateStarted: DateTime.now(), playerRefs: players);
    game.rounds.addAll(rounds);
    return game;
  }

  final fourPlayers = [
    GamePlayerRef(id: 'p1', name: 'Anke'),
    GamePlayerRef(id: 'p2', name: 'Bram'),
    GamePlayerRef(id: 'p3', name: 'Cato'),
    GamePlayerRef(id: 'p4', name: 'Dries'),
  ];

  Round askJoinRound({required bool success, String trump = 'Hearts'}) => Round(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: success ? 9 : 6,
        agreedTricks: 8,
        success: success,
        trump: trump,
        scoreDeltas: {
          'p1': success ? 3 : -3,
          'p2': success ? 3 : -3,
          'p3': success ? -3 : 3,
          'p4': success ? -3 : 3,
        },
      );

  Round soloRound({required bool success, String? declarerId, String trump = 'Clubs'}) => Round(
        contractType: 'Solo',
        declarerId: declarerId ?? 'p1',
        tricksWon: success ? 8 : 4,
        agreedTricks: 5,
        success: success,
        trump: trump,
        scoreDeltas: {
          (declarerId ?? 'p1'): success ? 9 : -9,
          for (final id in fourPlayers.map((p) => p.id))
            if (id != (declarerId ?? 'p1')) id: success ? -3 : 3,
        },
      );

  Round passRound() => Round(
        contractType: 'Pass',
        declarerId: 'p1',
        tricksWon: 0,
        agreedTricks: 0,
        success: true,
        scoreDeltas: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      );

  test('1: contractOutcomes skips Pass rounds entirely', () {
    final game = buildGame('g1', fourPlayers, [
      askJoinRound(success: true),
      passRound(),
      soloRound(success: false),
    ]);

    final outcomes = contractOutcomes([game]);
    expect(outcomes.length, 2);
    expect(outcomes.any((o) => o.contractType == 'Pass'), isFalse);
  });

  test('2: declarations emits 2 entries for an Ask & Join round, 1 for a Solo', () {
    final askJoinGame = buildGame('g1', fourPlayers, [askJoinRound(success: true)]);
    expect(declarations([askJoinGame]).length, 2);

    final soloGame = buildGame('g2', fourPlayers, [soloRound(success: true)]);
    expect(declarations([soloGame]).length, 1);
  });

  test('3: a two-person Miserie where one made it and one did not emits made:true and made:false '
      '— even though round.success is false', () {
    final miserieRound = Round(
      contractType: 'Miserie',
      declarerId: 'p1',
      partnerId: 'p2',
      tricksWon: 0,
      agreedTricks: 0,
      // Whole-round success is declarer-made AND partner-made — false
      // here since only the declarer succeeded. C1.1.2 says this must
      // never be read as "both players failed."
      success: false,
      scoreDeltas: {'p1': 5, 'p2': -5, 'p3': -2, 'p4': -2},
    );
    final game = buildGame('g1', fourPlayers, [miserieRound]);

    final decls = declarations([game]);
    expect(decls.length, 2);
    final p1 = decls.firstWhere((d) => d.playerId == 'p1');
    final p2 = decls.firstWhere((d) => d.playerId == 'p2');
    expect(p1.made, isTrue);
    expect(p2.made, isFalse);
  });

  test('4: a participant with a delta of exactly 0 is not emitted', () {
    final round = Round(
      contractType: 'Ask & Join',
      declarerId: 'p1',
      partnerId: 'p2',
      tricksWon: 8,
      agreedTricks: 8,
      success: true,
      // A zero-point scoring setting made the declarer's own delta 0 —
      // "neither right nor wrong," must not count as wrong.
      scoreDeltas: {'p1': 0, 'p2': 3, 'p3': -3, 'p4': -3},
    );
    final game = buildGame('g1', fourPlayers, [round]);

    final decls = declarations([game]);
    expect(decls.any((d) => d.playerId == 'p1'), isFalse);
    expect(decls.any((d) => d.playerId == 'p2'), isTrue);
  });

  test('5: trumpHistogram counts the four suits and reports Miserie/Pass/legacy rounds '
      'as untracked, never as a suit', () {
    final legacyRoundNoTrump = soloRound(success: true, trump: 'Clubs')..trump = null;
    final miserie = Round(
      contractType: 'Miserie',
      declarerId: 'p1',
      tricksWon: 0,
      agreedTricks: 0,
      success: true,
      trump: null,
      scoreDeltas: {'p1': 5, 'p2': -5 ~/ 3, 'p3': -5 ~/ 3, 'p4': -5 ~/ 3},
    );
    final game = buildGame('g1', fourPlayers, [
      askJoinRound(success: true, trump: 'Hearts'),
      askJoinRound(success: true, trump: 'Diamonds'),
      soloRound(success: true, trump: 'Clubs'),
      soloRound(success: true, trump: 'Spades'),
      legacyRoundNoTrump,
      miserie,
      passRound(),
    ]);

    final result = trumpHistogram([game]);
    expect(result.counts['Hearts'], 1);
    expect(result.counts['Diamonds'], 1);
    expect(result.counts['Clubs'], 1);
    expect(result.counts['Spades'], 1);
    // legacyRoundNoTrump + miserie = 2 untracked; Pass is excluded
    // entirely (not even counted as untracked), matching C1.1.
    expect(result.untracked, 2);
  });

  test('6: contractSuccess never contains a "Pass" key', () {
    final game = buildGame('g1', fourPlayers, [
      askJoinRound(success: true),
      soloRound(success: false),
      passRound(),
    ]);

    final result = contractSuccess([game]);
    expect(result.containsKey('Pass'), isFalse);
    expect(result['Ask & Join'], (made: 1, total: 1));
    expect(result['Solo'], (made: 0, total: 1));
  });

  test('7: biddingAccuracy of a player who declared 3 and made 2 is (2, 3)', () {
    final game = buildGame('g1', fourPlayers, [
      soloRound(success: true),
      soloRound(success: true),
      soloRound(success: false),
    ]);

    final result = biddingAccuracy([game]);
    expect(result['p1'], (made: 2, total: 3));
  });

  test('8: riskFactor eligible for a player counts only the games they played', () {
    final otherPlayers = [
      GamePlayerRef(id: 'q1', name: 'Egg'),
      GamePlayerRef(id: 'q2', name: 'Fay'),
      GamePlayerRef(id: 'q3', name: 'Gio'),
      GamePlayerRef(id: 'q4', name: 'Hoa'),
    ];
    final gameWithP1 = buildGame('g1', fourPlayers, [
      askJoinRound(success: true),
      soloRound(success: true),
    ]); // 2 non-Pass rounds
    final gameWithoutP1 = buildGame(
      'g2',
      otherPlayers,
      [
        Round(
          contractType: 'Solo',
          declarerId: 'q1',
          tricksWon: 8,
          agreedTricks: 5,
          success: true,
          scoreDeltas: {'q1': 9, 'q2': -3, 'q3': -3, 'q4': -3},
        ),
      ],
    ); // 1 non-Pass round, p1 not present

    final result = riskFactor([gameWithP1, gameWithoutP1]);
    expect(result.byPlayer['p1']!.eligible, 2);
  });

  test('9: tableAverage of a game of nothing but Ask & Join rounds is 0.5; '
      'of nothing but Solos, 0.25', () {
    final askJoinGame = buildGame('g1', fourPlayers, [
      askJoinRound(success: true),
      askJoinRound(success: false),
    ]);
    expect(riskFactor([askJoinGame]).tableAverage, closeTo(0.5, 1e-9));

    final soloGame = buildGame('g2', fourPlayers, [
      soloRound(success: true),
      soloRound(success: false),
    ]);
    expect(riskFactor([soloGame]).tableAverage, closeTo(0.25, 1e-9));
  });

  test('10: every function returns empty/zero on an empty game list — '
      'no division by zero, no NaN, no throw', () {
    expect(contractOutcomes([]), isEmpty);
    expect(declarations([]), isEmpty);

    final histogram = trumpHistogram([]);
    expect(histogram.counts.values.every((v) => v == 0), isTrue);
    expect(histogram.untracked, 0);

    expect(contractSuccess([]), isEmpty);
    expect(biddingAccuracy([]), isEmpty);

    final risk = riskFactor([]);
    expect(risk.byPlayer, isEmpty);
    expect(risk.tableAverage, 0.0);
    expect(risk.tableAverage.isNaN, isFalse);
  });
}

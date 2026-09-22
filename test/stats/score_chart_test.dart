// ALTERATIONS.md C1 — score progression chart tests. The old test 16
// ("absent below 3 rounds, present at 3+") tested `ScoreProgressionSection`,
// deleted in round 2's C5 — that guard is now `StatsPanel`'s own
// `stats_no_data` rule, tested in test/stats/stats_panel_test.dart instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/stats/score_chart.dart';

void main() {
  final players = [
    GamePlayerRef(id: 'p1', name: 'Anke'),
    GamePlayerRef(id: 'p2', name: 'Bram'),
    GamePlayerRef(id: 'p3', name: 'Cato'),
    GamePlayerRef(id: 'p4', name: 'Dries'),
  ];

  Game gameWithRounds(List<Round> rounds) {
    final game = Game(id: 'g1', dateStarted: DateTime.now(), playerRefs: players);
    for (final round in rounds) {
      game.rounds.add(round);
      round.scoreDeltas.forEach((id, delta) {
        game.totalScores[id] = (game.totalScores[id] ?? 0) + delta;
      });
    }
    return game;
  }

  Round scoreRound(Map<String, int> deltas) => Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        success: true,
        scoreDeltas: deltas,
      );

  Round passRound() => Round(
        contractType: 'Pass',
        declarerId: 'p1',
        tricksWon: 0,
        agreedTricks: 0,
        success: true,
        scoreDeltas: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      );

  test('12: cumulativeSeries matches totalScores at the final index', () {
    final game = gameWithRounds([
      scoreRound({'p1': 6, 'p2': -2, 'p3': -2, 'p4': -2}),
      scoreRound({'p1': -3, 'p2': 1, 'p3': 1, 'p4': 1}),
    ]);

    final series = cumulativeSeries(game);
    for (var i = 0; i < players.length; i++) {
      expect(series[i].last, game.totalScores[players[i].id]);
    }
  });

  test('13: series length equals rounds.length + 1', () {
    final game = gameWithRounds([
      scoreRound({'p1': 6, 'p2': -2, 'p3': -2, 'p4': -2}),
      scoreRound({'p1': -3, 'p2': 1, 'p3': 1, 'p4': 1}),
      scoreRound({'p1': 5, 'p2': -5, 'p3': 0, 'p4': 0}),
    ]);

    final series = cumulativeSeries(game);
    for (final s in series) {
      expect(s.length, game.rounds.length + 1);
    }
  });

  test('14: a Rondpas round contributes a flat step, not a gap', () {
    final game = gameWithRounds([
      scoreRound({'p1': 6, 'p2': -2, 'p3': -2, 'p4': -2}),
      passRound(),
      scoreRound({'p1': -3, 'p2': 1, 'p3': 1, 'p4': 1}),
    ]);

    final series = cumulativeSeries(game);
    // rounds[1] is the Rondpas round, contributing series index 2: every
    // series must repeat index 1's value unchanged there (a flat step),
    // and the series must still have one entry per round (no gap).
    for (final s in series) {
      expect(s.length, 4);
      expect(s[2], s[1]);
    }
  });

  test('15: a player who never scores yields an all-zero series, no NaN', () {
    final game = gameWithRounds([
      scoreRound({'p1': 6, 'p2': -2, 'p3': -2, 'p4': -2}),
      scoreRound({'p1': -3, 'p2': 1, 'p3': 1, 'p4': 1}),
    ]);
    // p4 never appears in either round's deltas above except via the
    // shared map — force a genuinely-absent key to prove the `?? 0`
    // fallback holds.
    game.rounds[0].scoreDeltas.remove('p4');
    game.rounds[1].scoreDeltas.remove('p4');

    final series = cumulativeSeries(game);
    final p4Index = players.indexWhere((p) => p.id == 'p4');
    for (final v in series[p4Index]) {
      expect(v, 0);
      expect(v.isNaN, isFalse);
    }
  });

  // Not part of ALTERATIONS.md's numbered test list, but this codebase has
  // a documented history (active_game_page.dart's Row/stretch bug) of
  // widgets that render nothing with zero analyzer/console error — this
  // actually triggers CustomPainter.paint() for every edge case the spec
  // calls out, rather than trusting that "it compiles" means "it paints."
  testWidgets('paints without throwing — spec edge cases', (tester) async {
    Future<void> pumpAndDrag(Game game) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ScoreProgressionChart(key: ValueKey(game.id), game: game))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScoreProgressionChart), findsOneWidget);
      // Drag across the chart to exercise the crosshair-painting path too.
      await tester.drag(find.byType(ScoreProgressionChart), const Offset(40, 0));
      await tester.pumpAndSettle();
    }

    // All-equal scores: flat lines must still render (a shared baseline,
    // not a divide-by-zero on a zero data range).
    await pumpAndDrag(gameWithRounds([
      scoreRound({'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0}),
      scoreRound({'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0}),
      scoreRound({'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0}),
    ]));

    // A single player at the table — no crash from indexing a lone series.
    final soloGame = Game(
      id: 'g-solo',
      dateStarted: DateTime.now(),
      playerRefs: [GamePlayerRef(id: 'p1', name: 'Anke')],
    );
    for (final delta in [3, -2, 5]) {
      final round = Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        success: true,
        scoreDeltas: {'p1': delta},
      );
      soloGame.rounds.add(round);
      soloGame.totalScores['p1'] = (soloGame.totalScores['p1'] ?? 0) + delta;
    }
    await pumpAndDrag(soloGame);
  });

  testWidgets('a round added to the same mutated Game after a drag still repaints correctly', (tester) async {
    // Regression test for the chart's cache invalidation: the chart caches
    // its cumulativeSeries() result keyed on (game.id, rounds.length) so a
    // drag frame doesn't recompute it, but GameProvider mutates the SAME
    // Game instance in place when a round is added rather than replacing
    // it — the cache must still notice, not keep serving stale data.
    final game = gameWithRounds([
      scoreRound({'p1': 1, 'p2': -1, 'p3': 0, 'p4': 0}),
      scoreRound({'p1': 1, 'p2': -1, 'p3': 0, 'p4': 0}),
      scoreRound({'p1': 1, 'p2': -1, 'p3': 0, 'p4': 0}),
    ]);

    Future<void> pumpChart() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScoreProgressionChart(key: ValueKey(game.id), game: game)),
        ),
      );
    }

    await pumpChart();
    await tester.pumpAndSettle();
    // Drag once to populate the cache via a non-round-adding rebuild path.
    await tester.drag(find.byType(ScoreProgressionChart), const Offset(20, 0));
    await tester.pumpAndSettle();

    // Mutate the SAME Game instance in place, the way GameProvider does —
    // a new round appended, not a new Game object.
    final newRound = scoreRound({'p1': 50, 'p2': -50, 'p3': 0, 'p4': 0});
    game.rounds.add(newRound);
    newRound.scoreDeltas.forEach((id, delta) {
      game.totalScores[id] = (game.totalScores[id] ?? 0) + delta;
    });
    expect(cumulativeSeries(game)[0].last, 53);

    await pumpChart();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ScoreProgressionChart), findsOneWidget);
  });
}

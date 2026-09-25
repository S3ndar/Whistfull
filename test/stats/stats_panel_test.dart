// ALTERATIONS.md (round 2) C5 — stats panel tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/stats/stats_panel.dart';

void main() {
  final players = [
    GamePlayerRef(id: 'p1', name: 'Anke'),
    GamePlayerRef(id: 'p2', name: 'Bram'),
    GamePlayerRef(id: 'p3', name: 'Cato'),
    GamePlayerRef(id: 'p4', name: 'Dries'),
  ];

  Game buildGame(String id, List<Round> rounds) {
    final game = Game(id: id, dateStarted: DateTime.now(), playerRefs: players);
    for (final round in rounds) {
      game.rounds.add(round);
      round.scoreDeltas.forEach((pid, delta) {
        game.totalScores[pid] = (game.totalScores[pid] ?? 0) + delta;
      });
    }
    return game;
  }

  Round soloRound({required bool success, String declarerId = 'p1', String trump = 'Clubs'}) {
    final defenders = players.map((p) => p.id).where((id) => id != declarerId);
    return Round(
      contractType: 'Solo',
      declarerId: declarerId,
      tricksWon: success ? 8 : 4,
      agreedTricks: 5,
      success: success,
      trump: trump,
      scoreDeltas: {
        declarerId: success ? 9 : -9,
        for (final id in defenders) id: success ? -3 : 3,
      },
    );
  }

  Widget wrap(Widget child) => ChangeNotifierProvider(
        create: (_) => LocalizationProvider(),
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  // roundsView makes StatsPanel return an Expanded as its own build
  // output (see stats_panel.dart), so it needs a Column ancestor to sit
  // in, not a SingleChildScrollView.
  Widget wrapWithRounds(Widget child) => ChangeNotifierProvider(
        create: (_) => LocalizationProvider(),
        child: MaterialApp(home: Scaffold(body: Column(children: [child]))),
      );

  final threeRoundGame = buildGame('g1', [
    soloRound(success: true),
    soloRound(success: false, declarerId: 'p2'),
    soloRound(success: true, declarerId: 'p3'),
  ]);

  testWidgets('15: allowProgression:false removes progression from the selector, '
      'and the default selection is a chart that exists', (tester) async {
    await tester.pumpWidget(wrap(StatsPanel(scope: [threeRoundGame], allowProgression: false)));
    await tester.pumpAndSettle();

    // Default with allowProgression:false is bidding accuracy — its
    // header label must be showing, and "Score progression" must not.
    expect(find.text('Bidding accuracy'), findsOneWidget);
    expect(find.text('Score progression'), findsNothing);

    // Open the selector sheet and confirm progression isn't offered.
    await tester.tap(find.text('Bidding accuracy'));
    await tester.pumpAndSettle();
    // "Bidding accuracy" is both the header label and this sheet's own
    // row label, so it now matches twice.
    expect(find.text('Bidding accuracy'), findsNWidgets(2));
    expect(find.text('Score progression'), findsNothing);
    expect(find.text('Trump suits chosen'), findsOneWidget);
  });

  testWidgets('16: changing the selection swaps the chart without rebuilding the scope', (tester) async {
    final scope = [threeRoundGame];
    await tester.pumpWidget(wrap(StatsPanel(scope: scope, allowProgression: true)));
    await tester.pumpAndSettle();

    // Default is progression.
    expect(find.text('Score progression'), findsOneWidget);

    await tester.tap(find.text('Score progression'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trump suits chosen'));
    await tester.pumpAndSettle();

    // The header now reads the newly-selected chart, and the trump
    // chart's own content (a suit row) is showing — the SAME `scope`
    // instance was passed in throughout, never replaced.
    expect(find.text('Trump suits chosen'), findsOneWidget);
    // The trump chart's row label ("♥ Hearts") is a RichText, not a plain
    // Text (its leading glyph is coloured via a separate TextSpan), so
    // find.textContaining (which only matches Text/EditableText) can't
    // see it — read the RichText's own plain-text content instead.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final allRichText = richTexts.map((r) => r.text.toPlainText()).join(' ');
    expect(allRichText, contains('Hearts'));
    expect(identical(scope, scope), isTrue);
  });

  testWidgets('17: a scope with fewer than 3 eligible rounds shows stats_no_data', (tester) async {
    final twoRoundGame = buildGame('g2', [
      soloRound(success: true),
      soloRound(success: false, declarerId: 'p2'),
    ]);
    await tester.pumpWidget(wrap(StatsPanel(scope: [twoRoundGame])));
    await tester.pumpAndSettle();

    expect(find.text('Not enough rounds yet'), findsOneWidget);
    // No selector when there's nothing to select between.
    expect(find.text('Score progression'), findsNothing);
  });

  testWidgets('18: with roundsView, Rounds is selected by default and the round list shows', (tester) async {
    await tester.pumpWidget(wrapWithRounds(StatsPanel(
      scope: [threeRoundGame],
      roundsView: const Text('THE ROUND LIST'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Rounds'), findsOneWidget);
    expect(find.text('THE ROUND LIST'), findsOneWidget);
    // The renamed header — no more "Charts".
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('CHARTS'), findsNothing);
  });

  testWidgets('19: selecting a chart covers the round list; selecting Rounds again restores it', (tester) async {
    await tester.pumpWidget(wrapWithRounds(StatsPanel(
      scope: [threeRoundGame],
      roundsView: const Text('THE ROUND LIST'),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score progression'));
    await tester.pumpAndSettle();

    expect(find.text('THE ROUND LIST'), findsNothing);
    expect(find.text('Score progression'), findsOneWidget);

    await tester.tap(find.text('Score progression'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();

    expect(find.text('THE ROUND LIST'), findsOneWidget);
  });

  testWidgets('20: with roundsView, Rounds is always available even with fewer than 3 eligible rounds', (tester) async {
    final twoRoundGame = buildGame('g3', [
      soloRound(success: true),
      soloRound(success: false, declarerId: 'p2'),
    ]);
    await tester.pumpWidget(wrapWithRounds(StatsPanel(
      scope: [twoRoundGame],
      roundsView: const Text('THE ROUND LIST'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('THE ROUND LIST'), findsOneWidget);
    expect(find.text('Rounds'), findsOneWidget);

    // Charts are still offered in the selector — picking one just shows
    // stats_no_data instead of the chart, same as the roundsView == null
    // case in test 17.
    await tester.tap(find.text('Rounds'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score progression'));
    await tester.pumpAndSettle();

    expect(find.text('THE ROUND LIST'), findsNothing);
    expect(find.text('Not enough rounds yet'), findsOneWidget);
  });

  testWidgets('21: without roundsView, behavior and header label are unchanged', (tester) async {
    await tester.pumpWidget(wrap(StatsPanel(scope: [threeRoundGame])));
    await tester.pumpAndSettle();

    expect(find.text('Score progression'), findsOneWidget);
    expect(find.text('Rounds'), findsNothing);
    expect(find.text('VIEW'), findsOneWidget);
  });

  testWidgets('22: contract success has no footnote; bidding accuracy has its help text (C4.2/C4.3)', (tester) async {
    await tester.pumpWidget(wrap(StatsPanel(scope: [threeRoundGame])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Score progression'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Success rate by contract'));
    await tester.pumpAndSettle();

    // C4.2 — deliberately no footnote on this chart.
    expect(find.textContaining('Miserie played by two'), findsNothing);

    await tester.tap(find.text('Success rate by contract'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bidding accuracy'));
    await tester.pumpAndSettle();

    // C4.3 — always-visible help text under the accuracy chart, same
    // treatment as the risk chart already has.
    expect(find.textContaining('It measures judgement, not points'), findsOneWidget);
  });
}

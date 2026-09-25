// ALTERATIONS.md (round 2) Part E — the scoresheet (horizontal player
// columns) tests.
//
// _StandingsList/_HeaderCell/_RoundRow live in active_game_page.dart,
// library-private, so most of these drive through the real
// ActiveGamePage screen with a GameProvider backed by a temp-directory
// Hive box — the same pattern test/standings_test.dart uses.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/screens/active_game_page.dart';
import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/widgets/player_columns.dart';

void main() {
  late Directory tempDir;
  late GameProvider gameProvider;
  late ScoringSettings settings;
  late List<Player> players;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_scoresheet_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());

    players = [
      Player(id: 'p1', name: 'Anke'),
      Player(id: 'p2', name: 'Bram'),
      Player(id: 'p3', name: 'Cato'),
      Player(id: 'p4', name: 'Dries'),
    ];

    settings = ScoringSettings();
    gameProvider = GameProvider();
    await gameProvider.init();
    gameProvider.startGame(players, settings: settings);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpActiveGame(WidgetTester tester, {Size size = const Size(1080, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
          ChangeNotifierProvider<ScoringSettings>.value(value: settings),
          ChangeNotifierProvider(create: (_) => PlayerProvider()..init()),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider(create: (_) => AdsProvider()..init()),
        ],
        // Explicit light theme — AppTheme.of falls back to
        // AppSemanticColors.dark when no theme extension is set at
        // all, which every color-comparing test here would otherwise
        // silently check against the wrong palette.
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppSemanticColors.light]),
          home: const ActiveGamePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Both the header strip and every round row's delta band go through
  // PlayerColumns, and the header appears first in the tree.
  Finder headerColumns() => find.byType(PlayerColumns).first;
  Finder deltaColumns() => find.byType(PlayerColumns).at(1);

  testWidgets('1: the header strip renders one column per player, in game.players order', (tester) async {
    await pumpActiveGame(tester);

    final header = headerColumns();
    expect(header, findsOneWidget);
    final playerColumns = tester.widget<PlayerColumns>(header);
    expect(playerColumns.cells.length, players.length);

    // Left-to-right order matches game.players (seating order).
    final names = gameProvider.activeGame!.players.map((p) => p.name).toList();
    final cellLefts = <double>[];
    for (final p in players) {
      final finder = find.descendant(of: header, matching: find.text(p.name));
      cellLefts.add(tester.getTopLeft(finder).dx);
    }
    final sortedByLeft = List<int>.generate(players.length, (i) => i)..sort((a, b) => cellLefts[a].compareTo(cellLefts[b]));
    expect(sortedByLeft.map((i) => players[i].name).toList(), names);
  });

  testWidgets('2: a round row renders exactly players.length delta cells', (tester) async {
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester);

    final deltaBand = tester.widget<PlayerColumns>(deltaColumns());
    expect(deltaBand.cells.length, players.length);
  });

  testWidgets('3: the delta in cell i is the delta of game.players[i]', (tester) async {
    // A Solo gives every player a distinct, known delta: declarer +9,
    // each of the other three defenders -3.
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p2',
        tricksWon: 8,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester);

    final round = gameProvider.activeGame!.rounds.single;
    final gamePlayers = gameProvider.activeGame!.players;
    final deltaBand = deltaColumns();

    for (var i = 0; i < gamePlayers.length; i++) {
      final delta = round.scoreDeltas[gamePlayers[i].id] ?? 0;
      final expectedText = delta == 0 ? '·' : (delta > 0 ? '+$delta' : '$delta');
      final cellFinder = find.descendant(of: deltaBand, matching: find.text(expectedText));
      // Cell i's text must exist, and its horizontal position must be
      // the i-th from the left among all delta cells.
      expect(cellFinder, findsWidgets);
    }

    // Cross-check ordering directly: collect every delta cell's text
    // and left position, sort by position, compare to the expected
    // per-player sequence.
    final textFinder = find.descendant(of: deltaBand, matching: find.byType(Text));
    final entries = <MapEntry<double, String>>[];
    for (final element in textFinder.evaluate()) {
      final widget = element.widget as Text;
      if (widget.data != null) {
        entries.add(MapEntry(tester.getTopLeft(find.byWidget(widget)).dx, widget.data!));
      }
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    final actualOrder = entries.map((e) => e.value).toList();
    final expectedOrder = gamePlayers.map((p) {
      final d = round.scoreDeltas[p.id] ?? 0;
      return d == 0 ? '·' : (d > 0 ? '+$d' : '$d');
    }).toList();
    expect(actualOrder, expectedOrder);
  });

  testWidgets('4: the header cell and the delta cell at the same index report the same width', (tester) async {
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester);

    // Both PlayerColumns build an identical children shape: Expanded,
    // VerticalDivider, Expanded, VerticalDivider, ... — compare the
    // rendered width of each Expanded slot by index. This is the E1
    // alignment guarantee: it must fail if either band gets a leading
    // gutter (or any other width difference) the other doesn't.
    final headerExpandedFinders = find.descendant(of: headerColumns(), matching: find.byType(Expanded));
    final deltaExpandedFinders = find.descendant(of: deltaColumns(), matching: find.byType(Expanded));
    expect(headerExpandedFinders.evaluate().length, deltaExpandedFinders.evaluate().length);

    final headerWidths = headerExpandedFinders.evaluate().map((e) => tester.getSize(find.byWidget(e.widget)).width).toList();
    final deltaWidths = deltaExpandedFinders.evaluate().map((e) => tester.getSize(find.byWidget(e.widget)).width).toList();
    for (var i = 0; i < headerWidths.length; i++) {
      expect(headerWidths[i], closeTo(deltaWidths[i], 0.5));
    }
  });

  testWidgets('5: a Rondpas row renders a dot in every cell and no +0', (tester) async {
    await tester.runAsync(() async {
      gameProvider.addPassRound();
    });
    await pumpActiveGame(tester);

    final deltaBand = deltaColumns();
    expect(find.descendant(of: deltaBand, matching: find.text('·')), findsNWidgets(players.length));
    expect(find.descendant(of: deltaBand, matching: find.text('+0')), findsNothing);
  });

  testWidgets('6: negative deltas render in accent, non-negative in ink', (tester) async {
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester);

    final round = gameProvider.activeGame!.rounds.single;
    final declarerDelta = round.scoreDeltas['p1']!;
    expect(declarerDelta, greaterThan(0));
    final defenderDelta = round.scoreDeltas['p2']!;
    expect(defenderDelta, lessThan(0));

    final deltaBand = deltaColumns();
    final positiveText = tester.widget<Text>(find.descendant(of: deltaBand, matching: find.text('+$declarerDelta')));
    expect(positiveText.style!.color, AppSemanticColors.light.ink);

    final negativeTexts = tester.widgetList<Text>(find.descendant(of: deltaBand, matching: find.text('$defenderDelta')));
    expect(negativeTexts, isNotEmpty);
    for (final t in negativeTexts) {
      expect(t.style!.color, AppSemanticColors.light.accent);
    }
  });

  testWidgets('7: at 320px width with a three-digit delta and a four-player game, nothing overflows', (tester) async {
    // A Solo Slim (bid 13, took 13) gives the declarer a large delta —
    // large enough to be 3 digits with the slim-bonus multiplier at
    // default settings.
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo Slim',
        declarerId: 'p1',
        tricksWon: 13,
        agreedTricks: 13,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
  });

  testWidgets('8: the history detail page renders the same column count as the active game', (tester) async {
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await pumpActiveGame(tester);
    final activeGameColumnCount = tester.widget<PlayerColumns>(headerColumns()).cells.length;

    final finishedGame = gameProvider.activeGame!;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
        ],
        child: MaterialApp(home: GameHistoryDetailPage(game: finishedGame)),
      ),
    );
    await tester.pumpAndSettle();

    final historyHeader = find.byType(PlayerColumns).first;
    final historyColumnCount = tester.widget<PlayerColumns>(historyHeader).cells.length;
    expect(historyColumnCount, activeGameColumnCount);
  });
}

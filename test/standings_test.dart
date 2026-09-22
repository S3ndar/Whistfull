// ALTERATIONS.md Part B — standings row tests.
//
// B1 (dealer marker) and B2 (fixed seating order, no rank numbers) both
// live in `_StandingsList` inside active_game_page.dart, which is
// library-private, so these are driven through the real `ActiveGamePage`
// screen with a `GameProvider` backed by a temp-directory Hive box —
// the same pattern `test/widget_test.dart` uses.
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
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

void main() {
  late Directory tempDir;
  late GameProvider gameProvider;
  late ScoringSettings settings;
  late List<Player> players;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_standings_test_');
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

  Future<void> pumpActiveGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
        child: const MaterialApp(home: ActiveGamePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Rows are found as the Text widgets carrying each player's name inside
  // the standings list, ordered top-to-bottom by vertical position.
  List<String> renderedNameOrder(WidgetTester tester) {
    final finder = find.byType(Text);
    final entries = <MapEntry<double, String>>[];
    for (final element in finder.evaluate()) {
      final widget = element.widget as Text;
      final text = widget.data;
      if (text != null && players.any((p) => p.name == text)) {
        final y = tester.getTopLeft(find.byWidget(widget)).dy;
        entries.add(MapEntry(y, text));
      }
    }
    entries.sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => e.value).toList();
  }

  testWidgets('1: dealer\'s row shows a Dealer marker, others do not', (tester) async {
    await pumpActiveGame(tester);

    // No rounds played yet: dealerIndex is 0, so game.players[0] (Anke) is
    // the dealer.
    expect(gameProvider.currentDealer!.name, 'Anke');
    expect(find.byType(WhistlyDealerBadge), findsOneWidget);
  });

  testWidgets('2: a player who is both dealer and sole leader shows both badges', (tester) async {
    // Dealer rotates to the NEXT seat as soon as a round is recorded (see
    // GameProvider.recomputeFromRounds), so after one round dealerIndex is
    // 1 — make the round's declarer Bram (players[1]) so he is dealer and
    // leader at once. A Solo contract (not a team one) gives Bram a
    // uniquely-highest score rather than tying him with a partner. Runs
    // through `runAsync` since addRound writes to the real Hive box, which
    // hangs inside the fake test zone otherwise.
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

    expect(gameProvider.currentDealer!.name, 'Bram');
    expect((gameProvider.activeGame!.totalScores['p2'] ?? 0) > 0, isTrue);
    expect(find.byType(WhistlyDealerBadge), findsOneWidget);
    expect(find.byType(WhistlyLeadBadge), findsOneWidget);
  });

  testWidgets('3: rows render in game.players (seating) order regardless of scores', (tester) async {
    // Make the last-seated player (Dries) the clear leader — if rows were
    // still sorted by score, Dries would render first.
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p4',
        tricksWon: 10,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });

    await pumpActiveGame(tester);

    expect(renderedNameOrder(tester), ['Anke', 'Bram', 'Cato', 'Dries']);
  });

  testWidgets('4: a round that changes the leader does not reorder rows', (tester) async {
    await pumpActiveGame(tester);
    expect(renderedNameOrder(tester), ['Anke', 'Bram', 'Cato', 'Dries']);

    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p3',
        tricksWon: 10,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();

    // Cato is now the leader, but seating order must be unchanged.
    final leaderId = gameProvider.activeGame!.players
        .reduce((a, b) => (gameProvider.activeGame!.totalScores[a.id] ?? 0) >
                (gameProvider.activeGame!.totalScores[b.id] ?? 0)
            ? a
            : b)
        .id;
    expect(leaderId, 'p3');
    expect(renderedNameOrder(tester), ['Anke', 'Bram', 'Cato', 'Dries']);
  });

  testWidgets('5: no rank digits are rendered on the standings rows', (tester) async {
    await pumpActiveGame(tester);

    // Rank cells used to be a lone "1", "2", "3", "4" mono Text widget per
    // row — with them gone, none of those single-digit strings should
    // appear anywhere in the standings list.
    for (final digit in ['1', '2', '3', '4']) {
      expect(find.text(digit), findsNothing);
    }
  });

  // ALTERATIONS.md round 2, B1.1/B1.2 — driven directly against the badge
  // widgets rather than the full app, since both are about the badges'
  // own geometry/colour, not their placement on the standings row (which
  // tests 1-5 above already cover).
  Widget wrapBadge(Widget child) => MaterialApp(
        theme: ThemeData(extensions: const [AppSemanticColors.light]),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('6: the Dealer badge renders accent text on a line-bordered bg fill', (tester) async {
    await tester.pumpWidget(wrapBadge(const WhistlyDealerBadge(label: 'Dealer')));

    final textWidget = tester.widget<Text>(find.text('DEALER'));
    expect(textWidget.style!.color, AppSemanticColors.light.accent);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppSemanticColors.light.bg);
    expect(decoration.border!.top.color, AppSemanticColors.light.line);
    expect(decoration.border!.top.width, 2);
  });

  testWidgets('7: the Dealer and Lead badges render at identical height', (tester) async {
    await tester.pumpWidget(wrapBadge(
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WhistlyDealerBadge(label: 'Dealer'),
          SizedBox(width: 6),
          WhistlyLeadBadge(label: 'Lead'),
        ],
      ),
    ));

    final dealerSize = tester.getSize(find.byType(WhistlyDealerBadge));
    final leadSize = tester.getSize(find.byType(WhistlyLeadBadge));
    expect(dealerSize.height, leadSize.height);
    // Widths are expected to differ ("DEALER" vs "LEAD") — B1.1 explicitly
    // forbids forcing them equal.
    expect(dealerSize.width, isNot(leadSize.width));
  });
}

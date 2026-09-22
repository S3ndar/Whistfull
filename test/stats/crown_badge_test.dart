// ALTERATIONS.md (round 2) D3 — crown badge/popover tests (5-6; test 7
// lives in test/theme_crown_test.dart since it's about AppSemanticColors,
// not this widget).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/stats/crown_badge.dart';
import 'package:whistly/theme/whistly_components.dart';

void main() {
  late Directory tempDir;
  late GameProvider gameProvider;

  final players = [
    Player(id: 'p1', name: 'Anke'),
    Player(id: 'p2', name: 'Bram'),
    Player(id: 'p3', name: 'Cato'),
    Player(id: 'p4', name: 'Dries'),
  ];

  Round soloSlimRound(String declarerId) => Round(
        contractType: 'Solo Slim',
        declarerId: declarerId,
        tricksWon: 13,
        agreedTricks: 13,
        success: true,
        scoreDeltas: {
          declarerId: 45,
          for (final p in players.where((p) => p.id != declarerId)) p.id: -15,
        },
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_crown_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());

    gameProvider = GameProvider();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('5: a player with two slims renders the crown and the count "2x"', (tester) async {
    await tester.runAsync(() async {
      final gamesBox = await Hive.openBox<Game>('games_box');
      await gameProvider.init();
      final gameA = Game(id: 'gA', dateStarted: DateTime(2026, 1, 1), dateEnded: DateTime(2026, 1, 1), isComplete: true, playerRefs: players.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList());
      gameA.rounds.add(soloSlimRound('p1'));
      gameA.totalScores['p1'] = 45;
      await gamesBox.put(gameA.id, gameA);

      final gameB = Game(id: 'gB', dateStarted: DateTime(2026, 2, 1), dateEnded: DateTime(2026, 2, 1), isComplete: true, playerRefs: players.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList());
      gameB.rounds.add(soloSlimRound('p1'));
      gameB.totalScores['p1'] = 45;
      await gamesBox.put(gameB.id, gameB);
    });

    await tester.pumpWidget(wrap(const SoloSlimCrown(playerId: 'p1')));
    await tester.pumpAndSettle();

    expect(find.byType(WhistlyCrownBadge), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
  });

  testWidgets('6: tapping the crown opens the popover; it lists one row per slim', (tester) async {
    await tester.runAsync(() async {
      final gamesBox = await Hive.openBox<Game>('games_box');
      await gameProvider.init();
      for (final id in ['gA', 'gB']) {
        final game = Game(
          id: id,
          dateStarted: DateTime(2026, 1, 1),
          dateEnded: DateTime(2026, 1, 1),
          isComplete: true,
          playerRefs: players.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList(),
        );
        game.rounds.add(soloSlimRound('p1'));
        game.totalScores['p1'] = 45;
        await gamesBox.put(id, game);
      }
    });

    await tester.pumpWidget(wrap(const SoloSlimCrown(playerId: 'p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(WhistlyCrownBadge));
    await tester.pumpAndSettle();

    expect(find.text('SOLO SLIM'), findsOneWidget);
    // One row per slim: both completed games' Solo Slim was round 1.
    expect(find.text('Round 1'), findsNWidgets(2));
  });
}

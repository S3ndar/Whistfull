// ALTERATIONS.md B4 — "At the table" section only exists with an active
// game; tests driven through the real Home screen (`WhistlyApp`), same
// provider-wiring pattern as test/widget_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/billing/purchase_provider.dart';
import 'package:whistly/main.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_home_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<GameProvider> pumpApp(WidgetTester tester, {bool startGame = false}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playerProvider = PlayerProvider()..init();
    final gameProvider = GameProvider();
    final settings = ScoringSettings();

    // Real Hive I/O (init and, when starting a game, the box write) hangs
    // if awaited directly inside the fake testWidgets zone — see
    // test/standings_test.dart's runAsync note for the same underlying
    // cause. Everything that touches Hive here runs inside one runAsync.
    await tester.runAsync(() async {
      await gameProvider.init();
      await settings.init();

      if (startGame) {
        final players = [
          Player(id: 'p1', name: 'Anke'),
          Player(id: 'p2', name: 'Bram'),
          Player(id: 'p3', name: 'Cato'),
          Player(id: 'p4', name: 'Dries'),
        ];
        gameProvider.startGame(players, settings: settings);
      }
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
          ChangeNotifierProvider<ScoringSettings>.value(value: settings),
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider(create: (_) => AdsProvider()..init()),
          ChangeNotifierProvider(
            create: (context) =>
                PurchaseProvider(adsProvider: context.read<AdsProvider>())..init(),
          ),
        ],
        child: const WhistlyApp(),
      ),
    );
    await tester.pumpAndSettle();
    return gameProvider;
  }

  testWidgets('9: no active game — "At the table" eyebrow is absent', (tester) async {
    await pumpApp(tester, startGame: false);

    expect(find.text('At the table'.toUpperCase()), findsNothing);
  });

  testWidgets('10: active game — the grid shows that game\'s players', (tester) async {
    await pumpApp(tester, startGame: true);

    expect(find.text('At the table'.toUpperCase()), findsOneWidget);
    for (final name in ['Anke', 'Bram', 'Cato', 'Dries']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('11: the "New game"/"Continue game" primary button is present either way', (tester) async {
    await pumpApp(tester, startGame: false);
    expect(find.text('New game'.toUpperCase()), findsOneWidget);
  });

  testWidgets('11b: "Continue game" replaces it once a game is active', (tester) async {
    await pumpApp(tester, startGame: true);
    expect(find.text('Continue game'.toUpperCase()), findsOneWidget);
  });
}

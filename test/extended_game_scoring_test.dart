// Extended end-to-end verification: plays a full game through every
// contract type (Ask & Join, Trull, Solo, Abondance, Miserie 1p, Open
// Miserie 2p, Solo Slim, Pass/Rondpas) against the real ActiveGamePage
// scoresheet UI (Part E), checking after every round that:
//   - nothing throws / overflows
//   - the header strip's running totals match GameProvider.totalScores
//   - the round's own delta band matches round.scoreDeltas exactly
//   - every round's deltas still sum to zero
// then exercises undo and ending the game.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/screens/active_game_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/widgets/player_columns.dart';

void main() {
  late Directory tempDir;
  late GameProvider gameProvider;
  late PlayerProvider playerProvider;
  late ScoringSettings settings;
  late List<Player> players;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_extended_scoring_test_');
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

    // Awaited here, not `create: (_) => PlayerProvider()..init()` — that
    // cascade leaves init()'s Hive read still pending when the test
    // body finishes, and its late notifyListeners() then fires against
    // an already-disposed provider during teardown, failing the test
    // even though every real assertion already passed.
    playerProvider = PlayerProvider();
    await playerProvider.init();
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
          ChangeNotifierProvider<PlayerProvider>.value(value: playerProvider),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider(create: (_) => AdsProvider()..adsRemoved = true),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppSemanticColors.light]),
          home: const ActiveGamePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Verifies the header strip's running totals against
  // GameProvider.totalScores, and the MOST RECENT round's delta band
  // against that round's own scoreDeltas — both read left-to-right in
  // game.players (seating) order, exactly as PlayerColumns renders them.
  void verifyScoresheet(WidgetTester tester, {required bool checkLastRoundDelta}) {
    expect(tester.takeException(), isNull);

    final game = gameProvider.activeGame!;
    final columnsFinders = find.byType(PlayerColumns);
    expect(columnsFinders.evaluate().isNotEmpty, isTrue);

    // Header is the first PlayerColumns in the tree.
    final header = columnsFinders.first;
    for (final player in game.players) {
      final score = game.totalScores[player.id] ?? 0;
      final expectedText = score >= 0 ? '+$score' : '$score';
      expect(
        find.descendant(of: header, matching: find.text(expectedText)),
        findsWidgets,
        reason: 'Header total for ${player.name} should show $expectedText',
      );
    }

    if (!checkLastRoundDelta) return;

    // Every round's deltas must sum to zero — points always move
    // between players, never created or destroyed.
    final round = game.rounds.last;
    final sum = round.scoreDeltas.values.fold<int>(0, (a, b) => a + b);
    expect(sum, 0, reason: 'Round deltas must sum to zero: ${round.scoreDeltas}');

    // The most recent round is the SECOND PlayerColumns instance (index
    // 1): header first, then the newest round's delta band (the round
    // list is newest-first).
    final deltaBand = columnsFinders.at(1);
    for (final player in game.players) {
      final delta = round.scoreDeltas[player.id] ?? 0;
      final expectedText = delta == 0 ? '·' : (delta > 0 ? '+$delta' : '$delta');
      expect(
        find.descendant(of: deltaBand, matching: find.text(expectedText)),
        findsWidgets,
        reason: 'Delta cell for ${player.name} should show $expectedText',
      );
    }
  }

  testWidgets('a full game through every contract type renders correctly at every step', (tester) async {
    await pumpActiveGame(tester);
    verifyScoresheet(tester, checkLastRoundDelta: false);

    // 1. Ask & Join — p1 + p2 vs p3/p4, bid 8, took 10 (success, margin 2)
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 10,
        agreedTricks: 8,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 2. Trull — p2 + p3, bid 9, took 9 (success, no margin)
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Trull',
        declarerId: 'p2',
        partnerId: 'p3',
        tricksWon: 9,
        agreedTricks: 9,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 3. Solo — p3, bid 5, took 3 (failure)
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo',
        declarerId: 'p3',
        tricksWon: 3,
        agreedTricks: 5,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 4. Abondance — p4, bid 9, took 11 (success, margin 2)
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Abondance',
        declarerId: 'p4',
        tricksWon: 11,
        agreedTricks: 9,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 5. Miserie, 1 player — p1 fails alone.
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Miserie',
        declarerId: 'p1',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: false,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 6. Open Miserie, 2 players — p2 succeeds, p3 fails (independent
    // outcomes — this is C1.1's "round.success is not a per-player
    // fact" case from the stats engine work, now exercised live).
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Open Miserie',
        declarerId: 'p2',
        partnerId: 'p3',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: true,
        partnerMiserieSuccess: false,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);

    // 7. Solo Slim — p4 takes all 13 alone.
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Solo Slim',
        declarerId: 'p4',
        tricksWon: 13,
        agreedTricks: 13,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);
    // The crown should now show for p4 (Dries) — D1/D3 live end to end.
    expect(gameProvider.soloSlimsByPlayer['p4']?.length, 1);

    // 8. Pass (Rondpas) — stacks the multiplier for the next round.
    await tester.runAsync(() async {
      gameProvider.addPassRound();
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);
    expect(gameProvider.pointMultiplier, 2);

    // 9. Ask & Join again, now doubled by the pending Rondpas multiplier.
    final beforeMultiplierRound = gameProvider.activeGame!.rounds.length;
    await tester.runAsync(() async {
      gameProvider.addRound(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p3',
        tricksWon: 8,
        agreedTricks: 8,
        miserieSuccess: true,
        settings: settings,
      );
    });
    await tester.pumpAndSettle();
    verifyScoresheet(tester, checkLastRoundDelta: true);
    expect(gameProvider.activeGame!.rounds.length, beforeMultiplierRound + 1);
    expect(gameProvider.pointMultiplier, 1, reason: 'multiplier resets after being consumed');

    // Undo the last round through the real header icon, not the
    // provider directly — exercises _confirmUndo's dialog too. The tap
    // that confirms it triggers a real Hive write (undoLastRound ->
    // recomputeFromRounds), so it must run inside runAsync the same
    // way a direct addRound call would — a tap callback's async work
    // isn't otherwise wrapped, and real I/O inside the fake-async test
    // zone hangs for the full test timeout instead of erroring.
    final scoresBeforeUndo = Map<String, int>.from(gameProvider.activeGame!.totalScores);
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('UNDO'));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(gameProvider.activeGame!.totalScores, isNot(scoresBeforeUndo));
    expect(gameProvider.pointMultiplier, 2, reason: 'undo restores the multiplier the undone round had consumed');

    // Sum of everyone's total must equal the sum of every round's
    // deltas (recomputeFromRounds is the single source of truth) —
    // both should independently come out to zero.
    final totalSum = gameProvider.activeGame!.totalScores.values.fold<int>(0, (a, b) => a + b);
    expect(totalSum, 0);

    // Finally, end the game through the real dialog and confirm the
    // screen unwinds without throwing. The win-celebration dialog that
    // follows plays a confetti animation whose AnimationController
    // never fully quiesces, so pumpAndSettle (which waits for exactly
    // that) hangs forever here — bounded pump() calls instead.
    await tester.tap(find.text('END GAME'));
    await tester.pumpAndSettle();
    expect(find.text('End Game?'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('END GAME').last);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.text('BACK TO HOME'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('BACK TO HOME'));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(gameProvider.activeGame, isNull);
  });
}

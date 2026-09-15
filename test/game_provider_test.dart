import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/scoring_settings.dart';

void main() {
  late Directory tempDir;
  late GameProvider provider;
  late ScoringSettings settings;
  late List<Player> players;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_game_provider_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());

    provider = GameProvider();
    settings = ScoringSettings();
    await settings.init();

    players = [
      Player(id: 'p1', name: 'Sander'),
      Player(id: 'p2', name: 'Alice'),
      Player(id: 'p3', name: 'Bob'),
      Player(id: 'p4', name: 'Charlie'),
    ];
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GameProvider Initialization & Flow', () {
    test('should start and end game correctly', () async {
      await provider.init();
      expect(provider.activeGame, isNull);

      provider.startGame(players, settings: settings);
      expect(provider.activeGame, isNotNull);
      // PLAN.md B4: the game's roster is now an id+name snapshot
      // (`GamePlayerRef`), not the live `Player` objects passed in.
      expect(provider.activeGame!.players.map((p) => p.id).toList(), players.map((p) => p.id).toList());
      expect(provider.activeGame!.players.map((p) => p.name).toList(), players.map((p) => p.name).toList());
      expect(provider.dealerIndex, 0);
      expect(provider.currentDealer!.id, 'p1');

      provider.endGame();
      expect(provider.activeGame, isNull);
    });

    test('PLAN.md B4: renaming a player after the game started leaves the '
        "game's roster showing the original name", () async {
      await provider.init();
      provider.startGame(players, settings: settings);
      final game = provider.activeGame!;
      expect(game.players.firstWhere((p) => p.id == 'p1').name, 'Sander');

      // Simulate a rename by mutating the live Player object passed to
      // `startGame` (there's no dedicated "rename player" feature yet —
      // see PLAN.md; this app doesn't expose renaming through the UI at
      // all today, so this is the most direct way to exercise the fix).
      // Pre-B4 this would have changed the name the game shows too, since
      // `Game.players` embedded these same objects; the fix is that
      // `startGame` snapshots id+name into an independent `GamePlayerRef`
      // instead, so mutating the live object afterwards can't reach it.
      players.firstWhere((p) => p.id == 'p1').name = 'Sander Renamed';

      expect(game.players.firstWhere((p) => p.id == 'p1').name, 'Sander');
    });

    test('should restore active game on init if activeGameId is saved', () async {
      await provider.init();
      provider.startGame(players, settings: settings);
      final gameId = provider.activeGame!.id;

      // Close and re-init a new GameProvider
      final newProvider = GameProvider();
      await newProvider.init();

      expect(newProvider.activeGame, isNotNull);
      expect(newProvider.activeGame!.id, gameId);
    });

    test('should advance dealer and stack point multiplier on pass round', () async {
      await provider.init();
      provider.startGame(players, settings: settings);

      expect(provider.pointMultiplier, 1);
      expect(provider.dealerIndex, 0);

      // Add a pass round
      provider.addPassRound();
      expect(provider.pointMultiplier, 2);
      expect(provider.dealerIndex, 1);
      expect(provider.activeGame!.rounds.length, 1);
      expect(provider.activeGame!.rounds.first.contractType, 'Pass');

      // Add another pass round (double again)
      provider.addPassRound();
      expect(provider.pointMultiplier, 4);
      expect(provider.dealerIndex, 2);
    });
  });

  group('GameProvider Scoring Calculations', () {
    setUp(() async {
      await provider.init();
      provider.startGame(players, settings: settings);
    });

    test('Ask & Join: success', () {
      // Declarer: p1, Partner: p2, Defending: p3, p4
      // Target: 8 tricks, Tricks won: 9. base = 2, overtricks = 1. total = 3.
      final deltas = provider.addRound(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 9,
        agreedTricks: 8,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 3);
      expect(deltas['p2'], 3);
      expect(deltas['p3'], -3);
      expect(deltas['p4'], -3);

      expect(provider.activeGame!.totalScores['p1'], 3);
      expect(provider.activeGame!.totalScores['p3'], -3);
      expect(provider.dealerIndex, 1); // Dealer rotated
    });

    test('Ask & Join: failure', () {
      // Declarer: p1, Partner: p2
      // Target: 8 tricks, Tricks won: 7. base = 2, total = 2.
      final deltas = provider.addRound(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 7,
        agreedTricks: 8,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], -2);
      expect(deltas['p2'], -2);
      expect(deltas['p3'], 2);
      expect(deltas['p4'], 2);
    });

    test('Trull: success', () {
      // Declarer: p1, Partner: p2. base = 9, overtricks = 1 (tricks: 10 vs target: 9). total = 10.
      final deltas = provider.addRound(
        contractType: 'Trull',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 10,
        agreedTricks: 9,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 10);
      expect(deltas['p2'], 10);
      expect(deltas['p3'], -10);
      expect(deltas['p4'], -10);
    });

    test('Solo: success', () {
      // Declarer: p1. Target: 5, Tricks won: 6. base = 2, overtricks = 1. total = 3.
      // Declarer gets 3 * 3 = 9. Defenders lose 3 each.
      final deltas = provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 9);
      expect(deltas['p2'], -3);
      expect(deltas['p3'], -3);
      expect(deltas['p4'], -3);
    });

    test('Solo: failure with escalation', () {
      // Declarer: p1. Target: 7, Tricks won: 6.
      // Base: aloneBase (2) + (7 - 5) = 4.
      // Failure: declarer loses 4 * 3 = 12. Defenders gain 4 each.
      final deltas = provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 7,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], -12);
      expect(deltas['p2'], 4);
      expect(deltas['p3'], 4);
      expect(deltas['p4'], 4);
    });

    test('Abondance: success', () {
      // Declarer: p1. Target: 9, Tricks won: 9. base = 5.
      // Success: declarer gets 5 * 3 = 15. Defenders lose 5 each.
      final deltas = provider.addRound(
        contractType: 'Abondance',
        declarerId: 'p1',
        tricksWon: 9,
        agreedTricks: 9,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 15);
      expect(deltas['p2'], -5);
      expect(deltas['p3'], -5);
      expect(deltas['p4'], -5);
    });

    test('Miserie: success', () {
      // Declarer: p1. base = 5.
      // Success: declarer gets 5 * 3 = 15. Defenders lose 5 each.
      final deltas = provider.addRound(
        contractType: 'Miserie',
        declarerId: 'p1',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: true,
        settings: settings,
      );

      expect(deltas['p1'], 15);
      expect(deltas['p2'], -5);
      expect(deltas['p3'], -5);
      expect(deltas['p4'], -5);
    });

    test('Open Miserie: failure', () {
      // Declarer: p1. base = 10.
      // Failure: declarer loses 10 * 3 = 30. Defenders gain 10 each.
      final deltas = provider.addRound(
        contractType: 'Open Miserie',
        declarerId: 'p1',
        tricksWon: 1,
        agreedTricks: 0,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], -30);
      expect(deltas['p2'], 10);
      expect(deltas['p3'], 10);
      expect(deltas['p4'], 10);
    });

    test('Double Miserie: both succeed', () {
      // Declarer: p1, Partner: p2. base = 5. Defenders: p3, p4.
      // Both succeed: declarers get 5 * 2 = 10 each. Defenders pay 5 * 2 = 10 each.
      final deltas = provider.addRound(
        contractType: 'Miserie',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: true,
        partnerMiserieSuccess: true,
        settings: settings,
      );

      expect(deltas['p1'], 10);
      expect(deltas['p2'], 10);
      expect(deltas['p3'], -10);
      expect(deltas['p4'], -10);
    });

    test('Double Miserie: both fail', () {
      // Declarer: p1, Partner: p2. base = 5. Defenders: p3, p4.
      // Both fail: declarers pay 5 * 2 = 10 each. Defenders get 5 * 2 = 10 each.
      final deltas = provider.addRound(
        contractType: 'Miserie',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: false,
        partnerMiserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], -10);
      expect(deltas['p2'], -10);
      expect(deltas['p3'], 10);
      expect(deltas['p4'], 10);
    });

    test('Double Miserie: one succeeds, one fails', () {
      // Declarer: p1 (succeeds), Partner: p2 (fails). base = 5. Defenders: p3, p4.
      // p1 gets 10, p2 pays 10. Defenders: net 0 (pay 5 to p1, get 5 from p2).
      final deltas = provider.addRound(
        contractType: 'Miserie',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 0,
        agreedTricks: 0,
        miserieSuccess: true,
        partnerMiserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 10);
      expect(deltas['p2'], -10);
      expect(deltas['p3'], 0);
      expect(deltas['p4'], 0);
    });

    test('Solo Slim: success', () {
      // Declarer: p1. base = 15.
      // Success: declarer gets 15 * 3 = 45. Defenders lose 15 each.
      final deltas = provider.addRound(
        contractType: 'Solo Slim',
        declarerId: 'p1',
        tricksWon: 13,
        agreedTricks: 13,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 45);
      expect(deltas['p2'], -15);
      expect(deltas['p3'], -15);
      expect(deltas['p4'], -15);
    });

    test('Should apply Rondpas multipliers and reset them afterwards', () {
      // Add two pass rounds to get a x4 multiplier
      provider.addPassRound();
      provider.addPassRound();
      expect(provider.pointMultiplier, 4);

      // Play Solo: success. Base = 2.
      // Delat: p1 gets 2 * 3 = 6. Defenders lose 2.
      // With x4 multiplier: p1 gets 24. Defenders lose 8.
      final deltas = provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 5,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      );

      expect(deltas['p1'], 24);
      expect(deltas['p2'], -8);
      expect(deltas['p3'], -8);
      expect(deltas['p4'], -8);

      // Verify multiplier is reset to 1
      expect(provider.pointMultiplier, 1);
    });
  });

  group('GameProvider Undo/Delete & Recompute', () {
    setUp(() async {
      await provider.init();
      provider.startGame(players, settings: settings);
    });

    test('undoLastRound() restores the exact totals from before that round',
        () {
      provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      ); // p1 +9, others -3 each

      final beforeSecondRound = Map<String, int>.from(
        provider.activeGame!.totalScores,
      );

      provider.addRound(
        contractType: 'Trull',
        declarerId: 'p2',
        partnerId: 'p3',
        tricksWon: 10,
        agreedTricks: 9,
        miserieSuccess: false,
        settings: settings,
      );
      expect(provider.activeGame!.totalScores, isNot(beforeSecondRound));

      final undone = provider.undoLastRound();

      expect(undone, isTrue);
      expect(provider.activeGame!.rounds.length, 1);
      expect(provider.activeGame!.totalScores, beforeSecondRound);
    });

    test('undoLastRound() on an empty round list returns false and mutates nothing',
        () {
      expect(provider.activeGame!.rounds, isEmpty);
      final totalsBefore = Map<String, int>.from(
        provider.activeGame!.totalScores,
      );
      final dealerBefore = provider.dealerIndex;
      final multiplierBefore = provider.pointMultiplier;

      final undone = provider.undoLastRound();

      expect(undone, isFalse);
      expect(provider.activeGame!.rounds, isEmpty);
      expect(provider.activeGame!.totalScores, totalsBefore);
      expect(provider.dealerIndex, dealerBefore);
      expect(provider.pointMultiplier, multiplierBefore);
    });

    test('undoing a Rondpas round restores the previous multiplier (2 passes -> x4; undo -> x2)',
        () {
      provider.addPassRound();
      provider.addPassRound();
      expect(provider.pointMultiplier, 4);

      final undone = provider.undoLastRound();

      expect(undone, isTrue);
      expect(provider.activeGame!.rounds.length, 1);
      expect(provider.pointMultiplier, 2);
    });

    test('deleteRound(index) on a middle round leaves the remaining totals correct',
        () {
      provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      ); // round 0: p1 +9, others -3 each

      provider.addRound(
        contractType: 'Trull',
        declarerId: 'p2',
        partnerId: 'p3',
        tricksWon: 10,
        agreedTricks: 9,
        miserieSuccess: false,
        settings: settings,
      ); // round 1 (to be deleted): p2/p3 +10, p1/p4 -10

      provider.addRound(
        contractType: 'Solo',
        declarerId: 'p4',
        tricksWon: 5,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      ); // round 2: p4 +6, others -2 each

      final round0Deltas = provider.activeGame!.rounds[0].scoreDeltas;
      final round2Deltas = provider.activeGame!.rounds[2].scoreDeltas;
      final expectedTotals = <String, int>{};
      for (var p in players) {
        expectedTotals[p.id] =
            (round0Deltas[p.id] ?? 0) + (round2Deltas[p.id] ?? 0);
      }

      final deleted = provider.deleteRound(1);

      expect(deleted, isTrue);
      expect(provider.activeGame!.rounds.length, 2);
      expect(provider.activeGame!.totalScores, expectedTotals);
    });

    test('recomputeFromRounds() is idempotent', () {
      provider.addPassRound();
      provider.addRound(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        miserieSuccess: false,
        settings: settings,
      );

      final totalsAfterFirst = Map<String, int>.from(
        provider.activeGame!.totalScores,
      );
      final dealerAfterFirst = provider.dealerIndex;
      final multiplierAfterFirst = provider.pointMultiplier;

      provider.recomputeFromRounds();
      provider.recomputeFromRounds();

      expect(provider.activeGame!.totalScores, totalsAfterFirst);
      expect(provider.dealerIndex, dealerAfterFirst);
      expect(provider.pointMultiplier, multiplierAfterFirst);
    });
  });

  group('GameProvider legacy save compatibility', () {
    test('a Game with scoringSnapshot == null (legacy save) still loads and appears in completedGames',
        () async {
      await provider.init();

      final legacyGame = Game(
        id: 'legacy-game-1',
        dateStarted: DateTime.now(),
        playerRefs: players.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList(),
        // No scoringSnapshot, no dateEnded, isComplete defaults to false:
        // this is exactly what a pre-5.2 save looks like on disk.
      );
      expect(legacyGame.scoringSnapshot, isNull);

      final gamesBox = Hive.box<Game>('games_box');
      await gamesBox.put(legacyGame.id, legacyGame);

      expect(
        provider.completedGames.map((g) => g.id),
        contains('legacy-game-1'),
      );
      final loaded =
          provider.completedGames.firstWhere((g) => g.id == 'legacy-game-1');
      expect(loaded.scoringSnapshot, isNull);
    });

    test('PLAN.md B4: a game with only the pre-migration embedded Player list '
        '(playerRefs == null) still loads and derives id+name from it', () async {
      await provider.init();

      // Simulate exactly what a pre-B4 save looks like on disk: `players`
      // (now `legacyPlayers`) holds full embedded Player copies and the new
      // `playerRefs` field was never written, so it's null. Bypassing the
      // `Game(...)` constructor (which always sets `playerRefs`) and setting
      // the legacy field directly is the only way to reproduce that shape
      // without hand-crafting Hive's binary format.
      final legacyGame = Game(
        id: 'legacy-game-b4',
        dateStarted: DateTime.now(),
        playerRefs: const [],
      )
        ..playerRefs = null
        ..legacyPlayers = players
        ..totalScores = {for (var p in players) p.id: 0};

      final gamesBox = Hive.box<Game>('games_box');
      await gamesBox.put(legacyGame.id, legacyGame);

      final loaded =
          provider.completedGames.firstWhere((g) => g.id == 'legacy-game-b4');

      // The `players` getter must derive the same id+name pairs from the
      // legacy embedded objects, with no live Player object anywhere in
      // the result (so callers can never accidentally call `.save()` on a
      // detached copy the way the pre-fix code could).
      expect(loaded.players.map((p) => p.id).toList(), players.map((p) => p.id).toList());
      expect(loaded.players.map((p) => p.name).toList(), players.map((p) => p.name).toList());
      expect(loaded.players, everyElement(isA<GamePlayerRef>()));

      // Round-trip through Hive again (read back what was just read) to
      // prove the derivation is stable, not a one-time artifact of the
      // object still being in memory.
      await gamesBox.put(legacyGame.id, loaded);
      final reloaded =
          provider.completedGames.firstWhere((g) => g.id == 'legacy-game-b4');
      expect(reloaded.players.map((p) => p.id).toList(), players.map((p) => p.id).toList());
    });
  });
}

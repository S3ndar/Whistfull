import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/providers/player_provider.dart';

void main() {
  late Directory tempDir;
  late PlayerProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_player_provider_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PlayerAdapter());
    }
    provider = PlayerProvider();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PlayerProvider Tests', () {
    test('should initialize with empty players list', () async {
      await provider.init();
      expect(provider.players, isEmpty);
    });

    test('should add players and load them sorted', () async {
      await provider.init();
      await provider.addPlayer('Charlie');
      await Future.delayed(const Duration(milliseconds: 5));
      await provider.addPlayer('Alice');
      await Future.delayed(const Duration(milliseconds: 5));
      await provider.addPlayer('Bob');

      // Default sorting is alphabetical when none are favorites
      expect(provider.players.length, 3);
      expect(provider.players[0].name, 'Alice');
      expect(provider.players[1].name, 'Bob');
      expect(provider.players[2].name, 'Charlie');
    });

    test('should sort favorites first', () async {
      await provider.init();
      await provider.addPlayer('Charlie');
      await Future.delayed(const Duration(milliseconds: 5));
      await provider.addPlayer('Alice');
      await Future.delayed(const Duration(milliseconds: 5));
      await provider.addPlayer('Bob');

      expect(provider.players.length, 3);

      // Make Bob a favorite (find by name, not index)
      final bob = provider.players.firstWhere((p) => p.name == 'Bob');
      await provider.toggleFavorite(bob);

      expect(provider.players[0].name, 'Bob'); // Favorite first
      expect(provider.players[0].isFavorite, isTrue);
      expect(provider.players[1].name, 'Alice');
      expect(provider.players[2].name, 'Charlie');
    });

    test('should increment games played for selected players', () async {
      await provider.init();
      await provider.addPlayer('Alice');
      await Future.delayed(const Duration(milliseconds: 5)); // avoid ID collision
      await provider.addPlayer('Bob');

      expect(provider.players.length, 2);

      // Find by name to avoid index-ordering dependency
      final alice = provider.players.firstWhere((p) => p.name == 'Alice');
      final bob = provider.players.firstWhere((p) => p.name == 'Bob');

      await provider.incrementGamesPlayed([alice]);

      expect(alice.gamesPlayed, 1);
      expect(bob.gamesPlayed, 0);
    });

    test('should populate default players', () async {
      await provider.init();
      await provider.populateDefaults();

      expect(provider.players.length, 4);
      final names = provider.players.map((p) => p.name).toList();
      expect(names, containsAll(['Sander', 'Alice', 'Bob', 'Charlie']));
      for (var player in provider.players) {
        expect(player.isFavorite, isTrue);
      }
    });

    test('should clear all players', () async {
      await provider.init();
      await provider.addPlayer('Alice');
      expect(provider.players, isNotEmpty);

      await provider.clearAll();
      expect(provider.players, isEmpty);
    });
  });
}

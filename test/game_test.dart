import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/player.dart';

void main() {
  group('Game Model Tests', () {
    final players = [
      Player(id: '1', name: 'Sander'),
      Player(id: '2', name: 'Alice'),
      Player(id: '3', name: 'Bob'),
      Player(id: '4', name: 'Charlie'),
    ];

    test('should initialize game with correct properties and default scores', () {
      final date = DateTime.now();
      final game = Game(
        id: 'g1',
        dateStarted: date,
        players: players,
      );

      expect(game.id, 'g1');
      expect(game.dateStarted, date);
      expect(game.players, players);
      expect(game.rounds, isEmpty);
      expect(game.pointMultiplier, 1);

      // Verify scores are initialized to 0 for all players
      expect(game.totalScores['1'], 0);
      expect(game.totalScores['2'], 0);
      expect(game.totalScores['3'], 0);
      expect(game.totalScores['4'], 0);
    });

    test('should allow custom rounds, scores and pointMultiplier', () {
      final customScores = {'1': 10, '2': -10, '3': 5, '4': -5};
      final game = Game(
        id: 'g2',
        dateStarted: DateTime.now(),
        players: players,
        totalScores: customScores,
        pointMultiplier: 4,
      );

      expect(game.totalScores, customScores);
      expect(game.pointMultiplier, 4);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/player.dart';

void main() {
  group('Player Model Tests', () {
    test('should create player with correct properties', () {
      final player = Player(id: '1', name: 'Sander');

      expect(player.id, '1');
      expect(player.name, 'Sander');
      expect(player.gamesPlayed, 0);
      expect(player.isFavorite, isFalse);
    });

    test('should allow custom gamesPlayed and isFavorite values', () {
      final player = Player(
        id: '2',
        name: 'Alice',
        gamesPlayed: 5,
        isFavorite: true,
      );

      expect(player.id, '2');
      expect(player.name, 'Alice');
      expect(player.gamesPlayed, 5);
      expect(player.isFavorite, isTrue);
    });
  });
}

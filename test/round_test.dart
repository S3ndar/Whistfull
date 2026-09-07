import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/round.dart';

void main() {
  group('Round Model Tests', () {
    test('should initialize with correct properties', () {
      final round = Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 6,
        agreedTricks: 5,
        success: true,
        scoreDeltas: {'p1': 3, 'p2': -1, 'p3': -1, 'p4': -1},
        dealerId: 'p2',
        trump: 'Hearts',
        multiplier: 2,
      );

      expect(round.contractType, 'Solo');
      expect(round.declarerId, 'p1');
      expect(round.partnerId, isNull);
      expect(round.tricksWon, 6);
      expect(round.agreedTricks, 5);
      expect(round.success, isTrue);
      expect(round.scoreDeltas, {'p1': 3, 'p2': -1, 'p3': -1, 'p4': -1});
      expect(round.dealerId, 'p2');
      expect(round.trump, 'Hearts');
      expect(round.multiplier, 2);
    });

    test('should apply default values', () {
      final round = Round(
        contractType: 'Miserie',
        declarerId: 'p1',
        tricksWon: 0,
        success: true,
        scoreDeltas: {},
      );

      expect(round.agreedTricks, 0);
      expect(round.multiplier, 1);
      expect(round.partnerId, isNull);
      expect(round.dealerId, isNull);
      expect(round.trump, isNull);
    });
  });
}

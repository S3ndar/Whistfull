// ALTERATIONS.md (round 2) C4 — chart builder tests. Not individually
// numbered by the plan (only C1/C3/C5 have numbered test lists for this
// part), but each function here has real logic (ordering, sorting,
// dimmed thresholds) not exercised by C1's or C3's own tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/stats/chart_builders.dart';
import 'package:whistly/theme/app_theme.dart';

void main() {
  final players = [
    GamePlayerRef(id: 'p1', name: 'Anke'),
    GamePlayerRef(id: 'p2', name: 'Bram'),
    GamePlayerRef(id: 'p3', name: 'Cato'),
    GamePlayerRef(id: 'p4', name: 'Dries'),
  ];

  Game buildGame(List<Round> rounds) {
    final game = Game(id: 'g1', dateStarted: DateTime.now(), playerRefs: players);
    game.rounds.addAll(rounds);
    return game;
  }

  test('trumpSuitsChart renders the four suits in fixed priority order, glyph-coloured', () {
    final game = buildGame([
      Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        success: true,
        trump: 'Clubs',
        scoreDeltas: {'p1': 9, 'p2': -3, 'p3': -3, 'p4': -3},
      ),
    ]);

    final result = trumpSuitsChart([game], AppSemanticColors.light);
    expect(result.data.map((d) => d.label).toList(), ['♥ Hearts', '♦ Diamonds', '♣ Clubs', '♠ Spades']);
    expect(result.data[2].value, 1); // Clubs
    expect(result.data[2].glyphColor, AppSemanticColors.light.suitInk);
    expect(result.data[0].glyphColor, AppSemanticColors.light.suitRed); // Hearts
  });

  test('contractSuccessChart orders by kContracts, not by rate, and never includes Pass', () {
    final game = buildGame([
      Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        success: true,
        scoreDeltas: {'p1': 9, 'p2': -3, 'p3': -3, 'p4': -3},
      ),
      Round(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 6,
        agreedTricks: 8,
        success: false,
        scoreDeltas: {'p1': -3, 'p2': -3, 'p3': 3, 'p4': 3},
      ),
      Round(
        contractType: 'Pass',
        declarerId: 'p1',
        tricksWon: 0,
        agreedTricks: 0,
        success: true,
        scoreDeltas: {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0},
      ),
    ]);

    final loc = LocalizationProvider();
    final data = contractSuccessChart([game], loc);
    // kContracts order is Ask & Join, Trull, Solo, ... — Ask & Join must
    // come before Solo even though Solo has the higher (100%) rate.
    expect(data.map((d) => d.label).toList(), ['Ask & Join', 'Alone']);
    expect(data.every((d) => d.dimmed), isTrue); // n=1 each, below the n<3 floor
  });

  test('biddingAccuracyChart sorts by rate descending', () {
    final game = buildGame([
      Round(
        contractType: 'Solo',
        declarerId: 'p1',
        tricksWon: 8,
        agreedTricks: 5,
        success: true,
        scoreDeltas: {'p1': 9, 'p2': -3, 'p3': -3, 'p4': -3},
      ),
      Round(
        contractType: 'Solo',
        declarerId: 'p2',
        tricksWon: 4,
        agreedTricks: 5,
        success: false,
        scoreDeltas: {'p2': -9, 'p1': 3, 'p3': 3, 'p4': 3},
      ),
    ]);

    final data = biddingAccuracyChart([game]);
    expect(data.first.label, 'Anke'); // 100% > 0%
    expect(data.first.value, 1.0);
    expect(data.last.label, 'Bram');
    expect(data.last.value, 0.0);
  });

  test('riskFactorChart sorts descending and reports the table average', () {
    final game = buildGame([
      Round(
        contractType: 'Ask & Join',
        declarerId: 'p1',
        partnerId: 'p2',
        tricksWon: 9,
        agreedTricks: 8,
        success: true,
        scoreDeltas: {'p1': 3, 'p2': 3, 'p3': -3, 'p4': -3},
      ),
    ]);

    final result = riskFactorChart([game]);
    expect(result.referenceValue, closeTo(0.5, 1e-9)); // one Ask & Join, 2 of 4 seats
    expect(result.data.first.value, 1.0); // p1/p2 were declarers this round
    expect(result.data.first.value >= result.data.last.value, isTrue);
  });
}

// Bulk simulation: X random games through the providers.
//
// For every seed, a random script (roster growth, favourites, games with
// random contracts, Rondpas streaks, undos, deletes, completions,
// abandons) is executed against the real GameProvider/PlayerProvider on
// a temp-directory Hive. After EVERY step the whole provider state is
// compared to the simulation ledger, whose scores come from an
// independent scoring oracle. At the end the app is "relaunched" from
// disk and compared again.
//
// Scale it from the command line:
//   flutter test test/simulation/simulated_games_test.dart \
//     --dart-define=SIM_GAMES=500 --dart-define=SIM_SEEDS=10
// Replay one failing seed:
//   flutter test test/simulation/simulated_games_test.dart --dart-define=SIM_SEED=1234

import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/scoring_settings.dart';

import 'expected_state.dart';
import 'game_generator.dart';
import 'scoring_oracle.dart';
import 'sim_harness.dart';
import 'sim_model.dart';
import 'sim_runner.dart';

const int kGames = int.fromEnvironment('SIM_GAMES', defaultValue: 40);
const int kSeeds = int.fromEnvironment('SIM_SEEDS', defaultValue: 5);
const int kSeed = int.fromEnvironment('SIM_SEED', defaultValue: -1);

List<int> get seeds => kSeed >= 0 ? [kSeed] : [for (var i = 0; i < kSeeds; i++) 1000 + i];

void main() {
  group('random games through the providers', () {
    for (final seed in seeds) {
      test('seed $seed: $kGames games match the ledger after every step and after a relaunch', () async {
        final script = GameGenerator(seed: seed, config: const GeneratorConfig(games: kGames)).generate();
        final h = await SimHarness.open();
        addTearDown(h.dispose);
        final world = ExpectedWorld(settings: h.settings, loc: h.loc);

        await SimRunner(script: script, world: world, driver: ProviderDriver(h)).run(
          checkpoint: (_, _) async => expectProviderState(h, world),
        );

        await h.relaunch();
        expectProviderState(h, world);

        // Sanity: the generator actually exercised what it should.
        expect(script.gameCount, kGames);
        expect(world.games.expand((g) => g.rounds).map((r) => r.contract).toSet().length,
            greaterThanOrEqualTo(kGames >= 20 ? Contract.values.length : 1));
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  group('scoring under non-default settings', () {
    test('custom scoring values + slim bonus off: app matches the oracle', () async {
      final h = await SimHarness.open();
      addTearDown(h.dispose);
      await h.settings.updateScore(
        askAndJoinBase: 3,
        trull: 7,
        aloneBase: 4,
        misere: 6,
        abundanceBase: 8,
        openMisere: 12,
        soloSlim: 20,
        slimBonusEnabled: false,
      );
      final world = ExpectedWorld(settings: h.settings, loc: h.loc);
      final script = GameGenerator(seed: 77, config: const GeneratorConfig(games: 15)).generate();
      await SimRunner(script: script, world: world, driver: ProviderDriver(h)).run(
        checkpoint: (_, _) async => expectProviderState(h, world),
      );
    });
  });

  group('oracle self-checks (hand-computed values)', () {
    final oracle = ScoringOracle(ScoringSettings());
    const seats = ['a', 'b', 'c', 'd'];
    ResolvedRound r(Contract c, {String? p, int agreed = 0, int won = 0, bool m1 = true, bool m2 = true}) =>
        ResolvedRound(
          contract: c,
          declarerId: 'a',
          partnerId: p,
          agreedTricks: agreed,
          tricksWon: won,
          declarerMiserieSuccess: m1,
          partnerMiserieSuccess: m2,
        );

    test('Ask & Join 8 made with 9: 2 + 1 overtrick = 3 each way', () {
      expect(oracle.score(r(Contract.askAndJoin, p: 'b', agreed: 8, won: 9), seats, 1).deltas,
          {'a': 3, 'b': 3, 'c': -3, 'd': -3});
    });
    test('Ask & Join 10 failed with 7: (2+2) + 3 short = 7, team pays', () {
      expect(oracle.score(r(Contract.askAndJoin, p: 'b', agreed: 10, won: 7), seats, 1).deltas,
          {'a': -7, 'b': -7, 'c': 7, 'd': 7});
    });
    test('Solo 5 made with 5 under x4 Rondpas: 2 per opponent, x4', () {
      expect(oracle.score(r(Contract.solo, agreed: 5, won: 5), seats, 4).deltas,
          {'a': 24, 'b': -8, 'c': -8, 'd': -8});
    });
    test('Abondance 9 with all 13: (5+4) doubled = 18 per opponent', () {
      expect(oracle.score(r(Contract.abondance, agreed: 9, won: 13), seats, 1).deltas,
          {'a': 54, 'b': -18, 'c': -18, 'd': -18});
    });
    test('Solo Slim made: 15 per opponent, no slim bonus on top', () {
      expect(oracle.score(r(Contract.soloSlim, agreed: 13, won: 13), seats, 1).deltas,
          {'a': 45, 'b': -15, 'c': -15, 'd': -15});
    });
    test('two-player Miserie, one made one failed: settled independently vs the 2 others', () {
      final res = oracle.score(r(Contract.miserie, p: 'b', m1: true, m2: false), seats, 1);
      expect(res.deltas, {'a': 10, 'b': -10, 'c': 0, 'd': 0});
      expect(res.success, isFalse);
    });
    test('Rondpas multiplier: doubles per trailing pass, resets after a contract, caps at 2^10', () {
      expect(ScoringOracle.multiplierAfter([]), 1);
      expect(ScoringOracle.multiplierAfter([Contract.pass, Contract.pass]), 4);
      expect(ScoringOracle.multiplierAfter([Contract.pass, Contract.solo]), 1);
      expect(ScoringOracle.multiplierAfter(List.filled(12, Contract.pass)), 1024);
    });
  });
}

// Simulation framework — the random script generator.
//
// Produces a [SimScript]: a roster that grows over time, favourites that
// get toggled, and a sequence of games with random rounds, undos,
// deletes, completions and abandons. Everything is drawn from one seeded
// [Random], so a (seed, config) pair always yields the same script — a
// failure message printing the seed is enough to reproduce it.

import 'dart:math';

import 'sim_model.dart';

class GeneratorConfig {
  final int games;

  /// Players added before the first game (at least 4 are always added).
  final int initialPlayers;

  /// Hard cap on roster size, so UI runs don't grow a huge list.
  final int maxPlayers;

  /// Chance, before each game, of adding one more player to the roster.
  final double newPlayerChance;

  /// Chance, before each game, of toggling a random player's favourite.
  final double toggleFavoriteChance;

  final int minRounds;
  final int maxRounds;

  /// Per round played: chance the next step is an undo / a delete of the
  /// last round (only when the game has at least one round).
  final double undoChance;
  final double deleteChance;

  /// Per finished game: chance it is abandoned rather than completed.
  final double abandonChance;

  /// Chance the LAST game is left active (never ended), so the Home and
  /// active-game "continue" paths get exercised too.
  final double leaveLastActiveChance;

  /// Chance a Miserie is played by two players.
  final double twoPlayerMiserieChance;

  /// Relative weight per contract.
  final Map<Contract, int> contractWeights;

  const GeneratorConfig({
    this.games = 10,
    this.initialPlayers = 5,
    this.maxPlayers = 12,
    this.newPlayerChance = 0.3,
    this.toggleFavoriteChance = 0.2,
    this.minRounds = 0,
    this.maxRounds = 20,
    this.undoChance = 0.05,
    this.deleteChance = 0.05,
    this.abandonChance = 0.2,
    this.leaveLastActiveChance = 0.3,
    this.twoPlayerMiserieChance = 0.3,
    this.contractWeights = const {
      Contract.askAndJoin: 30,
      Contract.trull: 6,
      Contract.solo: 16,
      Contract.abondance: 8,
      Contract.miserie: 8,
      Contract.openMiserie: 4,
      Contract.soloSlim: 3,
      Contract.pass: 12,
    },
  });

  /// Small, UI-friendly: few players, short games.
  const GeneratorConfig.ui({int games = 3})
      : this(
          games: games,
          initialPlayers: 4,
          maxPlayers: 7,
          newPlayerChance: 0.5,
          toggleFavoriteChance: 0.4,
          minRounds: 2,
          maxRounds: 8,
          undoChance: 0.1,
          deleteChance: 0.1,
        );
}

/// Single-word, unique, and never equal to a UI label ("Dealer", "Lead",
/// ...) — the UI driver and page validators find players by exact text.
const List<String> kSimNames = [
  'Anke', 'Bram', 'Cato', 'Dries', 'Elke', 'Floor', 'Gert', 'Hanne',
  'Ilse', 'Joris', 'Katrien', 'Lieven', 'Mieke', 'Nand', 'Odette', 'Pieter',
  'Quinten', 'Roos', 'Staf', 'Tine', 'Urbain', 'Veerle', 'Wout', 'Xander',
  'Yana', 'Zeger',
];

class GameGenerator {
  final int seed;
  final GeneratorConfig config;
  final Random _rng;

  GameGenerator({required this.seed, this.config = const GeneratorConfig()}) : _rng = Random(seed);

  final List<String> _roster = [];

  bool _chance(double p) => _rng.nextDouble() < p;
  int _between(int min, int max) => min + _rng.nextInt(max - min + 1);
  T _pick<T>(List<T> xs) => xs[_rng.nextInt(xs.length)];

  String _nextName() {
    final i = _roster.length;
    final base = kSimNames[i % kSimNames.length];
    final lap = i ~/ kSimNames.length;
    return lap == 0 ? base : '$base${lap + 1}';
  }

  SimScript generate() {
    final steps = <SimStep>[];

    void addPlayer() {
      final name = _nextName();
      _roster.add(name);
      steps.add(AddPlayerStep(name));
    }

    for (var i = 0; i < max(4, config.initialPlayers); i++) {
      addPlayer();
    }

    for (var g = 0; g < config.games; g++) {
      if (g > 0 && _roster.length < config.maxPlayers && _chance(config.newPlayerChance)) {
        addPlayer();
      }
      if (_chance(config.toggleFavoriteChance)) {
        steps.add(ToggleFavoriteStep(_pick(_roster)));
      }

      final seats = ([..._roster]..shuffle(_rng)).take(4).toList();
      steps.add(StartGameStep(seats));

      final rounds = _between(config.minRounds, config.maxRounds);
      var live = 0; // rounds currently in the game (after undos)
      for (var r = 0; r < rounds; r++) {
        steps.add(PlayRoundStep(_randomRound(seats)));
        live++;
        if (live > 0 && _chance(config.undoChance)) {
          steps.add(const UndoRoundStep());
          live--;
        } else if (live > 0 && _chance(config.deleteChance)) {
          steps.add(const DeleteLastRoundStep());
          live--;
        }
      }

      final isLast = g == config.games - 1;
      if (isLast && _chance(config.leaveLastActiveChance)) break;
      steps.add(EndGameStep(_chance(config.abandonChance) ? GameEnding.abandon : GameEnding.complete));
    }

    return SimScript(seed: seed, steps: steps);
  }

  Contract _randomContract() {
    final total = config.contractWeights.values.fold(0, (a, b) => a + b);
    var roll = _rng.nextInt(total);
    for (final entry in config.contractWeights.entries) {
      if (roll < entry.value) return entry.key;
      roll -= entry.value;
    }
    throw StateError('unreachable');
  }

  /// Tricks won, biased toward making the contract (~70%), so games have
  /// a realistic mix instead of 50/50 noise.
  int _tricksFor(int agreed) {
    if (agreed == 0 || _chance(0.7)) return _between(agreed, 13);
    return _between(0, agreed - 1);
  }

  SimRound _randomRound(List<String> seats) {
    final contract = _randomContract();
    if (contract == Contract.pass) return const SimRound.pass();

    final shuffled = [...seats]..shuffle(_rng);
    final declarer = shuffled[0];

    if (contract.isMiserie) {
      final two = _chance(config.twoPlayerMiserieChance);
      return SimRound(
        contract: contract,
        declarer: declarer,
        partner: two ? shuffled[1] : null,
        declarerMiserieSuccess: _chance(0.55),
        partnerMiserieSuccess: _chance(0.55),
      );
    }

    final agreed = contract.isNegotiable ? _between(contract.requiredTricks, 13) : contract.requiredTricks;
    final won = contract == Contract.soloSlim ? (_chance(0.5) ? 13 : _between(0, 12)) : _tricksFor(agreed);
    return SimRound(
      contract: contract,
      declarer: declarer,
      partner: contract.isTeam ? shuffled[1] : null,
      agreedTricks: agreed,
      tricksWon: won,
      trump: _pick(Suit.values),
    );
  }
}

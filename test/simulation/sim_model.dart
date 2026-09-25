// Simulation framework — the script model.
//
// A simulation is a flat list of [SimStep]s ("add player Bram", "start a
// game with these four seats", "play this round", "undo", "end the game").
// Steps name players by *name*, never by id: ids are minted by the app
// (`DateTime.now().millisecondsSinceEpoch`), so only the driver that
// executes a step can know them. Names are unique within a simulation
// (the generator guarantees it), which is also what lets the UI driver
// find a player on screen by their text.

/// The seven contracts `GameProvider.addRound` understands, plus Rondpas.
/// String values are exactly the `contractType` keys the app stores.
enum Contract {
  askAndJoin('Ask & Join'),
  trull('Trull'),
  solo('Solo'),
  abondance('Abondance'),
  miserie('Miserie'),
  openMiserie('Open Miserie'),
  soloSlim('Solo Slim'),
  pass('Pass');

  final String key;
  const Contract(this.key);

  bool get isMiserie => this == miserie || this == openMiserie;

  /// Contracts where the round-setup sheet asks for trump and tricks won.
  bool get hasTricks => !isMiserie && this != pass;

  /// Contracts where the sheet has a "negotiated tricks" stepper.
  bool get isNegotiable => this == askAndJoin || this == solo || this == abondance;

  /// Team contracts always have a partner; Miserie optionally does.
  bool get isTeam => this == askAndJoin || this == trull;

  /// The minimum (and, for non-negotiable contracts, the only) number of
  /// agreed tricks — mirrors `kContracts[..]['required']` in
  /// round_setup_dialog.dart, which is what the sheet feeds `addRound`.
  int get requiredTricks => switch (this) {
        askAndJoin => 8,
        trull => 9,
        solo => 5,
        abondance => 9,
        soloSlim => 13,
        miserie || openMiserie || pass => 0,
      };
}

enum Suit {
  hearts('Hearts', '♥'),
  diamonds('Diamonds', '♦'),
  clubs('Clubs', '♣'),
  spades('Spades', '♠');

  final String key;
  final String glyph;
  const Suit(this.key, this.glyph);
}

/// One round exactly as a player would enter it through the round-setup
/// sheet. Every combination the generator produces is one the sheet can
/// produce too, so the UI driver can replay any [SimRound].
class SimRound {
  final Contract contract;

  /// Declarer (or "Player 1" of a two-player Miserie). Null only for Pass.
  final String? declarer;

  /// Partner (team contracts) or "Player 2" of a two-player Miserie.
  final String? partner;

  final int agreedTricks;
  final int tricksWon;
  final Suit? trump;

  /// Miserie only: did the declarer / partner make their Miserie?
  final bool declarerMiserieSuccess;
  final bool partnerMiserieSuccess;

  const SimRound({
    required this.contract,
    this.declarer,
    this.partner,
    this.agreedTricks = 0,
    this.tricksWon = 0,
    this.trump,
    this.declarerMiserieSuccess = true,
    this.partnerMiserieSuccess = true,
  });

  const SimRound.pass() : this(contract: Contract.pass);

  @override
  String toString() {
    if (contract == Contract.pass) return 'Pass';
    final who = partner == null ? declarer : '$declarer+$partner';
    if (contract.isMiserie) {
      final r = partner == null
          ? (declarerMiserieSuccess ? 'made' : 'failed')
          : '${declarerMiserieSuccess ? 'made' : 'failed'}/${partnerMiserieSuccess ? 'made' : 'failed'}';
      return '${contract.key}($who $r)';
    }
    return '${contract.key}($who ${trump?.glyph ?? ''} $tricksWon/$agreedTricks)';
  }
}

/// How a game leaves the active state.
enum GameEnding { complete, abandon }

sealed class SimStep {
  const SimStep();
}

class AddPlayerStep extends SimStep {
  final String name;
  const AddPlayerStep(this.name);
  @override
  String toString() => 'AddPlayer($name)';
}

class ToggleFavoriteStep extends SimStep {
  final String name;
  const ToggleFavoriteStep(this.name);
  @override
  String toString() => 'ToggleFavorite($name)';
}

class StartGameStep extends SimStep {
  /// Seat order: seat 0 deals first, dealing rotates through this order.
  final List<String> seats;
  const StartGameStep(this.seats);
  @override
  String toString() => 'StartGame(${seats.join(', ')})';
}

class PlayRoundStep extends SimStep {
  final SimRound round;
  const PlayRoundStep(this.round);
  @override
  String toString() => 'Round($round)';
}

/// The header's undo icon: removes the most recent round.
class UndoRoundStep extends SimStep {
  const UndoRoundStep();
  @override
  String toString() => 'Undo';
}

/// The trash icon on the most recent round row. Same effect as undo, via
/// `GameProvider.deleteRound(last)` instead of `undoLastRound()`.
class DeleteLastRoundStep extends SimStep {
  const DeleteLastRoundStep();
  @override
  String toString() => 'DeleteLastRound';
}

class EndGameStep extends SimStep {
  final GameEnding ending;
  const EndGameStep(this.ending);
  @override
  String toString() => 'EndGame(${ending.name})';
}

/// A whole generated simulation: the steps, plus the seed that produced
/// them so a failure can always be replayed exactly.
class SimScript {
  final int seed;
  final List<SimStep> steps;
  const SimScript({required this.seed, required this.steps});

  int get gameCount => steps.whereType<StartGameStep>().length;
  int get roundCount => steps.whereType<PlayRoundStep>().length;
}

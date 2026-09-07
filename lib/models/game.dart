import 'package:hive/hive.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';

part 'game.g.dart';

@HiveType(typeId: 1)
class Game extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime dateStarted;

  @HiveField(2)
  late List<Player> players;

  @HiveField(3)
  late List<Round> rounds;

  @HiveField(4)
  late Map<String, int> totalScores; // Maps Player ID to current total score

  @HiveField(5)
  int pointMultiplier; // Doubles each time all players pass (Rondpas)

  // Scoring settings in force when this game was played, captured once at
  // `GameProvider.startGame()` time via `ScoringSettings.toSnapshot()`.
  // Nullable (and NOT `late`) because games saved by app versions before
  // this field existed have no snapshot on disk — anything reading it must
  // fall back to the live `ScoringSettings` when it is null. This is for
  // display / future re-derivation only: round `scoreDeltas` are already
  // persisted per round and must never be recomputed from this snapshot.
  @HiveField(6)
  Map<String, int>? scoringSnapshot;

  // When the game stopped being active. Set by both `GameProvider.endGame()`
  // (a real finish) and `GameProvider.abandonGame()` (abandoned mid-play).
  // Null while the game is still active, and also null for games saved
  // before this field existed — see `isComplete` and
  // `GameProvider.completedGames` for how legacy games are handled.
  @HiveField(7)
  DateTime? dateEnded;

  // True only when the game was played to an actual finish via
  // `endGame()`. `abandonGame()` deliberately leaves this false while
  // still setting `dateEnded`, so history can tell a finished game apart
  // from an abandoned one. Defaults to false, so it is also false for
  // every game saved before this field existed.
  @HiveField(8)
  bool isComplete;

  Game({
    required this.id,
    required this.dateStarted,
    required this.players,
    List<Round>? rounds,
    Map<String, int>? totalScores,
    this.pointMultiplier = 1,
    this.scoringSnapshot,
    this.dateEnded,
    this.isComplete = false,
  }) {
    this.rounds = rounds ?? [];
    this.totalScores = totalScores ?? {
      for (var player in players) player.id: 0
    };
  }
}

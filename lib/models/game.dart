import 'package:hive/hive.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';

part 'game.g.dart';

@HiveType(typeId: 1)
class Game extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late DateTime dateStarted;

  // PLAN.md B4: this used to be `late List<Player> players` — full embedded
  // Player copies. Renamed and made nullable so old on-disk games (which
  // wrote a real list here) still deserialize; no code writes it anymore.
  // Never read this directly — use the `players` getter below, which falls
  // back to deriving id+name from these legacy copies when `playerRefs`
  // (new games) is null. Kept private-ish by convention, not by the
  // language: Hive's generated adapter needs a public field to write into.
  @HiveField(2)
  List<Player>? legacyPlayers;

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

  // PLAN.md B4 fix: the game's roster as an id+name snapshot taken at
  // `startGame()` time — no live `Player` objects. Null only for games
  // saved before this field existed; see the `players` getter.
  @HiveField(9)
  List<GamePlayerRef>? playerRefs;

  Game({
    required this.id,
    required this.dateStarted,
    // Required in practice (every call site always has a roster to give
    // it) even though the field itself is nullable `List<GamePlayerRef>?`
    // — that nullability exists only so games Hive deserializes straight
    // from disk (bypassing this constructor entirely) can leave it unset
    // and fall back to `legacyPlayers` in the `players` getter below.
    required this.playerRefs,
    List<Round>? rounds,
    Map<String, int>? totalScores,
    this.pointMultiplier = 1,
    this.scoringSnapshot,
    this.dateEnded,
    this.isComplete = false,
  }) {
    this.rounds = rounds ?? [];
    this.totalScores = totalScores ?? {
      for (var player in playerRefs!) player.id: 0
    };
  }

  /// The game's roster, as an id+name snapshot. Reads `playerRefs` for
  /// every game started after the B4 migration; for a game saved before it
  /// (`playerRefs == null`), derives the same shape from the legacy
  /// embedded `Player` copies in `legacyPlayers` instead of exposing them
  /// directly — callers never need to know which one backs a given game.
  List<GamePlayerRef> get players =>
      playerRefs ?? legacyPlayers!.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList();
}

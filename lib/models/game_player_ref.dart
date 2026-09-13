import 'package:hive/hive.dart';

part 'game_player_ref.g.dart';

/// A game's roster entry: just the player's id and their name as it was
/// when the game started.
///
/// This is the fix for PLAN.md B4. `Game` used to embed full `Player`
/// objects (`@HiveField(2) late List<Player> players`) — Hive serializes a
/// nested `List<Player>` field by writing a full copy of each object's
/// bytes, not a live reference, so those embedded players silently drifted
/// out of sync with `players_box` (renaming a player never updated their
/// past games) and calling `.save()` on one of them was fragile: it isn't
/// bound to `players_box`, so a save could write nothing, write to the
/// wrong place, or throw, depending on Hive's internal state for that
/// object.
///
/// `GamePlayerRef` intentionally carries nothing else — no
/// `isFavorite`/`gamesPlayed`/mutable stats — because everywhere a game's
/// roster is read (standings, round rows, history, stats) only `id` and
/// `name` are ever used; anything live about a player belongs to
/// `PlayerProvider`/`players_box`, looked up by `id`.
@HiveType(typeId: 3)
class GamePlayerRef {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  const GamePlayerRef({required this.id, required this.name});
}

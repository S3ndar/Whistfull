import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/utils/hive_recovery.dart';

class PlayerProvider extends ChangeNotifier {
  static const String _boxName = 'players_box';
  Box<Player>? _playersBox;
  List<Player> _players = [];

  List<Player> get players => _players;

  Future<void> init() async {
    try {
      _playersBox = await Hive.openBox<Player>(_boxName);
    } catch (e) {
      debugPrint('Error initializing PlayerProvider Hive box: $e');
      // Only reset the box when the error indicates a genuinely
      // unreadable/incompatible on-disk schema. A transient error should
      // leave the box null (and the app degraded) rather than wipe data.
      if (isUnrecoverableHiveError(e)) {
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          _playersBox = await Hive.openBox<Player>(_boxName);
        } catch (inner) {
          debugPrint('Critical error resetting players Hive box: $inner');
        }
      }
    }
    _loadPlayers();
  }

  void _loadPlayers() {
    if (_playersBox == null) return;
    _players = _playersBox!.values.toList();
    _sortPlayers();
    notifyListeners();
  }

  void _sortPlayers() {
    // Sort logic: Favorites first, then alphabetical
    _players.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> addPlayer(String name) async {
    final player = Player(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    await _playersBox?.put(player.id, player);
    _loadPlayers();
  }

  Future<void> toggleFavorite(Player player) async {
    player.isFavorite = !player.isFavorite;
    await player.save();
    _loadPlayers();
  }

  // Takes ids rather than `Player` objects (PLAN.md B4): the caller is
  // `Game.players`, which are id+name-only `GamePlayerRef`s, not live
  // `Player`s — looking each one up here by id and mutating/saving *that*
  // box-bound instance is exactly what avoids the fragile "`.save()` on a
  // detached embedded copy" failure mode B4 describes. A player deleted
  // since the game started is simply skipped.
  Future<void> incrementGamesPlayed(List<String> playerIds) async {
    final box = _playersBox;
    if (box == null) return;
    for (var id in playerIds) {
      final player = box.get(id);
      if (player == null) continue;
      player.gamesPlayed++;
      await player.save();
    }
    _loadPlayers();
  }

  Future<void> populateDefaults() async {
    final defaults = ['Sander', 'Alice', 'Bob', 'Charlie'];
    for (var name in defaults) {
      final player = Player(
        id: DateTime.now().millisecondsSinceEpoch.toString() + name,
        name: name,
        isFavorite: true,
      );
      await _playersBox?.put(player.id, player);
    }
    _loadPlayers();
  }

  Future<void> deletePlayer(String id) async {
    await _playersBox?.delete(id);
    _loadPlayers();
  }

  Future<void> clearAll() async {
    await _playersBox?.clear();
    _loadPlayers();
  }
}

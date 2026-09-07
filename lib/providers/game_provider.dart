import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/utils/hive_recovery.dart';

class GameProvider extends ChangeNotifier {
  static const String _boxName = 'games_box';
  static const String _stateBoxName = 'app_state_box';
  Box<Game>? _gamesBox;
  Box? _appStateBox;
  Game? _activeGame;
  int _dealerIndex = 0;

  Game? get activeGame => _activeGame;
  int get dealerIndex => _dealerIndex;
  List<Game> get allGames => _gamesBox?.values.toList() ?? [];

  /// Games to show in history/stats: every game that has actually ended,
  /// i.e. is not the currently active game.
  ///
  /// A game is unambiguously "ended" once `dateEnded` is set or
  /// `isComplete` is true — both `endGame()` and `abandonGame()` set at
  /// least one of these before clearing the active game.
  ///
  /// Migration note: games saved by app versions before `dateEnded` and
  /// `isComplete` existed have NEITHER field set on disk, even if they
  /// were played to a genuine finish — old code never wrote them. If this
  /// getter only trusted the new fields, every one of a user's pre-upgrade
  /// games would silently disappear from their history the moment they
  /// update the app. To prevent that data loss, a non-active game with
  /// neither field set (the only case that can still reach the fallback
  /// below) is also treated as completed. Such legacy games simply can't
  /// be told apart from "finished" vs "abandoned" — they show in history
  /// without an Abandoned badge, matching pre-5.2 behaviour exactly.
  List<Game> get completedGames => _gamesBox?.values.where((g) {
        if (g.id == _activeGame?.id) return false;
        if (g.dateEnded != null || g.isComplete) return true;
        // Legacy game (see migration note above): still counts as completed.
        return true;
      }).toList() ?? [];

  int get pointMultiplier => _activeGame?.pointMultiplier ?? 1;

  Player? get currentDealer =>
      _activeGame != null ? _activeGame!.players[_dealerIndex] : null;

  Future<void> init() async {
    try {
      _gamesBox = await Hive.openBox<Game>(_boxName);
      _appStateBox = await Hive.openBox(_stateBoxName);

      if (_gamesBox == null || _appStateBox == null) return;

      final activeId = _appStateBox?.get('activeGameId');
      if (activeId != null) {
        _activeGame = _gamesBox?.get(activeId);
        if (_activeGame != null) {
          // Recalculate dealer index based on rounds played (dealer rotates clockwise)
          _dealerIndex =
              _activeGame!.rounds.length % _activeGame!.players.length;
        }
      }
    } catch (e) {
      debugPrint('Error initializing GameProvider: $e');
      // Only reset the boxes when the error indicates a genuinely
      // unreadable/incompatible on-disk schema. A transient error should
      // leave the boxes null (and the app degraded) rather than wipe data.
      if (isUnrecoverableHiveError(e)) {
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          _gamesBox = await Hive.openBox<Game>(_boxName);
          _appStateBox = await Hive.openBox(_stateBoxName);
          _appStateBox!.delete('activeGameId');
        } catch (inner) {
          debugPrint('Critical Hive error resetting boxes: $inner');
        }
      }
    }
    notifyListeners();
  }

  void startGame(List<Player> players, {required ScoringSettings settings}) {
    _dealerIndex = 0;
    _activeGame = Game(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateStarted: DateTime.now(),
      players: players,
      // Snapshot the live scoring settings so history keeps reading the
      // values that were actually in force when this game was played,
      // even if the user changes settings afterwards.
      scoringSnapshot: settings.toSnapshot(),
    );
    // Explicitly add to box and mark as active
    _gamesBox!.put(_activeGame!.id, _activeGame!);
    _appStateBox!.put('activeGameId', _activeGame!.id);
    notifyListeners();
  }

  // Finalizes the game as a genuine finish, clearing active status.
  void endGame() {
    if (_activeGame != null) {
      _activeGame!.dateEnded = DateTime.now();
      _activeGame!.isComplete = true;
      _gamesBox!.put(_activeGame!.id, _activeGame!);
    }
    _activeGame = null;
    _appStateBox!.delete('activeGameId');
    notifyListeners();
  }

  /// Ends the active game without recording a winner. Unlike `endGame()`,
  /// `isComplete` stays false — `dateEnded` alone marks it as ended, so
  /// `completedGames` still shows it in history while the UI can flag it
  /// with an "Abandoned" badge instead of treating it as a normal finish.
  void abandonGame() {
    if (_activeGame != null) {
      _activeGame!.dateEnded = DateTime.now();
      _gamesBox!.put(_activeGame!.id, _activeGame!);
    }
    _activeGame = null;
    _appStateBox!.delete('activeGameId');
    notifyListeners();
  }

  Map<String, int> addRound({
    required String contractType,
    required String declarerId,
    String? partnerId,
    required int tricksWon,
    required int agreedTricks,
    required bool miserieSuccess,
    bool partnerMiserieSuccess = true,
    required ScoringSettings settings,
    String? trump,
  }) {
    if (_activeGame == null) return {};

    final deltas = <String, int>{};
    for (var p in _activeGame!.players) {
      deltas[p.id] = 0;
    }

    bool success = false;
    final dealerId = currentDealer?.id ?? declarerId;

    switch (contractType) {
      case 'Ask & Join':
        success = tricksWon >= agreedTricks;
        final base = settings.askAndJoinBase; // 2
        final escalatedBase = base + (agreedTricks - 8);
        final overtricks = success ? (tricksWon - agreedTricks) : 0;
        final totalPoints = escalatedBase + overtricks;
        _applyTeam(deltas, declarerId, partnerId, totalPoints, success);
        break;

      case 'Trull':
        success = tricksWon >= agreedTricks;
        final base = settings.trull; // 9
        final overtricks = success ? (tricksWon - agreedTricks) : 0;
        final totalPoints = base + overtricks;
        _applyTeam(deltas, declarerId, partnerId, totalPoints, success);
        break;

      case 'Solo':
        success = tricksWon >= agreedTricks;
        final base = settings.aloneBase; // 2
        final escalatedBase = base + (agreedTricks - 5);
        final overtricks = success ? (tricksWon - agreedTricks) : 0;
        final totalPoints = escalatedBase + overtricks;
        _applySolo(deltas, declarerId, totalPoints, success);
        break;

      case 'Abondance':
        success = tricksWon >= agreedTricks;
        final base = settings.abundanceBase; // 5
        final escalatedBase = base + (agreedTricks - 9);
        final overtricks = success ? (tricksWon - agreedTricks) : 0;
        final totalPoints = escalatedBase + overtricks;
        _applySolo(deltas, declarerId, totalPoints, success);
        break;

      case 'Miserie':
      case 'Open Miserie':
        final points = contractType == 'Miserie' ? settings.misere : settings.openMisere;
        if (partnerId != null) {
          final defenders = _activeGame!.players
              .map((p) => p.id)
              .where((id) => id != declarerId && id != partnerId)
              .toList();

          // Declarer (declarerId) scoring
          if (miserieSuccess) {
            deltas[declarerId] = (deltas[declarerId] ?? 0) + (points * defenders.length);
            for (var defId in defenders) {
              deltas[defId] = (deltas[defId] ?? 0) - points;
            }
          } else {
            deltas[declarerId] = (deltas[declarerId] ?? 0) - (points * defenders.length);
            for (var defId in defenders) {
              deltas[defId] = (deltas[defId] ?? 0) + points;
            }
          }

          // Partner (partnerId) scoring
          if (partnerMiserieSuccess) {
            deltas[partnerId] = (deltas[partnerId] ?? 0) + (points * defenders.length);
            for (var defId in defenders) {
              deltas[defId] = (deltas[defId] ?? 0) - points;
            }
          } else {
            deltas[partnerId] = (deltas[partnerId] ?? 0) - (points * defenders.length);
            for (var defId in defenders) {
              deltas[defId] = (deltas[defId] ?? 0) + points;
            }
          }

          success = miserieSuccess && partnerMiserieSuccess;
        } else {
          success = miserieSuccess;
          _applySolo(deltas, declarerId, points, success);
        }
        break;

      case 'Solo Slim':
        success = tricksWon >= 13;
        _applySolo(deltas, declarerId, settings.soloSlim, success); // 15
        break;
    }

    // Apply multiplier to all deltas (Rondpas stacking). This must be read
    // BEFORE the new round is appended below — it is the multiplier that
    // applies to *this* round.
    final multiplier = _activeGame!.pointMultiplier;
    deltas.updateAll((_, v) => v * multiplier);

    final round = Round(
      contractType: contractType,
      declarerId: declarerId,
      partnerId: partnerId,
      tricksWon: tricksWon,
      scoreDeltas: deltas,
      success: success,
      dealerId: dealerId,
      agreedTricks: agreedTricks,
      trump: trump,
      multiplier: multiplier,
    );
    _activeGame!.rounds.add(round);

    // Recompute cumulative totals, dealer index and the pending Rondpas
    // multiplier purely from the round list (also persists + notifies).
    recomputeFromRounds();

    return deltas;
  }

  /// Records a "Rondpas" (all pass) round: advances dealer and doubles next multiplier.
  void addPassRound() {
    if (_activeGame == null) return;

    final dealerId = currentDealer?.id ?? _activeGame!.players[0].id;
    final emptyDeltas = <String, int>{
      for (var p in _activeGame!.players) p.id: 0
    };

    final round = Round(
      contractType: 'Pass',
      declarerId: dealerId, // use dealer as reference
      tricksWon: 0,
      scoreDeltas: emptyDeltas,
      success: true,
      dealerId: dealerId,
      agreedTricks: 0,
    );
    _activeGame!.rounds.add(round);

    // Recompute cumulative totals, dealer index and the pending Rondpas
    // multiplier purely from the round list (also persists + notifies).
    recomputeFromRounds();
  }

  /// Recomputes cumulative totals, dealer index and the pending Rondpas
  /// multiplier purely from the round list. Single source of truth.
  void recomputeFromRounds() {
    if (_activeGame == null) return;

    // Reset every player's total, then re-sum each round's scoreDeltas.
    // scoreDeltas are already stored post-multiplier — do NOT re-apply it.
    for (var p in _activeGame!.players) {
      _activeGame!.totalScores[p.id] = 0;
    }
    for (var round in _activeGame!.rounds) {
      round.scoreDeltas.forEach((playerId, delta) {
        _activeGame!.totalScores[playerId] =
            (_activeGame!.totalScores[playerId] ?? 0) + delta;
      });
    }

    // Dealer rotates by one seat per round (Rondpas rounds included).
    _dealerIndex =
        _activeGame!.rounds.length % _activeGame!.players.length;

    // Pending multiplier = 2 ^ (trailing consecutive Rondpas rounds).
    // A real contract resets the streak (and therefore the multiplier) to 1.
    int trailingPasses = 0;
    for (var round in _activeGame!.rounds.reversed) {
      if (round.contractType == 'Pass') {
        trailingPasses++;
      } else {
        break;
      }
    }
    final exponent = trailingPasses > 10 ? 10 : trailingPasses;
    _activeGame!.pointMultiplier = 1 << exponent;

    _gamesBox!.put(_activeGame!.id, _activeGame!);
    notifyListeners();
  }

  /// Removes the most recent round and restores all derived state.
  bool undoLastRound() {
    if (_activeGame == null || _activeGame!.rounds.isEmpty) return false;
    _activeGame!.rounds.removeLast();
    recomputeFromRounds();
    return true;
  }

  /// Removes the round at [index] and restores all derived state.
  bool deleteRound(int index) {
    if (_activeGame == null) return false;
    if (index < 0 || index >= _activeGame!.rounds.length) return false;
    _activeGame!.rounds.removeAt(index);
    recomputeFromRounds();
    return true;
  }

  void _applyTeam(
    Map<String, int> deltas,
    String declarerId,
    String? partnerId,
    int points,
    bool success,
  ) {
    final playingTeam = [declarerId, ?partnerId];
    final defendingTeam = _activeGame!.players
        .map((p) => p.id)
        .where((id) => !playingTeam.contains(id))
        .toList();

    if (success) {
      for (var id in playingTeam) {
        deltas[id] = (deltas[id] ?? 0) + points;
      }
      for (var id in defendingTeam) {
        deltas[id] = (deltas[id] ?? 0) - points;
      }
    } else {
      for (var id in playingTeam) {
        deltas[id] = (deltas[id] ?? 0) - points;
      }
      for (var id in defendingTeam) {
        deltas[id] = (deltas[id] ?? 0) + points;
      }
    }
  }

  void _applySolo(
    Map<String, int> deltas,
    String declarerId,
    int points,
    bool success,
  ) {
    final defenders = _activeGame!.players
        .map((p) => p.id)
        .where((id) => id != declarerId)
        .toList();

    if (success) {
      deltas[declarerId] =
          (deltas[declarerId] ?? 0) + (points * defenders.length);
      for (var id in defenders) {
        deltas[id] = (deltas[id] ?? 0) - points;
      }
    } else {
      deltas[declarerId] =
          (deltas[declarerId] ?? 0) - (points * defenders.length);
      for (var id in defenders) {
        deltas[id] = (deltas[id] ?? 0) + points;
      }
    }
  }

  Future<void> clearAllData() async {
    await _gamesBox?.clear();
    await _appStateBox?.clear();
    _activeGame = null;
    _dealerIndex = 0;
    notifyListeners();
  }
}

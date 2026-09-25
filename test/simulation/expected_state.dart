// Simulation framework — the expected-state ledger.
//
// [ExpectedWorld] is the simulation's own bookkeeping of what the app
// SHOULD contain after every step: the roster (names, favourites, games
// played), every game (seats, rounds, oracle-scored deltas, how it
// ended). It is fed the same [SimStep]s as the app and never reads app
// state, so comparing the two is a real check.
//
// On top of the raw ledger sit per-page "views" ([ActiveGameView],
// [HistoryView], ...): plain data describing, string for string, what
// each screen must render. They are built through a real
// [LocalizationProvider] so the expectations follow the translation
// tables rather than hardcoding English.
//
// Players are keyed by NAME throughout (unique per simulation); the
// app's ids are only needed to compare against provider state and are
// bound by the driver via [ExpectedWorld.bindId].

import 'dart:math';

import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/scoring_settings.dart';

import 'scoring_oracle.dart';
import 'sim_model.dart';

class ExpectedPlayer {
  final String name;
  bool isFavorite = false;
  int gamesPlayed = 0;
  ExpectedPlayer(this.name);
}

class ExpectedRound {
  final SimRound sim;
  final String dealer;
  final Map<String, int> deltas; // by player name
  final bool success;
  final int multiplier;
  const ExpectedRound({
    required this.sim,
    required this.dealer,
    required this.deltas,
    required this.success,
    required this.multiplier,
  });

  Contract get contract => sim.contract;
}

enum GameStatus { active, completed, abandoned }

class ExpectedGame {
  /// 0-based start order — also the order the app's Hive box holds them.
  final int index;
  final List<String> seats;
  final List<ExpectedRound> rounds = [];
  GameStatus status = GameStatus.active;

  ExpectedGame(this.index, this.seats);

  Map<String, int> get totals {
    final t = {for (final s in seats) s: 0};
    for (final r in rounds) {
      r.deltas.forEach((name, d) => t[name] = t[name]! + d);
    }
    return t;
  }

  int get dealerIndex => rounds.length % seats.length;
  String get dealer => seats[dealerIndex];
  int get pendingMultiplier => ScoringOracle.multiplierAfter(rounds.map((r) => r.contract).toList());

  int get maxScore => totals.values.reduce(max);

  /// Every player on the top score, in seat order (ties included).
  List<String> get winners => seats.where((s) => totals[s] == maxScore).toList();

  /// The one player wearing the Lead badge, or null on a tie at the top.
  String? get soleLeader {
    final w = winners;
    return w.length == 1 ? w.single : null;
  }
}

class ExpectedWorld {
  final ScoringSettings settings;
  final LocalizationProvider loc;
  final ScoringOracle oracle;

  ExpectedWorld._(this.settings, this.loc) : oracle = ScoringOracle(settings);

  factory ExpectedWorld({ScoringSettings? settings, LocalizationProvider? loc}) =>
      ExpectedWorld._(settings ?? ScoringSettings(), loc ?? LocalizationProvider());

  final Map<String, ExpectedPlayer> players = {};
  final List<ExpectedGame> games = [];

  ExpectedGame? get activeGame =>
      games.isNotEmpty && games.last.status == GameStatus.active ? games.last : null;

  /// Every game that is not the active one, oldest first — the app's
  /// `GameProvider.completedGames` (which includes abandoned games).
  List<ExpectedGame> get endedGames => games.where((g) => g.status != GameStatus.active).toList();

  // Kept apart from [players]: a driver binds the id right after the app
  // created the player, which is before the ledger applies the step.
  final Map<String, String> _ids = {};

  String idOf(String name) {
    final id = _ids[name];
    if (id == null) throw StateError('No app id bound for player "$name" yet');
    return id;
  }

  void bindId(String name, String id) => _ids[name] = id;

  // ─── Applying steps ────────────────────────────────────────────────────

  /// Applies [step] to the ledger. Returns the oracle result for a
  /// [PlayRoundStep] (so a driver can compare it to what the app
  /// returned), null otherwise.
  OracleResult? apply(SimStep step) {
    switch (step) {
      case AddPlayerStep(:final name):
        if (players.containsKey(name)) throw StateError('Duplicate player name "$name"');
        players[name] = ExpectedPlayer(name);
      case ToggleFavoriteStep(:final name):
        players[name]!.isFavorite = !players[name]!.isFavorite;
      case StartGameStep(:final seats):
        if (activeGame != null) throw StateError('StartGame while a game is still active');
        games.add(ExpectedGame(games.length, seats));
      case PlayRoundStep(:final round):
        return _playRound(round);
      case UndoRoundStep():
      case DeleteLastRoundStep():
        final g = activeGame!;
        if (g.rounds.isNotEmpty) g.rounds.removeLast();
      case EndGameStep(:final ending):
        final g = activeGame!;
        if (ending == GameEnding.complete) {
          g.status = GameStatus.completed;
          for (final s in g.seats) {
            players[s]!.gamesPlayed++;
          }
        } else {
          g.status = GameStatus.abandoned;
        }
    }
    return null;
  }

  OracleResult _playRound(SimRound sim) {
    final g = activeGame!;
    final multiplier = g.pendingMultiplier;
    final dealer = g.dealer;
    final resolved = ResolvedRound(
      contract: sim.contract,
      declarerId: sim.declarer,
      partnerId: sim.partner,
      agreedTricks: sim.agreedTricks,
      tricksWon: sim.tricksWon,
      declarerMiserieSuccess: sim.declarerMiserieSuccess,
      partnerMiserieSuccess: sim.partnerMiserieSuccess,
    );
    final result = oracle.score(resolved, g.seats, multiplier);
    g.rounds.add(ExpectedRound(
      sim: sim,
      dealer: dealer,
      deltas: result.deltas,
      success: result.success,
      multiplier: multiplier,
    ));
    return result;
  }

  // ─── Derived facts ─────────────────────────────────────────────────────

  /// Successful Solo Slims per player, across every game (active one
  /// included) — what drives the crown badge.
  Map<String, int> get soloSlimCounts {
    final counts = <String, int>{};
    for (final g in games) {
      for (final r in g.rounds) {
        if (r.contract == Contract.soloSlim && r.success) {
          counts[r.sim.declarer!] = (counts[r.sim.declarer!] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Roster order on the Players page: favourites first, then
  /// case-insensitive alphabetical.
  List<String> get rosterOrder {
    final list = players.values.toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list.map((p) => p.name).toList();
  }

  // ─── Formatting helpers (mirror the app's display rules) ──────────────

  String t(String key) => loc.translate(key);

  static String signed(int v) => v >= 0 ? '+$v' : '$v';
  static String deltaText(int v) => v == 0 ? '·' : (v > 0 ? '+$v' : '$v');

  String contractName(Contract c) => t(switch (c) {
        Contract.askAndJoin => 'bid_ask_join',
        Contract.trull => 'bid_trull',
        Contract.solo => 'bid_alone',
        Contract.abondance => 'bid_abundance',
        Contract.miserie => 'bid_misere',
        Contract.openMiserie => 'bid_open_misere',
        Contract.soloSlim => 'bid_solo_slim',
        Contract.pass => 'bid_pass',
      });

  String winnerLine(ExpectedGame g) =>
      t('history_winner').replaceFirst('{}', g.winners.join(' & ')).split('(').first.trim();

  String? crownLabel(String name) {
    final n = soloSlimCounts[name] ?? 0;
    if (n <= 1) return null;
    return t('crown_times').replaceFirst('{}', '$n');
  }

  RoundRowView roundRow(ExpectedGame g, int index) {
    final r = g.rounds[index];
    final n = index + 1;
    final List<String> meta;
    if (r.contract == Contract.pass) {
      meta = ['$n', '${t('bid_pass')} · ${t('dealer')}: ${r.dealer}'];
    } else {
      final who = r.sim.partner == null ? r.sim.declarer! : '${r.sim.declarer} & ${r.sim.partner}';
      meta = [
        '$n',
        if (r.sim.trump != null) r.sim.trump!.glyph,
        contractName(r.contract),
        who,
        (r.success ? t('setup_succeeded') : t('setup_failed')).toUpperCase(),
      ];
    }
    return RoundRowView(
      roundNumber: n,
      meta: meta,
      deltas: g.seats.map((s) => deltaText(r.deltas[s]!)).toList(),
    );
  }

  // ─── Page views ────────────────────────────────────────────────────────

  ActiveGameView activeGameView() {
    final g = activeGame!;
    final totals = g.totals;
    final slims = soloSlimCounts;
    return ActiveGameView(
      headerLine:
          '${t('round')} ${(g.rounds.length + 1).toString().padLeft(2, '0')} · ${t('dealer')} ${g.dealer}',
      cells: [
        for (final s in g.seats)
          HeaderCellView(
            name: s.split(' ').first,
            scoreText: signed(totals[s]!),
            isDealer: s == g.dealer,
            isLeader: s == g.soleLeader,
            hasCrown: (slims[s] ?? 0) > 0,
            crownLabel: crownLabel(s),
          ),
      ],
      multiplierBanner: g.pendingMultiplier > 1
          ? '${t('bid_pass')} — ${t('active_game_next_round')} ×${g.pendingMultiplier}'
          : null,
      // Newest first, as the live round list renders them.
      rows: [for (var i = g.rounds.length - 1; i >= 0; i--) roundRow(g, i)],
      emptyText: g.rounds.isEmpty ? t('active_game_no_rounds') : null,
      suitCounts: {
        for (final s in Suit.values) s: g.rounds.where((r) => r.sim.trump == s).length,
      },
    );
  }

  HomeView homeView() {
    final g = activeGame;
    return HomeView(
      hasActiveGame: g != null,
      dealerLine: g == null ? null : '${t('dealer')} · ${g.dealer}',
      tableScores: g == null ? const {} : {for (final s in g.seats) s: signed(g.totals[s]!)},
      showsPlayersNeeded: g == null && players.length < 4,
      primaryLabel: (g != null ? t('continue_game') : t('new_game')).toUpperCase(),
      primaryEnabled: g != null || players.length >= 4,
    );
  }

  PlayersView playersView() => PlayersView(
        order: rosterOrder,
        favorites: {for (final p in players.values) p.name: p.isFavorite},
        crowned: soloSlimCounts.keys.toSet(),
      );

  HistoryView historyView() {
    final ended = endedGames.reversed.toList(); // newest first
    return HistoryView(
      emptyText: ended.isEmpty ? t('history_empty') : null,
      showsStatsSection: ended.length >= 2,
      entries: [
        for (final g in ended)
          HistoryEntryView(
            gameIndex: g.index,
            winnerLine: winnerLine(g),
            roundsLine: t('history_rounds_played').replaceFirst('{}', '${g.rounds.length}'),
            scoreText: signed(g.maxScore),
            abandoned: g.status == GameStatus.abandoned,
          ),
      ],
    );
  }

  RecapView recapView(ExpectedGame g) {
    final totals = g.totals;
    return RecapView(
      finalScores: {for (final s in g.seats) s.split(' ').first: signed(totals[s]!)},
      rankedScores: (g.seats.map((s) => totals[s]!).toList()..sort((a, b) => b - a)),
      soleLeader: g.soleLeader,
      rows: [for (var i = 0; i < g.rounds.length; i++) roundRow(g, i)], // oldest first
    );
  }

  PlayerStatsView playerStatsView(String name) {
    final p = players[name]!;
    final mine = endedGames.where((g) => g.seats.contains(name)).toList().reversed.toList();
    var total = 0;
    var wins = 0;
    int? best;
    for (final g in mine) {
      final score = g.totals[name]!;
      total += score;
      if (best == null || score > best) best = score;
      if (score == g.maxScore) wins++;
    }
    final winRate = mine.isEmpty ? 0.0 : wins / mine.length * 100;
    return PlayerStatsView(
      title: t('stats_title').replaceFirst('{}', name),
      subtitle: (p.isFavorite ? t('players_favorite') : 'Player').toUpperCase(),
      stats: {
        t('stats_games').toUpperCase(): '${mine.length}',
        t('stats_wins').toUpperCase(): '$wins',
        t('stats_win_rate').toUpperCase(): '${winRate.toStringAsFixed(1)}%',
        t('stats_best_game').toUpperCase(): '${best ?? 0}',
        t('stats_avg_points').toUpperCase(): mine.isEmpty ? '0.0' : (total / mine.length).toStringAsFixed(1),
      },
      pastGames: [for (final g in mine) (winnerLine(g), signed(g.totals[name]!))],
      emptyText: mine.isEmpty ? t('stats_no_games') : null,
    );
  }

  CelebrationView celebrationView() {
    final g = activeGame!;
    return CelebrationView(
      heading: (g.winners.length > 1 ? t('stats_winners') : t('stats_winner')).toUpperCase(),
      winners: g.winners,
      scoreLine: '${t('score')}: ${g.maxScore}',
    );
  }
}

// ─── View value types ────────────────────────────────────────────────────

class HeaderCellView {
  final String name;
  final String scoreText;
  final bool isDealer;
  final bool isLeader;
  final bool hasCrown;
  final String? crownLabel;
  const HeaderCellView({
    required this.name,
    required this.scoreText,
    required this.isDealer,
    required this.isLeader,
    required this.hasCrown,
    required this.crownLabel,
  });
}

class RoundRowView {
  final int roundNumber;

  /// Left-to-right texts of the meta band: number, trump glyph (if any),
  /// contract name, contracting players, result badge — or, for a
  /// Rondpas, number + "Round Pass · Dealer: X".
  final List<String> meta;

  /// One delta text per seat, in seat order.
  final List<String> deltas;
  const RoundRowView({required this.roundNumber, required this.meta, required this.deltas});
}

class ActiveGameView {
  final String headerLine;
  final List<HeaderCellView> cells;
  final String? multiplierBanner;
  final List<RoundRowView> rows;
  final String? emptyText;
  final Map<Suit, int> suitCounts;
  const ActiveGameView({
    required this.headerLine,
    required this.cells,
    required this.multiplierBanner,
    required this.rows,
    required this.emptyText,
    required this.suitCounts,
  });
}

class HomeView {
  final bool hasActiveGame;
  final String? dealerLine;
  final Map<String, String> tableScores;
  final bool showsPlayersNeeded;
  final String primaryLabel;
  final bool primaryEnabled;
  const HomeView({
    required this.hasActiveGame,
    required this.dealerLine,
    required this.tableScores,
    required this.showsPlayersNeeded,
    required this.primaryLabel,
    required this.primaryEnabled,
  });
}

class PlayersView {
  final List<String> order;
  final Map<String, bool> favorites;
  final Set<String> crowned;
  const PlayersView({required this.order, required this.favorites, required this.crowned});
}

class HistoryEntryView {
  final int gameIndex;
  final String winnerLine;
  final String roundsLine;
  final String scoreText;
  final bool abandoned;
  const HistoryEntryView({
    required this.gameIndex,
    required this.winnerLine,
    required this.roundsLine,
    required this.scoreText,
    required this.abandoned,
  });
}

class HistoryView {
  final String? emptyText;
  final bool showsStatsSection;
  final List<HistoryEntryView> entries;
  const HistoryView({required this.emptyText, required this.showsStatsSection, required this.entries});
}

class RecapView {
  /// First name -> signed final score.
  final Map<String, String> finalScores;

  /// Final scores, highest first — the column order the recap must use.
  final List<int> rankedScores;
  final String? soleLeader;
  final List<RoundRowView> rows;
  const RecapView({
    required this.finalScores,
    required this.rankedScores,
    required this.soleLeader,
    required this.rows,
  });
}

class PlayerStatsView {
  final String title;
  final String subtitle;

  /// Uppercased stat label -> value text.
  final Map<String, String> stats;

  /// Newest first: (winner line, this player's signed score).
  final List<(String, String)> pastGames;
  final String? emptyText;
  const PlayerStatsView({
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.pastGames,
    required this.emptyText,
  });
}

class CelebrationView {
  final String heading;
  final List<String> winners;
  final String scoreLine;
  const CelebrationView({required this.heading, required this.winners, required this.scoreLine});
}

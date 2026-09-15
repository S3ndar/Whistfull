import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/localization_provider.dart';

import 'package:intl/intl.dart';
import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

class PlayerStatsPage extends StatelessWidget {
  final Player player;

  const PlayerStatsPage({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final completedGames = context.watch<GameProvider>().completedGames;
    final loc = context.watch<LocalizationProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final colors = AppTheme.of(context);

    // Find the latest version of the player from provider to get updated favorite status
    final latestPlayer = playerProvider.players.firstWhere((p) => p.id == player.id, orElse: () => player);

    // Filter games this player participated in (reversed for most recent)
    final playerGames = completedGames.where((g) => g.players.any((p) => p.id == player.id)).toList().reversed.toList();

    int totalPoints = 0;
    int wins = 0;
    int? bestScore;

    for (var game in playerGames) {
      final playerScore = game.totalScores[player.id] ?? 0;
      totalPoints += playerScore;

      if (bestScore == null || playerScore > bestScore) {
        bestScore = playerScore;
      }

      // Check if this player had the highest score in the game
      int maxScore = game.totalScores.isNotEmpty
          ? game.totalScores.values.reduce((a, b) => a > b ? a : b)
          : 0;
      if (playerScore == maxScore) {
        wins++;
      }
    }

    final winRate = playerGames.isEmpty ? 0.0 : (wins / playerGames.length) * 100;

    String formatTitleDate(DateTime date) {
      final locale = loc.currentLanguage == AppLanguage.nl ? 'nl_BE' : 'en_US';
      try {
        return DateFormat('MMM d, yyyy • HH:mm', locale).format(date);
      } catch (e) {
        return DateFormat('MMM d, yyyy • HH:mm').format(date);
      }
    }

    final statCells = [
      (loc.translate('stats_games'), '${playerGames.length}'),
      (loc.translate('stats_wins'), '$wins'),
      (loc.translate('stats_win_rate'), '${winRate.toStringAsFixed(1)}%'),
      (loc.translate('stats_best_game'), '${bestScore ?? 0}'),
      (loc.translate('stats_avg_points'), playerGames.isEmpty ? '0.0' : (totalPoints / playerGames.length).toStringAsFixed(1)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('stats_title').replaceFirst('{}', latestPlayer.name)),
        actions: [
          IconButton(
            icon: Icon(
              latestPlayer.isFavorite ? Icons.star : Icons.star_border,
              color: latestPlayer.isFavorite ? colors.ink : colors.muted,
            ),
            onPressed: () => context.read<PlayerProvider>().toggleFavorite(latestPlayer),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latestPlayer.name, style: WhistlyText.sectionHead(colors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    (latestPlayer.isFavorite ? loc.translate('players_favorite') : 'Player').toUpperCase(),
                    style: WhistlyText.eyebrow(colors.muted),
                  ),
                ],
              ),
            ),

            // Stat grid — line grid of bg cells, per spec's Player-grid
            // pattern (§5): label (eyebrow) over value (mono numeral).
            Container(
              color: colors.line,
              padding: const EdgeInsets.only(top: 2),
              // Fixed cell height via mainAxisExtent rather than
              // childAspectRatio: an aspect ratio ties cell height to the
              // window width, so on a wide viewport these cells grow absurdly
              // tall. Same fix as _PlayerGrid in main.dart.
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  mainAxisExtent: 84,
                ),
                itemCount: statCells.length,
                itemBuilder: (context, i) {
                  final (label, value) = statCells[i];
                  return Container(
                    color: colors.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value, style: WhistlyText.screenNumeral(colors.ink, size: 24)),
                        const SizedBox(height: 2),
                        Text(label.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
              child: Text(loc.translate('stats_past_games').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),

            playerGames.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 22),
                    child: Text(loc.translate('stats_no_games'), style: WhistlyText.body(colors.muted, size: 13)),
                  )
                : Column(
                    children: playerGames.map((game) {
                      final score = game.totalScores[player.id] ?? 0;

                      // Find winner(s) — highest score, ties included. Same
                      // fix as history_page.dart: a naive "keep the first
                      // max seen" scan silently drops co-winners on a tie.
                      final gameScores = game.totalScores.values;
                      final maxScore = gameScores.isEmpty ? 0 : gameScores.reduce((a, b) => a > b ? a : b);
                      final tiedWinners = game.players
                          .where((p) => (game.totalScores[p.id] ?? 0) == maxScore)
                          .map((p) => p.name)
                          .join(' & ');
                      final winnerName = tiedWinners.isEmpty ? 'Unknown' : tiedWinners;

                      return InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => GameHistoryDetailPage(game: game)));
                        },
                        child: Container(
                          color: colors.bg,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 1))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.translate('history_winner').replaceFirst('{}', winnerName).split('(').first.trim(),
                                      style: WhistlyText.rowTitle(colors.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(formatTitleDate(game.dateStarted), style: WhistlyText.mono(colors.muted)),
                                  ],
                                ),
                              ),
                              Text(
                                score >= 0 ? '+$score' : '$score',
                                style: WhistlyText.screenNumeral(score >= 0 ? colors.ink : colors.accent, size: 22),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

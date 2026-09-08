import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/localization_provider.dart';

import 'package:intl/intl.dart';
import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/theme/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('stats_title').replaceFirst('{}', latestPlayer.name)),
        actions: [
          IconButton(
            icon: Icon(
              latestPlayer.isFavorite ? Icons.star : Icons.star_border,
              color: latestPlayer.isFavorite ? AppColors.favoriteGold : colors.textSecondary,
            ),
            onPressed: () {
              context.read<PlayerProvider>().toggleFavorite(latestPlayer);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.selectedBg.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.selectedBg,
                    child: Text(
                      latestPlayer.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    latestPlayer.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(latestPlayer.isFavorite ? Icons.star : Icons.person, size: 14, color: colors.textFaint),
                      const SizedBox(width: 4),
                      Text(
                        latestPlayer.isFavorite ? loc.translate('players_favorite') : 'Player',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _statCard(context, loc, loc.translate('stats_games'), '${playerGames.length}', Icons.sports_esports),
                _statCard(context, loc, loc.translate('stats_wins'), '$wins', Icons.emoji_events),
                _statCard(context, loc, loc.translate('stats_win_rate'), '${winRate.toStringAsFixed(1)}%', Icons.pie_chart),
                _statCard(context, loc, loc.translate('stats_best_game'), '${bestScore ?? 0}', Icons.trending_up),
                _statCard(context, loc, loc.translate('stats_avg_points'), playerGames.isEmpty ? '0.0' : (totalPoints / playerGames.length).toStringAsFixed(1), Icons.bar_chart),
              ],
            ),
            const SizedBox(height: 32),
            
            // Past Games Section
            Text(
              loc.translate('stats_past_games'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            playerGames.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        loc.translate('stats_no_games'),
                        style: TextStyle(color: colors.textFaint),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: playerGames.length,
                    itemBuilder: (context, index) {
                      final game = playerGames[index];
                      final score = game.totalScores[player.id] ?? 0;
                      
                      // Find winner(s) — highest score, ties included. Same
                      // fix as history_page.dart: a naive "keep the first
                      // max seen" scan silently drops co-winners on a tie.
                      final gameScores = game.totalScores.values;
                      final maxScore = gameScores.isEmpty
                          ? 0
                          : gameScores.reduce((a, b) => a > b ? a : b);
                      final tiedWinners = game.players
                          .where((p) => (game.totalScores[p.id] ?? 0) == maxScore)
                          .map((p) => p.name)
                          .join(' & ');
                      final winnerName = tiedWinners.isEmpty ? 'Unknown' : tiedWinners;

                      return Card(
                        color: colors.surface,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameHistoryDetailPage(game: game),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            formatTitleDate(game.dateStarted),
                            style: TextStyle(fontSize: 13, color: colors.textMuted),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${loc.translate('history_winner').replaceFirst('{}', winnerName).split('(').first.trim()} ($maxScore)',
                                style: TextStyle(color: colors.textSecondary, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                loc.translate('history_rounds_played').replaceFirst('{}', game.rounds.length.toString()),
                                style: TextStyle(fontSize: 11, color: colors.textFaint),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: score >= 0 ? colors.success.withValues(alpha: 0.1) : colors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: score >= 0 ? colors.success.withValues(alpha: 0.3) : colors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              score >= 0 ? '+$score' : '$score',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: score >= 0 ? colors.success : colors.error,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, LocalizationProvider loc, String label, String value, IconData icon) {
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colors.error),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

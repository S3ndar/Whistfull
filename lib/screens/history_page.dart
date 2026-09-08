import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';

import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/ads/banner_ad_widget.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Reverse the list to show most recent completed games first
    final games = context.watch<GameProvider>().completedGames.reversed.toList();
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    String formatTitleDate(DateTime date) {
      final locale = loc.currentLanguage == AppLanguage.nl ? 'nl_BE' : 'en_US';
      try {
        return DateFormat('MMM d, yyyy • HH:mm', locale).format(date);
      } catch (e) {
        // Fallback if locale data is missing
        return DateFormat('MMM d, yyyy • HH:mm').format(date);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('history_title')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: games.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: colors.border),
                          const SizedBox(height: 16),
                          Text(
                            loc.translate('history_empty'),
                            style: TextStyle(color: colors.textFaint, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                final game = games[index];
                
                // Find winner(s) — highest score, ties included. Mirrors
                // active_game_page.dart's _showWinCelebration: that already
                // computes every tied top-scorer, but this used to keep
                // only the first player seen at the max, silently dropping
                // co-winners on a tie.
                final scores = game.players.map((p) => game.totalScores[p.id] ?? 0);
                final maxScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
                final winners = game.players.where((p) => (game.totalScores[p.id] ?? 0) == maxScore);
                final winnerName = winners.isEmpty
                    ? 'Unknown'
                    : winners.map((p) => p.name).join(' & ');

                // Ended via abandonGame() rather than a real finish through
                // endGame() — see GameProvider.completedGames.
                final isAbandoned = game.dateEnded != null && !game.isComplete;

                return Card(
                  color: colors.surface,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.borderFaint),
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameHistoryDetailPage(game: game),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: colors.borderFaint,
                      child: const Icon(Icons.style, color: AppColors.suitRed, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(
                          formatTitleDate(game.dateStarted),
                          style: TextStyle(fontSize: 14, color: colors.textSecondary),
                        ),
                        if (isAbandoned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              loc.translate('history_abandoned').toUpperCase(),
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          loc.translate('history_winner')
                              .replaceFirst('{}', winnerName)
                              .replaceFirst('{}', maxScore.toString()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          loc.translate('history_rounds_played').replaceFirst('{}', game.rounds.length.toString()),
                          style: TextStyle(fontSize: 12, color: colors.textFaint),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.chevron_right, color: colors.textFaint),
                  ),
                        );
                      },
                    ),
            ),
            // Reserves its own height and collapses entirely once ads are
            // removed — this page has no floating action button, so
            // there is no accidental-tap risk here.
            const AdaptiveBannerAd(),
          ],
        ),
      ),
    );
  }
}

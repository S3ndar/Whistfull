import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';

import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
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
                          Icon(Icons.history, size: 64, color: colors.line),
                          const SizedBox(height: 16),
                          Text(loc.translate('history_empty'), style: WhistlyText.body(colors.muted, size: 15)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: games.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: colors.line),
                      itemBuilder: (context, index) {
                        final game = games[index];

                        // Find winner(s) — highest score, ties included.
                        // Mirrors active_game_page.dart's
                        // _showWinCelebration.
                        final scores = game.players.map((p) => game.totalScores[p.id] ?? 0);
                        final maxScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
                        final winners = game.players.where((p) => (game.totalScores[p.id] ?? 0) == maxScore);
                        final winnerName = winners.isEmpty ? 'Unknown' : winners.map((p) => p.name).join(' & ');

                        // Ended via abandonGame() rather than a real finish
                        // through endGame() — see GameProvider.completedGames.
                        final isAbandoned = game.dateEnded != null && !game.isComplete;

                        return InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => GameHistoryDetailPage(game: game)));
                          },
                          child: Container(
                            color: colors.bg,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              loc.translate('history_winner').replaceFirst('{}', winnerName).split('(').first.trim(),
                                              style: WhistlyText.rowTitle(colors.ink),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isAbandoned)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(border: Border.all(color: colors.ink, width: 2)),
                                              child: Text(
                                                loc.translate('history_abandoned').toUpperCase(),
                                                style: WhistlyText.badge(colors.ink),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(formatTitleDate(game.dateStarted), style: WhistlyText.mono(colors.muted)),
                                      Text(
                                        loc.translate('history_rounds_played').replaceFirst('{}', game.rounds.length.toString()),
                                        style: WhistlyText.body(colors.muted, size: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  maxScore >= 0 ? '+$maxScore' : '$maxScore',
                                  style: WhistlyText.screenNumeral(maxScore >= 0 ? colors.ink : colors.accent, size: 24),
                                ),
                              ],
                            ),
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

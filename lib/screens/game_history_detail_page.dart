import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/widgets/round_setup_dialog.dart'; // For getContractName
import 'package:whistly/theme/app_theme.dart';

class GameHistoryDetailPage extends StatelessWidget {
  final Game game;

  const GameHistoryDetailPage({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final players = game.players;
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    String formatDate(DateTime date) {
      final locale = loc.currentLanguage == AppLanguage.nl ? 'nl_BE' : 'en_US';
      try {
        return DateFormat('EEEE, MMM d, yyyy • HH:mm', locale).format(date);
      } catch (e) {
        return DateFormat('EEEE, MMM d, yyyy • HH:mm').format(date);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('game_recap'))),
      body: Column(
        children: [
          // Game Date Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: colors.scrim,
            child: Text(
              formatDate(game.dateStarted),
              style: TextStyle(fontSize: 12, color: colors.textFaint),
              textAlign: TextAlign.center,
            ),
          ),
          // Final Scoreboard Header
          Container(
            color: colors.surface,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: AppColors.favoriteGold,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.translate('final_scores'),
                      style: const TextStyle(
                        color: AppColors.favoriteGold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: (() {
                    final maxScore = game.totalScores.isNotEmpty
                        ? game.totalScores.values.reduce((a, b) => a > b ? a : b)
                        : 0;
                    return players.map((player) {
                      final score = game.totalScores[player.id] ?? 0;
                      final isWinner = score == maxScore;

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isWinner
                              ? AppColors.selectedBg.withValues(alpha: 0.2)
                              : colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWinner
                                ? AppColors.selectedBg
                                : colors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              player.name.split(' ').first,
                              style: TextStyle(
                                fontSize: 13,
                                color: isWinner
                                    ? colors.error
                                    : colors.textSecondary,
                                fontWeight: isWinner
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              score >= 0 ? '+$score' : '$score',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: score >= 0
                                    ? colors.success
                                    : colors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList();
                })(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),

          // Round Recap List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: game.rounds.length,
              itemBuilder: (context, index) {
                final round = game.rounds[index];
                final roundNumber = index + 1;
                return _HistoricalRoundCard(
                  round: round,
                  roundNumber: roundNumber,
                  players: players,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalRoundCard extends StatelessWidget {
  final Round round;
  final int roundNumber;
  final List<Player> players;

  const _HistoricalRoundCard({
    required this.round,
    required this.roundNumber,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);
    final declarer = players.firstWhere(
      (p) => p.id == round.declarerId,
      orElse: () => players.first,
    );
    final partner = round.partnerId != null
        ? players.firstWhere(
            (p) => p.id == round.partnerId,
            orElse: () => players.first,
          )
        : null;

    final isMiserie = round.contractType == 'Miserie' || round.contractType == 'Open Miserie';
    final declarerWon = (round.scoreDeltas[round.declarerId] ?? 0) > 0;
    final partnerWon = partner != null && (round.scoreDeltas[round.partnerId] ?? 0) > 0;

    final trumpIcon = round.trump == 'Hearts' ? '♥' 
                   : round.trump == 'Diamonds' ? '♦'
                   : round.trump == 'Clubs' ? '♣'
                   : round.trump == 'Spades' ? '♠' : '';
    
    final trumpColor = (round.trump == 'Hearts' || round.trump == 'Diamonds') ? AppColors.suitRed
                    : (round.trump == 'Clubs' || round.trump == 'Spades') ? AppColors.suitBlack
                    : colors.textSecondary;

    return Card(
      color: colors.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.selectedBg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.selectedBg.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    loc
                        .translate('active_game_round_n')
                        .replaceFirst('{}', roundNumber.toString()),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  getContractName(loc, round.contractType),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (trumpIcon.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(trumpIcon, style: TextStyle(fontSize: 18, color: trumpColor)),
                ],
                const Spacer(),
                if (isMiserie && partner != null) ...[
                  Icon(
                    declarerWon ? Icons.check : Icons.close,
                    color: declarerWon ? colors.success : colors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${declarer.name.split(" ").first}: ${loc.translate(declarerWon ? 'won' : 'lost')}',
                    style: TextStyle(
                      color: declarerWon ? colors.success : colors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    partnerWon ? Icons.check : Icons.close,
                    color: partnerWon ? colors.success : colors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${partner.name.split(" ").first}: ${loc.translate(partnerWon ? 'won' : 'lost')}',
                    style: TextStyle(
                      color: partnerWon ? colors.success : colors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Icon(
                    round.success ? Icons.check : Icons.close,
                    color: round.success
                        ? colors.success
                        : colors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    loc.translate(round.success ? 'won' : 'lost'),
                    style: TextStyle(
                      color: round.success
                          ? colors.success
                          : colors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${declarer.name}${partner != null ? " + ${partner.name}" : ""}',
                style: TextStyle(fontSize: 12, color: colors.textFaint),
              ),
            ),
            Divider(height: 16, color: colors.border),
            Row(
              children: players.map((p) {
                final delta = round.scoreDeltas[p.id] ?? 0;
                return Expanded(
                  child: Text(
                    delta >= 0 ? '+$delta' : '$delta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: delta > 0
                          ? colors.success
                          : delta < 0
                          ? colors.error
                          : colors.textFaint,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

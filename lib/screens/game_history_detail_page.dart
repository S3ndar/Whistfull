import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/widgets/round_setup_dialog.dart'; // For getContractName
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/stats/stats_panel.dart';
import 'package:whistly/stats/crown_badge.dart';

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

    final ranked = [...players]..sort((a, b) => (game.totalScores[b.id] ?? 0).compareTo(game.totalScores[a.id] ?? 0));
    final topScore = ranked.isEmpty ? 0 : (game.totalScores[ranked.first.id] ?? 0);
    final soleLeaderId = ranked.where((p) => (game.totalScores[p.id] ?? 0) == topScore).length == 1 ? ranked.first.id : null;

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('game_recap'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
            child: Text(formatDate(game.dateStarted), style: WhistlyText.mono(colors.muted), textAlign: TextAlign.center),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
            child: Text(
              loc.translate('final_scores').toUpperCase(),
              textAlign: TextAlign.center,
              style: WhistlyText.eyebrow(colors.muted),
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
            child: Column(
              children: List.generate(ranked.length, (i) {
                final player = ranked[i];
                final score = game.totalScores[player.id] ?? 0;
                return Container(
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: colors.line, width: 1))),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  child: Row(
                    children: [
                      SizedBox(width: 16, child: Text('${i + 1}', style: WhistlyText.mono(colors.muted, size: 12))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(player.name, style: WhistlyText.rowTitle(colors.ink), overflow: TextOverflow.ellipsis),
                            ),
                            SoloSlimCrown(playerId: player.id),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (player.id == soleLeaderId) ...[
                        WhistlyLeadBadge(label: loc.translate('lead')),
                        const SizedBox(width: 8),
                      ],
                      ConstrainedBox(
                        // See the matching column in active_game_page.dart's
                        // _StandingsList: 56px is a minimum, not a cap — a
                        // fixed `width: 56` let a 3-digit total wrap onto
                        // two lines instead of staying on one.
                        constraints: const BoxConstraints(minWidth: 56),
                        child: Text(
                          score >= 0 ? '+$score' : '$score',
                          textAlign: TextAlign.right,
                          softWrap: false,
                          style: WhistlyText.screenNumeral(score >= 0 ? colors.ink : colors.accent),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          // ALTERATIONS.md (round 2) C5, placement 2; covers the round
          // list below whenever a chart is selected instead of "Rounds".
          StatsPanel(
            scope: [game],
            roundsView: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: game.rounds.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: colors.line),
              itemBuilder: (context, index) {
                final round = game.rounds[index];
                return _HistoricalRoundRow(round: round, roundNumber: index + 1, players: players);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalRoundRow extends StatelessWidget {
  final Round round;
  final int roundNumber;
  final List<GamePlayerRef> players;

  const _HistoricalRoundRow({required this.round, required this.roundNumber, required this.players});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    if (round.contractType == 'Pass') {
      final dealer = players.firstWhere((p) => p.id == round.dealerId, orElse: () => players.first);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 12))),
            const SizedBox(width: 12),
            Expanded(child: Text(loc.translate('bid_pass'), style: WhistlyText.rowTitle(colors.muted))),
            Text('${loc.translate('dealer')}: ${dealer.name}', style: WhistlyText.mono(colors.muted)),
          ],
        ),
      );
    }

    final declarer = players.firstWhere((p) => p.id == round.declarerId, orElse: () => players.first);
    final partner = round.partnerId != null
        ? players.firstWhere((p) => p.id == round.partnerId, orElse: () => players.first)
        : null;

    final isMiserie = round.contractType == 'Miserie' || round.contractType == 'Open Miserie';
    final overallSuccess = isMiserie && partner != null
        ? (round.scoreDeltas[round.declarerId] ?? 0) > 0 && (round.scoreDeltas[round.partnerId] ?? 0) > 0
        : round.success;

    final trumpGlyph = round.trump == 'Hearts'
        ? '♥'
        : round.trump == 'Diamonds'
            ? '♦'
            : round.trump == 'Clubs'
                ? '♣'
                : round.trump == 'Spades'
                    ? '♠'
                    : '';
    final trumpColor = (round.trump == 'Hearts' || round.trump == 'Diamonds')
        ? colors.suitRed
        : (round.trump == 'Clubs' || round.trump == 'Spades')
            ? colors.suitInk
            : colors.muted;

    final partnerLine = partner != null ? '${declarer.name} & ${partner.name}' : declarer.name;
    final deltasLine = players.map((p) {
      final d = round.scoreDeltas[p.id] ?? 0;
      return '${p.name.split(' ').first} ${d >= 0 ? '+$d' : '$d'}';
    }).join('  ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 12))),
          const SizedBox(width: 12),
          SizedBox(
            width: 24,
            child: trumpGlyph.isEmpty ? null : Text(trumpGlyph, style: TextStyle(fontSize: 24, color: trumpColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(getContractName(loc, round.contractType), style: WhistlyText.rowTitle(colors.ink)),
                const SizedBox(height: 2),
                Text('$partnerLine · $deltasLine', style: WhistlyText.mono(colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WhistlyResultBadge(
            achieved: overallSuccess,
            achievedLabel: loc.translate('setup_succeeded'),
            failedLabel: loc.translate('setup_failed'),
          ),
        ],
      ),
    );
  }
}

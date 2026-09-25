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
import 'package:whistly/widgets/player_columns.dart';

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
          // ALTERATIONS.md (round 2) E4 — through the same PlayerColumns
          // as the round list below, but in RANKED order: a finished
          // game legitimately ranks by score (unlike the live view's
          // fixed seating order), and this block's own column order
          // doesn't need to match the round list's — they're two
          // separate tables, not one continuous grid.
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: PlayerColumns(
                cells: ranked.map((player) {
                  final score = game.totalScores[player.id] ?? 0;
                  return _HistoryHeaderCell(
                    player: player,
                    score: score,
                    isLeader: player.id == soleLeaderId,
                    loc: loc,
                    colors: colors,
                  );
                }).toList(),
              ),
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
                // E4 — the round list's columns follow game.players
                // (seating order), not `ranked`, so each delta stays
                // under the name it belongs to round by round.
                return _HistoricalRoundRow(round: round, roundNumber: index + 1, players: players);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// E4's `PlayerColumns` cell for the final-scores block — no Dealer
/// badge (a finished game has no current dealer), otherwise the same
/// content and sizing as active_game_page.dart's `_HeaderCell`.
class _HistoryHeaderCell extends StatelessWidget {
  final GamePlayerRef player;
  final int score;
  final bool isLeader;
  final LocalizationProvider loc;
  final AppSemanticColors colors;

  const _HistoryHeaderCell({
    required this.player,
    required this.score,
    required this.isLeader,
    required this.loc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  player.name.split(' ').first,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WhistlyText.rowTitle(colors.ink).copyWith(fontSize: 13),
                ),
              ),
              SoloSlimCrown(playerId: player.id),
            ],
          ),
          if (isLeader) ...[
            const SizedBox(height: 4),
            WhistlyLeadBadge(label: loc.translate('lead')),
          ],
          const SizedBox(height: 6),
          Text(
            score >= 0 ? '+$score' : '$score',
            textAlign: TextAlign.center,
            style: WhistlyText.screenNumeral(score >= 0 ? colors.ink : colors.accent, size: 22),
          ),
        ],
      ),
    );
  }
}

/// E4 — the same meta band / delta band split as
/// active_game_page.dart's `_RoundRow`, through the same
/// `PlayerColumns`, in `game.players` (seating) order.
class _HistoricalRoundRow extends StatelessWidget {
  final Round round;
  final int roundNumber;
  final List<GamePlayerRef> players;

  const _HistoricalRoundRow({required this.round, required this.roundNumber, required this.players});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    // No horizontal padding here — StatsPanel already insets its whole
    // roundsView (this row's only caller) by 22px; see the matching
    // comment on active_game_page.dart's _RoundRow.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          child: _buildMetaBand(loc, colors),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PlayerColumns(cells: _deltaCells(colors)),
        ),
      ],
    );
  }

  Widget _buildMetaBand(LocalizationProvider loc, AppSemanticColors colors) {
    if (round.contractType == 'Pass') {
      final dealer = players.firstWhere((p) => p.id == round.dealerId, orElse: () => players.first);
      return Row(
        children: [
          SizedBox(width: 20, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 11))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${loc.translate('bid_pass')} · ${loc.translate('dealer')}: ${dealer.name}',
              style: WhistlyText.mono(colors.muted, size: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

    final contractingLine = partner != null ? '${declarer.name} & ${partner.name}' : declarer.name;

    return Row(
      children: [
        SizedBox(width: 20, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 11))),
        const SizedBox(width: 8),
        SizedBox(
          width: 18,
          child: trumpGlyph.isEmpty ? null : Text(trumpGlyph, style: TextStyle(fontSize: 14, color: trumpColor)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            getContractName(loc, round.contractType),
            style: WhistlyText.rowTitle(colors.ink).copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(contractingLine, style: WhistlyText.mono(colors.muted, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        WhistlyResultBadge(
          achieved: overallSuccess,
          achievedLabel: loc.translate('setup_succeeded'),
          failedLabel: loc.translate('setup_failed'),
        ),
      ],
    );
  }

  List<Widget> _deltaCells(AppSemanticColors colors) {
    return players.map((p) {
      final delta = round.scoreDeltas[p.id] ?? 0;
      final text = delta == 0 ? '·' : (delta > 0 ? '+$delta' : '$delta');
      final color = delta == 0 ? colors.muted : (delta > 0 ? colors.ink : colors.accent);
      return Text(
        text,
        textAlign: TextAlign.center,
        style: WhistlyText.mono(color, size: 13, weight: FontWeight.w800),
      );
    }).toList();
  }
}

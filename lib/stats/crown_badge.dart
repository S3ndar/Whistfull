import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/game_history_detail_page.dart';
import 'package:whistly/stats/achievements.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

/// ALTERATIONS.md (round 2) D3 — wires `WhistlyCrownBadge` (the pure
/// glyph, in whistly_components.dart) to `GameProvider.soloSlimsByPlayer`
/// and the tap popover. Renders nothing for a player with no slim.
///
/// Meant to sit as a suffix directly after the player's name (inside the
/// same `Row`/`Flexible` as their name `Text`, not as a separate badge
/// grouped with Dealer/Lead over by the score) — a leading gap separates
/// it from the name; there's deliberately no trailing gap, since nothing
/// else is meant to follow it in that slot. Used wherever a player's
/// name is listed: active_game_page.dart's standings,
/// game_history_detail_page.dart's final scores, players_page.dart's
/// roster, player_stats_page.dart's header.
class SoloSlimCrown extends StatelessWidget {
  final String playerId;
  const SoloSlimCrown({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final slims = gameProvider.soloSlimsByPlayer[playerId];
    if (slims == null || slims.isEmpty) return const SizedBox.shrink();
    final loc = context.watch<LocalizationProvider>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        WhistlyCrownBadge(
          countLabel: slims.length > 1 ? loc.translate('crown_times').replaceFirst('{}', '${slims.length}') : null,
          onTap: () => _showPopover(context, loc, slims, gameProvider),
        ),
      ],
    );
  }

  void _showPopover(
    BuildContext context,
    LocalizationProvider loc,
    List<SoloSlim> slims,
    GameProvider gameProvider,
  ) {
    // Tap, not long-press — Material's Tooltip is long-press-on-touch,
    // rounded and elevated, the wrong interaction and the wrong chrome.
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colors = AppTheme.of(dialogContext);
        String formatDate(DateTime date) {
          final locale = loc.currentLanguage == AppLanguage.nl ? 'nl_BE' : 'en_US';
          try {
            return DateFormat('MMM d, yyyy', locale).format(date);
          } catch (e) {
            return DateFormat('MMM d, yyyy').format(date);
          }
        }

        return Dialog(
          backgroundColor: colors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: colors.line, width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.translate('crown_solo_slim').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
                const SizedBox(height: 8),
                Text(loc.translate('crown_solo_slim_desc'), style: WhistlyText.body(colors.ink, size: 13)),
                const SizedBox(height: 16),
                Container(height: 1, color: colors.line),
                const SizedBox(height: 4),
                for (final slim in slims)
                  _SlimRow(
                    slim: slim,
                    dateLabel: formatDate(slim.date),
                    isActiveGame: slim.gameId == gameProvider.activeGame?.id,
                    loc: loc,
                    colors: colors,
                    onTap: (game) {
                      Navigator.pop(dialogContext);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => GameHistoryDetailPage(game: game)));
                    },
                    resolveGame: () => gameProvider.completedGames.where((g) => g.id == slim.gameId).firstOrNull,
                  ),
                const SizedBox(height: 12),
                Center(
                  child: WhistlyTextAction(
                    label: loc.translate('close'),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlimRow extends StatelessWidget {
  final SoloSlim slim;
  final String dateLabel;
  final bool isActiveGame;
  final LocalizationProvider loc;
  final AppSemanticColors colors;
  final void Function(Game game) onTap;
  final Game? Function() resolveGame;

  const _SlimRow({
    required this.slim,
    required this.dateLabel,
    required this.isActiveGame,
    required this.loc,
    required this.colors,
    required this.onTap,
    required this.resolveGame,
  });

  @override
  Widget build(BuildContext context) {
    final roundLabel = loc.translate('crown_round').replaceFirst('{}', '${slim.roundNumber}');
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(dateLabel, style: WhistlyText.mono(colors.muted, size: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isActiveGame ? loc.translate('crown_in_progress') : roundLabel,
              style: WhistlyText.body(colors.ink, size: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );

    if (isActiveGame) return content;
    return InkWell(
      onTap: () {
        final game = resolveGame();
        if (game != null) onTap(game);
      },
      child: content,
    );
  }
}

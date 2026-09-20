import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

/// Minimal shape `PlayerGridPicker` needs from either a live `Player`
/// (Home, idle state), a game's `GamePlayerRef` roster (Home, active game;
/// round setup's declarer/partner steps), or any other 4-seat source.
/// `gamesPlayed` is only meaningful when `showRecord` is true and no
/// `activeGame` is supplied.
class PlayerGridEntry {
  final String id;
  final String name;
  final int gamesPlayed;
  const PlayerGridEntry({required this.id, required this.name, this.gamesPlayed = 0});
}

/// ALTERATIONS.md B3 — the 2x2 player grid, shared between Home's
/// display-only "At the table" grid and `RoundSetupDialog`'s declarer/
/// partner picker, so the two never drift into two different visual
/// languages for "here are the four seated players."
///
/// `bg` cells on a `line`-coloured grid, 2px gutters, fixed cell height,
/// name 17px/800 (spec §5/§7) — always in the caller's given order (seating
/// order), never re-sorted, matching the standings row's B2 stability rule.
///
/// Two modes, picked by whether [onSelect] is given:
/// - Display-only (Home): no tap handling, `showRecord` shows each
///   player's game total (active game) or games-played count (idle).
/// - Picker (round setup): [onSelect] makes cells tappable. [selectedId]
///   fills a cell `accent`/`onAccent`; [disabledId] (e.g. the declarer,
///   while picking their partner) mutes the cell to `muted` text on `bg`
///   and makes it untappable. `showRecord` is false here — a picker cell
///   shows only the name.
class PlayerGridPicker extends StatelessWidget {
  final List<PlayerGridEntry> players;
  final Game? activeGame;
  final String? selectedId;
  final String? disabledId;
  final ValueChanged<PlayerGridEntry>? onSelect;
  final bool showRecord;

  const PlayerGridPicker({
    super.key,
    required this.players,
    this.activeGame,
    this.selectedId,
    this.disabledId,
    this.onSelect,
    this.showRecord = true,
  });

  /// Fixed row height. Clears the 44px minimum tap target from spec §7 and
  /// fits a 17px name over an 11px mono record.
  static const double _cellHeight = 76;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final loc = context.watch<LocalizationProvider>();
    final cells = List.generate(4, (i) => i < players.length ? players[i] : null);

    // A fixed cell height, not an aspect ratio — see `_HomePlayTab`'s
    // original comment: `childAspectRatio` tied cell height to window
    // width, which on a wide viewport grew the grid tall enough to push
    // the primary button off the bottom of the screen.
    Widget cell(PlayerGridEntry? p) {
      if (p == null) {
        return Expanded(
          child: Container(color: colors.bg, height: _cellHeight),
        );
      }

      final isSelected = selectedId == p.id;
      final isDisabled = disabledId == p.id;
      final cellBg = isSelected ? colors.accent : colors.bg;
      final nameColor = isSelected ? colors.onAccent : (isDisabled ? colors.muted : colors.ink);

      final recordLabel = showRecord
          ? (activeGame != null
              ? (() {
                  final record = activeGame!.totalScores[p.id] ?? 0;
                  return record >= 0 ? '+$record' : '$record';
                })()
              : '${p.gamesPlayed} ${loc.translate('stats_games').toUpperCase()}')
          : null;

      final content = Container(
        color: cellBg,
        height: _cellHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: WhistlyText.rowTitle(nameColor),
              overflow: TextOverflow.ellipsis,
            ),
            if (recordLabel != null) ...[
              const SizedBox(height: 2),
              Text(recordLabel, style: WhistlyText.mono(isSelected ? colors.onAccent : colors.muted)),
            ],
          ],
        ),
      );

      return Expanded(
        child: onSelect == null || isDisabled
            ? content
            : InkWell(onTap: () => onSelect!(p), child: content),
      );
    }

    return Container(
      color: colors.line,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [cell(cells[0]), const SizedBox(width: 2), cell(cells[1])]),
          const SizedBox(height: 2),
          Row(children: [cell(cells[2]), const SizedBox(width: 2), cell(cells[3])]),
        ],
      ),
    );
  }
}

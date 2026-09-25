import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';

/// ALTERATIONS.md (round 2) E1 — N equal columns separated by 1px `line`
/// rules, inside the 22px screen gutter. The header strip and every
/// round row render through this, which is what keeps a delta under
/// its player's name. Nothing else may lay out player-indexed cells.
///
/// No leading gutter inside `PlayerColumns` — a `SizedBox` in front of
/// the delta band but not the header band is the one mistake that
/// silently breaks alignment (see test/scoresheet_test.dart 4).
///
/// The divider between columns is a left border on the `Container`
/// wrapping each cell (skipped on the first), not a literal
/// `VerticalDivider`. A `VerticalDivider` needs an `IntrinsicHeight`
/// ancestor to have a height to fill, and `IntrinsicHeight` measures
/// each child by laying it out with an effectively unbounded height —
/// a cell built from a `Row`/`Flexible` (as the header cell's
/// name-plus-crown line is) can blow up under that measurement pass
/// with a five-figure overflow, even though the exact same cell
/// renders fine under this Row's real, bounded constraints. A border
/// draws the same 1px rule without needing either widget.
///
/// No `crossAxisAlignment: CrossAxisAlignment.stretch` here — this Row
/// is a non-flex child of a `Column` (in both call sites) and so is
/// itself given unbounded height; `stretch` on a `Row` with unbounded
/// height forces `BoxConstraints` with an infinite height onto every
/// cell, crashing layout. This is the exact trap CLAUDE.md documents
/// for `active_game_page.dart`'s old action row — default (`center`)
/// alignment is what every other Row in this codebase already uses.
class PlayerColumns extends StatelessWidget {
  final List<Widget> cells; // exactly game.players.length, in that order
  const PlayerColumns({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Row(
      children: List.generate(cells.length, (i) {
        return Expanded(
          child: Container(
            decoration: i == 0 ? null : BoxDecoration(border: Border(left: BorderSide(color: colors.line, width: 1))),
            child: cells[i],
          ),
        );
      }),
    );
  }
}

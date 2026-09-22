import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

/// ALTERATIONS.md (round 2) C3 — one bar for one category. `value` is
/// 0..1 for a rate chart (C4.2-C4.4) or a raw count for the trump
/// histogram (C4.1) — the chart's `axisMax` decides which. `trailing` is
/// the row's own right-aligned mono text (e.g. `'62%  n=13'` or `'7'`),
/// computed by the caller so this file never has to know the difference
/// between a rate and a count.
class BarDatum {
  final String label;
  final double value;
  final String trailing;
  final bool dimmed; // true when n < 3 — see BarChart's doc comment
  final Color? glyphColor; // suit red/ink, trump chart only

  const BarDatum({
    required this.label,
    required this.value,
    required this.trailing,
    this.dimmed = false,
    this.glyphColor,
  });
}

/// C3 — the one bar chart every C4 chart is a thin mapping onto (C4.1-
/// C4.4 each turn a `game_stats.dart` function's output into a
/// `List<BarDatum>`; none of them paint anything of their own).
///
/// Horizontal bars, not vertical — player names and "Open Miserie" don't
/// fit under a vertical bar without rotating the label, and a rotated
/// label doesn't belong in a typeset, rule-based interface.
///
/// Anatomy: 28px row height, 6px gap, label left (`rowTitle`-weight
/// 13px), bar in the middle (a 2px `line`-bordered, unfilled track with
/// an `ink` fill to the value — the Result badge's "bordered track"
/// logic), `trailing` right-aligned in mono. The single largest bar
/// fills `accent` (one accent gesture per chart, spec §5).
///
/// Small samples are this chart's whole failure mode — a 100% bar off
/// one round is a lie. `dimmed: true` (n < 3) draws that row's bar at
/// 1px in `muted`, and its label in `muted` too — still shown, since
/// hiding data is worse, but reading as provisional. A dimmed bar is
/// never the one that gets `accent`, even if its value is numerically
/// the largest — "provisional" and "the chart's headline" don't mix.
///
/// [axisMax] is 1.0 for every rate chart (so bars are comparable between
/// players) and the trump histogram's own max count for C4.1 — pass
/// null to auto-derive it from the data (never below 1, so a
/// data-is-all-zero chart never divides by zero).
///
/// [referenceValue]/[referenceLabel] draw the C4.4-only 1px dashed
/// vertical `muted` rule at `tableAverage`; omitted by every other
/// chart.
class BarChart extends StatelessWidget {
  final List<BarDatum> data;
  final double? axisMax;
  final double? referenceValue;
  final String? referenceLabel;

  const BarChart({
    super.key,
    required this.data,
    this.axisMax,
    this.referenceValue,
    this.referenceLabel,
  });

  static const double _rowHeight = 28;
  static const double _rowGap = 6;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    if (data.isEmpty) return const SizedBox.shrink();

    final dataMax = data.map((d) => d.value).fold<double>(0, (a, b) => a > b ? a : b);
    final resolvedAxisMax = (axisMax ?? dataMax) <= 0 ? 1.0 : (axisMax ?? dataMax);

    // The largest bar gets accent — but never a dimmed one; "provisional"
    // must not also read as "the chart's headline."
    final eligibleForAccent = data.where((d) => !d.dimmed);
    final maxEligibleValue =
        eligibleForAccent.isEmpty ? null : eligibleForAccent.map((d) => d.value).reduce((a, b) => a > b ? a : b);

    Widget row(BarDatum datum) {
      final isLargest = !datum.dimmed && maxEligibleValue != null && datum.value == maxEligibleValue && datum.value > 0;
      final fillColor = datum.dimmed ? colors.muted : (isLargest ? colors.accent : colors.ink);
      final labelColor = datum.dimmed ? colors.muted : colors.ink;
      final borderWidth = datum.dimmed ? 1.0 : 2.0;
      final fraction = (datum.value / resolvedAxisMax).clamp(0.0, 1.0);

      return SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: _rowLabel(datum, labelColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Container(
                key: ValueKey('bar-track-${datum.label}'),
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: datum.dimmed ? colors.muted : colors.line, width: borderWidth),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: ValueKey('bar-fill-${datum.label}'),
                      width: constraints.maxWidth * fraction,
                      height: double.infinity,
                      color: fillColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                datum.trailing,
                textAlign: TextAlign.right,
                style: WhistlyText.mono(datum.dimmed ? colors.muted : colors.ink, size: 11),
              ),
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < data.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: _rowGap));
      rows.add(row(data[i]));
    }

    if (referenceValue != null) {
      // A 1px dashed vertical muted rule at tableAverage (C4.4 only),
      // positioned over the bar column specifically — it shares the
      // bars' own coordinate space (axisMax), not the label/trailing
      // columns either side of it.
      final refFraction = (referenceValue! / resolvedAxisMax).clamp(0.0, 1.0);
      rows.add(const SizedBox(height: _rowGap));
      rows.add(
        Row(
          children: [
            const Expanded(flex: 4, child: SizedBox.shrink()),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned(
                      left: constraints.maxWidth * refFraction,
                      child: CustomPaint(
                        size: const Size(1, 14),
                        painter: _DashedLinePainter(color: colors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 64),
          ],
        ),
      );
      if (referenceLabel != null) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(referenceLabel!, style: WhistlyText.mono(colors.muted, size: 9)),
          ),
        );
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// C4.1's trump chart prefixes each label with its own suit glyph
/// (already the label's first character), coloured via [BarDatum.glyphColor]
/// — a fixed generic dot would lose the "which suit" information the
/// glyph carries. Every other chart has no glyphColor and renders as a
/// plain `Text`.
Widget _rowLabel(BarDatum datum, Color labelColor) {
  if (datum.glyphColor == null || datum.label.isEmpty) {
    return Text(
      datum.label,
      style: WhistlyText.rowTitle(labelColor).copyWith(fontSize: 13),
      overflow: TextOverflow.ellipsis,
    );
  }
  final glyph = datum.label.substring(0, 1);
  final rest = datum.label.substring(1);
  return RichText(
    overflow: TextOverflow.ellipsis,
    text: TextSpan(
      children: [
        TextSpan(text: glyph, style: WhistlyText.rowTitle(datum.glyphColor!).copyWith(fontSize: 13)),
        TextSpan(text: rest, style: WhistlyText.rowTitle(labelColor).copyWith(fontSize: 13)),
      ],
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashLength = 3.0;
    const gapLength = 2.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + dashLength).clamp(0, size.height)), paint);
      y += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

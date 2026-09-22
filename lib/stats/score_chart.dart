import 'package:flutter/material.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

/// ALTERATIONS.md C1 — pure, testable series derivation: one cumulative
/// running-total series per player, in `game.players` (seating) order —
/// never reordered, matching B2's stability rule for the standings list.
/// Each series has length `game.rounds.length + 1` (index 0 is the
/// pre-game zero). A Rondpas round's `scoreDeltas` are all zero, so it
/// still advances every series by one index with no change in value — a
/// flat step, not a gap.
List<List<int>> cumulativeSeries(Game game) {
  final ids = game.players.map((p) => p.id).toList();
  final series = List.generate(ids.length, (_) => <int>[0]);
  for (final round in game.rounds) {
    for (var i = 0; i < ids.length; i++) {
      series[i].add(series[i].last + (round.scoreDeltas[ids[i]] ?? 0));
    }
  }
  return series;
}

// Secondary identity cue, in fixed seating order — never reassigned when
// scores change, same rule as B2's row order and the direct name labels.
const List<List<double>> _dashPatterns = [
  <double>[], // solid
  <double>[6, 4],
  <double>[2, 3],
  <double>[8, 3, 2, 3],
];

// ALTERATIONS.md (round 2) C2/C5: `ScoreProgressionSection` — the
// collapsible wrapper that used to own both the "≥3 rounds" guard and
// the "Score progression" text-action toggle — was deleted here.
// `StatsPanel` (lib/stats/stats_panel.dart) now owns the header/selector
// active_game_page.dart mounts instead, and its `stats_no_data` rule
// (driven by game_stats.dart's `contractOutcomes`, i.e. non-Pass rounds)
// is the single guard every chart in the panel shares, replacing this
// section's own round-count check.

/// The chart itself — a `CustomPainter` line chart, not a package: the
/// theme forbids radius/shadows/gradients that most chart packages assume.
class ScoreProgressionChart extends StatefulWidget {
  final Game game;

  /// Whose line is drawn in `accent`; defaults to the sole leader (no
  /// multi-way tie) when null. All other lines are `ink`.
  final String? accentPlayerId;

  const ScoreProgressionChart({super.key, required this.game, this.accentPlayerId});

  static const double height = 160;

  @override
  State<ScoreProgressionChart> createState() => _ScoreProgressionChartState();
}

class _ScoreProgressionChartState extends State<ScoreProgressionChart> {
  double? _dragDx;

  // `cumulativeSeries` is O(rounds x players) — cheap for one build, but
  // build() also reruns on every onHorizontalDragUpdate frame (just to
  // move the crosshair), and `widget.game` is the same mutable Game
  // instance across those rebuilds (GameProvider mutates it in place), so
  // identity checks on `widget.game` can't tell "a round was added" apart
  // from "the drag moved." Caching on `rounds.length` can, and is the
  // cheapest signal that's actually correct: a real round changes it, a
  // drag frame never does.
  List<List<int>>? _cachedSeries;
  int _cachedRoundCount = -1;
  String? _cachedGameId;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final game = widget.game;
    if (_cachedSeries == null || _cachedRoundCount != game.rounds.length || _cachedGameId != game.id) {
      _cachedSeries = cumulativeSeries(game);
      _cachedRoundCount = game.rounds.length;
      _cachedGameId = game.id;
    }
    final series = _cachedSeries!;
    final players = game.players;

    String? accentId = widget.accentPlayerId;
    if (accentId == null && players.isNotEmpty) {
      final finals = {for (var i = 0; i < players.length; i++) players[i].id: series[i].last};
      final top = finals.values.reduce((a, b) => a > b ? a : b);
      final leaders = finals.entries.where((e) => e.value == top);
      accentId = leaders.length == 1 ? leaders.first.key : null;
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        setState(() => _dragDx = local.dx.clamp(0.0, box.size.width));
      },
      onHorizontalDragEnd: (_) => setState(() => _dragDx = null),
      onHorizontalDragCancel: () => setState(() => _dragDx = null),
      child: SizedBox(
        height: ScoreProgressionChart.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ScoreChartPainter(
            series: series,
            players: players,
            accentPlayerId: accentId,
            colors: colors,
            dragDx: _dragDx,
          ),
        ),
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<List<int>> series;
  final List<dynamic> players; // GamePlayerRef, kept loosely typed to avoid a cyclic import
  final String? accentPlayerId;
  final AppSemanticColors colors;
  final double? dragDx;

  _ScoreChartPainter({
    required this.series,
    required this.players,
    required this.accentPlayerId,
    required this.colors,
    required this.dragDx,
  });

  static const double _labelReserve = 76; // right-edge name labels
  static const double _bottomReserve = 16; // x-axis round numbers
  static const double _leftReserve = 34; // y-axis value labels

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.isEmpty) return;
    final pointCount = series.first.length;
    final plotWidth = (size.width - _labelReserve - _leftReserve).clamp(1.0, double.infinity);
    final plotHeight = (size.height - _bottomReserve).clamp(1.0, double.infinity);
    final plotLeft = _leftReserve;

    var minV = 0;
    var maxV = 0;
    for (final s in series) {
      for (final v in s) {
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    final pad = ((maxV - minV) * 0.1).clamp(1, double.infinity);
    final rangeMin = minV - pad;
    final rangeMax = maxV + pad;
    final range = (rangeMax - rangeMin).clamp(1, double.infinity);

    double xFor(int i) => pointCount <= 1
        ? plotLeft
        : plotLeft + (plotWidth * i / (pointCount - 1));
    double yFor(int v) => plotHeight - ((v - rangeMin) / range) * plotHeight;

    // Baseline at y=0 — always drawn, 1px, since scores can go negative.
    final baselinePaint = Paint()
      ..color = colors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(plotLeft, yFor(0)), Offset(plotLeft + plotWidth, yFor(0)), baselinePaint);

    // Y-axis value labels: max, 0, min — muted, mono.
    _drawText(canvas, '$maxV', Offset(0, yFor(maxV) - 6), colors.muted);
    _drawText(canvas, '0', Offset(0, yFor(0) - 6), colors.muted);
    if (minV != 0) _drawText(canvas, '$minV', Offset(0, yFor(minV) - 6), colors.muted);

    // X-axis labels: first, last, one midpoint round index.
    final lastIdx = pointCount - 1;
    final midIdx = lastIdx ~/ 2;
    for (final i in {0, midIdx, lastIdx}) {
      _drawText(canvas, '$i', Offset(xFor(i) - 6, plotHeight + 2), colors.muted);
    }

    // One line per player, in fixed seating order — dash pattern is
    // positional (seat index), never reassigned when scores change.
    for (var pi = 0; pi < series.length; pi++) {
      final s = series[pi];
      final isAccent = accentPlayerId != null && pi < players.length && players[pi].id == accentPlayerId;
      final lineColor = isAccent ? colors.accent : colors.ink;
      final dash = _dashPatterns[pi % _dashPatterns.length];

      final path = Path()..moveTo(xFor(0), yFor(s[0]));
      for (var i = 1; i < s.length; i++) {
        path.lineTo(xFor(i), yFor(s[i]));
      }
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      if (dash.isEmpty) {
        canvas.drawPath(path, paint);
      } else {
        canvas.drawPath(_dashedPath(path, dash), paint);
      }

      // Point markers only when rounds are spaced far enough apart to
      // show them meaningfully (spec: none below 8px).
      final stepX = pointCount > 1 ? plotWidth / (pointCount - 1) : plotWidth;
      if (stepX >= 8) {
        final dotPaint = Paint()..color = lineColor;
        for (var i = 0; i < s.length; i++) {
          canvas.drawCircle(Offset(xFor(i), yFor(s[i])), 1.5, dotPaint);
        }
      }

      // Direct label at the right end — the primary identity cue.
      if (pi < players.length) {
        _drawText(
          canvas,
          players[pi].name as String,
          Offset(plotLeft + plotWidth + 4, yFor(s.last) - 6),
          lineColor,
          bold: true,
        );
      }
    }

    // Drag crosshair: vertical line + each player's value at that round,
    // in mono, at the top — replaces a hover tooltip on touch.
    if (dragDx != null) {
      final nearestIdx = pointCount <= 1
          ? 0
          : (((dragDx! - plotLeft) / plotWidth) * (pointCount - 1)).round().clamp(0, lastIdx);
      final crossX = xFor(nearestIdx);
      final crossPaint = Paint()
        ..color = colors.ink
        ..strokeWidth = 1;
      canvas.drawLine(Offset(crossX, 0), Offset(crossX, plotHeight), crossPaint);

      var labelY = 0.0;
      for (var pi = 0; pi < series.length; pi++) {
        if (nearestIdx >= series[pi].length) continue;
        final isAccent = accentPlayerId != null && pi < players.length && players[pi].id == accentPlayerId;
        final v = series[pi][nearestIdx];
        _drawMonoText(canvas, v >= 0 ? '+$v' : '$v', Offset(crossX + 4, labelY), isAccent ? colors.accent : colors.ink);
        labelY += 12;
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, {bool bold = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: WhistlyText.badge(color).copyWith(fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawMonoText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: WhistlyText.mono(color)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  Path _dashedPath(Path source, List<double> pattern) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var patternIndex = 0;
      var draw = true;
      while (distance < metric.length) {
        final len = pattern[patternIndex % pattern.length];
        final next = (distance + len).clamp(0.0, metric.length);
        if (draw) {
          dest.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        draw = !draw;
        patternIndex++;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.accentPlayerId != accentPlayerId ||
        oldDelegate.dragDx != dragDx;
  }
}

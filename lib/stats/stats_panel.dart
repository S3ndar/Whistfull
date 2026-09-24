import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/stats/bar_chart.dart';
import 'package:whistly/stats/chart_builders.dart';
import 'package:whistly/stats/game_stats.dart';
import 'package:whistly/stats/score_chart.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';

enum _ChartKind { rounds, progression, trumps, contractSuccess, accuracy, risk }

String _chartLabel(_ChartKind kind, LocalizationProvider loc) {
  switch (kind) {
    case _ChartKind.rounds:
      return loc.translate('stats_chart_rounds');
    case _ChartKind.progression:
      return loc.translate('stats_chart_progression');
    case _ChartKind.trumps:
      return loc.translate('stats_chart_trumps');
    case _ChartKind.contractSuccess:
      return loc.translate('stats_chart_contract_success');
    case _ChartKind.accuracy:
      return loc.translate('stats_chart_accuracy');
    case _ChartKind.risk:
      return loc.translate('stats_chart_risk');
  }
}

/// One widget, three placements (Home's active game, a game's history
/// detail, and the history tab), a "View" selector switching between
/// charts and — where [roundsView] is given — the underlying round list.
/// [scope] is the games this instance reads — `[activeGame]`, `[game]`,
/// or every `completedGames` depending on where it's mounted; this
/// widget never reaches into a provider itself.
///
/// [roundsView] is the round list to show when "Rounds" is selected —
/// selecting any chart instead COVERS it, occupying the same space, and
/// selecting "Rounds" again brings it back. Passed by
/// active_game_page.dart and game_history_detail_page.dart, both of
/// which show a round list next to their panel; omitted by
/// history_page.dart, which shows a game list with its own separate
/// collapse toggle and has no "Rounds" concept. When given, this widget
/// takes the flexible remaining height of its parent `Column` (it must
/// be a direct child of one, same as any `Expanded`) so the round list
/// can scroll; when omitted, it sizes to its own content exactly as
/// before.
///
/// [allowProgression] is false for multi-game scopes — a cumulative
/// score line across unrelated games is meaningless — which also removes
/// it from the selector.
class StatsPanel extends StatefulWidget {
  final List<Game> scope;
  final bool allowProgression;
  final Widget? roundsView;
  const StatsPanel({super.key, required this.scope, this.allowProgression = true, this.roundsView});

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  // Selection lives here only — a view toggle, not user data, so it is
  // deliberately never persisted to Hive (C5's own instruction).
  late _ChartKind _selected;

  List<_ChartKind> get _available => [
        if (widget.roundsView != null) _ChartKind.rounds,
        if (widget.allowProgression) _ChartKind.progression,
        _ChartKind.trumps,
        _ChartKind.contractSuccess,
        _ChartKind.accuracy,
        _ChartKind.risk,
      ];

  _ChartKind get _defaultSelection => widget.roundsView != null
      ? _ChartKind.rounds
      : (widget.allowProgression ? _ChartKind.progression : _ChartKind.accuracy);

  @override
  void initState() {
    super.initState();
    _selected = _defaultSelection;
  }

  @override
  void didUpdateWidget(StatsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // allowProgression/roundsView are fixed per placement in practice,
    // but guard against the selection becoming stale/invalid if either
    // ever changes.
    if (!_available.contains(_selected)) {
      _selected = _defaultSelection;
    }
  }

  Future<void> _openSelector(LocalizationProvider loc, AppSemanticColors colors) async {
    final chosen = await showModalBottomSheet<_ChartKind>(
      context: context,
      backgroundColor: colors.bg,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in _available)
                InkWell(
                  onTap: () => Navigator.pop(sheetContext, kind),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: kind == _selected ? colors.accent : colors.bg,
                      border: Border(bottom: BorderSide(color: colors.line, width: 1)),
                    ),
                    child: Text(
                      _chartLabel(kind, loc),
                      style: WhistlyText.rowTitle(kind == _selected ? colors.onAccent : colors.ink),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) setState(() => _selected = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final loc = context.watch<LocalizationProvider>();

    // C2's old ">= 3 rounds" guard, unified here as C3's stats_no_data
    // rule: "eligible" means non-Pass rounds (C1.1) across the whole
    // scope. Only gates the CHART options — the round list, when given,
    // is always viewable regardless of how much data exists for charts.
    final eligibleRounds = contractOutcomes(widget.scope).length;
    final hasEnoughData = eligibleRounds >= 3;
    final showSelector = widget.roundsView != null || hasEnoughData;

    final header = Row(
      children: [
        Expanded(
          child: Text(loc.translate('stats_title_view').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
        ),
        if (showSelector)
          InkWell(
            onTap: () => _openSelector(loc, colors),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_chartLabel(_selected, loc), style: WhistlyText.rowTitle(colors.ink).copyWith(fontSize: 13)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18, color: colors.ink),
              ],
            ),
          ),
      ],
    );

    final body = _selected == _ChartKind.rounds
        ? widget.roundsView!
        : (hasEnoughData
            ? SingleChildScrollView(child: _buildChart(colors, loc))
            : Text(loc.translate('stats_no_data'), style: WhistlyText.body(colors.muted, size: 13)));

    if (widget.roundsView == null) {
      // No round list to cover — sizes to its own content, exactly as
      // before this feature existed.
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [header, const SizedBox(height: 12), body],
        ),
      );
    }

    // A round list needs the flexible remaining height of the parent
    // Column to scroll — Expanded must be this widget's own build
    // output (not a wrapper the caller adds) so it's still a direct
    // child of that Column.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(AppSemanticColors colors, LocalizationProvider loc) {
    switch (_selected) {
      case _ChartKind.rounds:
        // Never reached — handled directly in build() above.
        return const SizedBox.shrink();

      case _ChartKind.progression:
        // allowProgression is only ever true for a single-game scope
        // (a cumulative line across unrelated games is meaningless), so
        // scope.first is always the right (and only) game here.
        if (widget.scope.isEmpty) return const SizedBox.shrink();
        return ScoreProgressionChart(game: widget.scope.first);

      case _ChartKind.trumps:
        final result = trumpSuitsChart(widget.scope, colors);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarChart(data: result.data),
            if (result.untracked > 0) ...[
              const SizedBox(height: 8),
              Text(
                loc.translate('stats_untracked_trump').replaceFirst('{}', '${result.untracked}'),
                style: WhistlyText.mono(colors.muted, size: 11),
              ),
            ],
          ],
        );

      case _ChartKind.contractSuccess:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarChart(data: contractSuccessChart(widget.scope, loc), axisMax: 1.0),
            const SizedBox(height: 8),
            Text(loc.translate('stats_miserie_note'), style: WhistlyText.mono(colors.muted, size: 11)),
          ],
        );

      case _ChartKind.accuracy:
        return BarChart(data: biddingAccuracyChart(widget.scope), axisMax: 1.0);

      case _ChartKind.risk:
        final result = riskFactorChart(widget.scope);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BarChart(
              data: result.data,
              axisMax: 1.0,
              referenceValue: result.referenceValue,
              referenceLabel: loc.translate('stats_table_average'),
            ),
            const SizedBox(height: 8),
            Text(loc.translate('stats_risk_help'), style: WhistlyText.mono(colors.muted, size: 11)),
          ],
        );
    }
  }
}

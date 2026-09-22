import 'package:whistly/models/game.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/stats/bar_chart.dart';
import 'package:whistly/stats/game_stats.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/widgets/round_setup_dialog.dart' show getContractName, kContracts;

/// ALTERATIONS.md (round 2) C4 — each function here is a thin mapping
/// from a `game_stats.dart` function's output to a `List<BarDatum>`. No
/// new painting lives in this file — `BarChart` (C3) draws everything.

/// Id -> display name across the whole scope. A player might have been
/// renamed since some of these games were played; this uses whichever
/// game in the scope mentions them last, which is "close enough" for a
/// chart label and never wrong in the common case (no rename at all).
Map<String, String> _playerNames(Iterable<Game> games) {
  final names = <String, String>{};
  for (final game in games) {
    for (final p in game.players) {
      names[p.id] = p.name;
    }
  }
  return names;
}

String _pct(double ratio) => '${(ratio * 100).round()}%';

/// C4.1 — trump suits chosen. Fixed suit-priority order (Hearts,
/// Diamonds, Clubs, Spades — the order rules_page.dart already uses),
/// never sorted by count, so the chart's shape is comparable between
/// scopes. `untracked` is the round count to show in the chart's
/// `stats_untracked_trump` footnote when > 0.
({List<BarDatum> data, int untracked}) trumpSuitsChart(Iterable<Game> games, AppSemanticColors colors) {
  final histogram = trumpHistogram(games);
  const suits = [
    ('Hearts', '♥'),
    ('Diamonds', '♦'),
    ('Clubs', '♣'),
    ('Spades', '♠'),
  ];
  final data = suits.map((entry) {
    final (suit, glyph) = entry;
    final count = histogram.counts[suit] ?? 0;
    final isRed = suit == 'Hearts' || suit == 'Diamonds';
    return BarDatum(
      label: '$glyph $suit',
      value: count.toDouble(),
      trailing: '$count',
      glyphColor: isRed ? colors.suitRed : colors.suitInk,
    );
  }).toList();
  return (data: data, untracked: histogram.untracked);
}

/// C4.2 — success rate by contract, ordered by `kContracts` (not by
/// rate) and labelled via `getContractName`. Only contract types that
/// actually occur in the scope are shown; `'Pass'` never appears since
/// `contractSuccess` never produces it.
List<BarDatum> contractSuccessChart(Iterable<Game> games, LocalizationProvider loc) {
  final success = contractSuccess(games);
  final data = <BarDatum>[];
  for (final contract in kContracts) {
    final key = contract['key'] as String;
    final stats = success[key];
    if (stats == null) continue;
    final rate = stats.total == 0 ? 0.0 : stats.made / stats.total;
    data.add(BarDatum(
      label: getContractName(loc, key),
      value: rate,
      trailing: '${_pct(rate)}  n=${stats.total}',
      dimmed: stats.total < 3,
    ));
  }
  return data;
}

/// C4.3 — bidding accuracy, sorted by rate DESCENDING (this chart's
/// whole question is who is best, so here sorting is the content).
/// Players with 0 declarations are already absent from `biddingAccuracy`.
List<BarDatum> biddingAccuracyChart(Iterable<Game> games) {
  final accuracy = biddingAccuracy(games);
  final names = _playerNames(games);
  final entries = accuracy.entries.map((entry) {
    final rate = entry.value.total == 0 ? 0.0 : entry.value.made / entry.value.total;
    return (playerId: entry.key, rate: rate, made: entry.value.made, total: entry.value.total);
  }).toList()
    ..sort((a, b) => b.rate.compareTo(a.rate));

  return entries
      .map((e) => BarDatum(
            label: names[e.playerId] ?? e.playerId,
            value: e.rate,
            trailing: '${_pct(e.rate)}  n=${e.total}',
            dimmed: e.total < 3,
          ))
      .toList();
}

/// C4.4 — risk factor, sorted descending, plus the table-average
/// reference line `BarChart` draws as a dashed rule.
({List<BarDatum> data, double referenceValue}) riskFactorChart(Iterable<Game> games) {
  final risk = riskFactor(games);
  final names = _playerNames(games);
  final entries = risk.byPlayer.entries.map((entry) {
    final rate = entry.value.eligible == 0 ? 0.0 : entry.value.taken / entry.value.eligible;
    return (playerId: entry.key, rate: rate, taken: entry.value.taken, eligible: entry.value.eligible);
  }).toList()
    ..sort((a, b) => b.rate.compareTo(a.rate));

  final data = entries
      .map((e) => BarDatum(
            label: names[e.playerId] ?? e.playerId,
            value: e.rate,
            trailing: '${_pct(e.rate)}  n=${e.eligible}',
            dimmed: e.eligible < 3,
          ))
      .toList();
  return (data: data, referenceValue: risk.tableAverage);
}

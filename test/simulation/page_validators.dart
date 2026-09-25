// Simulation framework — page validators.
//
// One `expect…Page` per screen. Each takes the view the ledger says the
// screen should show (expected_state.dart) and checks the rendered
// widget tree against it — texts, their left-to-right order inside the
// scoresheet columns, badges, enabled/disabled state. They assume the
// screen is already the one on top; navigation is the UI driver's job.
//
// They read what is rendered, never provider state, so a bug in a
// widget's own formatting (wrong sign, wrong column, stale total) fails
// here even when the provider is right.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/widgets/player_columns.dart';
import 'package:whistly/widgets/player_grid_picker.dart';

import 'expected_state.dart';
import 'sim_model.dart';

// ─── Tree helpers ────────────────────────────────────────────────────────

String? _textOf(Widget w) => w is Text ? (w.data ?? w.textSpan?.toPlainText()) : null;

/// Every `Text` under [scope], in tree (= reading) order.
List<String> textsIn(Finder scope) => find
    .descendant(of: scope, matching: find.byType(Text))
    .evaluate()
    .map((e) => _textOf(e.widget))
    .whereType<String>()
    .toList();

/// Every `Text` under [scope], ordered by rendered x position.
List<String> textsLeftToRight(WidgetTester tester, Finder scope) {
  final entries = <(double, String)>[];
  for (final e in find.descendant(of: scope, matching: find.byType(Text)).evaluate()) {
    final s = _textOf(e.widget);
    if (s == null) continue;
    final box = e.renderObject as RenderBox;
    entries.add((box.localToGlobal(Offset.zero).dx, s));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  return entries.map((e) => e.$2).toList();
}

void _expectList(List<String> actual, List<String> expected, String what) {
  expect(actual, orderedEquals(expected), reason: what);
}

/// The texts of one `PlayerColumns` cell, in tree order.
List<String> _cellTexts(WidgetTester tester, Finder columns, int i) {
  final cells = tester.widget<PlayerColumns>(columns).cells;
  return textsIn(find.descendant(of: columns, matching: find.byWidget(cells[i])));
}

/// The scoresheet round rows under the header strip, top to bottom: each
/// is the `Column` holding a meta band and a delta band.
List<Finder> _roundRows() {
  final bands = find.byType(PlayerColumns);
  final n = bands.evaluate().length;
  return [
    for (var i = 1; i < n; i++) find.ancestor(of: bands.at(i), matching: find.byType(Column)).first,
  ];
}

void _expectRoundRow(WidgetTester tester, Finder row, RoundRowView v, {required bool deletable}) {
  final deltaBand = find.descendant(of: row, matching: find.byType(PlayerColumns));
  final deltaTexts = textsLeftToRight(tester, deltaBand);
  final all = textsIn(row);
  final meta = all.sublist(0, all.length - deltaTexts.length);
  _expectList(meta, v.meta, 'round ${v.roundNumber}: meta band');
  _expectList(deltaTexts, v.deltas, 'round ${v.roundNumber}: delta cells (seat order)');
  expect(find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
      deletable ? findsOneWidget : findsNothing,
      reason: 'round ${v.roundNumber}: delete affordance only on the newest round');
}

// ─── Active game ─────────────────────────────────────────────────────────

void expectActiveGamePage(WidgetTester tester, ExpectedWorld world, ActiveGameView v) {
  expect(find.text(v.headerLine), findsOneWidget, reason: 'header line "${v.headerLine}"');

  // Header strip: one column per seat, in seat order.
  final header = find.byType(PlayerColumns).first;
  final cells = tester.widget<PlayerColumns>(header).cells;
  expect(cells.length, v.cells.length, reason: 'header strip column count');
  final dealer = world.t('dealer').toUpperCase();
  final lead = world.t('lead').toUpperCase();
  for (var i = 0; i < v.cells.length; i++) {
    final c = v.cells[i];
    _expectList(
      _cellTexts(tester, header, i),
      // `if (!= null)`, not a null-aware element: build_runner's pinned
      // analyzer can't parse those (see game_provider.dart).
      // ignore: use_null_aware_elements
      [c.name, if (c.crownLabel != null) c.crownLabel!, if (c.isDealer) dealer, if (c.isLeader) lead, c.scoreText],
      'header cell $i (${c.name})',
    );
    final cell = find.descendant(of: header, matching: find.byWidget(cells[i]));
    expect(find.descendant(of: cell, matching: find.byType(WhistlyCrownBadge)),
        c.hasCrown ? findsOneWidget : findsNothing,
        reason: 'crown on ${c.name}');
  }

  final passPrefix = '${world.t('bid_pass')} — ';
  if (v.multiplierBanner != null) {
    expect(find.text(v.multiplierBanner!), findsOneWidget, reason: 'Rondpas multiplier banner');
  } else {
    expect(find.textContaining(passPrefix), findsNothing, reason: 'no multiplier banner expected');
  }

  final rows = _roundRows();
  expect(rows.length, v.rows.length, reason: 'number of round rows (is the surface tall enough to build them all?)');
  if (v.emptyText != null) expect(find.text(v.emptyText!), findsOneWidget);
  for (var i = 0; i < rows.length; i++) {
    _expectRoundRow(tester, rows[i], v.rows[i], deletable: i == 0);
  }

  // Suit strip: the 22px glyphs, each with its trump count underneath.
  for (final suit in Suit.values) {
    final glyph = find.byWidgetPredicate((w) => w is Text && w.data == suit.glyph && w.style?.fontSize == 22);
    expect(glyph, findsOneWidget, reason: 'suit strip ${suit.glyph}');
    final column = find.ancestor(of: glyph, matching: find.byType(Column)).first;
    _expectList(textsIn(column), [suit.glyph, '${v.suitCounts[suit]}'], 'suit strip count ${suit.glyph}');
  }

  final undo = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.undo), matching: find.byType(IconButton)));
  expect(undo.onPressed != null, v.rows.isNotEmpty, reason: 'undo enabled iff there are rounds');
}

// ─── Home ────────────────────────────────────────────────────────────────

void expectHomePage(WidgetTester tester, ExpectedWorld world, HomeView v) {
  final primary = find.widgetWithText(WhistlyPrimaryButton, v.primaryLabel);
  expect(primary, findsOneWidget, reason: 'primary button "${v.primaryLabel}"');
  expect(tester.widget<WhistlyPrimaryButton>(primary).onPressed != null, v.primaryEnabled,
      reason: 'primary button enabled state');

  expect(find.text(world.t('home_add_players_needed')), v.showsPlayersNeeded ? findsOneWidget : findsNothing,
      reason: '"add players" hint');

  if (v.hasActiveGame) {
    expect(find.text(v.dealerLine!), findsOneWidget, reason: 'home dealer line');
    final grid = find.byType(PlayerGridPicker);
    expect(grid, findsOneWidget);
    v.tableScores.forEach((name, score) {
      final nameText = find.descendant(of: grid, matching: find.text(name));
      expect(nameText, findsOneWidget, reason: 'home table: $name');
      final cell = find.ancestor(of: nameText, matching: find.byType(Column)).first;
      _expectList(textsIn(cell), [name, score], 'home table cell $name');
    });
  } else {
    expect(find.byType(PlayerGridPicker), findsNothing, reason: 'no table without an active game');
  }
}

// ─── Players ─────────────────────────────────────────────────────────────

void expectPlayersPage(WidgetTester tester, ExpectedWorld world, PlayersView v) {
  final list = find.byType(ListView);
  expect(list, findsOneWidget);
  final names = textsIn(list).where(v.order.contains).toList();
  _expectList(names, v.order, 'players list order (favourites first, then A-Z)');

  for (final name in v.order) {
    final row = find.ancestor(of: find.descendant(of: list, matching: find.text(name)), matching: find.byType(InkWell)).first;
    final fav = v.favorites[name]!;
    expect(find.descendant(of: row, matching: find.byIcon(fav ? Icons.star : Icons.star_border)), findsOneWidget,
        reason: '$name favourite star');
    expect(find.descendant(of: row, matching: find.byType(WhistlyCrownBadge)),
        v.crowned.contains(name) ? findsOneWidget : findsNothing,
        reason: '$name crown');
  }
}

// ─── History ─────────────────────────────────────────────────────────────

void expectHistoryPage(WidgetTester tester, ExpectedWorld world, HistoryView v) {
  if (v.emptyText != null) {
    expect(find.text(v.emptyText!), findsOneWidget);
    return;
  }
  final statsTitle = world.t('stats_section_title').toUpperCase();
  expect(find.text(statsTitle), v.showsStatsSection ? findsOneWidget : findsNothing, reason: 'history stats section');

  final texts = textsIn(find.byType(ListView)).where((t) => t != statsTitle).toList();
  final abandoned = world.t('history_abandoned').toUpperCase();
  var k = 0;
  String next(String what) {
    expect(k, lessThan(texts.length), reason: 'history list ended early, expected $what');
    return texts[k++];
  }

  for (final (i, e) in v.entries.indexed) {
    final label = 'history row $i (game #${e.gameIndex})';
    expect(next('winner'), e.winnerLine, reason: '$label winner');
    if (e.abandoned) expect(next('badge'), abandoned, reason: '$label abandoned badge');
    next('date'); // formatted wall-clock time — not modelled
    expect(next('rounds'), e.roundsLine, reason: '$label rounds');
    expect(next('score'), e.scoreText, reason: '$label top score');
  }
  expect(k, texts.length, reason: 'history list has more rows than expected: ${texts.sublist(k)}');
}

// ─── Game recap (history detail) ─────────────────────────────────────────

void expectRecapPage(WidgetTester tester, ExpectedWorld world, RecapView v) {
  final lead = world.t('lead').toUpperCase();
  final header = find.byType(PlayerColumns).first;
  final n = tester.widget<PlayerColumns>(header).cells.length;
  expect(n, v.finalScores.length, reason: 'recap column count');

  final seen = <String, String>{};
  final order = <int>[];
  String? leader;
  for (var i = 0; i < n; i++) {
    final texts = _cellTexts(tester, header, i);
    final name = texts.first;
    final score = texts.last;
    seen[name] = score;
    order.add(int.parse(score));
    if (texts.contains(lead)) leader = name;
  }
  expect(seen, v.finalScores, reason: 'recap: final score per player');
  expect(order, v.rankedScores, reason: 'recap: columns ranked highest score first');
  expect(leader, v.soleLeader, reason: 'recap: Lead badge');

  final rows = _roundRows();
  expect(rows.length, v.rows.length, reason: 'recap: number of round rows');
  for (var i = 0; i < rows.length; i++) {
    _expectRoundRow(tester, rows[i], v.rows[i], deletable: false);
  }
}

// ─── Player stats ────────────────────────────────────────────────────────

void expectPlayerStatsPage(WidgetTester tester, ExpectedWorld world, PlayerStatsView v) {
  expect(find.descendant(of: find.byType(AppBar), matching: find.text(v.title)), findsOneWidget,
      reason: 'stats page title');
  expect(find.text(v.subtitle), findsOneWidget, reason: 'stats page subtitle');

  v.stats.forEach((label, value) {
    final labelText = find.text(label);
    expect(labelText, findsOneWidget, reason: 'stat "$label"');
    final cell = find.ancestor(of: labelText, matching: find.byType(Column)).first;
    _expectList(textsIn(cell), [value, label], 'stat "$label"');
  });

  final body = textsIn(find.byType(SingleChildScrollView));
  final start = body.indexOf(world.t('stats_past_games').toUpperCase());
  expect(start, isNonNegative, reason: 'past games header');
  final past = body.sublist(start + 1);
  if (v.emptyText != null) {
    _expectList(past, [v.emptyText!], 'no past games');
    return;
  }
  expect(past.length, v.pastGames.length * 3, reason: 'past games rows: $past');
  for (final (i, (winner, score)) in v.pastGames.indexed) {
    expect(past[i * 3], winner, reason: 'past game $i winner');
    expect(past[i * 3 + 2], score, reason: 'past game $i score');
  }
}

// ─── End-of-game celebration ─────────────────────────────────────────────

void expectCelebrationDialog(WidgetTester tester, CelebrationView v) {
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  final texts = textsIn(dialog);
  expect(texts, containsAllInOrder([v.heading, ...v.winners, v.scoreLine]), reason: 'celebration dialog');
}

// Simulation framework — the UI driver.
//
// Executes every [SimStep] by tapping through the real app, the way a
// player would: the Players tab's add dialog, the table setup page, the
// multi-step round sheet (contract → declarer → partner → negotiated
// tricks → trump → result), the undo and delete confirmations, the End
// game dialog and the win celebration.
//
// Needs a harness opened with [SimStorage.memory] (see sim_harness.dart
// for why) and the app already pumped from `harness.app()`.
//
// With [validate] on, it also checks every screen it passes through
// against the ledger: the table setup list, the celebration dialog, and
// the active game after every round/undo/delete. [tour] visits every
// other page (Home, Players, each player's stats, History, each game's
// recap) and validates them too.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/active_game_page.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/widgets/player_grid_picker.dart';
import 'package:whistly/widgets/round_setup_dialog.dart';

import 'expected_state.dart';
import 'page_validators.dart';
import 'sim_harness.dart';
import 'sim_model.dart';
import 'sim_runner.dart';

class UiDriver implements SimDriver {
  final WidgetTester tester;
  final SimHarness h;
  final bool validate;

  UiDriver(this.tester, this.h, {this.validate = true});

  String t(String key) => h.loc.translate(key);
  String up(String key) => t(key).toUpperCase();

  // ─── Low-level helpers ─────────────────────────────────────────────────

  /// [settle] false: pump a fixed second instead of pumpAndSettle — for
  /// the win dialog, whose confetti keeps animating and never settles.
  Future<void> tap(Finder f, {String? what, bool settle = true}) async {
    expect(f, findsOneWidget, reason: 'tap target: ${what ?? f}');
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  /// Taps something that advances the round sheet after a Future.delayed
  /// (150-300ms) — pumpAndSettle alone doesn't advance fake time past a
  /// pending timer that isn't an animation.
  Future<void> tapAndWait(Finder f, {String? what}) async {
    await tap(f, what: what);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // Finders skip offstage widgets, and a pushed opaque route puts the tab
  // bar offstage — so "tab bar found" means "nothing is pushed on top".
  bool get _atRoot => find.byType(BottomNavigationBar).evaluate().isNotEmpty;

  bool get _onActiveGame => find.byType(ActiveGamePage).evaluate().isNotEmpty;

  /// Back to the tab bar from anywhere the simulation goes.
  Future<void> toRoot() async {
    var guard = 0;
    while (!_atRoot) {
      if (++guard > 5) fail('could not navigate back to the tab bar');
      if (_onActiveGame) {
        // Its own back IconButton, not an AppBar BackButton.
        await tap(find.byTooltip(t('back')), what: 'active game back');
      } else {
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> openTab(int index) async {
    await toRoot();
    const keys = ['start_game', 'players', 'history', 'rules'];
    await tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(up(keys[index]))),
        what: 'tab ${keys[index]}');
  }

  Finder get _sheet => find.byType(RoundSetupDialog);
  Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);
  Finder _inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

  // ─── Steps ─────────────────────────────────────────────────────────────

  @override
  Future<void> execute(SimStep step, ExpectedWorld world) async {
    switch (step) {
      case AddPlayerStep(:final name):
        await openTab(1);
        await tap(find.byIcon(Icons.person_add), what: 'add player');
        await tester.enterText(find.byType(TextField), name);
        await tester.pump();
        waitForNextMillisecond();
        await tap(_inDialog(find.text(up('add'))), what: 'ADD');
        world.bindId(name, h.players.players.firstWhere((p) => p.name == name).id);

      case ToggleFavoriteStep(:final name):
        await openTab(1);
        final row = find.ancestor(
          of: find.descendant(of: find.byType(ListView), matching: find.text(name)),
          matching: find.byType(InkWell),
        ).first;
        await tap(find.descendant(of: row, matching: find.byType(IconButton)), what: 'star of $name');

      case StartGameStep(:final seats):
        await openTab(0);
        await tap(find.widgetWithText(WhistlyPrimaryButton, up('new_game')), what: 'NEW GAME');
        final list = find.byType(ListView);
        if (validate) {
          // The setup page lists the roster in PlayerProvider order.
          final listed = textsIn(list).where(world.players.containsKey).toList();
          expect(listed, world.rosterOrder, reason: 'table setup: roster order');
        }
        for (final s in seats) {
          await tap(find.descendant(of: list, matching: find.text(s)), what: 'seat $s');
        }
        waitForNextMillisecond();
        await tap(find.widgetWithText(WhistlyPrimaryButton, up('start_game')), what: 'START GAME');
        expect(_onActiveGame, isTrue, reason: 'START GAME opens the active game');

      case PlayRoundStep(:final round):
        await _enterRound(round, world);

      case UndoRoundStep():
        await tap(find.byIcon(Icons.undo), what: 'undo icon');
        await tap(_inDialog(find.text(up('undo'))), what: 'confirm UNDO');

      case DeleteLastRoundStep():
        await tap(find.byIcon(Icons.delete_outline), what: 'delete icon on newest round');
        await tap(_inDialog(find.text(up('delete'))), what: 'confirm DELETE');

      case EndGameStep(:final ending):
        await tap(find.widgetWithText(WhistlySecondaryButton, up('end_game')), what: 'END GAME');
        if (ending == GameEnding.abandon) {
          await tap(_inDialog(find.text(up('active_game_abandon'))), what: 'ABANDON');
        } else {
          await tap(_inDialog(find.text(up('end_game'))), what: 'confirm END GAME', settle: false);
          if (validate) expectCelebrationDialog(tester, world.celebrationView());
          await tap(find.widgetWithText(WhistlyPrimaryButton, up('back_home')), what: 'BACK TO HOME', settle: false);
          await tester.pumpAndSettle();
        }
        expect(_onActiveGame, isFalse, reason: 'ending a game leaves the active game page');
    }
  }

  Future<void> _enterRound(SimRound r, ExpectedWorld world) async {
    await tap(find.widgetWithText(WhistlyPrimaryButton, up('active_game_add_round')), what: 'ADD ROUND');
    expect(_sheet, findsOneWidget);

    final contractName = world.contractName(r.contract);
    await tapAndWait(_inSheet(find.text(contractName)), what: 'contract $contractName');
    if (r.contract == Contract.pass) {
      expect(_sheet, findsNothing, reason: 'Pass submits straight away');
      return;
    }

    final nl = h.loc.currentLanguage == AppLanguage.nl;
    if (r.contract.isMiserie && r.partner != null) {
      await tap(_inSheet(find.text((nl ? '2 Spelers' : '2 Players').toUpperCase())), what: 'Miserie: 2 players');
    }
    final grid = _inSheet(find.byType(PlayerGridPicker));
    await tapAndWait(find.descendant(of: grid, matching: find.text(r.declarer!)), what: 'declarer ${r.declarer}');
    if (r.partner != null) {
      await tapAndWait(find.descendant(of: grid, matching: find.text(r.partner!)), what: 'partner ${r.partner}');
    }

    if (r.contract.isNegotiable) {
      for (var i = r.contract.requiredTricks; i < r.agreedTricks; i++) {
        await tap(_inSheet(find.byIcon(Icons.add)), what: 'negotiated +');
      }
      if (validate) expect(_inSheet(find.text('${r.agreedTricks}')), findsOneWidget, reason: 'negotiated tricks shown');
      await tapAndWait(find.widgetWithText(WhistlyPrimaryButton, up('next')), what: 'NEXT');
    }

    if (r.contract.hasTricks) {
      await tapAndWait(_inSheet(find.text(r.trump!.glyph)), what: 'trump ${r.trump!.glyph}');
      // The tricks-won stepper starts at the agreed count.
      final diff = r.tricksWon - r.agreedTricks;
      for (var i = 0; i < diff.abs(); i++) {
        await tap(_inSheet(find.byIcon(diff > 0 ? Icons.add : Icons.remove)), what: 'tricks won ${diff > 0 ? '+' : '-'}');
      }
      if (validate) expect(_inSheet(find.text('${r.tricksWon}')), findsOneWidget, reason: 'tricks won shown');
    }

    if (r.contract.isMiserie) {
      final failed = _inSheet(find.text(up('setup_failed')));
      if (!r.declarerMiserieSuccess) await tap(failed.at(0), what: 'declarer failed');
      if (r.partner != null && !r.partnerMiserieSuccess) await tap(failed.at(1), what: 'partner failed');
    }

    await tap(_inSheet(find.byType(WhistlyPrimaryButton)), what: 'confirm round');
    expect(_sheet, findsNothing, reason: 'confirming closes the round sheet');
  }

  // ─── Validation tour ───────────────────────────────────────────────────

  /// Visits and validates every page, then returns to the active game if
  /// there is one.
  Future<void> tour(ExpectedWorld world) async {
    await openTab(0);
    expectHomePage(tester, world, world.homeView());

    await openTab(1);
    expectPlayersPage(tester, world, world.playersView());
    for (final name in world.rosterOrder) {
      await tap(
        find.descendant(of: find.byType(ListView), matching: find.text(name)),
        what: 'player row $name',
      );
      expectPlayerStatsPage(tester, world, world.playerStatsView(name));
      await toRoot();
    }

    await openTab(2);
    final history = world.historyView();
    expectHistoryPage(tester, world, history);
    for (final (i, entry) in history.entries.indexed) {
      await tap(_historyRow(i), what: 'history row $i');
      expectRecapPage(tester, world, world.recapView(world.games[entry.gameIndex]));
      await toRoot();
    }

    if (world.activeGame != null) {
      await openTab(0);
      await tap(find.widgetWithText(WhistlyPrimaryButton, up('continue_game')), what: 'CONTINUE GAME');
      expectActiveGamePage(tester, world, world.activeGameView());
    }
  }

  /// The i-th game row of the History list (skipping the stats section).
  Finder _historyRow(int i) {
    final pattern = RegExp('^${RegExp.escape(t('history_rounds_played')).replaceFirst(r'\{\}', r'\d+')}\$');
    final rows = find.descendant(of: find.byType(ListView), matching: find.byType(InkWell)).evaluate().where((e) {
      return find
          .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
          .evaluate()
          .any((t) => pattern.hasMatch((t.widget as Text).data ?? ''));
    }).toList();
    return find.byWidget(rows[i].widget);
  }
}

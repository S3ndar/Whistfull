// UI simulation: random games played by tapping through the real app,
// with every screen validated against the simulation ledger.
//
// Each step (add player, star a favourite, seat a table, enter a round
// through the round sheet, undo, delete, end or abandon) is performed
// through the widgets. After each step the rendered active-game page
// (scoresheet header, badges, multiplier banner, every round row, suit
// strip) and the provider state are checked; after every game the Home
// and History pages; and at the end a full tour visits every page —
// Home, Players, each player's stats, History and every game's recap.
//
//   flutter test test/simulation/ui_simulation_test.dart \
//     --dart-define=SIM_UI_GAMES=6 --dart-define=SIM_UI_SEEDS=5
//   flutter test test/simulation/ui_simulation_test.dart --dart-define=SIM_SEED=2003

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whistly/providers/localization_provider.dart';

import 'expected_state.dart';
import 'game_generator.dart';
import 'page_validators.dart';
import 'sim_harness.dart';
import 'sim_model.dart';
import 'sim_runner.dart';
import 'ui_driver.dart';

const int kUiGames = int.fromEnvironment('SIM_UI_GAMES', defaultValue: 3);
const int kUiSeeds = int.fromEnvironment('SIM_UI_SEEDS', defaultValue: 3);
const int kSeed = int.fromEnvironment('SIM_SEED', defaultValue: -1);

List<int> get seeds => kSeed >= 0 ? [kSeed] : [for (var i = 0; i < kUiSeeds; i++) 2000 + i];

Future<void> runUiSimulation(
  WidgetTester tester, {
  required int seed,
  required int games,
  AppLanguage language = AppLanguage.en,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  // Tall enough that every list (round rows, history, roster) is fully
  // built — ListView only builds what is on screen.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final h = (await tester.runAsync(
    () => SimHarness.open(storage: SimStorage.memory, language: language, themeMode: themeMode),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));

  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();

  final world = ExpectedWorld(settings: h.settings, loc: h.loc);
  final driver = UiDriver(tester, h);
  final script = GameGenerator(seed: seed, config: GeneratorConfig.ui(games: games)).generate();

  // Empty app first: nothing to show anywhere yet.
  expectHomePage(tester, world, world.homeView());

  await SimRunner(script: script, world: world, driver: driver).run(
    checkpoint: (_, step) async {
      expectProviderState(h, world);
      switch (step) {
        case StartGameStep() || PlayRoundStep() || UndoRoundStep() || DeleteLastRoundStep():
          expectActiveGamePage(tester, world, world.activeGameView());
        case EndGameStep():
          expectHomePage(tester, world, world.homeView());
          await driver.openTab(2);
          expectHistoryPage(tester, world, world.historyView());
        case AddPlayerStep() || ToggleFavoriteStep():
          expectPlayersPage(tester, world, world.playersView());
      }
    },
  );

  await driver.tour(world);
  expect(tester.takeException(), isNull);
}

void main() {
  group('random games through the UI', () {
    for (final seed in seeds) {
      testWidgets('seed $seed: $kUiGames games, every screen matches the ledger', (tester) async {
        await runUiSimulation(tester, seed: seed, games: kUiGames);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });

  testWidgets('Dutch + dark mode: same validation, translated expectations', (tester) async {
    await runUiSimulation(tester, seed: 4242, games: 2, language: AppLanguage.nl, themeMode: ThemeMode.dark);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

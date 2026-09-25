// Simulation framework — the app harness.
//
// Boots the real providers against a throwaway Hive, and can pump the
// real `WhistlyApp` on top of them.
//
// Two storage modes:
// - [SimStorage.disk]: a temp-directory Hive. Real serialization through
//   the generated adapters, and [SimHarness.relaunch] can close
//   everything and re-open it from disk — "does the data survive an app
//   restart". Only usable from real-async code (`test()`, or inside
//   `tester.runAsync`): file I/O never completes inside testWidgets'
//   fake-async zone.
// - [SimStorage.memory]: every box is pre-opened in memory
//   (`Hive.openBox(name, bytes: ...)`), so when a provider later calls
//   `Hive.openBox(name)` it gets the already-open in-memory box. Writes
//   complete as microtasks, which is what makes tapping through the UI
//   inside testWidgets work without `runAsync` around every tap.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/main.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';

enum SimStorage { disk, memory }

class SimHarness {
  final SimStorage storage;
  final AppLanguage language;
  final ThemeMode themeMode;
  final Directory tempDir;

  late PlayerProvider players;
  late GameProvider games;
  late ScoringSettings settings;
  late LocalizationProvider loc;
  late ThemeProvider theme;
  late AdsProvider ads;

  SimHarness._(this.storage, this.language, this.themeMode, this.tempDir);

  static Future<SimHarness> open({
    SimStorage storage = SimStorage.disk,
    AppLanguage language = AppLanguage.en,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final dir = await Directory.systemTemp.createTemp('whistly_sim_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());

    PackageInfo.setMockInitialValues(
      appName: 'Whistly',
      packageName: 'whistly',
      version: '0.0.0-sim',
      buildNumber: '0',
      buildSignature: '',
    );

    final h = SimHarness._(storage, language, themeMode, dir);
    if (storage == SimStorage.memory) {
      final empty = Uint8List(0);
      await Hive.openBox<Player>('players_box', bytes: empty);
      await Hive.openBox<Game>('games_box', bytes: empty);
      await Hive.openBox('app_state_box', bytes: empty);
      await Hive.openBox('settings_box', bytes: empty);
    }
    final settingsBox = await Hive.openBox('settings_box');
    // Ads off: the ad SDK and the UMP consent flow are platform channels
    // with no test implementation. With the entitlement set, AdsProvider
    // never touches them and every AdaptiveBannerAd collapses to nothing.
    await settingsBox.put('ads_removed', true);
    await settingsBox.put('language_index', language.index);
    await settingsBox.put('theme_mode', themeMode.index);

    await h._initProviders();
    return h;
  }

  Future<void> _initProviders() async {
    players = PlayerProvider();
    games = GameProvider();
    settings = ScoringSettings();
    loc = LocalizationProvider();
    theme = ThemeProvider();
    ads = AdsProvider();
    await players.init();
    await games.init();
    await settings.init();
    await loc.init();
    await theme.init();
    await ads.init();
  }

  /// Closes every box and boots fresh providers from what is on disk —
  /// the equivalent of killing and relaunching the app.
  Future<void> relaunch() async {
    if (storage != SimStorage.disk) {
      throw StateError('relaunch() needs SimStorage.disk: memory boxes do not survive Hive.close()');
    }
    await _drainWrites();
    await Hive.close();
    await _initProviders();
  }

  /// `GameProvider._persist` is fire-and-forget, and after a write Hive may
  /// start a compaction; closing the box underneath either one logs
  /// "Box has already been closed" (the data itself is already written).
  /// The app never closes Hive, so this only matters here: give in-flight
  /// writes a moment to finish before closing. Only for real-async code;
  /// memory boxes have nothing in flight.
  Future<void> _drainWrites() async {
    if (storage == SimStorage.disk) await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> dispose() async {
    await _drainWrites();
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  }

  /// The real app, wired to this harness's already-initialised providers.
  /// (PurchaseProvider is left out: it is only read by the Settings page,
  /// which the simulation never opens, and it talks to the store plugin.)
  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: players),
          ChangeNotifierProvider<ScoringSettings>.value(value: settings),
          ChangeNotifierProvider<GameProvider>.value(value: games),
          ChangeNotifierProvider<LocalizationProvider>.value(value: loc),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<AdsProvider>.value(value: ads),
        ],
        child: const WhistlyApp(),
      );
}

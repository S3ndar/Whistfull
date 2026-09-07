import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/billing/purchase_provider.dart';
import 'package:whistly/main.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_widget_test_');
    // Hive.init(path) instead of Hive.initFlutter(): the latter resolves its
    // storage directory via path_provider, which needs a platform channel
    // mock this test doesn't set up. Pointing straight at a temp directory
    // gives the same on-disk behaviour without that dependency.
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('app boots against a temp-directory Hive and renders the home screen',
      (WidgetTester tester) async {
    // The default test surface (800x600) is far smaller than any real phone
    // and overflows this screen's layout; size it like an actual device so
    // the smoke test reflects real rendering rather than a test-harness
    // artifact.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PlayerProvider()..init()),
          ChangeNotifierProvider(create: (_) => ScoringSettings()..init()),
          ChangeNotifierProvider(create: (_) => GameProvider()..init()),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider(create: (_) => AdsProvider()..init()),
          ChangeNotifierProvider(
            create: (context) =>
                PurchaseProvider(adsProvider: context.read<AdsProvider>())..init(),
          ),
        ],
        child: const WhistlyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The home tab (bottom nav index 0) should be showing: its title and
    // the primary navigation destinations are the smoke-test signal that
    // the app booted, providers initialised and the widget tree rendered.
    expect(find.text('WHISTLY'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    // The home tab (index 0) is selected by default, so the bottom nav
    // shows its *active* icon variant, not the outline one.
    expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
  });
}

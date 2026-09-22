import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/billing/purchase_provider.dart';
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
import 'package:whistly/theme/whistly_components.dart';

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
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
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

    await pumpApp(tester);
    await tester.pumpAndSettle();

    // The home tab (WhistlyTabBar index 0) should be showing: the brand
    // wordmark and the primary navigation destinations are the smoke-test
    // signal that the app booted, providers initialised and the widget
    // tree rendered.
    expect(find.text('Whistly'), findsOneWidget);
    expect(find.byType(WhistlyTabBar), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('4: Home renders without a suit glyph (ALTERATIONS.md B5)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.pumpAndSettle();

    // The brand mark (WhistlyLogoMark, in the header) legitimately shows
    // each suit glyph exactly once as its own logo design — that's not
    // the decorative strip B5 removes. Before B5, the strip duplicated
    // each glyph a second time; after, each should appear exactly once.
    for (final glyph in ['♠', '♥', '♦', '♣']) {
      expect(find.textContaining(glyph), findsOneWidget);
    }
  });

  testWidgets('5: Home lays out at 320x568 with no overflow (ALTERATIONS.md B5)',
      (WidgetTester tester) async {
    // The smallest realistic phone viewport — the one that had already
    // overflowed once with the suit strip present.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Whistly'), findsOneWidget);
  });
}

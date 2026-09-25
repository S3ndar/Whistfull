// ALTERATIONS.md (round 2) Part F — the add-round sheet fills the screen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/widgets/round_setup_dialog.dart';

void main() {
  late Directory tempDir;
  late GameProvider gameProvider;
  late ScoringSettings settings;
  late List<GamePlayerRef> players;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_round_sheet_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(PlayerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GameAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RoundAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GamePlayerRefAdapter());

    final rawPlayers = [
      Player(id: 'p1', name: 'Anke'),
      Player(id: 'p2', name: 'Bram'),
      Player(id: 'p3', name: 'Cato'),
      Player(id: 'p4', name: 'Dries'),
    ];
    players = rawPlayers.map((p) => GamePlayerRef(id: p.id, name: p.name)).toList();

    settings = ScoringSettings();
    gameProvider = GameProvider();
    await gameProvider.init();
    gameProvider.startGame(rawPlayers, settings: settings);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Mirrors the exact showModalBottomSheet call in active_game_page.dart —
  // the sheet's own height guarantee (Part F) comes from the combination
  // of this call's `constraints` AND RoundSetupDialog's own fixed-height
  // SizedBox, so the test must go through a real sheet, not just pump the
  // dialog's content directly into a Scaffold body.
  Future<void> openSheet(WidgetTester tester, Size surfaceSize) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameProvider>.value(value: gameProvider),
          ChangeNotifierProvider<ScoringSettings>.value(value: settings),
          ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => WhistlyPrimaryButton(
                label: 'Open',
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
                    builder: (_) => RoundSetupDialog(players: players),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WhistlyPrimaryButton));
    await tester.pumpAndSettle();
  }

  double sheetHeight(WidgetTester tester) => tester.getSize(find.byType(RoundSetupDialog)).height;

  testWidgets('9: opening the sheet on a 640px-tall surface gives it a height >= 0.85 x 640', (tester) async {
    await openSheet(tester, const Size(360, 640));
    expect(sheetHeight(tester), greaterThanOrEqualTo(0.85 * 640));
  });

  testWidgets("10: the sheet's height is the same on the contract step and on the result step", (tester) async {
    await openSheet(tester, const Size(360, 640));
    final contractStepHeight = sheetHeight(tester);

    // Walk the wizard: contract (Ask & Join, needs a partner and is
    // negotiable) -> declarer -> partner -> negotiated -> trump -> result.
    await tester.tap(find.text('Ask & Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bram'));
    await tester.pumpAndSettle();
    // Negotiated step: advance via its own "Next" primary button —
    // scoped to inside the sheet, since the page behind it also has a
    // WhistlyPrimaryButton (the "Open" trigger) still in the tree.
    await tester.tap(find.descendant(of: find.byType(RoundSetupDialog), matching: find.byType(WhistlyPrimaryButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♥'));
    await tester.pumpAndSettle();

    expect(sheetHeight(tester), contractStepHeight);
  });

  testWidgets('11: the confirm button is hit-testable on the result step of an Ask & Join without scrolling, at 360x640', (tester) async {
    await openSheet(tester, const Size(360, 640));

    await tester.tap(find.text('Ask & Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anke'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bram'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RoundSetupDialog), matching: find.byType(WhistlyPrimaryButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('♥'));
    await tester.pumpAndSettle();

    // Now on the result step — the confirm button must be within the
    // visible viewport, i.e. hit-testable without an extra scroll
    // gesture. The sheet's own trigger button sits behind the modal
    // barrier and is no longer hit-testable, so only the confirm
    // button (inside RoundSetupDialog) should match.
    final confirmButton = find.descendant(
      of: find.byType(RoundSetupDialog),
      matching: find.byType(WhistlyPrimaryButton),
    );
    expect(confirmButton, findsOneWidget);
    expect(confirmButton.hitTestable(), findsOneWidget);
  });
}

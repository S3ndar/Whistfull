// ALTERATIONS.md B3 — player grid picker tests.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/widgets/player_grid_picker.dart';

void main() {
  late Directory tempDir;

  final players = const [
    PlayerGridEntry(id: 'p1', name: 'Anke'),
    PlayerGridEntry(id: 'p2', name: 'Bram'),
    PlayerGridEntry(id: 'p3', name: 'Cato'),
    PlayerGridEntry(id: 'p4', name: 'Dries'),
  ];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_player_grid_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    String? selectedId,
    String? disabledId,
    ValueChanged<PlayerGridEntry>? onSelect,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocalizationProvider()..init(),
        child: MaterialApp(
          home: Scaffold(
            body: PlayerGridPicker(
              players: players,
              selectedId: selectedId,
              disabledId: disabledId,
              showRecord: false,
              onSelect: onSelect,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('6: four cells render in seating order', (tester) async {
    await pumpPicker(tester);

    final names = ['Anke', 'Bram', 'Cato', 'Dries'];
    for (final name in names) {
      expect(find.text(name), findsOneWidget);
    }

    // Top-left to bottom-right reading order must match seating order:
    // sort by (y, then x) and compare against the seating list.
    final positioned = names
        .map((n) => MapEntry(n, tester.getTopLeft(find.text(n))))
        .toList()
      ..sort((a, b) {
        final dy = a.value.dy.compareTo(b.value.dy);
        return dy != 0 ? dy : a.value.dx.compareTo(b.value.dx);
      });
    expect(positioned.map((e) => e.key).toList(), names);
  });

  testWidgets('7: tapping a cell selects it and reports the right player', (tester) async {
    PlayerGridEntry? tapped;
    await pumpPicker(tester, onSelect: (p) => tapped = p);

    await tester.tap(find.text('Cato'));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'p3');
    expect(tapped?.name, 'Cato');
  });

  testWidgets('8: the declarer\'s cell is disabled when picking their partner', (tester) async {
    PlayerGridEntry? tapped;
    // Anke (p1) is already the declarer — disabled while picking her partner.
    await pumpPicker(tester, disabledId: 'p1', onSelect: (p) => tapped = p);

    await tester.tap(find.text('Anke'));
    await tester.pumpAndSettle();
    expect(tapped, isNull);

    await tester.tap(find.text('Bram'));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'p2');
  });
}

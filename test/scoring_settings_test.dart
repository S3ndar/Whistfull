import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:whistly/scoring_settings.dart';

void main() {
  late Directory tempDir;
  late ScoringSettings settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_scoring_settings_test_');
    Hive.init(tempDir.path);
    settings = ScoringSettings();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ScoringSettings Tests', () {
    test('should initialize with default settings values', () async {
      await settings.init();

      expect(settings.askAndJoinBase, 2);
      expect(settings.trull, 9);
      expect(settings.aloneBase, 2);
      expect(settings.misere, 5);
      expect(settings.abundanceBase, 5);
      expect(settings.openMisere, 10);
      expect(settings.soloSlim, 15);

      // Test compatibility getters
      expect(settings.askAndJoin, 2);
      expect(settings.alone, 2);
      expect(settings.abundance, 5);
    });

    test('should update scores immediately in-memory', () async {
      await settings.init();

      settings.updateScore(
        askAndJoinBase: 4,
        trull: 10,
        aloneBase: 3,
        misere: 6,
        abundanceBase: 8,
        openMisere: 12,
        soloSlim: 20,
      );

      // Verify immediate in-memory update (updateScore is fire-and-forget async)
      expect(settings.askAndJoinBase, 4);
      expect(settings.trull, 10);
      expect(settings.aloneBase, 3);
      expect(settings.misere, 6);
      expect(settings.abundanceBase, 8);
      expect(settings.openMisere, 12);
      expect(settings.soloSlim, 20);

      // Flush async Hive write before tearDown closes the box
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('should persist updated scores to Hive', () async {
      await settings.init();

      settings.updateScore(
        askAndJoinBase: 4,
        trull: 10,
        aloneBase: 3,
        misere: 6,
        abundanceBase: 8,
        openMisere: 12,
        soloSlim: 20,
      );

      // Allow the async Hive write (fire-and-forget) to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Re-initialize a new ScoringSettings object from the same Hive box to verify persistence
      final newSettings = ScoringSettings();
      await newSettings.init();

      expect(newSettings.askAndJoinBase, 4);
      expect(newSettings.trull, 10);
      expect(newSettings.aloneBase, 3);
      expect(newSettings.misere, 6);
      expect(newSettings.abundanceBase, 8);
      expect(newSettings.openMisere, 12);
      expect(newSettings.soloSlim, 20);
    });

    test('should partial update scores and leave others intact', () async {
      await settings.init();

      settings.updateScore(
        askAndJoinBase: 5,
      );

      expect(settings.askAndJoinBase, 5);
      expect(settings.trull, 9); // Unchanged default

      // Flush async Hive write before tearDown closes the box
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });
}

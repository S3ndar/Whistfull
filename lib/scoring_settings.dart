import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:whistly/utils/hive_recovery.dart';

class ScoringSettings extends ChangeNotifier {
  static const String _boxName = 'settings_box';

  // Base points (won/lost from each opponent)
  int askAndJoinBase = 2;
  int trull = 9;
  int aloneBase = 2;
  int misere = 5;
  int abundanceBase = 5; // Base for 9 tricks, others are tiered
  int openMisere = 10;
  int soloSlim = 15;

  Future<void> init() async {
    Box? box;
    try {
      box = await Hive.openBox(_boxName);
    } catch (e) {
      debugPrint('Error initializing ScoringSettings Hive box: $e');
      // Only reset the box when the error indicates a genuinely
      // unreadable/incompatible on-disk schema. A transient error should
      // leave the box null (and the app degraded) rather than wipe data.
      if (isUnrecoverableHiveError(e)) {
        try {
          await Hive.deleteBoxFromDisk(_boxName);
          box = await Hive.openBox(_boxName);
        } catch (inner) {
          debugPrint('Critical error resetting settings Hive box: $inner');
        }
      }
    }

    if (box != null) {
      askAndJoinBase = box.get('askAndJoinBase', defaultValue: 2);
      trull = box.get('trull', defaultValue: 9);
      aloneBase = box.get('aloneBase', defaultValue: 2);
      misere = box.get('misere', defaultValue: 5);
      abundanceBase = box.get('abundanceBase', defaultValue: 5);
      openMisere = box.get('openMisere', defaultValue: 10);
      soloSlim = box.get('soloSlim', defaultValue: 15);
    }
    notifyListeners();
  }

  // Legacy getters for compatibility
  int get askAndJoin => askAndJoinBase;
  int get alone => aloneBase;
  int get abundance => abundanceBase;

  /// Captures the current values as a plain map, keyed by field name.
  /// Used by `GameProvider.startGame` to stamp `Game.scoringSnapshot` with
  /// the settings in force when a game starts, so history can later show
  /// (or re-derive) figures using the settings that were actually live at
  /// the time — instead of whatever the settings happen to be today.
  Map<String, int> toSnapshot() {
    return {
      'askAndJoinBase': askAndJoinBase,
      'trull': trull,
      'aloneBase': aloneBase,
      'misere': misere,
      'abundanceBase': abundanceBase,
      'openMisere': openMisere,
      'soloSlim': soloSlim,
    };
  }

  /// Builds a standalone `ScoringSettings` from a snapshot map (e.g. a
  /// historical `Game.scoringSnapshot`), for display/re-derivation only.
  /// Missing keys fall back to the current defaults. This instance is not
  /// backed by Hive and is never `init()`-ed — never call `updateScore` on
  /// it, since that would try to persist into the live settings box.
  static ScoringSettings fromSnapshot(Map<String, int> snapshot) {
    final s = ScoringSettings();
    s.askAndJoinBase = snapshot['askAndJoinBase'] ?? s.askAndJoinBase;
    s.trull = snapshot['trull'] ?? s.trull;
    s.aloneBase = snapshot['aloneBase'] ?? s.aloneBase;
    s.misere = snapshot['misere'] ?? s.misere;
    s.abundanceBase = snapshot['abundanceBase'] ?? s.abundanceBase;
    s.openMisere = snapshot['openMisere'] ?? s.openMisere;
    s.soloSlim = snapshot['soloSlim'] ?? s.soloSlim;
    return s;
  }

  Future<void> updateScore({
    int? askAndJoinBase,
    int? trull,
    int? aloneBase,
    int? misere,
    int? abundanceBase,
    int? openMisere,
    int? soloSlim,
  }) async {
    if (askAndJoinBase != null) this.askAndJoinBase = askAndJoinBase;
    if (trull != null) this.trull = trull;
    if (aloneBase != null) this.aloneBase = aloneBase;
    if (misere != null) this.misere = misere;
    if (abundanceBase != null) this.abundanceBase = abundanceBase;
    if (openMisere != null) this.openMisere = openMisere;
    if (soloSlim != null) this.soloSlim = soloSlim;
    notifyListeners();

    final box = await Hive.openBox(_boxName);
    if (askAndJoinBase != null) await box.put('askAndJoinBase', askAndJoinBase);
    if (trull != null) await box.put('trull', trull);
    if (aloneBase != null) await box.put('aloneBase', aloneBase);
    if (misere != null) await box.put('misere', misere);
    if (abundanceBase != null) await box.put('abundanceBase', abundanceBase);
    if (openMisere != null) await box.put('openMisere', openMisere);
    if (soloSlim != null) await box.put('soloSlim', soloSlim);
  }
}

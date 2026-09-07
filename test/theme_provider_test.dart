import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:whistly/providers/theme_provider.dart';

void main() {
  late Directory tempDir;
  late ThemeProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_theme_test_');
    Hive.init(tempDir.path);
    provider = ThemeProvider();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ThemeProvider Tests', () {
    test('should initialize with System mode by default', () async {
      await provider.init();
      expect(provider.themeMode, ThemeMode.system);
      // isDark is a legacy getter: true for both dark and system, since it
      // has no BuildContext to resolve system's actual platform brightness.
      expect(provider.isDark, isTrue);
    });

    test('should change theme mode correctly', () async {
      await provider.init();
      provider.setThemeMode(ThemeMode.light);
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDark, isFalse);
    });

    test('should toggle theme mode correctly', () async {
      await provider.init();
      expect(provider.themeMode, ThemeMode.system);

      // toggleTheme() reads the legacy isDark getter, which treats system
      // as "dark" (see comment above), so the first toggle from the default
      // goes to light rather than dark.
      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('should persist theme selection', () async {
      await provider.init();
      provider.setThemeMode(ThemeMode.light);

      // Give a tiny moment for async write if any, though setThemeMode awaits Hive openBox/put
      // But let's create a new provider and load from the same Hive box to verify persistence.
      final newProvider = ThemeProvider();
      await newProvider.init();

      expect(newProvider.themeMode, ThemeMode.light);
      expect(newProvider.isDark, isFalse);
    });
  });
}

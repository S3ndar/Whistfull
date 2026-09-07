import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  static const String _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Legacy getter used by settings_page.dart. True for both
  /// ThemeMode.dark and ThemeMode.system (system has no BuildContext
  /// here to resolve platform brightness) so nothing that relied on
  /// this getter for "dark" behaviour breaks. Prefer [isDarkIn] when
  /// a BuildContext is available, since it resolves system correctly.
  bool get isDark => _themeMode != ThemeMode.light;

  /// Correctly resolves ThemeMode.system via the platform brightness.
  bool isDarkIn(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    final saved = box.get(_key, defaultValue: 0); // 0 = system (default)
    _themeMode = ThemeMode.values[saved];
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final box = await Hive.openBox(_boxName);
    await box.put(_key, mode.index);
  }

  void toggleTheme() {
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}

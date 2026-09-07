import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:whistly/providers/localization_provider.dart';

void main() {
  late Directory tempDir;
  late LocalizationProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('whistly_localization_test_');
    Hive.init(tempDir.path);
    provider = LocalizationProvider();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalizationProvider Tests', () {
    test('should initialize with English by default', () async {
      await provider.init();
      expect(provider.currentLanguage, AppLanguage.en);
      expect(provider.translate('app_title'), 'Whistly');
      expect(provider.translate('won'), 'ACHIEVED');
    });

    test('should change language and translate correctly', () async {
      await provider.init();

      provider.setLanguage(AppLanguage.nl);
      expect(provider.currentLanguage, AppLanguage.nl);
      expect(provider.translate('won'), 'GEHAALD'); // Dutch translation is 'GEHAALD'

      // Also verify fallback translation
      expect(provider.translate('app_title'), 'Whistly'); // Same in both or fallbacks
    });

    test('should persist language selection', () async {
      await provider.init();
      provider.setLanguage(AppLanguage.nl);

      // Reinitialize a new provider using the same box
      final newProvider = LocalizationProvider();
      await newProvider.init();

      expect(newProvider.currentLanguage, AppLanguage.nl);
    });
  });
}

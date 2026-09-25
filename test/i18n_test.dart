import 'package:flutter_test/flutter_test.dart';
import 'package:minacalc_pro/core/i18n.dart';

void main() {
  test('critical interface strings exist in all supported languages', () {
    const critical = [
      'login', 'jobs', 'map', 'sync', 'profile', 'online', 'offline',
      'syncing', 'saveDraft', 'checklist', 'photos', 'location',
      'signature', 'review', 'downloadMap', 'controlledItem', 'finish',
    ];
    for (final locale in AppStrings.supported) {
      final strings = AppStrings(locale);
      for (final key in critical) {
        expect(strings.t(key), isNot(equals(key)), reason: '$locale:$key');
        expect(strings.t(key).trim(), isNotEmpty, reason: '$locale:$key');
      }
      expect(strings.legalNotice.trim(), isNotEmpty);
    }
  });
}

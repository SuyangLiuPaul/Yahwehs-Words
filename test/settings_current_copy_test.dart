import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';

void main() {
  test('current settings labels and explanations exist in all locales', () {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      for (final key in [
        'settingsSectionDashboard',
        'dashboardLayoutHint',
        'dashboardSection_quickLinks_description',
        'onboardCustomizeBody',
        'onboardCustomizeBodyChina'
      ]) {
        expect(uiStrings[key]?[locale], isNotNull, reason: '$key / $locale');
        expect(uiStrings[key]![locale], isNotEmpty);
      }
    }
  });
  test('Home section copy matches the compact Home and fixed notices', () {
    expect(uiStrings['settingsSectionDashboard']!['en'], 'Home sections');
    expect(uiStrings['dashboardSection_quickLinks_description']!['en'],
        contains('expandable Study, Reference and Help'));
    expect(uiStrings['dashboardLayoutHint']!['en'], contains('announcements'));
    for (final key in ['onboardCustomizeBody', 'onboardCustomizeBodyChina']) {
      expect(uiStrings[key]!['en'], contains('Settings → Home sections'));
      expect(uiStrings[key]!['en'], isNot(contains('Dashboard layout')));
    }
  });
}

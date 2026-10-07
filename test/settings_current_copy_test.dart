import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/dashboard_section.dart';

void main() {
  test('every Home section has a localized settings description', () {
    for (final section in DashboardSection.values) {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final copy = uiStrings['dashboardSection_${section.name}_description'];
        expect(copy?[locale], isNotNull, reason: '${section.name} / $locale');
        expect(section.description(locale), copy![locale]);
      }
    }
  });
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

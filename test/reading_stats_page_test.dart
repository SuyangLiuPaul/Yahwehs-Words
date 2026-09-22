// What the reading-statistics page is allowed to say.
//
// Two claims on this page can be wrong in ways the reader cannot detect,
// so both are pinned here:
//
//  1. The period. A coverage percentage with no period attached reads as
//     a lifetime figure. A reader of two years' standing seeing "1% of
//     the canon" would be told something false about themselves by an
//     app that had only been counting since Tuesday.
//  2. The absence of a streak. 打卡 is excluded from this project, and a
//     "days in a row" number is the same mechanic whatever it is called,
//     so the guard is against the shape rather than against one word.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/reading_stats_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/profile_service.dart';
import 'package:yahwehs_words/services/reading_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWith(WidgetTester tester, Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    await ProfileService.instance.init();
    ReadingHistoryService.instance.resetForTest();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: ReadingStatsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// A record of John 3 and John 4, begun on 1 September 2026.
  Map<String, Object> seededRecord() {
    final scoped = ProfileService.instance.scopedKey;
    final begun = DateTime(2026, 9, 1, 8, 0);
    return {
      scoped(ReadingHistoryService.coverageBaseKey): jsonEncode({
        'John': [3, 4]
      }),
      scoped(ReadingHistoryService.logBaseKey): jsonEncode([
        {
          'b': 'John',
          'c': 4,
          'v': 'kjv',
          't': begun.add(const Duration(minutes: 5)).millisecondsSinceEpoch
        },
        {
          'b': 'John',
          'c': 3,
          'v': 'kjv',
          't': begun.millisecondsSinceEpoch
        },
      ]),
      scoped(ReadingHistoryService.sinceBaseKey): begun.millisecondsSinceEpoch,
    };
  }

  testWidgets('the page names the date recording began, beside the figures',
      (tester) async {
    // ProfileService.scopedKey needs a booted profile before the seed map
    // can be keyed, so the first init happens against an empty store.
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    expect(find.textContaining('2026-09-01'), findsOneWidget,
        reason: 'without the period line every percentage on the page reads '
            'as a lifetime figure');
  });

  testWidgets('coverage is shown as counts as well as a percentage',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    // 2 of the canon's 1,189 chapters. The raw counts sit beside the
    // percentage because "0%" alone hides whether that is 2 chapters or
    // none at all.
    expect(find.textContaining('2 / 1189'), findsOneWidget);
    expect(find.textContaining('/ 66'), findsOneWidget);
  });

  testWidgets('an empty record explains itself instead of showing zeroes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, {});

    // A wall of 0% would read as an accusation. The first thing a reader
    // sees here is what is recorded and where it goes.
    expect(find.textContaining('0 / 1189'), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  /// A single recent entry with the given book/version, under the given
  /// UI locale. Coverage is seeded to match so the page doesn't hit its
  /// empty state.
  Map<String, Object> seededEntry({
    required String book,
    required String version,
    required String locale,
  }) {
    final scoped = ProfileService.instance.scopedKey;
    final at = DateTime(2026, 9, 1, 8, 0);
    return {
      'locale': locale,
      scoped(ReadingHistoryService.coverageBaseKey): jsonEncode({
        book: [5]
      }),
      scoped(ReadingHistoryService.logBaseKey): jsonEncode([
        {'b': book, 'c': 5, 'v': version, 't': at.millisecondsSinceEpoch},
      ]),
      scoped(ReadingHistoryService.sinceBaseKey): at.millisecondsSinceEpoch,
    };
  }

  testWidgets(
      'a recent entry follows the version it was read in, not the UI locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    // Traditional CUVS entry under a Simplified UI locale: the row must
    // render Traditional glyphs, following e.version rather than locale.
    await pumpWith(
        tester,
        seededEntry(
            book: 'John', version: 'cuvs-yhwh-tr', locale: 'zh-Hans'));

    expect(find.textContaining('約翰福音 5'), findsOneWidget,
        reason: 'book names follow the reading version, not the UI locale');
    expect(find.textContaining('约翰福音 5'), findsNothing,
        reason: 'must not fall back to the Simplified locale default');
  });

  testWidgets('an English-version entry renders English under a zh locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(
        tester, seededEntry(book: 'John', version: 'kjv', locale: 'zh-Hans'));

    expect(find.textContaining('John 5'), findsOneWidget,
        reason: 'KJV is English source text regardless of UI locale');
    // The By-book aggregate row (bare "约翰福音", no chapter) is still
    // locale-driven and expected here — only the chapter-suffixed
    // recent-row form must be absent.
    expect(find.textContaining('约翰福音 5'), findsNothing);
  });

  testWidgets('an entry with no stored version falls back to the UI locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    // '' is what legacy entries (written before `v` existed) decode to
    // via ReadingHistoryEntry.fromJson's default.
    await pumpWith(
        tester, seededEntry(book: 'John', version: '', locale: 'zh-Hans'));

    expect(find.textContaining('约翰福音 5'), findsOneWidget,
        reason: 'an empty version must degrade to today\'s locale-driven '
            'behaviour, not an empty or English label');
  });

  testWidgets(
      "the By-book aggregate stays locale-driven even when a recent entry "
      "isn't", (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    // A KJV recent entry (English row) alongside a Simplified locale:
    // the By-book row for John must still read in Simplified, because
    // it aggregates across versions and has no single one to follow.
    await pumpWith(
        tester, seededEntry(book: 'John', version: 'kjv', locale: 'zh-Hans'));

    expect(find.textContaining('约翰福音'), findsOneWidget,
        reason: 'the By-book row is an aggregate and must not pick up the '
            "recent entry's version");
  });

  testWidgets('nothing on the page counts consecutive days', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');
    for (final banned in [
      'streak',
      'in a row',
      'consecutive',
      'days running',
      '连续',
      '連續',
      '打卡',
    ]) {
      expect(rendered.contains(banned), isFalse,
          reason: 'the owner excluded 打卡 from this project — "$banned" is '
              'that mechanic under another name');
    }
  });
}

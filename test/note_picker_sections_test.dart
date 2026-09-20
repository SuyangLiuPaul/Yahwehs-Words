// The note editor's book step, in sections — 2026-09-20.
//
// 「words 这个插入经文感觉是不是需要好好设计一下 current book 分新旧约之
// 类的 这样就更加清晰和navigate」. It was one flat grid of every book the
// edition has, in canonical order: 66 identical pills, which is a list
// you read rather than one you navigate.
//
// Now: the book the reader is in (a note is almost always written on
// the verse in front of them), then 旧约, then 新约, each under a
// heading.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/widgets/note_reference_picker_sheet.dart';

List<Verse> _chapter(String book, int chapter, int count) => [
      for (var v = 1; v <= count; v++)
        Verse(book: book, chapter: chapter, verse: v, text: '$book $chapter:$v'),
    ];

Future<MainProvider> _provider() async {
  // Before any setCurrentChapter: the provider persists the reading
  // position, and that needs prefs to exist.
  SharedPreferences.setMockInitialValues({});
  final mp = MainProvider();
  mp.setVerses([
    ..._chapter('创世记', 1, 5),
    ..._chapter('诗篇', 23, 6),
    ..._chapter('使徒行传', 24, 27),
    ..._chapter('约翰福音', 3, 16),
  ]);
  return mp;
}

Future<void> pumpPicker(WidgetTester tester, MainProvider mp) async {
  // Defaults, not `loadSettings()`: that starts the account's cloud
  // pull, whose timer outlives the widget tree and fails the test on a
  // pending-timer assertion before any expectation is read.
  final settings = AppSettings();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NoteReferencePickerSheet(
        locale: 'zh-Hans',
        mainProvider: mp,
        settings: settings,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the two testaments are named', (tester) async {
    await pumpPicker(tester, await _provider());
    expect(find.text('旧约'), findsOneWidget);
    expect(find.text('新约'), findsOneWidget);
  });

  testWidgets('the book the reader is in comes first, once', (tester) async {
    final mp = await _provider();
    mp.setCurrentChapter(book: '使徒行传', chapter: 24);
    await pumpPicker(tester, mp);

    expect(find.text('当前书卷'), findsOneWidget);

    // It appears twice on the page: once at the top, once in its own
    // testament — and the top one is above the 旧约 heading.
    final top = tester.getTopLeft(find.text('当前书卷')).dy;
    final ot = tester.getTopLeft(find.text('旧约')).dy;
    expect(top, lessThan(ot), reason: 'where you are comes first');

    final acts = find.text('使徒行传');
    expect(acts, findsNWidgets(2));
    expect(tester.getTopLeft(acts.first).dy, lessThan(ot));
  });

  testWidgets('with no current book it simply starts at the Old Testament',
      (tester) async {
    await pumpPicker(tester, await _provider());
    expect(find.text('当前书卷'), findsNothing);
    expect(find.text('旧约'), findsOneWidget);
  });

  testWidgets('and tapping a book still goes to its chapters',
      (tester) async {
    final mp = await _provider();
    mp.setCurrentChapter(book: '约翰福音', chapter: 3);
    await pumpPicker(tester, mp);

    await tester.tap(find.text('约翰福音').first);
    await tester.pumpAndSettle();
    // The chapter step: John 3 is the only chapter seeded.
    expect(find.text('3'), findsWidgets);
  });
}

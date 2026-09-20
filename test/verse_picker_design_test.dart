// The verse step is built like the chapter step — 2026-09-20.
//
// The owner, with the two screens side by side: 「chapter design better
// than verse can you improve this page」.
//
// The chapter grid is square tiles on a fixed-column grid, the current
// chapter filled in the primary colour, and a header naming the book
// with a count badge. The verse step was wide pills in a Wrap, with no
// current-verse state at all and `Top` sitting in the same run at
// double width, so the first row never lined up with the rest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/book.dart';
import 'package:yahwehs_words/models/chapter.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/widgets/book_chapter_picker.dart';

MainProvider _provider() {
  final mp = MainProvider();
  final verses = <Verse>[
    for (var c = 1; c <= 6; c++)
      for (var v = 1; v <= (c == 6 ? 34 : 10); v++)
        Verse(book: '马太福音', chapter: c, verse: v, text: 'x'),
  ];
  mp.setVerses(verses);
  mp.setBooks([
    Book(
      title: '马太福音',
      chapters: [
        for (var c = 1; c <= 6; c++)
          Chapter(
              title: c,
              verses: verses.where((v) => v.chapter == c).toList()),
      ],
    ),
  ]);
  mp.setCurrentChapter(book: '马太福音', chapter: 6);
  mp.updateCurrentVerse(
      verse: verses.firstWhere((v) => v.chapter == 6 && v.verse == 9));
  return mp;
}

class _Host extends StatelessWidget {
  const _Host();
  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MainProvider>();
    return BookChapterPicker(
      currentBook: mp.currentBook ?? '',
      currentChapter: mp.currentChapter ?? 1,
      onChapterSelected: (book, chapter, {int? verse}) {},
    );
  }
}

Future<void> _openVerseStep(WidgetTester tester, MainProvider mp) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: Scaffold(body: _Host())),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('马太福音').first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('6').first);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the verse tiles are square, like the chapter tiles',
      (tester) async {
    await _openVerseStep(tester, _provider());

    final grid = find.byType(GridView);
    expect(grid, findsOneWidget, reason: 'a grid, not a Wrap of pills');
    final delegate = (tester.widget<GridView>(grid).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount);
    expect(delegate.childAspectRatio, 1.0,
        reason: 'the pills were much wider than tall');
  });

  testWidgets('the verse the reader is on is filled in, as the current '
      'chapter is', (tester) async {
    final mp = _provider();
    await _openVerseStep(tester, mp);

    // Verse 9 is where the reader is.
    final tile = find.ancestor(
      of: find.text('9'),
      matching: find.byType(Material),
    );
    final scheme = ThemeData().colorScheme;
    final filled = tester
        .widgetList<Material>(tile)
        .where((m) => m.color != null && m.color != scheme.surface);
    expect(filled, isNotEmpty,
        reason: 'the current verse had no state of its own before');
  });

  testWidgets('Top is its own row, not a double-width tile in the grid',
      (tester) async {
    await _openVerseStep(tester, _provider());

    final top = find.byKey(const Key('versePicker.top'));
    expect(top, findsOneWidget);
    // Above the grid, and spanning it.
    final topRect = tester.getRect(top);
    final gridRect = tester.getRect(find.byType(GridView));
    expect(topRect.bottom, lessThanOrEqualTo(gridRect.top + 1));
    expect(topRect.width, greaterThan(gridRect.width / 2));
  });

  testWidgets('the header counts the verses, as the chapter step counts '
      'chapters', (tester) async {
    await _openVerseStep(tester, _provider());
    // 马太福音 6 has 34 verses in this fixture.
    expect(find.textContaining('34'), findsWidgets);
    expect(find.text('马太福音 6'), findsOneWidget);
  });
}

/// The teachings page, and the promises its dataset makes.
///
/// PORTED FROM YAHWEH'S SWORD, 2026-09-21, with the page. Everything down
/// to 'the page says the arrangement is its own' is Sword's test with the
/// package renamed — the dataset is the same file, so the same promises
/// hold or fail together. What follows it is Words' own: the copy has to
/// resolve against THIS app's sermon corpus and plate index, and the home
/// page has to lead to it.
///
/// 2026-09-16. Three of these are about HONESTY rather than about
/// rendering, because that is where this feature can go wrong quietly:
/// a page that silently upgraded a cross-reference into a claim of
/// dependence would look exactly like one that did not.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/jesus_teachings_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/jesus_teachings_service.dart';
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_words/utils/passage_localizer.dart' show localizePassage;
import 'package:yahwehs_words/utils/reference_parser.dart' show parseReference;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JesusTeachingsData data;

  setUpAll(() async {
    data = await JesusTeachingsService.instance.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
  });

  test('every reference the page prints can actually be opened', () {
    // The page turns each of these into a tap that calls
    // `parseReference`. One that does not parse is a dead chip, and
    // there are thousands of them — a spot check would miss it.
    var checked = 0;
    for (final t in data.teachings) {
      for (final raw in [
        for (final r in t.refs) r.label,
        ...t.oldTestament,
        for (final a in t.apostles) a.ref,
      ]) {
        expect(parseReference(raw), isNotNull,
            reason: '${t.id}: "$raw" does not parse, so its chip is dead');
        checked++;
      }
    }
    expect(checked, greaterThan(1000),
        reason: 'only $checked references were checked — the dataset is '
            'not carrying what this test assumes');
  });

  test('a teaching never reaches outside the gospels', () {
    // The defect this caught while the generator was being written:
    // Nave's outline lines carry the PARALLEL references for one
    // teaching, and a merge that took them wholesale gave the parable
    // of the lost sheep a claim on Mark 15 — the crucifixion.
    const gospels = {'Matthew', 'Mark', 'Luke', 'John'};
    for (final t in data.teachings) {
      for (final r in t.refs) {
        expect(gospels, contains(r.book),
            reason: '${t.id} cites ${r.label}, which is not a gospel');
      }
    }
  });

  test('only the apostles\' own claims are marked as the Lord\'s word', () {
    // The whole honesty argument, as an assertion. A cross-reference
    // says two passages are related; it does not say one rests on the
    // other. The only links allowed to carry a claim of dependence are
    // the ones where an apostle says so himself.
    const declared = {
      '1 Corinthians 7:10',
      '1 Corinthians 7:11',
      '1 Corinthians 9:14',
      '1 Corinthians 11:23',
      '1 Corinthians 11:24',
      '1 Corinthians 11:25',
      '1 Thessalonians 4:15',
      'Acts 20:35',
    };
    var marked = 0;
    for (final t in data.teachings) {
      for (final a in t.apostles) {
        if (a.lordsWord == null) continue;
        marked++;
        expect(declared, contains(a.ref.split('-').first.trim()),
            reason: '${t.id}: ${a.ref} is marked as the Lord\'s own word, '
                'and the New Testament does not say that of it');
      }
    }
    expect(marked, greaterThan(0),
        reason: 'nothing is marked, so this test is passing vacuously — '
            'the teachings the apostles cite by name are missing from '
            'the spine');
  });

  test('every entry has a Chinese title', () {
    // 「这些也没用根据语言翻译好」. Nave's outline is English in this
    // dataset, so more than a quarter of the entries showed an English
    // sentence to a Chinese reader. Some take the app's own section
    // heading, which is already trilingual; the rest are translated in
    // the generator and kept literal, because translating a heading is
    // localisation and the passage it names is printed beside it.
    for (final t in data.teachings) {
      expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(t.titleFor('zh-Hans')), isTrue,
          reason: '${t.id} shows "${t.titleFor('zh-Hans')}" in a Chinese UI');
      expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(t.titleFor('zh-Hant')), isTrue,
          reason: '${t.id} has no traditional title');
    }
  });

  test('a plate chip shows a name, not a filename', () {
    // The first build printed `illus_tissot_healing_of_the_lepers_at_
    // capernaum` at the reader — an asset id wearing a chip.
    for (final t in data.teachings) {
      for (final p in t.plates) {
        expect(p.titleFor('zh-Hans'), isNot(p.id));
        expect(p.titleFor('zh-Hans'), isNotEmpty);
      }
    }
  });

  test('parallel passages are one teaching, not three', () {
    // 「有平行经文的也要放在一起」. Nave lists the synoptic parallels of a
    // teaching on one line, so the sower is Mt 13, Mk 4 and Lk 8 — one
    // entry carrying three references rather than three entries.
    final multi = data.teachings
        .where((t) => t.refs.map((r) => r.book).toSet().length > 1)
        .toList();
    expect(multi.length, greaterThan(10),
        reason: 'only ${multi.length} teachings carry parallels');
    final sower = data.teachings.firstWhere((t) => t.refs
        .any((r) => r.book == 'Matthew' && r.chapter == 13 && r.start == 1));
    expect(sower.refs.map((r) => r.book).toSet(),
        containsAll(<String>{'Matthew', 'Mark', 'Luke'}),
        reason: 'the sower lost its parallels: ${sower.label}');
  });

  test('the list is one level deep, and the folding lost nothing', () {
    // 2026-09-16 「类似于登山宝训下面的都放在一起 ... 所以就要非常简单」.
    // The first build was an outline: the Sermon on the Mount, then
    // twenty-one rows indented under it, eighty-seven rows for
    // fifty-odd teachings. It is a list now — so the two things that
    // could go wrong are that a row still hides another row, and that
    // what the folding absorbed stopped being visible anywhere.
    // Not a row count: the parables are each their own row, so the
    // list is longer than it was and that is the point. What has to
    // hold is that no row is hiding another one.

    final mount = data.teachings.firstWhere((t) => t.id.contains('mount'));
    expect(mount.contains.length, greaterThan(10),
        reason: 'the Sermon on the Mount names only ${mount.contains.length} '
            'of the teachings inside it; the Beatitudes alone are eight');
    expect(mount.sermons.length, greaterThan(12),
        reason: 'the parts folded in but their sermons did not come with '
            'them — the twelve-sermon cap has to lift for a row that '
            'stands for twenty-one teachings');

    for (final t in data.teachings) {
      for (final c in t.contains) {
        expect(c.titleFor('zh-Hans'), isNot(t.titleFor('zh-Hans')),
            reason: '${t.id} lists itself among its own parts');
        expect(parseReference(c.ref), isNotNull,
            reason: '${t.id}: "${c.ref}" is a dead chip');
      }
    }
  });

  test('the parables are all there, and each is its own teaching', () {
    // 2026-09-16 「Scholars generally count between 30 and 40 parables
    // told by Jesus in the New Testament 这里却并没有看出来 好像只有15个」.
    //
    // Fifteen was the folding doing it: Matthew 13 is a discourse, so
    // the sower, the tares, the mustard seed, the treasure, the pearl
    // and the net had all disappeared into one row. A parable is not a
    // PART of a teaching the way a sermon on Matthew 5:4 is part of the
    // Sermon on the Mount, and the fold now refuses to put one inside
    // anything else.
    final parables = data.teachings.where((t) => t.kind == 'parable');
    expect(parables.length, inInclusiveRange(30, 50),
        reason: '${parables.length} parables — published lists count '
            'between thirty and forty');

    // The ones every list has, by the passage rather than by the name.
    const mustHave = {
      'Matthew 13:1': 'the sower',
      'Matthew 13:24': 'the weeds',
      'Matthew 13:44': 'the hidden treasure',
      'Matthew 13:45': 'the pearl',
      'Matthew 13:47': 'the net',
      'Matthew 18:23': 'the unmerciful servant',
      'Matthew 20:1': 'the workers in the vineyard',
      'Matthew 25:1': 'the ten virgins',
      'Matthew 25:14': 'the talents',
      'Luke 10:30': 'the good Samaritan',
      'Luke 15:11': 'the prodigal son',
      'Luke 16:19': 'the rich man and Lazarus',
      'Luke 18:9': 'the Pharisee and the tax collector',
    };
    final opens = {
      for (final t in parables)
        for (final r in t.refs) '${r.book} ${r.chapter}:${r.start}'
    };
    for (final entry in mustHave.entries) {
      expect(opens, contains(entry.key),
          reason: 'no parable begins at ${entry.key} — ${entry.value} is '
              'not on the page');
    }

    // And a parable's reference is the parable's, not whatever a
    // sermon on it happened to cover. The weeds came out spanning
    // Matthew 13:24-53, which is most of the chapter.
    final weeds = parables.firstWhere(
        (t) => t.refs.any((r) => r.book == 'Matthew' && r.start == 24));
    final matthew = weeds.refs.firstWhere((r) => r.book == 'Matthew');
    expect(matthew.end, lessThan(45), reason: 'the weeds claim ${weeds.label}');
  });

  test('no title says it is part one of something', () {
    // 2026-09-16 「讲道分类 为什么分上下了」. The sermon corpus is a
    // preached series, so a teaching that took two Sundays is titled
    // 「不要忧虑（上）」 and 「不要忧虑（下）」 — and both sermons land on the
    // same passage and become ONE entry here. The surviving title then
    // told the reader this was part one of something whose part two is
    // nowhere on the page.
    final marker = RegExp(r'[（(]\s*(?:上|中|下|续|續|[一二三四五六七八九十]+|'
        r'Part\s*[0-9IVX]+)\s*[)）]');
    for (final t in data.teachings) {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(marker.hasMatch(t.titleFor(locale)), isFalse,
            reason: '${t.id} is titled "${t.titleFor(locale)}"');
      }
      // And the passage is printed on its own line, so a title that
      // repeats it prints it twice.
      expect(t.titleFor('zh-Hans'), isNot(contains('章')),
          reason: '${t.id} carries its reference in its title');
      // The note under it is the reader's language or nothing. An
      // English sentence under a Chinese title is not a note.
      for (final locale in ['zh-Hans', 'zh-Hant']) {
        if (t.noteFor(locale) case final note?) {
          expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(note), isTrue,
              reason: '${t.id} shows the note "$note" in $locale');
        }
      }
    }
  });

  test('the disclaimer is in the reader\'s language', () {
    // 2026-09-16 「这里面语言也没用翻译好」. This sentence is the page's
    // own statement of what it may claim; in a language the reader did
    // not ask for it is not a disclaimer, it is decoration.
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      expect(data.claimsFor(locale), isNotEmpty);
    }
    expect(
        RegExp(r'[\u4e00-\u9fff]').hasMatch(data.claimsFor('zh-Hans')), isTrue);
  });

  testWidgets('the page says the arrangement is its own', (tester) async {
    // An editorial list that will not admit to being editorial is the
    // thing to avoid here. The claim comes out of the dataset rather
    // than being retyped in the UI, so this also pins that the two
    // cannot drift apart.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const JesusTeachingsPage(),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('jesusTeachingsList')), findsOneWidget);
    expect(find.textContaining('从主领受的'), findsOneWidget,
        reason: 'the preface, which is where the conviction lives');
    expect(find.textContaining('串珠只说明'), findsOneWidget,
        reason: 'the page must state what a cross-reference does and does '
            'not claim, in the language the reader is reading it in');

    // 「类似于比喻可以放在一起」 — the parables in one tap, and still in
    // the order the gospels put them.
    await tester.tap(find.byKey(const ValueKey('teachingKind-parable')));
    await tester.pumpAndSettle();
    final parables = data.teachings.where((t) => t.kind == 'parable');
    // Fewer than the sermon corpus's 34 sermons on parables, and that
    // is the folding working: the two on the sower are one entry, and
    // the ones inside Matthew 13 are inside 天国的比喻.
    expect(parables.length, greaterThan(12),
        reason: 'only ${parables.length} parables were classified');
    expect(find.text(parables.first.titleFor('zh-Hans')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('teachingKind-all')));
    await tester.pumpAndSettle();

    // And a teaching opens, with its references in the reader's own
    // language 「这里面语言也没用翻译好」.
    final first = data.teachings.first;
    await tester.tap(find.byKey(ValueKey('teaching-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text(localizePassage(first.refs.first.label, 'zh-Hans')),
        findsWidgets);
    expect(find.textContaining('马太福音'), findsWidgets,
        reason: 'the chips still print English book names');
  });


  // ── Words' own ─────────────────────────────────────────────────────

  test('every sermon the copy names is in this app\'s own corpus', () {
    // The dataset was built against Sword's sermon index. Words carries
    // a larger one (429 against Sword's 289) and on 2026-09-21 every id
    // resolved — but a sermon chip whose id is missing does nothing when
    // tapped, silently, and the next re-copy from Sword could bring one.
    final index = json.decode(
        File('assets/sermons/index.json').readAsStringSync());
    final ids = <String>{
      for (final s in (index is Map ? index['sermons'] : index) as List)
        '${(s as Map)['id']}'
    };
    expect(ids, isNotEmpty);
    var checked = 0;
    for (final t in data.teachings) {
      for (final s in t.sermons) {
        expect(ids, contains(s.id),
            reason: '${t.id} links sermon ${s.id}, which Words does not '
                'ship — that chip would do nothing');
        checked++;
      }
    }
    expect(checked, greaterThan(100));
  });

  test('every plate the copy names is in this app\'s own map index', () {
    final raw = json.decode(File('assets/maps_index.json').readAsStringSync());
    final ids = <String>{
      for (final m in (raw is Map ? raw['maps'] : raw) as List)
        '${(m as Map)['id']}'
    };
    expect(ids, isNotEmpty);
    var checked = 0;
    for (final t in data.teachings) {
      for (final p in t.plates) {
        expect(ids, contains(p.id),
            reason: '${t.id} links plate ${p.id}, which Words does not '
                'ship — that chip would do nothing');
        checked++;
      }
    }
    expect(checked, greaterThan(100));
  });

  test('the page is on the route table under its own path', () {
    // Three copies of one fact, kept together by
    // `url_routing_stage3_sync_test`; this only pins that the page is
    // among them, which that test cannot know to ask.
    expect(kJesusTeachingsRoute, '/jesus-teachings');
    expect(File('lib/main.dart').readAsStringSync(),
        contains("name: '/jesus-teachings',"));
    expect(File('lib/utils/route_paths.dart').readAsStringSync(),
        contains("'/jesus-teachings',"));
  });

  test('the home page leads to it, inside Featured', () {
    // 2026-09-21, moved the morning after it shipped at the foot of the
    // page: 「耶稣教导放在诗歌下面年代前面 featured那边」 — under Songs,
    // above the chronology chart.
    //
    // A SOURCE-LEVEL guard: the dashboard needs the whole app standing
    // to pump, and what can go wrong quietly here is the wiring and the
    // ORDER, both of which are readable in the source.
    final src = File('lib/pages/dashboard_page.dart').readAsStringSync();
    final featured = src.indexOf('case DashboardSection.featured:');
    final songs = src.indexOf("routeName: '/songs'");
    final card = src.indexOf("ValueKey('home.jesusTeachings')");
    final chronology = src.indexOf("routeName: '/chronology'");
    expect(featured, greaterThan(0));
    expect(card, greaterThan(featured),
        reason: 'the card must live inside the Featured section, so the '
            'reader can reorder and hide it with everything else');
    expect(card, greaterThan(songs), reason: 'it goes under Songs');
    expect(card, lessThan(chronology),
        reason: 'it goes above the chronology chart');
    expect(src, contains('routeName: kJesusTeachingsRoute'));
    // And it is a Featured card, not a one-off: the old foot-of-page
    // widget is gone rather than left behind unused.
    expect(src, isNot(contains('_JesusTeachingsCard')));
  });
}

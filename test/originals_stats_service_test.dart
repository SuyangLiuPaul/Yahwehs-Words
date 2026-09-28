// Round-56 note: `OriginalsStatsService` had zero test references
// despite being the live data source behind every Stats-page tab
// (`OriginalsStatsService.aggregate()` / `.load()`, see
// stats_page.dart:859-860). This file pins its invariants against the
// real `assets/strongs/` bundle rather than hard-coded censuses, since
// those go stale as the concordance/lexicon are re-imported (queue has
// carried-forward counts that drifted: 1,730 → 3,290 → 3,305).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/originals_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OriginalsLemma.glossFor', () {
    const both = OriginalsLemma(
      strongs: 'H1',
      isHebrew: true,
      lemma: 'x',
      translit: 'x',
      glossEn: 'father',
      glossZhHans: '父',
      glossZhHant: '父(繁)',
      count: 1,
      byBook: {},
    );
    const hansOnly = OriginalsLemma(
      strongs: 'H2',
      isHebrew: true,
      lemma: 'x',
      translit: 'x',
      glossEn: 'father',
      glossZhHans: '父',
      glossZhHant: '',
      count: 1,
      byBook: {},
    );
    const enOnly = OriginalsLemma(
      strongs: 'H3',
      isHebrew: true,
      lemma: 'x',
      translit: 'x',
      glossEn: 'father',
      glossZhHans: '',
      glossZhHant: '',
      count: 1,
      byBook: {},
    );

    test('zh-Hant prefers the Traditional gloss', () {
      expect(both.glossFor('zh-Hant'), '父(繁)');
    });

    test('zh-Hant falls through to Simplified when Traditional is empty',
        () {
      expect(hansOnly.glossFor('zh-Hant'), '父');
    });

    test('any zh-prefixed locale without Hant uses Simplified', () {
      expect(both.glossFor('zh-Hans'), '父');
      expect(both.glossFor('zh'), '父');
    });

    test('falls through all the way to English when both Chinese glosses '
        'are empty', () {
      expect(enOnly.glossFor('zh-Hant'), 'father');
    });

    test('non-zh locale uses English regardless of Chinese glosses', () {
      expect(both.glossFor('en'), 'father');
    });
  });

  group('OriginalsStatsService against the real bundle', () {
    setUp(OriginalsStatsService.clearCache);
    tearDown(OriginalsStatsService.clearCache);

    test('clearCache() clears both the lemma list and the aggregate cache',
        () async {
      final firstAggregate = await OriginalsStatsService.aggregate();
      // Same call again must be the identical cached instance.
      final secondAggregate = await OriginalsStatsService.aggregate();
      expect(identical(firstAggregate, secondAggregate), isTrue);

      OriginalsStatsService.clearCache();
      final thirdAggregate = await OriginalsStatsService.aggregate();
      // Reloaded from a cleared cache: a fresh instance, not the
      // stale one. Before this test's companion fix, `clearCache()`
      // only nulled `_cache`, not `_aggregateCache`, so this would
      // have returned the identical stale instance instead.
      expect(identical(firstAggregate, thirdAggregate), isFalse);
      // But the values must still agree — clearing and reloading
      // from the same immutable assets must not change the numbers.
      expect(thirdAggregate.totalWords, firstAggregate.totalWords);
    });

    test('load() sorts strictly by descending count, ties broken by '
        'Strong\'s number', () async {
      final all = await OriginalsStatsService.load();
      expect(all, isNotEmpty);
      for (var i = 1; i < all.length; i++) {
        final prev = all[i - 1];
        final cur = all[i];
        expect(prev.count >= cur.count, isTrue,
            reason: '${prev.strongs}(${prev.count}) should be >= '
                '${cur.strongs}(${cur.count})');
        if (prev.count == cur.count) {
          expect(prev.strongs.compareTo(cur.strongs) <= 0, isTrue,
              reason: 'tie between ${prev.strongs} and ${cur.strongs} '
                  'must break by ascending Strong\'s number');
        }
      }
    });

    test('every lemma with a null lexicon lookup is genuinely dropped — '
        'measured at HEAD: 76 of 13,988 concordance keys, all Greek codes '
        'above the real Strong\'s range (G6000+), 86 of 436,786 total '
        'occurrences (~0.02%). Not a defect: see '
        '"TVM codes sit above H8674/G5624" trap.', () async {
      final concordanceRaw =
          await rootBundle.loadString('assets/strongs/concordance.json');
      final hebrewRaw =
          await rootBundle.loadString('assets/strongs/hebrew.json');
      final greekRaw =
          await rootBundle.loadString('assets/strongs/greek.json');
      final concordance =
          (jsonDecodeMap(concordanceRaw));
      final hebrew = jsonDecodeMap(hebrewRaw);
      final greek = jsonDecodeMap(greekRaw);

      final all = await OriginalsStatsService.load();
      final loadedKeys = all.map((l) => l.strongs).toSet();

      var missingCount = 0;
      var missingOcc = 0;
      for (final entry in concordance.entries) {
        final key = entry.key;
        if (key.startsWith('_')) continue;
        final isHebrew = key.startsWith('H');
        final lex = isHebrew ? hebrew[key] : greek[key];
        if (lex == null) {
          missingCount++;
          final n = (entry.value as Map)['n'];
          missingOcc += (n as num).toInt();
          expect(loadedKeys.contains(key), isFalse,
              reason: '$key has no lexicon row and must not appear in '
                  'load() output');
          expect(key.startsWith('G'), isTrue,
              reason: 'every lexicon-miss key measured at HEAD is Greek');
          final numeric = int.parse(key.substring(1));
          expect(numeric > 5624, isTrue,
              reason: 'every lexicon-miss key measured at HEAD is above '
                  'the real Strong\'s range');
        }
      }
      expect(missingCount, 76);
      expect(missingOcc, 86);
    });

    test('filtered(): H/G split is exhaustive and disjoint, respects '
        'limit', () async {
      final all = await OriginalsStatsService.load();
      final hebrew = await OriginalsStatsService.filtered(language: 'hebrew');
      final greek = await OriginalsStatsService.filtered(language: 'greek');

      expect(hebrew.every((l) => l.isHebrew), isTrue);
      expect(greek.every((l) => !l.isHebrew), isTrue);
      // Exhaustive: every entry in `all` is in exactly one of the two.
      expect(hebrew.length + greek.length, all.length);
      final hebrewStrongs = hebrew.map((l) => l.strongs).toSet();
      final greekStrongs = greek.map((l) => l.strongs).toSet();
      expect(hebrewStrongs.intersection(greekStrongs), isEmpty);

      final limited = await OriginalsStatsService.filtered(limit: 10);
      expect(limited.length, 10);
      expect(limited, all.take(10).toList());

      // limit larger than the list must not pad or crash.
      final overLimit =
          await OriginalsStatsService.filtered(language: 'hebrew', limit: 1 << 30);
      expect(overLimit.length, hebrew.length);
    });

    test('topN() respects n and does not over-take', () async {
      final all = await OriginalsStatsService.load();
      final top5 = await OriginalsStatsService.topN(n: 5);
      expect(top5.length, 5);
      expect(top5, all.take(5).toList());

      final topAll = await OriginalsStatsService.topN(n: 1 << 30);
      expect(topAll.length, all.length);
    });

    test('aggregate(): totals are the sum of their own per-lemma parts '
        '(invariant, not a hard-coded census)', () async {
      final all = await OriginalsStatsService.load();
      final agg = await OriginalsStatsService.aggregate();

      final expectedHebrewTotal = all
          .where((l) => l.isHebrew)
          .fold<int>(0, (sum, l) => sum + l.count);
      final expectedGreekTotal = all
          .where((l) => !l.isHebrew)
          .fold<int>(0, (sum, l) => sum + l.count);
      expect(agg.totalHebrewWords, expectedHebrewTotal);
      expect(agg.totalGreekWords, expectedGreekTotal);
      expect(agg.totalWords, expectedHebrewTotal + expectedGreekTotal);

      final expectedUniqueHebrew = all.where((l) => l.isHebrew).length;
      final expectedUniqueGreek = all.where((l) => !l.isHebrew).length;
      expect(agg.uniqueHebrewLemmas, expectedUniqueHebrew);
      expect(agg.uniqueGreekLemmas, expectedUniqueGreek);
      expect(agg.uniqueLemmas, expectedUniqueHebrew + expectedUniqueGreek);

      final expectedHebrewHapax =
          all.where((l) => l.isHebrew && l.count == 1).length;
      final expectedGreekHapax =
          all.where((l) => !l.isHebrew && l.count == 1).length;
      expect(agg.hebrewHapaxCount, expectedHebrewHapax);
      expect(agg.greekHapaxCount, expectedGreekHapax);
      expect(agg.totalHapax, expectedHebrewHapax + expectedGreekHapax);

      // bookStats totals must reconcile against the same per-lemma
      // byBook counts the totals above were built from.
      final perBookExpected = <String, int>{};
      for (final lemma in all) {
        for (final e in lemma.byBook.entries) {
          perBookExpected[e.key] = (perBookExpected[e.key] ?? 0) + e.value;
        }
      }
      final perBookActual = {
        for (final b in agg.bookStats) b.englishBook: b.totalWords,
      };
      expect(perBookActual, perBookExpected);
    });

    test('bookStats is in canonical Bible order and every englishBook '
        'resolves (none falls on the 999 fallback)', () async {
      const canonicalOrder = [
        'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
        'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
        '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
        'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
        'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
        'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
        'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
        'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
        'Matthew', 'Mark', 'Luke', 'John', 'Acts',
        'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
        'Ephesians', 'Philippians', 'Colossians',
        '1 Thessalonians', '2 Thessalonians',
        '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
        'Hebrews', 'James', '1 Peter', '2 Peter',
        '1 John', '2 John', '3 John', 'Jude', 'Revelation',
      ];
      final agg = await OriginalsStatsService.aggregate();

      var lastIndex = -1;
      for (final b in agg.bookStats) {
        final idx = canonicalOrder.indexOf(b.englishBook);
        expect(idx, greaterThanOrEqualTo(0),
            reason: '${b.englishBook} did not resolve in the canonical '
                'order — it would silently sort to the end (999 '
                'fallback)');
        expect(idx, greaterThan(lastIndex),
            reason: 'bookStats must be in strictly ascending canonical '
                'order');
        lastIndex = idx;
      }

      const otBooks = <String>{
        'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
        'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
        '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
        'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
        'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
        'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
        'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
        'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
      };
      for (final b in agg.bookStats) {
        expect(b.isOt, otBooks.contains(b.englishBook));
      }
    });

    // `rootBundle` is a `CachingAssetBundle` — it keeps its own
    // key→Future<String> cache independent of
    // `OriginalsStatsService._cache`, so the mocked failure below must
    // `evict()` first (or the bundle just replays the real asset it
    // already loaded in an earlier test) and evict again after
    // unmocking (or the bundle would replay its own cached *rejected*
    // future forever, which would mask exactly the recovery this test
    // exists to prove).
    const concordanceKey = 'assets/strongs/concordance.json';

    test('load() does not cache a poisoned asset failure — it retries '
        'and recovers on the next call', () async {
      rootBundle.evict(concordanceKey);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        return null; // asset "not found" — rootBundle.loadString throws
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      });

      final poisoned = await OriginalsStatsService.load();
      expect(poisoned, isEmpty,
          reason: 'a failed asset load must still return the empty-state '
              'list, not throw');

      // Restore real asset loading and call again WITHOUT clearCache().
      // Pre-fix, `_cache = results` sits outside the try, so the empty
      // list from the failed call above would have been cached
      // permanently and this would still be empty.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      rootBundle.evict(concordanceKey);
      final recovered = await OriginalsStatsService.load();
      expect(recovered, isNotEmpty,
          reason: 'load() must retry after a failure instead of being '
              'stuck on the cached empty list from the poisoned call');
    });

    test('aggregate() does not cache a zeroed result from a poisoned '
        'load() — it retries and recovers on the next call', () async {
      rootBundle.evict(concordanceKey);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      });

      final poisoned = await OriginalsStatsService.aggregate();
      expect(poisoned.totalWords, 0);
      expect(poisoned.bookStats, isEmpty);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      rootBundle.evict(concordanceKey);
      final recovered = await OriginalsStatsService.aggregate();
      expect(recovered.totalWords, greaterThan(0),
          reason: 'aggregate() must not be stuck on the zeroed result '
              'cached from the poisoned load() above');
      expect(recovered.bookStats, isNotEmpty);
    });

    test('topInBook is per-book (not global), at most 5, descending by '
        'that book\'s own count', () async {
      final agg = await OriginalsStatsService.aggregate();
      final genesis =
          agg.bookStats.firstWhere((b) => b.englishBook == 'Genesis');
      expect(genesis.topInBook.length, lessThanOrEqualTo(5));
      for (var i = 1; i < genesis.topInBook.length; i++) {
        expect(genesis.topInBook[i - 1].value >= genesis.topInBook[i].value,
            isTrue);
      }

      // Per-book, not global: the book's own top strongs should not
      // generally equal the whole-Bible top (unless a stopword like
      // "the"/kai genuinely dominates every book, which is exactly what
      // this test would fail to catch if topInBook were secretly
      // global — so also check the recorded value equals the raw
      // per-book count from the source lemma, not the lemma's global
      // total).
      final all = await OriginalsStatsService.load();
      for (final entry in genesis.topInBook) {
        final lemma = all.firstWhere((l) => l.strongs == entry.key);
        expect(entry.value, lemma.byBook['Genesis']);
        // A per-book value can never exceed that lemma's own global
        // total.
        expect(entry.value <= lemma.count, isTrue);
      }
    });
  });
}

Map<String, dynamic> jsonDecodeMap(String raw) {
  return (jsonDecode(raw) as Map).cast<String, dynamic>();
}

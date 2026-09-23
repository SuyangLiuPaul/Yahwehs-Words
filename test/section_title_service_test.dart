import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/section_title_map.dart';
import 'package:yahwehs_words/services/section_title_service.dart';

/// `SectionTitleService` itself had zero direct coverage before this file.
/// Three existing tests come close but stop short of it:
///
///   * `english_version_membership_parity_test.dart:65` checks that every
///     `language == 'en'` `BibleVersionInfo` is a key in
///     `sectionTitleSetByVersion` — a version-list guard, not a lookup
///     guard, and it says nothing about Chinese versions or about whether
///     the set id it names actually exists in the asset.
///   * `canon_chapters_test.dart:290` parses `assets/section_titles.json`
///     directly and checks the references are in-canon — an asset guard.
///   * `traditional_ridge_glyph_test.dart:102` pins one glyph class inside
///     the asset — also an asset guard.
///
/// None of the three ever calls `SectionTitleService.headingAt` or
/// `titleAt`, so the load path, the exact-verse lookup, the fallback
/// branch and the soft-fail path were all unexercised. This file drives
/// the service through its public API instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> asset;
  setUpAll(() {
    asset = jsonDecode(File('assets/section_titles.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  setUp(SectionTitleService.clearCache);
  tearDown(SectionTitleService.clearCache);

  group('set ids resolve', () {
    test('every value in sectionTitleSetByVersion is a key under "sets" '
        'in the asset', () {
      final setIds = (asset['sets'] as Map<String, dynamic>).keys.toSet();
      for (final entry in sectionTitleSetByVersion.entries) {
        expect(
          setIds,
          contains(entry.value),
          reason: '"${entry.key}" -> "${entry.value}", but "${entry.value}" '
              'is not a key under "sets" in assets/section_titles.json — '
              'a mistyped or renamed set id would silently leave that '
              'version with no headings at all, and nothing else would '
              'notice',
        );
      }
    });
  });

  group('script parity is not crossed', () {
    test('Traditional versions map to cuv-tr, Simplified twins to cuv', () {
      const traditional = ['cuvs-yhwh-tr', 'biblexg-v2-tr', 'biblexg-v3-tr'];
      const simplified = ['cuvs-yhwh', 'biblexg-v2', 'biblexg-v3'];
      for (final v in traditional) {
        expect(
          sectionTitleSetByVersion[v],
          'cuv-tr',
          reason: '"$v" is a Traditional version and must not be handed '
              'the Simplified "cuv" set',
        );
      }
      for (final v in simplified) {
        expect(
          sectionTitleSetByVersion[v],
          'cuv',
          reason: '"$v" is a Simplified version and must not be handed '
              'the Traditional "cuv-tr" set',
        );
      }
    });
  });

  group('the three sets cover the same verses', () {
    Set<String> keysOf(String setId) {
      final books = (asset['sets'] as Map<String, dynamic>)[setId]
          as Map<String, dynamic>;
      final out = <String>{};
      books.forEach((book, chapters) {
        (chapters as Map<String, dynamic>).forEach((chapter, entries) {
          for (final e in entries as List) {
            out.add('$book/$chapter/${(e as Map)['verse']}');
          }
        });
      });
      return out;
    }

    test('cuv, cuv-tr and english-classic hold an identical key set', () {
      final cuv = keysOf('cuv');
      final cuvTr = keysOf('cuv-tr');
      final englishClassic = keysOf('english-classic');
      expect(cuv.difference(cuvTr), isEmpty,
          reason: 'cuv has a heading cuv-tr does not — a Traditional '
              'reader would silently lose it');
      expect(cuvTr.difference(cuv), isEmpty,
          reason: 'cuv-tr has a heading cuv does not — a Simplified '
              'reader would silently lose it');
      expect(cuv.difference(englishClassic), isEmpty,
          reason: 'cuv has a heading english-classic does not — an '
              'English reader would silently lose it');
      expect(englishClassic.difference(cuv), isEmpty,
          reason: 'english-classic has a heading cuv does not — a '
              'Chinese reader would silently lose it');
    });
  });

  group('headingAt / titleAt', () {
    test('returns null before ensureLoaded()', () {
      expect(
        SectionTitleService.headingAt(
          version: 'kjv',
          englishBook: 'Genesis',
          chapter: 1,
          verse: 1,
        ),
        isNull,
      );
    });

    test('exact-verse only — a heading at verse 1 does not answer '
        'a lookup for verse 2', () async {
      await SectionTitleService.ensureLoaded();
      final v1 = SectionTitleService.headingAt(
        version: 'cuvs-yhwh',
        englishBook: 'Genesis',
        chapter: 1,
        verse: 1,
      );
      expect(v1, isNotNull);
      expect(v1!.title, '起初创造天地');

      final v2 = SectionTitleService.headingAt(
        version: 'cuvs-yhwh',
        englishBook: 'Genesis',
        chapter: 1,
        verse: 2,
      );
      expect(v2, isNull);
    });

    test('returns null for a version with no mapping', () async {
      await SectionTitleService.ensureLoaded();
      expect(
        SectionTitleService.headingAt(
          version: 'not-a-real-version',
          englishBook: 'Genesis',
          chapter: 1,
          verse: 1,
        ),
        isNull,
      );
    });

    test('titleAt returns exactly headingAt(...)!.title', () async {
      await SectionTitleService.ensureLoaded();
      final heading = SectionTitleService.headingAt(
        version: 'kjv',
        englishBook: 'Genesis',
        chapter: 1,
        verse: 1,
      );
      final title = SectionTitleService.titleAt(
        version: 'kjv',
        englishBook: 'Genesis',
        chapter: 1,
        verse: 1,
      );
      expect(heading, isNotNull);
      expect(title, heading!.title);
    });
  });

  group('soft-fail', () {
    // rootBundle caches string loads by key, so evict before and after or
    // the mock (or the real content) is silently bypassed by the cache —
    // same trap documented in illustration_attribution_new_grouping_test.
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        final key = utf8.decode(message!.buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes));
        if (key != 'assets/section_titles.json') return null;
        final bytes = Uint8List.fromList(utf8.encode('not valid json'));
        return ByteData.view(bytes.buffer);
      });
      rootBundle.evict('assets/section_titles.json');
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
      rootBundle.evict('assets/section_titles.json');
    });

    test('a broken asset lands on const {} and lookups return null, '
        'not throw', () async {
      await SectionTitleService.ensureLoaded();
      expect(
        SectionTitleService.headingAt(
          version: 'kjv',
          englishBook: 'Genesis',
          chapter: 1,
          verse: 1,
        ),
        isNull,
      );
    });
  });

  group('ensureLoaded()', () {
    test('is idempotent — a second call after a completed load does not '
        'touch the asset channel again', () async {
      await SectionTitleService.ensureLoaded();
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        callCount++;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null));

      await SectionTitleService.ensureLoaded();
      expect(callCount, 0,
          reason: 'ensureLoaded() re-read the asset after _cache was '
              'already populated');
    });
  });
}

// The add-on pipeline end to end, through the REAL catalog and the REAL
// FetchVerses: import a fixture, see it in the picker's list, read it through
// MainProvider, switch it off, take it away, restart, and fail to store.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/constants/bible_versions.dart';
import 'package:yahwehs_words/constants/text_patterns.dart';
import 'package:yahwehs_words/constants/book_name_mapping.dart';
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/addons/addon_import_service.dart';
import 'package:yahwehs_words/services/addons/addon_registry.dart';
import 'package:yahwehs_words/services/addons/addon_store.dart';
import 'package:yahwehs_words/services/fetch_books.dart';
import 'package:yahwehs_words/services/fetch_verses.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';

Uint8List _fx(String name) =>
    Uint8List.fromList(File('test/fixtures/addons/$name').readAsBytesSync());

Future<AddonImportResult> _import(String file, String label,
    {bool attested = true}) async {
  final bytes = _fx(file);
  final parsed = await AddonImportService.analyse(bytes, file);
  return AddonImportService.commit(
    parsed: parsed,
    sourceBytes: bytes,
    fileName: file,
    label: label,
    attested: attested,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAddonBackend backend;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = InMemoryAddonBackend();
    AddonStore.backend = backend;
    AddonRegistry.resetForTest();
  });
  tearDown(() {
    AddonStore.backend = null;
    AddonRegistry.resetForTest();
  });

  test('importing makes an edition: in the catalog, last, with its own script', () async {
    final before = availableVersions.length;
    final r = await _import('mybible_min.SQLite3', 'My Test Bible');
    expect(r.ok, isTrue, reason: '${r.problem}');
    expect(r.entry!.id, 'user-my-test-bible');

    expect(availableVersions.length, before + 1);
    expect(availableVersions.last.value, 'user-my-test-bible',
        reason: 'unvetted text sorts after every vetted edition');
    expect(versionInfoFor('user-my-test-bible')!.menuLabel, 'My Test Bible');
    expect(bibleVersionLanguage('user-my-test-bible'), 'en');
    expect(scriptForVersion('user-my-test-bible'), 'en',
        reason: 'an English import must not render 創世記 beside English text');
    expect(shortBibleVersionLabel('user-my-test-bible'), 'My Te…');
    expect(isImportedVersion('user-my-test-bible'), isTrue);
    expect(isImportedVersion('kjv'), isFalse);
    expect(bibleVersions.any((v) => isImportedVersion(v.value)), isFalse,
        reason: 'no bundled code may ever take the imported prefix');
  });

  test('an import is read through the real pipeline, books and all', () async {
    await _import('mybible_min.SQLite3', 'My Test Bible');
    final mp = MainProvider()..setVersion('user-my-test-bible');
    expect(mp.currentVersion, 'user-my-test-bible',
        reason: 'resolvableVersion must accept an enabled import');
    await FetchVerses.execute(mainProvider: mp);
    expect(mp.verses.length, 8);
    await FetchBooks.execute(mainProvider: mp);
    expect(mp.versesInChapter('Genesis', 1).map((v) => v.verse), [1, 2, 3, 4]);
    expect(mp.versesInChapter('John', 3).length, 2);
    expect(mp.chapterList.map((c) => '${c.book} ${c.chapter}').toList(),
        ['Genesis 1', 'Genesis 2', 'John 3', 'Revelation 22']);
    expect(mp.versesInChapter('Genesis', 1)[1].text, contains('[without form]'));
  });

  test('a Chinese module gets Chinese book names and the right tab', () async {
    final r = await _import('mysword_zh.bbl.mybible', '中文测试');
    expect(r.ok, isTrue, reason: '${r.problem}');
    final id = r.entry!.id;
    expect(id, startsWith('user-text-'), reason: 'a non-ASCII name gets a stable hash code');
    expect(scriptForVersion(id), 'zh-Hans');
    expect(bibleVersionLanguage(id), 'zh-Hans');
    final mp = MainProvider()..setVersion(id);
    await FetchVerses.execute(mainProvider: mp);
    expect(mp.verses.first.book, '创世记');
    expect(mp.verses.first.text, '起初神创造天地。');
  });

  test('turning it off removes it from every resolution path', () async {
    await _import('mybible_min.SQLite3', 'My Test Bible');
    expect(await AddonRegistry.setEnabled('user-my-test-bible', false), isTrue);
    expect(versionInfoFor('user-my-test-bible'), isNull);
    expect(availableVersions.any((v) => v.value == 'user-my-test-bible'), isFalse);
    expect(resolvableVersion('user-my-test-bible'), isNot('user-my-test-bible'));
    expect(bibleVersionLanguage('user-my-test-bible'), 'en',
        reason: 'an unknown import is never guessed to be Chinese');
    // Its text is still on the device: turning it back on restores it.
    expect(backend.payloads, contains('user-my-test-bible'));
    expect(await AddonRegistry.setEnabled('user-my-test-bible', true), isTrue);
    expect(versionInfoFor('user-my-test-bible'), isNotNull);
  });

  test('removing it deletes the text and the catalog entry', () async {
    await _import('mybible_min.SQLite3', 'My Test Bible');
    await AddonRegistry.forget('user-my-test-bible');
    expect(AddonRegistry.all, isEmpty);
    expect(backend.payloads, isEmpty);
    expect(versionInfoFor('user-my-test-bible'), isNull);
  });

  test('it survives a restart: only the manifest is read to list it', () async {
    await _import('mybible_min.SQLite3', 'My Test Bible');
    AddonRegistry.resetForTest();
    expect(availableVersions.any((v) => isImportedVersion(v.value)), isFalse);
    await AddonRegistry.restore();
    expect(AddonRegistry.all.single.label, 'My Test Bible');
    expect(versionInfoFor('user-my-test-bible'), isNotNull);
    final mp = MainProvider()..setVersion('user-my-test-bible');
    await FetchVerses.execute(mainProvider: mp);
    expect(mp.verses.length, 8);
  });

  test('a store that refuses leaves NOTHING behind and says so', () async {
    backend.failWrites = true;
    final r = await _import('mybible_min.SQLite3', 'My Test Bible');
    expect(r.outcome, ImportOutcome.couldNotStore);
    expect(AddonRegistry.all, isEmpty);
    expect(backend.payloads, isEmpty);
    expect(versionInfoFor('user-my-test-bible'), isNull);
  });

  test('the manifest failing AFTER the payload rolls the payload back', () async {
    // Payload write succeeds, manifest write fails.
    final flaky = _FailManifestBackend();
    AddonStore.backend = flaky;
    final r = await _import('mybible_min.SQLite3', 'My Test Bible');
    expect(r.outcome, ImportOutcome.couldNotStore);
    expect(flaky.inner.payloads, isEmpty, reason: 'no orphan payload');
    expect(AddonRegistry.all, isEmpty);
  });

  test('an unreadable manifest is an empty one, and the app still boots', () async {
    await _import('mybible_min.SQLite3', 'My Test Bible');
    AddonStore.backend = _BrokenBackend();
    AddonRegistry.resetForTest();
    await AddonRegistry.restore();
    expect(AddonRegistry.all, isEmpty);
  });

  test('the licence confirmation is not optional', () async {
    final r = await _import('mybible_min.SQLite3', 'My Test Bible', attested: false);
    expect(r.outcome, ImportOutcome.rejected);
    expect(r.problem, ImportProblem.licenceNotAttested);
    expect(AddonRegistry.all, isEmpty);
  });

  test('names: empty and taken are refused; a bundled code cannot be shadowed', () async {
    expect((await _import('mybible_min.SQLite3', '   ')).problem, ImportProblem.nameEmpty);
    expect((await _import('mybible_min.SQLite3', 'KJV')).ok, isTrue);
    // "KJV" became user-kjv — NOT kjv.
    expect(AddonRegistry.byId('user-kjv'), isNotNull);
    expect(versionInfoFor('kjv')!.value, 'kjv');
    expect(versionInfoFor('kjv')!.menuLabel, isNot('KJV'),
        reason: 'the bundled KJV keeps its own row');
    expect((await _import('mybible_min.SQLite3', 'kjv')).problem, ImportProblem.nameTaken);
  });

  test('what leaves the device never carries an import\'s code', () async {
    await _import('mybible_min.SQLite3', 'ESV from church');
    expect(syncSafeVersion('user-esv-from-church'), 'kjv');
    expect(syncSafeVersion('kjv'), 'kjv');
    expect(syncSafeVersion('cuvs-yhwh'), 'cuvs-yhwh');
    final zh = await _import('mysword_zh.bbl.mybible', '中文测试');
    expect(syncSafeVersion(zh.entry!.id), 'cuvs-yhwh');
  });

  test('a single-Testament import names a same-language fallback', () async {
    final bytes = _fx('theword_nt.nt');
    final parsed = await AddonImportService.analyse(bytes, 'theword_nt.nt');
    final r = await AddonImportService.commit(
        parsed: parsed, sourceBytes: bytes, fileName: 'x.nt', label: 'NT Only', attested: true);
    expect(r.ok, isTrue);
    expect(bibleVersionFullCanonFallback(r.entry!.id), 'bsb-yhwh');
    expect(AddonRegistry.byId(r.entry!.id)!.coversOldTestament, isFalse);
  });

  test('a legacy record (written before the manifest) is carried over', () async {
    backend.payloads['user-old-one'] = jsonEncode([
      {'book': 'Genesis', 'chapter': '1', 'verse': '1', 'text': 'In the beginning.'},
      {'book': 'Genesis', 'chapter': '1', 'verse': '2', 'text': 'And the earth.'},
    ]);
    backend.legacy['user-old-one'] = (label: 'Old One', script: 'en');
    await AddonRegistry.restore();
    final e = AddonRegistry.byId('user-old-one')!;
    expect(e.legacy, isTrue);
    expect(e.verseCount, 2);
    expect(e.label, 'Old One');
    // And it was written to the manifest, so this happens once.
    expect((await backend.readManifest()).entries.map((x) => x.id), ['user-old-one']);
  });

  test('an imported text is shown and copied exactly as the file has it', () {
    // The app rewrites the LORD / 耶和华 for its own editions at render time;
    // an imported edition's text is not ours to amend.
    expect(isVerbatimEdition('user-my-bible'), isTrue);
    expect(isVerbatimEdition('kjv'), isFalse);
    expect(isVerbatimEdition(null), isFalse);
    const raw = 'And the LORD said to 耶和华, [the LORD]<note: LORD>.';
    expect(sanitizeForCopy(raw), contains('Yahweh'));
    expect(sanitizeForCopy(raw, verbatim: true), 'And the LORD said to 耶和华, [the LORD].');
    expect(sanitizeVerseText('神对耶和华说', verbatim: true), '神对耶和华说');
    expect(sanitizeVerseText('神对耶和华说'), '神对雅伟说');
    expect(displayCleanup('the LORD', verbatim: true), 'the LORD');
    expect(displayCleanup('the LORD'), 'Yahweh');
    expect(sanitizeForProjection('the LORD', verbatim: true), 'the LORD');
    expect(sanitizeForProjection('the LORD'), 'Yahweh');
  });

  test('AddonEntry.tryFromJson and the manifest never throw', () {
    for (final bad in <Object?>[null, 7, 'x', <String, Object?>{}, {'id': 'kjv'},
        {'id': 'user-a', 'label': '', 'script': 'en'},
        {'id': 'user-a', 'label': 'A', 'script': 'klingon'},
        {'id': 'user-a', 'label': 'A', 'script': 'en', 'schemaVersion': 99},
        {'id': 'user-${'x' * 100}', 'label': 'A', 'script': 'en'}]) {
      expect(AddonEntry.tryFromJson(bad), isNull, reason: '$bad');
    }
    final odd = AddonEntry.tryFromJson(
        {'id': 'user-a', 'label': 'A', 'script': 'en', 'books': 'nope', 'verseCount': 'x'})!;
    expect(odd.books, isEmpty);
    expect(odd.verseCount, 0);
    for (final bad in <Object?>[null, 3, {'entries': 5}, {'entries': [1, 2, null]}]) {
      expect(AddonManifest.fromJson(bad).entries, isEmpty);
    }
    // Duplicate ids keep the first.
    final m = AddonManifest.fromJson({
      'entries': [
        {'id': 'user-a', 'label': 'A', 'script': 'en'},
        {'id': 'user-a', 'label': 'B', 'script': 'en'},
      ]
    });
    expect(m.entries.single.label, 'A');
  });
}

class _FailManifestBackend extends InMemoryAddonBackend {
  InMemoryAddonBackend get inner => this;
  @override
  Future<bool> writeManifest(AddonManifest manifest) async => false;
}

class _BrokenBackend extends InMemoryAddonBackend {
  @override
  Future<AddonManifest> readManifest() async => throw StateError('boom');
}

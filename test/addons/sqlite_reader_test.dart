// The SQLite reader, against SQLite itself.
//
// Every fixture under test/fixtures/addons was written by Python's `sqlite3`
// (tools/make_addon_fixtures.py), and its `.expected.json` is what Python's
// `SELECT *` returned — an independent implementation of the format. The
// reader must return exactly those rows, in exactly that order.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/sqlite_reader.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/addons/$name').readAsBytesSync();

Map<String, dynamic> _expected(String name) =>
    json.decode(File('test/fixtures/addons/$name').readAsStringSync())
        as Map<String, dynamic>;

List<List<Object?>> _rows(SqliteFile db, String table) {
  final out = <List<Object?>>[];
  db.scan(db.table(table)!, (_, r) => out.add(r));
  return out;
}

void main() {
  const oracle = <String, String>{
    'mybible_min.SQLite3': 'mybible_min.expected.json',
    'mybible_books_all.SQLite3': 'mybible_books_all.expected.json',
    'mybible_deep_tree.SQLite3': 'mybible_deep_tree.expected.json',
    'mybible_overflow.SQLite3': 'mybible_overflow.expected.json',
    'mybible_bigpage.SQLite3': 'mybible_bigpage.expected.json',
    'mybible_russian.SQLite3': 'mybible_russian.expected.json',
    'mysword_bible.bbl.mybible': 'mysword_bible.expected.json',
  };

  group('rows match what SQLite itself returned', () {
    oracle.forEach((file, expectedFile) {
      test(file, () {
        final db = SqliteFile.open(_fixture(file));
        final expected = _expected(expectedFile);
        for (final entry in expected.entries) {
          final got = _rows(db, entry.key);
          final want = (entry.value as List)
              .map((r) => (r as List).cast<Object?>())
              .toList();
          expect(got.length, want.length, reason: '${entry.key} row count');
          for (var i = 0; i < want.length; i++) {
            expect(got[i], want[i], reason: '${entry.key} row $i');
          }
        }
      });
    });
  });

  group('the fixtures really exercise the hard cases', () {
    test('a multi-level b-tree', () {
      final db = SqliteFile.open(_fixture('mybible_deep_tree.SQLite3'));
      expect(db.pageSize, 512);
      _rows(db, 'verses');
      expect(db.lastScanDepth, greaterThanOrEqualTo(3),
          reason: 'interior pages were never walked');
    });

    test('overflow chains', () {
      final db = SqliteFile.open(_fixture('mybible_overflow.SQLite3'));
      _rows(db, 'verses');
      expect(db.lastScanOverflowPages, greaterThan(20));
    });

    test('a 65536-byte page, stored in the header as 1', () {
      final db = SqliteFile.open(_fixture('mybible_bigpage.SQLite3'));
      expect(db.pageSize, 65536);
      final rows = _rows(db, 'verses');
      expect((rows[1][3] as String).length, 70000);
    });

    test('multi-byte text is decoded, not byte-counted', () {
      final db = SqliteFile.open(_fixture('mybible_overflow.SQLite3'));
      final rows = _rows(db, 'verses');
      final last = rows.last[3] as String;
      expect(last.startsWith('创世记'), isTrue);
      expect(last.length, 3 * 700);
    });
  });

  group('the schema', () {
    test('tables and columns are read from sqlite_master', () {
      final db = SqliteFile.open(_fixture('mybible_books_all.SQLite3'));
      final names = db.tables.map((t) => t.name).toSet();
      expect(names, containsAll(['info', 'books_all', 'verses', 'stories', 'introductions']));
      expect(db.table('verses')!.columns,
          ['book_number', 'chapter', 'verse', 'text']);
      expect(db.table('VERSES'), isNotNull, reason: 'case-insensitive');
      expect(db.table('nope'), isNull);
    });

    test('MySword columns keep their declared names', () {
      final db = SqliteFile.open(_fixture('mysword_bible.bbl.mybible'));
      expect(db.table('Bible')!.columns, ['Book', 'Chapter', 'Verse', 'Scripture']);
      expect(db.table('Details')!.columnIndex('encryption'), greaterThan(0));
    });
  });

  group('refusals', () {
    test('not a SQLite file', () {
      expect(() => SqliteFile.open(Uint8List.fromList(List.filled(300, 7))),
          throwsA(isA<NotSqliteException>()));
      expect(() => SqliteFile.open(Uint8List(10)),
          throwsA(isA<NotSqliteException>()));
      expect(() => SqliteFile.open(Uint8List.fromList(utf8.encode('{"a":1}' * 40))),
          throwsA(isA<NotSqliteException>()));
    });

    test('too large', () {
      final big = Uint8List(SqliteLimits.maxFileBytes + 1);
      expect(() => SqliteFile.open(big), throwsA(isA<SqliteTooLargeException>()));
    });

    test('UTF-16 database', () {
      final b = Uint8List.fromList(_fixture('mybible_min.SQLite3'));
      ByteData.sublistView(b).setUint32(56, 2);
      expect(() => SqliteFile.open(b), throwsA(isA<UnsupportedSqliteException>()));
    });

    test('reserved space per page', () {
      final b = Uint8List.fromList(_fixture('mybible_min.SQLite3'));
      b[20] = 12;
      expect(() => SqliteFile.open(b), throwsA(isA<UnsupportedSqliteException>()));
    });

    test('an impossible page size', () {
      final b = Uint8List.fromList(_fixture('mybible_min.SQLite3'));
      ByteData.sublistView(b).setUint16(16, 1000);
      expect(() => SqliteFile.open(b), throwsA(isA<CorruptSqliteException>()));
    });
  });

  test('scanAsync gives the same rows and honours cancellation', () async {
    final db = SqliteFile.open(_fixture('mybible_deep_tree.SQLite3'));
    final t = db.table('verses')!;
    final sync = _rows(db, 'verses');
    final async = <List<Object?>>[];
    await db.scanAsync(t, (_, r) => async.add(r), yieldEvery: 100);
    expect(async, sync);

    var n = 0;
    await expectLater(
      db.scanAsync(t, (_, __) => n++, yieldEvery: 100, cancelled: () => n >= 300),
      throwsA(isA<SqliteCancelledException>()),
    );
    expect(n, lessThan(sync.length));
  });
}

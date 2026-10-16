// A module is a file somebody downloaded from a forum. Whatever is in it,
// the reader must either read it or refuse it with a SqliteException — in
// well under two seconds, without hanging, without running out of memory,
// and without ever throwing a RangeError at somebody who picked a file.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/addons/sqlite_reader.dart';

Uint8List _fixture(String name) =>
    Uint8List.fromList(File('test/fixtures/addons/$name').readAsBytesSync());

/// Open [b] and read every table. Returns normally or throws a
/// [SqliteException]; anything else fails the test by propagating.
void _readEverything(Uint8List b) {
  final sw = Stopwatch()..start();
  try {
    final db = SqliteFile.open(b);
    for (final t in db.tables) {
      if (t.withoutRowId) continue;
      db.scan(t, (_, __) {});
    }
  } on SqliteException {
    // a clean refusal is the other acceptable outcome
  }
  expect(sw.elapsedMilliseconds, lessThan(2000), reason: 'took too long');
}

/// Like [_readEverything] but lets the refusal through, for tests that
/// must see one.
void _readAllStrict(Uint8List b) {
  final db = SqliteFile.open(b);
  for (final t in db.tables) {
    db.scan(t, (_, __) {});
  }
}

int _pageType(Uint8List b, int page, int pageSize) =>
    b[(page - 1) * pageSize + (page == 1 ? 100 : 0)];

/// Pages OTHER than page 1 (whose b-tree header sits after the 100-byte
/// file header) whose first byte is [type].
List<int> _pagesOfType(Uint8List b, int pageSize, int type) => [
      for (var p = 2; p <= b.length ~/ pageSize; p++)
        if (_pageType(b, p, pageSize) == type) p
    ];

void main() {
  const tree = 'mybible_deep_tree.SQLite3';
  const overflow = 'mybible_overflow.SQLite3';

  test('truncated at every 97th byte of two real files', () {
    for (final name in [tree, overflow, 'mysword_bible.bbl.mybible']) {
      final full = _fixture(name);
      for (var cut = 0; cut < full.length; cut += 97) {
        _readEverything(Uint8List.sublistView(full, 0, cut));
      }
    }
  });

  test('an interior page whose child is itself', () {
    final b = _fixture(tree);
    final interior = _pagesOfType(b, 512, 0x05);
    expect(interior, isNotEmpty);
    final p = interior.first;
    final base = (p - 1) * 512;
    // First cell pointer -> its 4-byte left child.
    final ptr = ByteData.sublistView(b).getUint16(base + 12);
    ByteData.sublistView(b).setUint32(base + ptr, p);
    expect(() {
      final db = SqliteFile.open(b);
      db.scan(db.table('verses')!, (_, __) {});
    }, throwsA(isA<CorruptSqliteException>()));
  });

  test('a cycle through three pages', () {
    final b = _fixture(tree);
    final interior = _pagesOfType(b, 512, 0x05);
    expect(interior.length, greaterThanOrEqualTo(3));
    final bd = ByteData.sublistView(b);
    void point(int from, int to) {
      final base = (from - 1) * 512;
      bd.setUint32(base + bd.getUint16(base + 12), to);
    }

    point(interior[0], interior[1]);
    point(interior[1], interior[2]);
    point(interior[2], interior[0]);
    expect(() {
      final db = SqliteFile.open(b);
      db.scan(db.table('verses')!, (_, __) {});
    }, throwsA(isA<SqliteException>()));
  });

  test('a child page past the end of the file', () {
    final b = _fixture(tree);
    final p = _pagesOfType(b, 512, 0x05).first;
    ByteData.sublistView(b).setUint32((p - 1) * 512 + 8, 999999);
    _readEverything(b);
    expect(() {
      final db = SqliteFile.open(b);
      db.scan(db.table('verses')!, (_, __) {});
    }, throwsA(isA<CorruptSqliteException>()));
  });

  test('a header that claims far more pages than the file has still reads', () {
    final b = _fixture(tree);
    ByteData.sublistView(b).setUint32(28, 1000000);
    final db = SqliteFile.open(b);
    var n = 0;
    db.scan(db.table('verses')!, (_, __) => n++);
    expect(n, greaterThan(2000));
  });

  test('a cell pointer past the end of its page', () {
    final b = _fixture(tree);
    final leaf = _pagesOfType(b, 512, 0x0d).first;
    ByteData.sublistView(b).setUint16((leaf - 1) * 512 + 8, 0xFFFF);
    _readEverything(b);
  });

  test('a payload length that is nine 0xFF bytes of varint', () {
    final b = _fixture(tree);
    final leaf = _pagesOfType(b, 512, 0x0d).first;
    final base = (leaf - 1) * 512;
    final ptr = ByteData.sublistView(b).getUint16(base + 8);
    for (var i = 0; i < 9; i++) {
      b[base + ptr + i] = 0xFF;
    }
    _readEverything(b);
    expect(() => _readAllStrict(b), throwsA(isA<SqliteException>()));
  });

  test('a record header longer than its record', () {
    final b = _fixture(tree);
    final leaf = _pagesOfType(b, 512, 0x0d).first;
    final base = (leaf - 1) * 512;
    final ptr = ByteData.sublistView(b).getUint16(base + 8);
    // payloadLen varint (1 byte), rowid varint (1-2 bytes), then header len.
    var pos = base + ptr;
    while (b[pos] >= 0x80) {
      pos++;
    }
    pos++; // payload length
    while (b[pos] >= 0x80) {
      pos++;
    }
    pos++; // rowid
    b[pos] = 0x7F; // header length 127: longer than the cell
    _readEverything(b);
  });

  test('a self-pointing overflow page', () {
    final b = _fixture(overflow);
    // Overflow pages start with a 4-byte next pointer, so their first byte
    // (the "page type") is 0x00 for any chain shorter than 16M pages.
    final over = _pagesOfType(b, 512, 0x00);
    expect(over, isNotEmpty);
    for (final p in over) {
      ByteData.sublistView(b).setUint32((p - 1) * 512, p);
    }
    _readEverything(b);
    expect(() {
      final db = SqliteFile.open(b);
      db.scan(db.table('verses')!, (_, __) {});
    }, throwsA(isA<CorruptSqliteException>()));
  });

  test('ten thousand zero bytes', () {
    expect(() => SqliteFile.open(Uint8List(10000)),
        throwsA(isA<NotSqliteException>()));
  });

  test('a real header followed by random bytes', () {
    final real = _fixture(tree);
    final rng = Random(7);
    for (var i = 0; i < 20; i++) {
      final b = Uint8List.fromList(real);
      for (var j = 100; j < b.length; j++) {
        b[j] = rng.nextInt(256);
      }
      _readEverything(b);
    }
  });

  test('300 single-byte corruptions of a real file', () {
    final real = _fixture(tree);
    final rng = Random(20261017);
    for (var i = 0; i < 300; i++) {
      final b = Uint8List.fromList(real);
      b[rng.nextInt(b.length)] = rng.nextInt(256);
      _readEverything(b);
    }
  });

  test('300 single-byte corruptions of an overflow file', () {
    final real = _fixture(overflow);
    final rng = Random(99);
    for (var i = 0; i < 300; i++) {
      final b = Uint8List.fromList(real);
      b[rng.nextInt(b.length)] = rng.nextInt(256);
      _readEverything(b);
    }
  });

  test('a file of exactly one page and nothing else', () {
    final real = _fixture('mybible_min.SQLite3');
    _readEverything(Uint8List.sublistView(real, 0, 4096));
  });
}

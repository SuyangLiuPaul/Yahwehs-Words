/// A read-only reader for the SQLite file format — enough of it to read
/// the module files other people's Bible apps write (MyBible.zone,
/// MySword), on every platform this app runs on, with no native library.
///
/// ## Why this exists instead of a package
///
/// `sqflite` has no web, Windows or Linux build. `sqlite3` needs a native
/// binary or a WebAssembly file served beside the app on each of five
/// platforms. And the input is a file somebody downloaded from a forum:
/// reading it with a C library is the riskier choice, not the safer one.
/// A reader written against the documented file format
/// (https://www.sqlite.org/fileformat2.html), in a memory-safe language,
/// with every loop bounded, behaves identically everywhere and cannot be
/// made to read outside the bytes it was handed.
///
/// ## What it reads, and — deliberately — what it does not
///
/// It scans ordinary tables (rowid tables: the b-tree of leaf and interior
/// table pages, with overflow chains). That is all a module needs: nobody
/// looks a verse up by key, we read every row once and sort them into
/// our own shape. So there is no index traversal, no collation, no
/// freelist, no WAL, no SQL.
///
/// Refused, with a named error rather than half-supported:
///   * a file whose header is not SQLite's (including SQLCipher-encrypted
///     files, whose first page is random bytes);
///   * `WITHOUT ROWID` tables;
///   * UTF-16 databases (header text encoding 2 or 3);
///   * non-zero reserved space per page.
///
/// ## Untrusted input
///
/// Every file is hostile until proven otherwise:
///   * no recursion — the b-tree walk uses an explicit stack;
///   * every page is visited at most once (cycles, shared pages and
///     overflow loops all surface as [CorruptSqliteException]);
///   * every page number, cell pointer, varint and declared length is
///     checked against the bytes actually present before it is used;
///   * everything that could grow is capped (see [SqliteLimits]);
///   * long scans yield to the event loop and poll for cancellation.
library;

import 'dart:convert';
import 'dart:typed_data';

/// The ceilings. One place, one set of numbers, all enforced.
class SqliteLimits {
  SqliteLimits._();

  /// Largest file accepted. The biggest Bible this app ships is ~9 MB;
  /// 64 MB admits any real module and refuses a disk image.
  static const int maxFileBytes = 64 * 1024 * 1024;

  /// Rows read from one table. A whole Bible with the deuterocanon is
  /// under 40,000 verses.
  static const int maxRowsPerTable = 250000;

  /// One cell's payload. A verse is under 2 KB.
  static const int maxCellBytes = 4 * 1024 * 1024;

  /// Decoded text and blob bytes handed out across one scan.
  static const int maxTotalBytes = 48 * 1024 * 1024;
}

/// Base of every failure this reader reports. Carries a stable [code] the
/// UI maps to a sentence, so the reader of the app is never shown
/// "RangeError".
abstract class SqliteException implements Exception {
  const SqliteException(this.code, this.message);

  /// Stable machine-readable reason: `notSqlite`, `unsupported`,
  /// `corrupt`, `tooLarge`, `cancelled`.
  final String code;
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// The bytes are not a SQLite database at all.
class NotSqliteException extends SqliteException {
  const NotSqliteException(String message) : super('notSqlite', message);
}

/// A valid SQLite file that uses a feature this reader does not read.
class UnsupportedSqliteException extends SqliteException {
  const UnsupportedSqliteException(String message)
      : super('unsupported', message);
}

/// The file starts out as SQLite and then contradicts itself — truncated,
/// damaged, or hostile.
class CorruptSqliteException extends SqliteException {
  const CorruptSqliteException(String message) : super('corrupt', message);
}

/// A [SqliteLimits] ceiling was hit.
class SqliteTooLargeException extends SqliteException {
  const SqliteTooLargeException(String message) : super('tooLarge', message);
}

/// The caller asked to stop.
class SqliteCancelledException extends SqliteException {
  const SqliteCancelledException() : super('cancelled', 'cancelled');
}

/// One table in the file.
class SqliteTable {
  SqliteTable._(this.name, this.rootPage, this.sql, this.columns,
      this.rowidAliasColumn, this.withoutRowId);

  final String name;
  final int rootPage;
  final String sql;

  /// Declared column names, in order.
  final List<String> columns;

  /// Index of an `INTEGER PRIMARY KEY` column, whose value SQLite keeps in
  /// the rowid rather than in the record. -1 when there is none.
  final int rowidAliasColumn;
  final bool withoutRowId;

  int columnIndex(String column) {
    final want = column.toLowerCase();
    for (var i = 0; i < columns.length; i++) {
      if (columns[i].toLowerCase() == want) return i;
    }
    return -1;
  }

  @override
  String toString() => 'SqliteTable($name, cols=$columns)';
}

typedef SqliteRowCallback = void Function(int rowid, List<Object?> row);

/// An open database. Construction validates the header and reads the
/// schema; rows are read on demand.
class SqliteFile {
  SqliteFile._(this._bytes, this._pageSize, this._pageCount);

  final Uint8List _bytes;
  final int _pageSize;
  final int _pageCount;
  List<SqliteTable>? _tables;

  /// Deepest b-tree the last scan met. A test hook: it is how the suite
  /// proves a fixture really does exercise interior pages.
  int lastScanDepth = 0;

  /// Overflow pages followed by the last scan. Same purpose.
  int lastScanOverflowPages = 0;

  int get pageSize => _pageSize;
  int get pageCount => _pageCount;

  /// Open [bytes] as a SQLite database. Throws a [SqliteException].
  factory SqliteFile.open(Uint8List bytes) {
    if (bytes.length > SqliteLimits.maxFileBytes) {
      throw SqliteTooLargeException(
          'file is ${bytes.length} bytes; limit is ${SqliteLimits.maxFileBytes}');
    }
    const magic = 'SQLite format 3\u0000';
    if (bytes.length < 100) {
      throw const NotSqliteException('too short to be a SQLite file');
    }
    for (var i = 0; i < 16; i++) {
      if (bytes[i] != magic.codeUnitAt(i)) {
        throw const NotSqliteException('missing SQLite header');
      }
    }
    final bd = ByteData.sublistView(bytes);
    var pageSize = bd.getUint16(16);
    if (pageSize == 1) pageSize = 65536;
    if (pageSize < 512 || pageSize > 65536 || (pageSize & (pageSize - 1)) != 0) {
      throw CorruptSqliteException('bad page size $pageSize');
    }
    final reserved = bytes[20];
    if (reserved != 0) {
      throw const UnsupportedSqliteException(
          'database reserves bytes at the end of each page');
    }
    final encoding = bd.getUint32(56);
    if (encoding != 1 && encoding != 0) {
      throw const UnsupportedSqliteException('database text is UTF-16');
    }
    // The header's page count is only trustworthy when the file-change
    // counter matches; either way a truncated file is shorter than it
    // claims, so the byte length is the ceiling.
    final available = bytes.length ~/ pageSize;
    if (available < 1) {
      throw const CorruptSqliteException('file is shorter than one page');
    }
    final headerPages = bd.getUint32(28);
    final pageCount =
        (headerPages > 0 && headerPages <= available) ? headerPages : available;
    return SqliteFile._(bytes, pageSize, pageCount);
  }

  /// Every ordinary table, from `sqlite_master`.
  List<SqliteTable> get tables {
    final cached = _tables;
    if (cached != null) return cached;
    final out = <SqliteTable>[];
    final scan = _Scan(this);
    scan.walk(1, (rowid, row) {
      // type, name, tbl_name, rootpage, sql
      if (row.length < 5) return;
      if (row[0] != 'table') return;
      final name = row[1];
      final root = row[3];
      final sql = row[4];
      if (name is! String || root is! int || sql is! String) return;
      if (name.startsWith('sqlite_')) return;
      if (root < 2) return; // virtual tables have rootpage 0
      final parsed = _parseCreateTable(sql);
      out.add(SqliteTable._(name, root, sql, parsed.columns,
          parsed.rowidAlias, parsed.withoutRowId));
    }, SqliteLimits.maxRowsPerTable);
    _tables = out;
    return out;
  }

  SqliteTable? table(String name) {
    final want = name.toLowerCase();
    for (final t in tables) {
      if (t.name.toLowerCase() == want) return t;
    }
    return null;
  }

  bool hasTable(String name) => table(name) != null;

  /// Read every row of [table], calling [onRow] for each. Synchronous: for
  /// tests and for small tables. The import path uses [scanAsync].
  void scan(SqliteTable table, SqliteRowCallback onRow) {
    if (table.withoutRowId) {
      throw UnsupportedSqliteException(
          'table "${table.name}" is WITHOUT ROWID');
    }
    final s = _Scan(this);
    s.walk(table.rootPage, (rowid, row) {
      onRow(rowid, _applyAlias(table, rowid, row));
    }, SqliteLimits.maxRowsPerTable);
    lastScanDepth = s.maxDepth;
    lastScanOverflowPages = s.overflowPages;
  }

  /// As [scan], but yields to the event loop every [yieldEvery] rows and
  /// stops when [cancelled] returns true. The web has no real isolates,
  /// so this is how a 30,000-row import keeps the page alive.
  Future<void> scanAsync(
    SqliteTable table,
    SqliteRowCallback onRow, {
    int yieldEvery = 2000,
    bool Function()? cancelled,
  }) async {
    if (table.withoutRowId) {
      throw UnsupportedSqliteException(
          'table "${table.name}" is WITHOUT ROWID');
    }
    final s = _Scan(this);
    var n = 0;
    final it = s.rows(table.rootPage, SqliteLimits.maxRowsPerTable).iterator;
    while (it.moveNext()) {
      final r = it.current;
      onRow(r.$1, _applyAlias(table, r.$1, r.$2));
      if (++n % yieldEvery == 0) {
        if (cancelled != null && cancelled()) {
          throw const SqliteCancelledException();
        }
        await Future<void>.delayed(Duration.zero);
      }
    }
    lastScanDepth = s.maxDepth;
    lastScanOverflowPages = s.overflowPages;
  }

  static List<Object?> _applyAlias(
      SqliteTable t, int rowid, List<Object?> row) {
    // A record may hold fewer columns than the table declares (columns
    // added later); the reader sees them as NULL.
    final width = t.columns.length;
    List<Object?> out = row;
    if (row.length < width) {
      out = List<Object?>.filled(width, null)..setRange(0, row.length, row);
    }
    final a = t.rowidAliasColumn;
    if (a >= 0 && a < out.length && out[a] == null) {
      out = List<Object?>.of(out);
      out[a] = rowid;
    }
    return out;
  }
}

// ── schema parsing ─────────────────────────────────────────────────────

class _ParsedCreate {
  _ParsedCreate(this.columns, this.rowidAlias, this.withoutRowId);
  final List<String> columns;
  final int rowidAlias;
  final bool withoutRowId;
}

/// Pull column names out of a `CREATE TABLE` statement. Not a SQL parser:
/// it finds the outer parentheses, splits on top-level commas, and takes
/// the first identifier of each clause that is not a table constraint.
_ParsedCreate _parseCreateTable(String sql) {
  final open = sql.indexOf('(');
  if (open < 0) return _ParsedCreate(const [], -1, false);
  // Find the matching close, respecting quotes and nesting.
  var depth = 0;
  var close = -1;
  String? quote;
  for (var i = open; i < sql.length; i++) {
    final c = sql[i];
    if (quote != null) {
      if (c == quote) quote = null;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      quote = c;
    } else if (c == '[') {
      quote = ']';
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) {
        close = i;
        break;
      }
    }
  }
  if (close < 0) return _ParsedCreate(const [], -1, false);
  final body = sql.substring(open + 1, close);
  final tail = sql.substring(close + 1).toUpperCase();
  final withoutRowId = RegExp(r'WITHOUT\s+ROWID').hasMatch(tail);

  final clauses = <String>[];
  var start = 0;
  depth = 0;
  quote = null;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (quote != null) {
      if (c == quote) quote = null;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      quote = c;
    } else if (c == '[') {
      quote = ']';
    } else if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
    } else if (c == ',' && depth == 0) {
      clauses.add(body.substring(start, i));
      start = i + 1;
    }
  }
  clauses.add(body.substring(start));

  final columns = <String>[];
  var alias = -1;
  const constraintStarts = {
    'PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'
  };
  for (final raw in clauses) {
    final clause = raw.trim();
    if (clause.isEmpty) continue;
    final name = _firstIdentifier(clause);
    if (name == null) continue;
    if (constraintStarts.contains(name.$1.toUpperCase()) && !name.$2) continue;
    columns.add(name.$1);
    // `INTEGER PRIMARY KEY` (exactly that type) aliases the rowid.
    final rest = clause.substring(name.$3).trim().toUpperCase();
    if (RegExp(r'^INTEGER\b').hasMatch(rest) &&
        RegExp(r'\bPRIMARY\s+KEY\b').hasMatch(rest) &&
        !RegExp(r'\bPRIMARY\s+KEY\s+DESC\b').hasMatch(rest)) {
      alias = columns.length - 1;
    }
  }
  return _ParsedCreate(columns, withoutRowId ? -1 : alias, withoutRowId);
}

/// (identifier, wasQuoted, endOffset) or null.
(String, bool, int)? _firstIdentifier(String s) {
  if (s.isEmpty) return null;
  final c = s[0];
  if (c == '"' || c == "'" || c == '`') {
    final end = s.indexOf(c, 1);
    if (end < 0) return null;
    return (s.substring(1, end), true, end + 1);
  }
  if (c == '[') {
    final end = s.indexOf(']', 1);
    if (end < 0) return null;
    return (s.substring(1, end), true, end + 1);
  }
  final m = RegExp(r'^[A-Za-z_\u0080-￿][A-Za-z0-9_$\u0080-￿]*')
      .firstMatch(s);
  if (m == null) return null;
  return (m.group(0)!, false, m.end);
}

// ── the b-tree walk ────────────────────────────────────────────────────

class _Frame {
  _Frame(this.page, this.depth);
  final int page;
  final int depth;
}

class _Scan {
  _Scan(this.f)
      : _visited = Uint8List(f._pageCount + 1),
        _usable = f._pageSize;

  final SqliteFile f;
  final Uint8List _visited;
  final int _usable;
  int maxDepth = 0;
  int overflowPages = 0;
  int _totalBytes = 0;

  Uint8List get _b => f._bytes;
  int get _ps => f._pageSize;

  void walk(int root, SqliteRowCallback onRow, int maxRows) {
    for (final r in rows(root, maxRows)) {
      onRow(r.$1, r.$2);
    }
  }

  /// Rows of the table whose b-tree is rooted at [root], in rowid order.
  Iterable<(int, List<Object?>)> rows(int root, int maxRows) sync* {
    var emitted = 0;
    // Explicit stack of pages still to visit. Interior pages push their
    // children right-to-left so the left-most is popped first.
    final stack = <_Frame>[_Frame(root, 1)];
    while (stack.isNotEmpty) {
      final fr = stack.removeLast();
      if (fr.depth > maxDepth) maxDepth = fr.depth;
      if (fr.depth > 64) {
        throw const CorruptSqliteException('b-tree is impossibly deep');
      }
      final page = fr.page;
      _claim(page);
      final base = (page - 1) * _ps;
      final hdr = base + (page == 1 ? 100 : 0);
      if (hdr + 8 > _b.length) {
        throw const CorruptSqliteException('page header past end of file');
      }
      final type = _b[hdr];
      final bd = ByteData.sublistView(_b);
      final nCells = bd.getUint16(hdr + 3);
      switch (type) {
        case 0x0d: // leaf table
          final arr = hdr + 8;
          if (arr + nCells * 2 > base + _ps) {
            throw const CorruptSqliteException('cell array past end of page');
          }
          for (var i = 0; i < nCells; i++) {
            final ptr = bd.getUint16(arr + i * 2);
            if (ptr < (arr - base) + nCells * 2 || ptr >= _ps) {
              throw const CorruptSqliteException('cell pointer out of range');
            }
            if (++emitted > maxRows) {
              throw SqliteTooLargeException('more than $maxRows rows');
            }
            yield _readLeafCell(base, ptr);
          }
          break;
        case 0x05: // interior table
          if (hdr + 12 > _b.length) {
            throw const CorruptSqliteException('interior header cut off');
          }
          final arr = hdr + 12;
          if (arr + nCells * 2 > base + _ps) {
            throw const CorruptSqliteException('cell array past end of page');
          }
          final rightmost = bd.getUint32(hdr + 8);
          final children = <int>[];
          for (var i = 0; i < nCells; i++) {
            final ptr = bd.getUint16(arr + i * 2);
            if (ptr < (arr - base) + nCells * 2 || ptr + 4 > _ps) {
              throw const CorruptSqliteException('cell pointer out of range');
            }
            children.add(bd.getUint32(base + ptr));
          }
          children.add(rightmost);
          for (var i = children.length - 1; i >= 0; i--) {
            final c = children[i];
            if (c < 2 || c > f._pageCount) {
              throw CorruptSqliteException('child page $c out of range');
            }
            stack.add(_Frame(c, fr.depth + 1));
          }
          break;
        case 0x0a:
        case 0x02:
          throw const UnsupportedSqliteException(
              'table is stored as an index (WITHOUT ROWID)');
        default:
          throw CorruptSqliteException(
              'unexpected b-tree page type 0x${type.toRadixString(16)}');
      }
    }
  }

  void _claim(int page) {
    if (page < 1 || page > f._pageCount) {
      throw CorruptSqliteException('page $page out of range');
    }
    if (_visited[page] != 0) {
      throw CorruptSqliteException('page $page is reached twice');
    }
    _visited[page] = 1;
  }

  (int, List<Object?>) _readLeafCell(int pageBase, int ptr) {
    var pos = pageBase + ptr;
    final end = pageBase + _ps;
    final (payloadLen, n1) = _varint(pos, end);
    pos += n1;
    final (rowid, n2) = _varint(pos, end);
    pos += n2;
    if (payloadLen < 0 || payloadLen > SqliteLimits.maxCellBytes) {
      throw SqliteTooLargeException('cell of $payloadLen bytes');
    }
    final x = _usable - 35;
    final int local;
    if (payloadLen <= x) {
      local = payloadLen;
    } else {
      final m = ((_usable - 12) * 32) ~/ 255 - 23;
      final k = m + ((payloadLen - m) % (_usable - 4));
      local = k <= x ? k : m;
    }
    final neededEnd = pos + local + (payloadLen > x ? 4 : 0);
    if (neededEnd > end) {
      throw const CorruptSqliteException('cell runs past end of page');
    }
    final Uint8List payload;
    if (payloadLen <= x) {
      payload = Uint8List.sublistView(_b, pos, pos + payloadLen);
    } else {
      payload = _gather(pos, local, payloadLen);
    }
    return (rowid, _decodeRecord(payload));
  }

  /// Local payload plus its overflow chain, as one buffer.
  Uint8List _gather(int localStart, int local, int total) {
    final out = Uint8List(total);
    out.setRange(0, local, _b, localStart);
    var written = local;
    var next = ByteData.sublistView(_b).getUint32(localStart + local);
    final perPage = _usable - 4;
    // A chain can never be longer than the bytes it must carry.
    var guard = (total - local) ~/ perPage + 2;
    while (written < total) {
      if (next == 0) {
        throw const CorruptSqliteException('overflow chain ends early');
      }
      if (--guard < 0) {
        throw const CorruptSqliteException('overflow chain too long');
      }
      _claim(next);
      overflowPages++;
      final base = (next - 1) * _ps;
      final take = (total - written) < perPage ? (total - written) : perPage;
      if (base + 4 + take > _b.length) {
        throw const CorruptSqliteException('overflow page cut off');
      }
      out.setRange(written, written + take, _b, base + 4);
      written += take;
      next = ByteData.sublistView(_b).getUint32(base);
    }
    return out;
  }

  /// SQLite's varint: 1–9 bytes, big-endian, 7 bits each; the ninth byte
  /// contributes all eight. Arithmetic rather than shifts, because on the
  /// web an `int` shift is 32-bit.
  (int, int) _varint(int pos, int end) {
    var result = 0;
    for (var i = 0; i < 8; i++) {
      if (pos + i >= end) {
        throw const CorruptSqliteException('varint runs past end of page');
      }
      final byte = _b[pos + i];
      result = result * 128 + (byte & 0x7f);
      if (byte < 0x80) return (result, i + 1);
    }
    if (pos + 8 >= end) {
      throw const CorruptSqliteException('varint runs past end of page');
    }
    result = result * 256 + _b[pos + 8];
    return (result, 9);
  }

  List<Object?> _decodeRecord(Uint8List p) {
    var pos = 0;
    final (hdrLen, hn) = _varintIn(p, 0);
    pos = hn;
    if (hdrLen < hn || hdrLen > p.length) {
      throw const CorruptSqliteException('record header longer than record');
    }
    final types = <int>[];
    while (pos < hdrLen) {
      final (t, n) = _varintIn(p, pos);
      pos += n;
      types.add(t);
      if (types.length > 4096) {
        throw const CorruptSqliteException('record has too many columns');
      }
    }
    pos = hdrLen;
    final out = <Object?>[];
    for (final t in types) {
      switch (t) {
        case 0:
          out.add(null);
        case 1:
          out.add(_int(p, pos, 1));
          pos += 1;
        case 2:
          out.add(_int(p, pos, 2));
          pos += 2;
        case 3:
          out.add(_int(p, pos, 3));
          pos += 3;
        case 4:
          out.add(_int(p, pos, 4));
          pos += 4;
        case 5:
          out.add(_int(p, pos, 6));
          pos += 6;
        case 6:
          out.add(_int(p, pos, 8));
          pos += 8;
        case 7:
          if (pos + 8 > p.length) {
            throw const CorruptSqliteException('float runs past record');
          }
          out.add(ByteData.sublistView(p, pos, pos + 8).getFloat64(0));
          pos += 8;
        case 8:
          out.add(0);
        case 9:
          out.add(1);
        case 10:
        case 11:
          throw const CorruptSqliteException('reserved serial type');
        default:
          final isText = t.isOdd;
          final len = isText ? (t - 13) ~/ 2 : (t - 12) ~/ 2;
          if (len < 0 || pos + len > p.length) {
            throw const CorruptSqliteException(
                'column runs past the end of its record');
          }
          _totalBytes += len;
          if (_totalBytes > SqliteLimits.maxTotalBytes) {
            throw const SqliteTooLargeException('decoded content too large');
          }
          if (isText) {
            out.add(utf8.decode(Uint8List.sublistView(p, pos, pos + len),
                allowMalformed: true));
          } else {
            out.add(Uint8List.fromList(Uint8List.sublistView(p, pos, pos + len)));
          }
          pos += len;
      }
    }
    return out;
  }

  (int, int) _varintIn(Uint8List p, int pos) {
    var result = 0;
    for (var i = 0; i < 8; i++) {
      if (pos + i >= p.length) {
        throw const CorruptSqliteException('varint runs past record');
      }
      final byte = p[pos + i];
      result = result * 128 + (byte & 0x7f);
      if (byte < 0x80) return (result, i + 1);
    }
    if (pos + 8 >= p.length) {
      throw const CorruptSqliteException('varint runs past record');
    }
    return (result * 256 + p[pos + 8], 9);
  }

  /// Big-endian two's-complement integer of [width] bytes. Built from
  /// arithmetic so it is exact on the VM and as exact as a double allows
  /// on the web (module integers are tiny; this is correctness, not need).
  int _int(Uint8List p, int pos, int width) {
    if (pos + width > p.length) {
      throw const CorruptSqliteException('integer runs past record');
    }
    if (width == 8) {
      // Split so the VM never overflows and the web never shifts 64 bits.
      var hi = 0;
      for (var i = 0; i < 4; i++) {
        hi = hi * 256 + p[pos + i];
      }
      var lo = 0;
      for (var i = 4; i < 8; i++) {
        lo = lo * 256 + p[pos + i];
      }
      if (hi >= 2147483648) hi -= 4294967296;
      return hi * 4294967296 + lo;
    }
    var v = 0;
    for (var i = 0; i < width; i++) {
      v = v * 256 + p[pos + i];
    }
    final half = _pow2(width * 8 - 1);
    if (v >= half) v -= _pow2(width * 8);
    return v;
  }

  static int _pow2(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 2;
    }
    return r;
  }
}

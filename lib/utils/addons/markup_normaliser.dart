/// Turn a verse's markup — in any of the dialects third-party modules use —
/// into the app's own vocabulary, and nothing else.
///
/// ## The output vocabulary
///
/// The reader understands exactly this, in a verse's `text`:
///
///   * plain text;
///   * `[words]` — words the translators added (rendered as a styled
///     insertion, as the LEB and NASB already are);
///   * `<note: …>` — a footnote, shown as a numbered marker;
///   * `\n` — a line break inside a verse.
///
/// There is no italic span, no words-of-Jesus colour and no inline Strong's
/// number in that list, so the importer does not pretend to have them: red
/// letters and Strong's numbers are COUNTED and dropped, and the import report
/// says so.
///
/// ## Why this is the security boundary
///
/// A module is somebody else's file. The normaliser never copies a tag
/// through: not `<a>`, not `<img>`, not `<script>`, not a link, not a URL. It
/// emits only the four tokens above, so there is nothing for the reader to
/// execute or fetch — safe by construction, not by sanitising. The last pass
/// strips every `<`, `>`, `{`, `}`, `[` and `]` the module did not turn into
/// one of those tokens, because an unbalanced one would otherwise be eaten by
/// the reader's annotation pattern and swallow the rest of the verse.
///
/// ## Forgiving, because real files are not clean
///
/// `tools/import_yahweh_ont.py` catalogues what a real theWord export
/// contains: text swallowed into a tag (`<牲畜WH2874>`), a missing `>`
/// (`<WH5921<WH3802>`), a doubled `<` (`<<WG5624>`), suffix noise
/// (`<WH3190s>`), a dropped `W` (`<H4480x>`) or dropped letter (`<3588>`).
/// None of those may leak a Strong's number into the reading text or abort the
/// import; each is handled and counted.
library;

import 'addon_types.dart';

/// Which tag vocabulary a verse is written in.
enum MarkupDialect {
  /// MyBible.zone: `<i>`, `<J>`, `<S>1234</S>`, `<n>`, `<f>`, `<pb/>` …
  myBible,

  /// MySword and theWord: GBF-style `<FI>…<Fi>`, `<WG123>`, `<RF>…<Rf>`,
  /// `<CM>` … plus a little HTML.
  gbf,

  /// Zefania XML verse content: `<NOTE>`, `<STYLE>`, `<BR/>`, `<gr>` …
  zefania,
}

/// What one verse's markup became.
class NormalisedVerse {
  const NormalisedVerse({
    required this.text,
    this.startsParagraph = false,
    this.endsParagraph = false,
    this.hadStrongs = false,
  });

  final String text;

  /// A paragraph marker came BEFORE the first word.
  final bool startsParagraph;

  /// A paragraph marker came AFTER the last word, so the NEXT verse opens a
  /// paragraph.
  final bool endsParagraph;

  /// The verse carried Strong's numbers (all of which were dropped).
  final bool hadStrongs;
}

// Private-use markers: our own `[` `]` and note delimiters, kept apart from
// any bracket the module itself contained until the final pass.
const String _kOpenAdd = '';
const String _kCloseAdd = '';
const String _kOpenNote = '';
const String _kCloseNote = '';
const String _kNewline = '';

/// The kinds of open element the normaliser tracks.
enum _Ctx { drop, add, note, strip }

class _Open {
  _Open(this.key, this.kind, this.noteStart);
  final String key; // matching key for the closing tag
  final _Ctx kind;
  final int noteStart; // index in `out` where a note's text begins
}

/// Normalise [raw] (one verse's text in [dialect]). Counts go into [report].
NormalisedVerse normaliseVerse(
  String raw,
  MarkupDialect dialect,
  ImportReport report,
) {
  // The private-use characters are OUR markers; a module cannot be allowed
  // to smuggle them in.
  var text = raw.replaceAll(RegExp('[\uE000-\uE004]'), '');
  if (dialect == MarkupDialect.gbf) text = _repairGbf(text);

  final out = StringBuffer();
  final stack = <_Open>[];
  var hadStrongs = false;
  var leadingPara = false;
  var trailingPara = false;
  // Whether any visible character has been written yet / since the last
  // paragraph marker (to tell "before the first word" from "mid-verse").
  var wroteText = false;

  bool dropping() => stack.any((o) => o.kind == _Ctx.drop);

  void emit(String s) {
    if (s.isEmpty || dropping()) return;
    out.write(s);
    if (s != _kNewline && s.trim().isNotEmpty) {
      wroteText = true;
      trailingPara = false;
    }
  }

  void markParagraph() {
    if (dropping()) return;
    if (!wroteText) {
      leadingPara = true;
    } else {
      trailingPara = true;
    }
  }

  void open(String key, _Ctx kind) {
    // A note inside a note, or an insertion inside an insertion, is just
    // text in the outer one: the reader's annotation pattern cannot nest, and
    // a `>` or `]` inside would end it early.
    if ((kind == _Ctx.note || kind == _Ctx.add) &&
        stack.any((o) => o.kind == kind)) {
      kind = _Ctx.strip;
    }
    stack.add(_Open(key, kind, out.length));
    if (kind == _Ctx.add) {
      if (!dropping()) out.write(_kOpenAdd);
    } else if (kind == _Ctx.note) {
      if (!dropping()) out.write(_kOpenNote);
    }
  }

  void close(String key) {
    // Close the nearest open element with this key; ignore a stray close.
    final i = stack.lastIndexWhere((o) => o.key == key);
    if (i < 0) return;
    // Anything opened inside it and never closed is closed with it.
    while (stack.length > i + 1) {
      _closeTop(stack, out, report);
    }
    _closeTop(stack, out, report);
  }

  void closeAll() {
    while (stack.isNotEmpty) {
      _closeTop(stack, out, report);
    }
  }

  for (final tok in _scan(text)) {
    if (tok is _Text) {
      emit(tok.text);
      continue;
    }
    final t = tok as _Tag;
    switch (dialect) {
      case MarkupDialect.myBible:
        _myBibleTag(t, emit, open, close, markParagraph, report, () {
          hadStrongs = true;
        });
      case MarkupDialect.gbf:
        _gbfTag(t, emit, open, close, markParagraph, report, () {
          hadStrongs = true;
        });
      case MarkupDialect.zefania:
        _zefaniaTag(t, emit, open, close, markParagraph, report, () {
          hadStrongs = true;
        });
    }
  }
  closeAll();

  return NormalisedVerse(
    text: _finish(out.toString(), report),
    startsParagraph: leadingPara,
    endsParagraph: trailingPara,
    hadStrongs: hadStrongs,
  );
}

void _closeTop(List<_Open> stack, StringBuffer out, ImportReport report) {
  final o = stack.removeLast();
  final dropped = stack.any((x) => x.kind == _Ctx.drop);
  if (dropped) return;
  switch (o.kind) {
    case _Ctx.add:
      out.write(_kCloseAdd);
    case _Ctx.note:
      out.write(_kCloseNote);
    case _Ctx.drop:
    case _Ctx.strip:
      break;
  }
}

// ── dialects ───────────────────────────────────────────────────────────

void _myBibleTag(
  _Tag t,
  void Function(String) emit,
  void Function(String, _Ctx) open,
  void Function(String) close,
  void Function() para,
  ImportReport report,
  void Function() strongs,
) {
  final n = t.name; // MyBible tags are case-sensitive per its spec
  if (t.closing) {
    close(n);
    return;
  }
  switch (n) {
    case 'S':
      strongs();
      report.strongsTagsDropped++;
      if (!t.selfClosing) open('S', _Ctx.drop);
    case 'm':
      if (!t.selfClosing) open('m', _Ctx.drop);
    case 'i':
      if (!t.selfClosing) open('i', _Ctx.add);
    case 'J':
    case 'e':
      if (!t.selfClosing) open(n, _Ctx.strip);
    case 't':
      emit(_kNewline);
      if (!t.selfClosing) open('t', _Ctx.strip);
    case 'n':
      report.notesKept++;
      if (!t.selfClosing) open('n', _Ctx.note);
    case 'f':
      report.footnoteMarkersDropped++;
      if (!t.selfClosing) open('f', _Ctx.drop);
    case 'h':
      report.headingsDropped++;
      if (!t.selfClosing) open('h', _Ctx.drop);
    case 'br':
      emit(_kNewline);
    case 'pb':
      para();
    default:
      report.unknownTagsDropped++;
      // Unknown: strip the tag, keep what is inside it.
      if (!t.selfClosing) open(n, _Ctx.strip);
  }
}

void _gbfTag(
  _Tag t,
  void Function(String) emit,
  void Function(String, _Ctx) open,
  void Function(String) close,
  void Function() para,
  ImportReport report,
  void Function() strongs,
) {
  final n = t.name;

  // Closing forms of the GBF pairs are written with a lower-case second
  // letter (`<Fi>`), HTML closes with `</i>`.
  if (t.closing) {
    close(_gbfCloseKey(n));
    return;
  }
  // Strong's and morphology: `<WG123>`, `<WH123x>`, `<WT …>`, and the
  // damaged shapes `_repairGbf` could not recover.
  if (_isStrongsTag(n)) {
    if (n.startsWith('WT') || n.startsWith('wt')) {
      // morphology: nothing to count beyond "tagged"
    } else {
      report.strongsTagsDropped++;
    }
    strongs();
    return;
  }
  switch (n) {
    case 'FI':
      open('FI', _Ctx.add);
    case 'Fi':
      close('FI');
    case 'FR':
    case 'FO':
    case 'FU':
      open(n, _Ctx.strip);
    case 'Fr':
    case 'Fo':
    case 'Fu':
      close(n.toUpperCase());
    case 'RF':
      report.notesKept++;
      open('RF', _Ctx.note);
    case 'Rf':
      close('RF');
    case 'TS':
    case 'TS1':
    case 'TS2':
    case 'TS3':
      report.headingsDropped++;
      open('TS', _Ctx.drop);
    case 'Ts':
    case 'Ts1':
    case 'Ts2':
    case 'Ts3':
      close('TS');
    case 'Q':
      report.interlinearDropped++;
      open('Q', _Ctx.drop);
    case 'q':
      close('Q');
    case 'CM':
      para();
    case 'CL':
      emit(_kNewline);
    case 'CI':
    case 'PF0':
    case 'PF1':
    case 'PF2':
    case 'PF3':
    case 'PF4':
    case 'PF5':
    case 'PF6':
    case 'PF7':
    case 'PI0':
    case 'PI1':
    case 'PI2':
    case 'PI3':
    case 'PI4':
    case 'PI5':
    case 'PI6':
    case 'PI7':
      break; // layout hints we do not use
    case 'br':
    case 'BR':
    case 'p':
    case 'P':
      emit(_kNewline);
    default:
      if (n.startsWith('RX')) {
        report.crossRefsDropped++;
      } else if (_kHtmlStrip.contains(n.toLowerCase())) {
        if (!t.selfClosing) open(n.toLowerCase(), _Ctx.strip);
      } else {
        report.unknownTagsDropped++;
        if (!t.selfClosing) open(n, _Ctx.strip);
      }
  }
}

const _kHtmlStrip = {
  'b', 'i', 'u', 's', 'sub', 'sup', 'font', 'span', 'em', 'strong', 'big',
  'small', 'center', 'div', 'a',
};

String _gbfCloseKey(String closeName) {
  switch (closeName) {
    case 'Fi':
      return 'FI';
    case 'Fr':
      return 'FR';
    case 'Fo':
      return 'FO';
    case 'Fu':
      return 'FU';
    case 'Rf':
      return 'RF';
    case 'Ts':
    case 'Ts1':
    case 'Ts2':
    case 'Ts3':
      return 'TS';
    case 'q':
      return 'Q';
    default:
      return closeName.toLowerCase(); // </b>, </font> …
  }
}

bool _isStrongsTag(String n) {
  if (RegExp(r'^[WwHhGg]{0,3}\d{1,5}[A-Za-z]{0,2}$').hasMatch(n)) return true;
  if (n.startsWith('WG') || n.startsWith('WH') || n.startsWith('WT')) {
    return true;
  }
  if (n.startsWith('wg') || n.startsWith('wh') || n.startsWith('wt')) {
    return true;
  }
  return false;
}

void _zefaniaTag(
  _Tag t,
  void Function(String) emit,
  void Function(String, _Ctx) open,
  void Function(String) close,
  void Function() para,
  ImportReport report,
  void Function() strongs,
) {
  final n = t.name.toUpperCase();
  if (t.closing) {
    close(n);
    return;
  }
  switch (n) {
    case 'NOTE':
      report.notesKept++;
      if (!t.selfClosing) open('NOTE', _Ctx.note);
    case 'BR':
      emit(_kNewline);
    case 'CAPTION':
      report.headingsDropped++;
      if (!t.selfClosing) open('CAPTION', _Ctx.drop);
    case 'XREF':
      report.crossRefsDropped++;
      if (!t.selfClosing) open('XREF', _Ctx.drop);
    case 'GR':
      strongs();
      report.strongsTagsDropped++;
      if (!t.selfClosing) open('GR', _Ctx.strip);
    case 'STYLE':
    case 'DIV':
    case 'SUP':
      if (!t.selfClosing) open(n, _Ctx.strip);
    default:
      report.unknownTagsDropped++;
      if (!t.selfClosing) open(n, _Ctx.strip);
  }
}

// ── GBF repair ─────────────────────────────────────────────────────────

/// Mend the damage `tools/import_yahweh_ont.py` documents in real exports,
/// before tokenising. Every repair only ever makes a Strong's tag parse as one;
/// none invents text.
String _repairGbf(String s) {
  // Text swallowed into a tag:  <牲畜WH2874>  →  牲畜<WH2874>
  s = s.replaceAllMapped(
    RegExp(r'<([^<>A-Za-z0-9\s]+)([WwHhGg]{1,2}\d{1,5}[A-Za-z]{0,2})>'),
    (m) => '${m[1]}<${m[2]}>',
  );
  // A doubled opener:  <<WG5624>  →  <WG5624>
  s = s.replaceAll(RegExp(r'<{2,}'), '<');
  // A tag that never closed before the next one opened:  <WH5921<WH3802>
  s = s.replaceAllMapped(
    RegExp(r'<([WwHhGg]{1,2}\d{1,5}[A-Za-z]{0,2})(?=<)'),
    (m) => '<${m[1]}>',
  );
  return s;
}

// ── tokeniser ──────────────────────────────────────────────────────────

abstract class _Tok {}

class _Text extends _Tok {
  _Text(this.text);
  final String text;
}

class _Tag extends _Tok {
  _Tag(this.name, {required this.closing, required this.selfClosing});
  final String name;
  final bool closing;
  final bool selfClosing;
}

final RegExp _nameChars = RegExp(r'[A-Za-z0-9.%_\-]');

/// Split [s] into text and tags. A `<` that does not begin something that
/// looks like a tag is text (and is stripped in the final pass).
Iterable<_Tok> _scan(String s) sync* {
  var i = 0;
  final buf = StringBuffer();
  Iterable<_Tok> flush() sync* {
    if (buf.isNotEmpty) {
      yield _Text(buf.toString());
      buf.clear();
    }
  }

  while (i < s.length) {
    final c = s[i];
    if (c != '<') {
      buf.write(c);
      i++;
      continue;
    }
    // Try a tag: <  /?  name  (anything but < >)*  >
    var j = i + 1;
    var closing = false;
    if (j < s.length && s[j] == '/') {
      closing = true;
      j++;
    }
    final nameStart = j;
    while (j < s.length && _nameChars.hasMatch(s[j])) {
      j++;
    }
    final name = s.substring(nameStart, j);
    // A name must start with a letter, except the digit-led Strong's
    // shapes (`<3588>`), which the GBF dialect reads as a tag.
    final startsOk = name.isNotEmpty &&
        (RegExp(r'^[A-Za-z]').hasMatch(name) ||
            RegExp(r'^\d{1,5}[A-Za-z]{0,2}$').hasMatch(name));
    if (!startsOk) {
      buf.write(c);
      i++;
      continue;
    }
    // Find the end of the tag without crossing another `<`.
    var k = j;
    var found = false;
    while (k < s.length && k - i < 400) {
      final ch = s[k];
      if (ch == '>') {
        found = true;
        break;
      }
      if (ch == '<') break;
      k++;
    }
    if (!found) {
      // `<NAME` with no `>` before the next `<` or the end: a damaged tag.
      // Drop the `<` and the name rather than leak the name into the text.
      i = j;
      yield* flush();
      yield _Tag(name, closing: false, selfClosing: true);
      continue;
    }
    final selfClosing = s[k - 1] == '/';
    yield* flush();
    yield _Tag(name, closing: closing, selfClosing: selfClosing);
    i = k + 1;
  }
  yield* flush();
}

// ── final pass ─────────────────────────────────────────────────────────

final RegExp _entity = RegExp(r'&(#x[0-9A-Fa-f]+|#\d+|[A-Za-z]+);');

String _decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(_entity, (m) {
    final body = m[1]!;
    switch (body) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      case 'nbsp':
        return ' ';
      case 'ldquo':
        return '“';
      case 'rdquo':
        return '”';
      case 'lsquo':
        return '‘';
      case 'rsquo':
        return '’';
      case 'mdash':
        return '—';
      case 'ndash':
        return '–';
      case 'hellip':
        return '…';
    }
    if (body.startsWith('#x')) {
      final cp = int.tryParse(body.substring(2), radix: 16);
      return _safeCodePoint(cp) ?? m[0]!;
    }
    if (body.startsWith('#')) {
      final cp = int.tryParse(body.substring(1));
      return _safeCodePoint(cp) ?? m[0]!;
    }
    return m[0]!; // an unknown named entity stays as written
  });
}

String? _safeCodePoint(int? cp) {
  if (cp == null || cp < 0x20 || cp > 0x10FFFF) return null;
  if (cp >= 0xD800 && cp <= 0xDFFF) return null;
  if (cp >= 0xE000 && cp <= 0xE004) return null; // our own markers
  return String.fromCharCode(cp);
}

/// Strip, decode, tidy, and turn the private markers into the app's tokens.
String _finish(String assembled, ImportReport report) {
  // Raw module content may not contain our markers.
  var s = assembled;
  s = _decodeEntities(s);

  // Remove every angle/brace/bracket the MODULE wrote. Ours are still the
  // private-use characters at this point, so they are untouched.
  var stripped = 0;
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (ch == '<' || ch == '>' || ch == '{' || ch == '}' || ch == '[' || ch == ']') {
      stripped++;
      continue;
    }
    if (r < 0x20 && r != 0x0A && r != 0x09) continue; // control characters
    sb.write(ch);
  }
  report.strayBracketsStripped += stripped;
  s = sb.toString();

  // Tidy whitespace.
  s = s.replaceAll('\r', ' ').replaceAll('\t', ' ').replaceAll('\n', ' ');
  s = s.replaceAll(RegExp(r' {2,}'), ' ');

  // Empty insertions and notes disappear — repeatedly, because removing an
  // empty note can leave the insertion around it empty too.
  final emptyAdd = RegExp('$_kOpenAdd\\s*$_kCloseAdd');
  final emptyNote = RegExp('$_kOpenNote\\s*$_kCloseNote');
  for (var guard = 0; guard < 8; guard++) {
    final before = s;
    s = s.replaceAll(emptyAdd, '').replaceAll(emptyNote, '');
    if (s == before) break;
  }
  // Tidy inside insertions and notes.
  s = s.replaceAllMapped(RegExp('$_kOpenAdd(.*?)$_kCloseAdd', dotAll: true),
      (m) => '$_kOpenAdd${m[1]!.trim()}$_kCloseAdd');

  // Notes: their text cannot contain `>` (already stripped) and must not
  // contain our add markers.
  s = s.replaceAllMapped(RegExp('$_kOpenNote(.*?)$_kCloseNote', dotAll: true),
      (m) {
    var body = m[1]!
        .replaceAll(_kOpenAdd, '')
        .replaceAll(_kCloseAdd, '')
        .replaceAll(_kNewline, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return body.isEmpty ? '' : '$_kOpenNote$body$_kCloseNote';
  });

  // The note pass can empty a note, which can empty the insertion around it.
  for (var guard = 0; guard < 8; guard++) {
    final before = s;
    s = s.replaceAll(emptyAdd, '').replaceAll(emptyNote, '');
    if (s == before) break;
  }

  s = s.replaceAll(_kOpenAdd, '[').replaceAll(_kCloseAdd, ']');
  s = s.replaceAll(_kOpenNote, '<note: ').replaceAll(_kCloseNote, '>');

  // The reader's annotation pattern cannot nest: `[a <note: x> b]` would be
  // one bracket token and the note inside it would never be a note. Lift any
  // note out of an insertion, to just after it.
  s = s.replaceAllMapped(RegExp(r'\[([^\[\]]*)\]'), (m) {
    final inner = m[1]!;
    final notes = RegExp(r'<note: [^>]*>').allMatches(inner).map((x) => x[0]!).toList();
    if (notes.isEmpty) return m[0]!;
    final bare = inner.replaceAll(RegExp(r'<note: [^>]*>'), '').replaceAll(RegExp(r' {2,}'), ' ').trim();
    return (bare.isEmpty ? '' : '[$bare]') + notes.join();
  });

  // Newlines (ours) — collapse runs, trim edges and spaces around them.
  s = s.replaceAll(_kNewline, '\n');
  s = s.replaceAll(RegExp(r' *\n *'), '\n');
  s = s.replaceAll(RegExp(r'\n{2,}'), '\n');
  s = s.trim();
  return s;
}

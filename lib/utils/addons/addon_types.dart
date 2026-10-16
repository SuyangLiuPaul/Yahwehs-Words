/// The shapes the add-on importer passes around. Pure Dart, no Flutter, no
/// app imports: the parsers run on the plain VM in tests and are identical in
/// Words and Sword.
library;

/// What kind of file this is, as far as we can tell from its CONTENT.
/// (Never from its name: MyBible modules are routinely renamed, and
/// distributed zipped.)
enum AddonFormat {
  /// Our own `[{book,chapter,verse,text}]` JSON.
  appJson,

  /// `book,chapter,verse,text` CSV.
  csv,

  /// theWord `.ont` / `.ot` / `.nt` plain-text Bible.
  theWord,

  /// Zefania XML Bible.
  zefania,

  /// MyBible.zone SQLite Bible.
  myBible,

  /// MySword `.bbl.mybible` SQLite Bible.
  mySword,
}

/// What the file turned out to contain, for the "this isn't supported"
/// answers. Only [bible] is imported.
enum AddonKind {
  bible,
  commentary,
  dictionary,
  crossReferences,
  other,
}

/// Why a file was refused. Each maps to one sentence in the UI that says
/// what the reader should do next — never a bare "failed".
enum ImportProblem {
  empty,
  tooLarge,
  notRecognised,
  encrypted,
  zipArchive,
  eSword,
  notABible, // a commentary / dictionary / plan: recognised, not imported yet
  noVerses,
  noBooksInCanon,
  corruptFile,
  unsupportedLayout,
  wrongVerseCount, // a theWord file whose line count is not one the format has
  nameEmpty,
  nameTaken,
  licenceNotAttested,
  cancelled,

  /// The platform could not show its file chooser at all.
  pickerFailed,
}

/// A refusal carrying its reason and, when there is one, the thing to quote.
class ImportRefusal implements Exception {
  const ImportRefusal(this.problem, {this.detail});

  final ImportProblem problem;

  /// A file name, a count, a table name — whatever the message can quote.
  final String? detail;

  @override
  String toString() => 'ImportRefusal($problem${detail == null ? '' : ': $detail'})';
}

/// One verse, parsed. [book] is the 1-based index into the 66-book canon
/// (`kCanonBooks[book - 1]`); everything that does not fit the canon is
/// dropped and counted before a [ParsedVerse] is made.
class ParsedVerse {
  const ParsedVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    this.paragraphStart = false,
    this.superscription = '',
  });

  final int book;
  final int chapter;
  final int verse;

  /// Already in the app's own markup vocabulary (see markup_normaliser.dart):
  /// plain text, `[added words]`, `<note: …>`, `\n`. Nothing else.
  final String text;
  final bool paragraphStart;

  /// A psalm title numbered 0 in the source, folded onto verse 1.
  final String superscription;

  ParsedVerse copyWith({
    String? text,
    bool? paragraphStart,
    String? superscription,
  }) =>
      ParsedVerse(
        book: book,
        chapter: chapter,
        verse: verse,
        text: text ?? this.text,
        paragraphStart: paragraphStart ?? this.paragraphStart,
        superscription: superscription ?? this.superscription,
      );
}

/// How the module numbers its verses, when it says.
enum AddonVersification { standard, russianPsalms, unknown }

/// What the file says about itself. Every field is optional because real
/// modules leave most of them out; nothing here is invented.
class ModuleMeta {
  const ModuleMeta({
    this.title = '',
    this.abbreviation = '',
    this.description = '',
    this.language = '',
    this.rightToLeft = false,
    this.strongsPresent = false,
    this.versification = AddonVersification.unknown,
  });

  final String title;
  final String abbreviation;

  /// The publisher's own words, shown verbatim.
  final String description;

  /// As the file spells it: `en`, `rus`, `zho`, `chi`… The importer maps it
  /// to a script only for choosing book names, never to rewrite text.
  final String language;
  final bool rightToLeft;

  /// The file declares or carries Strong's numbers. They are NOT shown.
  final bool strongsPresent;
  final AddonVersification versification;
}

/// A bounded, plain-language account of what happened to a file. This is the
/// feature's honesty: "7 books weren't imported" is said here, not hidden.
class ImportReport {
  ImportReport();

  int versesAccepted = 0;
  int versesDroppedOutsideCanon = 0;
  int versesDuplicate = 0;
  int versesEmpty = 0;
  int superscriptionsFolded = 0;
  int headingsDropped = 0;
  int crossRefsDropped = 0;
  int footnoteMarkersDropped = 0;
  int notesKept = 0;
  int strongsTagsDropped = 0;
  int unknownTagsDropped = 0;
  int strayBracketsStripped = 0;
  int interlinearDropped = 0;

  /// Books present in the file that the app does not carry, by the name the
  /// file gives (or `#<number>` when it only gave a number), with how many
  /// verses each held.
  final Map<String, int> booksDropped = {};

  /// At most [maxWarnings] one-line warnings (`code|detail`), so a damaged
  /// file cannot turn the report into a wall of text.
  final List<ImportWarning> warnings = [];
  static const int maxWarnings = 50;

  void warn(String code, [String detail = '']) {
    if (warnings.length < maxWarnings) {
      warnings.add(ImportWarning(code, detail));
    }
  }

  void dropBook(String name, [int verses = 1]) {
    booksDropped[name] = (booksDropped[name] ?? 0) + verses;
  }
}

class ImportWarning {
  const ImportWarning(this.code, this.detail);

  /// A stable key the UI turns into a sentence (`ui_strings` key
  /// `addonWarn_<code>`).
  final String code;
  final String detail;
}

/// A successfully read module: the verses that fit, what the file said about
/// itself, and the account of everything else.
class ParsedModule {
  ParsedModule({
    required this.format,
    required this.meta,
    required this.verses,
    required this.report,
  });

  final AddonFormat format;
  final ModuleMeta meta;

  /// Canon order; (book, chapter, verse) unique.
  final List<ParsedVerse> verses;
  final ImportReport report;

  /// 1-based canon indexes of the books present.
  Set<int> get books => {for (final v in verses) v.book};

  bool get coversOldTestament => books.any((b) => b <= 39);
  bool get coversNewTestament => books.any((b) => b >= 40);
}

/// A cooperative-cancellation handle. The web has no real isolates, so a
/// long parse runs on the event loop in slices and checks this between them.
class CancelToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Yield to the event loop. Parsers call it every few thousand rows.
Future<void> yieldToEventLoop() => Future<void>.delayed(Duration.zero);

/// Reports progress to whoever is watching. [done] of [total]; total 0 =
/// unknown.
typedef ProgressCallback = void Function(String phaseKey, int done, int total);

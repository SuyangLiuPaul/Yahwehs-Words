import 'package:flutter/material.dart';

import 'package:yahwehs_words/constants/book_groups.dart'
    show canonicalNtBooks, canonicalOtBooks;
import 'package:yahwehs_words/constants/book_names.dart';
import 'package:yahwehs_words/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/verse.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/utils/note_reference_parser.dart'
    show formatCompactReference;
import 'package:yahwehs_words/services/fetch_books.dart' show standardBookOrder;
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;

/// 2026-05-19 (v1.2.59): book → chapter → verse picker for the
/// note editor's "+ Reference" button.
///
/// Returns the `[Book Ch:V]` insertion string via [Navigator.pop]
/// when the user confirms, or `null` if they cancel / dismiss.
///
/// Reuses the data already loaded in [MainProvider] — no network
/// fetches, no extra asset loads. The book list comes from
/// [standardBookOrder] (canonical 66-book ordering), chapters are
/// derived from `mp.books` (built from the current version's verse
/// list), and verses are derived from `mp.verses` filtered by the
/// chosen book + chapter.
///
/// The picker shows book names in the user's locale (Simplified /
/// Traditional / English) but emits the canonical English form in
/// the `[Book Ch:V]` payload so the parser can resolve it cleanly
/// regardless of which version the reader is on later.
class NoteReferencePickerSheet extends StatefulWidget {
  final String locale;
  final MainProvider mainProvider;
  final AppSettings settings;

  const NoteReferencePickerSheet({
    super.key,
    required this.locale,
    required this.mainProvider,
    required this.settings,
  });

  @override
  State<NoteReferencePickerSheet> createState() =>
      _NoteReferencePickerSheetState();
}

enum _PickerStep { book, chapter, verse }

class _NoteReferencePickerSheetState
    extends State<NoteReferencePickerSheet> {
  _PickerStep _step = _PickerStep.book;
  String? _selectedBookCanonical; // canonical English book name
  int? _selectedChapter;

  /// 2026-05-19 (v1.2.61): multi-select verse picker — set of verse
  /// numbers the user has tapped on. The verse step shows the full
  /// verse text and lets the user toggle as many as they want; the
  /// bottom bar previews the compact reference being built (e.g.
  /// "Genesis 1:2,5,7,9-10") and the Insert button emits it.
  final Set<int> _selectedVerses = <int>{};

  /// Map canonical English book name → list of unique chapters
  /// available in `mp.verses`. Built lazily on first book pick.
  late final Map<String, List<int>> _chaptersByBook = _buildChaptersByBook();

  Map<String, List<int>> _buildChaptersByBook() {
    final out = <String, Set<int>>{};
    for (final v in widget.mainProvider.verses) {
      final canonical = bookNameToEnglish[v.book] ?? v.book;
      (out[canonical] ??= <int>{}).add(v.chapter);
    }
    return {
      for (final entry in out.entries)
        entry.key: (entry.value.toList()..sort()),
    };
  }

  /// 2026-05-19 (v1.2.61): full Verse objects for the multi-select
  /// step — same filter as [_versesIn] but returns Verse not int,
  /// so the picker UI can show verse text alongside the toggle.
  List<Verse> _verseObjectsIn(String canonicalBook, int chapter) {
    final out = <Verse>[];
    for (final v in widget.mainProvider.verses) {
      final candidate = bookNameToEnglish[v.book] ?? v.book;
      if (candidate == canonicalBook && v.chapter == chapter) {
        out.add(v);
      }
    }
    out.sort((a, b) => a.verse.compareTo(b.verse));
    return out;
  }

  /// Resolve a canonical English book name to the label we should
  /// show the user in the picker grid. Uses the inverse of
  /// `bookNameToEnglish` filtered by the requested locale prefix
  /// (Chinese sources for zh-*, English for en).
  String _displayBookName(String canonical) {
    if (widget.locale == 'en') return canonical;
    // For zh-Hans / zh-Hant: pick a non-English alias from
    // bookNameToEnglish that maps to this canonical. Both
    // simplified + traditional names live in the same map, so
    // we just need any non-ASCII alias.
    for (final entry in bookNameToEnglish.entries) {
      if (entry.value != canonical) continue;
      final alias = entry.key;
      if (alias == canonical) continue;
      final isAscii = alias.codeUnits.every((c) => c < 128);
      if (isAscii) continue;
      // For Traditional locale, prefer aliases containing 約/紀/書/類
      // etc. Quick heuristic: if zh-Hant requested and alias has
      // any traditional-only character, take it. Otherwise the
      // first non-ASCII alias works.
      if (widget.locale == 'zh-Hant') {
        // crude check: any of the obvious traditional-only chars
        // we know exist in our aliases
        if (alias.contains(RegExp(r'[紀書師後傳記從約馬撒書創利亞]'))) {
          return alias;
        }
      } else {
        return alias;
      }
    }
    // Fallback to canonical if no alias found
    return canonical;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = widget.settings;
    final fs = settings.fontSize;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollController) => Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title + step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _titleForStep(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
                if (_step != _PickerStep.book)
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      uiStrings['back']?[widget.locale] ?? 'Back',
                      style: TextStyle(fontSize: fs - 2),
                    ),
                    onPressed: _goBackOneStep,
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  tooltip: uiStrings['close']?[widget.locale] ?? 'Close',
                ),
              ],
            ),
          ),
          // Breadcrumb of choices made so far
          if (_step != _PickerStep.book) _buildBreadcrumb(scheme, fs),
          const Divider(height: 1),
          Expanded(
            child: _buildGrid(scrollController, scheme, fs),
          ),
        ],
      ),
    );
  }

  String _titleForStep() {
    final k = switch (_step) {
      _PickerStep.book => 'notePickerPickBook',
      _PickerStep.chapter => 'notePickerPickChapter',
      _PickerStep.verse => 'notePickerPickVerse',
    };
    final fallback = switch (_step) {
      _PickerStep.book => 'Pick a book',
      _PickerStep.chapter => 'Pick a chapter',
      _PickerStep.verse => 'Pick a verse',
    };
    return uiStrings[k]?[widget.locale] ?? fallback;
  }

  Widget _buildBreadcrumb(ColorScheme scheme, double fs) {
    final parts = <String>[];
    if (_selectedBookCanonical != null) {
      parts.add(_displayBookName(_selectedBookCanonical!));
    }
    if (_selectedChapter != null) parts.add('${_selectedChapter!}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final p in parts)
            Chip(
              label: Text(p, style: TextStyle(fontSize: fs - 4)),
              backgroundColor:
                  scheme.primaryContainer.withValues(alpha: 0.6),
              labelStyle: TextStyle(color: scheme.onPrimaryContainer),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(
      ScrollController scrollController, ColorScheme scheme, double fs) {
    switch (_step) {
      case _PickerStep.book:
        return _buildBookGrid(scrollController, scheme, fs);
      case _PickerStep.chapter:
        return _buildChapterGrid(scrollController, scheme, fs);
      case _PickerStep.verse:
        return _buildVerseGrid(scrollController, scheme, fs);
    }
  }

  /// The book step, in sections.
  ///
  /// 2026-09-20: it was one flat grid of every book the version has —
  /// 66 identical pills in canonical order, which is a list you read
  /// rather than a list you navigate. 「current book 分新旧约之类的 这样
  /// 就更加清晰和navigate」. Three sections now: the chapter the reader
  /// came from (one tap, and it is almost always the one they want,
  /// because a note is being written ON that verse), then 旧约, then
  /// 新约, each under its own heading.
  Widget _buildBookGrid(
      ScrollController scrollController, ColorScheme scheme, double fs) {
    // Use canonical 66-book ordering, BUT filter to books actually
    // present in `mp.verses` (some NT-only versions don't have OT).
    final available = standardBookOrder
        .where((b) => _chaptersByBook.containsKey(b))
        .toList();
    final current = _currentCanonicalBook();
    final ot = [for (final b in available) if (canonicalOtBooks.contains(b)) b];
    final nt = [for (final b in available) if (canonicalNtBooks.contains(b)) b];
    // Anything the canon lists neither way (an imported edition's own
    // book) still has to be reachable.
    final rest = [
      for (final b in available)
        if (!canonicalOtBooks.contains(b) && !canonicalNtBooks.contains(b)) b
    ];

    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 160,
      mainAxisExtent: 48,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    );

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: fs - 4,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );

    SliverGrid gridOf(List<String> books) => SliverGrid(
          gridDelegate: grid,
          delegate: SliverChildBuilderDelegate(
            (_, i) => _bookTile(books[i], scheme, fs),
            childCount: books.length,
          ),
        );

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 4)),
        if (current != null && _chaptersByBook.containsKey(current)) ...[
          SliverToBoxAdapter(
            child: heading(_s('notePickerCurrentBook', 'Where you are')),
          ),
          SliverGrid(
            gridDelegate: grid,
            delegate: SliverChildBuilderDelegate(
              (_, __) => _bookTile(current, scheme, fs, emphasised: true),
              childCount: 1,
            ),
          ),
        ],
        if (ot.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: heading(_s('notePickerOldTestament', 'Old Testament')),
          ),
          gridOf(ot),
        ],
        if (nt.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: heading(_s('notePickerNewTestament', 'New Testament')),
          ),
          gridOf(nt),
        ],
        if (rest.isNotEmpty) gridOf(rest),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  /// The reader's current book as a canonical English name, or null.
  String? _currentCanonicalBook() {
    final raw = widget.mainProvider.currentBook;
    if (raw == null || raw.isEmpty) return null;
    return bookNameToEnglish[raw] ?? raw;
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  Widget _bookTile(String canonical, ColorScheme scheme, double fs,
      {bool emphasised = false}) {
    final label = _displayBookName(canonical);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide(
            color: emphasised ? scheme.primary : scheme.outlineVariant),
        backgroundColor:
            emphasised ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      ),
      onPressed: () {
        setState(() {
          _selectedBookCanonical = canonical;
          _selectedChapter = null;
          _step = _PickerStep.chapter;
        });
      },
      child: Text(
        label,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fs - 3,
          fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildChapterGrid(
      ScrollController scrollController, ColorScheme scheme, double fs) {
    final chapters = _chaptersByBook[_selectedBookCanonical!] ?? const <int>[];
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisExtent: 48,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: chapters.length,
      itemBuilder: (_, i) {
        final ch = chapters[i];
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          onPressed: () {
            setState(() {
              _selectedChapter = ch;
              _step = _PickerStep.verse;
            });
          },
          child: Text('$ch', style: TextStyle(fontSize: fs - 2)),
        );
      },
    );
  }

  Widget _buildVerseGrid(
      ScrollController scrollController, ColorScheme scheme, double fs) {
    // 2026-05-19 (v1.2.61): verse step is now a vertical, scrollable
    // list of full-text verses with multi-select. The user can tap
    // any number of them; the bottom bar previews the compact ref
    // string being built and the Insert button emits it.
    final verses =
        _verseObjectsIn(_selectedBookCanonical!, _selectedChapter!);
    // 2026-06-18 (v1.3.90): the inserted reference now reads in the
    // user's language. `_displayBookName` returns the localized book
    // name (English for `en`); crucially it picks that name straight out
    // of `bookNameToEnglish`, so the parser resolves it back to the
    // canonical English book — the picker → insert → re-parse round-trip
    // stays lossless and the chip stays tappable.
    final preview = formatCompactReference(
      englishBook: _selectedBookCanonical!,
      chapter: _selectedChapter!,
      verses: _selectedVerses.toList(),
      displayBook: _displayBookName(_selectedBookCanonical!),
    );
    return Column(
      children: [
        // Selection-summary bar above the list — gives the user
        // continuous feedback on what they're building.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  preview.isEmpty
                      ? (uiStrings['notePickerSelectVerses']
                              ?[widget.locale] ??
                          'Tap one or more verses below')
                      : preview,
                  style: TextStyle(
                    fontSize: fs - 3,
                    color: preview.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                    fontWeight: preview.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedVerses.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip:
                      uiStrings['notePickerClearSelection']?[widget.locale] ??
                          'Clear selection',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      setState(() => _selectedVerses.clear()),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _selectedVerses.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(preview),
                child: Text(
                  uiStrings['notePickerInsert']?[widget.locale] ??
                      'Insert',
                  style: TextStyle(fontSize: fs - 3),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: verses.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: scheme.outlineVariant),
            itemBuilder: (_, i) {
              final v = verses[i];
              final selected = _selectedVerses.contains(v.verse);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedVerses.remove(v.verse);
                    } else {
                      _selectedVerses.add(v.verse);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Verse number + checkmark indicator
                      SizedBox(
                        width: 32,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              v.verseLabel,
                              style: TextStyle(
                                fontSize: fs - 2,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: scheme.primary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Verse text (sanitized — no <note: …> popup
                      // markup, no `{phrase}` braces, no `\n` line
                      // breaks; just clean reading text).
                      Expanded(
                        child: Text(
                          sanitizeForSearch(v.text),
                          style: TextStyle(
                            fontSize: fs - 2,
                            color: selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _goBackOneStep() {
    setState(() {
      if (_step == _PickerStep.verse) {
        _step = _PickerStep.chapter;
        _selectedChapter = null;
        _selectedVerses.clear();
      } else if (_step == _PickerStep.chapter) {
        _step = _PickerStep.book;
        _selectedBookCanonical = null;
      }
    });
  }
}

/// Public entry — opens the sheet, awaits the user's choice, and
/// returns the `[Book Ch:V]` string (or null if cancelled).
Future<String?> showNoteReferencePicker({
  required BuildContext context,
  required String locale,
  required MainProvider mainProvider,
  required AppSettings settings,
}) {
  return showModalBottomSheet<String>(
    // useSafeArea: without it Flutter wraps the sheet in
    // MediaQuery.removePadding(removeTop: true), so any SafeArea
    // INSIDE the sheet sees padding.top == 0 and does nothing —
    // the header then draws under the clock and the notch.
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => NoteReferencePickerSheet(
      locale: locale,
      mainProvider: mainProvider,
      settings: settings,
    ),
  );
}

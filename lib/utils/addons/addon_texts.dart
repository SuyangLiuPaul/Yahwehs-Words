/// The sentences the importer says, from the ui-strings tables.
///
/// Pure Dart (the tables are plain maps), so the wording is testable without
/// a widget — and every refusal and every report line is exercised in all
/// three locales by `test/addons/addon_texts_test.dart`.
library;

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';

String _t(String key, String locale) =>
    uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? key;

/// `{name}` placeholders replaced.
String addonFmt(String template, Map<String, Object> values) {
  var s = template;
  values.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

String addonText(String key, String locale, [Map<String, Object> values = const {}]) =>
    addonFmt(_t(key, locale), values);

/// Why a file was refused, in the reader's language, saying what to do next.
String addonProblemText(ImportProblem p, String locale, {String? detail}) {
  var d = detail ?? '';
  if (p == ImportProblem.notABible) {
    d = _t('addonKind_${_kindKey(detail)}', locale);
  }
  return addonFmt(_t('addonProblem_${p.name}', locale), {'detail': d});
}

String _kindKey(String? detail) {
  switch (detail) {
    case 'commentary':
    case 'dictionary':
    case 'crossReferences':
      return detail!;
    default:
      return 'other';
  }
}

/// The lines of the import report: what was kept, and — never silently —
/// what was not. Empty lines are omitted; order is by how much a reader
/// would want to know.
List<String> addonReportLines(
  ImportReport r,
  ModuleMeta meta,
  String locale, {
  required int books,
}) {
  String f(String key, Map<String, Object> v) => addonText(key, locale, v);
  final out = <String>[
    f('addonReportAccepted', {'n': r.versesAccepted, 'b': books}),
  ];
  if (r.booksDropped.isNotEmpty) {
    final names = r.booksDropped.keys.take(8).join(', ') +
        (r.booksDropped.length > 8 ? '…' : '');
    out.add(f('addonReportBooksDropped',
        {'n': r.booksDropped.length, 'names': names}));
  }
  if (r.versesDroppedOutsideCanon > 0) {
    out.add(f('addonReportVersesDropped', {'n': r.versesDroppedOutsideCanon}));
  }
  if (r.versesDuplicate > 0) {
    out.add(f('addonReportDuplicates', {'n': r.versesDuplicate}));
  }
  if (r.superscriptionsFolded > 0) {
    out.add(f('addonReportSuper', {'n': r.superscriptionsFolded}));
  }
  if (r.headingsDropped > 0) {
    out.add(f('addonReportHeadings', {'n': r.headingsDropped}));
  }
  if (r.crossRefsDropped > 0) {
    out.add(f('addonReportCrossRefs', {'n': r.crossRefsDropped}));
  }
  if (r.notesKept > 0) {
    out.add(f('addonReportNotes', {'n': r.notesKept}));
  }
  if (meta.strongsPresent) out.add(_t('addonReportStrongs', locale));
  for (final w in r.warnings.take(6)) {
    out.add(addonFmt(_t('addonWarn_${w.code}', locale), {'detail': w.detail}));
  }
  if (r.strayBracketsStripped > 0) {
    out.add(f('addonReportStrays', {'n': r.strayBracketsStripped}));
  }
  return out;
}

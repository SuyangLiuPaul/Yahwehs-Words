/// Typesetting for the Berean Interlinear's deliberately empty glosses.
///
/// The source pairs an untranslated Greek word with `()`. Retain the
/// Greek word and the imported source files; only omit the empty English
/// wrapper in the reader. Other editions must keep their own punctuation.
String formatBereanInterlinearText(String text, {required String version}) {
  if (version.toLowerCase() != 'bib') return text;
  return text.replaceAll(RegExp(r'[ \t]*\(\s*\)'), '');
}

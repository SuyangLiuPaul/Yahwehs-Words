import '../constants/book_groups.dart';
import 'version_mapper.dart' show toEnglish;

const hebrewBibleScope = '@hebrew-bible';
const greekBibleScope = '@greek-bible';
bool isTestamentScope(String? scope) => scope == hebrewBibleScope || scope == greekBibleScope;
bool matchesSearchBookScope(String book, String? scope) {
  if (scope == null) return true;
  final english = toEnglish(book) ?? book;
  if (scope == hebrewBibleScope) return canonicalOtBooks.contains(english);
  if (scope == greekBibleScope) return canonicalNtBooks.contains(english);
  return english == (toEnglish(scope) ?? scope);
}
String searchBookScopeLabel(String scope, String locale) {
  if (!isTestamentScope(scope)) return scope;
  final hebrew = scope == hebrewBibleScope;
  if (locale == 'zh-Hans') return hebrew ? '希伯来圣经（旧约）' : '希腊圣经（新约）';
  if (locale == 'zh-Hant') return hebrew ? '希伯來聖經（舊約）' : '希臘聖經（新約）';
  return hebrew ? 'Hebrew Bible (OT)' : 'Greek Bible (NT)';
}

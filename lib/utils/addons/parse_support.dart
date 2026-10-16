/// Small helpers every parser shares.
library;

import 'addon_types.dart';

/// Rows between yields to the event loop. The web has no real isolates, so a
/// 30,000-verse import keeps the page alive by running in slices.
const int kYieldEvery = 2000;

/// What a parser is told about the world it runs in.
class ParseContext {
  ParseContext({this.cancel, this.onProgress});

  final CancelToken? cancel;
  final ProgressCallback? onProgress;

  /// Throw [ImportRefusal] (cancelled) if the reader pressed Cancel.
  void checkCancelled() {
    if (cancel?.cancelled ?? false) {
      throw const ImportRefusal(ImportProblem.cancelled);
    }
  }

  /// Call once per row; yields and checks for cancellation periodically.
  Future<void> tick(int n, String phase, int total) async {
    if (n % kYieldEvery != 0) return;
    checkCancelled();
    onProgress?.call(phase, n, total);
    await yieldToEventLoop();
  }
}

/// Cell → string, tolerating NULL, numbers and blobs.
String cellString(Object? v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

/// Cell → int, tolerating numeric text and floats; null when it is neither.
int? cellInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v == v.roundToDouble() ? v.toInt() : null;
  if (v is String) {
    final t = v.trim();
    return int.tryParse(t) ?? (double.tryParse(t)?.toInt());
  }
  return null;
}

/// A "true"-ish value as the SQLite modules spell it.
bool cellTrue(Object? v) {
  if (v == null) return false;
  if (v is int) return v != 0;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

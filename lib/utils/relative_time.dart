/// 2026-05-24 (v1.2.91): shared relative-time formatter ("5 分钟前 /
/// 5 minutes ago"). Pulled out of settings_page.dart's private
/// `_relative` helper so the search-page recent-queries rows can
/// reuse the same formatting without duplicating the logic.
///
/// Format buckets (locale-aware, with zh-Hans / zh-Hant / en):
///   < 30 s        → "刚刚" / "剛剛" / "just now"
///   < 60 s        → "不到一分钟前" / "不到一分鐘前" / "less than a minute ago"
///   < 60 min      → "5 分钟前" / "5 分鐘前" / "5 minutes ago"
///   < 24 h        → "3 小时前" / "3 小時前" / "3 hours ago"
///   otherwise     → "2 天前" / "2 days ago" (天/前 are script-invariant)
///
/// Caller is expected to render the result as a small caption. The
/// helper does not refresh on its own — wrap in a periodic rebuild
/// (e.g. a 30 s Timer) if you need the label to stay accurate while
/// the screen is open.
String relativeTime(DateTime when, String locale) {
  // Normalise both sides to UTC so a viewer crossing a DST boundary
  // doesn't produce a negative difference for a stamp written 30 min
  // ago. `when` may have been constructed locally — fine, .toUtc()
  // is a no-op for already-UTC times.
  final now = DateTime.now().toUtc();
  final whenUtc = when.toUtc();
  final diff = now.difference(whenUtc);
  // Clamp clock-skew futures (remote-sync clients may stamp slightly
  // ahead of the local clock) to "just now" rather than rendering
  // "-3 seconds ago".
  if (diff.isNegative) return _justNow(locale);
  // `AppSettings.locale` is normally 'zh-Hans' / 'zh-Hant' / 'en', but an
  // imported settings blob restores `locale` with no validation (see
  // AppSettings.fromJson), so an unrecognised 'zh-*' tag must still land on
  // Simplified rather than falling through to English.
  final isTraditional = locale == 'zh-Hant';
  final isZh = locale.startsWith('zh');
  if (diff.inSeconds < 30) return _justNow(locale);
  if (diff.inMinutes < 1) {
    if (isTraditional) return '不到一分鐘前';
    return isZh ? '不到一分钟前' : 'less than a minute ago';
  }
  if (diff.inMinutes < 60) {
    if (isTraditional) return '${diff.inMinutes} 分鐘前';
    return isZh
        ? '${diff.inMinutes} 分钟前'
        : '${diff.inMinutes} minute${diff.inMinutes == 1 ? "" : "s"} ago';
  }
  if (diff.inHours < 24) {
    if (isTraditional) return '${diff.inHours} 小時前';
    return isZh
        ? '${diff.inHours} 小时前'
        : '${diff.inHours} hour${diff.inHours == 1 ? "" : "s"} ago';
  }
  // 天/前 are identical glyphs in Simplified and Traditional, so this
  // bucket needs no isTraditional branch.
  return isZh
      ? '${diff.inDays} 天前'
      : '${diff.inDays} day${diff.inDays == 1 ? "" : "s"} ago';
}

String _justNow(String locale) {
  if (locale == 'zh-Hant') return '剛剛';
  return locale.startsWith('zh') ? '刚刚' : 'just now';
}

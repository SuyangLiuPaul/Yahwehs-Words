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

/// 2026-09-22: moved out of `reading_stats_page.dart`'s private
/// `_relativeTime` so it stops re-duplicating [relativeTime]'s
/// `locale.startsWith('zh')` branching. It is a SECOND formatter beside
/// [relativeTime], not a caller of it: [relativeTime] buckets by elapsed
/// seconds/minutes/hours down to "just now"; this one only cares which
/// *calendar day* something fell on, because the stats page's own
/// docstring says "the exact second a chapter was opened is neither
/// interesting nor something the dwell-gated record can claim precisely."
/// Collapsing the two would trade 今天/昨天/ISO-date for 刚刚/N 分钟前 on a
/// page that deliberately wants day granularity — do not do that.
///
/// Buckets, all script-invariant so no `isTraditional` branch is needed:
///   same calendar day (incl. clock-skew futures) → "今天" / "Today"
///   previous calendar day                        → "昨天" / "Yesterday"
///   2-29 calendar days back                       → "N 天前" / "N days ago"
///   30+ calendar days back                        → an ISO date via [isoDate]
///
/// Compares calendar dates, not elapsed `Duration.inDays`: a chapter
/// opened at 23:30 and viewed at 08:00 the next morning is 8.5 elapsed
/// hours, which `inDays` would round down to 0 and misreport as "today"
/// when it was actually read yesterday.
///
/// The day-count itself is done via [DateTime.utc] built from [at] and
/// [now]'s local `year`/`month`/`day` fields, NOT via two local midnights
/// (`DateTime(y, m, d)`) differenced directly: a local midnight-to-midnight
/// `Duration` is only 24h apart on an ordinary day. On the 23-hour day a
/// DST region loses each spring, two local midnights 2 calendar days apart
/// are only 47 elapsed hours, and `Duration.inDays` truncates that to 1 —
/// which would put a reading from two days ago in the "Yesterday" bucket.
/// [DateTime.utc] has no DST, so differencing two UTC instants built from
/// the same y/m/d numbers is pure date arithmetic: always an exact
/// multiple of 24h, regardless of what the local clock did on the days
/// in between.
///
/// [at] is expected to be a local `DateTime` (as `ReadingHistoryEntry.at`
/// is), and [now] defaults to the real local clock — pass it explicitly
/// only from a test.
String relativeDay(DateTime at, String locale, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfToday = DateTime.utc(today.year, today.month, today.day);
  final startOfAt = DateTime.utc(at.year, at.month, at.day);
  final days = startOfToday.difference(startOfAt).inDays;
  final zh = locale.startsWith('zh');
  if (days <= 0) return zh ? '今天' : 'Today';
  if (days == 1) return zh ? '昨天' : 'Yesterday';
  if (days < 30) return zh ? '$days 天前' : '$days days ago';
  return isoDate(at);
}

/// `YYYY-MM-DD`, zero-padded. Used by [relativeDay]'s 30+ day fallback and
/// by `reading_stats_page.dart`'s period line ("Covers reading recorded
/// on this device since {date}").
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 2026-09-08: the words the fuzzy search says out loud.
///
/// Shaped like `uiStrings` — a `Map<String, Map<String, String>>` keyed
/// by string-key then by locale, every key carrying all three of
/// `zh-Hans`, `zh-Hant` and `en`. Kept in its own file rather than
/// folded into `ui_strings.dart` because that file is 400 KB and more
/// than one agent appends to it; a shared file is where two of them
/// collide. Every lookup here goes through `fuzzySearchStrings`, never
/// `uiStrings`, so the two cannot be confused at a call site.
///
/// A NOTE ON THE TWO CHINESE COLUMNS: `zh-Hant` is not `zh-Hans` with
/// the characters swapped one for one. Where a string uses no character
/// that differs between the scripts the same text appears in both
/// columns on purpose, because forcing a difference where none exists
/// is noise rather than correctness. Where a character does differ
/// (词/詞, 异/異, 开/開, 寻/尋, 时/時) the Traditional column uses the
/// Traditional form throughout.
///
/// ## Why every one of these is short
///
/// Four of them are appended to a verse reference in the result list —
/// `创世纪 1:1 · 异体字` — in a row whose title line is already carrying
/// a book name, a chapter and a verse, with the scripture underneath. A
/// label that wraps that line costs more than it explains. So each is
/// two or three characters in Chinese and two words in English, and
/// each names WHICH looser reading found the row rather than saying
/// "approximate" four different ways: a reader who can see that 磯法
/// matched 矶法 has been told something, and a reader who is told
/// "fuzzy" has not.
library;

const Map<String, Map<String, String>> fuzzySearchStrings = {
  // ── The setting itself ──────────────────────────────────────────────
  //
  // Written for the Settings row that will sit beside "Ignore vowel
  // points and accents" (`searchIgnoresPointing` in `ui_strings.dart`),
  // whose switch this one is modelled on. The strings are here before
  // that row exists so the page that builds it reads a string instead of
  // inventing one.

  /// Search chips and this preference operate the same global matcher.
  /// Literal hits remain literal; additional hits say why they matched.
  'fuzzySearchSetting': {
    'zh-Hans': '模糊搜索',
    'zh-Hant': '模糊搜尋',
    'en': 'Fuzzy search',
  },
  'fuzzySearchSettingSubtitle': {
    'zh-Hans':
        '匹配简繁写法、圣经名称别称和英文词形，例如 磯法 / 矶法、loved / love。扩展结果会标示原因。',
    'zh-Hant':
        '匹配簡繁寫法、聖經名稱別稱和英文詞形，例如 磯法 / 矶法、loved / love。擴展結果會標示原因。',
    'en':
        'Adds script variants, Bible name aliases and English inflections, such as 磯法 / 矶法 and loved / love. Expanded hits are labelled.',
  },

  // ── Row labels, one per rung ────────────────────────────────────────
  //
  // `fuzzy_search.dart` names five rungs; only four appear here, because
  // the literal rung is the one that needs no label. A row with no label
  // contains what the reader typed. That is the whole contract, and it
  // is why these are per-rung rather than one shared "approximate": an
  // unlabelled row and a labelled one have to mean different things at a
  // glance, and four labels that name their reason are still a glance.

  /// The same word in the other Chinese script — 磯法 matching 矶法.
  /// Nothing about the query's meaning changed; only which keyboard the
  /// reader was typing on.
  'fuzzyLabelScript': {
    'zh-Hans': '异体字',
    'zh-Hant': '異體字',
    'en': 'other script',
  },

  /// Another spelling of the same name or word, from the synonym groups
  /// in `search_Bible name aliases.dart` — 上帝 matching 神, 弥赛亚 matching
  /// 基督. The English reads "other spelling" and not "synonym" because
  /// every group in that file is one thing under two names, never two
  /// things that mean roughly the same.
  'fuzzyLabelSynonym': {
    'zh-Hans': '同名异写',
    'zh-Hant': '同名異寫',
    'en': 'other spelling',
  },

  /// English inflection — `loved` matching "love". Named for what
  /// changed (the form of the word) rather than for the algorithm that
  /// found it; "Porter stem" is true and tells a reader nothing.
  'fuzzyLabelStem': {
    'zh-Hans': '词形',
    'zh-Hant': '詞形',
    'en': 'word form',
  },

  /// The loosest rung: the query's own words, found in the verse but not
  /// side by side. This is the only label that has to warn as well as
  /// explain, because it is the only rung where the verse may not say
  /// what the reader asked — 信心的祷告 occurs in no verse, and this
  /// rung answers it with the verses that hold 信心, 祷 and 告 in
  /// separate places.
  'fuzzyLabelSegmented': {
    'zh-Hans': '词分开',
    'zh-Hant': '詞分開',
    'en': 'words apart',
  },

  /// A fifth rung, YsWords' own rather than one of `fuzzy_search.dart`'s
  /// ported five (see `fuzzy_result_label.dart`'s `_pinyinMatches`):
  /// romanised Chinese — `yesu` or `ys` matching 耶稣. Named for what the
  /// reader typed, the same convention as the other four.
  'fuzzyLabelPinyin': {
    'zh-Hans': '拼音',
    'zh-Hant': '拼音',
    'en': 'pinyin',
  },
};

/// Search options are named where the reader actually types the query.
const searchOptionsStrings = <String, Map<String, String>>{
  'fuzzy': {'en': 'Fuzzy search', 'zh-Hans': '模糊搜索', 'zh-Hant': '模糊搜尋'},
  'pinyin': {'en': 'Pinyin search', 'zh-Hans': '拼音搜索', 'zh-Hant': '拼音搜尋'},
  'fuzzyHelp': {
    'en':
        'Adds script variants, synonyms and English inflections; expanded hits are labelled.',
    'zh-Hans': '匹配简繁写法、近义词和英文词形；扩展结果会标示原因。',
    'zh-Hant': '匹配簡繁寫法、近義詞和英文詞形；擴展結果會標示原因。'
  },
  'pinyinHelp': {
    'en':
        'Search Chinese verses using yesu, ye su, yē sū, or initials such as ys.',
    'zh-Hans': '用 yesu、ye su、yē sū 或首字母 ys 搜索中文经文。',
    'zh-Hant': '用 yesu、ye su、yē sū 或首字母 ys 搜尋中文經文。'
  },
  'plainOnly': {
    'en':
        'These options apply to plain text. Strong’s numbers and operator queries keep their exact rules.',
    'zh-Hans': '这些选项只用于普通文本。Strong’s 编号和运算符查询仍按精确规则检索。',
    'zh-Hant': '這些選項只用於普通文字。Strong’s 編號和運算符查詢仍按精確規則檢索。'
  },
  'chineseOnly': {
    'en':
        'Pinyin searches Chinese text in the selected Bible edition. Choose a Chinese edition for yesu / ys.',
    'zh-Hans': '拼音只匹配所选译本的中文经文。搜索 yesu / ys 时请选中文译本。',
    'zh-Hant': '拼音只匹配所選譯本的中文經文。搜尋 yesu / ys 時請選中文譯本。'
  },
};
String searchOptionText(String key, String locale) =>
    searchOptionsStrings[key]?[locale] ??
    searchOptionsStrings[key]?['en'] ??
    key;

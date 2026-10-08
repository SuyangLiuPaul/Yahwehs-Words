/// Search options are named where the reader actually types the query.
const searchOptionsStrings = <String, Map<String, String>>{
  'fuzzy': {'en': 'Fuzzy search', 'zh-Hans': '模糊搜索', 'zh-Hant': '模糊搜尋'},
  'fuzzyHelp': {
    'en':
        'Adds script variants, Bible name aliases and English inflections; expanded hits are labelled.',
    'zh-Hans': '匹配简繁写法、圣经名称别称和英文词形；扩展结果会标示原因。',
    'zh-Hant': '匹配簡繁寫法、聖經名稱別稱和英文詞形；擴展結果會標示原因。'
  },
  'modeHelp': {
    'en':
        'Off: exact text. On: script variants, Bible name aliases and English word forms.',
    'zh-Hans': '关闭为精确搜索；开启匹配简繁写法、圣经名称别称和英文词形。',
    'zh-Hant': '關閉為精確搜尋；開啟匹配簡繁寫法、聖經名稱別稱和英文詞形。'
  },
  'plainOnly': {
    'en':
        'These options apply to plain text. Strong’s numbers and operator queries keep their exact rules.',
    'zh-Hans': '这些选项只用于普通文本。Strong’s 编号和运算符查询仍按精确规则检索。',
    'zh-Hant': '這些選項只用於普通文字。Strong’s 編號和運算符查詢仍按精確規則檢索。'
  },
};
String searchOptionText(String key, String locale) =>
    searchOptionsStrings[key]?[locale] ??
    searchOptionsStrings[key]?['en'] ??
    key;

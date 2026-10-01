/// The one word this app puts in front of a date it cannot settle.
///
/// It lived in three places, and all three chose the Chinese form with a
/// single `locale.startsWith('zh')` test — which is Simplified 约, shown
/// to Traditional readers on the wheel (161 events), the Bible timeline
/// (75 of its 98) and the family tree. That is not a house style: the
/// files around it already distinguish the scripts, `岁` from `歲` two
/// lines below one of the offending branches
/// (`biblical_person.dart:199`) and `主后` from `主後` in
/// `ui_strings.dart`. It is the same slip made three times, which is
/// what a duplicated locale test produces.
///
/// The prefix carries its own trailing space so a caller never has to
/// decide, and every surface reads the same. `c. 586 BC`, `约 主前586`,
/// `約 主前586`.
library;

String approximatePrefix(String locale) => switch (locale) {
      'zh-Hant' => '約 ',
      _ when locale.startsWith('zh') => '约 ',
      _ => 'c. ',
    };

/// "In the year N after creation", the Anno Mundi label.
///
/// 后 is a queen and 後 is "after"; only Simplified merges them, so a
/// Traditional reader reading 创世后 is reading "the queen of creation".
String annoMundiLabel(int year, String locale) => switch (locale) {
      'zh-Hant' => '創世後 $year 年',
      _ when locale.startsWith('zh') => '创世后 $year 年',
      _ => 'AM $year',
    };

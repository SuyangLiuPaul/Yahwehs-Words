import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/services/fetch_books.dart' show standardBookOrder;
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/utils/version_mapper.dart' show localeAwareBookName;
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

const kStudyTestamentsPath = '/study/testaments';

/// Hidden page (reached by URL only): the New Testament and the Old Testament,
/// set side by side. Tab 1: every quotation / allusion the app's own LEB and
/// NET notes mark, with both texts. Tab 2: types the New Testament itself
/// names. Tab 3: reciprocal cross-references. Source of the data:
/// bible-sermon-research/v3 (generator + checks live outside the repo).
class StudyTestamentsPage extends StatefulWidget {
  const StudyTestamentsPage({super.key, this.loader});

  /// Test hook.
  final Future<String> Function(String)? loader;

  @override
  State<StudyTestamentsPage> createState() => _StudyTestamentsPageState();
}

class _StudyTestamentsPageState extends State<StudyTestamentsPage> {
  late Future<StudyTestaments> _future;
  // tab 1
  bool _byOt = false;
  String? _ntBook, _otBook, _type;
  int? _ntChapter, _otChapter;
  bool _formulaOnly = false;
  String _query = '';
  // tab 3
  String? _rNtBook, _rOtBook;
  int? _rNtChapter, _rOtChapter;
  String _rQuery = '';

  @override
  void initState() {
    super.initState();
    _future = StudyData.loadTestaments(loader: widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          actions: const [LanguageSwitcherButton(alwaysVisible: true)],
          title: Text(studyL(locale, 'New Testament ↔ Old Testament',
              '新约与旧约的对应', '新約與舊約的對應')),
          bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: studyL(locale, 'Quotations', '引用与应验', '引用與應驗')),
                Tab(text: studyL(locale, 'Types', '预表', '預表')),
                Tab(text: studyL(locale, 'Related', '相关经文', '相關經文')),
                Tab(text: studyL(locale, 'About', '说明', '說明')),
              ]),
        ),
        body: FutureBuilder<StudyTestaments>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                  child: FilledButton(
                      onPressed: () => setState(() => _future =
                          StudyData.loadTestaments(loader: widget.loader)),
                      child: Text(studyL(locale, 'Retry', '重试', '重試'))));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!;
            return TabBarView(children: [
              _quotations(d, locale),
              _typology(d, locale),
              _related(d, locale),
              _about(d, locale),
            ]);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 引用与应验
  Widget _quotations(StudyTestaments d, String locale) {
    final counts = <String, int>{};
    for (final e in d.entries) {
      counts[e.main] = (counts[e.main] ?? 0) + 1;
    }
    bool keep(StudyCorrespondence e) =>
        studyInPassage(e.ntChapters, _ntBook, _ntChapter) &&
        studyInPassage(e.otChapters, _otBook, _otChapter) &&
        (_type == null || e.ot.any((o) => o.type == _type)) &&
        (!_formulaOnly || e.formula != null) &&
        e.matches(_query, locale);
    final shown = d.entries.where(keep).toList();
    // groups: by NT book (default) or by OT book
    final groups = <String, List<StudyCorrespondence>>{};
    if (_byOt) {
      for (final e in shown) {
        final books = <String>{
          for (final c in e.otChapters)
            if (_otBook == null || c.$1 == _otBook) c.$1
        };
        for (final b in books) {
          groups.putIfAbsent(b, () => []).add(e);
        }
      }
    } else {
      for (final e in shown) {
        final b = studyParseRef(e.nt)!.book;
        groups.putIfAbsent(b, () => []).add(e);
      }
    }
    final order = _byOt
        ? standardBookOrder.sublist(0, 39)
        : standardBookOrder.sublist(39);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
            title: studyL(locale, 'Where the New Testament speaks the Old',
                '新约怎样引用旧约', '新約怎樣引用舊約'),
            subtitle: studyL(
                locale,
                '${d.entries.length} New Testament passages that quote, paraphrase or allude to the Old Testament, each with both texts side by side. Taken from the notes of the app’s own LEB and NET Bibles.',
                '${d.entries.length} 处新约经文引用、意译或暗指旧约，每处都把新旧约经文并排列出。依据应用自带的 LEB 与 NET 译本的脚注整理。',
                '${d.entries.length} 處新約經文引用、意譯或暗指舊約，每處都把新舊約經文並排列出。依據應用自帶的 LEB 與 NET 譯本的腳註整理。'),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in ['quote', 'paraphrase', 'allusion'])
                  GestureDetector(
                    key: ValueKey('type.$t'),
                    onTap: () => setState(() => _type = _type == t ? null : t),
                    child: Opacity(
                        opacity: _type == null || _type == t ? 1 : 0.4,
                        child: StudyBadge(
                            text: '${_typeLabel(t, locale)} ${counts[t] ?? 0}',
                            color: _typeColor(context, t))),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
              key: const ValueKey('study.search'),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: studyL(
                      locale,
                      'Search a passage or a word',
                      '搜索经文或词语',
                      '搜尋經文或詞語'),
                  border: const OutlineInputBorder()),
              onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 10),
          StudyPassageFilter(
              keyPrefix: 'nt',
              label: studyL(locale, 'New Testament book', '新约经卷', '新約經卷'),
              available: {
                for (final e in d.entries) ...e.ntChapters
              },
              book: _ntBook,
              chapter: _ntChapter,
              locale: locale,
              onChanged: (b, c) => setState(() {
                    _ntBook = b;
                    _ntChapter = c;
                  })),
          const SizedBox(height: 10),
          StudyPassageFilter(
              keyPrefix: 'ot',
              label: studyL(locale, 'Old Testament book', '旧约经卷', '舊約經卷'),
              available: {
                for (final e in d.entries) ...e.otChapters
              },
              book: _otBook,
              chapter: _otChapter,
              locale: locale,
              onChanged: (b, c) => setState(() {
                    _otBook = b;
                    _otChapter = c;
                  })),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilterChip(
              key: const ValueKey('formula'),
              label: Text(studyL(locale, 'With a “fulfilled / it is written” formula',
                  '带“应验”或“经上记着”的', '帶“應驗”或“經上記著”的')),
              selected: _formulaOnly,
              onSelected: (v) => setState(() => _formulaOnly = v),
            ),
            ChoiceChip(
              key: const ValueKey('sort.nt'),
              label: Text(studyL(locale, 'Order by New Testament', '按新约排序',
                  '按新約排序')),
              selected: !_byOt,
              onSelected: (_) => setState(() => _byOt = false),
            ),
            ChoiceChip(
              key: const ValueKey('sort.ot'),
              label: Text(studyL(locale, 'Order by Old Testament', '按旧约排序',
                  '按舊約排序')),
              selected: _byOt,
              onSelected: (_) => setState(() => _byOt = true),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
              studyL(
                  locale,
                  '${shown.length} of ${d.entries.length} shown',
                  '显示 ${shown.length} / ${d.entries.length}',
                  '顯示 ${shown.length} / ${d.entries.length}'),
              style: Theme.of(context).textTheme.labelLarge),
          if (shown.isEmpty)
            Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                    child: Text(studyL(locale, 'No matching passages',
                        '没有匹配的经文', '沒有匹配的經文')))),
          for (final b in order)
            if (groups[b] != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Text(
                    '${localeAwareBookName(b, locale)} · ${groups[b]!.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              for (final e in groups[b]!)
                _CorrespondenceCard(
                    key: ValueKey('ct.${_byOt ? '$b.' : ''}${e.id}'),
                    entry: e,
                    locale: locale),
            ],
        ]);
  }

  // ------------------------------------------------------------ 预表
  Widget _typology(StudyTestaments d, String locale) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
            title: studyL(locale, 'Types the New Testament names',
                '新约自己指明的预表', '新約自己指明的預表'),
            subtitle: studyL(
                locale,
                '${d.typology.length} places where the New Testament itself calls an Old Testament person, event or institution a type, shadow, example or allegory. Each shows the New Testament’s own word for it.',
                '${d.typology.length} 处新约自己说明旧约的人、事、制度是预像、影儿、榜样或比方；每条都标出新约自己用的词。',
                '${d.typology.length} 處新約自己說明舊約的人、事、制度是預像、影兒、榜樣或比方；每條都標出新約自己用的詞。'),
          ),
          const SizedBox(height: 14),
          for (final t in d.typology) _TypologyCard(item: t, locale: locale),
        ]);
  }

  // ------------------------------------------------------------ 相关经文
  Widget _related(StudyTestaments d, String locale) {
    bool keep(StudyRelated r) {
      final nt = studyChaptersOf([r.nt]);
      final ot = studyChaptersOf(r.ot);
      if (!studyInPassage(nt, _rNtBook, _rNtChapter)) return false;
      if (!studyInPassage(ot, _rOtBook, _rOtChapter)) return false;
      final q = _rQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return r.nt.toLowerCase().contains(q) ||
          localizePassage(r.nt, locale).toLowerCase().contains(q) ||
          r.ot.any((o) =>
              o.toLowerCase().contains(q) ||
              localizePassage(o, locale).toLowerCase().contains(q));
    }

    final shown = d.related.where(keep).toList();
    final ntAvail = <(String, int)>{
      for (final r in d.related) ...studyChaptersOf([r.nt])
    };
    final otAvail = <(String, int)>{
      for (final r in d.related) ...studyChaptersOf(r.ot)
    };
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: shown.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudyHeader(
                    title: studyL(locale, 'More related passages',
                        '更多相关经文', '更多相關經文'),
                    subtitle: studyL(
                        locale,
                        'Cross-references between New Testament verses and Old Testament passages, kept only where each side lists the other (Treasury of Scripture Knowledge, with OpenBible.info votes). These are looser than the explicit quotations: tap a passage to read it.',
                        '新约经文与旧约经文之间的交叉引用，只保留双方互相列出的（《圣经串珠》并结合 OpenBible.info 的投票）。比“引用与应验”宽松：点经文即可阅读。',
                        '新約經文與舊約經文之間的交叉引用，只保留雙方互相列出的（《聖經串珠》並結合 OpenBible.info 的投票）。比“引用與應驗”寬鬆：點經文即可閱讀。'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                      key: const ValueKey('related.search'),
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: studyL(locale, 'Search a passage',
                              '搜索经文', '搜尋經文'),
                          border: const OutlineInputBorder()),
                      onChanged: (v) => setState(() => _rQuery = v)),
                  const SizedBox(height: 10),
                  StudyPassageFilter(
                      keyPrefix: 'rnt',
                      label: studyL(
                          locale, 'New Testament book', '新约经卷', '新約經卷'),
                      available: ntAvail,
                      book: _rNtBook,
                      chapter: _rNtChapter,
                      locale: locale,
                      onChanged: (b, c) => setState(() {
                            _rNtBook = b;
                            _rNtChapter = c;
                          })),
                  const SizedBox(height: 10),
                  StudyPassageFilter(
                      keyPrefix: 'rot',
                      label: studyL(
                          locale, 'Old Testament book', '旧约经卷', '舊約經卷'),
                      available: otAvail,
                      book: _rOtBook,
                      chapter: _rOtChapter,
                      locale: locale,
                      onChanged: (b, c) => setState(() {
                            _rOtBook = b;
                            _rOtChapter = c;
                          })),
                  const SizedBox(height: 6),
                  Text(
                      studyL(
                          locale,
                          '${shown.length} of ${d.related.length} shown',
                          '显示 ${shown.length} / ${d.related.length}',
                          '顯示 ${shown.length} / ${d.related.length}'),
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                ]);
          }
          final r = shown[i - 1];
          final scheme = Theme.of(context).colorScheme;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudyRefChips(refs: [r.nt], locale: locale),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.arrow_downward_rounded,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                          studyL(locale, 'Old Testament', '旧约', '舊約'),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 4),
                    StudyRefChips(refs: r.ot, locale: locale),
                  ]),
            ),
          );
        });
  }

  // ------------------------------------------------------------ 说明
  Widget _about(StudyTestaments d, String locale) {
    Widget bullet(String en, String hs, String ht) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('• ${studyL(locale, en, hs, ht)}',
            style: const TextStyle(fontSize: 15, height: 1.6)));
    final scheme = Theme.of(context).colorScheme;
    final sources = <StudySource>[
      StudySource(
          const StudyText({
            'zh-Hans':
                'OpenBible.info：交叉引用（《圣经串珠》并结合社区投票），CC-BY 4.0',
            'zh-Hant':
                'OpenBible.info：交叉引用（《聖經串珠》並結合社區投票），CC-BY 4.0',
            'en':
                'OpenBible.info: cross-references (Treasury of Scripture Knowledge with community votes), CC-BY 4.0',
          }),
          'https://www.openbible.info/labs/cross-references/'),
    ];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
              title: studyL(locale, 'About this page', '关于这一页', '關於這一頁'),
              subtitle: studyL(
                  locale,
                  'A research page: the New Testament and the Old Testament side by side. It is not linked from anywhere in the app.',
                  '这是一个研究页：把新约与旧约并排对照。应用里没有任何入口指向它。',
                  '這是一個研究頁：把新約與舊約並排對照。應用裡沒有任何入口指向它。')),
          StudyLabel2(studyL(locale, 'Three layers', '三个层次', '三個層次')),
          bullet(
              'Quotations: every New Testament passage that the notes of the app’s own LEB and NET Bibles mark as a quotation, a paraphrase or an allusion, with both texts. Where both notes agree it says so.',
              '引用与应验：应用自带的 LEB 与 NET 译本脚注里，凡标明为引用、意译或暗指旧约的新约经文，都并排列出新旧约经文；两个译本的脚注一致时会注明。',
              '引用與應驗：應用自帶的 LEB 與 NET 譯本腳註裡，凡標明為引用、意譯或暗指舊約的新約經文，都並排列出新舊約經文；兩個譯本的腳註一致時會註明。'),
          bullet(
              'Types: only places where the New Testament itself says an Old Testament person, event or institution is a type, shadow, example or allegory, with its own word.',
              '预表：只收新约自己明说“旧约的人、事、制度是预像、影儿、榜样或比方”的地方，并标出新约用的词。',
              '預表：只收新約自己明說“舊約的人、事、制度是預像、影兒、榜樣或比方”的地方，並標出新約用的詞。'),
          bullet(
              'Related passages: cross-references that both sides list, shown as links only. They are looser than the first two layers.',
              '相关经文：双方互相列出的交叉引用，只作链接；比前两层宽松。',
              '相關經文：雙方互相列出的交叉引用，只作連結；比前兩層寬鬆。'),
          StudyLabel2(studyL(locale, 'How reliable is it', '可靠程度', '可靠程度')),
          bullet(
              'Verse text comes from the app’s own Bibles (Chinese Union Version; KJV in English). Tap a verse to read it in your own Bible.',
              '经文原文取自应用自己的圣经（和合本；英文界面用 KJV）；点经文可在你自己的圣经里阅读。',
              '經文原文取自應用自己的聖經（和合本；英文介面用 KJV）；點經文可在你自己的聖經裡閱讀。'),
          bullet(
              'The list of quotations is only as complete as the two translations’ notes. Some books, above all Revelation, allude to the Old Testament far more often than any note marks; those are in the “Related” tab.',
              '“引用与应验”的完整程度取决于这两个译本的脚注；有些书卷（尤其是启示录）对旧约的暗指，比任何脚注标出的都多，那些放在“相关经文”里。',
              '“引用與應驗”的完整程度取決於這兩個譯本的腳註；有些書卷（尤其是啟示錄）對舊約的暗指，比任何腳註標出的都多，那些放在“相關經文”裡。'),
          bullet(
              'Verse numbers follow the English Bible (Psalm titles and a few chapters differ in the Hebrew). The Old Testament passage shown is the one the note names; the New Testament sometimes follows the Greek translation (Septuagint) rather than the Hebrew, so the wording can differ.',
              '节号依英文圣经（诗篇标题等在希伯来文里编号略有不同）。所列旧约经文就是脚注所指的那一处；新约有时依从希腊文译本（七十士译本）而不是希伯来文，所以字句可能不同。',
              '節號依英文聖經（詩篇標題等在希伯來文裡編號略有不同）。所列舊約經文就是腳註所指的那一處；新約有時依從希臘文譯本（七十士譯本）而不是希伯來文，所以字句可能不同。'),
          bullet(
              'The explanations are written in Chinese; in English you will see English titles and the KJV text.',
              '说明文字以中文写成；英文界面只有标题和经文是英文。',
              '說明文字以中文寫成；英文介面只有標題和經文是英文。'),
          StudyLabel2(studyL(locale, 'Sources', '外部资料', '外部資料')),
          Text(
              studyL(
                  locale,
                  'The LEB (Lexham English Bible) and NET (New English Translation) notes are those bundled in this app.',
                  '“引用”的依据是本应用自带的 LEB（Lexham English Bible）与 NET（New English Translation）译本的脚注。',
                  '“引用”的依據是本應用自帶的 LEB（Lexham English Bible）與 NET（New English Translation）譯本的腳註。'),
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant)),
          for (final s in sources) StudySourceLink(source: s, locale: locale),
        ]);
  }
}

String _typeLabel(String t, String locale) => switch (t) {
      'quote' => studyL(locale, 'Quotation', '引用', '引用'),
      'paraphrase' => studyL(locale, 'Paraphrase', '意译', '意譯'),
      _ => studyL(locale, 'Allusion', '暗指', '暗指'),
    };

Color _typeColor(BuildContext context, String t) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (t) {
    'quote' => dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
    'paraphrase' => dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
    _ => dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309),
  };
}

class _CorrespondenceCard extends StatelessWidget {
  final StudyCorrespondence entry;
  final String locale;
  const _CorrespondenceCard({super.key, required this.entry, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = entry;
    final both = e.ot.any((o) => o.srcs.length > 1);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant)),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(localizePassage(e.nt, locale),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.35)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            StudyBadge(
                text: _typeLabel(e.main, locale), color: _typeColor(context, e.main)),
            if (e.formula != null)
              StudyBadge(
                  text: e.formula == 'fulfil'
                      ? studyL(locale, 'Fulfilled', '应验', '應驗')
                      : studyL(locale, 'It is written', '经上记着', '經上記著'),
                  color: scheme.tertiary),
            for (final o in e.ot.take(3))
              StudyBadge(
                  text: '→ ${localizePassage(o.ref, locale)}',
                  color: scheme.onSurfaceVariant),
            if (e.ot.length > 3)
              StudyBadge(
                  text: '+${e.ot.length - 3}', color: scheme.onSurfaceVariant),
          ]),
        ),
        children: [
          StudyLabel2(studyL(locale, 'New Testament', '新约', '新約')),
          StudyVerseBlock(verse: e.ntBlock, locale: locale),
          StudyLabel2(studyL(locale, 'Old Testament', '旧约', '舊約')),
          for (final o in e.ot) ...[
            Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StudyBadge(
                    text: '${_typeLabel(o.type, locale)} · ${o.srcs.join(' + ')}',
                    color: _typeColor(context, o.type))),
            StudyVerseBlock(verse: o.block, locale: locale),
          ],
          if (both)
            Text(
                studyL(
                    locale,
                    'LEB and NET both mark this.',
                    'LEB 与 NET 两个译本的脚注都标出了这一处。',
                    'LEB 與 NET 兩個譯本的腳註都標出了這一處。'),
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TypologyCard extends StatelessWidget {
  final StudyTypology item;
  final String locale;
  const _TypologyCard({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = item;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant)),
      child: ExpansionTile(
        key: ValueKey('typology.${t.id}'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(t.title.of(locale),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.35)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            StudyBadge(text: t.word.of(locale), color: scheme.tertiary),
          ]),
        ),
        children: [
          StudyLabel2(studyL(locale, 'What the New Testament says',
              '新约怎么说', '新約怎麼說')),
          Text(t.says.of(locale),
              style: const TextStyle(fontSize: 15, height: 1.6)),
          StudyLabel2(studyL(locale, 'Old Testament', '旧约', '舊約')),
          for (final v in t.otBlocks) StudyVerseBlock(verse: v, locale: locale),
          if (t.ot.length > t.otBlocks.length)
            StudyRefChips(
                refs: t.ot.skip(t.otBlocks.length).toList(), locale: locale),
          StudyLabel2(studyL(locale, 'New Testament', '新约', '新約')),
          for (final v in t.ntBlocks) StudyVerseBlock(verse: v, locale: locale),
          if (t.nt.length > t.ntBlocks.length)
            StudyRefChips(
                refs: t.nt.skip(t.ntBlocks.length).toList(), locale: locale),
        ],
      ),
    );
  }
}

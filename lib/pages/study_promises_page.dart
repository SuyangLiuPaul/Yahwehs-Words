import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

const kStudyPromisesPath = '/study/promises';

/// Hidden page (no link anywhere; reached by URL only): the promises of God,
/// Bible first: the verses themselves, then what the Bible says about their
/// fulfilment, then history where a source was opened. Related sermons are
/// links only.
class StudyPromisesPage extends StatefulWidget {
  const StudyPromisesPage({super.key, this.loader});

  /// Test hook.
  final Future<String> Function(String)? loader;

  @override
  State<StudyPromisesPage> createState() => _StudyPromisesPageState();
}

class _StudyPromisesPageState extends State<StudyPromisesPage> {
  late Future<StudyPromises> _future;
  String _query = '';
  String? _status; // null = all
  String? _cond;

  @override
  void initState() {
    super.initState();
    _future = StudyData.loadPromises(loader: widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          actions: const [LanguageSwitcherButton(alwaysVisible: true)],
          title: Text(studyL(locale, 'Promises of God', '神的应许', '神的應許')),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: studyL(locale, 'Promises', '应许目录', '應許目錄')),
            Tab(text: studyL(locale, 'About', '说明', '說明')),
          ]),
        ),
        body: FutureBuilder<StudyPromises>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                  child: FilledButton(
                      onPressed: () => setState(() => _future =
                          StudyData.loadPromises(loader: widget.loader)),
                      child: Text(studyL(locale, 'Retry', '重试', '重試'))));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!;
            return TabBarView(children: [
              _catalogue(d, locale),
              _about(d, locale),
            ]);
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 目录
  Widget _catalogue(StudyPromises d, String locale) {
    final brightness = Theme.of(context).brightness;
    final counts = <String, int>{};
    for (final p in d.promises) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }
    bool keep(StudyPromise p) =>
        (_status == null || p.status == _status) &&
        (_cond == null || p.cond == _cond) &&
        p.matches(_query, locale);
    final shown = d.promises.where(keep).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
            title: studyL(
                locale, 'God has made many promises', '神有很多应许', '神有很多應許'),
            subtitle: studyL(
                locale,
                '${d.promises.length} promises in ten groups, each marked fulfilled, being fulfilled, partly / disputed, or not yet. Each starts with the Bible text, then what the Bible says about its fulfilment, then history where a source was opened. Related sermons are only links.',
                '${d.promises.length} 条应许，分十组；每条标明已应验、持续应验中、部分应验或有分歧、尚未应验。每条先列经文原文，再说圣经里的应验与现状，有来源的再与历史对照；相关讲道只作链接。',
                '${d.promises.length} 條應許，分十組；每條標明已應驗、持續應驗中、部分應驗或有分歧、尚未應驗。每條先列經文原文，再說聖經裡的應驗與現狀，有來源的再與歷史對照；相關講道只作連結。'),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in ['✔', '∞', '◐', '✘'])
                  GestureDetector(
                    key: ValueKey('status.$s'),
                    onTap: () =>
                        setState(() => _status = _status == s ? null : s),
                    child: Opacity(
                        opacity: _status == null || _status == s ? 1 : 0.4,
                        child: StudyBadge(
                            text:
                                '${d.status[s]!.label.of(locale)} ${counts[s] ?? 0}',
                            color: studyStatusColor(s, brightness),
                            glyph: s)),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
              key: const ValueKey('study.search'),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: studyL(locale, 'Search a promise or passage',
                      '搜索应许或经文', '搜尋應許或經文'),
                  border: const OutlineInputBorder()),
              onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in ['unconditional', 'conditional', 'mixed'])
              FilterChip(
                key: ValueKey('cond.$c'),
                label: Text(d.conds[c]!.label.of(locale)),
                selected: _cond == c,
                onSelected: (v) => setState(() => _cond = v ? c : null),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
              studyL(
                  locale,
                  '${shown.length} of ${d.promises.length} shown',
                  '显示 ${shown.length} / ${d.promises.length}',
                  '顯示 ${shown.length} / ${d.promises.length}'),
              style: Theme.of(context).textTheme.labelLarge),
          if (shown.isEmpty)
            Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                    child: Text(studyL(locale, 'No matching promises',
                        '没有匹配的应许', '沒有匹配的應許')))),
          for (final (gid, gname) in d.groups)
            ..._group(d, locale, gid, gname, shown, brightness),
        ]);
  }

  List<Widget> _group(StudyPromises d, String locale, String gid,
      StudyText gname, List<StudyPromise> shown, Brightness brightness) {
    final items = shown.where((p) => p.group == gid).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(gname.of(locale),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      for (final p in items)
        _PromiseCard(
            promise: p, data: d, locale: locale, brightness: brightness),
    ];
  }

  // ------------------------------------------------------------------ 说明
  Widget _about(StudyPromises d, String locale) {
    final brightness = Theme.of(context).brightness;
    Widget bullet(String en, String hs, String ht) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('• ${studyL(locale, en, hs, ht)}',
            style: const TextStyle(fontSize: 15, height: 1.6)));
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
              title: studyL(locale, 'About this page', '关于这一页', '關於這一頁'),
              subtitle: studyL(
                  locale,
                  'A research page on the promises of God, Bible first. It is not linked from anywhere in the app.',
                  '这是一个关于神的应许的研究页，以圣经为主。应用里没有任何入口指向它。',
                  '這是一個關於神的應許的研究頁，以聖經為主。應用裡沒有任何入口指向它。')),
          StudyLabel2(studyL(locale, 'Status legend', '状态说明', '狀態說明')),
          for (final s in ['✔', '∞', '◐', '✘'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StudyBadge(
                    text: d.status[s]!.label.of(locale),
                    color: studyStatusColor(s, brightness),
                    glyph: s),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(d.status[s]!.note.of(locale),
                        style: const TextStyle(fontSize: 14, height: 1.5))),
              ]),
            ),
          StudyLabel2(studyL(locale, 'How reliable is it', '可靠程度', '可靠程度')),
          bullet(
              'Verse text comes from the app’s own Bibles (Chinese Union Version; KJV in English). Tap a verse to read it in your own Bible.',
              '经文原文取自应用自己的圣经（和合本；英文界面用 KJV），没有凭记忆引用；点经文可在你自己的圣经里阅读。',
              '經文原文取自應用自己的聖經（和合本；英文介面用 KJV），沒有憑記憶引用；點經文可在你自己的聖經裡閱讀。'),
          bullet(
              'The status of each promise is judged from the Bible’s own record first. Where the Bible itself says both “fulfilled” and “still to come”, the entry says so.',
              '每条应许的状态，首先依据圣经自己的记载判断；圣经内部同时有“已应验”和“还有未得”的说法时，条目会如实写明。',
              '每條應許的狀態，首先依據聖經自己的記載判斷；聖經內部同時有“已應驗”和“還有未得”的說法時，條目會如實寫明。'),
          bullet(
              'History notes name the source I opened (below). History can say whether an event happened; it cannot decide theology. Where traditions read a passage differently, the page says so and does not pick a side.',
              '“与现实历史的关系”只列我打开读过的来源（见下）。历史能说明事件有没有发生，不能代替神学判断；传统之间读法不同的地方，本页注明，不替任何一方裁决。',
              '“與現實歷史的關係”只列我打開讀過的來源（見下）。歷史能說明事件有沒有發生，不能代替神學判斷；傳統之間讀法不同的地方，本頁註明，不替任何一方裁決。'),
          bullet(
              'Related sermons are links only. They are not the basis of any entry.',
              '相关讲道只是链接，不是任何一条的依据。',
              '相關講道只是連結，不是任何一條的依據。'),
          bullet(
              'The explanations are written in Chinese; in English you will see English titles and the KJV text.',
              '说明文字以中文写成；英文界面只有标题和经文是英文。',
              '說明文字以中文寫成；英文介面只有標題和經文是英文。'),
          StudyLabel2(
              studyL(locale, 'Sources opened', '外部资料（我实际打开的）', '外部資料（我實際打開的）')),
          for (final s in _allSources(d)) StudySourceLink(source: s, locale: locale),
        ]);
  }
}

List<StudySource> _allSources(StudyPromises d) {
  final seen = <String>{};
  return [
    for (final p in d.promises)
      for (final s in p.sources)
        if (seen.add(s.url)) s
  ];
}

class _PromiseCard extends StatelessWidget {
  final StudyPromise promise;
  final StudyPromises data;
  final String locale;
  final Brightness brightness;
  const _PromiseCard(
      {required this.promise,
      required this.data,
      required this.locale,
      required this.brightness});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = promise;
    final sColor = studyStatusColor(p.status, brightness);
    final condLabel = data.conds[p.cond]?.label.of(locale) ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant)),
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: sColor, width: 5))),
        child: ExpansionTile(
          key: ValueKey('promise.${p.id}'),
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(p.title.of(locale),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.35)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              StudyBadge(
                  text: data.status[p.status]!.label.of(locale),
                  color: sColor,
                  glyph: p.status),
              if (condLabel.isNotEmpty && p.cond != 'none')
                StudyBadge(text: condLabel, color: scheme.secondary),
              for (final r in p.refs.take(2))
                StudyBadge(
                    text: localizePassage(r, locale),
                    color: scheme.onSurfaceVariant),
            ]),
          ),
          children: [
            StudyLabel2(studyL(locale, 'The promise', '应许经文', '應許經文')),
            for (final v in p.verseBlocks)
              StudyVerseBlock(verse: v, locale: locale),
            if (p.refs.length > p.verseBlocks.length)
              StudyRefChips(
                  refs: p.refs.skip(p.verseBlocks.length).toList(),
                  locale: locale),
            StudyLabel2(
                studyL(locale, 'To whom, on what condition', '对象与条件', '對象與條件')),
            Text('${p.who.of(locale)}\n${p.condText.of(locale)}',
                style: const TextStyle(fontSize: 15, height: 1.6)),
            StudyLabel2(
                studyL(locale, 'Fulfilment and status', '应验与现状', '應驗與現狀')),
            Text(p.fulfil.of(locale),
                style: const TextStyle(fontSize: 15, height: 1.6)),
            if (p.fulfilRefs.isNotEmpty) ...[
              const SizedBox(height: 8),
              StudyRefChips(refs: p.fulfilRefs, locale: locale),
            ],
            if (p.history != null) ...[
              StudyLabel2(studyL(
                  locale, 'How it relates to history', '与现实历史的关系', '與現實歷史的關係')),
              Text(p.history!.of(locale),
                  style: const TextStyle(fontSize: 15, height: 1.6)),
              for (final s in p.sources)
                StudySourceLink(source: s, locale: locale),
            ],
            if (p.sermons.isNotEmpty) ...[
              StudyLabel2(studyL(locale, 'Related sermons', '相关讲道', '相關講道')),
              StudySermonLinks(sermons: p.sermons, locale: locale),
            ],
          ],
        ),
      ),
    );
  }
}

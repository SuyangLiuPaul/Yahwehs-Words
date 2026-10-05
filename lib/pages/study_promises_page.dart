import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/study_claim_card.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

const kStudyPromisesPath = '/study/promises';

/// Hidden page (no link anywhere; reached by URL only): the promises of God,
/// which have been fulfilled and which have not, set against the sermons and
/// against history. Source: docs/讲道与圣经对照研究-圣经原则与神的应许-2026-10-05.docx
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          actions: const [LanguageSwitcherButton(alwaysVisible: true)],
          title: Text(studyL(locale, 'Promises of God', '神的应许', '神的應許')),
          bottom: TabBar(tabs: [
            Tab(text: studyL(locale, 'Promises', '应许目录', '應許目錄')),
            Tab(text: studyL(locale, 'Sermons vs Bible', '讲道对照', '講道對照')),
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
              _propositions(d, locale),
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
                '${d.promises.length} representative promises, grouped, each marked fulfilled, being fulfilled, partly / disputed, or not yet — with the Bible text, the sermons, and how they relate to history. Tap a reference to read it in your Bible.',
                '${d.promises.length} 条代表性的应许，分十组；每条标明已应验、持续应验中、部分应验或有分歧、尚未应验，并列出经文、讲道，以及与现实历史的关系。点经文可直接在你的圣经里阅读。',
                '${d.promises.length} 條代表性的應許，分十組；每條標明已應驗、持續應驗中、部分應驗或有分歧、尚未應驗，並列出經文、講道，以及與現實歷史的關係。點經文可直接在你的聖經裡閱讀。'),
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

  // ------------------------------------------------------------------ 讲道对照
  Widget _propositions(StudyPromises d, String locale) {
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          StudyHeader(
            title: studyL(locale, 'What the sermons say about promises',
                '讲道怎样讲应许', '講道怎樣講應許'),
            subtitle: studyL(
                locale,
                'Nine claims from the sermons, each quoted verbatim, set against the Bible, with an assessment. Tap a quote to open the sermon.',
                '讲道里关于应许的九个命题：每条都有逐字核对的原话，与圣经逐项对照，并给出评估。点原话可打开对应讲道。',
                '講道裡關於應許的九個命題：每條都有逐字核對的原話，與聖經逐項對照，並給出評估。點原話可打開對應講道。'),
          ),
          const SizedBox(height: 14),
          for (final c in d.propositions)
            StudyClaimCard(
                claim: c,
                verdict: d.verdicts[c.verdict]!,
                locale: locale,
                keyPrefix: 'proposition',
                initiallyExpanded: c.n == 1),
        ]);
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
                  'A research page: Pastor Eric H. H. Chang’s sermons compared with the Bible and with history. It is not linked from anywhere in the app.',
                  '这是一个研究页：把张熙和牧师的讲道与圣经、与现实历史对照。应用里没有任何入口指向它。',
                  '這是一個研究頁：把張熙和牧師的講道與聖經、與現實歷史對照。應用裡沒有任何入口指向它。')),
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
              'Every Bible reference opens the app’s own text; nothing is quoted from memory.',
              '每一处经文都打开应用自己的圣经，没有凭记忆引用。',
              '每一處經文都打開應用自己的聖經，沒有憑記憶引用。'),
          bullet(
              'Every sermon quotation was checked verbatim against the sermon text. Tap it to open the sermon.',
              '每一条讲道原话都逐字核对过对应讲道的中文文本；点一下可打开讲道。',
              '每一條講道原話都逐字核對過對應講道的中文文本；點一下可打開講道。'),
          bullet(
              'History notes name the source I opened (below). History can say whether an event happened; it cannot decide theology.',
              '“与现实历史的关系”只列我打开读过的来源（见下）。历史能说明事件有没有发生，不能代替神学判断。',
              '“與現實歷史的關係”只列我打開讀過的來源（見下）。歷史能說明事件有沒有發生，不能代替神學判斷。'),
          bullet(
              'I did not read all 429 sermons: I read the passages where “promise” is densest. This is not an exhaustive survey.',
              '我没有读完全部429篇讲道：读的是“应许”一词最密集的相关段落，不是穷尽阅读。',
              '我沒有讀完全部429篇講道：讀的是“應許”一詞最密集的相關段落，不是窮盡閱讀。'),
          bullet(
              'The text is written in Chinese; in English you will see the Chinese content with English titles.',
              '研究内容以中文写成；英文界面只有标题和标签是英文。',
              '研究內容以中文寫成；英文介面只有標題和標籤是英文。'),
          StudyLabel2(
              studyL(locale, 'Sources opened', '外部资料（我实际打开的）', '外部資料（我實際打開的）')),
          for (final s in d.sources) StudySourceLink(source: s, locale: locale),
        ]);
  }
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
            StudyRefChips(refs: p.refs, locale: locale),
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
              StudyLabel2(studyL(locale, 'In the sermons', '讲道里', '講道裡')),
              for (final q in p.sermons)
                StudyQuoteBlock(quote: q, locale: locale),
            ],
          ],
        ),
      ),
    );
  }
}

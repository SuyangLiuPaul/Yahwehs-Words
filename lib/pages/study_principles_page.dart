import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

const kStudyPrinciplesPath = '/study/principles';

/// Hidden page (reached by URL only): principles of the Bible, Bible first.
/// Each entry shows the verses themselves, then the limits and other readings
/// worth knowing; related sermons are links only. Source:
/// bible-sermon-research/v2 (generator + checks live outside the repo).
class StudyPrinciplesPage extends StatefulWidget {
  const StudyPrinciplesPage({super.key, this.loader});

  /// Test hook.
  final Future<String> Function(String)? loader;

  @override
  State<StudyPrinciplesPage> createState() => _StudyPrinciplesPageState();
}

class _StudyPrinciplesPageState extends State<StudyPrinciplesPage> {
  late Future<StudyPrinciples> _future;
  String _query = '';
  String? _cat; // null = all
  String? _book;
  int? _chapter;

  @override
  void initState() {
    super.initState();
    _future = StudyData.loadPrinciples(loader: widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        actions: const [LanguageSwitcherButton(alwaysVisible: true)],
        title: Text(studyL(locale, 'Bible principles', '圣经原则', '聖經原則')),
      ),
      body: FutureBuilder<StudyPrinciples>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: FilledButton(
                    onPressed: () => setState(() => _future =
                        StudyData.loadPrinciples(loader: widget.loader)),
                    child: Text(studyL(locale, 'Retry', '重试', '重試'))));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final shown = d.principles
              .where((p) =>
                  (_cat == null || p.cat == _cat) &&
                  studyInPassage(p.chapters, _book, _chapter) &&
                  p.matches(_query, locale))
              .toList();
          final counts = <String, int>{};
          for (final p in d.principles) {
            counts[p.cat] = (counts[p.cat] ?? 0) + 1;
          }
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                StudyHeader(
                  title: studyL(locale, 'Principles of the Bible',
                      '圣经里的原则', '聖經裡的原則'),
                  subtitle: studyL(
                      locale,
                      '${d.principles.length} principles in ${d.categories.length} groups. Each begins with the Bible text itself, then the limits and other readings worth knowing. Related sermons are only links. Tap a verse to read it in your own Bible.',
                      '${d.principles.length} 条原则，分 ${d.categories.length} 类。每条先列出经文原文，再说明需要留意的边界和不同读法；相关讲道只作链接，点一下就能去读。点经文可在你自己的圣经里阅读。',
                      '${d.principles.length} 條原則，分 ${d.categories.length} 類。每條先列出經文原文，再說明需要留意的邊界和不同讀法；相關講道只作連結，點一下就能去讀。點經文可在你自己的聖經裡閱讀。'),
                ),
                const SizedBox(height: 14),
                TextField(
                    key: const ValueKey('study.search'),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: studyL(
                            locale,
                            'Search a principle, passage or sermon number',
                            '搜索原则、经文或讲道编号',
                            '搜尋原則、經文或講道編號'),
                        border: const OutlineInputBorder()),
                    onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 10),
                StudyPassageFilter(
                    available: {for (final p in d.principles) ...p.chapters},
                    book: _book,
                    chapter: _chapter,
                    locale: locale,
                    onChanged: (b, c) => setState(() {
                          _book = b;
                          _chapter = c;
                        })),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final (id, name) in d.categories)
                    FilterChip(
                      key: ValueKey('cat.$id'),
                      label: Text('${name.of(locale)} ${counts[id] ?? 0}'),
                      selected: _cat == id,
                      onSelected: (v) => setState(() => _cat = v ? id : null),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(
                    studyL(
                        locale,
                        '${shown.length} of ${d.principles.length} shown',
                        '显示 ${shown.length} / ${d.principles.length}',
                        '顯示 ${shown.length} / ${d.principles.length}'),
                    style: Theme.of(context).textTheme.labelLarge),
                if (shown.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                          child: Text(studyL(locale, 'No matching principles',
                              '没有匹配的原则', '沒有匹配的原則')))),
                for (final (id, name) in d.categories)
                  ..._category(context, locale, id, name, shown),
                const SizedBox(height: 20),
                _about(context, locale, d),
              ]);
        },
      ),
    );
  }

  List<Widget> _category(BuildContext context, String locale, String id,
      StudyText name, List<StudyPrinciple> shown) {
    final items = shown.where((p) => p.cat == id).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(name.of(locale),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      for (final p in items) _PrincipleCard(principle: p, locale: locale),
    ];
  }

  Widget _about(BuildContext context, String locale, StudyPrinciples d) {
    final scheme = Theme.of(context).colorScheme;
    final seen = <String>{};
    final sources = <StudySource>[
      for (final p in d.principles)
        for (final s in p.sources)
          if (seen.add(s.url)) s
    ];
    Widget bullet(String en, String hs, String ht) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('• ${studyL(locale, en, hs, ht)}',
            style: const TextStyle(fontSize: 14.5, height: 1.6)));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(studyL(locale, 'About this page', '关于这一页', '關於這一頁'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        bullet(
            'Verse text is taken from the app’s own Bibles (Chinese Union Version; KJV in English), not from memory.',
            '经文原文取自应用自己的圣经（和合本；英文界面用 KJV），没有凭记忆引用。',
            '經文原文取自應用自己的聖經（和合本；英文介面用 KJV），沒有憑記憶引用。'),
        bullet(
            'The entries were gathered from the Bible first, then matched to sermons that teach them. Sermons are links, not authorities on this page.',
            '条目先从圣经整理，再对应到讲这些原则的讲道；讲道在这一页只是链接，不是依据。',
            '條目先從聖經整理，再對應到講這些原則的講道；講道在這一頁只是連結，不是依據。'),
        bullet(
            'Where Christian traditions read a passage differently, the page says so and does not pick a side. The sources for those comparisons are listed below.',
            '凡基督教传统对经文有不同读法的地方，本页都会注明，不替任何一方裁决；这些比较所依据的资料列在下面。',
            '凡基督教傳統對經文有不同讀法的地方，本頁都會註明，不替任何一方裁決；這些比較所依據的資料列在下面。'),
        bullet(
            'The explanations are written in Chinese; in English you will see English titles and the KJV text.',
            '说明文字以中文写成；英文界面只有标题和经文是英文。',
            '說明文字以中文寫成；英文介面只有標題和經文是英文。'),
        if (sources.isNotEmpty) ...[
          StudyLabel2(
              studyL(locale, 'Sources', '外部资料', '外部資料')),
          for (final s in sources) StudySourceLink(source: s, locale: locale),
        ],
      ]),
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  final StudyPrinciple principle;
  final String locale;
  const _PrincipleCard({required this.principle, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = principle;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant)),
      child: ExpansionTile(
        key: ValueKey('principle.${p.id}'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
            radius: 15,
            backgroundColor: scheme.primary,
            child: Text('${p.n}',
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12))),
        title: Text(p.title.of(locale),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.35)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(p.line.of(locale),
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant))),
        children: [
          StudyLabel2(studyL(locale, 'What the Bible says', '圣经怎么说', '聖經怎麼說')),
          for (final v in p.verseBlocks)
            StudyVerseBlock(verse: v, locale: locale),
          if (p.says.isNotEmpty) StudyBullets(points: p.says, locale: locale),
          StudyLabel2(studyL(locale, 'More passages', '更多经文', '更多經文')),
          StudyRefChips(refs: p.verses, locale: locale),
          if (p.limits.isNotEmpty) ...[
            StudyLabel2(studyL(locale, 'Limits and other readings',
                '需要留意的边界与不同读法', '需要留意的邊界與不同讀法')),
            StudyBullets(points: p.limits, locale: locale),
          ],
          if (p.sources.isNotEmpty) ...[
            StudyLabel2(studyL(locale, 'Sources', '参考资料', '參考資料')),
            for (final s in p.sources) StudySourceLink(source: s, locale: locale),
          ],
          if (p.sermons.isNotEmpty) ...[
            StudyLabel2(studyL(locale, 'Related sermons', '相关讲道', '相關講道')),
            StudySermonLinks(sermons: p.sermons, locale: locale),
          ],
        ],
      ),
    );
  }
}

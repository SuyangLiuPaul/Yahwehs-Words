import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/study_claim_card.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

const kStudyPrinciplesPath = '/study/principles';

/// Hidden page (reached by URL only): the principles the sermons themselves
/// name, each set against the Bible. Source:
/// docs/讲道与圣经对照研究-圣经原则与神的应许-2026-10-05.docx
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
  String? _verdict;

  @override
  void initState() {
    super.initState();
    _future = StudyData.loadPrinciples(loader: widget.loader);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        actions: const [LanguageSwitcherButton(alwaysVisible: true)],
        title: Text(studyL(
            locale, 'Bible principles — study', '圣经原则 · 研读', '聖經原則 · 研讀')),
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
          final counts = <String, int>{};
          for (final p in d.principles) {
            counts[p.verdict] = (counts[p.verdict] ?? 0) + 1;
          }
          final shown = d.principles
              .where((p) =>
                  (_verdict == null || p.verdict == _verdict) &&
                  p.matches(_query, locale))
              .toList();
          return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                StudyHeader(
                  title: studyL(locale, 'Principles the sermons name',
                      '讲道自己说出来的原则', '講道自己說出來的原則'),
                  subtitle: studyL(
                      locale,
                      'Nine principles taken from the sermons’ own wording, each set against the Bible and given an assessment. Tap a reference to read it in your Bible; tap a quote to open the sermon.',
                      '从讲道自己的用语里整理出来的九条原则，每条与圣经逐项对照并给出评估。点经文可在你的圣经里阅读；点原话可打开对应讲道。',
                      '從講道自己的用語裡整理出來的九條原則，每條與聖經逐項對照並給出評估。點經文可在你的聖經裡閱讀；點原話可打開對應講道。'),
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final v in ['agree', 'qualify', 'tradition'])
                        GestureDetector(
                          key: ValueKey('verdict.$v'),
                          onTap: () => setState(
                              () => _verdict = _verdict == v ? null : v),
                          child: Opacity(
                              opacity:
                                  _verdict == null || _verdict == v ? 1 : 0.4,
                              child: StudyBadge(
                                  text:
                                      '${d.verdicts[v]!.label.of(locale)} ${counts[v] ?? 0}',
                                  color: studyVerdictColor(v, brightness),
                                  glyph: studyVerdictGlyph(v))),
                        ),
                    ]),
                  ],
                ),
                const SizedBox(height: 14),
                _auditCard(context, locale),
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
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                          child: Text(studyL(locale, 'No matching principles',
                              '没有匹配的原则', '沒有匹配的原則')))),
                for (final p in shown)
                  StudyClaimCard(
                      claim: p,
                      verdict: d.verdicts[p.verdict]!,
                      locale: locale,
                      keyPrefix: 'principle',
                      initiallyExpanded: p.n == 1),
              ]);
        },
      ),
    );
  }

  /// A short, honest note on the 18 principles the app already carries.
  Widget _auditCard(BuildContext context, String locale) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            studyL(locale, 'About the 18 principles already in the app',
                '关于应用里已有的 18 条原则', '關於應用裡已有的 18 條原則'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        Text(
            studyL(
                locale,
                'Each of the 18 rests on one sermon and one English line (all 18 lines were verified verbatim). The scripture links are the sermon’s own index, not a point-by-point comparison, and the set misses the sermons that use the word “principle” most (203, fy-sm16, 765, 036, 231). The nine below follow the sermons’ own structure.',
                '现有 18 条每条只来自一篇讲道、一句英文截取（18 句都已逐字核对）；经文链接是那篇讲道自己的索引，不是逐条对照；而讲道里“原则”一词最密集的几篇（203、fy-sm16、765、036、231）没有收入。下面九条按讲道自己的结构整理。',
                '現有 18 條每條只來自一篇講道、一句英文截取（18 句都已逐字核對）；經文連結是那篇講道自己的索引，不是逐條對照；而講道裡“原則”一詞最密集的幾篇（203、fy-sm16、765、036、231）沒有收入。下面九條按講道自己的結構整理。'),
            style: TextStyle(
                fontSize: 14, height: 1.6, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/learning_data.dart';
import 'package:yahwehs_words/models/sermon.dart';
import 'package:yahwehs_words/pages/sermon_detail_page.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart';

const kPrinciplesPath = '/bible-principles';
const kPrinciplesTitle = {
  'en': 'Bible principles',
  'zh-Hans': '圣经原则',
  'zh-Hant': '聖經原則'
};
String _l(String locale, String en, String hs, String ht) => locale == 'zh-Hans'
    ? hs
    : locale == 'zh-Hant'
        ? ht
        : en;

class _PrinciplesData {
  final List<BiblePrinciple> principles;
  final List<Sermon> sermons;
  final SermonRefs refs;
  const _PrinciplesData(this.principles, this.sermons, this.refs);
}

class BiblePrinciplesPage extends StatefulWidget {
  const BiblePrinciplesPage({super.key});
  @override
  State<BiblePrinciplesPage> createState() => _BiblePrinciplesPageState();
}

class _BiblePrinciplesPageState extends State<BiblePrinciplesPage> {
  late Future<_PrinciplesData> _future;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PrinciplesData> _load() async {
    final p = await LearningData.loadPrinciples();
    final s = await SermonService.instance.loadIndex();
    final r = await SermonService.instance.loadRefs();
    return _PrinciplesData(p, s, r);
  }

  Future<void> _ref(String value) async {
    final ref = parseReference(value);
    if (ref != null) await showVersePopup(context, ref);
  }

  Future<void> _sermon(Sermon sermon) async {
    await pushPage(SermonDetailPage(sermon: sermon),
        routeName: '/sermons/${sermon.id}');
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return Scaffold(
        appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(learningText(kPrinciplesTitle, locale))),
        body: FutureBuilder<_PrinciplesData>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: FilledButton(
                        onPressed: () => setState(() => _future = _load()),
                        child: Text(_l(locale, 'Retry', '重试', '重試'))));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data!;
              final filtered = data.principles
                  .where((p) =>
                      p.matches(_query, locale) ||
                      p.sermonIds.any((id) => (data.refs.bySermon[id] ?? [])
                          .any((r) => localizePassage(r, locale)
                              .toLowerCase()
                              .contains(_query.trim().toLowerCase()))))
                  .toList();
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: _l(
                                locale,
                                'Principle, passage or sermon number',
                                '原则、经文或讲道编号',
                                '原則、經文或講道編號'),
                            border: const OutlineInputBorder()),
                        onChanged: (v) => setState(() => _query = v))),
                Expanded(
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                  Text(_l(
                      locale,
                      'A study guide to Pastor Eric H. H. Chang’s sermons. These selected summaries are editorial; open the sermon to read his own argument. The references below are the complete indexed citations of the source sermon, not an exhaustive list of every possible related passage.',
                      '张熙和牧师讲道研读导览。以下是精选原则的编辑摘要，请打开原讲道阅读牧师的论证。经文部分列出出处讲道的全部已索引引用，并非声称穷尽所有可能相关的经文。',
                      '張熙和牧師講道研讀導覽。以下是精選原則的編輯摘要，請打開原講道閱讀牧師的論證。經文部分列出出處講道的全部已索引引用，並非聲稱窮盡所有可能相關的經文。')),
                  const SizedBox(height: 12),
                  Text('${filtered.length} / ${data.principles.length}',
                      style: Theme.of(context).textTheme.labelLarge),
                  if (filtered.isEmpty)
                    Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_l(locale, 'No matching principles',
                            '没有匹配的原则', '沒有匹配的原則'))),
                  for (final p in filtered)
                    Card(
                        child: ExpansionTile(
                            key: ValueKey('principle.${p.id}'),
                            title: Text(learningText(p.title, locale)),
                            subtitle: Text(learningText(p.summary, locale)),
                            childrenPadding: const EdgeInsets.all(16),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          Text(_l(locale, 'Source sermon', '出处讲道', '出處講道'),
                              style: Theme.of(context).textTheme.titleSmall),
                          for (final id in p.sermonIds) ...[
                            for (final sermon
                                in data.sermons.where((s) => s.id == id))
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '#$id · ${sermon.localizedTitle(locale)}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _sermon(sermon)),
                            const SizedBox(height: 8),
                            Text(
                                _l(locale, 'Scripture cited in this sermon',
                                    '本讲道引用的经文', '本講道引用的經文'),
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final r
                                  in data.refs.bySermon[id] ?? const <String>[])
                                if (parseReference(r) != null)
                                  ActionChip(
                                      label: Text(localizePassage(r, locale)),
                                      onPressed: () => _ref(r))
                            ]),
                          ],
                        ])),
                ])),
              ]);
            }));
  }
}

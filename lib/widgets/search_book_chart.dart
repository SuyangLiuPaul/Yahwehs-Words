import 'package:flutter/material.dart';

/// Counts are supplied by the active result set, so a scoped search
/// cannot accidentally chart a different corpus. Text queries count
/// matching verses; occurrence maps may only come from an exact index.
class SearchBookChart extends StatelessWidget {
  const SearchBookChart(
      {super.key,
      required this.counts,
      required this.locale,
      required this.bookLabel,
      this.occurrences = false,
      this.scope,
      this.partial = false});
  final Map<String, int> counts;
  final String locale;
  final String Function(String) bookLabel;
  final bool occurrences;
  final String? scope;
  final bool partial;

  String _text(String en, String hans, String hant) => locale == 'zh-Hans'
      ? hans
      : locale == 'zh-Hant'
          ? hant
          : en;
  String get _unit => occurrences
      ? _text('occurrences', '出现次数', '出現次數')
      : _text('matching verses', '命中经文', '命中經文');

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final order = {for (var i = 0; i < entries.length; i++) entries[i].key: i};
    entries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : order[a.key]!.compareTo(order[b.key]!);
    });
    final title = _text('By book', '按书卷统计', '按書卷統計');
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        icon: const Icon(Icons.bar_chart_rounded, size: 20),
        label: Text(title),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          constraints: const BoxConstraints(maxWidth: 720),
          builder: (context) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(title,
                                style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text([
                        if (scope != null && scope!.isNotEmpty) scope!,
                        '${entries.fold<int>(0, (n, e) => n + e.value)} $_unit',
                        _text('Highest first', '从高到低', '從高到低'),
                      ].join(' · '))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(partial
                          ? _text(
                              'These results are incomplete; a full distribution is unavailable.',
                              '结果不完整，无法显示完整分布。',
                              '結果不完整，無法顯示完整分布。')
                          : occurrences
                              ? _text(
                                  'Each occurrence is counted, including repeated uses in one verse.',
                                  '每次出现都计数，包括同一节经文中的重复出现。',
                                  '每次出現都計數，包括同一節經文中的重複出現。')
                              : _text(
                                  'Each matching verse counts once, even if the word appears more than once.',
                                  '每节命中经文计一次，即使词语在该节出现多次。',
                                  '每節命中經文計一次，即使詞語在該節出現多次。'))),
                  if (!partial)
                    Expanded(
                        child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final label = bookLabel(e.key);
                        return Semantics(
                            label: '$label: ${e.value} $_unit',
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: Text(label)),
                                            const SizedBox(width: 12),
                                            Text('${e.value}')
                                          ]),
                                      const SizedBox(height: 5),
                                      ExcludeSemantics(
                                          child: LinearProgressIndicator(
                                              value:
                                                  e.value / entries.first.value,
                                              minHeight: 12,
                                              borderRadius:
                                                  BorderRadius.circular(3))),
                                    ])));
                      },
                    )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tally the already scoped results in their input order in one pass.
Map<String, int> searchBookCounts(Iterable<String> books) {
  final counts = <String, int>{};
  for (final book in books) {
    counts[book] = (counts[book] ?? 0) + 1;
  }
  return counts;
}

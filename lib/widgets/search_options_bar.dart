import 'package:flutter/material.dart';
import '../constants/search_options_strings.dart';

/// Two independent preferences beside the query, with a wrapping layout
/// for the workbench's narrow pane and large accessibility text.
class SearchOptionsBar extends StatelessWidget {
  const SearchOptionsBar(
      {super.key,
      required this.locale,
      required this.fuzzy,
      required this.pinyin,
      required this.onFuzzyChanged,
      required this.onPinyinChanged,
      this.plainQuery = true,
      this.busy = false});
  final String locale;
  final bool fuzzy, pinyin, plainQuery, busy;
  final ValueChanged<bool> onFuzzyChanged, onPinyinChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilterChip(
                label: Text(searchOptionText('fuzzy', locale)),
                tooltip: searchOptionText('fuzzyHelp', locale),
                selected: fuzzy,
                onSelected: plainQuery && !busy ? onFuzzyChanged : null),
            FilterChip(
                label: Text(searchOptionText('pinyin', locale)),
                tooltip: searchOptionText('pinyinHelp', locale),
                selected: pinyin,
                onSelected: plainQuery && !busy ? onPinyinChanged : null),
          ]),
          if (!plainQuery || pinyin || fuzzy)
            Text(
                searchOptionText(
                    !plainQuery
                        ? 'plainOnly'
                        : pinyin
                            ? 'chineseOnly'
                            : 'fuzzyHelp',
                    locale),
                style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

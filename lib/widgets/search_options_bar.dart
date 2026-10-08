import 'package:flutter/material.dart';
import '../constants/search_options_strings.dart';

/// A single optional expansion mode; exact text search remains the default.
class SearchOptionsBar extends StatelessWidget {
  const SearchOptionsBar(
      {super.key,
      required this.locale,
      required this.fuzzy,
      required this.onFuzzyChanged,
      this.plainQuery = true,
      this.busy = false});
  final String locale;
  final bool fuzzy, plainQuery, busy;
  final ValueChanged<bool> onFuzzyChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FilterChip(
            label: Text(searchOptionText('fuzzy', locale)),
            tooltip: searchOptionText('fuzzyHelp', locale),
            selected: fuzzy,
            onSelected: plainQuery && !busy ? onFuzzyChanged : null),
        Text(
            searchOptionText(
                !plainQuery
                    ? 'plainOnly'
                    : fuzzy
                        ? 'fuzzyHelp'
                        : 'modeHelp',
                locale),
            style: Theme.of(context).textTheme.bodySmall),
      ]));
}

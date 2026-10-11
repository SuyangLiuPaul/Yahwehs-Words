import 'package:flutter/material.dart';

/// A large touch target when one translated phrase has several source numbers.
/// Names and mappings come from the source; this dialog never edits them.
Future<String?> chooseTaggedNumber(
  BuildContext context, {
  required String text,
  required List<String> numbers,
}) async {
  if (numbers.isEmpty) return null;
  if (numbers.length == 1) return numbers.single;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => SafeArea(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final number in numbers)
          ListTile(
              title: Text(number),
              minTileHeight: 48,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(number)),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
      ]),
    )),
  );
}

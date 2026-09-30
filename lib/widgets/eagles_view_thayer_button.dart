import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The English Eagle's View article complements the existing Chinese
/// BDB/Thayer entry. Loading happens only when the reader opens it.
class EaglesViewThayerButton extends StatelessWidget {
  const EaglesViewThayerButton(
      {super.key, required this.number, required this.locale});
  final String number;
  final String locale;
  static Future<Map<String, dynamic>>? _entries;
  static Future<Map<String, dynamic>> _load() => _entries ??= rootBundle
      .loadString('assets/thayer.json')
      .then((s) => jsonDecode(s) as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) {
    final match =
        RegExp(r'^G0*(\d+)$', caseSensitive: false).firstMatch(number);
    if (match == null) return const SizedBox.shrink();
    final key = 'G${int.parse(match.group(1)!)}';
    final title = locale == 'zh-Hans'
        ? 'Thayer 英文词典 · Eagle’s View'
        : locale == 'zh-Hant'
            ? 'Thayer 英文詞典 · Eagle’s View'
            : 'Thayer’s lexicon · Eagle’s View';
    return TextButton.icon(
      icon: const Icon(Icons.menu_book_outlined, size: 18),
      label: Text(title),
      onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('$title · $key'),
                content: SizedBox(
                    width: 560,
                    child: FutureBuilder<Map<String, dynamic>>(
                        future: _load(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError)
                            return Text(locale == 'zh-Hans'
                                ? '无法加载词典条目。'
                                : locale == 'zh-Hant'
                                    ? '無法載入詞典條目。'
                                    : 'This article could not be loaded.');
                          if (!snapshot.hasData)
                            return const SizedBox(
                                height: 64,
                                child:
                                    Center(child: CircularProgressIndicator()));
                          final data = snapshot.data!;
                          final article = (data['entries']
                              as Map<String, dynamic>)[key] as String?;
                          return SingleChildScrollView(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                SelectableText(article ??
                                    (locale == 'zh-Hans'
                                        ? '此编号没有 Thayer 条目。'
                                        : locale == 'zh-Hant'
                                            ? '此編號沒有 Thayer 條目。'
                                            : 'No Thayer article for this number.')),
                                const SizedBox(height: 20),
                                Text(data['attribution'] as String,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]));
                        })),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                          MaterialLocalizations.of(context).closeButtonLabel))
                ],
              )),
    );
  }
}

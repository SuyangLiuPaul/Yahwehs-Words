import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/verse_share_layout.dart';
import 'verse_card.dart';

/// The same preferences drive Settings, the live share preview and PNG export.
/// Photo framing remains local to the existing photo picker.
class VerseShareLayoutControls extends StatelessWidget {
  final bool showPreview;
  const VerseShareLayoutControls({super.key, this.showPreview = true});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final v = settings.verseShareLayout;
    final zh = settings.locale.startsWith('zh');
    String t(String en, String cn) {
      if (!zh) return en;
      if (settings.locale != 'zh-Hant') return cn;
      const traditional = {
        '经文图片排版': '經文圖片排版',
        '经文出处': '經文出處',
        '这里显示所选经文。分享图片面板会预览你的实际经文。': '這裡顯示所選經文。分享圖片面板會預覽你的實際經文。',
        '译本名称': '譯本名稱',
        '雅伟之言': '雅偉之言',
        '文字对齐': '文字對齊',
        '左对齐': '左對齊',
        '右对齐': '右對齊',
        '字号比例': '字號比例',
        '边距': '邊距',
        '显示经文出处': '顯示經文出處',
        '显示译本名称': '顯示譯本名稱',
        '仅改变排版；译本所需的来源及授权说明始终保留。': '僅改變排版；譯本所需的來源及授權說明始終保留。',
        '恢复默认': '恢復預設',
      };
      return traditional[cn] ?? cn;
    }

    void save(VerseShareLayout value) {
      settings.setVerseShareLayout(value);
    }

    Widget choice<T>(String title, T value, List<T> values,
            String Function(T) label, void Function(T) select) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final item in values)
                  ChoiceChip(
                      label: Text(label(item)),
                      selected: item == value,
                      onSelected: (_) => select(item))
              ]),
            ]));
    Widget slider(String title, double value, double min, double max, int steps,
            void Function(double) select) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$title · ${value.toStringAsFixed(2)}'),
          Slider(
              value: value,
              min: min,
              max: max,
              divisions: steps,
              label: value.toStringAsFixed(2),
              onChanged: select),
        ]);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.image_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(t('Verse image layout', '经文图片排版'),
                            style: Theme.of(context).textTheme.titleMedium))
                  ]),
                  if (showPreview) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: VerseCard(
                                reference: t('Passage reference', '经文出处'),
                                body: t(
                                    'Your selected passage appears here. Preview your actual verse in the image sharing panel.',
                                    '这里显示所选经文。分享图片面板会预览你的实际经文。'),
                                versionLabel: t('Translation name', '译本名称'),
                                appName: t("Yahweh’s Words", '雅伟之言'),
                                scheme: Theme.of(context).colorScheme,
                                layout: v,
                                fontFamily: settings.fontFamily))),
                  ],
                  choice(
                      t('Text position', '文字位置'),
                      v.position,
                      VerseSharePosition.values,
                      (i) => switch (i) {
                            VerseSharePosition.top => t('Top', '上方'),
                            VerseSharePosition.center => t('Middle', '居中'),
                            VerseSharePosition.bottom => t('Bottom', '下方')
                          },
                      (i) => save(v.copyWith(position: i))),
                  choice(
                      t('Text alignment', '文字对齐'),
                      v.alignment,
                      VerseShareAlignment.values,
                      (i) => switch (i) {
                            VerseShareAlignment.left => t('Left', '左对齐'),
                            VerseShareAlignment.center => t('Centre', '居中'),
                            VerseShareAlignment.right => t('Right', '右对齐')
                          },
                      (i) => save(v.copyWith(alignment: i))),
                  slider(t('Text size', '字号比例'), v.fontScale, .8, 1.4, 6,
                      (i) => save(v.copyWith(fontScale: i))),
                  slider(t('Line spacing', '行距'), v.lineHeight, 1.2, 2, 8,
                      (i) => save(v.copyWith(lineHeight: i))),
                  slider(t('Margins', '边距'), v.padding, 16, 40, 6,
                      (i) => save(v.copyWith(padding: i))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('Show passage reference', '显示经文出处')),
                      value: v.showReference,
                      onChanged: (i) => save(v.copyWith(showReference: i))),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('Show translation name', '显示译本名称')),
                      value: v.showVersion,
                      onChanged: (i) => save(v.copyWith(showVersion: i))),
                  Text(
                      t('Only the layout changes. Required translation credits remain visible.',
                          '仅改变排版；译本所需的来源及授权说明始终保留。'),
                      style: Theme.of(context).textTheme.bodySmall),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          icon: const Icon(Icons.restore),
                          label: Text(t('Restore defaults', '恢复默认')),
                          onPressed: () => save(const VerseShareLayout()))),
                ])));
  }
}

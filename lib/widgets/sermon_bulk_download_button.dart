import 'package:flutter/material.dart';
import '../models/sermon.dart';
import '../services/offline_audio_downloads.dart';
import '../services/sermon_download_items.dart';
import '../utils/app_nav.dart';
import 'sermon_offline_downloads.dart';

/// The caller supplies the currently visible filter or series, never the
/// unfiltered catalogue. Resolving metadata does not start any download.
class SermonBulkDownloadButton extends StatefulWidget {
  const SermonBulkDownloadButton(
      {super.key,
      required this.sermons,
      required this.locale,
      this.service,
      this.resolveParts});
  final List<Sermon> sermons;
  final String locale;
  final OfflineAudioDownloads? service;
  final Future<List<AudioDownloadItem>> Function(String, String)? resolveParts;
  @override
  State<SermonBulkDownloadButton> createState() =>
      _SermonBulkDownloadButtonState();
}

class _SermonBulkDownloadButtonState extends State<SermonBulkDownloadButton> {
  bool _loading = false;
  String l(String en, String zh, String tw) =>
      offlineLabel(widget.locale, en, zh, tw);
  Future<void> _choose() async {
    final svc = widget.service ?? OfflineAudioDownloads.instance;
    final snapshot = List<Sermon>.of(widget.sermons);
    setState(() => _loading = true);
    try {
      await svc.init();
      final groups = <Sermon, List<AudioDownloadItem>>{};
      for (final sermon in snapshot) {
        final parts = await (widget.resolveParts ?? sermonDownloadItems)(
            sermon.id, sermon.localizedTitle(widget.locale));
        final missing = parts.where((p) => !svc.isReady([p])).toList();
        if (missing.isNotEmpty) groups[sermon] = missing;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l('No new audio to download in these results.',
                '这些结果没有需要下载的新录音。', '這些結果沒有需要下載的新錄音。'))));
        return;
      }
      final selected = groups.keys.toSet();
      final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (ctx, update) {
                final parts = [for (final s in selected) ...groups[s]!];
                final bytes = parts.fold<int>(0, (n, p) => n + p.expectedBytes);
                final unknown = parts.where((p) => p.expectedBytes <= 0).length;
                return AlertDialog(
                  title: Text(l('Download these results', '下载当前结果', '下載目前結果')),
                  content: SizedBox(
                      width: 480,
                      height: MediaQuery.sizeOf(ctx).height * 0.5,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            '${selected.length} ${l('sermons', '篇讲道', '篇講道')} · ${parts.length} ${l('audio parts', '段录音', '段錄音')}\n${(bytes / 1048576).toStringAsFixed(1)} MB${unknown == 0 ? '' : ' + $unknown ${l('unknown sizes', '段大小未知', '段大小未知')}'}'),
                        Text(l(
                            'Already saved audio is skipped. Keep the app open while downloading.',
                            '跳过已保存录音。下载时请保持应用打开。',
                            '略過已儲存錄音。下載時請保持應用開啟。')),
                        Flexible(
                            child: SingleChildScrollView(
                                child: Column(children: [
                          for (final sermon in groups.keys)
                            CheckboxListTile(
                                title:
                                    Text(sermon.localizedTitle(widget.locale)),
                                value: selected.contains(sermon),
                                onChanged: (v) => update(() {
                                      if (v == true) {
                                        selected.add(sermon);
                                      } else {
                                        selected.remove(sermon);
                                      }
                                    })),
                        ]))),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l('Cancel', '取消', '取消'))),
                    FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(ctx, true),
                        child: Text(l('Download', '下载', '下載')))
                  ],
                );
              }));
      if (accepted != true) return;
      await svc.enqueue([for (final sermon in selected) ...groups[sermon]!]);
      if (mounted) {
        pushPage(SermonDownloadsPage(locale: widget.locale, service: svc));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.download_for_offline_outlined),
      label: Text(l('Download results', '下载当前结果', '下載目前結果')),
      onPressed: _loading ||
              widget.sermons.isEmpty ||
              !(widget.service ?? OfflineAudioDownloads.instance).supported
          ? null
          : _choose);
}

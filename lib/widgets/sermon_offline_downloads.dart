import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/offline_audio_downloads.dart';
import '../services/sermon_download_items.dart';
import '../services/sermon_service.dart';
import '../pages/sermon_detail_page.dart';
import '../utils/app_nav.dart';

String offlineLabel(String locale, String en, String hans, String hant) =>
    locale == 'en'
        ? en
        : locale == 'zh-Hant'
            ? hant
            : hans;

class SermonOfflineButton extends StatefulWidget {
  const SermonOfflineButton(
      {super.key,
      required this.sermonId,
      required this.title,
      required this.locale});
  final String sermonId, title, locale;
  @override
  State<SermonOfflineButton> createState() => _SermonOfflineButtonState();
}

class _SermonOfflineButtonState extends State<SermonOfflineButton> {
  late Future<List<AudioDownloadItem>> _parts;
  @override
  void initState() {
    super.initState();
    _parts =
        sermonDownloadItems(widget.sermonId, widget.title).then((parts) async {
      try {
        await OfflineAudioDownloads.instance.init();
      } catch (_) {/* Download action reports storage errors. */}
      return parts;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AudioDownloadItem>>(
      future: _parts,
      builder: (context, snap) {
        final parts = snap.data;
        if (parts == null || parts.isEmpty) return const SizedBox.shrink();
        final svc = OfflineAudioDownloads.instance;
        if (!svc.supported) return const SizedBox.shrink();
        return ListenableBuilder(
            listenable: svc,
            builder: (context, _) {
              final ready = svc.isReady(parts);
              final busy = parts.any((p) => [
                    AudioDownloadState.queued,
                    AudioDownloadState.downloading
                  ].contains(svc.status(p.id)?.state));
              return TextButton.icon(
                  icon: Icon(ready
                      ? Icons.download_done
                      : Icons.download_for_offline_outlined),
                  label: Text(offlineLabel(
                      widget.locale,
                      ready
                          ? 'Downloaded'
                          : busy
                              ? 'Downloading…'
                              : 'Download audio',
                      ready
                          ? '已下载'
                          : busy
                              ? '下载中…'
                              : '下载录音',
                      ready
                          ? '已下載'
                          : busy
                              ? '下載中…'
                              : '下載錄音')),
                  onPressed: () async {
                    if (!ready && !busy) {
                      final size =
                          parts.fold<int>(0, (n, p) => n + p.expectedBytes);
                      final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                                  title: Text(offlineLabel(
                                      widget.locale,
                                      'Download this sermon?',
                                      '下载这篇讲道？',
                                      '下載這篇講道？')),
                                  content: Text(
                                      '${widget.title}\n${(size / 1048576).toStringAsFixed(1)} MB'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(offlineLabel(widget.locale,
                                            'Cancel', '取消', '取消'))),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(offlineLabel(widget.locale,
                                            'Download', '下载', '下載')))
                                  ]));
                      if (confirmed != true) return;
                      try {
                        await svc.enqueue(parts);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$e')));
                        }
                        return;
                      }
                    }
                    if (context.mounted) {
                      pushPage(SermonDownloadsPage(locale: widget.locale));
                    }
                  });
            });
      });
}

class SermonDownloadsLink extends StatelessWidget {
  const SermonDownloadsLink(
      {super.key, required this.locale, this.compact = false});
  final String locale;
  final bool compact;
  @override
  Widget build(BuildContext context) => compact
      ? IconButton(
          icon: const Icon(Icons.download_for_offline_outlined),
          tooltip: offlineLabel(locale, 'Sermon downloads', '讲道下载', '講道下載'),
          onPressed: () => pushPage(SermonDownloadsPage(locale: locale)))
      : TextButton.icon(
          icon: const Icon(Icons.download_for_offline_outlined),
          label: Text(offlineLabel(locale, 'Sermon downloads', '讲道下载', '講道下載')),
          onPressed: () => pushPage(SermonDownloadsPage(locale: locale)));
}

class SermonDownloadsPage extends StatefulWidget {
  const SermonDownloadsPage({super.key, required this.locale, this.service});
  final OfflineAudioDownloads? service;
  final String locale;
  @override
  State<SermonDownloadsPage> createState() => _SermonDownloadsPageState();
}

class _SermonDownloadsPageState extends State<SermonDownloadsPage> {
  late final _svc = widget.service ?? OfflineAudioDownloads.instance;
  String? _error;
  String _query = '', _filter = 'all';
  final _selected = <String>{};
  List<AudioDownloadItem> get _visible => _svc.items.where((p) {
        final state = _svc.status(p.id)?.state;
        final matches = switch (_filter) {
          'ready' => state == AudioDownloadState.downloaded,
          'failed' => state == AudioDownloadState.failed,
          'pending' => [
              AudioDownloadState.queued,
              AudioDownloadState.downloading,
              AudioDownloadState.paused
            ].contains(state),
          _ => true,
        };
        return matches &&
            '${p.title} ${p.sermonId}'
                .toLowerCase()
                .contains(_query.toLowerCase());
      }).toList();
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(offlineLabel(
                    widget.locale,
                    'Delete ${ids.length} downloads?',
                    '删除 ${ids.length} 个下载？',
                    '刪除 ${ids.length} 個下載？')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                          offlineLabel(widget.locale, 'Cancel', '取消', '取消'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                          offlineLabel(widget.locale, 'Delete', '删除', '刪除')))
                ]));
    if (yes != true) return;
    await _act(() async {
      for (final id in ids) {
        await _svc.delete(id);
        _selected.remove(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _svc.init();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(String id) async {
    final sermons = await SermonService.instance.loadIndex();
    final matching = sermons.where((s) => s.id == id);
    if (mounted && matching.isNotEmpty) {
      pushPage(SermonDetailPage(sermon: matching.first),
          routeName: '/sermons/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    String l(String en, String zh) => offlineLabel(
        locale,
        en,
        zh,
        const {
              '讲道离线下载': '講道離線下載',
              '搜索下载': '搜尋下載',
              '已下载': '已下載',
              '待下载': '待下載',
              '失败': '失敗',
              '继续': '繼續',
              '暂停': '暫停',
              '取消队列': '取消佇列',
              '检查已保存文件': '檢查已儲存檔案',
              '重试失败项': '重試失敗項目',
              '选择当前结果': '選擇目前結果',
              '清除选择': '清除選擇',
              '删除所选': '刪除所選',
            }[zh] ??
            zh);
    return Scaffold(
        appBar: AppBar(title: Text(l('Sermon downloads', '讲道离线下载'))),
        body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListenableBuilder(
                    listenable: _svc,
                    builder: (context, _) =>
                        ListView(padding: const EdgeInsets.all(16), children: [
                          Text(l(
                              'Saved on this device. Keep this screen open while downloading.',
                              '保存在此设备。下载时请保持此页面打开。')),
                          if (kIsWeb)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(l(
                                    'Browser downloads belong to this site/browser; an installed PWA may have separate storage. The browser can remove downloads when storage is low. Open the app online before using it offline.',
                                    '网页下载属于当前网站／浏览器，安装后的 PWA 可能使用独立存储。空间不足时浏览器可能清除下载；离线使用前请先联网打开应用。'))),
                          Text(
                              '${_svc.records.length} · ${(_svc.totalBytes / 1048576).toStringAsFixed(1)} MB'),
                          TextField(
                              decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  labelText: l('Search downloads', '搜索下载')),
                              onChanged: (v) => setState(() => _query = v)),
                          Wrap(spacing: 8, children: [
                            for (final f in [
                              ('all', l('All', '全部')),
                              ('ready', l('Ready', '已下载')),
                              ('pending', l('Pending', '待下载')),
                              ('failed', l('Failed', '失败'))
                            ])
                              ChoiceChip(
                                  label: Text(f.$2),
                                  selected: _filter == f.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = f.$1)),
                          ]),
                          Wrap(spacing: 8, children: [
                            if (_svc.pendingCount > 0) ...[
                              Text(
                                  '${_svc.pendingCount} ${l('pending', '待下载')}'),
                              TextButton.icon(
                                  icon: Icon(_svc.paused
                                      ? Icons.play_arrow
                                      : Icons.pause),
                                  label: Text(_svc.paused
                                      ? l('Resume', '继续')
                                      : l('Pause', '暂停')),
                                  onPressed: () => _act(_svc.paused
                                      ? _svc.resumeAll
                                      : _svc.pauseAll)),
                              TextButton(
                                  onPressed: () => _act(_svc.cancelAll),
                                  child: Text(l('Cancel queue', '取消队列'))),
                            ],
                            TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _act(_svc.refresh),
                                label: Text(l('Check saved files', '检查已保存文件'))),
                            if (_svc.items.any((p) =>
                                _svc.status(p.id)?.state ==
                                AudioDownloadState.failed))
                              TextButton(
                                  onPressed: () => _act(_svc.retryFailed),
                                  child: Text(l('Retry failed', '重试失败项'))),
                            TextButton(
                                onPressed: () => setState(() => _selected
                                    .addAll(_visible.map((p) => p.id))),
                                child: Text(l('Select visible', '选择当前结果'))),
                            if (_selected.isNotEmpty) ...[
                              TextButton(
                                  onPressed: () => setState(_selected.clear),
                                  child: Text(l('Clear selection', '清除选择'))),
                              TextButton.icon(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: _deleteSelected,
                                  label: Text(
                                      '${l('Delete selected', '删除所选')} (${_selected.length})')),
                            ],
                          ]),
                          if (_error != null)
                            Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                          if (_svc.items.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(l(
                                    'No recordings downloaded yet. Open a sermon with audio and tap Download audio.',
                                    '尚无录音下载。打开有录音的讲道，点击「下载录音」。'))),
                          for (final item in _visible) _row(item, locale),
                        ])))));
  }

  Widget _row(AudioDownloadItem item, String locale) {
    final st = _svc.status(item.id);
    final ready = st?.state == AudioDownloadState.downloaded;
    final busy = st?.state == AudioDownloadState.queued ||
        st?.state == AudioDownloadState.downloading;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  value: _selected.contains(item.id),
                  onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(item.id);
                        } else {
                          _selected.remove(item.id);
                        }
                      })),
              if (busy)
                LinearProgressIndicator(
                    value: st?.state == AudioDownloadState.queued
                        ? null
                        : st?.progress),
              if (st != null)
                Text(ready
                    ? offlineLabel(locale, 'Ready offline', '可离线播放', '可離線播放')
                    : st.state == AudioDownloadState.paused
                        ? offlineLabel(locale, 'Paused — resume queue',
                            '已暂停，继续队列', '已暫停，繼續佇列')
                        : st.state == AudioDownloadState.failed
                            ? offlineLabel(locale, 'Download failed — retry',
                                '下载失败，请重试', '下載失敗，請重試')
                            : '${(st.received / 1048576).toStringAsFixed(1)} MB'),
              if (st?.error != null)
                Text(st!.error!, style: Theme.of(context).textTheme.bodySmall),
              Wrap(spacing: 8, children: [
                if (ready)
                  TextButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                          offlineLabel(locale, 'Open sermon', '打开讲道', '打開講道')),
                      onPressed: () => _open(item.sermonId)),
                if (!busy && !ready)
                  TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(offlineLabel(locale, 'Retry', '重试', '重試')),
                      onPressed: () async {
                        try {
                          await _svc.enqueue([item]);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      }),
                if (!busy)
                  TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(offlineLabel(locale, 'Delete', '删除', '刪除')),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                    title: Text(offlineLabel(
                                        locale,
                                        'Delete this download?',
                                        '删除此下载？',
                                        '刪除此下載？')),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(offlineLabel(
                                              locale, 'Cancel', '取消', '取消'))),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(offlineLabel(
                                              locale, 'Delete', '删除', '刪除')))
                                    ]));
                        if (yes == true) {
                          try {
                            await _svc.delete(item.id);
                          } catch (e) {
                            if (mounted) setState(() => _error = '$e');
                          }
                        }
                      })
              ])
            ])));
  }
}

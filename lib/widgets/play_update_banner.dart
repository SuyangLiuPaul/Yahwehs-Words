import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Only Play's installed-package query determines whether a tester can update.
/// Store builds never fall back to a GitHub APK with a different signing key.
class PlayUpdateBanner extends StatefulWidget {
  const PlayUpdateBanner({super.key, required this.locale});
  final String locale;
  static bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const bool.fromEnvironment('STORE_BUILD');

  @override
  State<PlayUpdateBanner> createState() => _PlayUpdateBannerState();
}

class _PlayUpdateBannerState extends State<PlayUpdateBanner>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('yahweh/play_update');
  Map<dynamic, dynamic>? _info;
  int? _dismissed;
  bool _checking = false;
  bool _acting = false;
  bool _failed = false;
  Timer? _timer;

  String _s(String en, String hans, String hant) => switch (widget.locale) {
        'zh-Hans' => hans,
        'zh-Hant' => hant,
        _ => en,
      };

  @override
  void initState() {
    super.initState();
    if (!PlayUpdateBanner.supported) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
    // Poll only during an active download while the app is in the foreground.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      if (_info?['downloading'] == true) unawaited(_check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (_checking || !PlayUpdateBanner.supported) return;
    _checking = true;
    try {
      final info = await _channel
          .invokeMapMethod<dynamic, dynamic>('check')
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // Offline/Play unavailable does not block reading or trigger APK installation.
    } finally {
      _checking = false;
    }
  }

  Future<void> _act(String method) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final ok = await _channel
          .invokeMethod<bool>(method)
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _failed = ok != true);
      await _check();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (!PlayUpdateBanner.supported || info == null) {
      return const SizedBox.shrink();
    }
    final downloaded = info['downloaded'] == true;
    final downloading = info['downloading'] == true;
    if (!downloaded &&
        !downloading &&
        (info['available'] != true || info['code'] == _dismissed)) {
      return const SizedBox.shrink();
    }
    final label = _failed
        ? _s('Open Google Play to update', '请打开 Google Play 更新',
            '請開啟 Google Play 更新')
        : downloaded
            ? _s('Update ready — restart to install', '更新已下载，重启即可安装',
                '更新已下載，重新啟動即可安裝')
            : downloading
                ? _s('Downloading update from Google Play…',
                    '正在从 Google Play 下载更新…', '正在從 Google Play 下載更新…')
                : _s('An update is available on Google Play',
                    'Google Play 有可用更新', 'Google Play 有可用更新');
    final total = (info['total'] as num?)?.toDouble() ?? 0;
    final bytes = (info['bytes'] as num?)?.toDouble() ?? 0;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: total > 0 ? (bytes / total).clamp(0, 1) : null),
          ],
          if (!downloading)
            Wrap(spacing: 8, children: [
              if (!downloaded)
                TextButton(
                  onPressed: _acting
                      ? null
                      : () => setState(() => _dismissed = info['code'] as int?),
                  child: Text(_s('Not now', '暂不', '暫不')),
                ),
              FilledButton(
                onPressed: _acting
                    ? null
                    : () => _act(_failed
                        ? 'store'
                        : downloaded
                            ? 'complete'
                            : 'start'),
                child: Text(_acting
                    ? _s('Please wait…', '请稍候…', '請稍候…')
                    : _failed
                        ? _s('Open Google Play', '打开 Google Play',
                            '開啟 Google Play')
                        : downloaded
                            ? _s('Restart now', '立即重启', '立即重新啟動')
                            : _s('Update now', '立即更新', '立即更新')),
              ),
            ]),
        ]),
      ),
    );
  }
}

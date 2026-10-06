// "Check for updates" for every build that has no GitHub self-updater:
// the web app, and the store builds (Google Play, App Store, Microsoft
// Store). Until 2026-10-06 those builds had NO manual check at all — the
// existing tile hides itself when `UpdateService.isSupported` is false —
// so a Play tester who wondered "is there a newer version?" had nothing
// to press. The automatic banners still run; this is the button.
//
// One tap asks the channel's own authority (Play's installed-package
// query, the App Store lookup, the Microsoft Store, or the web server's
// version.json), and then the admin portal's registry for release notes
// and a "must update" floor. Every failure ends in a message, never a
// crash, and in a link the reader can still follow.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:yahwehs_words/constants/app_version.dart';
import 'package:yahwehs_words/services/release_registry.dart';
import 'package:yahwehs_words/services/update_service.dart';
import 'package:yahwehs_words/utils/page_reload.dart';

enum ManualUpdateKind { upToDate, available, required, failed }

class ManualUpdateResult {
  final ManualUpdateKind kind;
  final String? version;
  final String notes;
  final Future<void> Function()? act;
  final String? actLabelEn;
  const ManualUpdateResult(this.kind,
      {this.version, this.notes = '', this.act, this.actLabelEn});
}

/// Whether this build should show the tile: everything the GitHub tile
/// does NOT cover.
bool manualUpdateTileApplies() => !UpdateService.isSupported;

/// Pure decision, separated from I/O so it can be tested: given what the
/// channel said ([channelNewer], null = couldn't ask) and the portal's
/// entry, what should the reader be told?
ManualUpdateKind decideUpdate({
  required bool? channelNewer,
  required ReleaseEntry? registry,
  required String current,
}) {
  if (registry != null &&
      registry.min.isNotEmpty &&
      UpdateService.isNewer(registry.min, current)) {
    return ManualUpdateKind.required;
  }
  if (channelNewer == true) return ManualUpdateKind.available;
  if (channelNewer == false) return ManualUpdateKind.upToDate;
  // The channel could not be asked: fall back to the portal's number.
  if (registry != null && registry.latest.isNotEmpty) {
    return UpdateService.isNewer(registry.latest, current)
        ? ManualUpdateKind.available
        : ManualUpdateKind.upToDate;
  }
  return ManualUpdateKind.failed;
}

class ManualUpdateTile extends StatefulWidget {
  const ManualUpdateTile({super.key, required this.locale, this.checker});
  final String locale;

  /// Test seam.
  final Future<ManualUpdateResult> Function()? checker;

  @override
  State<ManualUpdateTile> createState() => _ManualUpdateTileState();
}

class _ManualUpdateTileState extends State<ManualUpdateTile> {
  bool _busy = false;

  String _t(String en, String hans, String hant) => switch (widget.locale) {
        'zh-Hans' => hans,
        'zh-Hant' => hant,
        _ => en,
      };

  static const _store = bool.fromEnvironment('STORE_BUILD');
  static const _appleId = String.fromEnvironment('APPLE_ID',
      defaultValue: '6817557892');
  static const _msId =
      String.fromEnvironment('MS_STORE_ID', defaultValue: '9NVJ28XSKP67');

  Future<ManualUpdateResult> _check() async {
    final reg = await ReleaseRegistry.fetch();
    final notes = reg?.notesFor(widget.locale) ?? '';
    bool? newer;
    String? version = reg?.latest.isNotEmpty == true ? reg!.latest : null;
    Future<void> Function()? act;
    String? label;

    try {
      if (kIsWeb) {
        final r = await http
            .get(Uri.base.resolve('version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final v = (jsonDecode(r.body) as Map)['version']?.toString() ?? '';
          if (v.isNotEmpty) {
            version = v;
            newer = UpdateService.isNewer(v, kAppVersion);
            act = () async => reloadPage();
            label = 'Reload now';
          }
        }
      } else if (defaultTargetPlatform == TargetPlatform.android && _store) {
        const ch = MethodChannel('yahweh/play_update');
        final info = await ch
            .invokeMapMethod<dynamic, dynamic>('check')
            .timeout(const Duration(seconds: 15));
        if (info != null) {
          newer = info['available'] == true ||
              info['downloaded'] == true ||
              info['downloading'] == true;
          act = () async {
            try {
              final ok = await ch.invokeMethod<bool>('start');
              if (ok != true) await ch.invokeMethod<bool>('store');
            } catch (_) {
              try {
                await ch.invokeMethod<bool>('store');
              } catch (_) {
                await _openUrl(reg?.url ?? '');
              }
            }
          };
          label = 'Update on Google Play';
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows && _store) {
        const ch = MethodChannel('yahweh/store_update');
        newer = await ch
            .invokeMethod<bool>('check')
            .timeout(const Duration(seconds: 20));
        act = () => _openUrl(
            'ms-windows-store://pdp/?ProductId=$_msId', 'https://apps.microsoft.com/detail/$_msId');
        label = 'Open Microsoft Store';
      } else if ((defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) &&
          _store) {
        final mac = defaultTargetPlatform == TargetPlatform.macOS;
        final country =
            WidgetsBinding.instance.platformDispatcher.locale.countryCode ??
                'US';
        final r = await http
            .get(Uri.https('itunes.apple.com', '/lookup', {
              'id': _appleId,
              'country': country,
              'entity': mac ? 'macSoftware' : 'software',
            }))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          for (final x in (jsonDecode(r.body)['results'] as List? ?? const [])) {
            if (x['trackId'].toString() != _appleId) continue;
            final v = x['version'] as String?;
            if (v != null) {
              version = v;
              newer = UpdateService.isNewer(v, kAppVersion);
            }
          }
        }
        act = () => _openUrl(
            mac
                ? 'macappstore://apps.apple.com/app/id$_appleId'
                : 'itms-apps://apps.apple.com/app/id$_appleId',
            'https://apps.apple.com/app/id$_appleId');
        label = mac ? 'Open Mac App Store' : 'Open App Store';
      }
    } catch (_) {
      newer = null; // fall through to the portal's number
    }

    // Where nothing above gave an action, the portal's link is the way.
    if (act == null && (reg?.url ?? '').isNotEmpty) {
      act = () => _openUrl(reg!.url);
      label = 'Open download page';
    }
    final kind =
        decideUpdate(channelNewer: newer, registry: reg, current: kAppVersion);
    return ManualUpdateResult(kind,
        version: version, notes: notes, act: act, actLabelEn: label);
  }

  static Future<void> _openUrl(String primary, [String? fallback]) async {
    for (final u in [primary, if (fallback != null) fallback]) {
      if (u.isEmpty) continue;
      try {
        if (await launchUrl(Uri.parse(u),
            mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }

  String _actLabel(String? en) => switch (en) {
        'Reload now' => _t('Reload now', '立即刷新', '立即重新整理'),
        'Update on Google Play' =>
          _t('Update on Google Play', '去 Google Play 更新', '前往 Google Play 更新'),
        'Open Microsoft Store' =>
          _t('Open Microsoft Store', '打开 Microsoft Store', '開啟 Microsoft Store'),
        'Open App Store' => _t('Open App Store', '打开 App Store', '開啟 App Store'),
        'Open Mac App Store' =>
          _t('Open Mac App Store', '打开 Mac App Store', '開啟 Mac App Store'),
        _ => _t('Open download page', '打开下载页面', '開啟下載頁面'),
      };

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    ManualUpdateResult res;
    try {
      res = await (widget.checker ?? _check)();
    } catch (_) {
      res = const ManualUpdateResult(ManualUpdateKind.failed);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final title = switch (res.kind) {
      ManualUpdateKind.upToDate => _t('You’re up to date', '已是最新版本', '已是最新版本'),
      ManualUpdateKind.available => _t('A new version is available', '有新版本可用', '有新版本可用'),
      ManualUpdateKind.required =>
        _t('Please update to keep using the app', '请更新后继续使用', '請更新後繼續使用'),
      ManualUpdateKind.failed =>
        _t('Couldn’t check for updates', '暂时无法检查更新', '暫時無法檢查更新'),
    };
    final canAct = res.act != null &&
        (res.kind == ManualUpdateKind.available ||
            res.kind == ManualUpdateKind.required ||
            res.kind == ManualUpdateKind.failed);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('manual-update.dialog'),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('Installed: v$kAppVersion', '当前版本：v$kAppVersion',
                    '目前版本：v$kAppVersion')),
                if (res.version != null)
                  Text(_t('Latest: v${res.version}', '最新版本：v${res.version}',
                      '最新版本：v${res.version}')),
                if (res.kind == ManualUpdateKind.failed)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_t(
                          'Check your connection and try again.',
                          '请检查网络后重试。',
                          '請檢查網路後重試。'))),
                if (res.notes.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(res.notes)),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('Close', '关闭', '關閉'))),
          if (canAct)
            FilledButton(
                key: const ValueKey('manual-update.act'),
                onPressed: () {
                  Navigator.pop(ctx);
                  res.act!();
                },
                child: Text(_actLabel(res.actLabelEn))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.checker == null && !manualUpdateTileApplies()) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const ValueKey('manual-update.tile'),
      contentPadding: EdgeInsets.zero,
      leading: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.system_update_alt),
      title: Text(_t('Check for updates', '检查更新', '檢查更新')),
      subtitle: Text(_t('Current version v$kAppVersion',
          '当前版本 v$kAppVersion', '目前版本 v$kAppVersion')),
      onTap: _busy ? null : _tap,
    );
  }
}

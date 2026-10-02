import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_version.dart';
import '../services/update_service.dart';

/// Store eligibility is independent of a GitHub release or website deployment.
class StoreUpdateBanner extends StatefulWidget {
  const StoreUpdateBanner({super.key, required this.locale});
  final String locale;
  @override
  State<StoreUpdateBanner> createState() => _StoreUpdateBannerState();
}

class _StoreUpdateBannerState extends State<StoreUpdateBanner>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('yahweh/store_update');
  static const appleId = '6817557892';
  static const microsoftId = '9NVJ28XSKP67';
  bool available = false;
  bool checking = false;
  bool dismissed = false;
  String? version;
  DateTime? checkedAt;
  bool get supported =>
      !kIsWeb &&
      const bool.fromEnvironment('STORE_BUILD') &&
      const [TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows]
          .contains(defaultTargetPlatform);
  String text(String en, String hans, String hant) => widget.locale == 'zh-Hant'
      ? hant
      : widget.locale.startsWith('zh')
          ? hans
          : en;
  @override
  void initState() {
    super.initState();
    if (supported) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(check());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  Future<void> check() async {
    if (!supported ||
        checking ||
        (checkedAt != null &&
            DateTime.now().difference(checkedAt!) <
                const Duration(minutes: 5))) {
      return;
    }
    checking = true;
    try {
      var found = false;
      String? next;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        found = await channel
                .invokeMethod<bool>('check')
                .timeout(const Duration(seconds: 20)) ??
            false;
      } else {
        final country =
            WidgetsBinding.instance.platformDispatcher.locale.countryCode ??
                'US';
        final uri = Uri.https('itunes.apple.com', '/lookup', {
          'id': appleId,
          'country': country,
          'entity': defaultTargetPlatform == TargetPlatform.macOS
              ? 'macSoftware'
              : 'software'
        });
        final response =
            await http.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          for (final result in (body['results'] as List? ?? const [])) {
            if (result['trackId'].toString() != appleId) continue;
            next = result['version'] as String?;
            found = next != null && UpdateService.isNewer(next, kAppVersion);
          }
        }
      }
      if (mounted) {
        setState(() {
          if (version != next) dismissed = false;
          available = found;
          version = next;
        });
      }
    } catch (_) {
      /* Offline and missing native support never prevent reading. */
    } finally {
      checking = false;
      checkedAt = DateTime.now();
    }
  }

  Future<void> openStore() async {
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final native = Uri.parse(windows
        ? 'ms-windows-store://pdp/?ProductId=$microsoftId'
        : defaultTargetPlatform == TargetPlatform.macOS
            ? 'macappstore://apps.apple.com/app/id$appleId'
            : 'itms-apps://apps.apple.com/app/id$appleId');
    final fallback = Uri.parse(windows
        ? 'https://apps.microsoft.com/detail/$microsoftId'
        : 'https://apps.apple.com/app/id$appleId');
    var opened = false;
    try {
      opened = await launchUrl(native, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      try {
        opened =
            await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text(
              'Open your app store to update.', '请打开应用商店更新。', '請開啟應用商店更新。'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!supported || !available || dismissed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
        color: scheme.primaryContainer,
        padding: const EdgeInsets.all(12),
        child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.system_update_alt),
              Text(version == null
                  ? text('An update is available in Microsoft Store',
                      'Microsoft Store 有可用更新', 'Microsoft Store 有可用更新')
                  : text('Version v$version is available in App Store',
                      'App Store 有新版本 v$version', 'App Store 有新版本 v$version')),
              TextButton(
                  onPressed: () => setState(() => dismissed = true),
                  child: Text(text('Not now', '暂不', '暫不'))),
              FilledButton(
                  onPressed: openStore,
                  child: Text(text('Update now', '立即更新', '立即更新')))
            ]));
  }
}

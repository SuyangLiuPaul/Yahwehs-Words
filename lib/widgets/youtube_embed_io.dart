import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'package:yahwehs_words/widgets/youtube_embed_src.dart';

/// The YouTube player, embedded in-app on iOS, Android and macOS.
///
/// 2026-08-23, from the user watching a featured video on the iPhone:
/// "iOS版本featured video跳到YouTube是特意的还是留在app上看" — asked
/// twice in one evening, which is its own answer. Linking out WAS
/// deliberate (the old stub's six-target reasoning), but the user wants
/// to stay in the app, so the three platforms with a real webview now
/// get the same youtube-nocookie embed the web build uses.
///
/// Windows and Linux still return null and keep the link-out path:
/// `webview_flutter` compiles there (it is a federated interface) but
/// has no implementation, so the gate is a RUNTIME platform check —
/// which is exactly what keeps all six targets building from one file
/// where a compile-time split could not tell desktop apart.
Widget? youtubeEmbed(String videoId, {int startSeconds = 0}) {
  if (!(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
    return null;
  }
  return _YoutubeEmbed(videoId: videoId, startSeconds: startSeconds);
}

/// Always null here: the position-preserving language switch is web-only
/// for now.
///
/// The web build reads the player over `postMessage`. This one runs the
/// same iframe one layer down, inside a `webview_flutter` page we wrote,
/// so the answer would have to come back over a JS channel from that
/// wrapper — a second, differently-shaped mechanism, on the three
/// platforms hardest to verify from here. Returning null means
/// [youtubeEmbed]'s `startSeconds` stays 0 on native and the URL is
/// byte-for-byte the one that has been shipping, so nothing about
/// native playback changes while this is unbuilt.
int? youtubeEmbedPositionSeconds(String videoId) => null;

class _YoutubeEmbed extends StatefulWidget {
  const _YoutubeEmbed({required this.videoId, this.startSeconds = 0});

  final String videoId;
  final int startSeconds;

  @override
  State<_YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<_YoutubeEmbed> {
  late final WebViewController _controller;

  /// 2026-10-03, from the owner: some YouTube songs on iPhone "keep
  /// loading". The wrapper page has no way to say the player never came
  /// up — a blocked or stalled request leaves YouTube's own spinner on
  /// screen forever with nothing to tap. The wrapper now reports the
  /// iframe's `load` event; if it has not arrived in [_loadTimeout], or
  /// the page itself fails to load, the spinner is replaced by a retry.
  static const _loadTimeout = Duration(seconds: 15);
  bool _loaded = false;
  bool _failed = false;
  Timer? _watchdog;

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_loadTimeout, () {
      if (mounted && !_loaded) setState(() => _failed = true);
    });
  }

  void _load() {
    _loaded = false;
    _failed = false;
    _armWatchdog();
    _controller.loadHtmlString(
        _wrapperHtml(widget.videoId, widget.startSeconds),
        baseUrl: 'https://yswords-qat.netlify.app');
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // WebKit needs two things declared AT CREATION or inline playback
    // silently degrades: without `allowsInlineMediaPlayback` iOS hands
    // the video to the system fullscreen player the moment it starts
    // (the jump-out this widget exists to remove, one layer down), and
    // without an empty `mediaTypesRequiringUserAction` the autoplay in
    // the embed URL is ignored — the user taps the thumbnail and then
    // must tap the player's own button, the same video needing two
    // plays. Android's equivalent is a setter after creation.
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..addJavaScriptChannel('YtLoaded', onMessageReceived: (_) {
        _watchdog?.cancel();
        if (mounted) setState(() => _loaded = true);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted && !_loaded) {
            setState(() => _failed = true);
          }
        },
      ))
      // v1.4.130 loaded the embed URL as the TOP document and every
      // video failed with "Error 153 — Video player configuration
      // error". 153 is YouTube refusing an embed whose request carries
      // no embedding page: the iframe player is designed to live INSIDE
      // a page, and a bare webview navigation has no parent origin and
      // sends no Referer. So the player ships wrapped in a minimal
      // page, and `baseUrl` names an origin we control — the same one
      // the media-proxy fallback uses — which is what the Referer is
      // derived from.
      ;
    _load();
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Mirrors the web build's iframe (`youtube_embed_web.dart`): same
  /// nocookie host, same allow list (including the clipboard-write the
  /// player's own "copy link" needs), plus `playsinline` and
  /// `autoplay` — the widget only mounts after the thumbnail tap, so
  /// starting immediately is honouring that tap.
  ///
  /// The URL now comes from the shared [youtubeEmbedSrc] rather than a
  /// second copy of the same string, which is how the two stopped
  /// mirroring each other last time. `enableJsApi` is off here and
  /// [startSeconds] is always 0 (see [youtubeEmbedPositionSeconds]), so
  /// what this builds is byte-for-byte the URL that was here before.
  static String _wrapperHtml(String id, int startSeconds) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}
iframe{border:0;width:100%;height:100%}</style></head><body>
<iframe onload="try{YtLoaded.postMessage('1')}catch(e){}" src="${youtubeEmbedSrc(id, startSeconds: startSeconds)}"
 allow="accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen; clipboard-write"
 allowfullscreen></iframe></body></html>''';

  static String _lang(BuildContext context) {
    final l = Localizations.localeOf(context);
    if (l.languageCode != 'zh') return 'en';
    final tw = l.scriptCode == 'Hant' ||
        l.countryCode == 'TW' ||
        l.countryCode == 'HK';
    return tw ? 'zh-Hant' : 'zh-Hans';
  }

  static const _slow = {
    'zh-Hans': '视频加载太久了',
    'zh-Hant': '影片載入太久了',
    'en': 'The video is taking too long to load',
  };
  static const _retry = {
    'zh-Hans': '重试',
    'zh-Hant': '重試',
    'en': 'Retry',
  };

  @override
  Widget build(BuildContext context) {
    final web = WebViewWidget(controller: _controller);
    if (!_failed) return web;
    final lang = _lang(context);
    return Stack(fit: StackFit.expand, children: [
      web,
      Container(
        color: const Color(0xFF000000),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_slow[lang]!,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(_load),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: Text(_retry[lang]!),
          ),
        ]),
      ),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yahwehs_words/services/admin_overlay.dart';

/// The announcement set in the admin portal. Dismissing hides THIS text
/// for good (stored by its id); a new or edited announcement shows again.
/// Renders nothing when there is none — nearly always.
class AdminAnnouncementBanner extends StatefulWidget {
  const AdminAnnouncementBanner(
      {super.key, required this.locale, required this.announcement});
  final String locale;
  final AdminAnnouncement? announcement;

  @override
  State<AdminAnnouncementBanner> createState() =>
      _AdminAnnouncementBannerState();
}

class _AdminAnnouncementBannerState extends State<AdminAnnouncementBanner> {
  static const _key = 'admin.announcement.dismissed';
  String? _dismissedId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _dismissedId = p.getString(_key);
          _loaded = true;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    if (a == null || !_loaded || a.id == _dismissedId) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final bg = a.warn ? scheme.errorContainer : scheme.primaryContainer;
    final fg = a.warn ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: const ValueKey('admin.announcement'),
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: a.url.isEmpty
              ? null
              : () => launchUrl(Uri.parse(a.url),
                  mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(children: [
              Icon(a.warn ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                  color: fg),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(a.textFor(widget.locale),
                      style: TextStyle(color: fg, height: 1.4))),
              IconButton(
                key: const ValueKey('admin.announcement.close'),
                icon: Icon(Icons.close, color: fg),
                tooltip: switch (widget.locale) {
                  'zh-Hans' => '关闭',
                  'zh-Hant' => '關閉',
                  _ => 'Dismiss',
                },
                onPressed: () async {
                  setState(() => _dismissedId = a.id);
                  try {
                    (await SharedPreferences.getInstance())
                        .setString(_key, a.id);
                  } catch (_) {}
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

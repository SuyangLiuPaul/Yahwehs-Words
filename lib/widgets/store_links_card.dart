import 'package:flutter/material.dart';
import 'package:yahwehs_words/services/link_opener.dart';

/// Store and testing links share the website's installation guide so that
/// approval status and invitation instructions can change without a new binary.
class StoreLinksCard extends StatelessWidget {
  const StoreLinksCard({super.key, required this.locale});
  final String locale;

  @override
  Widget build(BuildContext context) {
    final chinese = locale.startsWith('zh');
    final traditional = locale == 'zh-Hant';
    String text(String en, String hans, String hant) =>
        chinese ? (traditional ? hant : hans) : en;
    Widget link(IconData icon, String label, String url) => OutlinedButton.icon(
          onPressed: () =>
              LinkOpener.openExternally(context, url, locale: locale),
          icon: Icon(icon, size: 20),
          label: Text(label),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text('Get the app', '下载与测试版', '下載與測試版'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text(
                'Store downloads, beta invitations, and the latest packages.',
                '商店下载、测试版加入步骤和最新安装包。',
                '商店下載、測試版加入步驟和最新安裝包。')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              link(Icons.window, 'Microsoft Store',
                  'https://apps.microsoft.com/detail/9NVJ28XSKP67'),
              link(
                  Icons.apple,
                  text('Apple · App Store & TestFlight',
                      'Apple · 商店与 TestFlight', 'Apple · 商店與 TestFlight'),
                  'https://yahwehword.com/beta#words-apple'),
              link(
                  Icons.android,
                  text('Google Play · Join beta', 'Google Play · 加入测试',
                      'Google Play · 加入測試'),
                  'https://yahwehword.com/beta#words-android'),
              link(
                  Icons.download_outlined,
                  text('Latest packages', '最新安装包', '最新安裝包'),
                  'https://github.com/SuyangLiuPaul/Yahwehs-Words/releases/latest'),
            ]),
          ],
        ),
      ),
    );
  }
}

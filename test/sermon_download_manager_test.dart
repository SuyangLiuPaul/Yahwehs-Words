import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/services/offline_audio_downloads.dart';
import 'package:yahwehs_words/widgets/sermon_offline_downloads.dart';
import 'offline_audio_downloads_test.dart' show Store, item, second;

void main() {
  for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
    testWidgets('download manager search and selection fit phone: $locale',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'sermons.downloads.v1': jsonEncode([
          const AudioDownloadRecord(item, 6).toJson(),
          const AudioDownloadRecord(second, 6).toJson()
        ])
      });
      final store = Store()..files.addAll([item.id, second.id]);
      final svc = OfflineAudioDownloads(storage: store);
      await svc.init();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: SermonDownloadsPage(locale: locale, service: svc))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Talk B');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, 'Talk A'), findsNothing);
      expect(find.widgetWithText(CheckboxListTile, 'Talk B'), findsOneWidget);
      final select = find.text(locale == 'en'
          ? 'Select visible'
          : locale == 'zh-Hant'
              ? '選擇目前結果'
              : '选择当前结果');
      await tester.ensureVisible(select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      expect(
          find.widgetWithText(
              TextButton,
              locale == 'en'
                  ? 'Delete selected (1)'
                  : locale == 'zh-Hant'
                      ? '刪除所選 (1)'
                      : '删除所选 (1)'),
          findsOneWidget);
      expect(store.files.length, 2);
      expect(tester.takeException(), isNull);
    });
  }
}

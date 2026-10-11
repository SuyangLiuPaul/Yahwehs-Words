import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/pages/song_downloads_page.dart';

void main() {
  for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
    for (final confirm in [false, true]) {
      testWidgets('$locale removal requires explicit confirmation $confirm',
          (tester) async {
        bool? result;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
          return TextButton(
            onPressed: () async {
              result = await showSongDownloadDeleteConfirmation(context,
                  title: '做你忠心朋友', locale: locale);
            },
            child: const Text('Open'),
          );
        })));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.textContaining('做你忠心朋友'), findsOneWidget);
        expect(
            find.text(uiStrings['songsDeleteOne']![locale]!), findsOneWidget);
        await tester
            .tap(find.text(uiStrings[confirm ? 'delete' : 'cancel']![locale]!));
        await tester.pumpAndSettle();
        expect(result, confirm);
      });
    }
  }
}

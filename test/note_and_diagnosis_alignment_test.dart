import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/widgets/verse_notes_block.dart';
import 'package:yahwehs_words/widgets/diagnosis_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahwehs_words/services/installation_diagnostics.dart';

void main() {
  testWidgets('number is vertically centred on wrapped note for both languages and font sizes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    for(final size in [18.0,32.0]) {
      final settings=AppSettings(); await tester.runAsync(() => settings.setFontSize(size));
      for(final note in ['你们的有古卷作我们的。这是一条跨行的说明，用于检查数字与文字垂直居中。','Some ancient manuscripts read our instead of your. This long note wraps across several lines.']) {
        await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:SizedBox(width:320,child:VerseNotesBlock(notes:[note],settings:settings,locale:'en',preview:0))))));
        await tester.pumpAndSettle();
        expect(tester.widget<Table>(find.byType(Table)).defaultVerticalAlignment,TableCellVerticalAlignment.middle);
        final digits=find.byWidgetPredicate((w)=>w is Text && isNoteMarkerText(w.data??''));
        expect(digits,findsOneWidget);
        expect((tester.getCenter(digits).dy-tester.getCenter(find.text(note)).dy).abs(),lessThan(1));
        expect(tester.takeException(),isNull);
      }
      settings.dispose();
      await tester.pump(const Duration(seconds: 1));
    }
  });
  testWidgets('diagnosis icon is centred beside heading and report buttons stay usable', (tester) async {
    SharedPreferences.setMockInitialValues({});InstallationDiagnostics.clearMemoryForTest();
    for(final locale in ['en','zh-Hans','zh-Hant']) {
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(1.5)),child:SingleChildScrollView(child:SizedBox(width:320,child:DiagnosisTile(key:ValueKey(locale),locale:locale)))))));
      await tester.pumpAndSettle();
      final title=find.text(locale=='en'?'Diagnosis ID':locale=='zh-Hans'?'诊断编号':'診斷編號');
      final icon=find.byIcon(Icons.bug_report_outlined);
      expect(icon,findsOneWidget);expect((tester.getCenter(icon).dy-tester.getCenter(title).dy).abs(),lessThan(1));
      for(final button in tester.widgetList<TextButton>(find.byType(TextButton))) {expect(button.onPressed,isNotNull);}
      expect(tester.takeException(),isNull);
    }
  });
}

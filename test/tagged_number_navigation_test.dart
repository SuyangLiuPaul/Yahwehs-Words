import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/tagged_text_service.dart';
import 'package:yahwehs_words/utils/strongs_inline.dart';
import 'package:yahwehs_words/widgets/tagged_number_picker.dart';

void main() {
  test('primary, implied and s2 retain distinct identities without grammar',
      () {
    final run = TaggedRun.fromJson({
      'w': '每日，',
      's': 'G2596',
      'i': ['G2250', 'G2250', 'G0'],
      's2': ['G2596', 'G3588'],
      'g': ['G5748']
    });
    expect(run.lexicalNumbers, ['G2596', 'G3588', 'G2250']);
    final printed = inlineStrongsNumbers(
        strongs: run.strongs,
        implied: run.implied,
        additional: run.additional,
        grammar: run.grammar);
    expect(printed.map((n) => n.text), ['(G2250)', 'G2596', 'G3588', 'G5748']);
    expect(
        printed.map((n) => n.lexicalNumber), ['G2250', 'G2596', 'G3588', null]);
    expect(
        TaggedRun.fromJson({
          'w': ' ',
          'i': ['H853']
        }).lexicalNumbers,
        ['H853']);
    expect(TaggedRun.fromJson({'w': 'supplied', 's': 'H0'}).lexicalNumbers,
        isEmpty);
  });
  testWidgets(
      'multi-number picker supports touch, cancel and back at large scale',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: MediaQuery(
                    data: const MediaQueryData(
                        textScaler: TextScaler.linear(1.6)),
                    child: TextButton(
                        onPressed: () async {
                          selected = await chooseTaggedNumber(context,
                              text: '每日 / every day',
                              numbers: ['G2596', 'G2250']);
                        },
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.widgetWithText(ListTile, 'G2250')).height,
        greaterThanOrEqualTo(48));
    await tester.tap(find.text('G2250'));
    await tester.pumpAndSettle();
    expect(selected, 'G2250');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
  });
}

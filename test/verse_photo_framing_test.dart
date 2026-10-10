import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/widgets/verse_photo_framing.dart';
import 'package:yahwehs_words/widgets/verse_photo_framing_dialog.dart';

void main() {
  test('pan respects both crop edges and retains image proportions', () {
    const f = VersePhotoFraming();
    VersePhotoFraming pan(double dx) => f.gesture(
        viewport: const Size(100, 100),
        image: const Size(300, 100),
        startFocal: const Offset(50, 50),
        focal: Offset(50 + dx, 50),
        gestureScale: 1);
    expect(pan(500).horizontal, 0);
    expect(pan(-500).horizontal, 1);
    expect(pan(50).horizontal, .25);
    expect(pan(50).vertical, .5);
  });
  test('off-centre pinch preserves the source point under the fingers', () {
    const f = VersePhotoFraming(x: .25, y: .5);
    final next = f.gesture(
        viewport: const Size(100, 100),
        image: const Size(300, 100),
        startFocal: const Offset(30, 40),
        focal: const Offset(35, 50),
        gestureScale: 2);
    // Source pixel at the initial focal point is (80,40). After zoom
    // its location is (160 - cropX,80 - cropY) = new focal point.
    expect(160 - next.horizontal * 500, closeTo(35, .001));
    expect(80 - next.vertical * 100, closeTo(50, .001));
    expect(const VersePhotoFraming(zoom: 99, x: -3, y: double.nan).scale, 4);
    expect(const VersePhotoFraming(zoom: 99, x: -3, y: double.nan).alignment,
        const Alignment(-1, 0));
  });
  testWidgets('real crop pixels cover wide and tall frames at both edges',
      (tester) async {
    final png = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.drawRect(const Rect.fromLTWH(0, 0, 100, 100),
          Paint()..color = const Color(0xffff0000));
      c.drawRect(const Rect.fromLTWH(100, 0, 100, 100),
          Paint()..color = const Color(0xff00ff00));
      c.drawRect(const Rect.fromLTWH(200, 0, 100, 100),
          Paint()..color = const Color(0xff0000ff));
      final image = await recorder.endRecording().toImage(300, 100);
      final b = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return b!.buffer.asUint8List();
    }))!;
    final provider = MemoryImage(png);
    for (final size in [const Size(100, 100), const Size(50, 150)]) {
      for (final x in [0.0, 1.0]) {
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            home: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VersePhotoBackground(
                            photo: provider,
                            framing: VersePhotoFraming(zoom: 2, x: x),
                            background: Colors.black))))));
        await tester
            .runAsync(() => precacheImage(provider, key.currentContext!));
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final b = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          image.dispose();
          return b!.buffer.asUint8List();
        }))!;
        for (final offset in [
          0,
          (size.width.toInt() * size.height.toInt() - 1) * 4
        ]) {
          expect(bytes[offset + 3], 255,
              reason: 'crop must never reveal blank corners');
          expect(bytes[offset + (x == 0 ? 0 : 2)], 255,
              reason: 'left/right framing must export the chosen edge');
        }
      }
    }
  });
  testWidgets('framing dialog supports pan/pinch/reset/cancel and reopen',
      (tester) async {
    VersePhotoFraming current = const VersePhotoFraming();
    VersePhotoFraming? answer;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      answer = await showDialog<VersePhotoFraming>(
                          context: context,
                          builder: (_) => VersePhotoFramingDialog(
                              initial: current,
                              photoSize: const Size(300, 100),
                              cardSize: const Size(100, 100),
                              locale: 'en',
                              cardBuilder: (f) => SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: ColoredBox(color: Colors.blue))));
                      if (answer != null) current = answer!;
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final frame = find.byKey(const ValueKey('verse-photo-viewfinder'));
    final drag = await tester.startGesture(tester.getCenter(frame));
    await drag.moveBy(const Offset(20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(30, 0));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this framing'));
    await tester.pumpAndSettle();
    expect(current.horizontal, lessThan(.5));
    expect(current.scale, 1.25);
    final saved = current;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.text('Reset framing'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(current, same(saved));
    expect(answer, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final centre = tester.getCenter(frame);
    final a =
        await tester.startGesture(centre - const Offset(30, 0), pointer: 1);
    final b =
        await tester.startGesture(centre + const Offset(30, 0), pointer: 2);
    await tester.pump();
    await a.moveTo(centre - const Offset(60, 0));
    await b.moveTo(centre + const Offset(60, 0));
    await tester.pump();
    await a.moveTo(centre - const Offset(90, 0));
    await b.moveTo(centre + const Offset(90, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this framing'));
    await tester.pumpAndSettle();
    expect(current.scale, greaterThan(1.25));
    expect(tester.takeException(), isNull);
  });
}

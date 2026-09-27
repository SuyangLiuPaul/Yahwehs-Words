import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/utils/theme_color_helpers.dart';

/// 2026-09-28: no test imported this file before now (checked by
/// grepping test/ for the import path, not by filename guessing).
/// It backs 8 call sites across pages and widgets, all passing one of
/// five real [MaterialColor]s (grepped from those call sites): green,
/// teal, orange, red, blue.
void main() {
  double contrast(double l1, double l2) {
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  // MaterialApp wraps its theme in an AnimatedTheme, so a second
  // pumpWidget with a different `theme:` inside the SAME testWidgets
  // call still reports the FIRST brightness until the transition
  // finishes — Theme.of(context) silently lags. One pumpWidget per
  // testWidgets call (i.e. one brightness per test) sidesteps that
  // instead of chasing pumpAndSettle timing.
  Future<BuildContext> pumpAt(WidgetTester tester, Brightness b) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: b),
      home: Builder(builder: (ctx) {
        captured = ctx;
        return const SizedBox();
      }),
    ));
    return captured;
  }

  final realPalettes = <MaterialColor>[
    Colors.green,
    Colors.teal,
    Colors.orange,
    Colors.red,
    Colors.blue,
  ];

  group('paletteBg', () {
    testWidgets('light: shade100, opaque', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      for (final c in realPalettes) {
        expect(paletteBg(ctx, c), c.shade100);
      }
    });

    testWidgets('dark: shade900 at alpha 0.45', (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      for (final c in realPalettes) {
        expect(paletteBg(ctx, c), c.shade900.withValues(alpha: 0.45));
      }
    });
  });

  group('paletteFg', () {
    testWidgets('light: shade900', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      for (final c in realPalettes) {
        expect(paletteFg(ctx, c), c.shade900);
      }
    });

    testWidgets('dark: shade200', (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      for (final c in realPalettes) {
        expect(paletteFg(ctx, c), c.shade200);
      }
    });
  });

  group('paletteBorder', () {
    testWidgets('light: shade700 at alpha 0.45', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      for (final c in realPalettes) {
        expect(paletteBorder(ctx, c), c.shade700.withValues(alpha: 0.45));
      }
    });

    testWidgets('dark: shade400 at alpha 0.55', (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      for (final c in realPalettes) {
        expect(paletteBorder(ctx, c), c.shade400.withValues(alpha: 0.55));
      }
    });
  });

  group('paletteAccent', () {
    testWidgets('light: shade700', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      for (final c in realPalettes) {
        expect(paletteAccent(ctx, c), c.shade700);
      }
    });

    testWidgets('dark: shade300', (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      for (final c in realPalettes) {
        expect(paletteAccent(ctx, c), c.shade300);
      }
    });
  });

  group('status* wrappers delegate to paletteAccent / paletteBg', () {
    testWidgets('light', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      expect(statusOk(ctx), paletteAccent(ctx, Colors.green));
      expect(statusWarn(ctx), paletteAccent(ctx, Colors.orange));
      expect(statusBgOk(ctx), paletteBg(ctx, Colors.green));
      expect(statusBgWarn(ctx), paletteBg(ctx, Colors.orange));
    });

    testWidgets('dark', (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      expect(statusOk(ctx), paletteAccent(ctx, Colors.green));
      expect(statusWarn(ctx), paletteAccent(ctx, Colors.orange));
      expect(statusBgOk(ctx), paletteBg(ctx, Colors.green));
      expect(statusBgWarn(ctx), paletteBg(ctx, Colors.orange));
    });
  });

  group('contrast direction — the file\'s stated purpose', () {
    // Luminance is a linear combination of (linearized) channel
    // values, and Color.computeLuminance() already linearizes before
    // combining, so blending luminances directly (as below) is exact,
    // not an approximation of blending the colors first.
    testWidgets('light: paletteFg is darker than paletteBg', (tester) async {
      final ctx = await pumpAt(tester, Brightness.light);
      for (final c in realPalettes) {
        final bgLum = paletteBg(ctx, c).computeLuminance();
        final fgLum = paletteFg(ctx, c).computeLuminance();
        expect(fgLum, lessThan(bgLum), reason: '${c.toString()} in light mode');
      }
    });

    testWidgets('dark: paletteFg is lighter than paletteBg composited over the scaffold',
        (tester) async {
      final ctx = await pumpAt(tester, Brightness.dark);
      // paletteBg is shade900 at alpha 0.45 in dark mode — translucent,
      // so computeLuminance() on it directly would silently ignore the
      // alpha. Composite over the actual dark scaffold surface first.
      final surfaceLum =
          Theme.of(ctx).scaffoldBackgroundColor.computeLuminance();
      for (final c in realPalettes) {
        final rawBgLum = c.shade900.computeLuminance();
        final groundLum = surfaceLum * (1 - 0.45) + rawBgLum * 0.45;
        final fgLum = paletteFg(ctx, c).computeLuminance();
        expect(fgLum, greaterThan(groundLum), reason: '${c.toString()} in dark mode');
      }
    });
  });

  // Not asserted (measuring, not fixing, per this iteration's scope):
  // light-mode orange measures ~3.0:1 (contrast(0.778, 0.227)), below
  // the 4.5:1 WCAG-AA text threshold that every other real palette
  // clears (light ~4.7–6.8:1, dark ~4.6–7.1:1). See
  // docs/autonomous-queue.md for the filed finding — this is a design
  // call for the user, not something this test should paper over by
  // asserting a threshold the code doesn't actually meet.
  test('measured contrast — orange (light) is the outlier, recorded not asserted',
      () {
    final bgLum = Colors.orange.shade100.computeLuminance();
    final fgLum = Colors.orange.shade900.computeLuminance();
    expect(contrast(bgLum, fgLum), closeTo(2.99, 0.05));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/utils/responsive.dart';

/// `ResponsiveBreakpoints` (lib/utils/responsive.dart) is pure static
/// logic used by 23 files under lib/ but had zero behavioural test
/// coverage before this file (confirmed: `grep -rln DeviceClass test/`
/// returns only this file — there is no other test reference to
/// `DeviceClass` at all). Every boundary and
/// device figure below was measured against the current file, not
/// invented — if an assertion here disagrees with the code, the
/// assertion is wrong, not the code (the breakpoints are tuned from
/// named user device reports; see the file's own comments).
void main() {
  group('classOf boundary exactness (< vs <= is the regression class)', () {
    test('360: real 360-wide Androids must classify as phone, not miniPhone',
        () {
      expect(ResponsiveBreakpoints.classOf(359), DeviceClass.miniPhone);
      expect(ResponsiveBreakpoints.classOf(360), DeviceClass.phone);
    });

    test('600', () {
      expect(ResponsiveBreakpoints.classOf(599), DeviceClass.phone);
      expect(ResponsiveBreakpoints.classOf(600), DeviceClass.tablet);
    });

    test('1024: iPad Pro 12.9" portrait sits exactly here and is desktop',
        () {
      expect(ResponsiveBreakpoints.classOf(1023), DeviceClass.tablet);
      expect(ResponsiveBreakpoints.classOf(1024), DeviceClass.desktop);
    });

    test('1920: a 1920-wide viewport is tv, not desktop', () {
      expect(ResponsiveBreakpoints.classOf(1919), DeviceClass.desktop);
      expect(ResponsiveBreakpoints.classOf(1920), DeviceClass.tv);
    });
  });

  group('cross-function invariants, swept across a range so a '
      'half-applied threshold edit gets caught', () {
    final widths = [
      for (var w = 0.0; w <= 2200; w += 1) w,
    ];

    test('isPhone(w) <=> classOf(w) in {miniPhone, phone}', () {
      for (final w in widths) {
        final dc = ResponsiveBreakpoints.classOf(w);
        final isPhoneClass =
            dc == DeviceClass.miniPhone || dc == DeviceClass.phone;
        expect(ResponsiveBreakpoints.isPhone(w), isPhoneClass, reason: 'w=$w');
      }
    });

    test('isTabletOrWider(w) is the exact complement of isPhone(w)', () {
      for (final w in widths) {
        expect(ResponsiveBreakpoints.isTabletOrWider(w),
            !ResponsiveBreakpoints.isPhone(w),
            reason: 'w=$w');
      }
    });

    test('isDesktopOrWider(w) <=> classOf(w) in {desktop, tv}', () {
      for (final w in widths) {
        final dc = ResponsiveBreakpoints.classOf(w);
        final isDesktopClass = dc == DeviceClass.desktop || dc == DeviceClass.tv;
        expect(ResponsiveBreakpoints.isDesktopOrWider(w), isDesktopClass,
            reason: 'w=$w');
      }
    });
  });

  group('scale-like getters are non-decreasing miniPhone -> tv', () {
    const order = [
      DeviceClass.miniPhone,
      DeviceClass.phone,
      DeviceClass.tablet,
      DeviceClass.desktop,
      DeviceClass.tv,
    ];

    void expectNonDecreasing(
        String name, double Function(DeviceClass) getter) {
      test(name, () {
        for (var i = 1; i < order.length; i++) {
          final prev = getter(order[i - 1]);
          final cur = getter(order[i]);
          expect(cur, greaterThanOrEqualTo(prev),
              reason: '$name: ${order[i - 1]}=$prev -> ${order[i]}=$cur');
        }
      });
    }

    expectNonDecreasing(
        'spacingScale', ResponsiveBreakpoints.spacingScale);
    expectNonDecreasing(
        'chapterTileSize', ResponsiveBreakpoints.chapterTileSize);
    expectNonDecreasing(
        'loadingLogoSize', ResponsiveBreakpoints.loadingLogoSize);
    expectNonDecreasing(
        'verseIndent', ResponsiveBreakpoints.verseIndent);
    expectNonDecreasing(
        'readingPadding', ResponsiveBreakpoints.readingPadding);
    expectNonDecreasing(
        'headerInset', ResponsiveBreakpoints.headerInset);

    // maxContentWidth and settingsMaxWidth are NOT non-decreasing across
    // the full miniPhone->tv range: both return double.infinity (no
    // cap) for miniPhone/phone, then a finite, increasing cap from
    // tablet onward — infinity -> 560/1100 reads as a decrease. Assert
    // the two properties that actually hold instead of the blanket
    // claim: uncapped on phone-classes, non-decreasing across the
    // finite-capped classes.
    for (final dc in [DeviceClass.miniPhone, DeviceClass.phone]) {
      test('maxContentWidth($dc) is uncapped', () {
        expect(ResponsiveBreakpoints.maxContentWidth(dc), double.infinity);
      });
      test('settingsMaxWidth($dc) is uncapped', () {
        expect(ResponsiveBreakpoints.settingsMaxWidth(dc), double.infinity);
      });
    }

    const cappedOrder = [
      DeviceClass.tablet,
      DeviceClass.desktop,
      DeviceClass.tv,
    ];
    test('maxContentWidth is non-decreasing across tablet/desktop/tv', () {
      for (var i = 1; i < cappedOrder.length; i++) {
        expect(
            ResponsiveBreakpoints.maxContentWidth(cappedOrder[i]),
            greaterThanOrEqualTo(
                ResponsiveBreakpoints.maxContentWidth(cappedOrder[i - 1])),
            reason: '${cappedOrder[i - 1]} -> ${cappedOrder[i]}');
      }
    });
    test('settingsMaxWidth is non-decreasing across tablet/desktop/tv', () {
      for (var i = 1; i < cappedOrder.length; i++) {
        expect(
            ResponsiveBreakpoints.settingsMaxWidth(cappedOrder[i]),
            greaterThanOrEqualTo(
                ResponsiveBreakpoints.settingsMaxWidth(cappedOrder[i - 1])),
            reason: '${cappedOrder[i - 1]} -> ${cappedOrder[i]}');
      }
    });
  });

  group('documented device cases pin the tuning that shipped for '
      'named user reports', () {
    test('iPad mini / iPad / iPad Pro 11" portrait are tablet, uncropped '
        'under the 1100 cap', () {
      for (final w in [768.0, 810.0, 834.0]) {
        expect(ResponsiveBreakpoints.classOf(w), DeviceClass.tablet,
            reason: 'w=$w');
        expect(
            ResponsiveBreakpoints
                .maxContentWidth(ResponsiveBreakpoints.classOf(w)),
            greaterThanOrEqualTo(w),
            reason: 'w=$w should not be cropped');
      }
    });

    test('iPad Pro 11" landscape (1194) is desktop, uncropped under the '
        '1400 cap', () {
      expect(ResponsiveBreakpoints.classOf(1194), DeviceClass.desktop);
      expect(ResponsiveBreakpoints.maxContentWidth(DeviceClass.desktop),
          greaterThanOrEqualTo(1194));
    });

    test('Xiaomi Pad 7 Ultra landscape (~1800) is desktop and gets ~200 px '
        'margin per side, the user report that set the 1400 cap', () {
      const width = 1800.0;
      expect(ResponsiveBreakpoints.classOf(width), DeviceClass.desktop);
      final marginPerSide =
          (width - ResponsiveBreakpoints.maxContentWidth(DeviceClass.desktop)) /
              2;
      expect(marginPerSide, closeTo(200, 1));
    });
  });
}

// First dedicated coverage for BreadcrumbObserver (lib/utils/
// breadcrumb_observer.dart). `grep -rn "BreadcrumbObserver" test/` returned
// nothing before this file — error_reporter_test.dart covers the
// ErrorReporter ring buffer itself (append, cap, ordering), not this
// observer. It is wired at lib/main.dart:1303 as ONE OF TWO observers
// (BreadcrumbObserver, _UrlRestoreObserver) — not the only one.
//
// These tests exercise the observer's own logic (direct calls with real
// MaterialPageRoutes, plus one widget test driving a real Navigator).
// Whether GetX's Get.to* navigations reach navigatorObservers at all is a
// separate, unverified question this file does not claim to answer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_words/services/error_reporter.dart';
import 'package:yahwehs_words/utils/breadcrumb_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ErrorReporter.resetForTest();
  });

  List<({DateTime timestamp, String action, String? data})> crumbs() =>
      ErrorReporter.breadcrumbsForTest;

  MaterialPageRoute<void> namedRoute(String name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox(),
      );

  group('direct calls', () {
    test('didPush uses the NEW route\'s name and records a nav:push crumb',
        () {
      final observer = BreadcrumbObserver();
      final route = namedRoute('/search');

      observer.didPush(route, namedRoute('/home'));

      expect(ErrorReporter.currentRouteForTest, '/search');
      final push =
          crumbs().where((b) => b.action == 'nav:push').toList();
      expect(push, hasLength(1));
      expect(push.single.data, '/search');
    });

    test(
        'didPop sets the current route to PREVIOUS route, not the route '
        'being popped', () {
      final observer = BreadcrumbObserver();
      final popped = namedRoute('/search');
      final previous = namedRoute('/home');

      observer.didPop(popped, previous);

      expect(ErrorReporter.currentRouteForTest, '/home',
          reason: 'after a pop, the reader is back on the previous route, '
              'not the one that just closed — inverting this would make '
              'every mailed-in crash report say the wrong screen');
      final pop = crumbs().where((b) => b.action == 'nav:pop').toList();
      expect(pop, hasLength(1));
      expect(pop.single.data, 'from /search → /home');
    });

    test('didPop with no previousRoute falls back to (unknown)', () {
      final observer = BreadcrumbObserver();
      final popped = namedRoute('/search');

      observer.didPop(popped, null);

      expect(ErrorReporter.currentRouteForTest, '(unknown)');
      final pop = crumbs().where((b) => b.action == 'nav:pop').toList();
      expect(pop.single.data, 'from /search → (unknown)');
    });

    test(
        'didReplace uses the NEW route\'s name, not the old one, and '
        'records a nav:replace crumb', () {
      final observer = BreadcrumbObserver();
      final oldRoute = namedRoute('/home');
      final newRoute = namedRoute('/settings');

      observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

      expect(ErrorReporter.currentRouteForTest, '/settings');
      final replace =
          crumbs().where((b) => b.action == 'nav:replace').toList();
      expect(replace, hasLength(1));
      expect(replace.single.data, '/settings');
    });

    test('didReplace with a null newRoute falls back to (unknown)', () {
      final observer = BreadcrumbObserver();

      observer.didReplace(newRoute: null, oldRoute: namedRoute('/home'));

      expect(ErrorReporter.currentRouteForTest, '(unknown)');
      final replace =
          crumbs().where((b) => b.action == 'nav:replace').toList();
      expect(replace.single.data, '(unknown)');
    });

    test('an anonymous route falls back to its runtimeType, not (unknown)',
        () {
      final observer = BreadcrumbObserver();
      final anonymous = MaterialPageRoute<void>(builder: (_) => const SizedBox());

      observer.didPush(anonymous, namedRoute('/home'));

      expect(ErrorReporter.currentRouteForTest, 'MaterialPageRoute<void>',
          reason: 'a null/empty settings.name (typical for modal sheets) '
              'must still produce a useful crumb, distinct from a genuinely '
              'null route');
      expect(crumbs().single.data, 'MaterialPageRoute<void>');
    });

    test(
        'didRemove on a detached previousRoute records the crumb but does '
        'not move currentRoute', () {
      final observer = BreadcrumbObserver();
      final removed = namedRoute('/search');
      final previous = namedRoute('/home'); // never attached to a Navigator

      ErrorReporter.setCurrentRoute('/existing');
      observer.didRemove(removed, previous);

      expect(ErrorReporter.currentRouteForTest, '/existing',
          reason: 'a detached route is never "current" (Route.isCurrent is '
              'false when !_installed), so a route object built outside a '
              'live Navigator must never be treated as the new top');
      final remove = crumbs().where((b) => b.action == 'nav:remove').toList();
      expect(remove, hasLength(1));
      expect(remove.single.data, 'removed /search');
    });

    test('didRemove with a null previousRoute records the crumb and leaves '
        'currentRoute alone', () {
      final observer = BreadcrumbObserver();
      final removed = namedRoute('/search');

      ErrorReporter.setCurrentRoute('/existing');
      observer.didRemove(removed, null);

      expect(ErrorReporter.currentRouteForTest, '/existing');
      final remove = crumbs().where((b) => b.action == 'nav:remove').toList();
      expect(remove.single.data, 'removed /search');
    });
  });

  group('wired into a real Navigator', () {
    testWidgets(
        'push then pop on a live Navigator produces the matching crumb '
        'trail in order', (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [BreadcrumbObserver()],
        initialRoute: '/',
        routes: {
          '/': (_) => Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => Navigator.of(ctx).pushNamed('/next'),
                    child: const Text('go'),
                  ),
                ),
              ),
          '/next': (_) => const Scaffold(body: Text('next page')),
        },
      ));

      // The initial route push is itself a nav:push crumb — this proves
      // the observer is actually wired into the tree, not just callable
      // in isolation (the planning item's stated point of this file).
      expect(crumbs().where((b) => b.action == 'nav:push'), hasLength(1));
      expect(ErrorReporter.currentRouteForTest, '/');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(ErrorReporter.currentRouteForTest, '/next');
      expect(crumbs().where((b) => b.action == 'nav:push'), hasLength(2));

      Navigator.of(tester.element(find.text('next page'))).pop();
      await tester.pumpAndSettle();

      expect(ErrorReporter.currentRouteForTest, '/',
          reason: 'popping back off /next must restore the previous '
              'route as current, proving the pop wiring (not just push) '
              'reaches this observer through a real Navigator');
      final pop = crumbs().where((b) => b.action == 'nav:pop').toList();
      expect(pop, hasLength(1));
      expect(pop.single.data, 'from /next → /');
    });

    testWidgets(
        'removeRoute on the TOP route repoints currentRoute to the route '
        'underneath and records a nav:remove crumb', (tester) async {
      final removedRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/next'),
        builder: (_) => const Scaffold(body: Text('next page')),
      );

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [BreadcrumbObserver()],
        initialRoute: '/',
        routes: {
          '/': (_) => Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => Navigator.of(ctx).push(removedRoute),
                    child: const Text('go'),
                  ),
                ),
              ),
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(ErrorReporter.currentRouteForTest, '/next');

      Navigator.of(tester.element(find.text('next page')))
          .removeRoute(removedRoute);
      await tester.pumpAndSettle();

      expect(ErrorReporter.currentRouteForTest, '/',
          reason: 'removing the route that was on top leaves the route '
              'underneath as current — the same as a pop, just without '
              'the pop gesture/animation');
      final remove = crumbs().where((b) => b.action == 'nav:remove').toList();
      expect(remove, hasLength(1));
      expect(remove.single.data, 'from /next → /');
    });

    testWidgets(
        'removeRouteBelow the top route leaves currentRoute unchanged but '
        'still records a nav:remove crumb', (tester) async {
      final middleRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/next'),
        builder: (_) => const Scaffold(body: Text('next page')),
      );
      final topRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/deeper'),
        builder: (_) => const Scaffold(body: Text('deeper page')),
      );

      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [BreadcrumbObserver()],
        initialRoute: '/',
        routes: {
          '/': (_) => Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => Navigator.of(ctx).push(middleRoute),
                    child: const Text('go'),
                  ),
                ),
              ),
        },
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('next page'))).push(topRoute);
      await tester.pumpAndSettle();
      expect(ErrorReporter.currentRouteForTest, '/deeper');

      Navigator.of(tester.element(find.text('deeper page')))
          .removeRouteBelow(topRoute);
      await tester.pumpAndSettle();

      expect(ErrorReporter.currentRouteForTest, '/deeper',
          reason: 'the removed route (/next) was never on top, so the '
              'current-route pointer must not move — this is the negative '
              'case that proves the isCurrent guard is doing work, not '
              'just an unconditional setCurrentRoute');
      final remove = crumbs().where((b) => b.action == 'nav:remove').toList();
      expect(remove, hasLength(1));
      expect(remove.single.data, 'removed /next');
    });
  });
}

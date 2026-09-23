/// NavigatorObserver that pushes a breadcrumb to `ErrorReporter`
library;
//
/// on every route transition, AND keeps the reporter's
/// "current route" pointer fresh so any error captured later
/// knows where the user was.
///
/// 2026-05-24 (v1.3.21): added alongside ErrorReporter so a crash
/// email shows the navigation trail leading up to the error
/// (e.g. "Dashboard → SearchPage → BibleReadingPane" then 💥).
///
/// Wire by adding to `Get.create`'s `navigatorObservers` OR (since
/// the app uses GetX) on the top-level GetMaterialApp. The
/// constructor takes no args; share one instance for the whole app
/// lifetime.

import 'package:flutter/material.dart';

import 'package:yahwehs_words/services/error_reporter.dart';

class BreadcrumbObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _routeName(route);
    ErrorReporter.setCurrentRoute(name);
    ErrorReporter.breadcrumb('nav:push', data: name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _routeName(previousRoute);
    ErrorReporter.setCurrentRoute(name);
    ErrorReporter.breadcrumb('nav:pop',
        data: 'from ${_routeName(route)} → $name');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = _routeName(newRoute);
    ErrorReporter.setCurrentRoute(name);
    ErrorReporter.breadcrumb('nav:replace', data: name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // previousRoute is the nearest still-present route below the removed
    // one. It's only the new current route if the removed route WAS the
    // top of the stack — isCurrent is false for a route removed from
    // lower in the stack (removeRouteBelow) or one already superseded by
    // a push that landed first (pushAndRemoveUntil).
    if (previousRoute?.isCurrent == true) {
      final name = _routeName(previousRoute);
      ErrorReporter.setCurrentRoute(name);
      ErrorReporter.breadcrumb('nav:remove',
          data: 'from ${_routeName(route)} → $name');
    } else {
      ErrorReporter.breadcrumb('nav:remove',
          data: 'removed ${_routeName(route)}');
    }
  }

  String _routeName(Route<dynamic>? route) {
    if (route == null) return '(unknown)';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    // Anonymous routes (typical for modal sheets) — fall back to
    // the route's runtimeType so the breadcrumb is still useful.
    return route.runtimeType.toString();
  }
}

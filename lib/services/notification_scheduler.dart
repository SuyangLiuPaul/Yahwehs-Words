// 2026-05-24 (v1.3.0): scheduled notification dispatcher. Uses
// flutter_local_notifications' `zonedSchedule` with daily-repeat
// matchDateTimeComponents so each enabled category fires at its
// configured local time every day.
//
// Architecture: pull-based, idempotent.
//   AppSettings change → AppSettings.setX → rescheduleAll(settings)
//   App launch         → main.dart        → rescheduleAll(settings)
//
// rescheduleAll cancels every scheduled notification then re-creates
// the enabled ones with fresh content from the bundled JSON sources.
// Stale content gets refreshed every time the user opens the app or
// touches a setting — no separate refresh path needed.
//
// Web is a no-op HERE, and is not unserved: a browser tab cannot wake
// itself, so there is nothing for `zonedSchedule` to be. The web's half
// of the feature is `notification_catchup.dart`, which delivers a due
// reminder the next time the reader opens the app. Read that file's
// header for why push-with-a-service-worker was not the answer.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/notification_category.dart';
import 'package:yahwehs_words/services/notification_content.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _tzReady = false;
bool _pluginInitialized = false;

/// Initialise timezone data + flutter_local_notifications. Idempotent.
/// MUST be called once at app startup before any rescheduleAll().
Future<void> initNotificationScheduler() async {
  if (kIsWeb) return;
  if (!_tzReady) {
    tz_data.initializeTimeZones();
    try {
      // flutter_timezone 5.x returns a TimezoneInfo record; the IANA
      // name ("Australia/Melbourne") now lives on `.identifier`.
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      debugPrint('[scheduler] tz set to ${tzInfo.identifier}');
    } catch (e) {
      // Fall back to UTC on platforms where flutter_timezone fails
      // (mostly unsupported desktop builds). Daily fires still work,
      // just at UTC-relative times — visible cosmetic issue only.
      debugPrint('[scheduler] tz detection failed: $e — falling back to UTC');
    }
    _tzReady = true;
  }
  if (!_pluginInitialized) {
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      iOS: darwinInit,
      macOS: darwinInit,
      android: androidInit,
    );
    await _plugin.initialize(initSettings);
    _pluginInitialized = true;
  }
}

bool _isSupported() {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// Cancel every scheduled YsWords notification and re-create the
/// enabled categories with fresh content.
Future<void> rescheduleAll(AppSettings settings) async {
  if (!_isSupported()) return;
  await initNotificationScheduler();

  await _plugin.cancelAll();
  if (!settings.notificationsEnabled) {
    debugPrint('[scheduler] master toggle off — left empty');
    return;
  }
  if (!_tzReady) {
    debugPrint('[scheduler] tz not ready — skip');
    return;
  }

  for (final id in NotificationCategoryIds.phase1) {
    final prefs = settings.notificationCategory(id);
    if (!prefs.enabled) continue;
    try {
      await _scheduleCategory(id, prefs, settings.locale);
    } catch (e, st) {
      debugPrint('[scheduler] $id failed: $e\n$st');
    }
  }
}

const _kAndroidChannel = AndroidNotificationDetails(
  'yswords_scheduled',
  'Scheduled Yahweh\'s Words notifications',
  channelDescription:
      'Daily Bible verse, sermon, and evidence digests',
  importance: Importance.high,
  priority: Priority.high,
);
const _kDarwinDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  presentBanner: true,
  presentList: true,
);
const _kDetails = NotificationDetails(
  android: _kAndroidChannel,
  iOS: _kDarwinDetails,
  macOS: _kDarwinDetails,
);

/// Compute the next instance of [prefs.hour]:[prefs.minute] that
/// matches one of the weekdays in prefs.weekdays. Always returns a
/// future TZDateTime.
tz.TZDateTime _nextFire(NotificationCategoryPrefs prefs) =>
    _nextFireAt(prefs.hour, prefs.minute, prefs.weekdays);

tz.TZDateTime _nextFireAt(int hour, int minute, Set<int> weekdays) {
  final now = tz.TZDateTime.now(tz.local);
  var candidate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  // Step forward at least one minute to avoid scheduling in the past.
  while (!candidate.isAfter(now) || !weekdays.contains(candidate.weekday)) {
    candidate = tz.TZDateTime(
        tz.local, candidate.year, candidate.month, candidate.day + 1, hour, minute);
  }
  return candidate;
}

/// Reading-plan reminders are booked one day at a time, two weeks ahead,
/// for EACH plan the reader is running (up to [kMaxReadingPlans]), at
/// that plan's own time when it has one.
///
/// The other categories repeat daily with the text they had when they
/// were booked — acceptable for "a verse reference", wrong for "today's
/// chapters": a repeating reminder would announce day 1's reading for
/// ever. Each booking here carries ITS day's passages, and a day that is
/// already read, or a plan that is finished, paused or not reminding,
/// books nothing. Every app open, settings change and plan change
/// re-books (cancelAll first), so the window slides forward and picks up
/// progress ticked since.
///
/// Ids: 1100 + 14 * (the plan's slot) + (the day), so 1100..1211.
Future<void> _scheduleReadingPlan(
    NotificationCategoryPrefs prefs, String locale) async {
  final slots = await ReadingPlanService.instance.reminderSlots();
  var booked = 0;
  for (var k = 0; k < slots.length; k++) {
    final slot = slots[k];
    final hour = slot.hour ?? prefs.hour;
    final minute = slot.hour == null ? prefs.minute : (slot.minute ?? 0);
    var fire = _nextFireAt(hour, minute, prefs.weekdays);
    for (var i = 0; i < 14; i++) {
      final r = await ReadingPlanService.instance
          .reminderForEntry(slot.entry, fire, locale);
      if (r != null) {
        await _plugin.zonedSchedule(
          1100 + 14 * k + i,
          r.title,
          r.body,
          fire,
          _kDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: NotificationCategoryIds.readingPlan,
        );
        booked++;
      }
      // The next wanted weekday, rebuilt from calendar fields rather
      // than `add(Duration(days: 1))`, which adds 24 h and so drifts an
      // hour across a daylight-saving change.
      var next = tz.TZDateTime(
          tz.local, fire.year, fire.month, fire.day + 1, hour, minute);
      while (!prefs.weekdays.contains(next.weekday)) {
        next = tz.TZDateTime(
            tz.local, next.year, next.month, next.day + 1, hour, minute);
      }
      fire = next;
    }
  }
  debugPrint('[scheduler] reading_plan booked $booked for ${slots.length} plans');
}

Future<void> _scheduleCategory(String categoryId,
    NotificationCategoryPrefs prefs, String locale) async {
  if (categoryId == NotificationCategoryIds.readingPlan) {
    return _scheduleReadingPlan(prefs, locale);
  }
  final fire = _nextFire(prefs);
  final content = await resolveNotificationContent(categoryId, fire, locale);
  // Stable int id derived from category string so cancel-by-category
  // works without bookkeeping.
  final id = _idForCategory(categoryId);
  await _plugin.zonedSchedule(
    id,
    content.title,
    content.body,
    fire,
    _kDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    // Repeat every day at the same time. Combined with weekdays
    // filtering at fire time isn't directly supported here, so on
    // weekday-restricted categories we'll cancel+reschedule daily
    // (handled by app-launch rescheduleAll).
    matchDateTimeComponents: DateTimeComponents.time,
    payload: categoryId,
  );
  debugPrint(
      '[scheduler] $categoryId scheduled for $fire — "${content.title}"');
}

int _idForCategory(String categoryId) {
  // Pick a stable but unique-per-category int. 1000 + offset matches
  // human-readable conventions; cancel(id) targets exactly this row.
  switch (categoryId) {
    case NotificationCategoryIds.dailyVerse:
      return 1001;
    case NotificationCategoryIds.bibleEvidence:
      return 1002;
    case NotificationCategoryIds.sermonOfDay:
      return 1003;
    case NotificationCategoryIds.newsDigest:
      return 1004;
    case NotificationCategoryIds.memoryVerse:
      return 1005;
    case NotificationCategoryIds.readingPlan:
      return 1100; // plus 14 per plan slot and 0..13 per booked day
    default:
      return 1000 + categoryId.hashCode.abs() % 1000;
  }
}

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

String learningText(Map<String, String> text, String locale) =>
    text[locale] ?? text['en'] ?? '';
Map<String, String> _text(Object? value) =>
    Map<String, String>.from(value as Map? ?? const {});

class PassionEvent {
  final String id;
  final Map<String, String> title, place, period, summary;
  final List<String> refs;
  final List<String> diagramRefs;
  final int? clockHour;
  // The owner’s reference diagram supplies estimates, never Gospel times.
  final int? diagramHour;
  const PassionEvent(
      {required this.id,
      required this.title,
      required this.place,
      required this.period,
      required this.summary,
      required this.refs,
      this.diagramRefs = const [],
      this.clockHour,
      this.diagramHour});
  factory PassionEvent.fromJson(Map<String, dynamic> j) => PassionEvent(
      id: j['id'] as String,
      title: _text(j['title']),
      place: _text(j['place']),
      period: _text(j['period']),
      summary: _text(j['summary']),
      refs: (j['refs'] as List).cast<String>(),
      diagramRefs: (j['diagramRefs'] as List? ?? const []).cast<String>(),
      clockHour: j['clockHour'] as int?,
      diagramHour: j['diagramHour'] as int?);
  bool hasGospel(String? gospel) =>
      gospel == null ||
      {...refs, ...diagramRefs}.any((r) => r.startsWith('$gospel '));
  List<String> refsFor(String? gospel) => {...refs, ...diagramRefs}
      .where((r) => gospel == null || r.startsWith('$gospel '))
      .toList();
  // Mark alone names the third hour. Luke and John give no ninth-hour
  // clock for the final cry; John has no darkness interval. A filter must
  // not import another Gospel's clock silently.
  int? hourFor(String? gospel) {
    if (gospel == null) return clockHour;
    if (id == 'cross') return gospel == 'Mark' ? clockHour : null;
    if (id == 'death') {
      return gospel == 'Mark' || gospel == 'Matthew' ? clockHour : null;
    }
    if (id == 'darkness') return gospel == 'John' ? null : clockHour;
    return null;
  }
}

class BiblePrinciple {
  final String id;
  final Map<String, String> title, summary;
  final List<String> sermonIds;
  const BiblePrinciple(
      {required this.id,
      required this.title,
      required this.summary,
      required this.sermonIds});
  factory BiblePrinciple.fromJson(Map<String, dynamic> j) => BiblePrinciple(
      id: j['id'] as String,
      title: _text(j['title']),
      summary: _text(j['summary']),
      sermonIds: (j['sermonIds'] as List).cast<String>());
  bool matches(String query, String locale) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        '${learningText(title, locale)} ${learningText(summary, locale)} ${sermonIds.join(' ')}'
            .toLowerCase()
            .contains(q);
  }
}

class LearningData {
  static Future<String> Function(String) _loader =
      (path) => rootBundle.loadString(path);
  @visibleForTesting
  static void setTestLoader(Future<String> Function(String)? loader) {
    _loader = loader ?? (path) => rootBundle.loadString(path);
  }

  static Future<List<PassionEvent>> loadPassion() async {
    final j = jsonDecode(await _loader('assets/passion_wheel.json'))
        as Map<String, dynamic>;
    return (j['events'] as List)
        .map((e) => PassionEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<BiblePrinciple>> loadPrinciples() async {
    final j = jsonDecode(await _loader('assets/bible_principles.json'))
        as Map<String, dynamic>;
    return (j['principles'] as List)
        .map((e) => BiblePrinciple.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Both renderer and hit target use this clock geometry. Noon and midnight
/// share an angle but have different radii, matching the owner's two rings.
double passionClockAngle(int hour) => -math.pi / 2 + (hour % 12) * math.pi / 6;
bool passionClockDay(int hour) => hour >= 6 && hour < 18;

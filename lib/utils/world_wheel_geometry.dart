import 'dart:math' as math;
import 'package:flutter/widgets.dart';

const worldWheelStart = -4200;
const worldWheelSize = 900.0;
double worldYearAngle(int year, int end) =>
    -math.pi / 2 +
    ((year - worldWheelStart) / (end - worldWheelStart)).clamp(0.0, 1.0) *
        math.pi *
        2;
Offset worldEventPoint(int year, int streamIndex, int streams, int end) {
  final angle = worldYearAngle(year, end);
  final radius = 145.0 + streamIndex * (245.0 / math.max(1, streams - 1));
  return const Offset(450, 450) +
      Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

int? closestWorldEvent(Offset tap, List<Offset> points,
    {double tolerance = 20}) {
  var distance = tolerance;
  int? hit;
  for (var i = 0; i < points.length; i++) {
    final d = (tap - points[i]).distance;
    if (d <= distance) {
      distance = d;
      hit = i;
    }
  }
  return hit;
}

String worldYearLabel(int year, String locale) => year < 0
    ? '${locale.startsWith('zh') ? '主前' : 'BC '}${-year}'
    : '${locale.startsWith('zh') ? '主后' : 'AD '}$year';

String worldDateBasis(String basis, String locale) {
  const labels = {
    'scripture': {'en': 'Scripture', 'zh-Hans': '经文依据', 'zh-Hant': '經文依據'},
    'scripture+thiele': {
      'en': 'Scripture + Thiele reconstruction',
      'zh-Hans': '经文与提勒年代重建',
      'zh-Hant': '經文與提勒年代重建'
    },
    'conventional': {
      'en': 'Conventional historical date',
      'zh-Hans': '通行历史年代',
      'zh-Hant': '通行歷史年代'
    },
    'traditional': {
      'en': 'Traditional date',
      'zh-Hans': '传统年代',
      'zh-Hant': '傳統年代'
    },
  };
  return labels[basis]?[locale] ?? labels[basis]?['en'] ?? basis;
}

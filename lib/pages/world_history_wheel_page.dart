import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/world_history/models/wheel_history.dart';
import 'package:yahwehs_words/utils/world_wheel_geometry.dart';
import 'package:yahwehs_words/utils/font_catalog.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/app_scroll_behavior.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart';

const kWorldWheelPath = '/world-history-wheel';
const kWorldWheelTitle = {
  'en': 'World history wheel',
  'zh-Hans': '世界历史圆盘',
  'zh-Hant': '世界歷史圓盤'
};
String _l(String l, String en, String hs, String ht) => l == 'zh-Hans'
    ? hs
    : l == 'zh-Hant'
        ? ht
        : en;

class WorldHistoryWheelPage extends StatefulWidget {
  const WorldHistoryWheelPage({super.key});
  @override
  State<WorldHistoryWheelPage> createState() => _WorldHistoryWheelPageState();
}

class _WorldHistoryWheelPageState extends State<WorldHistoryWheelPage> {
  late Future<WheelHistoryData> _future;
  String _query = '';
  String? _stream;
  String _kind = 'events';
  final _transform = TransformationController();
  double _fitWidth = 0;
  final _listScroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _future = WheelHistoryService.instance.load();
  }

  @override
  void dispose() {
    _transform.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  List<WheelHistoryEvent> _events(WheelHistoryData d, String locale) => d.events
      .where((e) =>
          (_stream == null || e.stream == _stream) &&
          ('${e.titleFor(locale)} ${e.descFor(locale)} ${e.year} ${e.refs.join(' ')}'
              .toLowerCase()
              .contains(_query.toLowerCase())))
      .toList();
  void _fit(double width, double height) {
    final scale = math.min(width, height) / worldWheelSize;
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, (width - worldWheelSize * scale) / 2)
      ..setEntry(1, 3, (height - worldWheelSize * scale) / 2);
  }

  Future<void> _detail(
      String title, String body, List<String> refs, String locale,
      {List<String> datingRefs = const []}) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * .75),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text(title,
                              style: Theme.of(ctx).textTheme.headlineSmall),
                          const SizedBox(height: 12),
                          SelectableText(body,
                              scrollPhysics: kSelectableTextPhysics),
                          const SizedBox(height: 16),
                          for (final group in [
                            (
                              refs,
                              _l(locale, 'Narrative passages', '事件经文', '事件經文')
                            ),
                            (
                              datingRefs,
                              _l(locale, 'Dating evidence', '年代推算依据', '年代推算依據')
                            ),
                          ])
                            if (group.$1.isNotEmpty) ...[
                              Text(group.$2,
                                  style: Theme.of(ctx).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final r in group.$1)
                                  if (parseReference(r) != null)
                                    ActionChip(
                                        label: Text(localizePassage(r, locale)),
                                        onPressed: () async {
                                          final ref = parseReference(r);
                                          if (ref != null) {
                                            await showVersePopup(ctx, ref);
                                          }
                                        })
                              ]),
                              const SizedBox(height: 12),
                            ],
                        ]))))));
  }

  void _event(WheelHistoryEvent e, String l) {
    _detail(
        e.titleFor(l),
        '${worldYearLabel(e.year, l)}${e.approximate ? ' ≈' : ''} · ${worldDateBasis(e.basis, l)}\n\n${e.descFor(l)}',
        e.refs,
        l,
        datingRefs: e.datingRefs);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppSettings>().locale;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
        appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(kWorldWheelTitle[l] ?? kWorldWheelTitle['en']!)),
        body: FutureBuilder<WheelHistoryData>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: FilledButton(
                        onPressed: () => setState(() =>
                            _future = WheelHistoryService.instance.load()),
                        child: Text(_l(l, 'Retry', '重试', '重試'))));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final d = snap.data!;
              final events = _events(d, l);
              final end = DateTime.now().year;
              final records = <Widget>[];
              bool matches(String stream, String text) =>
                  (_stream == null || _stream == stream) &&
                  text.toLowerCase().contains(_query.toLowerCase());
              if (_kind == 'powers') {
                for (final p in d.powers) {
                  if (matches(p.stream,
                      '${p.nameFor(l)} ${p.noteFor(l)} ${p.start} ${p.refs.join(' ')}')) {
                    records.add(Card(
                        child: ListTile(
                            title: Text(p.nameFor(l)),
                            subtitle: Text(
                                '${worldYearLabel(p.start, l)} → ${p.end == null ? _l(l, 'present', '至今', '至今') : worldYearLabel(p.end!, l)}${p.approximate ? ' ≈' : ''}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _detail(
                                p.nameFor(l),
                                '${worldDateBasis(p.basis, l)}\n\n${p.noteFor(l)}',
                                p.refs,
                                l))));
                  }
                }
              }
              if (_kind == 'ministries') {
                for (final p in d.ministries) {
                  if (matches('',
                          '${p.nameFor(l)} ${p.noteFor(l)} ${p.refs.join(' ')}') ||
                      (_stream == null &&
                          '${p.nameFor(l)} ${p.noteFor(l)}'
                              .toLowerCase()
                              .contains(_query.toLowerCase()))) {
                    records.add(Card(
                        child: ListTile(
                            title: Text(p.nameFor(l)),
                            subtitle: Text(
                                '${worldYearLabel(p.start, l)} → ${worldYearLabel(p.end, l)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _detail(
                                p.nameFor(l),
                                '${p.noteFor(l)}\n\n${_l(l, 'Ministry span, not a lifespan.', '事奉时段，并非寿命。', '事奉時段，並非壽命。')}',
                                p.refs,
                                l))));
                  }
                }
              }
              if (_kind == 'nations') {
                for (final n in d.nations) {
                  if (matches(
                      n.stream, '${n.nameFor(l)} ${n.noteFor(l)} ${n.ref}')) {
                    records.add(Card(
                        child: ListTile(
                            title: Text(n.nameFor(l)),
                            subtitle: Text(localizePassage(n.ref, l)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _detail(
                                n.nameFor(l), n.noteFor(l), [n.ref], l))));
                  }
                }
              }
              if (_kind == 'events') {
                for (final e in events) {
                  records.add(Card(
                      child: ListTile(
                          key: ValueKey('world.event.${e.id}'),
                          title: Text(e.titleFor(l)),
                          subtitle: Text(
                              '${worldYearLabel(e.year, l)}${e.approximate ? ' ≈' : ''} · ${worldDateBasis(e.basis, l)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _event(e, l))));
                }
              }
              return ListView.builder(
                  controller: _listScroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length + 3,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _l(l, 'Follow a people through history',
                                    '沿着民族与年代探索', '沿著民族與年代探索'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(_l(
                                    l,
                                    'Sources and date conventions',
                                    '资料与年代说明',
                                    '資料與年代說明')),
                                children: [
                                  Text(d.meta.axisFor(l)),
                                  const SizedBox(height: 8),
                                  Text(d.meta.provenanceFor(l)),
                                  const SizedBox(height: 8),
                                  Text(d.meta.coverageFor(l)),
                                ]),
                            const SizedBox(height: 8),
                            Text(_l(
                                l,
                                'Pinch or scroll to zoom · drag to explore · tap a dot or list entry for sources. ≈ marks an approximate date.',
                                '双指或滚轮缩放 · 拖动浏览 · 点击圆点或列表查看出处。≈ 表示约略年代。',
                                '雙指或滾輪縮放 · 拖動瀏覽 · 點擊圓點或列表查看出處。≈ 表示約略年代。')),
                            const SizedBox(height: 12),
                            TextField(
                                decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: _l(
                                        l,
                                        'Search events, people, year or Scripture',
                                        '搜索事件、民族、年份或经文',
                                        '搜尋事件、民族、年份或經文'),
                                    border: const OutlineInputBorder()),
                                onChanged: (v) => setState(() => _query = v)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                                key: ValueKey(_stream),
                                initialValue: _stream,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: _l(
                                        l, 'Historical stream', '历史线索', '歷史線索'),
                                    border: const OutlineInputBorder()),
                                items: [
                                  DropdownMenuItem<String>(
                                      value: null,
                                      child: Text(_l(
                                          l, 'All streams', '全部线索', '全部線索'))),
                                  for (final stream in d.streams)
                                    DropdownMenuItem(
                                        value: stream.id,
                                        child: Text(stream.nameFor(l),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis))
                                ],
                                onChanged: _kind == 'ministries'
                                    ? null
                                    : (v) => setState(() => _stream = v)),
                            const SizedBox(height: 12),
                          ]);
                    }
                    if (i == 1) {
                      return Card(
                          clipBehavior: Clip.antiAlias,
                          child: LayoutBuilder(builder: (context, c) {
                            const height = 430.0;
                            if (_fitWidth != c.maxWidth) {
                              _fitWidth = c.maxWidth;
                              _fit(c.maxWidth, height);
                            }
                            final drawn = d.streams
                                .where(
                                    (s) => _stream == null || s.id == _stream)
                                .toList();
                            final points = [
                              for (final e in events)
                                worldEventPoint(
                                    e.year,
                                    math.max(
                                        0,
                                        drawn.indexWhere(
                                            (s) => s.id == e.stream)),
                                    drawn.length,
                                    end)
                            ];
                            return Column(children: [
                              SizedBox(
                                  height: height,
                                  child: InteractiveViewer(
                                      transformationController: _transform,
                                      constrained: false,
                                      minScale: .15,
                                      maxScale: 5,
                                      boundaryMargin:
                                          const EdgeInsets.all(1000),
                                      child: GestureDetector(
                                          onTapUp: (tap) {
                                            final hit = closestWorldEvent(
                                                tap.localPosition, points);
                                            if (hit != null) {
                                              _event(events[hit], l);
                                            }
                                          },
                                          child: CustomPaint(
                                              size: const Size(worldWheelSize,
                                                  worldWheelSize),
                                              painter: _WorldPainter(d, drawn,
                                                  events, end, l, colors))))),
                              TextButton.icon(
                                  onPressed: () => _fit(c.maxWidth, height),
                                  icon: const Icon(Icons.center_focus_strong),
                                  label: Text(
                                      _l(l, 'Reset view', '重置视图', '重設視圖'))),
                            ]);
                          }));
                    }
                    if (i == 2) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final kind in [
                                'events',
                                'powers',
                                'nations',
                                'ministries'
                              ])
                                ChoiceChip(
                                    label: Text(kind == 'events'
                                        ? _l(l, 'Events', '事件', '事件')
                                        : kind == 'powers'
                                            ? _l(l, 'Powers', '政权', '政權')
                                            : kind == 'nations'
                                                ? _l(l, 'Nations', '民族', '民族')
                                                : _l(l, 'Ministries', '事奉',
                                                    '事奉')),
                                    selected: _kind == kind,
                                    onSelected: (_) => setState(() {
                                          _kind = kind;
                                          if (kind == 'ministries') {
                                            _stream = null;
                                          }
                                        }))
                            ]),
                            Text('${records.length}',
                                style: Theme.of(context).textTheme.labelLarge),
                            if (records.isEmpty)
                              Text(_l(l, 'No matching records', '没有匹配的资料',
                                  '沒有匹配的資料'))
                          ]);
                    }
                    return records[i - 3];
                  });
            }));
  }
}

class _WorldPainter extends CustomPainter {
  final WheelHistoryData data;
  final List<WheelStream> streams;
  final List<WheelHistoryEvent> events;
  final int end;
  final String locale;
  final ColorScheme colors;
  _WorldPainter(
      this.data, this.streams, this.events, this.end, this.locale, this.colors);
  Color _color(int index) =>
      HSVColor.fromAHSV(1, index * 137.5 % 360, .58, .75).toColor();
  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(450, 450);
    final p = Paint();
    canvas.drawColor(colors.surface, BlendMode.src);
    for (var i = 0; i < streams.length; i++) {
      final radius = 145 + i * (245 / math.max(1, streams.length - 1));
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.outlineVariant;
      canvas.drawCircle(center, radius, p);
      for (final power in data.powers.where((p) => p.stream == streams[i].id)) {
        final start = worldYearAngle(power.start, end);
        final finish = worldYearAngle(power.endFor(end), end);
        p
          ..color = _color(i).withValues(alpha: .5)
          ..strokeWidth = 6;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
            math.max(.001, finish - start), false, p);
      }
    }
    p.style = PaintingStyle.fill;
    for (final e in events) {
      final index = math.max(0, streams.indexWhere((s) => s.id == e.stream));
      p.color = _color(index);
      canvas.drawCircle(worldEventPoint(e.year, index, streams.length, end),
          e.basis.startsWith('scripture') ? 3.5 : 2.5, p);
    }
    for (final year in [-4000, -3000, -2000, -1000, 1, 1000, 2000]) {
      final a = worldYearAngle(year, end);
      final point = center + Offset(math.cos(a) * 418, math.sin(a) * 418);
      final tp = TextPainter(
          text: TextSpan(
              text: worldYearLabel(year, locale),
              style: TextStyle(
                  fontSize: 15,
                  fontFamilyFallback: kCjkFontFallback,
                  color: colors.onSurface)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, point - Offset(tp.width / 2, tp.height / 2));
    }
    final tp = TextPainter(
        text: TextSpan(
            text: '${events.length}\n${_l(locale, 'events', '事件', '事件')}',
            style: TextStyle(
                fontSize: 26,
                fontFamilyFallback: kCjkFontFallback,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_WorldPainter old) => true;
}

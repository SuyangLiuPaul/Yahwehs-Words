import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yahwehs_words/utils/version_mapper.dart'
    show localeAwareBookName;
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/learning_data.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart';

const kPassionWheelPath = '/passion-wheel';
const kPassionTitle = {
  'en': 'The Passion of Jesus',
  'zh-Hans': '主耶稣受难日时间表',
  'zh-Hant': '主耶穌受難日時間表'
};
String _l(String locale, String en, String hs, String ht) => locale == 'zh-Hans'
    ? hs
    : locale == 'zh-Hant'
        ? ht
        : en;

class PassionWheelPage extends StatefulWidget {
  const PassionWheelPage({super.key});
  @override
  State<PassionWheelPage> createState() => _PassionWheelPageState();
}

class _PassionWheelPageState extends State<PassionWheelPage> {
  late Future<List<PassionEvent>> _future;
  String? _gospel;
  String _selected = 'cross';
  bool _referenceTiming = true;
  bool _showOrder = true;
  int? _selectedHour = 9;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _future = LearningData.loadPassion();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(PassionEvent e) {
    setState(() {
      _selected = e.id;
      _selectedHour = _hour(e);
    });
  }

  int? _hour(PassionEvent e) =>
      _referenceTiming ? e.diagramHour : e.hourFor(_gospel);

  void _selectHour(int hour, List<PassionEvent> events) {
    setState(() {
      _selectedHour = hour;
      final atHour = events.where((e) => _hour(e) == hour).toList();
      if (atHour.isNotEmpty) _selected = atHour.first.id;
    });
  }

  Future<void> _attachment(String locale) => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
          child: Scaffold(
              appBar: AppBar(
                  title: Text(
                      _l(locale, 'Original reference diagram', '原始参考图片',
                          '原始參考圖片'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
              body: Column(children: [
                Expanded(
                    child: InteractiveViewer(
                        key: const ValueKey('passion.attachment.viewer'),
                        minScale: .5,
                        maxScale: 6,
                        child: Center(
                            child: Image.asset(kPassionReferenceImage,
                                fit: BoxFit.contain,
                                // Keep original detail for zoom while bounding decoded memory to ~4.2 MiB.
                                cacheWidth: 1382,
                                cacheHeight: 782,
                                errorBuilder: (context, error, stack) => Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(_l(
                                        locale,
                                        'The reference image could not be loaded. Close and reopen to retry.',
                                        '参考图片暂时无法加载，请关闭后重新打开。',
                                        '參考圖片暫時無法載入，請關閉後重新打開。'))),
                                semanticLabel: _l(
                                    locale,
                                    'Original Chinese Passion clock and Gospel references',
                                    '圣经黑暗时刻时辰圈原图及经文参考',
                                    '聖經黑暗時刻時辰圈原圖及經文參考'))))),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_l(
                        locale,
                        'Source credit printed on the image: 福音电台 · fydt.org. Pinch or scroll to zoom; drag to pan. Green times are Scripture markers in the source; other placements are estimates.',
                        '原图署名：福音电台 · fydt.org。可缩放并拖动查看；原图绿色时刻是经文时辰标记，其余为估计位置。',
                        '原圖署名：福音電台 · fydt.org。可縮放並拖動查看；原圖綠色時刻是經文時辰標記，其餘為估計位置。')))
              ]))));

  Future<void> _ref(String value) async {
    final ref = parseReference(value);
    if (ref != null) await showVersePopup(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          leading: const LocalizedBackButton(),
          actions: const [LanguageSwitcherButton(alwaysVisible: true)],
          title: Text(learningText(kPassionTitle, locale),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<PassionEvent>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                  child: FilledButton(
                      onPressed: () =>
                          setState(() => _future = LearningData.loadPassion()),
                      child: Text(_l(locale, 'Retry', '重试', '重試'))));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final visible =
                snap.data!.where((e) => e.hasGospel(_gospel)).toList();
            if (visible.isEmpty) {
              return Center(
                  child: Text(_l(locale, 'No scenes in this account.',
                      '此记载没有可用场景。', '此記載沒有可用場景。')));
            }
            final selected =
                visible.where((e) => e.id == _selected).firstOrNull ??
                    visible.first;
            return LayoutBuilder(builder: (context, constraints) {
              final large = constraints.maxWidth >= 900;
              final wheel = _wheel(visible, selected, locale, colors);
              final atHour = _selectedHour == null
                  ? <PassionEvent>[selected]
                  : visible.where((e) => _hour(e) == _selectedHour).toList();
              final detail = atHour.isEmpty
                  ? Card(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_l(
                              locale,
                              '${passionHourLabel(_selectedHour!)} · No scene is assigned to this hour in the selected view.',
                              '${passionHourLabel(_selectedHour!)} · 当前视图未在此时刻安排场景。',
                              '${passionHourLabel(_selectedHour!)} · 當前視圖未在此時刻安排場景。'))))
                  : Column(children: [
                      for (final e in atHour)
                        _detail(e, locale, colors,
                            primary: e.id == atHour.first.id)
                    ]);
              return ListView(
                  controller: _scroll,
                  padding: EdgeInsets.symmetric(
                      horizontal: large ? 32 : 16, vertical: 12),
                  children: [
                    Text(
                        _l(locale, 'Explore the Gospel accounts', '探索四福音的记载',
                            '探索四福音的記載'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_l(
                        locale,
                        'Explore the attached reference diagram and read the Gospel accounts. The diagram estimates most clock positions; Gospel hours shows only explicit time statements. Compare each account rather than treating a proposed timetable as an exact chronology.',
                        '把附件参考图变为互动时辰圈，并查阅四福音。参考图大部分钟点为估计；“经文时辰”仅显示明确的时辰记载。请并列阅读，不把拟定时间表当作精确历史时序。',
                        '把附件參考圖變為互動時辰圈，並查閱四福音。參考圖大部分鐘點為估計；「經文時辰」僅顯示明確的時辰記載。請並列閱讀，不把擬定時間表當作精確歷史時序。')),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                          key: const ValueKey('passion.mode.diagram'),
                          label: Text(_l(
                              locale, 'Reference diagram', '参考图时辰', '參考圖時辰')),
                          selected: _referenceTiming,
                          onSelected: (_) => setState(() {
                                _referenceTiming = true;
                                _selectedHour = null;
                              })),
                      ChoiceChip(
                          key: const ValueKey('passion.mode.gospel'),
                          label:
                              Text(_l(locale, 'Gospel hours', '经文时辰', '經文時辰')),
                          selected: !_referenceTiming,
                          onSelected: (_) => setState(() {
                                _referenceTiming = false;
                                _selectedHour = null;
                              })),
                      OutlinedButton.icon(
                          key: const ValueKey('passion.attachment.open'),
                          onPressed: () => _attachment(locale),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                              _l(locale, 'Attached image', '查看原图附件', '查看原圖附件')))
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final g in <String?>[
                        null,
                        'Matthew',
                        'Mark',
                        'Luke',
                        'John'
                      ])
                        ChoiceChip(
                            label: Text(g == null
                                ? _l(locale, 'All four', '四福音', '四福音')
                                : localeAwareBookName(g, locale, '')),
                            selected: _gospel == g,
                            onSelected: (_) => setState(() {
                                  _gospel = g;
                                  _selectedHour = null;
                                }))
                    ]),
                    const SizedBox(height: 12),
                    if (large)
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: wheel),
                            const SizedBox(width: 24),
                            Expanded(child: detail)
                          ])
                    else ...[wheel, const SizedBox(height: 12), detail],
                    const SizedBox(height: 12),
                    Card(
                        color: colors.secondaryContainer,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_l(
                                locale,
                                'Compare the time statements: Mark 15:25 names the third hour for crucifixion; John 19:14 names about the sixth hour before Pilate. No disputed harmonisation is assumed here. Tap both references in the relevant scenes.',
                                '比较时辰记载：可15:25记钉十字架为第三时；约19:14记在彼拉多面前时约第六时。本图不预设有争议的调和解释，可在相应场景打开两处经文。',
                                '比較時辰記載：可15:25記釘十字架為第三時；約19:14記在彼拉多面前時約第六時。本圖不預設有爭議的調和解釋，可在相應場景打開兩處經文。')))),
                    const SizedBox(height: 12),
                    Text(
                        _l(locale, 'Scenes · tap to explore', '场景 · 点击查看',
                            '場景 · 點擊查看'),
                        style: Theme.of(context).textTheme.titleLarge),
                    for (final e in visible)
                      Card(
                          child: ListTile(
                              key: ValueKey('passion.scene.${e.id}'),
                              selected: e.id == selected.id,
                              leading: Icon(
                                  _hour(e) == null
                                      ? Icons.menu_book_outlined
                                      : Icons.schedule,
                                  color: colors.primary),
                              title: Text(learningText(e.title, locale)),
                              subtitle: Text(learningText(e.period, locale)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _select(e);
                                _scroll.animateTo(0,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut);
                              })),
                  ]);
            });
          }),
    );
  }

  Widget _wheel(List<PassionEvent> visible, PassionEvent selected,
      String locale, ColorScheme colors) {
    final marks = visible.where((e) => _hour(e) != null).toList();
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              LayoutBuilder(builder: (context, c) {
                final side = math.min(c.maxWidth, 560.0);
                return SizedBox(
                    width: side,
                    height: side,
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _PassionPainter(locale,
                                  showDarkness:
                                      marks.any((e) => e.id == 'darkness')))),
                      Positioned.fill(
                          child: IgnorePointer(
                              child: Center(
                                  child: SizedBox(
                                      width: side * .30,
                                      child: Text(
                                          _l(locale, 'Jesus’\nPassion',
                                              '主耶稣\n受难日', '主耶穌\n受難日'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize:
                                                  math.min(18, side * .037),
                                              fontWeight: FontWeight.bold)))))),
                      if (_referenceTiming && _showOrder)
                        Positioned.fill(
                            child: IgnorePointer(
                                child: CustomPaint(
                                    key: const ValueKey('passion.order-path'),
                                    painter: _OrderPathPainter(marks
                                        .map(_hour)
                                        .whereType<int>()
                                        .toList())))),
                      for (final hour in List.generate(24, (i) => i))
                        _marker(hour, marks, selected, side, locale),
                    ]));
              }),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                  key: ValueKey('passion.hour-selector.$_selectedHour'),
                  initialValue: _selectedHour,
                  isExpanded: true,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: _l(locale, 'Choose an hour', '选择时刻', '選擇時刻')),
                  items: [
                    for (final hour in List.generate(24, (i) => i))
                      DropdownMenuItem(
                          value: hour, child: Text(passionHourLabel(hour)))
                  ],
                  onChanged: (hour) {
                    if (hour != null) _selectHour(hour, marks);
                  }),
              const SizedBox(height: 12),
              if (_referenceTiming) ...[
                FilterChip(
                    key: const ValueKey('passion.order'),
                    selected: _showOrder,
                    label: Text(_l(locale, 'Show order of events', '显示事件顺序',
                        '顯示事件順序')),
                    onSelected: (v) => setState(() => _showOrder = v)),
                const SizedBox(height: 4),
                Text(
                    _l(
                        locale,
                        'Red line: the order of events, from the evening meal (20:00) round the night, then out through the day to the burial (17:00).',
                        '红线：事件的先后顺序，从晚餐（20:00）起，绕过夜晚，再沿白昼向外，直到安葬（17:00）。',
                        '紅線：事件的先後順序，從晚餐（20:00）起，繞過夜晚，再沿白晝向外，直到安葬（17:00）。'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 8),
              ],
              Text(
                  _l(
                      locale,
                      'Outer ring: day · inner ring: night. Tap an hour to explore. Amber outlines: diagram estimates; green: Gospel hour markers.',
                      '外圈：白昼 · 内圈：夜晚。点击时刻查看。琥珀色空心点：原图估计；绿色点：经文时辰。',
                      '外圈：白晝 · 內圈：夜晚。點擊時刻查看。琥珀色空心點：原圖估計；綠色點：經文時辰。'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _bandLegend(const Color(0xff226176),
                        _l(locale, 'Daytime work', '白天工作', '白天工作')),
                    _bandLegend(
                        const Color(0xff66529a),
                        _l(locale, 'Evening meal and family gathering',
                            '傍晚用餐与家庭团聚', '傍晚用餐與家庭團聚')),
                    _bandLegend(const Color(0xff263a68),
                        _l(locale, 'Night rest', '夜间休息', '夜間休息')),
                  ]),
              if (_referenceTiming)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_l(
                        locale,
                        'The source’s evening band includes Sabbath gatherings and meals. The night band represents usual rest; Jesus remained awake through the hearings. These bands describe the diagram, not exact event times.',
                        '原图傍晚色带包括安息日聚会与圣餐晚饭；夜间色带表示通常的睡觉时间，而主耶稣通宵受审未眠。色带说明原图的日夜分区，不代表各事件的准确钟点。',
                        '原圖傍晚色帶包括安息日聚會與聖餐晚飯；夜間色帶表示通常的睡覺時間，而主耶穌通宵受審未眠。色帶說明原圖的日夜分區，不代表各事件的準確鐘點。'))),
              if (_referenceTiming)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_l(
                        locale,
                        'Source: owner-supplied 福音电台 diagram (fydt.org). Modern times are approximate; the original image is attached above.',
                        '来源：你提供的福音电台参考图（fydt.org）。现代钟点为近似或估计，原图附件见上方。',
                        '來源：你提供的福音電台參考圖（fydt.org）。現代鐘點為近似或估計，原圖附件見上方。'))),
            ])));
  }

  Widget _bandLegend(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ]);

  Widget _marker(int hour, List<PassionEvent> marks, PassionEvent selected,
      double side, String locale) {
    final events = marks.where((e) => _hour(e) == hour).toList();
    final radius = side * (passionClockDay(hour) ? .405 : .265);
    final angle = passionClockAngle(hour);
    final center = Offset(side / 2 + math.cos(angle) * radius,
        side / 2 + math.sin(angle) * radius);
    final active = _selectedHour == hour ||
        (_selectedHour == null && events.any((e) => e.id == selected.id));
    final explicit = events.any((e) => e.hourFor(_gospel) == hour);
    final color = explicit ? const Color(0xffa1ec91) : const Color(0xffffcc68);
    final label =
        '${passionHourLabel(hour)} · ${events.isEmpty ? _l(locale, 'No assigned scene', '未安排场景', '未安排場景') : events.map((e) => learningText(e.title, locale)).join(' · ')}';
    // Circular clipping excludes overlapping rectangular corners. A separate
    // hour selector provides a larger target for every hour, including empty ones.
    return Positioned(
        left: center.dx - 16,
        top: center.dy - 16,
        width: 32,
        height: 32,
        child: Semantics(
            button: true,
            selected: active,
            label: label,
            excludeSemantics: true,
            onTap: () => _selectHour(hour, marks),
            child: Tooltip(
                message: label,
                child: ClipOval(
                    child: InkResponse(
                        key: ValueKey(events.isNotEmpty
                            ? 'passion.marker.${events.first.id}'
                            : 'passion.hour.$hour'),
                        onTap: () => _selectHour(hour, marks),
                        radius: 16,
                        child: Center(
                            child: Container(
                                width: active
                                    ? 24
                                    : events.isEmpty
                                        ? 7
                                        : 17,
                                height: active
                                    ? 24
                                    : events.isEmpty
                                        ? 7
                                        : 17,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: events.isEmpty
                                        ? Colors.white38
                                        : explicit
                                            ? color
                                            : const Color(0xff183d54),
                                    border: Border.all(
                                        color: events.isEmpty
                                            ? Colors.white38
                                            : color,
                                        width: active ? 3 : 2)),
                                child: events.length > 1
                                    ? Center(
                                        child: Text('${events.length}',
                                            style: TextStyle(
                                                color: explicit
                                                    ? Colors.black
                                                    : color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10)))
                                    : null)))))));
  }

  Widget _detail(PassionEvent e, String locale, ColorScheme colors,
          {bool primary = true}) =>
      Card(
          color: colors.primaryContainer.withValues(alpha: .35),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(learningText(e.title, locale),
                        key: ValueKey(primary
                            ? 'passion.selected.title'
                            : 'passion.detail.${e.id}.title'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    if (_referenceTiming && e.diagramHour != null) ...[
                      Text(
                          _l(
                              locale,
                              'Reference diagram: ≈ ${passionHourLabel(e.diagramHour!)}',
                              '参考图：约 ${passionHourLabel(e.diagramHour!)}',
                              '參考圖：約 ${passionHourLabel(e.diagramHour!)}'),
                          key: ValueKey(primary
                              ? 'passion.selected.diagram-time'
                              : 'passion.detail.${e.id}.diagram-time'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                    ],
                    Text(learningText(e.period, locale),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(learningText(e.place, locale)),
                    const Divider(height: 28),
                    if (_referenceTiming && e.diagramSummary.isNotEmpty) ...[
                      Text(
                          _l(locale, 'Event described in the reference diagram',
                              '原图所述事件', '原圖所述事件'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(learningText(e.diagramSummary, locale),
                          key: ValueKey('passion.diagram-summary.${e.id}')),
                      const SizedBox(height: 12),
                    ],
                    Text(learningText(e.summary, locale)),
                    const SizedBox(height: 16),
                    if (_referenceTiming && e.diagramRefs.isNotEmpty) ...[
                      Text(
                          _l(locale, 'References printed on the attached image',
                              '原图所列经文', '原圖所列經文'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final r in e.diagramRefs.where((r) =>
                            _gospel == null || r.startsWith('${_gospel!} ')))
                          ActionChip(
                              label: Text(localizePassage(r, locale)),
                              avatar:
                                  const Icon(Icons.image_outlined, size: 16),
                              onPressed: () => _ref(r))
                      ]),
                      const SizedBox(height: 16),
                    ],
                    Text(
                        _l(locale, 'Further Gospel reading', '更多福音记载',
                            '更多福音記載'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final r in e.refs.where((r) =>
                          _gospel == null || r.startsWith('${_gospel!} ')))
                        ActionChip(
                            label: Text(localizePassage(r, locale)),
                            avatar:
                                const Icon(Icons.menu_book_outlined, size: 16),
                            onPressed: () => _ref(r))
                    ]),
                  ])));
}

const kPassionReferenceImage = 'assets/images/passion-reference-clock.jpeg';
String passionHourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

class _PassionPainter extends CustomPainter {
  final String locale;
  final bool showDarkness;
  _PassionPainter(this.locale, {required this.showDarkness});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final w = size.width;
    final p = Paint()..color = const Color(0xff226176);
    canvas.drawCircle(center, w * .49, p);
    p.color = const Color(0xff263a68);
    canvas.drawCircle(center, w * .355, p);
    p.color = const Color(0xff193b51);
    canvas.drawCircle(center, w * .195, p);
    // The reference distinguishes evening meal / domestic activity
    // from night rest. These are source-diagram bands, not event dates.
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .12
      ..color = const Color(0xff66529a).withValues(alpha: .55);
    canvas.drawArc(Rect.fromCircle(center: center, radius: w * .285),
        passionClockAngle(18), math.pi, false, p);
    if (showDarkness) {
      p
        ..strokeWidth = w * .12
        ..color = Colors.black.withValues(alpha: .28);
      canvas.drawArc(Rect.fromCircle(center: center, radius: w * .405),
          -math.pi / 2, math.pi / 2, false, p);
    }
    p
      ..strokeWidth = 1
      ..color = Colors.white24;
    for (final ratio in [.405, .265, .195]) {
      canvas.drawCircle(center, w * ratio, p);
    }
    p
      ..strokeWidth = w * .018
      ..color = Colors.white.withValues(alpha: .10);
    canvas.drawLine(
        center - Offset(0, w * .12), center + Offset(0, w * .12), p);
    canvas.drawLine(center - Offset(w * .09, w * .05),
        center + Offset(w * .09, -w * .05), p);
    for (var hour = 0; hour < 24; hour++) {
      final rad = w * (passionClockDay(hour) ? .46 : .323);
      final a = passionClockAngle(hour);
      final label = hour == 0 ? '00' : hour.toString().padLeft(2, '0');
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  fontSize: math.min(14, w * .033),
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          textDirection: TextDirection.ltr)
        ..layout();
      final at = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PassionPainter old) =>
      locale != old.locale || showDarkness != old.showDarkness;
}

/// One smooth line through the diagram's events in the order they happened.
///
/// The dial folds 24 hours onto 12 angles, so a reader cannot tell the
/// Thursday evening scenes from the Friday morning ones except by the
/// ring they sit on. This line starts at 18:00 on the inner (night) ring,
/// goes once round the night, eases out to the day ring across 05:00–06:00
/// and carries on to the last event: a spiral, never crossing itself,
/// that passes through every marker because the markers sit on the same
/// two rings at the same angles.
class _OrderPathPainter extends CustomPainter {
  final List<int> hours;
  _OrderPathPainter(this.hours);

  /// Hours after the 18:00 start (the Thursday-evening meal falls in 18–24).
  static double since(int hour) => ((hour - 18) % 24).toDouble();

  static double _ring(double h) {
    // Night ring until 05:00, day ring 06:00–17:00, easing between.
    double ease(double x) => x * x * (3 - 2 * x);
    if (h >= 5 && h < 6) return .265 + (.405 - .265) * ease(h - 5);
    if (h >= 6 && h < 17) return .405;
    if (h >= 17 && h < 18) return .405 + (.265 - .405) * ease(h - 17);
    return .265;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.length < 2) return;
    final ts = hours.map(since).toList()..sort();
    final start = ts.first, end = ts.last;
    final center = size.center(Offset.zero);
    final w = size.width;
    Offset at(double u) {
      final h = (18 + u) % 24;
      final a = -math.pi / 2 + (h % 12) * math.pi / 6;
      final r = w * _ring(h);
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    }

    final path = Path()..moveTo(at(start).dx, at(start).dy);
    for (var u = start + .05; u <= end + 1e-9; u += .05) {
      final o = at(u);
      path.lineTo(o.dx, o.dy);
    }
    final under = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * .016
      ..color = Colors.black.withValues(alpha: .35);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * .009
      ..color = const Color(0xffff5a4d).withValues(alpha: .92);
    canvas.drawPath(path, under);
    canvas.drawPath(path, line);

    // Direction: a small arrowhead every three hours, and one at the end.
    final head = Paint()..color = const Color(0xffff5a4d);
    void arrow(double u) {
      final p = at(u), q = at(u - .08);
      final d = p - q;
      if (d.distance == 0) return;
      final dir = d / d.distance;
      final n = Offset(-dir.dy, dir.dx);
      final len = w * .026, half = w * .014;
      final tip = p + dir * (len * .5);
      final base = p - dir * (len * .5);
      canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(base.dx + n.dx * half, base.dy + n.dy * half)
            ..lineTo(base.dx - n.dx * half, base.dy - n.dy * half)
            ..close(),
          head);
    }

    for (var u = start + 1.5; u < end - .3; u += 3) {
      arrow(u);
    }
    arrow(end);
  }

  @override
  bool shouldRepaint(_OrderPathPainter old) =>
      old.hours.length != hours.length ||
      !old.hours.every(hours.contains);
}

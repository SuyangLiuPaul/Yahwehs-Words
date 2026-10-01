import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/learning_data.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart';

const kPassionWheelPath = '/passion-wheel';
const kPassionTitle = {
  'en': 'The road to the cross',
  'zh-Hans': '耶稣受难时间圆盘',
  'zh-Hant': '耶穌受難時間圓盤'
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
    setState(() => _selected = e.id);
  }

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
          title: Text(learningText(kPassionTitle, locale))),
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
            final selected =
                visible.where((e) => e.id == _selected).firstOrNull ??
                    visible.first;
            return LayoutBuilder(builder: (context, constraints) {
              final large = constraints.maxWidth >= 900;
              final wheel = _wheel(visible, selected, locale, colors);
              final detail = _detail(selected, locale, colors);
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
                        'A Scripture study guide. Only stated hours get clock markers; other scenes retain their stated period. Event order is editorial: read each Gospel alongside the others.',
                        '经文研读导览：仅为经文明说的时辰标点；其余场景保留原有时段。列表顺序是编辑导读，请并列阅读各福音。',
                        '經文研讀導覽：僅為經文明說的時辰標點；其餘場景保留原有時段。列表順序是編輯導讀，請並列閱讀各福音。')),
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
                                : localizePassage(g, locale)),
                            selected: _gospel == g,
                            onSelected: (_) => setState(() => _gospel = g))
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
                                  e.hourFor(_gospel) == null
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
    final marks = visible.where((e) => e.hourFor(_gospel) != null).toList();
    return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              LayoutBuilder(builder: (context, c) {
                final side = math.min(c.maxWidth, 480.0);
                return SizedBox(
                    width: side,
                    height: side,
                    child: Stack(children: [
                      Positioned.fill(
                          child: CustomPaint(
                              painter: _PassionPainter(colors, locale,
                                  showDarkness:
                                      marks.any((e) => e.id == 'darkness')))),
                      Positioned.fill(
                          child: Center(
                              child: SizedBox(
                                  width: side * .34,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.menu_book_outlined,
                                            color: colors.primary, size: 32),
                                        const SizedBox(height: 6),
                                        Text(
                                            _l(locale, 'Gospel hours', '福音时辰',
                                                '福音時辰'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ])))),
                      for (final e in marks)
                        _marker(e, side, colors, locale, e.id == selected.id),
                    ]));
              }),
              const SizedBox(height: 8),
              Text(
                  _l(
                      locale,
                      'Outer ring: day · inner ring: night\nModern hours are approximate conversions.',
                      '外圈：白昼 · 内圈：夜晚\n现代钟点为大致换算。',
                      '外圈：白晝 · 內圈：夜晚\n現代鐘點為大致換算。'),
                  textAlign: TextAlign.center),
              if (selected.hourFor(_gospel) == null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        _l(
                            locale,
                            'This scene has no clock marker in the selected account.',
                            '所选记载没有为此场景提供钟点标记。',
                            '所選記載沒有為此場景提供鐘點標記。'),
                        style: TextStyle(color: colors.onSurfaceVariant))),
            ])));
  }

  Widget _marker(PassionEvent e, double side, ColorScheme colors, String locale,
      bool selected) {
    final hour = e.hourFor(_gospel)!;
    final radius = side * (passionClockDay(hour) ? .405 : .265);
    final angle = passionClockAngle(hour);
    final center = Offset(side / 2 + math.cos(angle) * radius,
        side / 2 + math.sin(angle) * radius);
    return Positioned(
        left: center.dx - 24,
        top: center.dy - 24,
        width: 48,
        height: 48,
        child: Semantics(
            button: true,
            onTap: () => _select(e),
            excludeSemantics: true,
            selected: selected,
            label:
                '${learningText(e.title, locale)} · ${learningText(e.period, locale)}',
            child: Tooltip(
                message: learningText(e.title, locale),
                child: IconButton(
                    key: ValueKey('passion.marker.${e.id}'),
                    onPressed: () => _select(e),
                    icon: Icon(
                        selected ? Icons.radio_button_checked : Icons.circle,
                        size: selected ? 26 : 18,
                        color: colors.primary),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent)))));
  }

  Widget _detail(PassionEvent e, String locale, ColorScheme colors) => Card(
      color: colors.primaryContainer.withValues(alpha: .35),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(learningText(e.title, locale),
                key: const ValueKey('passion.selected.title'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(learningText(e.period, locale),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(learningText(e.place, locale)),
            const Divider(height: 28),
            Text(learningText(e.summary, locale)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in e.refsFor(_gospel))
                ActionChip(
                    label: Text(localizePassage(r, locale)),
                    avatar: const Icon(Icons.menu_book_outlined, size: 16),
                    onPressed: () => _ref(r))
            ]),
          ])));
}

class _PassionPainter extends CustomPainter {
  final ColorScheme colors;
  final String locale;
  final bool showDarkness;
  _PassionPainter(this.colors, this.locale, {required this.showDarkness});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width * .405;
    final p = Paint()..color = colors.primaryContainer;
    canvas.drawCircle(center, r + size.width * .075, p);
    p.color = colors.secondaryContainer;
    canvas.drawCircle(center, size.width * .33, p);
    p.color = colors.surface;
    canvas.drawCircle(center, size.width * .19, p);
    if (showDarkness) {
      p
        ..color = colors.onSurface.withValues(alpha: .20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .11;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2,
          math.pi / 2, false, p);
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.outlineVariant;
    for (final ratio in [.405, .265, .19]) {
      canvas.drawCircle(center, size.width * ratio, p);
    }
    for (final hour in [0, 3, 6, 9, 12, 15, 18, 21]) {
      final day = passionClockDay(hour);
      final rad = size.width * (day ? .465 : .325);
      final a = passionClockAngle(hour);
      final label = hour == 0 ? '00' : hour.toString().padLeft(2, '0');
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
          textDirection: TextDirection.ltr)
        ..layout();
      final at = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PassionPainter old) =>
      colors != old.colors ||
      locale != old.locale ||
      showDarkness != old.showDarkness;
}

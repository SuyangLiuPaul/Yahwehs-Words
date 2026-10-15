import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/jump_to_reference.dart' as jumper;
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';

const kReadingPlanPath = '/reading-plan';

/// Open the reader on the first chapter of [s] (or its first verse).
Future<void> openReadingSegment(
    BuildContext context, ReadingSegment s) async {
  final mp = context.read<MainProvider>();
  final ref = BibleReference(
    englishBook: s.book,
    chapter: s.from,
    verseStart: s.fromVerse,
    verseEnd: s.fromVerse,
  );
  final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
  if (!context.mounted) return;
  final ok = await jumper.showJumpResultSnackBar(context, result);
  if (!ok || !context.mounted) return;
  pushPage(const HomePage(), routeName: '/HomePage');
}

class ReadingPlanPage extends StatefulWidget {
  const ReadingPlanPage({super.key, this.service});

  /// Test hook.
  final ReadingPlanService? service;

  @override
  State<ReadingPlanPage> createState() => _ReadingPlanPageState();
}

class _ReadingPlanPageState extends State<ReadingPlanPage> {
  ReadingPlanService get _svc => widget.service ?? ReadingPlanService.instance;
  late Future<List<ReadingPlan>> _plans;

  @override
  void initState() {
    super.initState();
    _plans = _svc.plans();
    if (!_svc.progressLoaded) _svc.reload();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        actions: const [LanguageSwitcherButton(alwaysVisible: true)],
        title: Text(rpText('readingPlan_title', locale)),
      ),
      body: FutureBuilder<List<ReadingPlan>>(
        future: _plans,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: FilledButton(
                    onPressed: () => setState(() => _plans = _svc.plans()),
                    child: Text(rpText('readingPlan_confirm', locale))));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return AnimatedBuilder(
            animation: _svc,
            builder: (context, _) =>
                _body(context, locale, snap.data!, _svc.progress),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, String locale, List<ReadingPlan> plans,
      ReadingPlanProgress? progress) {
    final active = progress == null
        ? null
        : plans.where((p) => p.id == progress.planId).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        if (active != null) ..._activeSection(context, locale, active, progress!),
        if (active == null) ...[
          Text(rpText('readingPlan_pickTitle', locale),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(rpText('readingPlan_pickHint', locale)),
          const SizedBox(height: 12),
        ] else ...[
          const SizedBox(height: 20),
          Text(rpText('readingPlan_other', locale),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        for (final p in plans)
          if (active == null || p.id != active.id)
            _PlanCard(
              plan: p,
              locale: locale,
              onStart: () => _confirmStart(context, locale, p, active != null),
            ),
        const SizedBox(height: 16),
        Text(rpText('readingPlan_source', locale),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Future<void> _confirmStart(BuildContext context, String locale,
      ReadingPlan plan, bool replacing) async {
    if (replacing) {
      final ok = await _ask(context, locale, 'readingPlan_replaceConfirm');
      if (ok != true) return;
    }
    await _svc.start(plan.id);
  }

  Future<bool?> _ask(BuildContext context, String locale, String key) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(rpText(key, locale)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(rpText('readingPlan_cancel', locale))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(rpText('readingPlan_confirm', locale))),
        ],
      ),
    );
  }

  List<Widget> _activeSection(BuildContext context, String locale,
      ReadingPlan plan, ReadingPlanProgress progress) {
    final st = readingPlanStatus(progress, plan.days, _svc.now);
    final theme = Theme.of(context);
    final today = st.today;
    final isDone = progress.done.contains(today);
    String two(int n) => n.toString().padLeft(2, '0');
    final s = progress.start;
    return [
      Text(rpText('readingPlan_${plan.id}_name', locale),
          style: theme.textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(rpText('readingPlan_doneCount', locale,
          {'done': st.doneCount, 'days': plan.days})),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: plan.days == 0 ? 0 : st.doneCount / plan.days),
      const SizedBox(height: 16),
      if (st.finished)
        _Note(text: rpText('readingPlan_finished', locale))
      else if (st.notStarted)
        _Note(
            text: rpText('readingPlan_notStarted', locale,
                {'date': '${s.year}-${two(s.month)}-${two(s.day)}'}))
      else if (st.calendarEnded)
        _Note(
            text: rpText('readingPlan_calendarEnded', locale,
                {'n': plan.days - st.doneCount})),
      if (!st.finished && st.unreadBefore > 0 && !st.notStarted)
        _Note(
            text: rpText('readingPlan_behind', locale,
                {'n': st.unreadBefore, 'day': st.resumeDay ?? today})),
      const SizedBox(height: 8),
      _DayCard(
        key: const ValueKey('plan.today'),
        title: '${rpText('readingPlan_today', locale)} · '
            '${rpText('readingPlan_dayOf', locale, {'day': today, 'days': plan.days})}',
        segments: plan.day(today),
        locale: locale,
        done: isDone,
        onOpen: (seg) => openReadingSegment(context, seg),
        onToggle: (v) => _svc.setDone(today, v),
      ),
      if (st.resumeDay != null && st.resumeDay != today && !st.notStarted) ...[
        const SizedBox(height: 8),
        _DayCard(
          key: const ValueKey('plan.resume'),
          title: rpText('readingPlan_dayOf', locale,
              {'day': st.resumeDay!, 'days': plan.days}),
          segments: plan.day(st.resumeDay!),
          locale: locale,
          done: progress.done.contains(st.resumeDay!),
          onOpen: (seg) => openReadingSegment(context, seg),
          onToggle: (v) => _svc.setDone(st.resumeDay!, v),
        ),
      ],
      const SizedBox(height: 12),
      ExpansionTile(
        key: const ValueKey('plan.allDays'),
        tilePadding: EdgeInsets.zero,
        title: Text(rpText('readingPlan_allDays', locale)),
        children: [
          for (var d = 1; d <= plan.days; d++)
            CheckboxListTile(
              key: ValueKey('plan.day.$d'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: progress.done.contains(d),
              onChanged: (v) => _svc.setDone(d, v ?? false),
              title: Text(rpText('readingPlan_dayOf', locale,
                  {'day': d, 'days': plan.days})),
              subtitle: Text(plan
                  .day(d)
                  .map((x) => readingSegmentLabel(x, locale))
                  .join(' · ')),
            ),
        ],
      ),
      TextButton.icon(
        key: const ValueKey('plan.stop'),
        icon: const Icon(Icons.stop_circle_outlined),
        label: Text(rpText('readingPlan_stop', locale)),
        onPressed: () async {
          if (await _ask(context, locale, 'readingPlan_stopConfirm') == true) {
            await _svc.stop();
          }
        },
      ),
    ];
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.primary)),
      );
}

class _PlanCard extends StatelessWidget {
  final ReadingPlan plan;
  final String locale;
  final VoidCallback onStart;
  const _PlanCard(
      {required this.plan, required this.locale, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('plan.card.${plan.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rpText('readingPlan_${plan.id}_name', locale),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(rpText('readingPlan_daysCount', locale, {'days': plan.days}),
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(rpText('readingPlan_${plan.id}_desc', locale)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: ValueKey('plan.start.${plan.id}'),
                onPressed: onStart,
                child: Text(rpText('readingPlan_startToday', locale)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String title;
  final List<ReadingSegment> segments;
  final String locale;
  final bool done;
  final void Function(ReadingSegment) onOpen;
  final void Function(bool) onToggle;
  const _DayCard({
    super.key,
    required this.title,
    required this.segments,
    required this.locale,
    required this.done,
    required this.onOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in segments)
                ActionChip(
                  label: Text(readingSegmentLabel(s, locale)),
                  onPressed: () => onOpen(s),
                ),
            ]),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: Icon(done ? Icons.check_circle : Icons.circle_outlined),
              label: Text(rpText(
                  done ? 'readingPlan_marked' : 'readingPlan_markDone',
                  locale)),
              onPressed: () => onToggle(!done),
            ),
          ],
        ),
      ),
    );
  }
}

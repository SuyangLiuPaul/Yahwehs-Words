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
import 'package:yahwehs_words/widgets/reading_plan_sheets.dart';

const kReadingPlanPath = '/reading-plan';

/// Open the reader on the first chapter of [s] (or its first verse).
///
/// [day] and [daySegments] make the reader a [ReadingSession]: limited to
/// that day's chapters, with a back arrow to the plan and a progress bar.
Future<void> openReadingSegment(BuildContext context, ReadingSegment s,
    {String? entryId, int? day, List<ReadingSegment>? daySegments}) async {
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
  final session = (day == null || entryId == null)
      ? null
      : ReadingSession.forDay(entryId, day, daySegments ?? [s]);
  pushPage(HomePage(session: session), routeName: '/HomePage');
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
            builder: (context, _) => _body(context, locale, snap.data!),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, String locale, List<ReadingPlan> plans) {
    final entries = _svc.entries;
    final byId = {for (final p in plans) p.id: p};
    // Plans that are running (not yet finished) are not offered again.
    final running = <String>{
      for (final e in entries)
        if (byId[e.planId] != null &&
            !readingPlanStatus(e, byId[e.planId]!.days, _svc.now).finished)
          e.planId,
    };
    final full = entries.length >= kMaxReadingPlans;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        if (entries.isEmpty) ...[
          Text(rpText('readingPlan_pickTitle', locale),
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(rpText('readingPlan_pickHint', locale)),
          const SizedBox(height: 12),
        ] else ...[
          Text(rpText('readingPlan_myPlans', locale),
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final e in entries)
            if (byId[e.planId] != null)
              _EntryCard(
                key: ValueKey('plan.entry.${e.id}'),
                entry: e,
                plan: byId[e.planId]!,
                locale: locale,
                svc: _svc,
              ),
          const SizedBox(height: 12),
          Text(rpText('readingPlan_addPlan', locale),
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(rpText('readingPlan_addHint', locale),
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        if (full)
          _Note(
              text: rpText('readingPlan_limitReached', locale,
                  {'n': kMaxReadingPlans})),
        for (final p in plans)
          if (!running.contains(p.id))
            _PlanCard(
              plan: p,
              locale: locale,
              enabled: !full,
              onStart: () => showStartPlanSheet(context, p, locale),
            ),
        const SizedBox(height: 16),
        Text(rpText('readingPlan_source', locale),
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// One running plan: where it stands, today's passages, every day, and a
/// button to its settings.
class _EntryCard extends StatelessWidget {
  final ReadingPlanProgress entry;
  final ReadingPlan plan;
  final String locale;
  final ReadingPlanService svc;
  const _EntryCard({
    super.key,
    required this.entry,
    required this.plan,
    required this.locale,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = readingPlanStatus(entry, plan.days, svc.now);
    final today = st.today;
    final isDone = entry.done.contains(today);
    final id = entry.id;
    String two(int n) => n.toString().padLeft(2, '0');
    final s = entry.start;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(rpText('readingPlan_${plan.id}_name', locale),
                    style: theme.textTheme.titleMedium),
              ),
              IconButton(
                key: ValueKey('plan.manage.$id'),
                tooltip: rpText('readingPlan_manage', locale),
                icon: const Icon(Icons.tune),
                onPressed: () => showManagePlanSheet(context, id, plan),
              ),
            ]),
            Text(
              [
                rpText('readingPlan_doneCount', locale,
                    {'done': st.doneCount, 'days': plan.days}),
                if (st.skippedCount > 0)
                  rpText('readingPlan_skippedCount', locale,
                      {'n': st.skippedCount}),
                if (st.paused) rpText('readingPlan_paused', locale),
              ].join(' · '),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: plan.days == 0 ? 0 : st.doneCount / plan.days),
            const SizedBox(height: 12),
            if (st.finished)
              _Note(text: rpText('readingPlan_finished', locale))
            else if (st.notStarted)
              _Note(
                  text: rpText('readingPlan_notStarted', locale,
                      {'date': '${s.year}-${two(s.month)}-${two(s.day)}'}))
            else if (st.calendarEnded)
              _Note(
                  text: rpText('readingPlan_calendarEnded', locale,
                      {'n': plan.days - st.doneCount - st.skippedCount})),
            if (!st.finished && st.unreadBefore > 0 && !st.notStarted)
              _Note(
                  text: rpText('readingPlan_behind', locale,
                      {'n': st.unreadBefore, 'day': st.resumeDay ?? today})),
            if (!st.finished) ...[
              const SizedBox(height: 4),
              _DayCard(
                key: ValueKey('plan.today.$id'),
                title: '${rpText('readingPlan_today', locale)} · '
                    '${rpText('readingPlan_dayOf', locale, {'day': today, 'days': plan.days})}',
                segments: plan.day(today),
                locale: locale,
                done: isDone,
                onOpen: (seg) => openReadingSegment(context, seg,
                    entryId: id, day: today, daySegments: plan.day(today)),
                onToggle: (v) => svc.setDone(id, today, v),
              ),
              if (st.resumeDay != null &&
                  st.resumeDay != today &&
                  !st.notStarted) ...[
                const SizedBox(height: 8),
                _DayCard(
                  key: ValueKey('plan.resume.$id'),
                  title: rpText('readingPlan_dayOf', locale,
                      {'day': st.resumeDay!, 'days': plan.days}),
                  segments: plan.day(st.resumeDay!),
                  locale: locale,
                  done: entry.done.contains(st.resumeDay!),
                  onOpen: (seg) => openReadingSegment(context, seg,
                      entryId: id,
                      day: st.resumeDay!,
                      daySegments: plan.day(st.resumeDay!)),
                  onToggle: (v) => svc.setDone(id, st.resumeDay!, v),
                ),
              ],
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              key: ValueKey('plan.allDays.$id'),
              tilePadding: EdgeInsets.zero,
              title: Text(rpText('readingPlan_allDays', locale)),
              children: [
                for (var d = 1; d <= plan.days; d++)
                  CheckboxListTile(
                    key: ValueKey('plan.day.$id.$d'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: entry.done.contains(d),
                    onChanged: (v) => svc.setDone(id, d, v ?? false),
                    title: Text(rpText('readingPlan_dayOf', locale,
                        {'day': d, 'days': plan.days})),
                    subtitle: Text(plan
                        .day(d)
                        .map((x) => readingSegmentLabel(x, locale))
                        .join(' · ')),
                    secondary: IconButton(
                      key: ValueKey('plan.openDay.$id.$d'),
                      tooltip: rpText('readingPlan_openDay', locale),
                      icon: const Icon(Icons.menu_book_outlined),
                      onPressed: plan.day(d).isEmpty
                          ? null
                          : () => openReadingSegment(context, plan.day(d).first,
                              entryId: id, day: d, daySegments: plan.day(d)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
  final bool enabled;
  final VoidCallback onStart;
  const _PlanCard(
      {required this.plan,
      required this.locale,
      required this.onStart,
      this.enabled = true});

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
                onPressed: enabled ? onStart : null,
                child: Text(rpText('readingPlan_startButton', locale)),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/home_page.dart';
import 'package:yahwehs_words/pages/reading_plan_schedule_page.dart';
import 'package:yahwehs_words/providers/main_provider.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/jump_to_reference.dart' as jumper;
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/reading_plan_sheets.dart';
import 'package:yahwehs_words/widgets/reading_plan_widgets.dart';

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
    final entries = _svc.entries
        .where((e) => _svc.planFor(e) != null)
        .toList();
    // Plans that are running (not yet finished) are not offered again.
    final running = <String>{
      for (final e in entries)
        if (e.custom == null &&
            !readingPlanStatus(e, _svc.planFor(e)!.days, _svc.now).finished)
          e.planId,
    };
    final full = _svc.entries.length >= kMaxReadingPlans;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
          children: [
            if (entries.isEmpty)
              _Welcome(locale: locale)
            else ...[
              _TodayHero(entries: entries, svc: _svc, locale: locale),
              const SizedBox(height: 22),
              _SectionHeading(
                  text: rpText('readingPlan_myPlans', locale),
                  trailing: entries.length > 1
                      ? rpText('readingPlan_plansCount', locale,
                          {'n': entries.length})
                      : null),
              const SizedBox(height: 10),
              for (final e in entries)
                _EntryCard(
                  key: ValueKey('plan.entry.${e.id}'),
                  entry: e,
                  plan: _svc.planFor(e)!,
                  locale: locale,
                  svc: _svc,
                ),
            ],
            const SizedBox(height: 14),
            _SectionHeading(
                text: entries.isEmpty
                    ? rpText('readingPlan_pickTitle', locale)
                    : rpText('readingPlan_addPlan', locale)),
            const SizedBox(height: 4),
            Text(
                entries.isEmpty
                    ? rpText('readingPlan_pickHint', locale)
                    : rpText('readingPlan_addHint', locale),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (full)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PlanPill(
                  icon: Icons.info_outline,
                  label: rpText('readingPlan_limitReached', locale,
                      {'n': kMaxReadingPlans}),
                ),
              ),
            for (final p in plans)
              if (!running.contains(p.id))
                _AvailablePlan(
                  plan: p,
                  locale: locale,
                  enabled: !full,
                  onStart: () => showStartPlanSheet(context, p, locale),
                ),
            _CustomPlanTile(
              locale: locale,
              enabled: !full,
              onStart: () => showStartPlanSheet(context, null, locale),
            ),
            const SizedBox(height: 18),
            Text(rpText('readingPlan_source', locale),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionHeading({required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(text,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (trailing != null)
          Text(trailing!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Nothing started yet: say what this is for, warmly, before the list.
class _Welcome extends StatelessWidget {
  final String locale;
  const _Welcome({required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.28), scheme.primary),
          ],
        ),
      ),
      child: Row(children: [
        Icon(Icons.event_available_outlined,
            size: 44, color: scheme.onPrimary.withValues(alpha: 0.95)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(rpText('readingPlan_welcomeTitle', locale),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimary, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// The top of the page: how today looks across every plan, the streak,
/// and one button that goes straight to the next thing to read.
class _TodayHero extends StatelessWidget {
  final List<ReadingPlanProgress> entries;
  final ReadingPlanService svc;
  final String locale;
  const _TodayHero(
      {required this.entries, required this.svc, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final now = svc.now;
    // Today's work: each plan that has something due today.
    var total = 0;
    var done = 0;
    ({ReadingPlanProgress e, ReadingPlan plan, int day, ReadingSegment seg})? next;
    for (final e in entries) {
      final plan = svc.planFor(e)!;
      final st = readingPlanStatus(e, plan.days, now);
      if (st.finished || st.paused || st.notStarted || st.restDay) continue;
      total++;
      if (e.done.contains(st.today)) {
        done++;
      } else if (next == null) {
        final seg = firstUnreadSegment(e, st.today, plan.day(st.today));
        if (seg != null) next = (e: e, plan: plan, day: st.today, seg: seg);
      }
    }
    final streak = readingStreak(entries, now);
    final allDone = total > 0 && done == total;
    final on = scheme.onPrimary;
    final weekday = rpText('readingPlan_wd${now.weekday}', locale);
    return Container(
      key: const ValueKey('plan.hero'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.28), scheme.primary),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: scheme.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                  '${formatPlanDate(now)} · $weekday',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: on.withValues(alpha: 0.85))),
            ),
            if (streak.current > 0)
              Container(
                key: const ValueKey('plan.streak'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: on.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    '🔥 ${rpText('readingPlan_streak', locale, {'n': streak.current})}',
                    style: TextStyle(
                        color: on, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? rpText('readingPlan_restDayNote', locale)
                : allDone
                    ? rpText('readingPlan_dayCompleted', locale)
                    : rpText('readingPlan_heroToRead', locale,
                        {'n': total - done}),
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: on, fontWeight: FontWeight.w800),
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 8,
                color: on,
                backgroundColor: on.withValues(alpha: 0.22),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 2, children: [
            if (total > 0)
              Text(
                  rpText('readingPlan_heroProgress', locale,
                      {'done': done, 'total': total}),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: on, fontWeight: FontWeight.w700)),
            if (streak.totalDays > 0) ...[
              Text(
                  rpText('readingPlan_streakBest', locale,
                      {'n': streak.longest}),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: on.withValues(alpha: 0.85))),
              Text(
                  rpText('readingPlan_daysRead', locale,
                      {'n': streak.totalDays}),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: on.withValues(alpha: 0.85))),
            ],
          ]),
          if (next != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('plan.hero.read'),
              style: FilledButton.styleFrom(
                backgroundColor: on,
                foregroundColor: scheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(
                '${rpText((next.e.readChapters[next.day]?.isNotEmpty ?? false) ? 'readingPlan_continueReading' : 'readingPlan_readNow', locale)}'
                ' · ${readingSegmentLabel(next.seg, locale)}',
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => openReadingSegment(context, next!.seg,
                  entryId: next.e.id,
                  day: next.day,
                  daySegments: next.plan.day(next.day)),
            ),
          ],
        ],
      ),
    );
  }
}

/// One running plan.
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
    final scheme = theme.colorScheme;
    final st = readingPlanStatus(entry, plan.days, svc.now);
    final id = entry.id;
    final pct = plan.days == 0 ? 0.0 : st.doneCount / plan.days;
    final catchUpDay = st.resumeDay;
    final behind = !st.finished && !st.notStarted && st.unreadBefore > 0;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              PlanRing(
                value: pct,
                size: 58,
                child: Text('${(pct * 100).floor()}%',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(readingPlanName(plan, locale),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      st.finished
                          ? rpText('readingPlan_completed', locale)
                          : rpText('readingPlan_dayOf', locale,
                              {'day': st.today, 'days': plan.days}),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                    if (!st.finished && plan.days > 0)
                      Text(
                          rpText('readingPlan_endsOn', locale, {
                            'date': formatPlanDate(entry.dateOfDay(plan.days)),
                          }),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('plan.manage.$id'),
                tooltip: rpText('readingPlan_manage', locale),
                icon: const Icon(Icons.tune),
                onPressed: () => showManagePlanSheet(context, id, plan),
              ),
            ]),
            if (behind ||
                st.paused ||
                st.notStarted ||
                st.restDay ||
                entry.remind ||
                st.skippedCount > 0) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  if (behind)
                    PlanPill(
                      key: const ValueKey('plan.behind'),
                      icon: Icons.schedule,
                      label: rpText('readingPlan_behindChip', locale,
                          {'n': st.unreadBefore}),
                      background: scheme.errorContainer,
                      foreground: scheme.onErrorContainer,
                      onTap: () => showManagePlanSheet(context, id, plan),
                    ),
                  if (st.paused)
                    PlanPill(
                        icon: Icons.pause_circle_outline,
                        label: rpText('readingPlan_paused', locale)),
                  if (st.notStarted)
                    PlanPill(
                        icon: Icons.event,
                        label: rpText('readingPlan_notStarted', locale, {
                          'date': formatPlanDate(entry.dateOfDay(1)),
                        })),
                  if (st.restDay)
                    PlanPill(
                        icon: Icons.free_breakfast_outlined,
                        label: rpText('readingPlan_restDayNote', locale)),
                  if (st.skippedCount > 0)
                    PlanPill(
                        icon: Icons.skip_next_outlined,
                        label: rpText('readingPlan_skippedCount', locale,
                            {'n': st.skippedCount})),
                  if (entry.remind)
                    PlanPill(
                        icon: Icons.notifications_active_outlined,
                        label: entry.hour != null
                            ? formatPlanTime(entry.hour!, entry.minute ?? 0)
                            : rpText('readingPlan_remindOn', locale)),
                ]),
              ),
            ],
            if (st.finished)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: _Note(text: rpText('readingPlan_finished', locale)),
              )
            else if (st.calendarEnded)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: _Note(
                    text: rpText('readingPlan_calendarEnded', locale, {
                  'n': plan.days - st.doneCount - st.skippedCount
                })),
              ),
            if (!st.finished && !st.notStarted) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DayPanel(
                  key: ValueKey('plan.today.$id'),
                  entry: entry,
                  plan: plan,
                  day: st.today,
                  label: rpText('readingPlan_todayLabel', locale),
                  locale: locale,
                  svc: svc,
                  highlight: true,
                ),
              ),
              if (catchUpDay != null && catchUpDay != st.today) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _DayPanel(
                    key: ValueKey('plan.resume.$id'),
                    entry: entry,
                    plan: plan,
                    day: catchUpDay,
                    label: rpText('readingPlan_catchUpDay', locale),
                    locale: locale,
                    svc: svc,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('plan.allDays.$id'),
                icon: const Icon(Icons.calendar_view_day_outlined, size: 18),
                label: Text(rpText('readingPlan_fullSchedule', locale)),
                onPressed: () => pushPage(
                    ReadingPlanSchedulePage(entryId: id, service: svc),
                    routeName: '/reading-plan/schedule'),
              ),
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
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary));
}

/// One day's reading inside a plan card: the passages (checked off as
/// they are read), a button that opens them, and the manual tick.
class _DayPanel extends StatelessWidget {
  final ReadingPlanProgress entry;
  final ReadingPlan plan;
  final int day;
  final String label;
  final String locale;
  final ReadingPlanService svc;
  final bool highlight;
  const _DayPanel({
    super.key,
    required this.entry,
    required this.plan,
    required this.day,
    required this.label,
    required this.locale,
    required this.svc,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final segs = plan.day(day);
    final isDone = entry.done.contains(day);
    final pages = ReadingSession.forDay(entry.id, day, segs).pages.length;
    final read = isDone ? pages : (entry.readChapters[day]?.length ?? 0);
    final next = isDone ? null : firstUnreadSegment(entry, day, segs);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '$label · ${rpText('readingPlan_dayShort', locale, {'day': day})}'
                ' · ${formatPlanDate(entry.dateOfDay(day))}',
                style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highlight ? scheme.primary : scheme.onSurfaceVariant),
              ),
            ),
            if (isDone) Icon(Icons.check_circle, color: scheme.primary, size: 20),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in segs)
              PassageChip(
                label: readingSegmentLabel(s, locale),
                read: readingSegmentRead(entry, day, s),
                onTap: () => openReadingSegment(context, s,
                    entryId: entry.id, day: day, daySegments: segs),
              ),
          ]),
          if (!isDone && read > 0 && pages > 1) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: read / pages, minHeight: 5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                  rpText('readingPlan_chaptersReadShort', locale,
                      {'n': read, 'total': pages}),
                  style: theme.textTheme.bodySmall),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            if (next != null)
              Expanded(
                child: (highlight ? FilledButton.icon : FilledButton.tonalIcon)(
                  key: ValueKey('plan.read.${entry.id}.$day'),
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(
                      rpText(
                          read > 0
                              ? 'readingPlan_continueReading'
                              : (highlight
                                  ? 'readingPlan_readNow'
                                  : 'readingPlan_catchUpDay'),
                          locale),
                      overflow: TextOverflow.ellipsis),
                  onPressed: () => openReadingSegment(context, next,
                      entryId: entry.id, day: day, daySegments: segs),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 8),
            TextButton.icon(
              key: ValueKey('plan.mark.${entry.id}.$day'),
              icon: Icon(
                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18),
              label: Text(rpText(
                  isDone ? 'readingPlan_marked' : 'readingPlan_markDone',
                  locale)),
              onPressed: () => svc.setDone(entry.id, day, !isDone),
            ),
          ]),
        ],
      ),
    );
  }
}

/// A plan the reader could start: a picture, what it is, how long.
class _AvailablePlan extends StatelessWidget {
  final ReadingPlan plan;
  final String locale;
  final bool enabled;
  final VoidCallback onStart;
  const _AvailablePlan({
    required this.plan,
    required this.locale,
    required this.onStart,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: ValueKey('plan.card.${plan.id}'),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onStart : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(readingPlanIcon(plan.id),
                  color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rpText('readingPlan_${plan.id}_name', locale),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (!rpText('readingPlan_${plan.id}_name', locale)
                      .contains('${plan.days}')) ...[
                    const SizedBox(height: 2),
                    Text(
                        rpText('readingPlan_daysCount', locale,
                            {'days': plan.days}),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: scheme.primary)),
                  ],
                  const SizedBox(height: 6),
                  Text(rpText('readingPlan_${plan.id}_desc', locale),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: ValueKey('plan.start.${plan.id}'),
              onPressed: enabled ? onStart : null,
              child: Text(rpText('readingPlan_startButton', locale)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CustomPlanTile extends StatelessWidget {
  final String locale;
  final bool enabled;
  final VoidCallback onStart;
  const _CustomPlanTile(
      {required this.locale, required this.enabled, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: const ValueKey('plan.card.custom'),
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onStart : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.add, color: scheme.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rpText('readingPlan_customTitle', locale),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(rpText('readingPlan_customDesc', locale),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('plan.start.custom'),
              onPressed: enabled ? onStart : null,
              child: Text(rpText('readingPlan_startButton', locale)),
            ),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/reading_plan_page.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/reading_plan_sheets.dart';
import 'package:yahwehs_words/widgets/reading_plan_widgets.dart';

/// Every day of one plan: its date, its passages, whether it is read.
/// Opens scrolled to today. Tick a day by hand with the box; tap the day
/// to open its reading (so a missed day can be made up).
class ReadingPlanSchedulePage extends StatefulWidget {
  final String entryId;
  final ReadingPlanService? service;
  const ReadingPlanSchedulePage({super.key, required this.entryId, this.service});

  @override
  State<ReadingPlanSchedulePage> createState() => _ReadingPlanSchedulePageState();
}

class _ReadingPlanSchedulePageState extends State<ReadingPlanSchedulePage> {
  static const double _rowHeight = 76;
  ReadingPlanService get _svc => widget.service ?? ReadingPlanService.instance;
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return AnimatedBuilder(
      animation: _svc,
      builder: (context, _) {
        final e = _svc.entry(widget.entryId);
        final plan = e == null ? null : _svc.planFor(e);
        if (e == null || plan == null) {
          return Scaffold(
            appBar: AppBar(leading: const LocalizedBackButton()),
            body: const SizedBox.shrink(),
          );
        }
        final st = readingPlanStatus(e, plan.days, _svc.now);
        _scroll ??= ScrollController(
            initialScrollOffset: ((st.today - 3).clamp(0, plan.days)) * _rowHeight);
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(readingPlanName(plan, locale)),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(rpText('readingPlan_scheduleHint', locale),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemExtent: _rowHeight,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                itemCount: plan.days,
                itemBuilder: (context, i) {
                  final d = i + 1;
                  return _DayRow(
                    entry: e,
                    plan: plan,
                    day: d,
                    today: st.today,
                    locale: locale,
                    svc: _svc,
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final ReadingPlanProgress entry;
  final ReadingPlan plan;
  final int day;
  final int today;
  final String locale;
  final ReadingPlanService svc;
  const _DayRow({
    required this.entry,
    required this.plan,
    required this.day,
    required this.today,
    required this.locale,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = entry.done.contains(day);
    final skipped = entry.skipped.contains(day);
    final isToday = day == today;
    final behind = day < today && !done && !skipped;
    final segs = plan.day(day);
    final read = !done && (entry.readChapters[day]?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isToday
            ? scheme.primaryContainer.withValues(alpha: 0.6)
            : (done ? Colors.transparent : scheme.surfaceContainerLow),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: segs.isEmpty
              ? null
              : () => openReadingSegment(context, segs.first,
                  entryId: entry.id, day: day, daySegments: segs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              Checkbox(
                key: ValueKey('plan.day.${entry.id}.$day'),
                shape: const CircleBorder(),
                value: done,
                onChanged: (v) => svc.setDone(entry.id, day, v ?? false),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                          '${rpText('readingPlan_dayShort', locale, {'day': day})}'
                          ' · ${formatPlanDate(entry.dateOfDay(day))}',
                          style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface)),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        PlanPill(
                            label: rpText('readingPlan_todayLabel', locale),
                            background: scheme.primary,
                            foreground: scheme.onPrimary),
                      ] else if (behind) ...[
                        const SizedBox(width: 8),
                        PlanPill(
                            label: rpText('readingPlan_catchUpDay', locale),
                            background: scheme.errorContainer,
                            foreground: scheme.onErrorContainer),
                      ] else if (skipped) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.skip_next_outlined,
                            size: 16, color: scheme.onSurfaceVariant),
                      ] else if (read) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.timelapse, size: 16, color: scheme.primary),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        segs
                            .map((x) => readingSegmentLabel(x, locale))
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('plan.openDay.${entry.id}.$day'),
                tooltip: rpText('readingPlan_openDay', locale),
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: segs.isEmpty
                    ? null
                    : () => openReadingSegment(context, segs.first,
                        entryId: entry.id, day: day, daySegments: segs),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

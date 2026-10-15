import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/models/notification_category.dart';
import 'package:yahwehs_words/pages/settings_page.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/version_mapper.dart' show localeAwareBookName;

/// 2026-10-16: the two sheets behind a running reading plan — one to
/// start it (when, and how to be reminded) and one to manage it later
/// (move the start date, change the reminder, pause, catch up, remove).

String _two(int n) => n.toString().padLeft(2, '0');

String formatPlanDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String formatPlanTime(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

/// What a reader has asked for in the reminder section.
@immutable
class ReminderDraft {
  final bool remind;

  /// Null = the Reading plan category's own time.
  final int? hour;
  final int? minute;
  final String message;
  const ReminderDraft(
      {this.remind = false, this.hour, this.minute, this.message = ''});

  ReminderDraft copyWith(
          {bool? remind,
          int? hour,
          int? minute,
          bool clearTime = false,
          String? message}) =>
      ReminderDraft(
        remind: remind ?? this.remind,
        hour: clearTime ? null : (hour ?? this.hour),
        minute: clearTime ? null : (minute ?? this.minute),
        message: message ?? this.message,
      );
}

/// Remind-me switch, the plan's own reminder time, and the reader's own
/// words for the notification. Shared by the start and manage sheets.
///
/// Turning the switch on also turns the Reading plan notification
/// category on (a reminder nothing would ever deliver is worse than no
/// switch); if the notification master switch is off it says so and
/// offers Settings rather than flipping it, because that is where the
/// operating system's permission is asked for.
class ReadingReminderFields extends StatefulWidget {
  final ReminderDraft value;
  final ValueChanged<ReminderDraft> onChanged;
  const ReadingReminderFields(
      {super.key, required this.value, required this.onChanged});

  @override
  State<ReadingReminderFields> createState() => _ReadingReminderFieldsState();
}

class _ReadingReminderFieldsState extends State<ReadingReminderFields> {
  late final TextEditingController _message =
      TextEditingController(text: widget.value.message);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    widget.onChanged(widget.value.copyWith(remind: on));
    if (!on) return;
    final settings = context.read<AppSettings>();
    final cat =
        settings.notificationCategory(NotificationCategoryIds.readingPlan);
    if (!cat.enabled) {
      await settings.setNotificationCategory(
          NotificationCategoryIds.readingPlan, cat.copyWith(enabled: true));
    }
  }

  Future<void> _pickTime() async {
    final settings = context.read<AppSettings>();
    final cat =
        settings.notificationCategory(NotificationCategoryIds.readingPlan);
    final v = widget.value;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: v.hour ?? cat.hour, minute: v.minute ?? cat.minute),
    );
    if (picked == null || !mounted) return;
    widget.onChanged(v.copyWith(hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final cat =
        settings.notificationCategory(NotificationCategoryIds.readingPlan);
    final v = widget.value;
    final hasOwnTime = v.hour != null && v.minute != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('reminder.switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(rpText('readingPlan_remindMe', locale)),
          value: v.remind,
          onChanged: _toggle,
        ),
        if (v.remind) ...[
          if (!settings.notificationsEnabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                key: const ValueKey('reminder.needsNotifications'),
                children: [
                  Expanded(
                      child: Text(
                          rpText('readingPlan_remindNeedsNotifications', locale),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  TextButton(
                    onPressed: () => pushPage(const SettingsPage(),
                        routeName: '/settings'),
                    child: Text(rpText('readingPlan_openSettings', locale)),
                  ),
                ],
              ),
            ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(rpText('readingPlan_remindWebNote', locale),
                  style: Theme.of(context).textTheme.bodySmall),
            )
          else
            ListTile(
              key: const ValueKey('reminder.time'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time_rounded),
              title: Text(rpText('readingPlan_remindTime', locale)),
              subtitle: Text(hasOwnTime
                  ? formatPlanTime(v.hour!, v.minute!)
                  : rpText('readingPlan_remindDefaultTime', locale,
                      {'time': formatPlanTime(cat.hour, cat.minute)})),
              trailing: hasOwnTime
                  ? TextButton(
                      key: const ValueKey('reminder.useDefault'),
                      onPressed: () =>
                          widget.onChanged(v.copyWith(clearTime: true)),
                      child:
                          Text(rpText('readingPlan_remindUseDefault', locale)))
                  : null,
              onTap: _pickTime,
            ),
          TextField(
            key: const ValueKey('reminder.message'),
            controller: _message,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: rpText('readingPlan_remindMessage', locale),
              hintText: rpText('readingPlan_remindMessageHint', locale),
              border: const OutlineInputBorder(),
            ),
            onChanged: (t) => widget.onChanged(v.copyWith(message: t)),
          ),
        ],
      ],
    );
  }
}

/// Weekday chips for the days a plan does not run on.
class DaysOffPicker extends StatelessWidget {
  final Set<int> value;
  final ValueChanged<Set<int>> onChanged;
  const DaysOffPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rpText('readingPlan_restDays', locale),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(rpText('readingPlan_restDaysHint', locale),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              key: ValueKey('daysOff.$d'),
              label: Text(rpText('readingPlan_wd$d', locale)),
              selected: value.contains(d),
              // Seven days off would be no plan at all: the last one stays.
              onSelected: (on) {
                final next = {...value};
                on ? next.add(d) : next.remove(d);
                if (next.length >= 7) return;
                onChanged(next);
              },
            ),
        ]),
      ],
    );
  }
}

/// Pick books from the canon, grouped Old / New Testament.
Future<Set<String>?> showBookPicker(BuildContext context, ChapterCatalog catalog,
    Set<String> initial, String locale) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BookPicker(catalog: catalog, initial: initial),
  );
}

class _BookPicker extends StatefulWidget {
  final ChapterCatalog catalog;
  final Set<String> initial;
  const _BookPicker({required this.catalog, required this.initial});

  @override
  State<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<_BookPicker> {
  late Set<String> _sel = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final books = widget.catalog.books;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            TextButton(
                key: const ValueKey('books.all'),
                onPressed: () => setState(() => _sel = {...books}),
                child: Text(rpText('readingPlan_customAll', locale))),
            TextButton(
                key: const ValueKey('books.none'),
                onPressed: () => setState(() => _sel = {}),
                child: Text(rpText('readingPlan_customNone', locale))),
            FilledButton(
                key: const ValueKey('books.done'),
                onPressed: () => Navigator.of(context).pop(_sel),
                child: Text(rpText('readingPlan_customDone', locale))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: books.length,
            itemBuilder: (c, i) => CheckboxListTile(
              key: ValueKey('book.${books[i]}'),
              dense: true,
              title: Text(localeAwareBookName(books[i], locale)),
              value: _sel.contains(books[i]),
              onChanged: (v) => setState(() {
                v == true ? _sel.add(books[i]) : _sel.remove(books[i]);
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Date range a start date may be moved within: far enough back to
/// record a plan begun months ago, far enough ahead to plan a new year.
DateTimeRange planDateRange(DateTime now) => DateTimeRange(
      start: DateTime(now.year, now.month, now.day - 400),
      end: DateTime(now.year + 2, now.month, now.day),
    );

/// Start [plan]: when, and how to be reminded. True when it was started.
Future<bool> showStartPlanSheet(
    BuildContext context, ReadingPlan? plan, String locale) async {
  final started = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StartPlanSheet(plan: plan),
  );
  return started == true;
}

class _StartPlanSheet extends StatefulWidget {
  /// Null: the reader is making their own plan.
  final ReadingPlan? plan;
  const _StartPlanSheet({required this.plan});

  @override
  State<_StartPlanSheet> createState() => _StartPlanSheetState();
}

enum _When { today, tomorrow, date }

enum _Pace { days, finishBy }

class _StartPlanSheetState extends State<_StartPlanSheet> {
  _When _when = _When.today;
  DateTime? _picked;
  ReminderDraft _reminder = const ReminderDraft();
  Set<int> _rest = {};
  bool _busy = false;

  // Making their own plan.
  final TextEditingController _name = TextEditingController();
  final TextEditingController _daysCtl = TextEditingController(text: '90');
  Set<String> _books = {};
  _Pace _pace = _Pace.days;
  DateTime? _finishBy;

  ReadingPlanService get _svc => ReadingPlanService.instance;
  bool get _isCustom => widget.plan == null;
  ChapterCatalog? get _catalog => _svc.catalog;

  @override
  void dispose() {
    _name.dispose();
    _daysCtl.dispose();
    super.dispose();
  }

  DateTime get _date {
    final n = _svc.now;
    final today = DateTime(n.year, n.month, n.day);
    switch (_when) {
      case _When.today:
        return today;
      case _When.tomorrow:
        return DateTime(today.year, today.month, today.day + 1);
      case _When.date:
        return _picked ?? today;
    }
  }

  /// Reading days from the start date up to and including [end], not
  /// counting the plan's days off.
  int _daysUntil(DateTime end) {
    final rest = _rest.length >= 7 ? <int>{} : _rest;
    var d = _date;
    var n = 0;
    while (!d.isAfter(end)) {
      if (!rest.contains(d.weekday)) n++;
      d = DateTime(d.year, d.month, d.day + 1);
      if (n > 5000) break;
    }
    return n;
  }

  int? get _customDays {
    if (_pace == _Pace.days) return int.tryParse(_daysCtl.text.trim());
    final f = _finishBy;
    return f == null ? null : _daysUntil(f);
  }

  /// What is wrong with the plan being made, or null.
  String? _customProblem(String locale) {
    final cat = _catalog;
    if (cat == null) return null;
    if (_books.isEmpty) return rpText('readingPlan_customPickBooks', locale);
    final n = _customDays;
    final chapters = cat.chapterCount(_books);
    if (_pace == _Pace.finishBy && (n == null || n < 1)) {
      return rpText('readingPlan_customBadDate', locale);
    }
    if (n == null || n < 1 || n > chapters) {
      return rpText('readingPlan_customTooMany', locale, {'n': chapters});
    }
    return null;
  }

  Future<void> _pickDate() async {
    final range = planDateRange(_svc.now);
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: range.start,
      lastDate: range.end,
    );
    if (d == null || !mounted) return;
    setState(() {
      _picked = d;
      _when = _When.date;
    });
  }

  Future<void> _pickFinish() async {
    final range = planDateRange(_svc.now);
    final d = await showDatePicker(
      context: context,
      initialDate: _finishBy ?? DateTime(_date.year, _date.month, _date.day + 89),
      firstDate: _date,
      lastDate: DateTime(range.end.year + 3, range.end.month, range.end.day),
    );
    if (d == null || !mounted) return;
    setState(() {
      _finishBy = d;
      _pace = _Pace.finishBy;
    });
  }

  Future<void> _chooseBooks(String locale) async {
    final cat = _catalog;
    if (cat == null) return;
    final picked = await showBookPicker(context, cat, _books, locale);
    if (picked != null && mounted) setState(() => _books = picked);
  }

  Future<void> _start() async {
    if (_busy) return;
    final locale = context.read<AppSettings>().locale;
    if (_isCustom && _customProblem(locale) != null) return;
    setState(() => _busy = true);
    final r = _reminder;
    final e = await _svc.start(
      widget.plan?.id ?? 'custom',
      custom: _isCustom
          ? CustomPlanSpec(
              name: _name.text.trim().isEmpty ? null : _name.text.trim(),
              books: _books.toList(),
              days: _customDays!)
          : null,
      startDate: _date,
      restDays: _rest,
      remind: r.remind,
      hour: r.hour,
      minute: r.minute,
      message: r.message,
    );
    if (!mounted) return;
    if (e == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(rpText('readingPlan_limitReached', locale,
              {'n': kMaxReadingPlans}))));
      setState(() => _busy = false);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _customSection(BuildContext context, String locale, ThemeData theme) {
    final cat = _catalog;
    final problem = _customProblem(locale);
    final chapters = cat == null ? 0 : cat.chapterCount(_books);
    final n = _customDays;
    final ot = cat == null ? <String>{} : cat.books.take(39).toSet();
    final nt = cat == null ? <String>{} : cat.books.skip(39).toSet();
    bool same(Set<String> a, Set<String> b) =>
        a.length == b.length && a.containsAll(b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('custom.name'),
          controller: _name,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: rpText('readingPlan_customName', locale),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(rpText('readingPlan_customBooks', locale),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            key: const ValueKey('custom.whole'),
            label: Text(rpText('readingPlan_customWholeBible', locale)),
            selected: cat != null && same(_books, {...ot, ...nt}),
            onSelected: (_) => setState(() => _books = {...ot, ...nt}),
          ),
          ChoiceChip(
            key: const ValueKey('custom.ot'),
            label: Text(rpText('readingPlan_customOt', locale)),
            selected: cat != null && same(_books, ot),
            onSelected: (_) => setState(() => _books = {...ot}),
          ),
          ChoiceChip(
            key: const ValueKey('custom.nt'),
            label: Text(rpText('readingPlan_customNt', locale)),
            selected: cat != null && same(_books, nt),
            onSelected: (_) => setState(() => _books = {...nt}),
          ),
          ActionChip(
            key: const ValueKey('custom.choose'),
            avatar: const Icon(Icons.checklist, size: 18),
            label: Text(rpText('readingPlan_customChoose', locale)),
            onPressed: () => _chooseBooks(locale),
          ),
        ]),
        if (_books.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(rpText('readingPlan_customSummary', locale,
              {'books': _books.length, 'chapters': chapters})),
        ],
        const SizedBox(height: 12),
        Text(rpText('readingPlan_customPace', locale),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            key: const ValueKey('custom.paceDays'),
            label: Text(rpText('readingPlan_customInDays', locale)),
            selected: _pace == _Pace.days,
            onSelected: (_) => setState(() => _pace = _Pace.days),
          ),
          ChoiceChip(
            key: const ValueKey('custom.paceDate'),
            label: Text(rpText('readingPlan_customByDate', locale)),
            selected: _pace == _Pace.finishBy,
            onSelected: (_) => _pickFinish(),
          ),
        ]),
        const SizedBox(height: 8),
        if (_pace == _Pace.days)
          TextField(
            key: const ValueKey('custom.days'),
            controller: _daysCtl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: rpText('readingPlan_customDays', locale),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          )
        else
          ListTile(
            key: const ValueKey('custom.finishBy'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_available_outlined),
            title: Text(rpText('readingPlan_customFinishBy', locale)),
            subtitle: Text(_finishBy == null
                ? rpText('readingPlan_pickDate', locale)
                : '${formatPlanDate(_finishBy!)} · ${rpText('readingPlan_daysCount', locale, {'days': n ?? 0})}'),
            onTap: _pickFinish,
          ),
        const SizedBox(height: 4),
        if (problem != null)
          Text(problem,
              key: const ValueKey('custom.problem'),
              style: TextStyle(color: theme.colorScheme.error))
        else if (n != null && n > 0)
          Text(rpText('readingPlan_customPerDay', locale,
              {'n': (chapters / n).toStringAsFixed(chapters % n == 0 ? 0 : 1)})),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final theme = Theme.of(context);
    final plan = widget.plan;
    final canStart = !_busy && (!_isCustom || _customProblem(locale) == null);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                plan == null
                    ? rpText('readingPlan_customTitle', locale)
                    : readingPlanName(plan, locale),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(plan == null
                ? rpText('readingPlan_customDesc', locale)
                : rpText('readingPlan_${plan.id}_desc', locale)),
            const SizedBox(height: 16),
            if (plan == null) ...[
              _customSection(context, locale, theme),
              const SizedBox(height: 16),
            ],
            Text(rpText('readingPlan_startDate', locale),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                key: const ValueKey('start.today'),
                label: Text(rpText('readingPlan_todayOption', locale)),
                selected: _when == _When.today,
                onSelected: (_) => setState(() => _when = _When.today),
              ),
              ChoiceChip(
                key: const ValueKey('start.tomorrow'),
                label: Text(rpText('readingPlan_tomorrowOption', locale)),
                selected: _when == _When.tomorrow,
                onSelected: (_) => setState(() => _when = _When.tomorrow),
              ),
              ChoiceChip(
                key: const ValueKey('start.pick'),
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_when == _When.date
                    ? formatPlanDate(_date)
                    : rpText('readingPlan_pickDate', locale)),
                selected: _when == _When.date,
                onSelected: (_) => _pickDate(),
              ),
            ]),
            const SizedBox(height: 8),
            Text(formatPlanDate(_date), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            DaysOffPicker(
                value: _rest, onChanged: (v) => setState(() => _rest = v)),
            const SizedBox(height: 12),
            ReadingReminderFields(
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const ValueKey('start.confirm'),
                onPressed: canStart ? _start : null,
                child: Text(rpText('readingPlan_startButton', locale)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Manage a running plan: start date, reminder, pause, catching up,
/// removing. Changes apply as they are made.
Future<void> showManagePlanSheet(
    BuildContext context, String entryId, ReadingPlan plan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ManagePlanSheet(entryId: entryId, plan: plan),
  );
}

class _ManagePlanSheet extends StatefulWidget {
  final String entryId;
  final ReadingPlan plan;
  const _ManagePlanSheet({required this.entryId, required this.plan});

  @override
  State<_ManagePlanSheet> createState() => _ManagePlanSheetState();
}

class _ManagePlanSheetState extends State<_ManagePlanSheet> {
  ReadingPlanService get _svc => ReadingPlanService.instance;
  Timer? _messageTimer;
  ReminderDraft? _pendingMessage;

  @override
  void dispose() {
    _flushMessage();
    super.dispose();
  }

  /// Typing saves a moment after the last keystroke, and on close, so a
  /// sync upload is not requested for every letter.
  void _flushMessage() {
    _messageTimer?.cancel();
    final d = _pendingMessage;
    _pendingMessage = null;
    if (d == null) return;
    final m = d.message.trim();
    unawaited(_svc.setReminder(widget.entryId,
        message: m.isEmpty ? null : m, clearMessage: m.isEmpty));
  }

  void _onReminder(ReadingPlanProgress e, ReminderDraft d) {
    if (d.message != (e.message ?? '') && d.remind == e.remind &&
        d.hour == e.hour && d.minute == e.minute) {
      _pendingMessage = d;
      _messageTimer?.cancel();
      _messageTimer = Timer(const Duration(milliseconds: 700), _flushMessage);
      return;
    }
    unawaited(_svc.setReminder(
      widget.entryId,
      remind: d.remind,
      hour: d.hour,
      minute: d.minute,
      clearTime: d.hour == null,
    ));
  }

  Future<void> _changeStart(ReadingPlanProgress e) async {
    final range = planDateRange(_svc.now);
    final d = await showDatePicker(
      context: context,
      initialDate: e.start.isBefore(range.start) ? range.start : e.start,
      firstDate: range.start.isBefore(e.start) ? range.start : e.start,
      lastDate: range.end,
    );
    if (d == null) return;
    await _svc.setStart(widget.entryId, d);
  }

  Future<void> _share(
      ReadingPlanProgress e, ReadingPlanStatus st, String locale) async {
    final text = rpText('readingPlan_shareText', locale, {
      'name': readingPlanName(widget.plan, locale),
      'day': st.today,
      'days': widget.plan.days,
      'done': st.doneCount,
    });
    try {
      await Share.share(text);
    } catch (_) {
      // No share sheet here (a desktop browser, a test): copy it instead.
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(rpText('readingPlan_shareCopied', locale))));
      }
    }
  }

  Future<void> _remove(String locale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(rpText('readingPlan_removeConfirm', locale)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(rpText('readingPlan_cancel', locale))),
          FilledButton(
              key: const ValueKey('manage.removeConfirm'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(rpText('readingPlan_confirm', locale))),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.remove(widget.entryId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _svc,
      builder: (context, _) {
        final e = _svc.entry(widget.entryId);
        if (e == null) return const SizedBox(height: 120);
        final st = readingPlanStatus(e, widget.plan.days, _svc.now);
        final draft = ReminderDraft(
            remind: e.remind,
            hour: e.hour,
            minute: e.minute,
            message: e.message ?? '');
        final behind = !st.finished && !st.notStarted && st.unreadBefore > 0;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(readingPlanName(widget.plan, locale),
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  key: const ValueKey('manage.start'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(rpText('readingPlan_changeStart', locale)),
                  subtitle: Text(formatPlanDate(e.start)),
                  onTap: () => _changeStart(e),
                ),
                const SizedBox(height: 8),
                DaysOffPicker(
                  value: e.restDays,
                  onChanged: (v) => _svc.setRestDays(widget.entryId, v),
                ),
                const Divider(),
                ReadingReminderFields(
                  value: draft,
                  onChanged: (d) => _onReminder(e, d),
                ),
                const Divider(),
                if (st.finished) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(rpText('readingPlan_completed', locale)),
                  ),
                  ListTile(
                    key: const ValueKey('manage.readAgain'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.replay),
                    title: Text(rpText('readingPlan_readAgain', locale)),
                    subtitle: Text(rpText('readingPlan_readAgainHint', locale)),
                    onTap: () async {
                      final again = await _svc.restart(widget.entryId);
                      if (!mounted) return;
                      if (again == null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                            content: Text(rpText('readingPlan_limitReached',
                                locale, {'n': kMaxReadingPlans}))));
                      } else {
                        Navigator.of(this.context).pop();
                      }
                    },
                  ),
                ] else
                  ListTile(
                    key: const ValueKey('manage.pause'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.paused
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline),
                    title: Text(rpText(
                        e.paused ? 'readingPlan_resume' : 'readingPlan_pause',
                        locale)),
                    subtitle: e.paused
                        ? null
                        : Text(rpText('readingPlan_pauseHint', locale)),
                    onTap: () => e.paused
                        ? _svc.resume(widget.entryId)
                        : _svc.pause(widget.entryId),
                  ),
                if (behind) ...[
                  ListTile(
                    key: const ValueKey('manage.catchUp'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fast_forward_outlined),
                    title: Text(rpText('readingPlan_catchUp', locale)),
                    subtitle: Text(rpText('readingPlan_catchUpHint', locale,
                        {'day': st.resumeDay ?? st.today})),
                    onTap: () => _svc.catchUp(widget.entryId),
                  ),
                  ListTile(
                    key: const ValueKey('manage.markMissedRead'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.done_all),
                    title: Text(rpText('readingPlan_markMissedRead', locale,
                        {'n': st.unreadBefore})),
                    subtitle:
                        Text(rpText('readingPlan_markMissedReadHint', locale)),
                    onTap: () => _svc.markMissedRead(widget.entryId),
                  ),
                  ListTile(
                    key: const ValueKey('manage.skipMissed'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.skip_next_outlined),
                    title: Text(rpText('readingPlan_skipMissed', locale,
                        {'n': st.unreadBefore})),
                    subtitle:
                        Text(rpText('readingPlan_skipMissedHint', locale)),
                    onTap: () => _svc.skipMissed(widget.entryId),
                  ),
                ],
                const Divider(),
                ListTile(
                  key: const ValueKey('manage.share'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share),
                  title: Text(rpText('readingPlan_share', locale)),
                  onTap: () => _share(e, st, locale),
                ),
                ListTile(
                  key: const ValueKey('manage.remove'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                  title: Text(rpText('readingPlan_remove', locale),
                      style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () => _remove(locale),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

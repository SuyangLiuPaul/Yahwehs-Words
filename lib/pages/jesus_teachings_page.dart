/// 主耶稣的教导 — the teachings of the Lord Jesus, and what the app
/// already knows about each of them.
///
/// PORTED FROM YAHWEH'S SWORD, 2026-09-21: 「主耶稣的教导我也要搬一份到
/// words」, reached from the bottom of the home page 「可以就直接放在最下面
/// home page的」. Sword is where this is written (「应该是直接写在sword里面
/// 的」); the dataset is a byte-for-byte copy and the service is Sword's
/// with the package renamed. This page is the one real rewrite, and only
/// in its skin: Sword draws with its workbench theme (`WbColors`,
/// `WbType`), which Words does not have, so the colours come from the
/// Material scheme and the strings from `uiStrings`. The structure, the
/// wording and every rule below are Sword's.
///
/// WHAT THIS PAGE MAY SAY, which is the whole design problem.
///
/// The owner's request was for a page where the apostles' letters are
/// shown as resting on Jesus' teaching, and the Old Testament under it.
/// That conviction is not in dispute here. The difficulty is that the
/// data which can link the passages — the Treasury of Scripture
/// Knowledge, merged with OpenBible.info votes — asserts only that two
/// passages are RELATED. "Rests on" is a directional claim TSK does not
/// make.
///
/// So the conviction goes in the PREFACE, in the owner's voice, with the
/// texts that ground it; and the column headings stay neutral —
/// 「在使徒书信中」, not 「以此为根基」. A reader who holds the conviction
/// sees exactly what they came for; the page never asserts more than its
/// sources carry.
///
/// The one exception is [TeachingLink.lordsWord]: five places where an
/// apostle says outright that he is handing on the Lord's own word
/// (1 Cor 7:10-11, 9:14, 11:23-25; 1 Thess 4:15; Acts 20:35). Those are
/// marked, because there scripture itself makes the claim.
///
/// The arrangement is editorial and the page says so rather than hoping
/// nobody asks — Sword's `scripts/build_jesus_teachings.py` carries the
/// reasons.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/map_viewer_page.dart';
import 'package:yahwehs_words/pages/sermon_detail_page.dart';
import 'package:yahwehs_words/services/jesus_teachings_service.dart';
import 'package:yahwehs_words/services/map_service.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_words/utils/passage_localizer.dart'
    show localizePassage;
import 'package:yahwehs_words/utils/reference_parser.dart' show parseReference;
import 'package:yahwehs_words/widgets/home_icon_button.dart';
import 'package:yahwehs_words/widgets/language_switcher_button.dart';
import 'package:yahwehs_words/widgets/localized_back_button.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart'
    show showVersePopup;

/// The path this page answers on, shared by the route table, the home
/// card and the tests so the three cannot disagree.
const String kJesusTeachingsRoute = '/jesus-teachings';

String _t(String key, String locale) =>
    uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? key;

/// The `uiStrings` key for each filter chip. `teaching` is the dataset's
/// word for everything that is neither a discourse nor a parable, and
/// the chip calls it 「其他教导」.
const Map<String?, String> _kindKey = {
  null: 'jesusTeachingsAll',
  'discourse': 'jesusTeachingsDiscourse',
  'parable': 'jesusTeachingsParable',
  'teaching': 'jesusTeachingsOther',
};

class JesusTeachingsPage extends StatefulWidget {
  const JesusTeachingsPage({super.key});

  @override
  State<JesusTeachingsPage> createState() => _JesusTeachingsPageState();
}

class _JesusTeachingsPageState extends State<JesusTeachingsPage> {
  Future<JesusTeachingsData>? _future;
  final Set<String> _open = {};

  /// null = everything, in canonical order. A kind narrows the list to
  /// that kind 「类似于比喻可以放在一起」 — the parables in one place,
  /// still in the order the gospels put them.
  String? _kind;

  @override
  void initState() {
    super.initState();
    _future = JesusTeachingsService.instance.load();
  }

  Future<void> _read(String raw) async {
    final ref = parseReference(raw);
    if (ref == null || !mounted) return;
    await showVersePopup(context, ref);
  }

  Future<void> _openSermon(String id) async {
    final all = await SermonService.instance.loadIndex();
    final match = all.where((s) => s.id == id);
    if (match.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SermonDetailPage(sermon: match.first)));
  }

  Future<void> _openPlate(String id, String locale) async {
    final maps = await MapService.loadMaps();
    final match = maps.where((m) => m.id == id);
    if (match.isEmpty || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MapViewerPage(map: match.first, locale: locale)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_t('jesusTeachings', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<JesusTeachingsData>(
        future: _future,
        // Already-decoded data goes straight in rather than through a
        // frame of spinner. It also makes the page testable: a
        // `rootBundle` read never completes inside a widget test's
        // fake-async zone, so a page that can only arrive via the
        // future can only ever be tested as a spinner.
        initialData: JesusTeachingsService.instance.cached,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${_t('loadErrorTitle', locale)}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          // ONE LEVEL. The first build indented each discourse's parts
          // under it, so the Sermon on the Mount was a row followed by
          // twenty-one more rows and the list ran to eighty-seven.
          // 2026-09-16 「我要你全部放一起 这样大家有一个overview 知道有
          // 什么教导 ... 要清晰简单」: the parts fold into the teaching
          // and are named inside it, so this is a list a reader can
          // take in, not an outline they have to climb.
          final top = _kind == null
              ? data.teachings
              : [
                  for (final t in data.teachings)
                    if (t.kind == _kind) t
                ];
          return ListView.builder(
            key: const ValueKey('jesusTeachingsList'),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: top.length + 1,
            itemBuilder: (context, i) => i == 0
                ? _preface(data, locale, scheme, settings)
                : _row(top[i - 1], locale, scheme, settings),
          );
        },
      ),
    );
  }

  TextStyle _style(AppSettings settings,
          {required Color color,
          required double size,
          FontWeight weight = FontWeight.w400,
          double height = 1.4}) =>
      TextStyle(
        color: color,
        fontFamily: settings.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
        fontWeight: weight,
        height: height,
      );

  Widget _preface(JesusTeachingsData data, String locale, ColorScheme scheme,
      AppSettings settings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t('jesusTeachingsPreface', locale),
              style: _style(settings,
                  color: scheme.onSurface, size: 14, height: 1.55)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final kind in _kindKey.keys)
              _kindChip(kind, data, locale, scheme, settings),
          ]),
          const SizedBox(height: 12),
          // The page's own limits, carried out of the dataset rather
          // than retyped here so the two cannot drift apart.
          Text(
              '${data.teachings.length} ${_t('jesusTeachingsCount', locale)} · '
              '${data.claimsFor(locale)}',
              style: _style(settings,
                  color: scheme.onSurfaceVariant, size: 12, height: 1.45)),
        ],
      ),
    );
  }

  Widget _kindChip(String? kind, JesusTeachingsData data, String locale,
      ColorScheme scheme, AppSettings settings) {
    final n = kind == null
        ? data.teachings.length
        : data.teachings.where((x) => x.kind == kind).length;
    return ChoiceChip(
      key: ValueKey('teachingKind-${kind ?? 'all'}'),
      label: Text('${_t(_kindKey[kind]!, locale)} $n'),
      labelStyle: _style(settings,
          color: _kind == kind
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
          size: 13,
          weight: _kind == kind ? FontWeight.w600 : FontWeight.w400,
          height: 1.2),
      selected: _kind == kind,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _kind = kind),
    );
  }

  Widget _row(JesusTeaching teaching, String locale, ColorScheme scheme,
      AppSettings settings) {
    final open = _open.contains(teaching.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('teaching-${teaching.id}'),
          onTap: () => setState(
              () => open ? _open.remove(teaching.id) : _open.add(teaching.id)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teaching.titleFor(locale),
                        style: _style(settings,
                            color: scheme.onSurface,
                            size: teaching.isDiscourse ? 16 : 15,
                            weight: teaching.isDiscourse
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.35),
                      ),
                      if (teaching.noteFor(locale) case final note?) ...[
                        const SizedBox(height: 2),
                        // Nave's own sentence, kept under the app's
                        // heading because it carries what a heading
                        // does not: which journey it happened on,
                        // whether this is the second telling.
                        Text(note,
                            style: _style(settings,
                                color: scheme.onSurfaceVariant,
                                size: 12.5,
                                height: 1.35)),
                      ],
                      const SizedBox(height: 3),
                      Text(localizePassage(teaching.label, locale),
                          style: _style(settings,
                              color: scheme.onSurfaceVariant,
                              size: 12.5,
                              height: 1.35)),
                    ],
                  ),
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    size: 22, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (open) _detail(teaching, locale, scheme, settings),
      ],
    );
  }

  Widget _detail(JesusTeaching teaching, String locale, ColorScheme scheme,
      AppSettings settings) {
    Widget section(String key, List<Widget> chips) {
      if (chips.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(key, locale),
                style: _style(settings,
                    color: scheme.onSurfaceVariant,
                    size: 12.5,
                    weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ),
      );
    }

    // A tappable passage, sermon or plate. Outlined rather than filled:
    // there can be forty of these open at once, and forty filled pills
    // read as buttons competing for attention rather than a list of
    // places to go.
    Widget chip(String label, VoidCallback onTap, {String? note}) => Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: _style(settings,
                          color: scheme.primary, size: 13.5, height: 1.3)),
                  if (note != null)
                    Text(note,
                        style: _style(settings,
                            color: scheme.tertiary,
                            size: 12,
                            weight: FontWeight.w600,
                            height: 1.3)),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section('jesusTeachingsScripture', [
            for (final r in teaching.refs)
              // The label a reader reads is in their own language;
              // `parseReference` is still given the English one, which
              // is what it was built to take.
              chip(localizePassage(r.label, locale), () => _read(r.label)),
          ]),
          // What folded into this row. Named, with its own passage, so
          // nothing the flattening absorbed became invisible.
          section('jesusTeachingsContains', [
            for (final c in teaching.contains)
              chip(
                  '${c.titleFor(locale)}  '
                  '${localizePassage(c.label, locale)}',
                  () => _read(c.ref)),
          ]),
          section('jesusTeachingsSermons', [
            for (final s in teaching.sermons)
              chip(
                  '${s.titleFor(locale)}${s.date.contains('-') && !s.date.contains('mm') ? '  ${s.date}' : ''}',
                  () => _openSermon(s.id)),
          ]),
          section('jesusTeachingsOt', [
            for (final r in teaching.oldTestament)
              chip(localizePassage(r, locale), () => _read(r)),
          ]),
          section('jesusTeachingsApostles', [
            for (final a in teaching.apostles)
              chip(localizePassage(a.ref, locale), () => _read(a.ref),
                  note: a.lordsWord == null
                      ? null
                      : _t('jesusTeachingsLordsWord', locale)),
          ]),
          section('jesusTeachingsPlates', [
            for (final p in teaching.plates)
              chip(p.titleFor(locale), () => _openPlate(p.id, locale)),
          ]),
        ],
      ),
    );
  }
}

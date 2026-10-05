import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yahwehs_words/models/sermon.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/pages/sermon_detail_page.dart';
import 'package:yahwehs_words/services/sermon_service.dart';
import 'package:yahwehs_words/utils/app_nav.dart';
import 'package:yahwehs_words/utils/passage_localizer.dart';
import 'package:yahwehs_words/utils/reference_parser.dart';
import 'package:yahwehs_words/widgets/verse_popup_sheet.dart';

String studyL(String locale, String en, String hs, String ht) =>
    locale == 'zh-Hans'
        ? hs
        : locale == 'zh-Hant'
            ? ht
            : en;

/// Colour for a promise status glyph (✔ ∞ ◐ ✘). Tuned for both themes.
Color studyStatusColor(String status, Brightness b) {
  final dark = b == Brightness.dark;
  switch (status) {
    case '✔':
      return dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    case '∞':
      return dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    case '◐':
      return dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309);
    default:
      return dark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A);
  }
}

Color studyVerdictColor(String verdict, Brightness b) {
  final dark = b == Brightness.dark;
  switch (verdict) {
    case 'agree':
      return dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    case 'qualify':
      return dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309);
    default:
      return dark ? const Color(0xFF90CAF9) : const Color(0xFF1E5AA8);
  }
}

String studyVerdictGlyph(String verdict) =>
    verdict == 'agree' ? '✔' : (verdict == 'qualify' ? '◐' : '⇄');

/// Status / verdict keys (✔ ∞ ◐ ✘ ⇄) are drawn as icons: the web build ships
/// no font for those code points and shows empty boxes.
IconData studyGlyphIcon(String g) {
  switch (g) {
    case '✔':
      return Icons.check_circle_rounded;
    case '∞':
      return Icons.all_inclusive_rounded;
    case '◐':
      return Icons.contrast_rounded;
    case '⇄':
      return Icons.swap_horiz_rounded;
    default:
      return Icons.hourglass_empty_rounded;
  }
}

/// A small rounded label with a tinted background.
class StudyBadge extends StatelessWidget {
  final String text;
  final Color color;
  final String? glyph;
  const StudyBadge(
      {super.key, required this.text, required this.color, this.glyph});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (glyph != null) ...[
          Icon(studyGlyphIcon(glyph!), size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// Section heading inside an expanded card.
class StudyLabel2 extends StatelessWidget {
  final String text;
  const StudyLabel2(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: scheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary)),
      ]),
    );
  }
}

/// Tappable Bible-reference chips: each opens the app's own verse popup, so
/// the text shown is always the reader's edition, not a copy.
class StudyRefChips extends StatelessWidget {
  final List<String> refs;
  final String locale;
  const StudyRefChips({super.key, required this.refs, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final r in refs)
        ActionChip(
          key: ValueKey('ref.$r'),
          visualDensity: VisualDensity.compact,
          avatar:
              Icon(Icons.menu_book_rounded, size: 15, color: scheme.primary),
          label: Text(localizePassage(r, locale),
              style: const TextStyle(fontSize: 13)),
          onPressed: () {
            final ref = parseReference(r);
            if (ref != null) showVersePopup(context, ref);
          },
        ),
    ]);
  }
}

Future<void> openSermonById(BuildContext context, String id) async {
  final list = await SermonService.instance.loadIndex();
  final Sermon? s = list.where((x) => x.id == id).firstOrNull;
  if (s == null || !context.mounted) return;
  await pushPage(SermonDetailPage(sermon: s), routeName: '/sermons/${s.id}');
}

/// A verbatim sermon quotation. Tapping opens the sermon it came from.
class StudyQuoteBlock extends StatelessWidget {
  final StudyQuote quote;
  final String locale;
  const StudyQuoteBlock({super.key, required this.quote, required this.locale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = quote.quote.of(locale);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('quote.${quote.sermonId}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => openSermonById(context, quote.sermonId),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border(left: BorderSide(color: scheme.primary, width: 3.5))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('「$text」', style: const TextStyle(fontSize: 15, height: 1.55)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.record_voice_over_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(
                      '${studyL(locale, 'Sermon', '讲道', '講道')} ${quote.sermonId}'
                      '${quote.sermonTitle.isEmpty ? '' : ' · ${quote.sermonTitle.of(locale)}'}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ]),
          ]),
        ),
      ),
    );
  }
}

class StudyBullets extends StatelessWidget {
  final List<StudyText> points;
  final String locale;
  const StudyBullets({super.key, required this.points, required this.locale});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final p in points)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle))),
            Expanded(
                child: Text(p.of(locale),
                    style: const TextStyle(fontSize: 15, height: 1.6))),
          ]),
        ),
    ]);
  }
}

/// External source link. Opens in the browser.
class StudySourceLink extends StatelessWidget {
  final StudySource source;
  final String locale;
  const StudySourceLink(
      {super.key, required this.source, required this.locale});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(source.url),
          mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.open_in_new_rounded, size: 15, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(source.name.of(locale),
                  style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.primary,
                      decoration: TextDecoration.underline))),
        ]),
      ),
    );
  }
}

/// The soft gradient header used by both pages.
class StudyHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const StudyHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.children = const []});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer,
                scheme.secondaryContainer.withValues(alpha: 0.7)
              ]),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.55, color: scheme.onPrimaryContainer)),
        if (children.isNotEmpty) const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

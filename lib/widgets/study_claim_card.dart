import 'package:flutter/material.dart';
import 'package:yahwehs_words/models/study_data.dart';
import 'package:yahwehs_words/widgets/study_widgets.dart';

/// One sermon claim set against the Bible: quotes, scripture, analysis, verdict.
/// Used for the nine principles and for the nine promise propositions.
class StudyClaimCard extends StatelessWidget {
  final StudyClaim claim;
  final StudyLabel verdict;
  final String locale;
  final bool initiallyExpanded;
  final String keyPrefix;
  const StudyClaimCard({
    super.key,
    required this.claim,
    required this.verdict,
    required this.locale,
    this.initiallyExpanded = false,
    this.keyPrefix = 'claim',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vColor =
        studyVerdictColor(claim.verdict, Theme.of(context).brightness);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant)),
      child: ExpansionTile(
        key: ValueKey('$keyPrefix.${claim.id}'),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            child: Text('${claim.n}',
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14))),
        title: Text(claim.title.of(locale),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, height: 1.35)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (claim.tagline != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(claim.tagline!.of(locale),
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: scheme.onSurfaceVariant))),
            Wrap(spacing: 8, runSpacing: 6, children: [
              StudyBadge(
                  text: verdict.label.of(locale),
                  color: vColor,
                  glyph: studyVerdictGlyph(claim.verdict)),
            ]),
          ]),
        ),
        children: [
          StudyLabel2(studyL(locale, 'What the sermons say', '讲道怎么说', '講道怎麼說')),
          for (final q in claim.quotes)
            StudyQuoteBlock(quote: q, locale: locale),
          StudyLabel2(studyL(locale, 'The Bible', '圣经怎么说', '聖經怎麼說')),
          StudyRefChips(refs: claim.verses, locale: locale),
          StudyLabel2(studyL(locale, 'Comparison', '对照分析', '對照分析')),
          StudyBullets(points: claim.points, locale: locale),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: vColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: vColor.withValues(alpha: 0.4))),
            child: Text(
                '${studyL(locale, 'Assessment: ', '评估：', '評估：')}${claim.verdictNote.of(locale)}',
                style: TextStyle(
                    color: vColor, fontWeight: FontWeight.w700, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

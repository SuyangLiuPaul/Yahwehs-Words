import 'package:flutter/material.dart';
import 'package:yahwehs_words/services/reading_plan_service.dart';

/// Small building blocks shared by the reading-plan page, its schedule,
/// the Home card and the sheets, so they look like one feature.

/// A plan's picture.
IconData readingPlanIcon(String planId) {
  switch (planId) {
    case 'bible-1y':
      return Icons.auto_stories_outlined;
    case 'bible-1y-ot-nt':
      return Icons.compare_arrows_rounded;
    case 'mcheyne':
      return Icons.history_edu_outlined;
    case 'nt-90':
      return Icons.menu_book_outlined;
    case 'gospels-30':
      return Icons.favorite_border_rounded;
    case 'psalms-proverbs-31':
      return Icons.music_note_outlined;
    case 'custom':
      return Icons.edit_calendar_outlined;
    default:
      return Icons.event_note_outlined;
  }
}

/// A circular progress ring with something in the middle (a percentage,
/// an icon).
class PlanRing extends StatelessWidget {
  final double value;
  final double size;
  final Widget? child;
  final Color? color;
  final Color? track;
  final double stroke;
  const PlanRing({
    super.key,
    required this.value,
    this.size = 56,
    this.child,
    this.color,
    this.track,
    this.stroke = 5,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color ?? scheme.primary,
              backgroundColor: track ?? scheme.primary.withValues(alpha: 0.14),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// A small rounded status pill ("3 behind", "Paused", "07:30").
class PlanPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;
  const PlanPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSecondaryContainer;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ),
      ]),
    );
    if (onTap == null) return pill;
    return InkWell(
        borderRadius: BorderRadius.circular(20), onTap: onTap, child: pill);
  }
}

/// A passage ("Genesis 1-3"): a check when it has been read.
class PassageChip extends StatelessWidget {
  final String label;
  final bool read;
  final VoidCallback? onTap;
  const PassageChip(
      {super.key, required this.label, required this.read, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = read ? scheme.primaryContainer : scheme.surface;
    final fg = read ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: bg,
      shape: StadiumBorder(
          side: BorderSide(
              color: read ? Colors.transparent : scheme.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(read ? Icons.check_circle : Icons.menu_book_outlined,
                size: 17, color: read ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// True when every chapter of [seg] on [day] has been read (or the day is).
bool readingSegmentRead(ReadingPlanProgress e, int day, ReadingSegment seg) {
  if (e.done.contains(day)) return true;
  final have = e.readChapters[day];
  if (have == null || have.isEmpty) return false;
  for (var c = seg.from; c <= seg.to; c++) {
    if (!have.contains('${seg.book}|$c')) return false;
  }
  return true;
}

/// The part of a plan's today the reader still has to read, first first.
ReadingSegment? firstUnreadSegment(
    ReadingPlanProgress e, int day, List<ReadingSegment> segments) {
  for (final s in segments) {
    if (!readingSegmentRead(e, day, s)) return s;
  }
  return null;
}

/// A rounded tinted container that groups related rows.
class PlanGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  const PlanGroup(
      {super.key,
      this.title,
      required this.children,
      this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w700)),
          ),
        // A Material, not a coloured box: the ListTiles inside paint
        // their ink on the nearest Material, and a box would hide it.
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: padding,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

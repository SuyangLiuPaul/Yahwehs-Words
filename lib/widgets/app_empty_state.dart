import 'package:flutter/material.dart';

/// The "nothing here yet" picture, one design for every page that has it:
/// a tinted disc with the page's icon, a short title, one line saying
/// what will appear and how, and — where there is somewhere to go — a
/// button. Replaces a grey icon over a line of italic text, which read as
/// an error rather than as an invitation.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Inherit the page's reading font for the title and body.
  final TextStyle? textStyle;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('emptyState.disc'),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: (textStyle ?? const TextStyle()).copyWith(
                  fontSize: theme.textTheme.titleMedium?.fontSize,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: (textStyle ?? const TextStyle()).copyWith(
                    fontSize: theme.textTheme.bodyMedium?.fontSize,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.tonalIcon(
                  key: const ValueKey('emptyState.action'),
                  icon: Icon(actionIcon ?? Icons.menu_book_rounded, size: 18),
                  label: Text(actionLabel!),
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

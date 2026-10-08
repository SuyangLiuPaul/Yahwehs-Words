import 'package:flutter/material.dart';

/// Utility cards share the Settings typography rather than Material defaults.
/// This stays local to Settings: compact study panes keep their own density.
class SettingsUtilityTheme extends StatelessWidget {
  const SettingsUtilityTheme(
      {super.key,
      required this.fontSize,
      required this.fontFamily,
      required this.child});
  final double fontSize;
  final String fontFamily;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final body = base.textTheme.bodyLarge!
        .copyWith(fontSize: fontSize, fontFamily: fontFamily, height: 1.4);
    final title = body.copyWith(fontWeight: FontWeight.w600);
    final secondary = body.copyWith(
        fontSize: fontSize * .85, color: base.colorScheme.onSurfaceVariant);
    final iconSize = (fontSize + 4).clamp(24.0, 32.0).toDouble();
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.copyWith(
            titleMedium: title, bodyLarge: body, bodyMedium: secondary),
        listTileTheme: base.listTileTheme.copyWith(
            titleTextStyle: title,
            subtitleTextStyle: secondary,
            iconColor: base.colorScheme.primary,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minLeadingWidth: iconSize,
            horizontalTitleGap: 16),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                textStyle: secondary.copyWith(fontWeight: FontWeight.w600),
                iconSize: iconSize,
                minimumSize: const Size(48, 48))),
        iconTheme: base.iconTheme
            .copyWith(size: iconSize, color: base.colorScheme.primary),
      ),
      child: child,
    );
  }
}

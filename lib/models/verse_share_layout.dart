/// Presentation only: callers still supply the actual passage and its credits.
enum VerseSharePosition { top, center, bottom }

enum VerseShareAlignment { left, center, right }

class VerseShareLayout {
  final VerseSharePosition position;
  final VerseShareAlignment alignment;
  final double fontScale, lineHeight, padding;
  final bool showReference, showVersion;
  const VerseShareLayout(
      {this.position = VerseSharePosition.center,
      this.alignment = VerseShareAlignment.left,
      this.fontScale = 1,
      this.lineHeight = 1.62,
      this.padding = 28,
      this.showReference = true,
      this.showVersion = true});

  static double _number(
      Object? value, double fallback, double min, double max) {
    if (value is! num || !value.isFinite) return fallback;
    return value.toDouble().clamp(min, max);
  }

  factory VerseShareLayout.fromJson(Object? raw) {
    final m = raw is Map ? raw : const {};
    return VerseShareLayout(
      position: VerseSharePosition.values.firstWhere(
          (v) => v.name == m['position'],
          orElse: () => VerseSharePosition.center),
      alignment: VerseShareAlignment.values.firstWhere(
          (v) => v.name == m['alignment'],
          orElse: () => VerseShareAlignment.left),
      fontScale: _number(m['fontScale'], 1, .8, 1.4),
      lineHeight: _number(m['lineHeight'], 1.62, 1.2, 2),
      padding: _number(m['padding'], 28, 16, 40),
      showReference:
          m['showReference'] is bool ? m['showReference'] as bool : true,
      showVersion: m['showVersion'] is bool ? m['showVersion'] as bool : true,
    );
  }
  Map<String, Object> toJson() => {
        'position': position.name,
        'alignment': alignment.name,
        'fontScale': fontScale,
        'lineHeight': lineHeight,
        'padding': padding,
        'showReference': showReference,
        'showVersion': showVersion
      };
  VerseShareLayout copyWith(
          {VerseSharePosition? position,
          VerseShareAlignment? alignment,
          double? fontScale,
          double? lineHeight,
          double? padding,
          bool? showReference,
          bool? showVersion}) =>
      VerseShareLayout.fromJson({
        ...toJson(),
        if (position != null) 'position': position.name,
        if (alignment != null) 'alignment': alignment.name,
        if (fontScale != null) 'fontScale': fontScale,
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (padding != null) 'padding': padding,
        if (showReference != null) 'showReference': showReference,
        if (showVersion != null) 'showVersion': showVersion
      });
}

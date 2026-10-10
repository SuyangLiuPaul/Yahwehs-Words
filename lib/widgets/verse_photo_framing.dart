import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Normalised position in the overflow of a cover-fitted photo.
/// The same values drive the editor, card preview and exported card.
@immutable
class VersePhotoFraming {
  const VersePhotoFraming({this.zoom = 1, this.x = 0.5, this.y = 0.5});

  final double zoom;
  final double x;
  final double y;

  double get scale => zoom.isFinite ? zoom.clamp(1.0, 4.0) : 1;
  double get horizontal => x.isFinite ? x.clamp(0.0, 1.0) : 0.5;
  double get vertical => y.isFinite ? y.clamp(0.0, 1.0) : 0.5;
  Alignment get alignment => Alignment(horizontal * 2 - 1, vertical * 2 - 1);

  /// Preserve the image point under the fingers while zooming/panning.
  VersePhotoFraming gesture({
    required Size viewport,
    required Size image,
    required Offset startFocal,
    required Offset focal,
    required double gestureScale,
  }) {
    if (viewport.isEmpty || image.isEmpty || !gestureScale.isFinite) {
      return this;
    }
    final cover =
        math.max(viewport.width / image.width, viewport.height / image.height);
    final next = (scale * gestureScale).clamp(1.0, 4.0);
    final ratio = next / scale;
    double position(
        double source, double view, double p, double from, double to) {
      final oldOverflow = source * cover * scale - view;
      final newOverflow = source * cover * next - view;
      if (newOverflow <= 0.001) return 0.5;
      return ((ratio * (from + p * oldOverflow) - to) / newOverflow)
          .clamp(0.0, 1.0);
    }

    return VersePhotoFraming(
      zoom: next,
      x: position(
          image.width, viewport.width, horizontal, startFocal.dx, focal.dx),
      y: position(
          image.height, viewport.height, vertical, startFocal.dy, focal.dy),
    );
  }
}

/// Always covers the frame without changing the photograph's proportions.
class VersePhotoBackground extends StatelessWidget {
  const VersePhotoBackground(
      {super.key,
      required this.photo,
      required this.framing,
      required this.background,
      this.scrim});

  final ImageProvider photo;
  final VersePhotoFraming framing;
  final Color background;
  final Color? scrim;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: background,
        child: LayoutBuilder(
            builder: (context, constraints) => ClipRect(
                  child: Transform.scale(
                    scale: framing.scale,
                    alignment: framing.alignment,
                    child: Image(
                      image: photo,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      fit: BoxFit.cover,
                      alignment: framing.alignment,
                      color: scrim,
                      colorBlendMode: BlendMode.srcOver,
                      excludeFromSemantics: true,
                    ),
                  ),
                )),
      );
}

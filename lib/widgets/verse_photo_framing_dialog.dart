import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/widgets/verse_photo_framing.dart';

class VersePhotoFramingDialog extends StatefulWidget {
  const VersePhotoFramingDialog(
      {super.key,
      required this.initial,
      required this.photoSize,
      required this.cardSize,
      required this.locale,
      required this.cardBuilder});

  final VersePhotoFraming initial;
  final Size photoSize;
  final Size cardSize;
  final String locale;
  final Widget Function(VersePhotoFraming) cardBuilder;

  @override
  State<VersePhotoFramingDialog> createState() =>
      _VersePhotoFramingDialogState();
}

class _VersePhotoFramingDialogState extends State<VersePhotoFramingDialog> {
  late VersePhotoFraming _framing = widget.initial;
  VersePhotoFraming? _start;
  Offset? _startFocal;
  Size? _startSize;

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  void _zoom(double delta) => setState(() => _framing = VersePhotoFraming(
      zoom: (_framing.scale + delta).clamp(1, 4),
      x: _framing.horizontal,
      y: _framing.vertical));

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_s('versePhotoFrame', 'Adjust photo'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  _s('versePhotoFrameHint',
                      'Drag to move the photo. Pinch or use the zoom controls.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final ratio = widget.cardSize.width / widget.cardSize.height;
                final width = math.min(constraints.maxWidth,
                    MediaQuery.sizeOf(context).height * 0.44 * ratio);
                final size = Size(width, width / ratio);
                return Center(
                    child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: GestureDetector(
                    key: const ValueKey('verse-photo-viewfinder'),
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) {
                      _start = _framing;
                      _startFocal = d.localFocalPoint;
                      _startSize = size;
                    },
                    onScaleUpdate: (d) {
                      if (_start == null ||
                          _startFocal == null ||
                          _startSize != size) {
                        return;
                      }
                      setState(() => _framing = _start!.gesture(
                          viewport: size,
                          image: widget.photoSize,
                          startFocal: _startFocal!,
                          focal: d.localFocalPoint,
                          gestureScale: d.scale));
                    },
                    child: Stack(fit: StackFit.expand, children: [
                      FittedBox(
                          fit: BoxFit.contain,
                          child: widget.cardBuilder(_framing)),
                      const IgnorePointer(
                          child: CustomPaint(painter: _FrameGuide())),
                    ]),
                  ),
                ));
              }),
              const SizedBox(height: 12),
              Row(children: [
                IconButton(
                    onPressed: _framing.scale <= 1 ? null : () => _zoom(-0.25),
                    tooltip: _s('versePhotoZoomOut', 'Zoom out'),
                    icon: const Icon(Icons.remove)),
                Expanded(
                    child: Slider(
                  value: _framing.scale,
                  min: 1,
                  max: 4,
                  label: '${(_framing.scale * 100).round()}%',
                  semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => setState(() => _framing = VersePhotoFraming(
                      zoom: v, x: _framing.horizontal, y: _framing.vertical)),
                )),
                IconButton(
                    onPressed: _framing.scale >= 4 ? null : () => _zoom(0.25),
                    tooltip: _s('versePhotoZoomIn', 'Zoom in'),
                    icon: const Icon(Icons.add)),
              ]),
              Text('${(_framing.scale * 100).round()}%'),
              const SizedBox(height: 8),
              Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                        onPressed: () => setState(
                            () => _framing = const VersePhotoFraming()),
                        child:
                            Text(_s('versePhotoFrameReset', 'Reset framing'))),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_s('cancel', 'Cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, _framing),
                        child: Text(
                            _s('versePhotoFrameApply', 'Use this framing'))),
                  ]),
            ]),
          ),
        ),
      );
}

class _FrameGuide extends CustomPainter {
  const _FrameGuide();
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    stroke.color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
        stroke);
    stroke.color = Colors.white.withValues(alpha: 0.7);
    for (var n = 1; n <= 2; n++) {
      canvas.drawLine(Offset(size.width * n / 3, 0),
          Offset(size.width * n / 3, size.height), stroke);
      canvas.drawLine(Offset(0, size.height * n / 3),
          Offset(size.width, size.height * n / 3), stroke);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(8)),
        stroke);
  }

  @override
  bool shouldRepaint(_FrameGuide oldDelegate) => false;
}

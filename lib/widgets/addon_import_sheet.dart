/// The import flow, one bottom sheet, four stages, cancellable at every one:
///
///   1. **Reading** — the file is parsed; nothing is stored. Cancel leaves
///      nothing behind.
///   2. **What we found** — the reader sees what the file is, names it, and
///      ticks the licence confirmation. Import stays DISABLED until they do:
///      a required checkbox, never pre-ticked, never an OK button.
///   3. **Saving**.
///   4. **The report** — what was kept and, never silently, what was not.
///
/// A refusal at any point is a plain sentence that says what to do next.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:yahwehs_words/constants/motion.dart' show AppMotion;
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/services/addons/addon_import_service.dart';
import 'package:yahwehs_words/utils/addons/addon_texts.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/font_catalog.dart' show kCjkFontFallback;

/// What the sheet resolves to.
class AddonImportSheetResult {
  const AddonImportSheetResult(this.entry, {this.readNow = false});
  final AddonEntry entry;
  final bool readNow;
}

Future<AddonImportSheetResult?> showAddonImportSheet(
  BuildContext context, {
  required String fileName,
  required Uint8List bytes,
  required String locale,
  String fontFamily = '',
}) {
  return showModalBottomSheet<AddonImportSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false, // a swipe must not silently abandon an import
    enableDrag: false,
    builder: (_) => _AddonImportSheet(
      fileName: fileName,
      bytes: bytes,
      locale: locale,
      fontFamily: fontFamily,
    ),
  );
}

enum _Stage { reading, found, saving, done, refused }

class _AddonImportSheet extends StatefulWidget {
  const _AddonImportSheet({
    required this.fileName,
    required this.bytes,
    required this.locale,
    required this.fontFamily,
  });

  final String fileName;
  final Uint8List bytes;
  final String locale;
  final String fontFamily;

  @override
  State<_AddonImportSheet> createState() => _AddonImportSheetState();
}

class _AddonImportSheetState extends State<_AddonImportSheet> {
  final CancelToken _cancel = CancelToken();
  final TextEditingController _name = TextEditingController();
  _Stage _stage = _Stage.reading;
  ParsedModule? _parsed;
  String _phase = 'addonAnalysing';
  int _done = 0;
  int _total = 0;
  bool _attested = false;
  ImportProblem? _problem;
  String? _detail;
  ImportProblem? _nameProblem;
  AddonEntry? _entry;

  String _t(String key, [Map<String, Object> v = const {}]) =>
      addonText(key, widget.locale, v);

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  @override
  void dispose() {
    _cancel.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    try {
      final parsed = await AddonImportService.analyse(
        widget.bytes,
        widget.fileName,
        cancel: _cancel,
        onProgress: (phase, done, total) {
          if (!mounted) return;
          setState(() {
            _phase = 'addonPhase_$phase';
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      _name.text = AddonImportService.suggestedLabel(parsed, widget.fileName);
      setState(() {
        _parsed = parsed;
        _stage = _Stage.found;
        _nameProblem = AddonImportService.checkLabel(_name.text);
      });
    } on ImportRefusal catch (e) {
      if (!mounted) return;
      if (e.problem == ImportProblem.cancelled) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _problem = e.problem;
        _detail = e.detail;
        _stage = _Stage.refused;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _problem = ImportProblem.corruptFile;
        _stage = _Stage.refused;
      });
    }
  }

  Future<void> _commit() async {
    final parsed = _parsed;
    if (parsed == null) return;
    setState(() => _stage = _Stage.saving);
    // Let the "Saving…" frame paint before the encode.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final r = await AddonImportService.commit(
      parsed: parsed,
      sourceBytes: widget.bytes,
      fileName: widget.fileName,
      label: _name.text,
      attested: _attested,
    );
    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _entry = r.entry;
        _stage = _Stage.done;
      });
      return;
    }
    setState(() {
      _problem = r.problem ??
          (r.outcome == ImportOutcome.unavailable
              ? ImportProblem.unsupportedLayout
              : ImportProblem.corruptFile);
      _detail = r.detail;
      _stage = _Stage.refused;
      if (r.outcome == ImportOutcome.couldNotStore) {
        _problem = null; // shown via its own key below
      }
      _storeFailed = r.outcome == ImportOutcome.couldNotStore;
      _unavailable = r.outcome == ImportOutcome.unavailable;
    });
  }

  bool _storeFailed = false;
  bool _unavailable = false;

  TextStyle get _body => TextStyle(
        fontFamily: widget.fontFamily.isEmpty ? null : widget.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: 14.5,
        height: 1.45,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + insets),
      child: SingleChildScrollView(
        child: AnimatedSize(
          duration: AppMotion.duration(context, AppMotion.standard),
          alignment: Alignment.topCenter,
          child: switch (_stage) {
            _Stage.reading => _reading(scheme),
            _Stage.found => _found(scheme),
            _Stage.saving => _saving(scheme),
            _Stage.done => _doneView(scheme),
            _Stage.refused => _refused(scheme),
          },
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _reading(ColorScheme scheme) {
    final value = _total > 0 ? (_done / _total).clamp(0.0, 1.0) : null;
    return Column(
      key: const ValueKey('addon.stage.reading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(_t('addonAnalysing')),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: value, minHeight: 6),
        ),
        const SizedBox(height: 10),
        Text(_t(_phase), style: _body.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('addon.cancel'),
            onPressed: () => _cancel.cancel(),
            child: Text(_t('addonCancel')),
          ),
        ),
      ],
    );
  }

  Widget _found(ColorScheme scheme) {
    final parsed = _parsed!;
    final formatName = _t('addonFormat_${parsed.format.name}');
    final canImport = _attested && _nameProblem == null;
    return Column(
      key: const ValueKey('addon.stage.found'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(_t('addonFoundTitle')),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            _t('addonFoundBody', {
              'format': formatName,
              'n': parsed.report.versesAccepted,
              'b': parsed.books.length,
            }),
            style: _body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('addon.name'),
          controller: _name,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: _t('addonNameLabel'),
            hintText: _t('addonNameHint'),
            counterText: '',
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            errorText: _nameProblem == null
                ? null
                : addonProblemText(_nameProblem!, widget.locale),
          ),
          onChanged: (v) => setState(
              () => _nameProblem = AddonImportService.checkLabel(v)),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('addon.attest'),
          value: _attested,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => _attested = v ?? false),
          title: Text(_t('addonLicenceAttest'),
              style: _body.copyWith(fontSize: 13.5)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const ValueKey('addon.cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('addonCancel')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('addon.import'),
              onPressed: canImport ? _commit : null,
              child: Text(_t('addonImportButton')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _saving(ColorScheme scheme) => Column(
        key: const ValueKey('addon.stage.saving'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(_t('addonStoring')),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
          const SizedBox(height: 24),
        ],
      );

  Widget _doneView(ColorScheme scheme) {
    final parsed = _parsed!;
    final lines = addonReportLines(parsed.report, parsed.meta, widget.locale,
        books: parsed.books.length);
    return Column(
      key: const ValueKey('addon.stage.done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(_t('addonDoneTitle')),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  i == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: i == 0 ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(lines[i], style: _body)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const ValueKey('addon.done'),
              onPressed: () =>
                  Navigator.of(context).pop(AddonImportSheetResult(_entry!)),
              child: Text(_t('addonDone')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('addon.readNow'),
              onPressed: () => Navigator.of(context)
                  .pop(AddonImportSheetResult(_entry!, readNow: true)),
              child: Text(_t('addonReadNow')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _refused(ColorScheme scheme) {
    final text = _storeFailed
        ? _t('addonProblem_couldNotStore')
        : _unavailable
            ? _t('addonProblem_unavailable')
            : addonProblemText(_problem ?? ImportProblem.corruptFile, widget.locale,
                detail: _detail);
    return Column(
      key: const ValueKey('addon.stage.refused'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(text, key: const ValueKey('addon.refusal'), style: _body)),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            key: const ValueKey('addon.close'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('addonClose')),
          ),
        ),
      ],
    );
  }
}

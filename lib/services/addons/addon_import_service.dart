/// Reading a file, showing the reader what it is, and — only if they agree —
/// keeping it.
///
/// Three steps, deliberately separate so the UI can put the reader between the
/// second and the third:
///
///   1. [analyse] — parse. Nothing is stored. Throws [ImportRefusal] with the
///      reason; reports progress; cancellable.
///   2. the reader sees what was found, names it, and ticks the licence box;
///   3. [commit] — encode, store, register.
///
/// A file that is refused, or a reader who cancels, leaves NOTHING behind.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:yahwehs_words/constants/bible_versions.dart'
    show versionInfoFor;
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/services/addons/addon_registry.dart';
import 'package:yahwehs_words/utils/addons/addon_payload.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/addons/parse_module.dart';

/// The ui-strings key of the sentence the reader agrees to. Stored with the
/// add-on, so a later change of wording does not retroactively claim they
/// agreed to the new one.
const String kLicenceAttestationKey = 'addonLicenceAttest';

enum ImportOutcome { imported, couldNotStore, unavailable, rejected }

class AddonImportResult {
  const AddonImportResult(this.outcome, {this.problem, this.detail, this.entry});

  final ImportOutcome outcome;
  final ImportProblem? problem;
  final String? detail;
  final AddonEntry? entry;

  bool get ok => outcome == ImportOutcome.imported;
}

class AddonImportService {
  AddonImportService._();

  /// Parse [bytes]. Throws [ImportRefusal].
  static Future<ParsedModule> analyse(
    Uint8List bytes,
    String fileName, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
  }) =>
      parseModule(bytes, fileName, cancel: cancel, onProgress: onProgress);

  /// A sensible name to offer: the module's own title, else its abbreviation,
  /// else the file's name without its extensions.
  static String suggestedLabel(ParsedModule m, String fileName) {
    final t = m.meta.title.trim();
    if (t.isNotEmpty) return t.length > 60 ? t.substring(0, 60) : t;
    final a = m.meta.abbreviation.trim();
    if (a.isNotEmpty) return a;
    var base = fileName.split(RegExp(r'[\\/]')).last;
    for (final ext in const ['.bbl.mybible', '.sqlite3', '.mybible', '.ont', '.ot', '.nt', '.xml', '.json', '.csv']) {
      if (base.toLowerCase().endsWith(ext)) {
        base = base.substring(0, base.length - ext.length);
        break;
      }
    }
    return base.trim().isEmpty ? 'Imported Bible' : base.trim();
  }

  /// Why [label] cannot be used, or null.
  static ImportProblem? checkLabel(String label) {
    if (label.trim().isEmpty) return ImportProblem.nameEmpty;
    final code = addonCodeForLabel(label);
    if (versionInfoFor(code) != null || AddonRegistry.byId(code) != null) {
      return ImportProblem.nameTaken;
    }
    return null;
  }

  /// Encode, store and register. [attested] must be true: the licence
  /// confirmation is not a courtesy the UI may skip.
  static Future<AddonImportResult> commit({
    required ParsedModule parsed,
    required Uint8List sourceBytes,
    required String fileName,
    required String label,
    required bool attested,
    DateTime? now,
  }) async {
    if (!attested) {
      return const AddonImportResult(ImportOutcome.rejected,
          problem: ImportProblem.licenceNotAttested);
    }
    final bad = checkLabel(label);
    if (bad != null) {
      return AddonImportResult(ImportOutcome.rejected,
          problem: bad, detail: addonCodeForLabel(label));
    }
    if (parsed.verses.isEmpty) {
      return AddonImportResult(ImportOutcome.rejected,
          problem: parsed.report.booksDropped.isNotEmpty
              ? ImportProblem.noBooksInCanon
              : ImportProblem.noVerses);
    }

    final family = languageFamilyFor(parsed);
    final script = scriptForFamily(family);
    final AddonPayload payload;
    try {
      payload = encodeAddonPayload(parsed, script);
    } on ImportRefusal catch (e) {
      return AddonImportResult(ImportOutcome.rejected,
          problem: e.problem, detail: e.detail);
    }

    final entry = AddonEntry(
      id: addonCodeForLabel(label),
      kind: AddonKind.bible,
      format: parsed.format,
      label: label.trim(),
      script: script,
      family: family,
      books: payload.books.toList()..sort(),
      verseCount: payload.verseCount,
      payloadBytes: payload.bytes,
      sourceFileName: fileName.split(RegExp(r'[\\/]')).last,
      sourceHash: sha256.convert(sourceBytes).toString().substring(0, 16),
      importedAtMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      enabled: true,
      licenceAttestation: kLicenceAttestationKey,
      abbreviation: parsed.meta.abbreviation,
      declaredLanguage: parsed.meta.language,
      description: parsed.meta.description,
      rightToLeft: parsed.meta.rightToLeft,
      strongsPresent: parsed.meta.strongsPresent,
      versification: parsed.meta.versification,
    );

    switch (await AddonRegistry.install(entry, payload.json)) {
      case InstallOutcome.installed:
        return AddonImportResult(ImportOutcome.imported, entry: entry);
      case InstallOutcome.couldNotStore:
        return const AddonImportResult(ImportOutcome.couldNotStore);
      case InstallOutcome.unavailable:
        return const AddonImportResult(ImportOutcome.unavailable);
    }
  }
}

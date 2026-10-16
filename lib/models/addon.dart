/// One installed add-on, as the manifest remembers it.
///
/// The manifest is a few KB and is the ONLY thing read at boot: the verse
/// payloads (megabytes each) are read only when an edition is actually opened.
/// (Sword's first importer read every payload at boot to list labels, so three
/// imports could time the boot out and make the reader's edition disappear.)
library;

import 'package:flutter/foundation.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';

/// Bumped when [AddonEntry]'s JSON changes shape.
const int kAddonSchemaVersion = 1;

@immutable
class AddonEntry {
  const AddonEntry({
    required this.id,
    required this.kind,
    required this.format,
    required this.label,
    required this.script,
    required this.family,
    required this.books,
    required this.verseCount,
    required this.payloadBytes,
    required this.sourceFileName,
    required this.sourceHash,
    required this.importedAtMs,
    required this.enabled,
    required this.licenceAttestation,
    this.abbreviation = '',
    this.declaredLanguage = '',
    this.description = '',
    this.rightToLeft = false,
    this.strongsPresent = false,
    this.versification = AddonVersification.unknown,
    this.legacy = false,
    this.schemaVersion = kAddonSchemaVersion,
  });

  /// The edition's code in the version catalog — always `user-…`.
  final String id;
  final AddonKind kind;
  final AddonFormat? format;

  /// What the reader called it.
  final String label;

  /// `en` | `zh-Hans` | `zh-Hant`: the script `Verse.book` is written in.
  final String script;

  /// `en` | `zh-Hans` | `zh-Hant` | `other`: the picker tab.
  final String family;

  /// 1-based canon indexes present.
  final List<int> books;
  final int verseCount;
  final int payloadBytes;
  final String sourceFileName;

  /// First 16 hex characters of the original file's SHA-256: provenance, so
  /// "which file was this" has an answer without keeping the file.
  final String sourceHash;
  final int importedAtMs;
  final bool enabled;

  /// The ui-strings KEY of the sentence the reader agreed to on import, so a
  /// later change of wording does not retroactively claim they agreed to it.
  final String licenceAttestation;

  final String abbreviation;

  /// The language tag as the FILE wrote it.
  final String declaredLanguage;

  /// The publisher's own words, shown verbatim.
  final String description;
  final bool rightToLeft;

  /// The file carries Strong's numbers. They are not shown by this app.
  final bool strongsPresent;
  final AddonVersification versification;

  /// Imported by an earlier version of the app, before the manifest existed:
  /// counts are reconstructed, not recorded.
  final bool legacy;
  final int schemaVersion;

  bool get coversOldTestament => books.any((b) => b <= 39);
  bool get coversNewTestament => books.any((b) => b >= 40);
  bool get isFullCanon => books.length == 66;

  AddonEntry copyWith({bool? enabled, String? label}) => AddonEntry(
        id: id,
        kind: kind,
        format: format,
        label: label ?? this.label,
        script: script,
        family: family,
        books: books,
        verseCount: verseCount,
        payloadBytes: payloadBytes,
        sourceFileName: sourceFileName,
        sourceHash: sourceHash,
        importedAtMs: importedAtMs,
        enabled: enabled ?? this.enabled,
        licenceAttestation: licenceAttestation,
        abbreviation: abbreviation,
        declaredLanguage: declaredLanguage,
        description: description,
        rightToLeft: rightToLeft,
        strongsPresent: strongsPresent,
        versification: versification,
        legacy: legacy,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'format': format?.name,
        'label': label,
        'script': script,
        'family': family,
        'books': books,
        'verseCount': verseCount,
        'payloadBytes': payloadBytes,
        'sourceFileName': sourceFileName,
        'sourceHash': sourceHash,
        'importedAtMs': importedAtMs,
        'enabled': enabled,
        'licenceAttestation': licenceAttestation,
        'abbreviation': abbreviation,
        'declaredLanguage': declaredLanguage,
        'description': description,
        'rightToLeft': rightToLeft,
        'strongsPresent': strongsPresent,
        'versification': versification.name,
        'legacy': legacy,
        'schemaVersion': schemaVersion,
      };

  /// Null — never an exception — for anything that is not a well-formed
  /// entry: a manifest written by a newer app, a truncated write, `{}`.
  static AddonEntry? tryFromJson(Object? j) {
    if (j is! Map) return null;
    try {
      final id = j['id'];
      final label = j['label'];
      final script = j['script'];
      final schema = j['schemaVersion'];
      if (id is! String || !id.startsWith('user-') || id.length > 80) return null;
      if (label is! String || label.trim().isEmpty) return null;
      if (script is! String || !const {'en', 'zh-Hans', 'zh-Hant'}.contains(script)) {
        return null;
      }
      if (schema is int && schema > kAddonSchemaVersion) return null;
      final books = j['books'];
      return AddonEntry(
        id: id,
        kind: AddonKind.values.asNameMap()[j['kind']] ?? AddonKind.bible,
        format: AddonFormat.values.asNameMap()[j['format']],
        label: label,
        script: script,
        family: (j['family'] is String &&
                const {'en', 'zh-Hans', 'zh-Hant', 'other'}.contains(j['family']))
            ? j['family'] as String
            : script,
        books: books is List
            ? [for (final b in books) if (b is int && b >= 1 && b <= 66) b]
            : const [],
        verseCount: j['verseCount'] is int ? j['verseCount'] as int : 0,
        payloadBytes: j['payloadBytes'] is int ? j['payloadBytes'] as int : 0,
        sourceFileName: j['sourceFileName'] is String ? j['sourceFileName'] as String : '',
        sourceHash: j['sourceHash'] is String ? j['sourceHash'] as String : '',
        importedAtMs: j['importedAtMs'] is int ? j['importedAtMs'] as int : 0,
        enabled: j['enabled'] is bool ? j['enabled'] as bool : true,
        licenceAttestation:
            j['licenceAttestation'] is String ? j['licenceAttestation'] as String : '',
        abbreviation: j['abbreviation'] is String ? j['abbreviation'] as String : '',
        declaredLanguage:
            j['declaredLanguage'] is String ? j['declaredLanguage'] as String : '',
        description: j['description'] is String ? j['description'] as String : '',
        rightToLeft: j['rightToLeft'] == true,
        strongsPresent: j['strongsPresent'] == true,
        versification:
            AddonVersification.values.asNameMap()[j['versification']] ??
                AddonVersification.unknown,
        legacy: j['legacy'] == true,
        schemaVersion: schema is int ? schema : 1,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The whole manifest: every add-on the device holds.
@immutable
class AddonManifest {
  const AddonManifest(this.entries, {this.schemaVersion = kAddonSchemaVersion});

  final List<AddonEntry> entries;
  final int schemaVersion;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'entries': [for (final e in entries) e.toJson()],
      };

  /// An unreadable manifest is an EMPTY one, never an exception: the app
  /// boots and the reader simply has no add-ons (their payloads are still
  /// there; re-importing is possible and nothing is half-installed).
  static AddonManifest fromJson(Object? j) {
    if (j is! Map) return const AddonManifest([]);
    final list = j['entries'];
    if (list is! List) return const AddonManifest([]);
    final seen = <String>{};
    final out = <AddonEntry>[];
    for (final raw in list) {
      final e = AddonEntry.tryFromJson(raw);
      if (e != null && seen.add(e.id)) out.add(e);
    }
    return AddonManifest(out);
  }
}

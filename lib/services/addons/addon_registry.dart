/// The runtime catalog of add-ons: what is installed, which are on, and the
/// keeper of the plain maps in `bible_versions.dart` that the rest of the app
/// reads.
///
/// Nothing here uploads, shares or syncs, and nothing can be made to — the
/// store has no network and this has no client.
///
/// ## Boot
///
/// [restore] runs once at boot BEFORE `MainProvider.restoreState`, bounded and
/// silent on failure. The order is load-bearing: restoreState validates the
/// remembered edition against the catalog, and a catalog that has not been
/// filled yet would call an imported edition "unknown", swap it for a bundled
/// one, and — in the migration branch — remember the swap. (This happened once
/// in Sword's first importer; the comment in its `main.dart` says so.)
library;

import 'package:flutter/foundation.dart';
import 'package:yahwehs_words/constants/bible_versions.dart';
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/services/addons/addon_store.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';

/// What installing did.
enum InstallOutcome {
  installed,

  /// The file was fine; the device would not keep it (no space, private
  /// browsing…). Distinct from every parse failure: the reader's next move is
  /// different, and nothing is wrong with their file.
  couldNotStore,

  /// No store at all on this build.
  unavailable,
}

class AddonRegistry {
  AddonRegistry._();

  /// Bumped on every change to the catalog, so a screen that lists add-ons —
  /// or the version picker — can rebuild. The catalog maps are plain maps;
  /// without this a new import would not appear until the page was reopened.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static List<AddonEntry> _entries = const [];

  /// Every add-on, enabled or not.
  static List<AddonEntry> get all => List.unmodifiable(_entries);

  static List<AddonEntry> get enabledBibles => [
        for (final e in _entries)
          if (e.enabled && e.kind == AddonKind.bible) e
      ];

  static AddonEntry? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Put every installed add-on back in the catalog. Silent on failure BY
  /// DESIGN: a reader whose browser will not open IndexedDB should get the app,
  /// not an error about a feature they may never have used.
  static Future<void> restore() async {
    try {
      final backend = AddonStore.backend;
      if (!backend.isAvailable) {
        _entries = const [];
        _publish();
        return;
      }
      var manifest = await backend.readManifest();
      // Carry over records written before the manifest existed (Sword's first
      // importer, web only).
      final legacy = await backend.legacyRecords();
      final known = {for (final e in manifest.entries) e.id};
      final migrated = <AddonEntry>[];
      for (final l in legacy.entries) {
        if (known.contains(l.key)) continue;
        final e = await _entryFromLegacy(backend, l.key, l.value.label, l.value.script);
        if (e != null) migrated.add(e);
      }
      if (migrated.isNotEmpty) {
        manifest = AddonManifest([...manifest.entries, ...migrated]);
        await backend.writeManifest(manifest);
      }
      _entries = manifest.entries;
      _publish();
    } catch (e, st) {
      debugPrint('AddonRegistry.restore failed: $e\n$st');
      _entries = const [];
      _publish();
    }
  }

  /// A manifest entry for a record the first importer wrote. Its counts are
  /// reconstructed by a cheap scan of the stored JSON, not recorded.
  static Future<AddonEntry?> _entryFromLegacy(
    AddonStoreBackend backend,
    String id,
    String label,
    String script,
  ) async {
    final payload = await backend.readPayload(id);
    if (payload == null) return null;
    final verses = RegExp(r'"verse":').allMatches(payload).length;
    final names = <String>{
      for (final m in RegExp(r'"book":"([^"]+)"').allMatches(payload)) m[1]!,
    };
    return AddonEntry(
      id: id,
      kind: AddonKind.bible,
      format: AddonFormat.appJson,
      label: label,
      script: script == 'zh-Hans' ? 'zh-Hans' : 'en',
      family: script == 'zh-Hans' ? 'zh-Hans' : 'en',
      books: const [],
      verseCount: verses,
      payloadBytes: payload.length,
      sourceFileName: '',
      sourceHash: '',
      importedAtMs: 0,
      enabled: true,
      licenceAttestation: 'aboutLicenseUserSupplied',
      legacy: true,
      description: '${names.length}',
    );
  }

  /// Install [entry] with its [payload]. Two-phase: payload first, manifest
  /// second, and a failure of either leaves nothing the app would show.
  static Future<InstallOutcome> install(AddonEntry entry, String payload) async {
    final backend = AddonStore.backend;
    if (!backend.isAvailable) return InstallOutcome.unavailable;
    if (!await backend.writePayload(entry.id, payload)) {
      return InstallOutcome.couldNotStore;
    }
    final next = AddonManifest([
      for (final e in _entries)
        if (e.id != entry.id) e,
      entry,
    ]);
    if (!await backend.writeManifest(next)) {
      await backend.deletePayload(entry.id);
      return InstallOutcome.couldNotStore;
    }
    _entries = next.entries;
    _publish();
    return InstallOutcome.installed;
  }

  /// Turn an add-on on or off. Off removes it from the picker and from every
  /// resolution path (the same machinery that already sends a stale `nasb`
  /// preference to the KJV); its text stays on the device.
  static Future<bool> setEnabled(String id, bool on) async {
    final cur = byId(id);
    if (cur == null || cur.enabled == on) return true;
    final next = AddonManifest([
      for (final e in _entries) e.id == id ? e.copyWith(enabled: on) : e,
    ]);
    if (!await AddonStore.backend.writeManifest(next)) return false;
    _entries = next.entries;
    _publish();
    return true;
  }

  /// Remove an add-on from the device. The catalog entry goes first: an
  /// edition still on disk but out of the picker is invisible clutter, while
  /// one in the picker with no text behind it is a version that fails to open.
  static Future<void> forget(String id) async {
    final next = AddonManifest([
      for (final e in _entries)
        if (e.id != id) e,
    ]);
    _entries = next.entries;
    _publish();
    await AddonStore.backend.writeManifest(next);
    await AddonStore.backend.deletePayload(id);
  }

  /// The stored verse JSON for [id], or null.
  static Future<String?> readPayload(String id) =>
      AddonStore.backend.readPayload(id);

  static Future<int> bytesUsed() => AddonStore.backend.bytesUsed();

  /// Test hook: forget everything in memory (not in the store).
  @visibleForTesting
  static void resetForTest() {
    _entries = const [];
    _publish();
  }

  /// Rebuild the plain maps `bible_versions.dart` reads, and tell listeners.
  static void _publish() {
    importedVersionLabels.clear();
    importedVersionScripts.clear();
    importedVersionFamilies.clear();
    importedVersionCoverage.clear();
    for (final e in enabledBibles) {
      importedVersionLabels[e.id] = e.label;
      importedVersionScripts[e.id] = e.script;
      importedVersionFamilies[e.id] = e.family;
      importedVersionCoverage[e.id] = e.legacy
          ? (ot: true, nt: true)
          : (ot: e.coversOldTestament, nt: e.coversNewTestament);
    }
    changes.value++;
  }
}

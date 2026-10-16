/// Where add-ons live — the contract, and an in-memory implementation.
///
/// **On this device and nowhere else.** No upload, no share, no sync, and no
/// code path in any backend that could add one: nothing here has a network
/// client. That is the feature's own condition — it is what keeps an importer
/// from becoming a distribution channel for somebody else's text.
///
/// Two kinds of record, deliberately separate:
///   * the MANIFEST — one small JSON document listing every add-on. The only
///     thing read at boot;
///   * a PAYLOAD per add-on — the verse JSON, megabytes. Read only when that
///     edition is opened.
///
/// An install is two-phase: payload first, manifest second. The manifest is
/// the commit point, so a crash or a full disk between the two leaves nothing
/// the app would show — and [AddonRegistry.restore] sweeps up the orphan.
library;

import 'package:yahwehs_words/models/addon.dart';

abstract class AddonStoreBackend {
  /// False when the platform cannot keep anything (a browser in private mode
  /// that refuses IndexedDB, say).
  bool get isAvailable;

  /// The manifest, or an EMPTY one when there is none or it is unreadable.
  /// Never throws.
  Future<AddonManifest> readManifest();

  /// Atomically replace the manifest. False on any failure.
  Future<bool> writeManifest(AddonManifest manifest);

  /// Store [json] under [id]. False on any failure (quota, private mode…);
  /// never true on a guess.
  Future<bool> writePayload(String id, String json);

  Future<String?> readPayload(String id);

  Future<void> deletePayload(String id);

  /// Every payload id present, manifest or not.
  Future<List<String>> listPayloadIds();

  /// Bytes the payloads occupy, approximately.
  Future<int> bytesUsed();

  /// Records written by an earlier version of the app, before the manifest
  /// existed: id → `(label, script)`. Only the web store (Sword's first
  /// importer) ever has any.
  Future<Map<String, ({String label, String script})>> legacyRecords();
}

/// The id rule every backend enforces before touching a file name or key.
final RegExp kAddonIdPattern = RegExp(r'^user-[a-z0-9-]{1,40}$');

/// In memory. Used by the test suite, and as the fallback when a platform's
/// real store cannot be opened.
class InMemoryAddonBackend implements AddonStoreBackend {
  InMemoryAddonBackend({this.failWrites = false, this.available = true});

  /// Make every write fail, as a full disk or a refusing browser would.
  bool failWrites;
  final bool available;

  AddonManifest _manifest = const AddonManifest([]);
  final Map<String, String> payloads = {};
  final Map<String, ({String label, String script})> legacy = {};

  @override
  bool get isAvailable => available;

  @override
  Future<AddonManifest> readManifest() async => _manifest;

  @override
  Future<bool> writeManifest(AddonManifest manifest) async {
    if (failWrites) return false;
    _manifest = manifest;
    return true;
  }

  @override
  Future<bool> writePayload(String id, String json) async {
    if (failWrites || !kAddonIdPattern.hasMatch(id)) return false;
    payloads[id] = json;
    return true;
  }

  @override
  Future<String?> readPayload(String id) async => payloads[id];

  @override
  Future<void> deletePayload(String id) async {
    payloads.remove(id);
    legacy.remove(id);
  }

  @override
  Future<List<String>> listPayloadIds() async => payloads.keys.toList();

  @override
  Future<int> bytesUsed() async =>
      payloads.values.fold<int>(0, (a, b) => a + b.length);

  @override
  Future<Map<String, ({String label, String script})>> legacyRecords() async =>
      Map.of(legacy);
}

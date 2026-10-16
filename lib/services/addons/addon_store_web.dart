/// The web add-on store: IndexedDB.
///
/// Why not `shared_preferences`: that is localStorage, ~5 MB shared with every
/// other preference. A New Testament fits and a Bible does not, and a store
/// that failed at the quota after the reader had waited through a parse would
/// be worse than none. IndexedDB has no such ceiling and is reached through
/// `package:web`, which the app already depends on.
///
/// Two object stores in one database:
///   * `versions` — one record per add-on, key = code, value `{json}`;
///   * `manifest` — one record, key `manifest`, value the manifest as a string.
///
/// Records in `versions` that carry a `label` were written by the first
/// importer (before the manifest existed); [legacyRecords] reports them so the
/// registry can carry them over.
///
/// Every operation resolves through a Completer on the request's own
/// `onsuccess` / `onerror`, and every one can fail — private mode may refuse
/// IndexedDB outright — so the API answers null/false rather than throwing.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/services/addons/addon_store_backend.dart';
import 'package:yahwehs_words/services/addons/addon_store_config.dart';

const String _kPayloads = 'versions';
const String _kManifestStore = 'manifest';
const String _kManifestKey = 'manifest';
const int _kDbVersion = 2;

AddonStoreBackend createPlatformAddonBackend() => _WebBackend();

class _WebBackend implements AddonStoreBackend {
  Future<web.IDBDatabase?> _open() {
    final done = Completer<web.IDBDatabase?>();
    try {
      final req = web.window.indexedDB.open(kAddonDbName, _kDbVersion);
      req.onupgradeneeded = (web.Event _) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_kPayloads)) {
          db.createObjectStore(_kPayloads);
        }
        if (!db.objectStoreNames.contains(_kManifestStore)) {
          db.createObjectStore(_kManifestStore);
        }
      }.toJS;
      req.onsuccess = (web.Event _) {
        if (!done.isCompleted) done.complete(req.result as web.IDBDatabase);
      }.toJS;
      req.onerror = (web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }.toJS;
      req.onblocked = (web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }.toJS;
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
    return done.future;
  }

  Future<T?> _run<T>(
    String storeName,
    String mode,
    void Function(web.IDBObjectStore store, Completer<T?> done) body,
  ) async {
    final db = await _open();
    if (db == null) return null;
    final done = Completer<T?>();
    try {
      final tx = db.transaction(storeName.toJS, mode);
      tx.onabort = (web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }.toJS;
      body(tx.objectStore(storeName), done);
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
    final r = await done.future;
    db.close();
    return r;
  }

  String? _stringField(JSObject obj, String name) {
    final f = obj.getProperty(name.toJS);
    return f == null || f.isUndefinedOrNull ? null : (f as JSString).toDart;
  }

  @override
  bool get isAvailable => true;

  @override
  Future<AddonManifest> readManifest() async {
    final raw = await _run<String>(_kManifestStore, 'readonly', (store, done) {
      final req = store.get(_kManifestKey.toJS);
      req.onsuccess = (web.Event _) {
        final v = req.result;
        done.complete(v == null || v.isUndefinedOrNull ? null : (v as JSString).toDart);
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(null);
      }.toJS;
    });
    if (raw == null) return const AddonManifest([]);
    try {
      return AddonManifest.fromJson(json.decode(raw));
    } catch (_) {
      return const AddonManifest([]);
    }
  }

  @override
  Future<bool> writeManifest(AddonManifest manifest) async {
    final ok = await _run<bool>(_kManifestStore, 'readwrite', (store, done) {
      final req = store.put(json.encode(manifest.toJson()).toJS, _kManifestKey.toJS);
      req.onsuccess = (web.Event _) {
        done.complete(true);
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(false);
      }.toJS;
    });
    return ok ?? false;
  }

  @override
  Future<bool> writePayload(String id, String payload) async {
    if (!kAddonIdPattern.hasMatch(id)) return false;
    final ok = await _run<bool>(_kPayloads, 'readwrite', (store, done) {
      final rec = JSObject()..setProperty('json'.toJS, payload.toJS);
      final req = store.put(rec, id.toJS);
      req.onsuccess = (web.Event _) {
        done.complete(true);
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(false);
      }.toJS;
    });
    return ok ?? false;
  }

  @override
  Future<String?> readPayload(String id) async {
    if (!kAddonIdPattern.hasMatch(id)) return null;
    return _run<String>(_kPayloads, 'readonly', (store, done) {
      final req = store.get(id.toJS);
      req.onsuccess = (web.Event _) {
        final v = req.result;
        if (v == null || v.isUndefinedOrNull) {
          done.complete(null);
          return;
        }
        done.complete(_stringField(v as JSObject, 'json'));
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(null);
      }.toJS;
    });
  }

  @override
  Future<void> deletePayload(String id) async {
    if (!kAddonIdPattern.hasMatch(id)) return;
    await _run<bool>(_kPayloads, 'readwrite', (store, done) {
      final req = store.delete(id.toJS);
      req.onsuccess = (web.Event _) {
        done.complete(true);
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(false);
      }.toJS;
    });
  }

  @override
  Future<List<String>> listPayloadIds() async {
    final out = await _run<List<String>>(_kPayloads, 'readonly', (store, done) {
      final req = store.getAllKeys();
      req.onsuccess = (web.Event _) {
        final keys = (req.result as JSArray).toDart;
        final ids = <String>[];
        for (final k in keys) {
          final s = k.dartify();
          if (s is String && kAddonIdPattern.hasMatch(s)) ids.add(s);
        }
        done.complete(ids);
      }.toJS;
      req.onerror = (web.Event _) {
        done.complete(null);
      }.toJS;
    });
    return out ?? const [];
  }

  @override
  Future<int> bytesUsed() async {
    // Sum of payload string lengths, read one at a time so no more than one
    // payload is in memory at once.
    var n = 0;
    for (final id in await listPayloadIds()) {
      final p = await readPayload(id);
      if (p != null) n += p.length;
    }
    return n;
  }

  @override
  Future<Map<String, ({String label, String script})>> legacyRecords() async {
    final out = <String, ({String label, String script})>{};
    for (final id in await listPayloadIds()) {
      final rec = await _run<({String label, String script})>(_kPayloads, 'readonly',
          (store, done) {
        final req = store.get(id.toJS);
        req.onsuccess = (web.Event _) {
          final v = req.result;
          if (v == null || v.isUndefinedOrNull) {
            done.complete(null);
            return;
          }
          final o = v as JSObject;
          final label = _stringField(o, 'label');
          if (label == null) {
            done.complete(null); // a new-style record: no label
            return;
          }
          done.complete((label: label, script: _stringField(o, 'script') ?? 'en'));
        }.toJS;
        req.onerror = (web.Event _) {
          done.complete(null);
        }.toJS;
      });
      if (rec != null) out[id] = rec;
    }
    return out;
  }
}

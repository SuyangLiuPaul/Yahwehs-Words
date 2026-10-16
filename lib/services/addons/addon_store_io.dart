/// The native add-on store: plain files under the app-support directory.
///
/// App-support rather than Documents on purpose: Documents is shown in the iOS
/// Files app and goes into iCloud backup — which would be an upload, by Apple,
/// of somebody else's text. App-support is neither. The Add-ons page's own
/// Remove button is the reader's way to delete.
///
/// Every write is a staging file followed by a rename: a rename on one
/// filesystem is atomic, so a reader of the file sees the old content or the
/// new, never half of either.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:yahwehs_words/models/addon.dart';
import 'package:yahwehs_words/services/addons/addon_store_backend.dart';
import 'package:yahwehs_words/services/addons/addon_store_config.dart';

AddonStoreBackend createPlatformAddonBackend() => _IoBackend();

class _IoBackend implements AddonStoreBackend {
  Directory? _dir;

  Future<Directory?> _root() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final d = Directory('${base.path}${Platform.pathSeparator}$kAddonDirName');
      await d.create(recursive: true);
      return _dir = d;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _file(String name) async {
    final d = await _root();
    return d == null ? null : File('${d.path}${Platform.pathSeparator}$name');
  }

  Future<bool> _atomicWrite(String name, String content) async {
    try {
      final f = await _file(name);
      if (f == null) return false;
      final staging = File('${f.path}.staging');
      await staging.writeAsString(content, flush: true);
      await staging.rename(f.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isAvailable => true;

  @override
  Future<AddonManifest> readManifest() async {
    try {
      final f = await _file('manifest.json');
      if (f == null || !await f.exists()) return const AddonManifest([]);
      return AddonManifest.fromJson(json.decode(await f.readAsString()));
    } catch (_) {
      return const AddonManifest([]);
    }
  }

  @override
  Future<bool> writeManifest(AddonManifest manifest) =>
      _atomicWrite('manifest.json', json.encode(manifest.toJson()));

  @override
  Future<bool> writePayload(String id, String payload) async {
    if (!kAddonIdPattern.hasMatch(id)) return false;
    return _atomicWrite('$id.json', payload);
  }

  @override
  Future<String?> readPayload(String id) async {
    if (!kAddonIdPattern.hasMatch(id)) return null;
    try {
      final f = await _file('$id.json');
      if (f == null || !await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deletePayload(String id) async {
    if (!kAddonIdPattern.hasMatch(id)) return;
    try {
      final f = await _file('$id.json');
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<List<String>> listPayloadIds() async {
    try {
      final d = await _root();
      if (d == null) return const [];
      final out = <String>[];
      await for (final e in d.list()) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.endsWith('.json') && name != 'manifest.json') {
          final id = name.substring(0, name.length - 5);
          if (kAddonIdPattern.hasMatch(id)) out.add(id);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<int> bytesUsed() async {
    try {
      final d = await _root();
      if (d == null) return 0;
      var n = 0;
      await for (final e in d.list()) {
        if (e is File) n += await e.length();
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<Map<String, ({String label, String script})>> legacyRecords() async =>
      const {};
}

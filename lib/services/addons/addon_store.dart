/// The add-on store's front door: the platform backend by default, swappable
/// for tests.
///
/// Split by the same conditional-export pattern the rest of the app uses
/// (`fetch_helper.dart`, `offline_audio_storage.dart`): `dart:io` on native,
/// IndexedDB on the web.
library;

import 'package:yahwehs_words/services/addons/addon_store_backend.dart';
import 'package:yahwehs_words/services/addons/addon_store_io.dart'
    if (dart.library.js_interop) 'package:yahwehs_words/services/addons/addon_store_web.dart'
    as platform;

export 'package:yahwehs_words/services/addons/addon_store_backend.dart';

class AddonStore {
  AddonStore._();

  static AddonStoreBackend? _override;
  static AddonStoreBackend? _platform;

  /// The backend in use. Tests install an [InMemoryAddonBackend] here.
  static AddonStoreBackend get backend =>
      _override ?? (_platform ??= platform.createPlatformAddonBackend());

  static set backend(AddonStoreBackend? b) => _override = b;
}

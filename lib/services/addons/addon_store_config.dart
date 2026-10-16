/// The one place the two apps differ in how they store add-ons.
///
/// Words never had imported editions, so its IndexedDB database is new.
/// Sword's first importer wrote to `seeksparks_versions`, and readers already
/// have Bibles in it; the add-on store opens the SAME database (version 2, which
/// only adds the manifest) so those imports survive the upgrade.
library;

/// IndexedDB database name (web only).
const String kAddonDbName = 'yahwehs_words_addons';

/// Folder name under the app-support directory (native only).
const String kAddonDirName = 'addons';

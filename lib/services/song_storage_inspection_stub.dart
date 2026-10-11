Future<Map<String, dynamic>> inspectSongDownloadStorage() async =>
    {'supported': false, 'reason': 'browser_storage_only'};

Future<bool> recheckSongDownloadStorage() async => false;

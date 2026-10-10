/// Files from iOS/Android/macOS, Windows drive letters and UNC shares.
bool isLocalAudioPath(String source) =>
    source.startsWith('/') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source) ||
    source.startsWith(r'\\');

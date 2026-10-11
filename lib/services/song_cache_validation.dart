import 'offline_audio_types.dart';

/// Pure classification used by startup and the read-only browser inspector.
String classifySongCacheBody(
    int expectedBytes, int actualBytes, List<int> prefix) {
  if (actualBytes == 0) return 'empty_body';
  if (expectedBytes > 0 && actualBytes != expectedBytes) return 'size_mismatch';
  if (!validAudioPrefix(prefix)) return 'invalid_prefix';
  return 'valid';
}

/// Reports never include URL credentials, fragments or query values.
String diagnosticCacheUrl(String value, Uri base) {
  try {
    final uri = base.resolve(value);
    return Uri(
            scheme: uri.scheme,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
            path: uri.path)
        .toString();
  } catch (_) {
    return '[invalid URL]';
  }
}

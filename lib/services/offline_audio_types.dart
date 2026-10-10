import 'dart:async';

class AudioDownloadItem {
  const AudioDownloadItem(
      {required this.id,
      required this.title,
      required this.url,
      required this.sermonId,
      this.expectedBytes = 0});
  final String id, title, url, sermonId;
  final int expectedBytes;
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'sermonId': sermonId,
        'expectedBytes': expectedBytes
      };
  factory AudioDownloadItem.fromJson(Map<String, dynamic> j) =>
      AudioDownloadItem(
          id: j['id'] as String,
          title: j['title'] as String,
          url: j['url'] as String,
          sermonId: j['sermonId'] as String,
          expectedBytes: (j['expectedBytes'] as num?)?.toInt() ?? 0);
}

class AudioDownloadRecord {
  const AudioDownloadRecord(this.item, this.bytes);
  final AudioDownloadItem item;
  final int bytes;
  Map<String, dynamic> toJson() => {'item': item.toJson(), 'bytes': bytes};
  factory AudioDownloadRecord.fromJson(Map<String, dynamic> j) =>
      AudioDownloadRecord(
          AudioDownloadItem.fromJson(
              (j['item'] as Map).cast<String, dynamic>()),
          (j['bytes'] as num).toInt());
}

enum AudioDownloadState { queued, downloading, downloaded, failed }

class AudioDownloadStatus {
  const AudioDownloadStatus(this.state,
      {this.received = 0, this.total = 0, this.error});
  final AudioDownloadState state;
  final int received, total;
  final String? error;
  double? get progress => total > 0 ? (received / total).clamp(0, 1) : null;
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadCancellation {
  bool cancelled = false;
  void Function()? abort;
  void cancel() {
    cancelled = true;
    abort?.call();
  }

  void check() {
    if (cancelled) throw const DownloadCancelled();
  }
}

abstract interface class OfflineAudioStorage {
  bool get supported;
  Future<void> init();
  Future<bool> contains(String id);
  String? sourceFor(String id);
  Future<int> download(
      AudioDownloadItem item,
      DownloadCancellation cancellation,
      void Function(int received, int total) progress);
  Future<void> remove(String id);
}

/// Reject HTTP-200 error pages before they can become a green download.
bool validAudioPrefix(List<int> prefix) {
  if (prefix.length < 3) return false;
  final text = String.fromCharCodes(prefix.take(64)).trimLeft().toLowerCase();
  return !text.startsWith('<') &&
      !text.startsWith('{') &&
      !text.startsWith('[');
}

String mediaProxyPath(String url) {
  const prefixes = {
    'https://www.christiandiscipleschurch.org/': '/song-media/cdc/',
    'https://fydt.org/': '/song-media/fydt/',
    'https://fuyindiantai.org/': '/song-media/fydt/',
    'https://cahayapengharapan.org/': '/song-media/cahaya/',
    'https://cgdc.hk/': '/song-media/cgdc/'
  };
  for (final p in prefixes.entries) {
    if (url.startsWith(p.key)) return p.value + url.substring(p.key.length);
  }
  return url;
}

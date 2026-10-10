import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'offline_audio_types.dart';

class PlatformOfflineAudioStorage implements OfflineAudioStorage {
  PlatformOfflineAudioStorage(
      {Future<Directory> Function()? directory,
      http.Client Function()? clientFactory,
      this.directoryName = "sermon_audio",
      this.fileName})
      : _directory = directory ?? getApplicationSupportDirectory,
        _clientFactory = clientFactory ?? http.Client.new;
  final Future<Directory> Function() _directory;
  final http.Client Function() _clientFactory;
  final String directoryName;
  final String? fileName;
  Directory? _dir;
  @override
  bool get supported => true;
  @override
  Future<void> init() async {
    _dir ??= Directory('${(await _directory()).path}/$directoryName');
    await _dir!.create(recursive: true);
  }

  String _path(String id) =>
      '${_dir!.path}/${fileName ?? '${sha256.convert(utf8.encode(id))}.mp3'}';
  @override
  Future<bool> contains(String id) async {
    await init();
    final f = File(_path(id));
    return await f.exists() && await f.length() > 0;
  }

  @override
  String? sourceFor(String id) => _dir == null ? null : _path(id);
  @override
  Future<void> remove(String id) async {
    await init();
    final f = File(_path(id));
    if (await f.exists()) await f.delete();
  }

  @override
  Future<int> download(AudioDownloadItem item, DownloadCancellation token,
      void Function(int, int) progress) async {
    await init();
    final path = _path(item.id);
    final proxy = mediaProxyPath(item.url);
    final candidates = [
      item.url,
      if (proxy.startsWith('/')) 'https://yahwehword.com$proxy'
    ];
    Object? failure;
    for (final url in candidates) {
      token.check();
      final client = _clientFactory();
      token.abort = client.close;
      final partial = File('$path.part');
      try {
        final res = await client
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode}');
        }
        final total = res.contentLength ?? 0;
        var bytes = 0;
        final prefix = <int>[];
        final sink = partial.openWrite();
        // Listen for disk-full/write errors immediately, including before close.
        Object? writeError;
        final done = sink.done.then<void>((_) {}, onError: (Object e) {
          writeError = e;
        });
        try {
          await for (final chunk
              in res.stream.timeout(const Duration(seconds: 30))) {
            token.check();
            if (writeError != null) throw writeError!;
            if (prefix.length < 64) {
              prefix.addAll(chunk.take(64 - prefix.length));
            }
            sink.add(chunk);
            bytes += chunk.length;
            progress(bytes, total);
          }
          await sink.flush();
        } finally {
          await sink.close();
          await done;
        }
        if (writeError != null) throw writeError!;
        token.check();
        if (bytes == 0 || !validAudioPrefix(prefix)) {
          throw const FormatException('Not an audio file');
        }
        if (total > 0 && bytes != total) {
          throw const FormatException('Incomplete download');
        }
        await partial.rename(path);
        token.check();
        return bytes;
      } on DownloadCancelled {
        rethrow;
      } on FileSystemException {
        rethrow;
      } catch (e) {
        failure = e;
        token.check();
      } finally {
        client.close();
        token.abort = null;
        if (await partial.exists()) await partial.delete();
      }
    }
    throw StateError('Download failed: $failure');
  }
}

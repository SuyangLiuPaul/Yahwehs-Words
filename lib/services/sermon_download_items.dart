import 'sermon_audio_service.dart';
import 'offline_audio_types.dart';

Future<List<AudioDownloadItem>> sermonDownloadItems(
    String id, String title) async {
  final audio = SermonAudioService.instance;
  await audio.load();
  return [
    for (final part in audio.partsOf(id))
      AudioDownloadItem(
          id: '$id:${part.part}',
          title: '$title · ${part.part}',
          url: SermonAudioService.urlFor(part),
          sermonId: id,
          expectedBytes: part.bytes)
  ];
}

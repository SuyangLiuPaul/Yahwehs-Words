import 'package:flutter/material.dart';
import '../constants/ui_strings.dart';
import '../models/song_queue.dart';

/// Recording choices for the current song. Queue-wide filtering belongs
/// in playlist creation, where dropping songs is an explicit choice.
class SongMixPicker extends StatelessWidget {
  final SongQueue queue;
  final String locale;
  final bool loading;
  final ValueChanged<TrackPreference> onSelected;
  const SongMixPicker(
      {super.key,
      required this.queue,
      required this.locale,
      required this.onSelected,
      this.loading = false});

  @override
  Widget build(BuildContext context) {
    final current = switch (queue.current?.kind) {
      'instrumental' => TrackPreference.instrumental,
      'accompaniment' => TrackPreference.accompaniment,
      _ => TrackPreference.vocal,
    };
    final options = <(TrackPreference, IconData, String)>[
      (TrackPreference.vocal, Icons.mic_rounded, 'songsTrackVocal'),
      (
        TrackPreference.accompaniment,
        Icons.queue_music_rounded,
        'songsTrackAccompaniment'
      ),
      (
        TrackPreference.instrumental,
        Icons.piano_rounded,
        'songsTrackInstrumental'
      ),
    ];
    return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (pref, icon, key) in options)
            ChoiceChip(
              avatar: Icon(icon, size: 16),
              label: Text(uiStrings[key]?[locale] ?? key,
                  style: const TextStyle(fontSize: 12)),
              selected: current == pref && queue.current != null,
              onSelected: !loading && queue.hasCurrentMix(pref)
                  ? (_) => onSelected(pref)
                  : null,
            )
        ]);
  }
}

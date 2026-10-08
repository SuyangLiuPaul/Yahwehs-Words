# UI consistency maintenance — 2026-10-08

## Scope

Owner requested minor typography, icon and alignment corrections in both apps,
with local commits and GitHub push only. This is source maintenance after 1.7.16:
no version bump, moved tag, store submission or website deployment.

## Findings and corrections

- Material defaults made update and Advanced tiles smaller than adjacent Settings
  controls, especially under Sword's compact workbench theme. Utility cards now
  share Settings title/body/secondary roles, selected font, theme accent and
  24–32 px icons. Dense research panes retain their intended information density.
- All text roles in both light and dark root themes inherit the selected family
  and CJK fallback; previously only three roles explicitly did so.
- Update cards now have one horizontal inset, removing Words' double inset and
  Sword's edge-hugging icon. Diagnosis cards have clear separation from adjacent
  cards and wrapping action buttons with 48 px minimum targets.
- Diagnosis identifiers use selectable monospace text with a readable minimum;
  reporting, copying, resetting and update-channel behavior are unchanged.

## Audit coverage and limits

The page-source inventory covers 45 `Words` page files, with shared themes,
font/icon declarations and responsive test coverage inspected. Metadata, chart
labels, scripture text and compact workbench chrome intentionally have distinct
roles rather than a single fixed size. Source inventory is not a claim that every
route/data state was individually screenshot-tested or that every native device
has been inspected.

Existing responsive suites cover Home/workbench-related pages, Settings, About,
Library, reading statistics, search, evidence, study and reference pages (the
exact page list is in `test/responsive_all_pages_smoke_test.dart` and
`test/responsive_overflow_smoke_test.dart`). New utility tests cover English,
Simplified and Traditional Chinese, light/dark themes, 320/390/768/1280 widths
and 1.5x text scaling, plus root font inheritance. Local Chrome Settings previews
were inspected at desktop and phone widths. No production setting was changed.

Evidence and logs: `/Users/pliu0036/Downloads/Yahweh-UI-Consistency-20261008/`.

## Validation

Both Flutter analyses: no issues. Focused responsive/utility suites: Words 150,
Sword 152 passed before the final identifier styling adjustment. Words complete suite: 4,104 passed / 36 skipped before final identifier styling;
Sword final complete suite: 6,143 passed / 10 skipped. Sword final focused font
ratchet/utility/diagnosis: 24 passed. Words final focused responsive/utility/update suite: 151 passed.

## Page-source inventory

These are source inspection entries, not individual screenshot approvals.

- `lib/pages/about_page.dart`
- `lib/pages/bible_principles_page.dart`
- `lib/pages/bible_timeline_page.dart`
- `lib/pages/bible_trivia_page.dart`
- `lib/pages/books_page.dart`
- `lib/pages/changelog_page.dart`
- `lib/pages/dashboard_page.dart`
- `lib/pages/evidence_detail_page.dart`
- `lib/pages/evidence_page.dart`
- `lib/pages/family_tree_page.dart`
- `lib/pages/feedback_page.dart`
- `lib/pages/help_page.dart`
- `lib/pages/highlights_page.dart`
- `lib/pages/home_page.dart`
- `lib/pages/jesus_teachings_page.dart`
- `lib/pages/library_page.dart`
- `lib/pages/loading_page.dart`
- `lib/pages/map_viewer_page.dart`
- `lib/pages/misconceptions_page.dart`
- `lib/pages/now_playing_page.dart`
- `lib/pages/passion_wheel_page.dart`
- `lib/pages/profile_edit_page.dart`
- `lib/pages/profiles_page.dart`
- `lib/pages/projection_page.dart`
- `lib/pages/reading_stats_page.dart`
- `lib/pages/search_page.dart`
- `lib/pages/sermon_detail_page.dart`
- `lib/pages/sermon_library_page.dart`
- `lib/pages/sermon_library_sermon_page.dart`
- `lib/pages/sermon_library_speaker_page.dart`
- `lib/pages/sermons_page.dart`
- `lib/pages/settings_page.dart`
- `lib/pages/song_downloads_page.dart`
- `lib/pages/song_playlist_detail_page.dart`
- `lib/pages/song_playlists_page.dart`
- `lib/pages/song_score_page.dart`
- `lib/pages/song_video_page.dart`
- `lib/pages/songs_page.dart`
- `lib/pages/stats_page.dart`
- `lib/pages/strongs_entry_page.dart`
- `lib/pages/study_principles_page.dart`
- `lib/pages/study_promises_page.dart`
- `lib/pages/study_testaments_page.dart`
- `lib/pages/videos_page.dart`
- `lib/pages/world_history_wheel_page.dart`

## Owner-authorized dev/prod rollout — 2026-10-08

The owner subsequently requested dev/prod deployment of this maintenance patch.
Words source `9f6f85974724d86e7ccf12d2f5883737678b2a3f` now serves on all six international/China dev, qat and prod sites; public domain `yahwehword.com` also matched. Version remains 1.7.16.

Canonical no-bump international/China builds were used. Slow Netlify uploads required same-build CLI recovery; no runtime edits were made during deployment. Full SHA-256 checks of main.dart.js, flutter_bootstrap.js and version.json matched each site's corresponding build. International main SHA-256: `79da49f1e7021eac7aa1ec1dbaa2468f6220763b029bfa566da3ee89fd71b1b1`; China main: `61275bd5de2601766a94c3bafe5a0640f74c1c1281566c34fafdafa91971cde5`. Startup asset manifest verification passed.

Live Settings was visually checked on international dev/prod and China prod. Evidence: `/Users/pliu0036/Downloads/Yahweh-UI-Consistency-20261008/web-live-verification-words.json`, deployment logs and live screenshots. This is a web maintenance delivery; immutable release tags and native/store packages remain unchanged. Source branch was pushed; no remote CI or main merge is claimed for this branch.

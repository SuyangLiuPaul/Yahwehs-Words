# Interactive Passion reference clock

Updated from the owner-supplied Chinese 福音电台 reference diagram (credit printed on the image: fydt.org). The attached JPEG is preserved byte for byte; SHA256 `80df6472ead28e4a85fb78b5df860ceecd046f7a6adb801d6ddf0c073c682804`.

- The existing `/passion-wheel` route is retained. The owner’s latest correction shows **The Passion of Jesus / 主耶稣受难日时间表 / 主耶穌受難日時間表** in both apps. Principles remain hidden; Words history remains hidden and Sword retains its established history wheel and strip.
- Day and night use separate rings. All 24 hours are interactive, with a full-width hour selector and accessible scene list. Empty hours say that no scene is assigned. 08:00 opens both judgment and mockery scenes.
- Reference diagram mode reproduces its 14 event placements and printed Scripture citations. Most placements are estimates. The original Gospel narrative, place, period and further-reading citations remain available.
- Gospel hours mode retains only explicit account-specific time markers; Mark and John are not silently harmonized. A Gospel filter does not borrow another account's hour.
- Tapping a passage opens the existing Scripture reader sheet. The original attached image opens in a zoomable viewer with its source credit.
- No Bible text, saved data, existing path or watch/car playback implementation is changed by this update.

## Verification

Two independent review rounds checked all diagram placements/references, original image bytes, narrow-screen hit regions and visibility preservation. Learning and visibility tests pass (19 per app), covering 320/402/1024px with 1.8x text, midnight, overlapping scenes, empty hours, dropdown synchronization, old hit-area corners and attachment opening. Both apps pass Flutter analysis. Full release CI and delivery status will be recorded separately; this document does not claim public store approval.

## Source timings

20:00 supper; 00:00 Gethsemane; 01:00 arrest; 02:00 Annas; 03:00 Caiaphas; 05:00 council; 06:00 Pilate; 07:00 Herod; 08:00 sentence and mockery; 09:00 crucifixion; 12:00 darkness; 15:00 death; 17:00 burial. Modern clock conversions are approximate. Other scenes have no assigned diagram hour and remain in the scene list.

## Translation and completeness follow-up

All 14 diagram event placements carry English, Simplified Chinese and Traditional Chinese descriptions, including both final judgment and soldiers’ mockery at 08:00. Gospel filter names use locale-aware book names, and both Passion/principles pages reserve a visible language button even on narrow phones. The original attached image is unchanged and remains Chinese; the interactive content supplies its translated companion. Diagram commentary about the temple offering is attributed to the diagram author, distinct from Gospel time statements. Image failure handling and bounded original-size decoding prevent a broken attachment from generating a Flutter crash.

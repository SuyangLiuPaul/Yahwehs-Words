# Offline media downloads — 2026-10-10

## Changes

- Words: visible song downloads on Home and Songs; byte progress, duplicate prevention, cancel/retry, preserved existing files and sheet music.
- Both: sermon recording downloads by part, manager, cancel/retry/delete and saved-audio playback. Network/stall timeouts, invalid/truncated response checks, temporary-file cleanup, and storage/quota error handling.
- Web: saved media survives startup cleanup; network-first workers retain boot files, renderer and fonts for cold offline navigation. Sword adds Windows audio support and the CDC media proxy. Scripture and EV content were not changed.

## Actual checks

- Words formal site, Chrome/mobile width: Ask 祈求 downloaded 8,518,053 audio bytes + 428,479 PDF bytes. Downloads restored after closing and disconnecting network; saved blob playback advanced to 2.21 s. Deletion then removed both cached files.
- Words China-mode actual app, Chrome: real Sermon 004 two parts restored after closed-page offline navigation; saved playback advanced to 2.16 s.
- Sword actual app, Chrome: real Sermon 004 two parts restored after closed-page offline navigation; playback advanced to 2.27 s.
- Sword actual app, persistent desktop WebKit: close page, stop the HTTP server, block HTTPS, reopen and play saved recording; advanced to 2.06 s. This did not use an emulated-offline flag.
- Analysis clean. Full suites: Words 4,116 passed / 36 skipped; Sword 6,155 passed / 10 skipped. Both Chrome cache suites passed 4 tests; Node worker lifecycle checks passed. Queue/storage tests cover duplicate, cancel/late write, retry, eviction, deletion, invalid/truncated response, disconnect and simulated quota/write failures. Sword Windows artifact build 38028404029 passed; no Windows device playback claim.
- Both live CDC recording proxies return HTTP 206 audio/mpeg with ID3 bytes.

## Entries and remaining device checks

Words: Home/Songs → Downloads (`#/songs/downloads`); open a song → Download for offline. Words sermons: `#/sermons/004` → Download audio / Sermon downloads. Sword: `?sermon=004`, Enter if shown, then Download audio / Sermon downloads (manager is an in-app screen).

Physical iPhone/TestFlight, Android, Windows, Safari and installed iOS PWA have not been installation/playback tested here. On each actual device/instance: download one song (Words) and a sermon, wait for completion, close, enable airplane mode, reopen and play; then delete/retry. Repeat Safari and PWA separately because storage can differ. Browser cache can be evicted; open the sermon online once to cache its text/app assets. This task deployed websites; it did not upload a new native store package, install one on a device, bump 1.7.16 or change tags.

Evidence: `/Users/pliu0036/Downloads/Yahweh-Offline-Media-20261010/`. Actual proofs: words-real-song-offline-proof.json, words-real-song-delete-proof.json, words-actual-offline-proof.json, sword-actual-offline-proof.json, sword-webkit-actual-offline-proof.json. Valid UI captures use words-real-song-*, words-actual-* and sword-verified-*; earlier misnavigated Sword captures are not verification. The separate PHP camera_proxy email has unconfirmed attribution and no PHP repair was performed.

## Final web delivery

Words runtime source: `3bd3647e149fefe9c0f9531d80a7108701bab5d8`. Current-head CI `38029696482` passed at `8eedd5aa77d01059a518e64143fd44de33a324a5` before merge. Merged tree matched the checked tree. Initial feature PRs Words 58 / Sword 48 and cold-start PRs Words 59 / Sword 49 are merged.

Words completed before Sword deployment. All eight sites are Ready; full live SHA-256 matched the captured build for main.dart.js, bootstrap, index, worker, both asset manifests and version.json. Per-site IDs/hashes are retained in `docs/offline-media-web-delivery-2026-10-10.json`.

- https://yswords-cn.netlify.app: deploy `6ac9d8b3db5937c77464e74d`.
- https://yswords-dev.netlify.app: deploy `6ac9d827e3ef05540ffa687d`.
- https://yswords-cn-qat.netlify.app: deploy `6ac9d8b46d030c7166615efe`.
- https://yswords-cn-dev.netlify.app: deploy `6ac9d8b39ec633877377ca41`.
- https://yswords-qat.netlify.app: deploy `6ac9d8272bf071f84ac329ca`.
- https://yahwehword.com: deploy `6ac9d827e323c8e1e6577f66`.

## 2026-10-11 source follow-up（尚未发布）

Words 讲道支持当前筛选／系列的批量选择、已保存跳过、未知体积提示；下载管理页可搜索、筛选、选择删除、暂停／继续和重试。队列重开后保持暂停，未完成录音继续时从头下载，不宣称断点续传。单项删除不取消其他下载。
旧索引和恢复备份保留；文件缺失、读错误和损坏不重写原索引。替换录音先保护旧文件，并记录恢复日志；下载失败或中断可回退。Web 检查截断响应，删除失败保留有效播放 URL。网页更新仅删除已知 Flutter shell 缓存，保留音频和其他缓存。
本地下载相关测试 36 项通过，flutter analyze 无问题；Node 缓存保留检查通过。管理页覆盖 390px、1.4 倍文字、中英文；这是自动化检查，不是实体设备／完整浏览器网络故障验证。
这批修改独立于不可变 1.7.17；没有新商店包、标签或网页部署。提交后仍需当前 head CI 通过再合并。
Words 诗歌另增加持久化待下载队列、显式暂停／继续和暂停行提示；重开不会自行触发大批网络下载。原有歌曲、乐谱和完成记录保留。

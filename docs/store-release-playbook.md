# Words / Sword 全平台发版流程

适用：两款 app 同一次版本升级，覆盖网站、GitHub 安装包、Apple、Google Play、Microsoft Store。只有 Paul 明确授权正式发版时才开始升版本、打 tag、部署生产站或提交商店。以各仓库最新 `HANDOFF.md`、`PROJECT_STATE.md` 和 `docs/delivery-<version>-*.md` 为准；历史聊天和旧 checkpoint 不覆盖更新记录。

## 单次发版顺序

1. **定版本和范围**：Words、Sword 共用显示版本；先确认本次实际功能，不给 Sword 加入 Words 的音乐、AI、Watch、CarPlay/Android Auto 功能。确认工作区和 owner 改动，先保护未提交内容。
2. **一次完成源码与商店文案**：更新两款版本/变更记录、各自测试、商店三语言 What's New。文案必须对应该 app 和本次改动；不复用旧版本文案。版本号、商店 version code、bundle ID、签名身份分别核对。
3. **一轮源码门禁**：对当前头跑各自完整 CI，按准确 commit SHA 读取结果。CI 失败只看失败步骤日志；修复后重跑当前头，合并后确认 main 树与通过测试的头一致。标签不可移动或覆盖。
4. **一次构建并保存清单**：从同一个不可变 tag 构建所有目标。保留每个包的 source SHA、run ID、平台、版本/version code、bundle ID/Publisher、架构、签名身份、文件大小和 SHA-256。重用已验证的同一构建；不得仅为轮询重复构建。
5. **部署网站**：按 owner 既定次序先 Words、后 Sword；每款按获授权的 dev/QAT/prod 范围发布。用线上版本和构建文件摘要回读验收，超时后重试同一构建，不平行部署两款网站。
6. **一次处理商店渠道**：可并行运行互不冲突的 Apple/Play/Microsoft 上传；每个商店分别读回版本与包状态。上传、平台处理、送审、通过、公开上线是不同状态，交付矩阵逐项记录，不把其中一个状态说成另一个。
7. **更新交接并停在真实关卡**：两份 delivery 记录与统一交接写入 run ID、哈希、状态和未验证事项。API draft/审核/真实测试资格等未完成步骤列为下一步；不取消旧审查、不重复提交同一包、不填写未经 owner 核实的问卷。

## 平台包和 API

| 渠道 | 上传包 | API 与资格要点 |
|---|---|---|
| Apple App Store / TestFlight | 签名 iOS `.ipa`；Mac App Store 签名导出包（当前用 `.pkg`） | 用现有 App Store Connect API key 上传，不必每次交互式登录；签名证书、profile、构建处理、合规、测试组和正式审查仍要分别核对。上传成功不代表审核通过。 |
| Google Play 手机 | Play 专用签名 `.aab`，不能拿 GitHub APK 替代 | 用 GitHub Actions `PLAY_SERVICE_ACCOUNT_JSON`。上传前从 Play API 读取各 track 和全部已用 version code；新 code 必须严格更大。Words Wear 有独立 Wear AAB/track/code，绝不能用手机 AAB 替代。现有上传 workflow 是 test-track draft 流程；确认正确三语言 notes 后才用，不自动等于送审或 production。真实 production 测试人数/天数门槛不能绕过。 |
| Microsoft Store | 与 listing Identity/Publisher 完全匹配的 x64 `.msix` | 用 GitHub Actions 的 `MS_STORE_*` OAuth secrets。API 流程会建 draft 并上传包；`PendingCommit` / `PendingUpload` 仍不是已校验、认证或发布。先 readback identity/version/status，再按明确授权在 Partner Center 完成验证/提交；不删除或覆盖已有 draft/submission。EXE/ZIP 不是 Store MSIX。 |
| GitHub / 直接下载 | APK、Windows EXE/安装包、Linux tarball、Mac 下载包等各自 release asset | 与 Play AAB、Microsoft MSIX、Apple 商店包分开验证签名、包名和摘要；不能用直接下载证明商店已更新。 |
| Web | 每款 canonical Flutter web build | 按 Words → Sword 部署，记录各站资源摘要并做线上回读；Web 版本不会替原生安装包升级。 |

## 当前已知关卡（2026-10-12；以 11:51 Melbourne checkpoint 为准）

- Apple 1.7.21 上传与构建处理证据见两款 delivery 文档及 `/Users/pliu0036/Downloads/Yahweh-Store-API-20261011/apple-1.7.21-upload-proof.json`。App Store 审核状态须单独读回。
- Microsoft Words `1152921505702099400`、Sword `1152921505702099459` 已经通过 guarded API workflow 提交（runs `38188399035` / `38188399251`），两个真实 MSIX 均为 1.7.21.0/x64，三语言文案与 SHA 已验证；API 状态 `CommitStarted`，automatic publication 已选，但尚未据此宣称公开上线。后续只读检查这两个 submission，不建重复 draft、不重复 commit。
- Sword Google Play 1.7.21 已通过 workflow `38187507703` 发布到现有 internal track，version code `2000023`，回读显示对内部测试者可用。Production 仍 inactive，当前资格为 12 名连续 opted-in 测试者 / 要求 14；Alpha 轨道保持原状。
- Words Google Play 1.7.21 尚未上传：现有 Words 更新仍在 `In review`，取消/替换会破坏当前审核，因此 uploader 保留 `ERROR_IF_IN_REVIEW`。生产资格同样未满足。Words phone + Wear 双包和递增 version-code uploader 修正已合并，PR #82 exact-head 与 main CI 均通过；待活动审核允许编辑后再按同一 release 上传两种 AAB，并核验正确本地化 notes。
- 1.7.21「创世记」显示修正不完整：locale-aware 页面已使用新拼写，但 `translateBookName` 为兼容冻结数据键会返回 `创世纪`，部分标题/选择器仍显示旧拼写；owner 已在 Microsoft Store 1.7.21 安装和网页中观察到，说明是共享显示逻辑，并非单一商店包问题。后续若要全 UI 统一，需另做源码修正并分别验证 Words/Sword；已上传的 1.7.21 包不可原位修改。
- Words/Sword 最新实况和完整 run IDs、submission IDs、哈希见 `/Users/pliu0036/Documents/CodingProject/Words-release-integration-20261011/docs/delivery-1.7.21-2026-10-11.md` 与 `/Users/pliu0036/Documents/CodingProject/Sword-store-api-20261011/docs/delivery-1.7.21-2026-10-11.md`。这些新状态覆盖本文早期的 1.7.21 readiness/draft 记录；审核/内部/正式发布不可混为一谈。

## 省 token 和避免重复劳动

- 新会话先读本文件、两款最新 `HANDOFF.md`、当前 delivery 文件；不要重读整段聊天、历史 delivery 或整个仓库。
- 用已记录的 exact run ID / commit SHA / package path。CI 通过就不重跑；只抓取失败 job/step 的日志。旧 tag 和已验证包可复用时不 rebuild、不重 upload。
- 每个平台和 app 做一次组合式 read-only preflight，输出简洁状态 JSON；凭据只读 GitHub Actions Secrets，绝不打印/复制进文档。
- 上传前一次核验 package identity、版本/version code、签名和 SHA-256；任何不匹配即停。完成后复用同一摘要读回证据，不重复整套检查。
- 最后只追加有意义的状态变化和下一步，不复制全部历史；清楚标注“已构建、已上传、待处理、已送审、已批准、已公开”中的真实状态。

## 自动化边界

现在已有各平台 API workflows，但不是一个覆盖所有商店并自动批准发布的单按钮。目标是一次授权、同一版本/源码、一次构建矩阵、分平台 API 上传和一张状态矩阵；商店审核、Google production 资格及需要人工确认的 Partner Center 步骤仍按平台要求分别完成。后续可把安全的 preflight/build/upload 草稿步骤统一成 release coordinator workflow，但必须保留每个平台的独立版本码、签名和 fail-closed guards。


## 上传成功后的记录方式（2026-10-12）

每个商店包成功上传/提交后立即追加到对应 app 的当前 delivery 文档；不必等审核通过。记录商店与轨道、版本/build/version code、准确包路径和 SHA-256、workflow/run ID、API/控制台回读状态、发布设置和下一道关卡。只写经回读证实的状态：上传接受、处理中、已送审、已批准、公开可用不能互相替代。秘密只记录其安全存放位置或 secret 名称，绝不落入文档。

Words/Sword 一组交付完成后，将新增的可复用步骤及故障防护更新到此流程和 Codex 长期记忆 `/Users/pliu0036/.codex/memories/yahweh-store-release.md`。更新前备份文件；在共享工作区保留 owner 变更，只编辑指定文档，不 stage 不相关文件。Google Play 更新 track 前确认所有已用 version code、正确手机/Wear AAB、正确本次三语言文案及审核状态；保留 `ERROR_IF_IN_REVIEW`，若有活动审核就等待，不取消或重复提交。Microsoft Store 上传后核验 Identity、Publisher、包版本/架构/哈希、三语言说明和 submission readback，再按授权提交；`CommitStarted` 仍需继续读状态，不能称公开上线。

1.7.21 的实际 run/submission IDs、包摘要和状态以 Words 与 Sword 两份当前 delivery 记录中的 2026-10-12 11:51 Melbourne checkpoint 为准。

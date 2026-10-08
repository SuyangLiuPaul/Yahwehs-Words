# Admin、About、CN 网页维护 — 2026-10-08

应用版本保持 1.7.16；无版本升级、标签、原生包或商店提交。

## 变更

- Admin 手机顶栏分为品牌/菜单、语言/账号两行；导航默认收起，点击入口后收起。入口带统一线条图标、边框、分组分隔、当前页高亮和方向提示。现有品牌图标用于顶栏、登录和 favicon；账号工具改为可关闭的下拉区域。
- About 卡片按内容自然高度排列，下载区域移除 margin-top:auto，消除 Sword 卡片中部空白。
- CN 从共享 About 重新生成，同步徽章分组和响应式布局；保留 CN 原有下载链接与说明。

## 已核对

- Admin prod deploy 6ac72e7e5bb77d48fca3050d；公开资源与本地 SHA-256 一致。数据库、base 文件、权限与规则未改。
- 线上 Admin 演示视图菜单已查看，中英文入口均有图标；导航后自动收起。演示模式未写入真实数据，不代表后端保存验证。
- yahwehword.com/about 与 /cn 返回内容均与本地文件完全一致。手机 390px，无横向溢出；两页面各卡片 hostname 与下载区域的额外垂直 gap 均为 0。桌面 About 已查看下载卡片。
- 国际网页 main.dart.js SHA-256 与上一轮完全一致：79da49f1e7021eac7aa1ec1dbaa2468f6220763b029bfa566da3ee89fd71b1b1。
- 无新增/运行测试套件。网页预渲染采用直接 Dart VM 方式，避免无关 Objective-C 构建钩子遇到本机 Xcode 许可提示；未接受许可或修改系统配置。

证据与部署日志：/Users/pliu0036/Downloads/Yahweh-Portal-About-Mobile-20261008/。

源码：Words 变更 cba61f46 已 push 到 fix/ui-consistency-20261008；primary 同步提交 058a7695。Admin 本地提交 7ccea00，仓库没有配置远程；prod 已部署。

## Owner 桌面反馈后的最终布局

旧的双卡并列仍有卡片底边高低不齐，owner 明确反馈桌面右侧空缺不舒适。桌面（44rem 以上）改为每个应用一个完整横向卡片，左侧品牌/介绍、右侧下载入口，使用细分隔线。手机保持介绍和下载自然单列。三个应用均使用同一结构；CN 再次由共享源生成。检查 CN 手机 DOM：三个卡片各一个 intro 与 downloads，没有横向溢出。此前并列卡片截图与 gap 数值属于前一检查点，不代表最终桌面布局。

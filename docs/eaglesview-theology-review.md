# Eagle’s View 神学用语审阅 — 2026-09-30

## 结论

提供的 EV 包**并未全部删除明确的三位一体解释**。在可读取的 20 个词典/研究数据库、76 张表、827,195 行中，扩展扫描找到 37 个候选字段；人工复核确认 **2 个 EV 词条存在明确用语**，另有 **1 个词条需解释性复核**。重复表、简繁字段、正常经文和语法术语会产生重复或误报，37 不代表 37 个问题。

| 优先级 | 原文件 / 位置 | 可核对的文字 | 判断 |
| --- | --- | --- | --- |
| 明确 | `Thayer.dct` → Dictionary → G2304（行 2722） | “spoken of the only and true God, trinity” | 明确三位一体解释，后文分别列 Christ、Holy Spirit、Father。 |
| 明确 | `Strong SCh.dct` → Dictionary → H7307（行 7491） | “神的灵, 三一神的第三位, 圣灵, 与圣父圣子同荣, 同尊” | 明确三一神第三位及同荣同尊解释。 |
| 需复核 | `Thayer.dct` → Dictionary → G1504（行 1574） | “to Christ on account of his divine nature and absolute moral excellence” | 关于基督神性的解释，不等同于明确三位一体陈述；请牧师决定保留或作编辑说明。 |
| 背景 | `MC.dct` → tblSubsection 等五张含重复内容的表 | “(神，基督，国度是) 永远，永恒” | 15 个字段命中同类分类标题，本身不足以判定为三位一体解释。 |

## 误报与保留原文

- `Strong Eng.dct` / `Thayer.dct` G2077 的 “third person of the same” 指动词第三人称，属于语法。
- `Thayer.dct` G1484 和中文 Strong G2098 / G2288 / G4102 / G4145 涉及外邦人、福音、死亡、信心和永恒财产；命中相邻关键字不等于三位一体主张。
- `Bookbase.mdb` 的弗 2:10、启 1:1、林前 1:21、林后 1:21、约壹 5:20、约 1:1 共 12 个简繁字段是经文。此次审阅没有修改这些经文，也不把经文本身归类为牧师的注释。

## Words / Sword 实际资产还需注意

EV 原包与应用内其他来源的词典必须分别核对：

| 应用资产 | 词条 | 当前情况 |
| --- | --- | --- |
| `assets/thayer.json` | G2304 | 两款均仍含明确 `trinity` 解释。 |
| `assets/strongs/greek.json`、`assets/strongs/thayer_zh.json` | G2316 | 两款 CBOL 中文释义仍列“三位一体”及第一、第二、第三位；这不是 EV 原包已编辑中文 G2316 的证明。 |
| 同上中文资产 | G3056 | 两款仍含“是神性中的第二位格”解释，需与 EV 已删减的对应释义区别处理。 |
| 同上中文资产 | G4151 | 关于圣灵人格及非人格力量的解释值得牧师复核；不能仅靠关键字作结论。 |
| `assets/strongs/bdb_zh.json` | H7307 | 已用的中文条目没有上面 EV 的“三一神第三位”句子。 |

本次按要求列出疑点，没有静默删除释义、改写经文或把编辑文字冒充原作者内容。若决定删去解释，应保留版本化原来源，并明确标记应用的编辑省略。

## 范围和复查

- 可读取词典、concordance、study 数据库字段全表扫描；未执行安装包内 EXE。
- `.bbl` 圣经模块、二进制程序及不可读取内容不在此次词典审阅范围，不能据此声称整个软件所有内容已经逐句审定。
- 中文 RTF 的 GBK 转义用于还原中文说明；英文数据库采用其原编码。Greek RTF 头部可能不能完整还原，不作为原文校勘依据。
- [机器可读位置、上下文及原文件 SHA-256](eaglesview-theology-review.json)保留所有 37 个候选字段的分类、表名、行号与短上下文。
- 复查脚本：`tools/review_eaglesview_theology.py --source <已解开的 named-files 文件夹> --output <JSON 路径>`，需要 `mdbtools`；只读源文件。

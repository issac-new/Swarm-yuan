# offline-cache 上游溯源登记（UPSTREAM.md）

> 本文件登记 offline-cache 内 vendor 组件的上游来源、版本与许可证，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）。
> 入库说明：`git check-ignore` 2026-07-20 实测本文件**未被忽略**（.gitignore 仅忽略 `offline-cache/gstack/`、`offline-cache/superpowers/` 目录与 `*.zip/*.whl/*.tgz`），可正常入库；同时随 offline zip 分发。
> 注意：offline-cache 内无 `.git`（gitlink 已移除），包内无法自证克隆自哪个上游 commit，故以本文件为准记录版本与获取日期。

## 一、vendor 组件登记

### 1. gstack v1.60.1.0

- **路径**：`offline-cache/gstack/`（完整源码克隆）
- **版本**：v1.60.1.0（`offline-cache/gstack/VERSION:1`）
- **许可证**：MIT，Copyright (c) 2026 Garry Tan（`offline-cache/gstack/LICENSE:1-3`）
- **作者**：Garry Tan（Y Combinator CEO）
- **来源**：GitHub，https://github.com/garrytan/gstack （`git clone --single-branch --depth 1`）
- **获取日期**：2026-07-20
- **MIT 义务**：副本或实质部分中须保留版权声明与许可声明（LICENSE 第 5-13 行）——分发 offline zip 时不得删除 `gstack/LICENSE`。

### 2. superpowers-marketplace v1.0.13

- **路径**：`offline-cache/superpowers/`（全目录仅 4 个文件：`LICENSE`、`README.md`、`.claude-plugin/marketplace.json`、`.claude/settings.local.json`）
- **版本**：marketplace v1.0.13（`offline-cache/superpowers/.claude-plugin/marketplace.json:7-10`）
- **许可证**：MIT，Copyright (c) 2025 Jesse Vincent（`offline-cache/superpowers/LICENSE:1-3`）
- **作者**：Jesse Vincent（obra）
- **来源**：GitHub，https://github.com/obra/superpowers-marketplace
- **获取日期**：2026-07-20
- **MIT 义务**：同上，分发时不得删除 `superpowers/LICENSE`。

## 二、⚠️ superpowers 核心插件未 vendor（空壳明示）

**superpowers 核心插件 v6.1.1 未 vendor 进 offline-cache；离线包内仅 superpowers-marketplace 元数据。**

- `marketplace.json` 编目 10 个插件，全部以 URL source 指向各自 GitHub 仓库（核心插件指向 `https://github.com/obra/superpowers.git`），**离线环境无法拉取**。
- 后果：离线安装得到的 `~/.claude/plugins/superpowers` 只有市场目录，**不含核心插件的 20+ skills 本体**；要获得核心能力须在线 `/plugin install superpowers@claude-plugins-official`。
- 市场内 10 个插件各有独立 license（marketplace README 明示 "Individual plugins: See respective plugin licenses"）；未来若 vendor 任何子插件，须逐一核实其 LICENSE 并保留。
- elements-of-style 插件内含 Strunk《The Elements of Style》(1918) 全文——1918 年美国出版物在美已入公有领域，跨境分发宜标注来源与公版状态。

## 三、⚠️ 遥测提示（gstack opt-in telemetry）

gstack 自带 **opt-in 遥测与设备 ID**（安装时问询流程见 `offline-cache/gstack/SKILL.md:191-217`）。swarm-yuan 离线分发 gstack 即间接分发其遥测提示。

**面向数据出境敏感的行业/国家合规场景，建议关闭遥测：安装问询时选择拒绝，或执行 `telemetry off`。** 遥测为 opt-in，不启用则不外发数据。

# 上游 vendor 决策：不 vendor superpowers 核心插件 v6.1.1

> 日期：2026-07-20 ｜ 分支：`feat/standards-compliance`（P1-7）
> 记录 superpowers 核心插件 vendor 问题的正式决策与理由，供后续版本维护参考，避免重复调研。格式参照 `docs/paradigm-decisions.md`。

## 处置总览

| # | 事项 | 决策 | 依据 |
|---|------|------|------|
| 1 | vendor superpowers 核心插件 v6.1.1 进 offline-cache | ❌ 不 vendor（维持 marketplace 元数据 + 空壳明示现状） | 本文件 §二 |
| 2 | 空壳误判治理（诚实检测 + 文案） | ✅ 已做（P0） | `self-check.sh` check_superpowers 实质检测、`offline-cache/UPSTREAM.md` §二 |

## 一、背景事实（2026-07-20 核实）

- offline-cache 内的 `superpowers/` 是 **superpowers-marketplace v1.0.13**（全目录仅 4 文件：`LICENSE`、`README.md`、`.claude-plugin/marketplace.json`、`.claude/settings.local.json`），核心插件 v6.1.1 本体不在包内；marketplace.json 以 URL source 指向 `https://github.com/obra/superpowers.git`（`docs/research/R5-upstream-local.md` §四，2026-07-20 本地实证）。
- 核心插件仓库 https://github.com/obra/superpowers ：**MIT** 许可证，最新 release **v6.1.1**（2026-07-02 发布；v6.0.0→v6.1.1 约六周内 5 个 tag）——GitHub REST API 实测，访问 2026-07-20。
- swarm-yuan 对 superpowers 的吸收是**文档级方法论引用**（14 个 skills 能力清单登记于 `swarm-yuan/references/subagent-orchestration.md:118-137`），不是运行时命令调用——`swarm-yuan/SKILL.md:108` 工具引用铁律的允许 CLI 清单（graphify/gitnexus/ocr/claude-mem/gsd-tools）不含 superpowers。
- P0 已完成诚实检测与文案：`scripts/self-check.sh` check_superpowers 实质检测（须含 `skills/` 子目录或 `.claude-plugin/plugin.json` 才判已安装；仅 marketplace 元数据判空壳 miss，fail-closed）；`scripts/install-offline-win.sh:105` 文案改为「目录已复制，需在 Claude Code 中 /plugin enable」；`offline-cache/UPSTREAM.md` §二空壳明示。

## 二、决策理由

### 1. zip 体积

offline zip 已 44MB（`docs/paradigm-decisions.md:49`）。核心插件含 20+ skills 本体及资源，vendor 将进一步膨胀 Release 附件；离线包的消费场景是 Windows 一次性落地 11 个运行时（`scripts/install-offline-win.sh:2,5-7`），体积直接决定分发成本。

### 2. 维护面

vendor 即承担版本追踪与逐版重核义务。核心插件迭代快（v6.0.0→v6.1.1 约六周 5 个 tag），vendor 副本会立即开始漂移，须纳入 `docs/upstream-baseline.md` 审计例程；而 swarm-yuan 对 superpowers 没有运行时调用，vendor 不带来任何运行时收益——纯属为「文档级引用」背维护负担。

### 3. 许可证

核心插件本身 MIT（允许再分发，保留 LICENSE 即可），不构成 vendor 障碍；但 marketplace 编目的 10 个插件各有独立 license（marketplace README 明示 "Individual plugins: See respective plugin licenses"），一旦开 vendor 口子，就须逐一核实并保留各子插件 LICENSE；elements-of-style 插件还内含 Strunk《The Elements of Style》(1918) 全文（美国公有领域，跨境分发宜标注来源与公版状态）。不 vendor 核心插件，即把许可证敞口收敛在 marketplace 元数据一个 MIT 文件上。

### 4. plugin 生态

superpowers 的正规获取路径是插件市场在线安装（marketplace.json 的 URL source 机制本为在线拉取设计）；vendor 核心插件等于维护一份脱离市场更新通道的静态副本，与上游生态演进脱节。离线用户需要核心能力时的既定路径：在线环境 `/plugin install superpowers@claude-plugins-official`，或手动 clone 仓库并保留其 LICENSE（UPSTREAM.md §二已明示）。

## 三、风险与缓解

| 风险 | 缓解 |
|---|---|
| 离线用户误以为已装核心插件（空壳） | P0 已修：self-check 实质检测 fail-closed；install-offline-win.sh 文案不再宣称核心能力；UPSTREAM.md §二明示 |
| references 引用的 14 个 skills 能力离线不可得 | 接受。吸收物是方法论（已写进 references 供 AI 阅读），不依赖插件本体在场 |
| 未来 superpowers 能力变成运行时依赖 | 复审触发：若 `SKILL.md:108` 允许 CLI 清单新增 superpowers 系命令，或离线分发成为主要形态，重开本决策并连子插件许可证复核一并进行 |

## 不做的事（本决策明确）

- 不 vendor 核心插件 v6.1.1 及 marketplace 任何子插件
- 不改 install-offline-win.sh 的复制目标（仍复制 marketplace 目录，由实质检测兜底避免误判）
- 不逐版追 superpowers 更新（引用基线 v6.1.1 = 上游最新 release，`docs/upstream-baseline.md` 状态 synced）

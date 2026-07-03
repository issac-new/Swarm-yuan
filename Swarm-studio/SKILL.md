---
name: swarm-studio
description: SwarmStudio (hermes-studio v0.6.23) 二次开发全流程技能。覆盖 overlay/patch/inject 机制、cockpit/kanban/matrix-chat 组件开发、build:dmg 桌面打包、run-trace 执行链、url-guard 安全加固、embedded SQLite 持久化、hermes-studio-mcp 工具接入。工作目录 /Volumes/nvme2230/lab/ncwk/。
---

# ncwk-dev — SwarmStudio 二次开发需求交付全流程技能

> 本技能由 swarm-yuan 生成器（generate-skill.sh）创建骨架，已按 ncwk 项目实际探查填充。
> **七方法论整合**：OpenSpec（proposal/spec delta）+ superpowers（subagent 编排）+ comet（脚本背书状态机）+ gstack/OCR（5 维度审查）+ GitNexus/graphify（代码图谱）+ gsd-core（goal-backward 验证，可安装）+ claude-mem（跨会话记忆，可选）。
> 方法论参考文件（subagent-orchestration.md / review-methodology.md / gsd-patterns.md / memory-persistence.md / code-graph-tools.md）已就绪，按需引用，勿重复复制其源码。

## 核心理念：7 铁律

| # | 铁律 | 来源 |
|---|------|------|
| 1 | **仅允许修改 `overlay/` 目录。** `upstream/` 只读，禁止直接改；upstream 变更只能通过 `overlay/patches/` 经 `npm run inject` 注入 | AGENTS.md（修改范围限制） |
| 2 | **所有开发基于 `main` 创建 `feat/`/`fix/`/`refactor/`/`chore/` 分支**，测试通过后合回 main | AGENTS.md（分支管理） |
| 3 | **upstream 变更必须通过 patch 文件实现**，由 inject 在构建时注入；A 类改造优先于 B 类 | AGENTS.md（项目结构） |
| 4 | **除非用户明确确认，绝不自动 push 远端** | 项目记忆 |
| 5 | **绝不删除 `backup/pre-squash` 分支** | 项目记忆 |
| 6 | **dev server 运行期间禁止 upstream checkout/clean**（会破坏注入态） | 项目记忆 |
| 7 | **release 产物仅 arm64.dmg + x64.zip**；push 前做敏感信息检查 | 项目记忆 |

## 改造分类

| 分类 | 位置 | 机制 | 适用 |
|------|------|------|------|
| **A 类**（overlay/custom） | `overlay/custom/client`、`overlay/custom/server` | 自有源码，经 `registries/client` 注册（registerRoute/registerNavEntry/registerComponent），bootstrap.ts 动态 import + feature flag 守卫，`npm run dev` HMR | 新增组件/store/API/路由（优先） |
| **B 类**（overlay/patches） | `overlay/patches/` + `patches/series` | unified diff patch，`npm run inject` 按 series 顺序 `git apply` 注入 upstream。路由按前缀：`hermes_cli/` `plugins/` `agent/` `apps/` `assets/` `acp_` → hermes-agent（容错跳过）；其余 → hermes-studio（fatal） | 修改 upstream 既有文件（A 类无法覆盖时） |

当前 **83 个活跃 patch**（patches/series 非注释行）。

## 全流程总览（8 节点）

```
①需求理解 → ②设计spec(OpenSpec) → ③实施plan → ④分支准备 → ⑤编码实现(subagent)
                                                                     ↓
        ⑧构建发布 ← ⑦合入main(需确认) ← ⑥测试验证(gsd+OCR)
```

详见 `references/workflow.md`（每节点 9 要素 + 完成检查表）。

## 七大方法论整合导航

| 方法论 | 在本技能的落点 | 参考文件 |
|--------|---------------|----------|
| **OpenSpec**（proposal → spec delta → design → tasks） | 节点②③：proposal.md + delta spec（ADDED/MODIFIED + SHALL/MUST + Scenario WHEN/THEN ####4hashtag）+ design.md + tasks.md（-[] checkbox） | assets/spec-template.md |
| **superpowers**（subagent 编排） | 节点⑤：orchestrator + fresh subagent per task + 两阶段审查 + progress ledger + 文件交接 + 连续执行 | references/subagent-orchestration.md |
| **comet**（脚本背书状态机） | 节点⑧状态控制：state-machine.sh 持久化阶段，survive context compaction | scripts/state-machine.sh + assets/state-machine.sh |
| **gstack + open-code-review**（5 维度审查） | 节点⑥：correctness/security/performance/maintainability/test-coverage + AUTO-FIX/ASK + 两遍清单 | references/review-methodology.md |
| **GitNexus + graphify**（代码图谱） | 节点⑤依赖查询：graphify path / GitNexus MCP 替代 grep | references/code-graph-tools.md + scripts/code-graph-tools.md |
| **gsd-core**（goal-backward 验证，可安装） | 节点⑥：goal-backward「task completion ≠ goal achievement」证伪 SUMMARY，BLOCKER/WARNING；节点⑤可调用 /gsd-execute-phase | references/gsd-patterns.md |
| **claude-mem**（跨会话记忆，可选） | 节点⑧状态控制：observer 自动捕获决策/发现，SessionStart(compact) 重新注入 | references/memory-persistence.md |

## 六段式结构导航

| 段 | 文件 | 职责 |
|----|------|------|
| meta | SKILL.md（本文件） | 核心理念、分类、流程、命令、门禁、记忆、检查表 |
| workflow | references/workflow.md | 8 节点 × 9 要素流程编排 |
| reference | references/codebase.md / dev-guide.md / release.md / reference-manual.md | 代码库/开发指南/发布/参考手册 |
| assets | assets/spec-template.md / plan-template.md / data-sample-template.md / branch-setup.sh / env-setup.sh / state-machine.sh | 模板与定制脚本 |
| check | scripts/precheck.sh + reference-manual.md 检查段 | 4 类质量门禁 + 5 维度审查 + goal-backward |
| scripts | scripts/precheck.sh / state-machine.sh / snippets.md / code-graph-tools.md / mcp-tools.md | 运行时脚本与速查 |

## 快速入口

| 场景 | 入口 |
|------|------|
| 新需求从零开始 | ① SKILL.md → workflow.md 节点① → spec-template.md |
| 已有 spec 要实施 | plan-template.md → branch-setup.sh → workflow.md 节点⑤ |
| 改 upstream 既有逻辑 | dev-guide.md「B 类开发」→ precheck.sh --scope |
| 加新组件/路由/API | dev-guide.md「A 类开发」→ snippets.md「注册 API」 |
| 桌面打包发布 | release.md → build:dmg:mac/win |
| 恢复中断的会话 | state-machine.sh status → memory-persistence.md |
| 查依赖关系 | code-graph-tools.md → graphify path / GitNexus MCP |
| MCP 工具 | mcp-tools.md（hermes-studio-mcp / hermes mcp serve） |

## 常用命令速查

```bash
cd /Volumes/nvme2230/lab/ncwk/overlay          # 所有开发在此目录

# 环境与状态
bash .agents/skills/ncwk-dev/assets/env-setup.sh        # 检测 Node>=23 / Python>=3.11 / git/gh/docker
bash .agents/skills/ncwk-dev/scripts/state-machine.sh status   # 读当前阶段状态

# 注入与清理
npm run clean           # node scripts/inject.mjs --clean（清自残留+upstream 还原）
npm run inject          # node scripts/inject.mjs（清→dirty-check→apply 83 patches→symlink→gen vite config→写 manifest）
npm run ensure-injected # node scripts/ensure-injected.mjs（幂等确保注入态）
npm run verify          # node scripts/verify-clean.mjs（校验注入态干净）

# 开发
npm run dev             # cross-env HERMES_WEB_UI_BACKEND_PORT=8647 vite --config vite.config.overlay.ts --host --port 8649 --strictPort（predev=ensure-injected）
bash scripts/serve-server.sh   # 启动/重启 Koa 后端（8647）

# 测试
npm test                # vitest run（overlay/vitest.config.ts，pattern custom/**/*.test.ts，37 files）

# 构建
npm run build:full      # openapi:generate → vite build → tsc --noEmit → build-server（必须用 overlay，非 upstream npm run build）
npm run build:dmg:mac   # inject → build:full → npm ci desktop → tsc main → electron-builder --publish never → SwarmStudio-0.6.23-arm64.dmg+.zip
npm run build:dmg:win   # 同上 → x64.exe+.zip+msi

# 同步上游
npm run sync            # bash scripts/sync-upstream.sh
```

## 端口

| 端口 | 服务 | 说明 |
|------|------|------|
| 8647 | Koa 后端 | hermes-web-ui backend API |
| 8649 | Vite HMR 前端 | `--strictPort`（占用即失败，不自动换端口） |
| 8650 | agent-health | `/agent-health` 代理，`Authorization: Bearer $API_SERVER_KEY`（patch 107 认证+路径白名单） |
| 8642 | Hermes gateway | Agent 网关 |
| 9119 | Hermes dashboard | Agent 仪表盘 |

## 质量门禁（4 类）

| 类型 | 作用 | 何时用 | 在本技能 |
|------|------|--------|---------|
| **Pre-flight** | 启动前验证前置条件（阻塞进入，无部分工作） | 开始阶段前 | branch-setup.sh 起点核验、env-setup.sh、precheck.sh --branch/--inject |
| **Revision** | 评估产出质量，回环给生产者，有迭代上限+停滞检测 | 产出后评估 | precheck.sh --test/--review、subagent 两阶段审查 |
| **Escalation** | 将无法解决的问题上报用户 | revision 无法解决时 | BLOCKED 处理、ASK 发现 |
| **Abort** | 终止以防损害，保留状态 | 继续有危险时 | dev server 期间 upstream checkout、保护分支误操作 |

## 三层记忆方案

| 层 | 工具 | 位置 | 用途 |
|----|------|------|------|
| 阶段状态 | comet state-machine.sh | `overlay/.swarm-yuan/state.yaml` | phase / verify_result / branch_status（survive compaction） |
| 任务进度 | superpowers progress ledger | `overlay/.swarm-yuan/sdd/progress.md` | Task N: complete（防重复派发） |
| 跨会话知识 | claude-mem（若装） | `~/.claude-mem/claude-mem.db` + ChromaDB | 决策/发现/gotcha，SessionStart(compact) 自动注入 |

> 推荐：state-machine.sh 管阶段 + progress ledger 管任务 + claude-mem 管跨会话知识。三者不冲突，各管一层。

## 完成检查表

- [ ] 改动仅在 `overlay/`（custom 或 patches），`precheck.sh --scope` 通过
- [ ] A 类已接入注册（registerRoute/registerNavEntry/registerComponent → bootstrap.ts 动态 import + flag 守卫）；B 类 patch 已入 `patches/series` 且 `npm run clean && npm run inject` 成功
- [ ] `npm test` 全绿（37 files），不退化于基线
- [ ] `precheck.sh --sensitive` 无敏感信息泄漏
- [ ] `precheck.sh --consistency` 业务规则 + 勾稽核对通过
- [ ] `precheck.sh --review`（ocr 若装则自动审查，否则手动 5 维度 + goal-backward）
- [ ] 已合入 main（`--no-ff`，`merge: <branch>`），未自动 push（除非用户确认）
- [ ] spec/plan 已归档到 `docs/superpowers/specs/` 与 `docs/superpowers/plans/`
- [ ] 发布仅 arm64.dmg + x64.zip；RELEASE-NOTES 已更新

## Tool 引用铁律

以下工具**只引用调用命令，不复制源码、不重新实现功能**，确保与本技能安全共存：

| 工具 | 引用方式 | 安装 |
|------|---------|------|
| **GitNexus** | `gitnexus analyze` / `gitnexus mcp`（MCP 图查询替代 grep） | `npm i -g gitnexus` |
| **graphify** | `graphify path A B` / `graphify explain X` / MCP server | `uv tool install graphifyy`（PyPI 双 y） |
| **ocr** | `ocr review --audience agent`（5 维度自动审查） | `npm i -g @alibaba-group/open-code-review` |
| **claude-mem** | observer 自动捕获；`search`/`timeline`/`get_observations` 检索 | `npx claude-mem install`（可选） |
| **gsd-core** | `/gsd-execute-phase` / `/gsd-verify`（goal-backward 运行时引擎） | `npx @opengsd/gsd-core --claude --global`（可选） |

> **gsd-core 安装器**只 prune `gsd-` 前缀目录；本技能（`ncwk-dev`，非 `gsd-` 前缀）在 `.agents/skills/` 下安全共存。
> **没有 `gsd-core init` 命令**——gsd-core bin 只是安装器；`gsd-tools init` 是 workflow-context 加载器（非 scaffolder）。
> gsd-core 未装时，降级为 swarm-yuan 自带的 state-machine.sh + subagent-orchestration.md 手动编排。

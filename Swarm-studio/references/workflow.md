# workflow.md — SwarmStudio 全流程总览（8 节点 × 9 要素）

> 本文件指导 Swarm-studio 技能的完整交付流程。每节点含 9 要素：①流程入口 ②参与方 ③前序依赖检查（Pre-flight）④质量门禁（标注类型）⑤分支处理（成功/失败/信息不足）⑥产出物归档（持久化/临时）⑦流程控制（暂停/恢复）⑧状态控制。末尾⑨完成检查表。

## 节点①需求理解

| 要素 | 内容 |
|------|------|
| ①流程入口 | 用户提出需求/bug/重构；或恢复中断会话（state-machine.sh status → claude-mem search） |
| ②参与方 | 用户 + 主会话（controller） |
| ③前序依赖检查 | **Pre-flight**：`bash assets/env-setup.sh`（Node>=23 / Python>=3.11 / git/gh/docker）；当前在 overlay 仓库；`npm run verify` 注入态干净 |
| ④质量门禁 | **Pre-flight**：需求是否清晰、是否落在 overlay 改造范围内（A/B 类可覆盖） |
| ⑤分支处理 | 成功→进②；信息不足→向用户澄清（批量汇总问一次，非逐个中断）；需求超出 overlay 范围→向用户说明限制 |
| ⑥产出物归档 | 临时：会话内需求摘要；持久：若装 claude-mem 则 observer 自动捕获 decision |
| ⑦流程控制 | 暂停点：需求澄清时等待用户；恢复：用户回答后继续 |
| ⑧状态控制 | `state-machine.sh init <change-name>`（phase=open）；记录 change 名称 |

## 节点②设计 spec（OpenSpec proposal）

| 要素 | 内容 |
|------|------|
| ①流程入口 | `assets/spec-template.md`；OpenSpec proposal 模式 |
| ②参与方 | 主会话（可派发 researcher subagent 调研现有代码） |
| ③前序依赖检查 | **Pre-flight**：节点①完成（state=open）；需求已澄清 |
| ④质量门禁 | **Revision**：spec 含背景/目标/非目标/决策记录/改造类型/Spec Delta/设计/测试策略 |
| ⑤分支处理 | 成功→进③；spec 不完整→补全后重审；复杂度低→可合并②③ |
| ⑥产出物归档 | **持久**：`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`（现有 29 files 规范） |
| ⑦流程控制 | 暂停点：等待用户确认 spec（尤其是决策记录与非目标） |
| ⑧状态控制 | `state-machine.sh transition design`（guard: open 产出物存在） |

**OpenSpec delta spec 格式**（spec-template.md §4）：
- `### ADDED Requirements` → `### Requirement: <名>`（用 SHALL/MUST）
- `#### Scenario: <场景名>`（4 个 hashtag）→ `- **WHEN** <条件>` / `- **THEN** <预期>`
- `### MODIFIED Requirements`（须含完整更新内容）
- `### REMOVED Requirements`（须含 Reason + Migration）
- design.md（可选，复杂变更）：Context / Goals/Non-Goals / Decisions(Rationale+Alternative) / Risks
- tasks.md：`- [ ]` checkbox 跟踪

## 节点③实施 plan（OpenSpec tasks + superpowers bite-sized）

| 要素 | 内容 |
|------|------|
| ①流程入口 | `assets/plan-template.md`；基于 spec 的 tasks.md 拆分 |
| ②参与方 | 主会话（controller 规划，可派发 planner subagent） |
| ③前序依赖检查 | **Pre-flight**：节点②完成（phase=design）；spec 已归档 |
| ④质量门禁 | **Revision**：plan 含 Goal/Tech Stack/文件结构表/Task 分解；每 Task 是 bite-sized（单 subagent 可完成）；标注 wave + depends_on（可选）+ files_modified |
| ⑤分支处理 | 成功→进④；plan 有矛盾→Pre-Flight Plan Review 批量汇总问用户 |
| ⑥产出物归档 | **持久**：`docs/superpowers/plans/YYYY-MM-DD-<topic>.md`（现有 30 files 规范） |
| ⑦流程控制 | 暂停点：等待用户确认 plan |
| ⑧状态控制 | `state-machine.sh transition build`（guard: build_mode + isolation 已设置）；写 progress ledger 初始 |

**plan 要点**：
- subagent-driven 推荐（每 Task 一 fresh subagent）；inline 备选
- Task 1 = 起点+分支核验；Task 2..N-1 = 编码+测试+commit；Task N = 合入 main（需用户确认）
- wave 并行：同 wave 的 executor 触碰不重叠关注点（gsd 模式，若装 gsd-core 用 /gsd-execute-phase）

## 节点④分支准备

| 要素 | 内容 |
|------|------|
| ①流程入口 | `assets/branch-setup.sh <branch-name>` |
| ②参与方 | 主会话 |
| ③前序依赖检查 | **Pre-flight**：起点核验 `git rev-parse HEAD == git rev-parse main`；工作树干净（文档除外）；不在保护分支（main / backup/pre-squash） |
| ④质量门禁 | **Pre-flight**：分支名匹配 `^(feat|fix|refactor|chore)/.+`；测试基线 `npm test`（37 files）记录 |
| ⑤分支处理 | 成功→`git checkout -b feat/<name>`→进⑤；HEAD≠main→报错（游离 commit）；工作树脏→提示 commit/stash |
| ⑥产出物归档 | 临时：基线测试结果（记入 plan） |
| ⑦流程控制 | 自动执行，无暂停 |
| ⑧状态控制 | `state-machine.sh set branch_status created` |

## 节点⑤编码实现（superpowers subagent 编排）

| 要素 | 内容 |
|------|------|
| ①流程入口 | references/subagent-orchestration.md（Spawn-Collect 循环）；references/dev-guide.md（A 类/B 类实现细节） |
| ②参与方 | controller（协调）+ implementer subagent（每 Task fresh）+ task reviewer subagent |
| ③前序依赖检查 | **Pre-flight**：分支已建（branch_status=created）；plan 已确认；progress ledger 已初始化 |
| ④质量门禁 | **Revision**：每 Task 后派发 task reviewer（spec 合规 + 代码质量两判决）；Critical/Important→派 fix subagent→重审。**Abort**：dev server 运行期间禁止 `git checkout`/`git clean` upstream |
| ⑤分支处理 | 成功（DONE）→标 ledger→下一 Task；DONE_WITH_CONCERNS→reviewer 重点看；NEEDS_CONTEXT→回答后重派；BLOCKED→见下方 |
| ⑥产出物归档 | 持久：`overlay/.swarm-yuan/sdd/progress.md`（Task N: complete commits base..head review clean）；implementer report 写文件非粘贴；A 类代码→`custom/`，B 类→`patches/NNN-*.patch` |
| ⑦流程控制 | **连续执行**：不在 Task 间停下来 check-in。停止仅因：无法解决的 BLOCKED / 阻碍进展的歧义 / 全部完成。上下文剩余≤25%→强制保存状态→暂停（gsd context-monitor 模式） |
| ⑧状态控制 | progress ledger（防重复派发）；若装 gsd-core 可调用 `/gsd-execute-phase <N>` |

**BLOCKED 处理（superpowers 铁律）**：1.上下文问题→提供更多上下文同模型；2.需要推理→更强模型；3.任务太大→拆分；4.plan 错了→上报人类。**绝不忽略 escalation，绝不迫使同一模型无变化重试。**

**A 类实现**（overlay/custom，优先）：
- 目录约定：`custom/client/`（.vue/.ts 组件、store）、`custom/server/`（Koa 后端）、`custom/hermes-agent-plugins/`
- 注册：`registries/client/` 的 registerRoute / registerNavEntry / registerComponent，经 `bootstrap.ts` 动态 import + `isFeatureEnabled` flag 守卫
- `npm run dev` HMR；entry.mts shim 复刻 upstream main.ts，在 `app.use(router)` 与 `app.mount()` 之间插入注册
- 后端：`custom/server/package.json` 用 CJS（无 `type:module`）避免 ERR_REQUIRE_ESM；改后端需重启 `serve-server.sh`

**B 类实现**（overlay/patches）：
- 先 `npm run verify` 确认注入态干净
- 临时改 upstream 文件 → `git diff > patches/NNN-<tag>-<desc>.patch`
- **dev server 运行期间禁止 `git checkout` 还原 upstream**（会破坏注入态）
- patch 末尾追加 `patches/series`；格式统一 diff，用 `HERMES_CUSTOM[Tag] BEGIN/END` 标识
- 路由前缀：`hermes_cli/` `plugins/` `agent/` `apps/` `assets/` `acp_` → hermes-agent（容错跳过）；其余 → hermes-studio（fatal）
- i18n：`node scripts/add-i18n-keys.mjs`；冲突：`git apply --reject`

## 节点⑥测试验证（gsd goal-backward + gstack/OCR 5 维度）

| 要素 | 内容 |
|------|------|
| ①流程入口 | `scripts/precheck.sh`（--test/--sensitive/--consistency/--review）；references/review-methodology.md |
| ②参与方 | 主会话 + task reviewer / final whole-branch reviewer subagent；若装 gsd-core 调用 `/gsd-verify` |
| ③前序依赖检查 | **Pre-flight**：所有 plan Task 完成（progress ledger 全 DONE）；分支有提交 |
| ④质量门禁 | **Revision**：`npm test`（37 files 全绿不退化）；`--sensitive`（敏感模式+私有 IP，url-guard 除外）；`--consistency`（幂等性）；`--review`（ocr 若装自动审查，否则手动 5 维度 + goal-backward） |
| ⑤分支处理 | 成功→进⑦；测试失败→回 ⑤ 修复；审查 Critical→派 fix subagent；**Escalation**：revision 循环无法解决→上报用户 |
| ⑥产出物归档 | 持久：审查报告（写文件）；若装 claude-mem observer 自动捕获 |
| ⑦流程控制 | 暂停点：ASK 类发现询问用户 |
| ⑧状态控制 | `state-machine.sh set verify_result pass`（或 fail） |

**gsd goal-backward 对抗验证**：核心口号「Task completion ≠ Goal achievement」。验证者从「阶段应交付什么」出发，**证伪** SUMMARY 叙事：FORCE 立场（假设目标未达成，直到代码库证据证明）；不信任 SUMMARY（记录的是 Claude 说了什么，验证代码实际有什么）；发现分类严格只有 BLOCKER / WARNING。

**gsd 6 测试契约**：1.练习真实代码非源码文本；2.无空真断言（LHS 须 SUT 计算）；3.无 pass-always 测试；4.测试声称路径（别 mock 整个 SUT）；5.完整 mock（只 mock I/O）；6.负空间反测。

**5 维度**：correctness / security / performance / maintainability / test-coverage。两遍清单：CRITICAL（SQL/竞态/注入/越权/路径穿越）+ INFORMATIONAL（命名/注释/风格）。处置：AUTO-FIX（机械修复）vs ASK（可能意见不一）。

## 节点⑦合入 main（需用户确认）

| 要素 | 内容 |
|------|------|
| ①流程入口 | plan-template.md Task N |
| ②参与方 | 主会话 + 用户（确认） |
| ③前序依赖检查 | **Pre-flight**：verify_result=pass；progress ledger 全 DONE |
| ④质量门禁 | **Escalation**：需用户明确确认方可合入 |
| ⑤分支处理 | 成功→`git checkout main && git merge --no-ff <branch> -m "merge: <branch>"`；用户拒绝→保留分支待议；冲突→rebase 后重跑 `npm test` |
| ⑥产出物归档 | 持久：merge commit；spec/plan 已在 docs/superpowers/ |
| ⑦流程控制 | **暂停点**：等待用户确认合入。**铁律**：除非用户明确要求，绝不自动 push 远端 |
| ⑧状态控制 | `state-machine.sh set branch_status merged`；`state-machine.sh transition archive` |

## 节点⑧构建发布（需用户确认）

| 要素 | 内容 |
|------|------|
| ①流程入口 | references/release.md |
| ②参与方 | 主会话 + 用户（确认发布） |
| ③前序依赖检查 | **Pre-flight**：已合入 main；`npm run verify` 干净；`precheck.sh --sensitive` 通过；RELEASE-NOTES 已更新 |
| ④质量门禁 | **Escalation**：需用户明确确认方可发布；**铁律**：release 仅 arm64.dmg + x64.zip |
| ⑤分支处理 | 成功→产物归档；构建失败→见 release.md 失败表；用户拒绝→不发布 |
| ⑥产出物归档 | 持久：`packages/desktop/release/SwarmStudio-0.6.23-arm64.dmg` + `.zip`（mac）/ `x64.exe`+`.zip`+`.msi`（win） |
| ⑦流程控制 | **暂停点**：等待用户确认发布 |
| ⑧状态控制 | `state-machine.sh set release_status done`（或 skipped） |

**build:dmg 5 步**：inject → build:full → `npm ci desktop` → `tsc main` → `electron-builder --publish never`（绕过 upstream `npm run dist`）。

## ⑨完成检查表

- [ ] 改动仅在 `overlay/`（custom 或 patches），`precheck.sh --scope` 通过
- [ ] A 类已接入注册（registerRoute/registerNavEntry/registerComponent → bootstrap.ts + flag 守卫）；B 类 patch 入 series 且 `clean && inject` 成功
- [ ] `npm test` 全绿（37 files），不退化于基线
- [ ] `precheck.sh --sensitive` 无泄漏；`--consistency` 勾稽通过；`--review` 审查通过
- [ ] goal-backward 对抗验证：SUMMARY 叙事被代码库证据证实（无 BLOCKER）
- [ ] 已合入 main（`--no-ff`，`merge: <branch>`），未自动 push
- [ ] spec/plan 已归档到 `docs/superpowers/specs/` + `plans/`
- [ ] 发布仅 arm64.dmg + x64.zip（若发布）；RELEASE-NOTES 更新
- [ ] `backup/pre-squash` 未被删除
- [ ] state-machine.sh 状态为 archive / release_status=done

## 状态机与三层记忆

- **阶段状态**：`scripts/state-machine.sh`（PROJECT_DIR 默认 `<project-root>/overlay`），PHASES=(open design build verify archive)。每节点转换调 `transition`，转换前 `guard` 检查准入。
- **任务进度**：`overlay/.swarm-yuan/sdd/progress.md`（superpowers progress ledger）。启动时 `cat`；标记完成的不重派；从第一个未完成恢复。
- **跨会话知识**：claude-mem（若装）observer 自动捕获 decision/discovery/gotcha，SessionStart(compact) 重新注入；未装则用 progress ledger + 手动 `overlay/.swarm-yuan/decisions.md`。

三者各管一层，不冲突。详见 references/memory-persistence.md。

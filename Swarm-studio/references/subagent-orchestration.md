# Subagent 编排模式 (Subagent-Driven Development)

> 整合自 [superpowers](https://github.com/obra/superpowers) 的 `subagent-driven-development` 方法论。
> 本文件指导目标技能的 workflow 节点⑤（编码实现）如何采用 subagent 编排模式。
> **仅引用方法论模式，不复制 superpowers 源码。**

## 核心理念

**为什么用 subagent？** 上下文隔离。为每个任务派发一个全新的 subagent，精确构造其指令与上下文，使其专注并成功完成任务。subagent **不继承**主会话的上下文与历史——你构造它正好需要的内容。这也保留主会话的上下文用于协调工作。

**核心公式（引自 superpowers）：**
> Fresh subagent per task + task review (spec + quality) + broad final review = high quality, fast iteration

## Orchestrator / Spawn-Collect 循环

主会话（controller）的职责是**协调**，不是直接编码：

```
1. 读 plan 一次，记录上下文 + 全局约束，创建 todos
2. Pre-Flight Plan Review — 扫描一遍，找出相互矛盾或违反全局约束的任务；
   批量汇总成一个问题问人（不是一个发现一个中断）
3. 每任务循环：
   a. 派发全新 implementer subagent（带 task brief）
   b. 若 implementer 提问 → 回答、提供上下文、重新派发
   c. implementer 实现、测试、提交、自审，回报状态
   d. controller 派发 task reviewer subagent（审查 spec 合规 + 代码质量）
   e. 若有问题 → 派发 fix subagent → 重新审查
   f. 标记任务完成 + 追加 progress ledger；下一个任务
4. 全部任务完成后 → 派发 final whole-branch reviewer → 收尾
```

## 文件交接（Context Hygiene）

**铁律：粘贴进 dispatch prompt 的内容会常驻 controller 上下文整个会话。** 所以交接用**文件路径**，非粘贴文本：

- task brief → 写入唯一命名的文件，prompt 里只给路径（"read this first — it is your requirements"）
- implementer 报告 → 写入 report 文件（`task-N-report.md`），prompt 里给路径 + 报告契约
- 审查包 → diff 写入文件，reviewer prompt 给文件路径

dispatch prompt 应含：(1) 一句话说明任务位置；(2) brief 路径；(3) 前序任务的接口/决策；(4) controller 对歧义的裁决；(5) report 路径 + 报告契约。

> 反模式（引自 superpowers）：一个真实会话的 dispatch 达 42k 字符，其中 99% 是粘贴的历史。

## 状态回报契约

implementer 回报**仅**短状态 + 提交 + 一行测试摘要 + concerns + report 路径：

| 状态 | 含义 | controller 处理 |
|------|------|----------------|
| `DONE` | 完成且自审通过 | 派发 reviewer |
| `DONE_WITH_CONCERNS` | 完成但有顾虑 | reviewer 重点看 concerns |
| `NEEDS_CONTEXT` | 需要更多信息 | 回答后重新派发 |
| `BLOCKED` | 无法继续 | 见下方处理 |

**BLOCKED 处理（引自 superpowers，不可忽略）：**
1. 上下文问题 → 提供更多上下文，同模型
2. 需要推理 → 用更强模型
3. 任务太大 → 拆分
4. plan 错了 → 上报人类

> "绝不忽略 escalation，也绝不迫使同一模型无变化地重试。"

## 两阶段审查

每任务完成后，派发 **task reviewer**，产出**两个判决**：

1. **Spec 合规** — 实现是否符合 spec/proposal 的要求
2. **代码质量** — 可读性、测试覆盖、错误处理、风格

若有 Critical/Important 发现 → 派发 fix subagent → 重新审查。Minor 发现记入 ledger，留待 final review。

**final whole-branch review** — 全部任务完成后，对整个分支做一次广审。

## 持久化进度（Progress Ledger）

**铁律：对话记忆不抗 context compaction。** 用 ledger 文件持久化进度：

- 位置：`<repo-root>/.swarm-yuan/sdd/progress.md`（或项目约定路径）
- 启动时 `cat` ledger；标记完成的任务 = DONE，不重新派发，从第一个未完成任务恢复
- 干净审查后追加：`Task N: complete (commits <base7>..<head7>, review clean)`

> 引自 superpowers："controllers that lost their place have re-dispatched entire completed task sequences — the single most expensive failure observed."

## 连续执行

**不要在任务之间停下来 check-in。** 执行 plan 的所有任务不停顿。停止的唯一理由：
- 无法解决的 BLOCKED
- 真正阻碍进展的歧义
- 所有任务完成

> "'Should I continue?' prompts and progress summaries waste their time."

## 模型选择

每次派发**显式指定模型**（省略会静默继承会话最贵模型）：
- 转录级任务（plan 已含完整代码）→ 便宜模型
- 集成任务 → 中档
- 架构与 final review → 最强模型

> "Turn count beats token price" — 最便宜模型在多步任务上要 2-3 倍轮次，reviewer/prose 实现者至少用中档。

## 构造 reviewer prompt 的禁忌

- 不要加开放式"检查所有用法"
- 不要让 reviewer 重跑 implementer 已跑过的测试
- **绝不预判发现**（"do not flag"、"treat as Minor at most"）— 让 reviewer 提出，在循环中裁决
- 全局约束块是 reviewer 的"注意力镜头"——从 spec 逐字复制精确值/格式/关系

## 与目标技能的整合

目标技能的 workflow 节点⑤应：
1. 引用本文件作为 subagent 编排指南
2. 在 plan-template.md 的 header 标注执行方式（subagent-driven 推荐 / inline 备选）
3. 在 scripts/state-machine.sh 中实现阶段状态持久化（survive compaction）

## superpowers v6 + comet v0.3 全量能力

> 来自 superpowers v6.1.1 + comet v0.3.9 源码调研。

### superpowers 14 个 Skills

| Skill | 用途 | swarm-yuan 落点 |
|-------|------|----------------|
| `brainstorming` | 代码前 Socratic 设计精炼 | 4-Phase SOP Phase 1 可引用 |
| `writing-plans` | 设计→2-5 分钟任务（精确文件路径 + 验证步骤） | spec §4 tasks 可引用 |
| `executing-plans` | 批量执行 + 人工检查点 | workflow 节点⑤可引用 |
| `subagent-driven-development` | 每任务新 subagent + 两阶段审查 | 本文件核心引用 |
| `dispatching-parallel-agents` | 并发 subagent 工作流 | wave 并行可引用 |
| `test-driven-development` | 强制 RED-GREEN-REFACTOR（删违规代码） | `--test` 可引用 |
| `systematic-debugging` | 4 阶段根因（root-cause-tracing/defense-in-depth/condition-based-waiting） | check 段可引用 |
| `verification-before-completion` | 确保"真的修了" | goal-backward 可引用 |
| `requesting-code-review` | 审查前清单 + 对照 plan + 严重度阻断 | `--review` 可引用 |
| `receiving-code-review` | 回应反馈 | 审查闭环可引用 |
| `using-git-worktrees` | 隔离工作空间 | 并行执行可引用 |
| `finishing-a-development-branch` | merge/PR/keep/discard 决策 + worktree 清理 | workflow 节点⑦可引用 |
| `writing-skills` | 编写新 skill 的元技能 | swarm-yuan 自身可引用 |
| `using-superpowers` | 启动引导（SessionStart hook 注入） | 生成 skill 可引用 |

### comet 5 阶段状态机

| 阶段 | 命令 | 产出 | swarm-yuan 落点 |
|------|------|------|----------------|
| Open | `/comet-open` | proposal.md, design.md, tasks.md | workflow 节点②③可引用 |
| Design | `/comet-design` | Design Doc, delta spec | 4-Phase SOP Phase 2 可引用 |
| Build | `/comet-build` | 实现代码, commit | workflow 节点⑤可引用 |
| Verify | `/comet-verify` | verification_report | check 段可引用 |
| Archive | `/comet-archive` | delta spec 同步 + 归档 | workflow 节点⑦可引用 |

### comet 关键能力（swarm-yuan 可能没用到）

| 能力 | 描述 | 价值 |
|------|------|------|
| **PreToolUse 写保护 hook** | `comet-hook-guard.sh` 在 open/design/archive 阶段硬阻止文件写入 | 防阶段越界 |
| **Phase-Entry 自洽检查** | 交叉检查 phase 字段 vs 产出物存在性（`phase: build` + 空 `design_doc` = 跳过设计 → 阻断） | 防非法跳阶 |
| **Context compression handoff** | Design Doc + SHA256 hash 引用替代全量 Spec 摘录（25-30% token 节省，100% 测试通过，95% spec 覆盖） | token 优化 |
| **Red Flags 反合理化清单** | 5 条 agent 自检（不能替用户决定/无大小例外/历史偏好≠当前确认/不反对≠同意/未验证≠通过） | 执行准则可引用 |
| **Preset 升级标准** | hotfix/tweak 自动检测是否需升级为 full workflow（3+ 文件/架构变更/新公共 API） | 因地制宜可引用 |
| **`build_pause: plan-ready`** | 计划生成后可恢复暂停（非 build_mode） | 4-Phase SOP 可引用 |
| **Debug Gate 协议** | 失败时强制加载 `systematic-debugging` skill + 根因定位前不修源码 | check 段可引用 |
| **Decision Point Protocol** | 9 个阻断节点 + "无大小例外"规则 | 疑虑确认可引用 |
| **Dirty-worktree 协议** | 恢复时处理未提交变更 | 状态恢复可引用 |
| **29 平台安装器** | 每平台目录映射 | 跨工具部署可引用 |
| **`comet-state check --recover`** | 压缩后结构化恢复 + 重跑自洽检查 | 状态恢复可引用 |
| **`comet-state scale`** | 确定 verify 阶段的验证级别（small/medium/large） | `--review` 分档可引用 |

## Ruflo v3.21 全量能力（agent meta-harness——swarm-yuan 须知道但可选引用）

> 来自 Ruflo（原 Claude Flow）v3.21.1 源码调研。323 MCP 工具 + 45 CLI 命令 + 33 插件 + witness 验证 + federation 跨机器协作。

### 核心定位

Ruflo 是 agent meta-harness——把 Claude Code / Codex 从单上下文助手变为协调式、自学习、多代理 swarm。`npx ruflo init` 一键赋予 Claude Code "神经系统"：agents 自组织为 swarm、从每个任务学习、跨会话记忆、跨机器安全通信。

### 关键能力（swarm-yuan 可能没用到）

| 能力 | 描述 | swarm-yuan 落点 |
|------|------|----------------|
| **3 层模型路由** | Tier 1 确定性 codemod（~1ms/$0）→ Tier 2 Haiku（~500ms）→ Tier 3 Sonnet/Opus；`[CODEMOD_AVAILABLE]`/`[TASK_MODEL_RECOMMENDATION]` 标记触发 | workflow 节点⑤按任务复杂度路由模型 |
| **Swarm 编排** | init swarm → spawn agents via Task tool（MCP 协调，Task 执行）；防漂移默认：层次拓扑、maxAgents 6-8、专业化策略、raft 共识 | 复杂变更的 Dynamic Workflow 替代/增强 |
| **Dual-Mode 协作** | 🔵 Claude + 🟢 Codex 并行 workers + 共享 `collaboration` 记忆命名空间 + 预置模板（feature/security/refactor/bugfix） | 跨 AI 交叉验证（gsd-core cross-AI 的增强版） |
| **AgentDB 向量记忆** | SQLite + HNSW 向量索引（~3x faster vs brute force）；RVF 便携格式跨平台传输；Claude Code ↔ AgentDB 桥（自动导入 ~/.claude/projects/*/memory/*.md） | claude-mem 的增强替代（HNSW vs ChromaDB） |
| **自学习循环** | RETRIEVE(HNSW) → JUDGE(verdicts) → DISTILL(LoRA) → CONSOLIDATE(EWC++)；SONA 神经模式 + ReasoningBank + 轨迹学习 → router 89% 路由准确率 | 记忆闭环的增强（从"记录"升级为"学习"） |
| **Witness 验证系统** | 每个已文档化修复用 SHA-256 指纹 + 标记子串 + Ed25519 签名证明；`ruflo verify` 验证安装字节匹配签名；三层回归保护（smoke + witness + temporal history） | `--stable-diff` 的增强（不只是检查"改了没"，而是密码学证明"字节匹配"） |
| **Agent Federation** | 跨机器/组织 agent 协作（mTLS + ed25519 challenge-response，无 API key）；14 类 PII 检测（BLOCK/REDACT/HASH/PASS）；行为信任评分；合规模式（HIPAA/SOC2/GDPR）；WireGuard mesh | 跨团队/跨仓库协调（--impact 的增强版） |
| **GOAP A* 目标规划** | 自然语言目标 → 状态空间 A* 搜索 → 可执行 agent 计划 + 自适应重规划 | 4-Phase SOP Phase 3（七步推演）的增强版 |
| **MetaHarness 自审计** | 给 harness 打分（1-100）+ 基因组（7 段）+ MCP 扫描 + 威胁建模 + 漂移检测 + MAP-Elites 进化 + redblue 对抗测试 + GEPA 学习 | swarm-yuan 自我迭代的增强（`--cognition` 的"元"层） |
| **IPFS 插件注册** | 去中心化不可变插件分发（IPFS via Pinata） | 插件分发（generate-skill.sh 的增强） |
| **Arena 竞争性测试** | 把 agent 策略作为程序在锦标赛中对决 + 爬山进化 + 共进化 | 目标技能质量评估的增强 |
| **Gaia 基准测试** | `/gaia`/`/gaia-run`/`/gaia-leaderboard` 竞争性基准 | 目标技能性能对比 |
| **Headless 后台实例** | `claude -p`（print/pipe 模式）并行后台工作 + `--max-budget-usd` + `--fallback-model` + `--resume` + `--fork-session` | Dynamic Workflows 的 CLI 级替代 |
| **1 MESSAGE = ALL OPERATIONS** | 批量所有 todos/agent spawns/file ops/terminal ops/memory ops 在一条消息中 | 并发效率（减少消息往返） |
| **自动 swarm 触发** | 3+ 文件变更/特性/重构/API+测试/安全/性能/schema 变更 → 自动触发 swarm；单编辑/简单修复/文档/配置 → 跳过 | 因地制宜（spec 分级的增强版） |

### Ruflo 行为规则（CLAUDE.md——目标技能可参考）

- 做被要求的事，不多不少；优先编辑而非创建；除非要求不创建文档
- **1 MESSAGE = ALL RELATED OPERATIONS**——批量所有操作在一条消息中
- MCP 协调；Task 执行——先调 MCP，再调 Task
- 防漂移 swarm 默认：层次拓扑、maxAgents 6-8、专业化、raft 共识、混合记忆、HNSW on、SONA on
- DDD + 有界上下文；文件 <500 行；类型化接口；TDD London School；事件溯源；边界输入验证

### 与 swarm-yuan 其他运行时的协同

| 方法论 | 重叠/增强 |
|--------|----------|
| superpowers subagent | Ruflo swarm 是增强版（6-8 agents + raft 共识 vs 单 subagent） |
| comet state-machine | Ruflo session 持久化是增强版（SQLite + HNSW vs YAML） |
| claude-mem | Ruflo AgentDB 是增强版（HNSW + 自学习 vs ChromaDB + 观察） |
| gsd-core goal-backward | Ruflo GOAP A* 是增强版（状态空间搜索 vs 对抗验证） |
| Dynamic Workflows | Ruflo swarm + Dual-Mode 是 Claude Code 原生 WF 的替代/增强 |
| gstack review | Ruflo MetaHarness 自审计是"审查的审查"（元层） |

> **swarm-yuan 不要求安装 Ruflo**——但如果项目已装，目标技能可引用其 swarm/memory/federation 能力。未装时降级为 superpowers subagent + claude-mem + gsd-core。
4. 在 dev-guide.md 的"任务流程填充"段引用本编排模式

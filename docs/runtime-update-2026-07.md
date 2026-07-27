# 运行时升级与功能差异报告（2026-07-26）

> 本报告记录 `swarm-yuan/research/` 下 11 个外部运行时仓库的对齐情况：6 个升级到最新稳定版，5 个已最新。每个升级项附功能差异与**整合建议**（建议的落地情况见 §3"整合吸收落地清单"）。
>
> 口径：本报告是留底文档，不进 `facts.conf` 单一事实源（运行时版本号不在 catchphrase 口径内）。运行时仓库本身是 `research/` 下未追踪的嵌套 git 仓库，升级不产生 swarm-yuan 自身的 git diff--本报告是升级的唯一留底。

## 1. 升级总览

| 运行时 | 接线层 | 旧版本 | 新版本 | 范围 commit 数 | 状态 |
|---|---|---|---|---|---|
| claude-mem | 深度接线 | v13.11.0 | v13.12.4 | ~6 个 release | ✅ 升级 |
| graphify | 深度接线 | v0.9.19 | v0.9.27 | 108 | ✅ 升级（origin/v8 线性路径）|
| gsd-core | CLI 接线 | v1.7.0 | v1.8.0 | 91 | ✅ 升级 |
| open-code-review | 深度接线 | v1.7.12 | v1.7.17 | 67 | ✅ 升级 |
| ruflo | 方法论引用 | v3.32.4 | v3.32.9 | 8 个修复 | ✅ 升级 |
| superpowers | 方法论引用 | v6.1.1 | v6.2.0 | SDD 重构 + 压缩扫荡 | ✅ 升级 |
| ECC | 方法论引用 | v2.0.0 | v2.0.0 | -- | ⊙ 已最新 |
| comet | CLI 接线 | 0.3.9 | 0.3.9 | -- | ⊙ 已最新 |
| gitnexus | 深度接线 | v1.6.9 | v1.6.9 | -- | ⊙ 已最新 |
| openspec | CLI 接线 | v1.6.0 | v1.6.0 | -- | ⊙ 已最新 |
| gstack | 方法论引用 | （无 tag）| （无 tag）| -- | ⊙ 已最新（main 跟随）|

### graphify 版本路径说明（重要）

`research/graphify` 存在两条无共同祖先的谱系：
- **v0.9.x 线**（`origin/v8`，生产主线）：40 语言 / 10+ IDE 平台 / strict PreToolUse hook / vs mem0/supermemory 基准。本次升级路径 v0.9.19 -> v0.9.27，`git merge-base v0.9.19 v0.9.27 = v0.9.19`，108 个 commit，2026-07-18 ~ 2026-07-26。
- **v1.0.0 线**（commit `0a31c08`，不在 `origin/v8`）：13 语言 / 单平台 / "Karpathy /raw folder" 框架，2026-04-05（比 v0.9.19 旧 3 个月），是独立且更不成熟的并行代码库。

**本次取 v0.9.27（v0.9.x 线），不取 v1.0.0**。理由：v1.0.0 与 v0.9.19 无共同祖先（`git merge-base` 返回空），是异源旧分支；取它会丢失当前生产线的 40 语言/10 平台能力。

## 2. 逐项功能差异

### 2.1 claude-mem（v13.11.0 -> v13.12.4）

**核心用途**：Claude Code（及 Codex/Cursor/Antigravity CLI/Windsurf）的持久记忆压缩系统--自动捕获工具使用观察、生成语义摘要、通过 hooks（捕获）+ worker 服务（压缩）+ Chroma 语义搜索（检索）跨会话可用。

**新功能**：
- **v13.12.0 双车道云同步（SyncHub，PR #3333）**：6 阶段同步架构--(P1) 每用户 Cloudflare Durable Object 同步枢纽 `workers/sync-hub`；(P2) 客户端 apply 路径 + schema 迁移 v41；(P3) 枢纽 push/pull 传输 + mutation outbox（持久本地变更队列，离线/重试存活）；(P4) advisory WebSocket 速度层（"正确性从不依赖 socket 存活"）；(P5) 护栏 + 监控（kill switch / watchdog / canary / 全同步矩阵 E2E）；(P6) canonical v2 projection pipeline。**默认关闭**（`CLAUDE_MEM_CLOUD_SYNC_HUB_URL` 空）。
- **v13.11.0 worker 原生云同步（PR #3182）**：独立 `cloud-sync.mjs` daemon 退役，worker 自身同步记忆；schema v40 自修复。
- **v13.12.2 `docs/merge-rubric.md`**（新工件）：bug-fix PR 的验收门槛，从 54-PR 合并扫荡中提炼。
- **v13.12.2 54 社区 bug-fix PR 合并**：根因修正 ONLY，拒绝 guards/circuit-breakers/fallbacks/retries/fail-open/self-healing/truncation。

**关键修复**：
- **v13.12.1 版本 oracle 单源**：4 个 worker-script resolver 改为按**版本排序、永不按 mtime**，共享一个确定性 version oracle。此前 mtime 排序导致重启风暴（一天 2,424 次回收）。
- **v13.12.3 SIGKILL-the-corpse**：hook 不再委托垂死 worker 回收自己；版本不匹配时 hook 自身读 PID 文件 -> `SIGKILL` 旧 worker -> 等端口关闭 -> 自己 spawn 新版本。垂死 worker 的 successor handoff 仅服务 CLI 发起的 `claude-mem restart`。

**行为变更/弃用**：无顶层 CLI 子命令变化；技能集字节级不变（18 skills）；`/cloud-sync` skill 为 SyncHub 重写。

**整合建议**（落地见 §3.6）：
1. "单一 version oracle、永不按 mtime 排序"作为 self-check 断言（G10）--选版本/候选的路径必须用全序（version > capability > lexical）。
2. Merge Rubric 作为反模式门禁模板--拒绝"survive 失败而非 correct 根因"的 generated gate/skill。
3. 两车道同步（持久 outbox + advisory 快路径 + kill switch/watchdog/canary）作为多运行时/多设备同步模式参考。
4. SIGKILL-the-corpse 作为子代理/进程编排的生命周期模式--回收 stale worker 时由 supervisor 而非垂死进程 own kill+respawn。

### 2.2 graphify（v0.9.19 -> v0.9.27）

**核心用途**：AI 编码助手的知识图谱构建器--`/graphify` 把项目（代码经 tree-sitter AST，文档/PDF/图片/视频经 LLM 语义 pass）映射为可查询图（`graph.json` + `graph.html` + `GRAPH_REPORT.md`）。查图而非 grep 文件。每条边标 `EXTRACTED`/`INFERRED`/`AMBIGUOUS`。本地优先（代码解析不用 LLM）。

**新功能**（v0.9.20-27）：
- **v0.9.27 C# 命名空间感知成员调用解析**（#1609）：typed receiver 经 `using`/scope 解析，`base.`/`this.field` receiver，经 `inherits` 链的继承成员查找。JS/TS 非相对 import 经 `jsconfig.json`/`tsconfig.json` `baseUrl`/`paths` 解析（#2153）。Python 装饰器创建图边（#2154）。
- **v0.9.26 Windows hook 重建超时武装**（#2148）：`threading.Timer` fallback（Windows 无 SIGALRM），`GRAPHIFY_REBUILD_TIMEOUT` 不再是静默 no-op。Bash `source` 文件调用得到 `calls` 边（#2141）。
- **v0.9.25 协议改 MIT -> Apache 2.0**（显式专利授权 + 专利报复 + 贡献条款；MIT 保留为 `LICENSE-MIT`）。移除死代码 `.graphifyinclude`（#2112）。
- **v0.9.24 MCP `get_neighbors`/`get_community` 遵守 `token_budget`（默认 2000）**，截断在顶部宣告（#2069）。
- **v0.9.23 `graphify path`/MCP `shortest_path` 确定性 + 每跳真实关系标注**（#2074）。`query` 不再丢弃超预算答案（种子按跳距排序，命名种子始终先渲染）。
- **v0.9.22 `graphify god-nodes` CLI 子命令**；`--output` 作为 `--out` 别名（#2004）。
- **v0.9.21 Ollama 自动检测 `OLLAMA_HOST`**（不仅 `OLLAMA_BASE_URL`）（#1940）。Barrel re-export 链解析（#1983）。
- **v0.9.20 graphify-first nudge 匹配 Claude Code 的 Grep 工具**（不仅 Bash）（#1986）。

**新 CLI/标志/hook**：新子命令 `graphify god-nodes`/`god_nodes`；新别名 `--output`；新 MCP 参数 `token_budget`；新 env `OLLAMA_HOST` 检测；`GRAPHIFY_REBUILD_TIMEOUT` 在 Windows 实装。strict PreToolUse hook（v0.9.19 引入，本范围细化）：`graphify install --project --strict` 装一个 PreToolUse hook，首次原始源码读取时 `permissionDecision: "deny"` 重定向到 `graphify query`，然后降级为软 nudge；每会话至多触发一次；fail open。

**行为变更/弃用**：协议 MIT -> Apache 2.0（向后兼容）；移除 `.graphifyinclude`（用 `.graphifyignore` 的 `!` 否定）；安装器不再覆盖不可解析的 settings 文件；`graphify uninstall` 不再删除用户自写的 `### graphify` 段。

**整合建议**（落地见 §3.3）：
1. **honest-edge provenance（EXTRACTED/INFERRED/AMBIGUOUS）作为记忆模式纪律**--每条 swarm-yuan 写回的记忆/断言应带溯源标签，`graphify diagnose` 对无源证据的 code-typed 节点标 `verification: "unverified"`。直接可移植的反幻觉机制。
2. **prompt-fingerprinted cache namespacing**--语义缓存条目按提取 prompt 的 fingerprint 命名空间化，prompt 变更只失效受影响条目。可移植到 swarm-yuan 的 cached 探查/分析。
3. **atomic-write + shrink-guard + fail-closed 作为工件完整性模式**--JSON 工件写临时文件再 `os.replace`；shrink guard 拒绝用更小的不完整图覆盖更大的完整图；不可解析文件 fail closed。
4. **token-budgeted、truncation-announced MCP/子代理输出**--每个工具/子代理响应声明 token 预算、按查询相关性排序、被查询目标保证不被截断、顶部宣告截断内容。
5. **strict PreToolUse "deny-then-downgrade" hook 模型**--hook deny 首次原始读取、重定向到结构化查询、然后降级为软 nudge、每会话至多一次、fail open。比 advisory `additionalContext` 更高带宽的门禁模型。

### 2.3 gsd-core（v1.7.0 -> v1.8.0）

**核心用途**：GSD Core（"Git. Ship. Done."）是上下文工程 + spec 驱动开发框架，驱动 AI 编码代理经 5 步阶段循环：**Discuss -> Plan -> Execute -> Verify -> Ship**。通过在 fresh-context 子代理中跑重研究/规划/执行、保持主会话精简、结构化工件（STATE.md/CONTEXT.md）跨会话存活来解决上下文腐化。

**新功能**（91 commits）：
- **可逆性评级（reversibility tagging，#1951）**：plan 记录 `<reversibility rating="reversible|costly|one-way">`；`one-way` 自动插 `checkpoint:decision`；`costly` 标记但不阻断；"不确定时按 reversible"避免 checkpoint 疲劳。`--no-reversibility-gates` 覆盖。
- **`<precondition>` 任务元素（Design by Contract，#1949）**：任务前可选元素，未满足则 halt with `checkpoint:human-verify`。与后置条件（`<verify>`/`<done>`/`<acceptance_criteria>`）+ 不变量（`must_haves.truths`）配合。
- **破窗台账（broken-windows ledger，#1950）**：`WINDOWS.md` 工件跨阶段累积 stubs/TODOs/skipped tests/unrun verifies/unmet truths；`/gsd-ship` **在有 open 条目时阻断**（`ship:pre` 门禁，`artifact-frontmatter-equals` 谓词 on `open_count == 0`）。新 `gsd-tools windows status|append|waive|fixed` 子命令。
- **tracer-first planning 默认（#1945）**：每个 plan 默认 LEAD 一个生产质量端到端"tracer"切片；post-tracer 反馈门禁 halt-on-fail（自治）或 `checkpoint:human-verify`（交互）。
- **gsd-debugger 可靠性套件（Epic #1957）**：多信号 fix-acceptance 护栏（5 信号：目标测试 + mutation check Stryker + no-op/behavior-deleting detector + adjacent/held-out tests + revert-and-reconfirm）；Spectrum-based fault localization（Ochiai，#1959）；RCA 分支（fishbone + AND-gate，#1960）；bug-taxonomy 分类 + 策略路由（Bohrbug/Heisenbug-Mandelbug/Concurrency，#1961）；regression-test hardening PBT（#1962）；blameless-postmortem Prevention block（#1963）；semantic KB recall via MemPalace（#1964）。
- **Claude orchestration capability（BETA，默认关）**：采用 Claude Code 的 Workflow 工具（`/effort ultracode`）作为可选并行执行后端。
- **Honest verifier**：verify-phase 对非可推断的 `backstop` truths 弃权（不 false-pass）；直接跑声明的 probe 脚本（不信 SUMMARY 自报 PASS）；阻断 phase-modified 源文件含未追踪 `TBD`/`FIXME`/`XXX` 债务标记前进。

**新 CLI/标志**：`gsd-tools windows status|append|waive|fixed`；`gsd-tools claude-orchestration detect-backend|emit-workflow`；`gsd-tools state rebuild`；`--no-reversibility-gates`、`--no-tracer`、`--failure-class`。

**行为变更/弃用**：移除 Gemini CLI 运行时（"用 Antigravity CLI 代替"）；验证 staleness 改用 git commit time（非 fs mtime）；ReDoS 加固；phase-directory 解析对跨项目碰撞 fail loud。

**整合建议**（落地见 §3.1、§3.2）：
1. **reversibility-tagged 决策门禁**--把 `reversible/costly/one-way` 三级作为决策属性：one-way 决策自动升级到 UserChallenge（需人工 checkpoint）。
2. **broken-windows ledger 作为跨阶段 ship 门禁**--`WINDOWS.md` 风格缺陷登记，ship 前任何 open 条目阻断。
3. **multi-signal fix-acceptance 护栏（反过拟合）**--5 信号门禁，尤其"revert-and-reconfirm"信号捕捉只因偶然状态通过的修复。
4. **bug-taxonomy-routed debugging**--先分类失败类（Bohrbug/Heisenbug/Concurrency），再经显式表路由技术；SBFL 在 Heisenbug 上明确禁止（flaky 谱毒化排名）。
5. **honest-verifier 弃权 + 债务标记阻断**--对非可推断 truth 弃权而非 false-pass；直接跑 probe 脚本；阻断含未解 `TBD`/`FIXME`/`XXX` 的前进。

### 2.4 open-code-review（v1.7.12 -> v1.7.17）

**核心用途**：OpenCodeReview（`ocr`）是 AI 驱动的代码审查 CLI（阿里巴巴内部工具开源）。读 Git diff，把变更文件发给可配置 LLM（经带 tool-use 的 agent），生成行级精度结构化审查评论。核心理念：**确定性工程 × agent 混合**--硬约束（精确文件选择、智能文件捆绑、细粒度规则匹配、外部定位/反思模块）处理"绝不能错"的；agent 处理动态决策与上下文检索。

**新功能**（67 commits）：
- **原生 OpenCode 集成（#498）**：`@opencode-ai/plugin` TS 插件，注册 `ocr_review` + `ocr_health` 工具 + `ocr-review` slash command。支持 `preview=true`（仅列将审查文件不用 LLM）。
- **iFlytek Spark 内置 LLM provider（#485）**：OpenAI 兼容端点。
- **GraphQL（.graphql/.gql）allowlist + 规则（#491）**：schema 演进/破坏性变更/命名/资源限制规则。
- **Julia（.jl）allowlist + 规则（#501）**：排除 Pkg `test-dir` 约定。
- **Rust 宏正确性检查（#475）**：`macro_rules!`/proc-macro 脚枪--`$expr` 双求值、缺 `$crate::`、未括号展开优先级、proc-macro panic 而非 `compile_error!`。仅在宏被定义时触发（保持精度优先）。
- **PO/Pot 代码审查规则（#404/#406）**：gettext `.po` 翻译文件 + `.pot` 模板。
- **Gerrit CI 集成示例（#401）**：stdlib-only `post_review.py`，一次批量 Gerrit POST。
- **Windows `install.ps1`（#397）**：校验和验证的一行安装。

**新 CLI/标志**：OpenCode 插件参数（`from`/`to`/`commit`/`resume`/`exclude`/`model`/`concurrency`/`timeoutMinutes`/`maxTools`/`maxGitProcesses`/`preview`）；新 slash command `ocr-review`；`--end-of-options` 守卫（git >= 2.24）。

**行为变更/弃用**：diff 解析修复（merge commit 对第一 parent 审查）；LLM 循环竞态修复（per-`RunPerFile` 会话作用域异步记忆压缩）；配置 round-trip 保留手编 `timeout_sec`。

**整合建议**：
1. **确定性工程 × agent 混合作为审查模式模板**--硬约束处理"绝不能错"的（精确文件选择、智能捆绑、细粒度规则匹配），agent 处理动态决策。
2. **四层规则优先级链 + `merge_system_rule`**--`--rule` flag > 项目 `.opencodereview/rule.json` > 全局 > 内嵌 `system_rules.json`，first-match-wins，可选合并。可移植到 swarm-yuan 的项目级门禁叠加框架默认。
3. **外部定位 + 反思模块**--position anchor 门禁（验证引用的行/文件匹配问题）+ reflection 门禁（复查评论内容对代码）作为两个质量门禁。
4. **per-language 规则文档注册表 + 精度优先偏置**--每语言规则文档，每规则"仅在 X 存在时触发"谓词守卫。
5. **async per-conversation 记忆压缩（竞态修复）**--每个 `RunPerFile` 会话 own 其压缩状态，防跨代理历史拼接。

### 2.5 ruflo（v3.32.4 -> v3.32.9）

**核心用途**：Ruflo（前 Claude Flow）是 Claude Code 和 Codex 的 **agent meta-harness**--用 100+ agents、协调 swarm、自学习记忆（AgentDB + better-sqlite3）、federated 通讯、MCP server、hooks、密码学 witness/验证系统包装模型的执行层。

**新功能**（8 个修复，无新 CLI 命令/标志）：
- **跨平台（Windows 原生）plugin hooks（#2721）**：把每个 hook 命令从 `/bin/bash -c '...'`（Windows 原生失败）改成 `node -e` bootstrap 解析 `scripts/ruflo-hook.cjs`--"同一命令串在 Windows/macOS/Linux 不变运行"。
- **真 memory-DB 完整性检查进默认 `doctor`（#2748）**：之前仅 `existsSync()+statSync()`（任何文件都 PASSED）；现在默认跑 `checkMemoryStructuralIntegrity`（有界、WAL-aware `PRAGMA quick_check`）；确定性 malformed DB 映射到 `fail` 非 `warn`。
- **拒绝不安全 sql.js whole-image 写（live native WAL writer 下，#2749）**：memory CRUD 若回退到 sql.js read-modify-export-rename 路径，存在 `-wal`/`-shm` sidecar（live native 连接证据）时**拒绝**，返回 typed `success: false`。
- **statusline 真模型名 + worktree-aware 版本解析（#2747）**：`getUserInfo()` 不再硬编码 `'Opus 4.6 (1M context)'`；`getPkgVersion()` 加纯 fs worktree-root resolver（解析 worktree `.git` 文件指针恢复主仓根，无 `git rev-parse` spawn）。
- **`memory_search` namespace 修复（#2722）**：MCP 工具处理器把省略的 `namespace` 强制为字面 `'default'`，击败搜索层 `|| 'all'` 扇出回退。
- **defense-in-depth better-sqlite3 去重（#2746）**：强制单一去重 `better-sqlite3@12.9.0`（修补 SQLite 3.53.0，修复 SQLite WAL-Reset Bug）；close 前 `wal_checkpoint(TRUNCATE)`。

**新 hook 机制形态**：`node -e` bootstrap hook 模式（`process.argv=[...];require(path.join(CLAUDE_PLUGIN_ROOT,'scripts','ruflo-hook.cjs'))`）是新跨平台 hook 调用标准，替代 shell-based hooks。

**行为变更**：`checkMemoryDatabase` 报告行重标"Memory Database Presence"（诚实化存在-only 范围）；malformed unencrypted DB 现 fail（原 warn）；`better-sqlite3` 加到 `@claude-flow/cli` optionalDependencies，每条路径在 `MODULE_NOT_FOUND` 时降级 sql.js。

**整合建议**：
1. **witness-attested 质量门禁**--三层回归模型（行为 smoke + 密码学 SHA-256/marker-substring/Ed25519 witness manifest + 时序 `history.jsonl` for bisection）。每个 swarm-yuan 门禁可证明其载荷检查仍在位。
2. **sidecar-presence refusal 作为并发安全门禁**--"若 `-wal`/`-shm` 存在则拒绝不安全写"泛化为协作写入者检测门禁。
3. **`node -e` 跨平台 hook bootstrap**--生成带 hooks 的技能应采用此形式（无 shell 展开），直接关联 swarm-yuan 的"11 运行时整合"声明。
4. **tiered native->fallback doctor 检查**--"优先 native `integrity_check`，回退 sql.js main-image-only，各自诚实标注"分层是优雅降级验证门禁的模板。
5. **worktree-root resolver 无 `git` spawn**--纯 fs `.git` 文件指针解析器，延迟敏感模式可用。

### 2.6 superpowers（v6.1.1 -> v6.2.0）

**核心用途**：跨 harness 技能包（Claude Code/Codex/Cursor/Kimi/Pi/Antigravity/OpenCode/Gemini）发~14 个行为塑造开发技能 + SessionStart bootstrap hook。技能以 markdown + prompt 模板 + shell 脚本形式；`evals/` harness 用 LLM 评判真实代理会话。

**新功能**：
- **SDD plan-scoped workspace**：`.superpowers/sdd/` 之前无 plan 身份或生命周期--后续 plan 会读前 plan 的进度账本当自己的（实战观察到"三轮污染"）。现 `sdd-workspace` 要求 plan 文件、解析 `.superpowers/sdd/<plan-basename>/`；ledger 首行命名其 plan；**最终审查干净后删除 workspace**（git 历史是持久记录）。
- **resume-based 修复环 + 五轮熔断**：修复环改用"resume 原实现者语义而非 fresh dispatch"：R1-3 resume 原实现者处理 open findings；R4-5 fresh dispatch 更强模型；R=5 熔断，controller **逐条 adjudicate** 每个 open finding（每条 adjudication 入 ledger；禁止静默丢弃）。
- **scoped re-review prompt**：新模板 `re-review-prompt.md`--re-reviewer 只验修复（per-finding verdicts ADDRESSED/NOT ADDRESSED）+ 检查 fix diff 新破坏，不重读全任务。out-of-scope 观察入 ledger 不入环。
- **`writing-good-tests.md`（替换 `testing-anti-patterns.md`）**：六规则正向目录，每条先给 GOOD 示例 + 吸收可证伪性纪律："说出会让该测试失败的生产改动，期望独立于被测代码推导"+ 闭合 **Mutation Check**。硬止两类陷阱：**string-presence trap**（grep 式测试伪造可证伪--可观察的是行为不是文本）+ **change-detector trap**（常量断言能失败却保护不了什么）。
- **Windows SessionStart hook via Git Bash**：hook 命令串以引号路径开头，破坏 PowerShell/cmd.exe；现声明 `shell: "bash"`，Claude Code ≥ 2.1.81 解析为 Git for Windows。
- **branch-wide 技能压缩扫荡**：recap/persuasion/social-proof 段跨~12 技能移除；guard 段转为 house **Excuse/Reality rationalization 表**。每次剪切经子代理探针微测；一次可测量降级行为的剪切（TDD 的"Why Order Matters"）被重作为 rationalization 行而非发布。
- **`finishing-a-development-branch` 不再提供丢弃工作**：完成菜单去掉"Discard this work"。

**新工件**（无新技能目录）：`skills/subagent-driven-development/re-review-prompt.md`（新文件）；`skills/test-driven-development/writing-good-tests.md`（新文件，替换 `testing-anti-patterns.md`）；`skills/using-superpowers/references/gemini-tools.md`（恢复）；新 hook 机制 `shell: "bash"` 声明。

**行为变更/弃用**：SDD workspace 改 per-plan 且最终审查干净后删除（breaking for 现有 scratch 目录）；修复环语义改 resume（R1-3）而非总 fresh dispatch；`testing-anti-patterns.md` 移除（折入 `writing-good-tests.md`）；`finishing-a-development-branch` Option 2 现真创建 PR/MR 并报告 URL。

**整合建议**（落地见 §3.4、§3.5）：
1. **plan-scoped 持久进度账本**--`.superpowers/sdd/<plan-basename>/` 模式：per-plan workspace、首行命名 plan、最终审查干净后删除、是 compaction 后的 resume map。
2. **resume-based 修复环 + 五轮熔断**--R1-3 resume / R4-5 fresh+更强模型 / R=5 adjudicate 模式，eval-验证的子代理模式。
3. **scoped re-review prompt 作为验证门禁**--re-reviewer 只判决 fix diff（ADDRESSED/NOT ADDRESSED per finding + 新破坏检查），out-of-scope 入 ledger。
4. **可证伪性门禁 + Mutation Check**--"说出会让该测试失败的生产改动"+"期望独立于被测代码推导"+ 闭合 mutation check + 硬止 string-presence/change-detector 陷阱。
5. **技能文本编辑的微测门控**--每次剪切经子代理探针微测；可测量降级行为的剪切被重作而非发布；rationalization 表形式（Excuse/Reality 行在代理 rationalization 中途触发处）。

## 3. 整合吸收落地清单

从上述 30+ 候选里精选 6 项落地。**全部不新增 `check_*` 门禁**（守决策 26 的 `FACT_GATES_BUDGET=54` 上限），以方法论吸收（references 文档 / SKILL.md 叙事 / state-machine warn 分支 / trace-log 字段 / 新增 G10 self-check 断言）为主。

| # | 来源 | 概念 | 落地点 | 类型 |
|---|---|---|---|---|
| 3.1 | gsd-core v1.8.0 | reversibility 分级 | `references/decision-governance.md` §2.4 + `decisions.jsonl` schema + `trace-log.sh` | 方法论 |
| 3.2 | gsd-core v1.8.0 | broken-windows ledger | `references/gsd-patterns.md` + `state-machine.sh` archive guard warn 分支 | 方法论 + warn 增强 |
| 3.3 | graphify v0.9.27 | honest-edge provenance（EXTRACTED/INFERRED/AMBIGUOUS）| `assets/trace-log.sh` confidence 字段 + `references/memory-persistence.md` | 方法论 + 字段扩展 |
| 3.4 | superpowers v6.2.0 | resume-based 5 轮熔断修复环 + scoped re-review | `references/subagent-orchestration.md` | 方法论 |
| 3.5 | superpowers v6.2.0 | 可证伪性 + Mutation Check | `references/review-methodology.md` | 方法论 |
| 3.6 | claude-mem v13.12.x | version oracle 单源真值 | `scripts/self-check.sh` G10 + `assets/facts.conf` `FACT_VERSION_ORACLE_RULE` | self-check 断言 |

**未落地但留作后续候选**（证据已记录，待预算或需求触发）：
- ruflo witness-attested 门禁（需新 check_*，超预算，待决策 26 修订）
- ruflo `node -e` 跨平台 hook bootstrap（待 hooks 实装时落地）
- graphify strict PreToolUse "deny-then-downgrade" hook 模型（待 hook 机制扩展）
- gsd-core multi-signal fix-acceptance 护栏（需新 check_*，超预算）
- ocr 四层规则优先级链（待 review 门禁重构）
- claude-mem 两车道同步模式（待多设备同步需求）

## 4. 验证

- 升级后各运行时 `git describe --tags --abbrev=0` 已对齐目标版本（见 §1 表）。
- graphify `git merge-base v0.9.19 v0.9.27 = v0.9.19`，确认线性路径（非异源 v1.0.0）。
- 整合落地不新增 `check_*` 函数，`FACT_GATES_TOTAL` 保持 54 ≤ `FACT_GATES_BUDGET` 54（G9 守住）。
- 新增 `FACT_VERSION_ORACLE_RULE` 是 `facts.conf` 变量（非 `precheck.conf` 变量），不计入 `FACT_CONF_VARS=169`。
- 落地验证见 self-check.sh G10 + shellcheck + bash -n + fixture 抽跑。

# 记忆持久化模式 (Memory Persistence Patterns)

> 整合自 [claude-mem](https://github.com/thedotmack/claude-mem) 的方法论模式。
> **只引用模式与 `claude-mem` 工具命令，不复制其源码。**

## 它解决什么问题

AI agent 的对话记忆不抗 context compaction——压缩后丢失关键决策与进展。superpowers 的 progress ledger 是轻量方案（单文件）。claude-mem 提供更完整的**跨会话/跨压缩记忆持久化**：状态存于 SQLite + 向量库（上下文窗外），每次会话启动/压缩时重新注入。

## claude-mem 工具引用（只引用调用）

```bash
# 安装（注册 hooks + 启动 worker）
npx claude-mem install
# 注意：npm install -g claude-mem 只装 SDK，不注册 hooks

# 安装后自动：
# - SessionStart(startup|clear|compact) hook → 注入历史记忆
# - PostToolUse hook → 观察 tool 调用，生成 observation
# - Stop hook → 生成 session summary
# - MCP server (search/timeline/get_observations) → 按需检索

# 记忆存储位置
~/.claude-mem/claude-mem.db      # SQLite (FTS5 全文搜索)
~/.claude-mem/chroma/            # ChromaDB 向量嵌入
```

> **铁律：只引用 claude-mem 命令，不重新实现记忆存储/检索/嵌入功能。**

## Detached Observer Agent（核心创新）

引自 `src/sdk/prompts.ts`：

> "You are a Claude-Mem, a specialized observer tool… You do not have access to tools."

**工作 agent 不写记忆**——一个独立的 observer agent 观察 tool I/O，生成 XML observation。这解耦了记忆捕获与工作会话的上下文预算。

observation XML 格式：
```xml
<observation>
  <type>bugfix|feature|refactor|change|discovery|decision|security_alert</type>
  <title>...</title>
  <facts><fact>...</fact></facts>
  <narrative>...</narrative>
  <concepts><concept>how-it-works|why-it-exists|what-changed|problem-solution|gotcha|pattern|trade-off</concept></concepts>
  <files_read><file>...</file></files_read>
  <files_modified><file>...</file></files_modified>
</observation>
```

### 在目标技能中的落地
- 若项目已装 claude-mem：workflow 节点⑤的 subagent 编排无需手动写记忆，observer 自动捕获
- 若未装：用 superpowers 的 progress ledger（轻量替代）+ 手动在关键决策点写 `.swarm-yuan/decisions.md`

## 3 层渐进式检索（Token 经济）

引自 `plugin/skills/mem-search/SKILL.md`。按需检索，省 ~10x token：

1. **search** — 紧凑索引（每结果 ~50-100 token，含 ID）
2. **timeline** — 某锚点 ID 周围的时序上下文
3. **get_observations** — 过滤后 ID 的完整详情（每条 ~500-1000 token）

过滤器：`type` / `obs_type` / `project` / `dateStart/dateEnd` / `orderBy`

### 在目标技能中的落地
- 目标技能的 reference 段建议用渐进式披露：SKILL.md 简要 → references/ 按需读 → 外部图谱/记忆按需查
- check 段的"状态恢复"引用：先 search 找相关历史，再 timeline 看上下文，再 get_observations 看详情

## 两 Session-ID 架构（压缩存活）

引自 `docs/SESSION_ID_ARCHITECTURE.md`：
- `contentSessionId` — Claude Code 的会话 ID（不变）
- `memorySessionId` — observer 的会话 ID（worker 重启时变）
- observation 存于 memorySessionId；恢复由 `hasRealMemorySessionId && lastPromptNumber > 1` 门控

**Pending message queue** — tool 事件入队（pending 状态），parser 返回有效响应才清空；解析失败队列保留，不丢 observation。重启循环：retry 1s→2s→4s，3 次连续重启后停。

### 在目标技能中的落地
- workflow 的"状态控制"要素：状态存于上下文窗外（state-machine.sh 的 `.swarm-yuan/state.yaml` + claude-mem 的 SQLite），压缩后可恢复
- 若用 claude-mem，SessionStart(compact) hook 自动重新注入记忆——无需手动恢复

## SQLite 并发安全（claude-mem v13.10.2）

> 引自 claude-mem v13.10.2。worker + hook 并发访问同一 SQLite DB 时的防御。

- **`busy_timeout`**：worker 进程与 PostToolUse hook 可能同时写 `claude-mem.db`，须设 `busy_timeout`（如 `5000ms`）避免 `SQLITE_BUSY` 立即失败
- **原子 settings 写**：`~/.claude-mem/settings.json` 须原子写（write-to-temp + rename），避免 hook 读到半写状态
- **migration column re-check**：启动时检查 schema 列是否已迁移，避免 legacy 重复行导致 boot 崩溃
- **worktree 相对 `gitdir:` 指针解析**：在 git worktree 中运行时，相对 `gitdir:` 指针须正确解析到主仓库

**在目标技能中的落地：**
- 若项目用 claude-mem，dev-guide.md 提示：concurrent worker/hook 访问须设 `busy_timeout`，不可裸连 SQLite
- precheck.sh 的 `--memory` 子命令（若项目自建 SQLite 记忆层）可扫描 `new Database(path)` 后无 `busy_timeout` 的模式

## 代理环境变量透传（claude-mem v13.10.2）

> 引自 claude-mem v13.10.2。supervisor 进程启动 SDK 子进程时须保留代理环境。

- `HTTPS_PROXY` 须透传给 SDK 子进程（不能只继承部分 env）
- Bedrock/Vertex 的 `skip-auth` env 须保留（否则子进程失去免鉴权配置）

**在目标技能中的落地：**
- security-spec §3 网络安全：若项目启动 LLM SDK 子进程，须显式透传 `HTTPS_PROXY` 等代理 env
- precheck.sh 的 `--security` 可扫描 `spawn()` 调用是否过滤了 `env`（若显式传 `env:` 须包含 `HTTPS_PROXY`）

## Mode-JSON 分类法（生成+检索同源）

引自 `plugin/modes/code.json`。一个 mode JSON 定义：
- `observation_types[]` — id/label/description（bugfix/feature/refactor/change/discovery/decision/security_*）
- `observation_concepts[]` — 知识类别（how-it-works/why-it-exists/what-changed/problem-solution/gotcha/pattern/trade-off）
- `prompts{}` — 运行时组合的 prompt 片段字典

**生成与检索同源**：mode 控制 observer 生成什么类型，也控制注入时过滤什么类型。

### 在目标技能中的落地（可选高级模式）
目标技能可生成 `.swarm-yuan/mode.json`，定义该项目的 observation 类型/概念分类。若装了 claude-mem，用 `CLAUDE_MEM_MODE` 环境变量指向它。

## `<private>` 隐私标签

引自 `user-message.ts`：用户用 `<private>...</private>` 包裹消息，存储前被剥离。

### 在目标技能中的落地
- workflow 的"产出物归档"要素：敏感上下文可用 `<private>` 标签保护，不写入持久记忆

## 记忆结构化查询

claude-mem 支持的查询维度：
- **By project** — `basename(cwd)`
- **By type** — bugfix/feature/refactor/change/discovery/decision/security_*
- **By concept** — JSON array match（how-it-works/gotcha/pattern...）
- **By timestamp** — created_at_epoch
- **By files** — files_read/files_modified
- **By session** — memory_session_id
- **全文** — FTS5 + **语义** — ChromaDB 嵌入（混合检索）

### 在目标技能中的落地
- 目标技能的 check 段"状态恢复"：用 `search`/`timeline`/`get_observations` 查历史决策，而非翻对话历史
- dev-guide.md 引用：查"这个模块为什么这样设计"→ `search "why" --type decision`

## 与 swarm-yuan 其他方法论的协同

| 方法论 | 记忆方案 | 适用场景 |
|--------|---------|---------|
| superpowers progress ledger | 单文件 `.swarm-yuan/sdd/progress.md` | 轻量，单会话内任务进度 |
| comet state-machine | `.swarm-yuan/state.yaml` | 阶段状态机（phase/verify_result） |
| claude-mem | SQLite + ChromaDB + observer | 跨会话/跨压缩的完整记忆（决策/发现/gotcha） |

**推荐组合**：state-machine.sh 管阶段状态 + progress ledger 管任务进度 + claude-mem（若装）管跨会话知识。三者不冲突，各管一层。

## WAL 安全备份（ruflo v3.23.0）

> 引自 ruflo v3.23.0。SQLite WAL 模式下的安全备份模式——naive 拷贝会损坏 DB。

### 为什么不能直接拷贝
SQLite 在 WAL（Write-Ahead Logging）模式下，`*.db` + `*-wal` + `*-shm` 三个文件组成一致状态。naive `cp *.db` 只拷贝主文件，丢失 WAL 中未 checkpoint 的事务——恢复后数据不一致或损坏。

### 安全备份模式
```
# better-sqlite3 在线备份（推荐，非破坏式只读源）
const backup = db.backup(`${dest}.db`);
while (backup.remaining > 0) backup.transfer(-1);
backup.close();

# 或 SQLite CLI
sqlite3 "$DB" ".backup '$DEST'"
```

**特性：**
- **在线非破坏**：源 DB 可继续读写，备份是一致性快照
- **轮转保留**：保留最近 N 份（默认 7），自动删除更旧的
- **可选异地**：备份完成后上传到 GCS (`--gcs gs://bucket/path`) 或 S3

**在目标技能中的落地：**
- 若项目用 SQLite 做状态存储（state-machine.sh 的 `.swarm-yuan/state.yaml` 是 YAML 不涉及，但若项目自建 SQLite 记忆/缓存层），dev-guide.md 须提示：WAL 模式 DB 不可直接 `cp`，须用在线 `.backup()`
- precheck.sh 的 `--memory` 子命令可扫描 `cp *.db` 或 `fs.copyFile(*.db)` 模式并告警

## Failure-signal 真实捕获（ruflo v3.22.0）

> 引自 ruflo v3.22.0。PostToolUse hook 须记录真实的工具执行结果，而非硬编码 `success:true`。

### 问题
observer 之前在 PostToolUse hook 中记录 `success: true` 硬编码值（898/898 次成功，0 失败）——oracle 层永远没有负例，无法学习"什么操作会失败"。

### 修复
- PostToolUse hook 读取 Claude Code 的 PostToolUse outcome（`tool_response.success` / `tool_response.error`）
- 记录真实 failure：`success: false` + `error_message` + `error_type`
- 这使 oracle 层有了负例：可挖掘"哪种 tool 组合容易失败"、"哪种输入导致 exec 超时"

**在目标技能中的落地：**
- memory-persistence 的 observer 须读 PostToolUse 真实 outcome，不可硬编码 `success:true`
- 若项目自建 observer，dev-guide.md 提示：从 `tool_response` 提取 `success/error` 字段，写入 observation 的 `<facts>` 段
- 这让 review-methodology 的 oracle 层（spec-completion audit）有了"失败操作"的历史数据

## Memory Distillation 自学习环（ruflo v3.22.0, ADR-174）

> 引自 ruflo v3.22.0。从 raw observations 蒸馏出可复用的 reasoning patterns——增量、非破坏式、provenance-gated。

### 蒸馏流水线
```
memory_entries (raw observations)
  → episodes (相关 observation 聚合为一个事件)
    → reasoning_patterns (从 episodes 抽象出可复用模式 + embeddings)
      → weak relational edges (pattern 间的弱关联)
```

**特性：**
- **增量**：只处理新增/变更的 observations，不全量重算
- **非破坏式**：只新增 episodes/patterns，不修改或删除已有
- **provenance-gated**：每个蒸馏产物记录来源 observation IDs，可溯源
- **本地训练**：可训练本地 SONA/MoE 模型（$0 默认，无 API 调用）
- CLI：`memory distill run|status|config` + `distill-tuning`（自优化检索参数）

**在目标技能中的落地（可选高级模式）：**
- 若项目长期运行（>1月），可在 check 段加"记忆蒸馏"步骤：定期从 observations 蒸馏 patterns
- 蒸馏产物存于 `.swarm-yuan/patterns.json`（可提交，团队共享）
- dev-guide.md 引用：查"这个模块的常见 failure pattern"→ 查蒸馏产物而非翻 raw observations

## claude-mem v13 全量能力（swarm-yuan 须知道但可选引用）

> 以下能力来自 claude-mem v13.10.1 源码调研。swarm-yuan **不要求全部使用**，但生成目标技能时须知道这些能力存在，按项目需要引用。

### 18 个内置 Skills（`plugin/skills/`）

| Skill | 用途 | swarm-yuan 落点 |
|-------|------|----------------|
| `do` | orchestrator 按任务派发 subagent 执行 | 与 superpowers subagent-driven 重叠，二选一 |
| `make-plan` | orchestrator 制定计划后派发 subagent | 与 gsd-core plan-phase 重叠 |
| `smart-explore` | tree-sitter AST 结构化代码搜索（20+ 语言） | 探查阶段可替代部分 grep |
| `learn-codebase` | 读全部源文件建立项目认知 | 探查阶段路 C 可引用 |
| `knowledge-agent` | 从 observation 构建可查询"知识脑" | reference-manual 的认知映射表可引用 |
| `mem-search` | 3 层渐进式检索（search→timeline→get_observations） | check 段状态恢复引用 |
| `pathfinder` | 特性分组流程图 + 重复关注点检测 + 统一架构提案 | reference-manual 依赖链路段可引用 |
| `standup` | 自动生成站会报告 | 项目管理方向可引用 |
| `timeline-report` | 时序报告 | 复盘可引用 |
| `weekly-digests` | 周报 | 项目管理方向可引用 |
| `what-the` | 快速解释代码/概念 | dev-guide 可引用 |
| `how-it-works` | 深度解释机制 | dev-guide 可引用 |
| `version-bump` | 版本升级 | release 段可引用 |
| `babysit` | 持续监控 agent 执行 | 长任务执行可引用 |
| `oh-my-issues` | 按 root cause 聚类 GitHub issue | 项目管理方向可引用 |
| `design-is` | 设计意图探索 | spec §1 背景可引用 |
| `wowerpoint` | 生成演示文稿 | 文档方向可引用 |

### 配置项（`~/.claude-mem/settings.json`）

关键配置（AI 生成 precheck.conf 时可参考）：
- `CLAUDE_MEM_MODEL` — 记忆模型（默认 `claude-haiku-4-5-20251001`），支持 `$TIER:fast`/`$TIER:smart` 分层路由
- `CLAUDE_MEM_CONTEXT_OBSERVATIONS` — 注入观察数（默认 50）
- `CLAUDE_MEM_SEMANTIC_INJECT` — 语义注入开关
- `CLAUDE_MEM_MODE` — 工作模式 + 输出语言（`code`/`code--zh`/`code--ja` 等 36 种）
- `CLAUDE_MEM_RATE_LIMIT_PER_MIN` / `CLAUDE_MEM_MONTHLY_REQUEST_CAP` — 限流
- `<private>` 标签 — 排除敏感内容不入库

### Worker/Server 双运行时

- **Worker 模式**（默认）：Bun 进程，本地 SQLite + ChromaDB，端口 37700+uid%100
- **Server 模式**：Docker（PostgreSQL + Redis），API-key 认证，多人共享，远程 MCP recall

### REST API + 远程 MCP

- 本地 Web Viewer：`http://localhost:37777`（10 个搜索端点）
- 远程 MCP recall：`/v1/mcp`（search/context/recent 工具，API-key 认证，限流，用量计量）

### 10+ IDE 集成

claude-code / cursor / opencode / openclaw / windsurf / codex-cli / copilot-cli / antigravity / goose / roo-code / warp

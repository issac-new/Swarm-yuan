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

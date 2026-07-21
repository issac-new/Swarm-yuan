# 代码图谱工具引用 (Code-Graph Tools Reference)

> 本文件指导目标技能如何**引用调用** [GitNexus](https://github.com/abhigyanpatwari/GitNexus) 与 [graphify](https://github.com/Graphify-Labs/graphify) 构建代码知识图谱。
> **铁律：只引用调用工具命令，不复制其源码，不重新实现其功能。**

## 为什么用代码图谱

AI agent 理解代码库时，传统方式是 grep + 读文件——易遗漏关系、上下文爆炸。代码图谱工具将整个代码库索引为知识图（依赖、调用链、簇、执行流），agent 查询图谱而非 grep，**不漏关系、省上下文**。

## 选型（按技术能力）

> 数据实测 2026-07-20（见 `docs/research/R6-upstream-web.md` §0/§1.3/§1.4）。
> **选型方针（决策 18，2026-07-21 起）：范式层面按技术能力选型，不因开源组件商业授权条款降级或调整优先级。** 授权合规评估是使用方组织自身的责任（登记见下表「许可证」列，仅供使用方自查），不进入 swarm-yuan 的工具默认/降级决策。

| 工具 | 许可证（事实登记，供使用方自查） | 能力定位 |
|------|--------|----------|
| **graphify** | MIT | 广谱知识图（代码+文档+媒体）、可提交 graph.json、Mermaid 导出；91.7k stars、活跃（2026-07-18） |
| **GitNexus** | PolyForm Noncommercial 1.0.0（GitHub API 返回 NOASSERTION，LICENSE 原文实测 2026-07-20） | 深度代码调用图、Tree-sitter 原生解析、LadybugDB 持久图、`--pdg` 污点分析、PreToolUse/PostToolUse hooks、多仓库 group query |

两者**平权**，按项目需要选择或并用：
- 侧重深度调用链分析、持久 DB、多仓库、 hooks 集成 → GitNexus
- 侧重广谱（代码+文档+媒体）、可提交的图、Mermaid 可视化 → graphify
- 大型项目可并用：GitNexus 做深度调用图，graphify 做广谱知识图 + Mermaid 可视化

补充说明：

- **graphify 仓库已迁移**：org URL 由 `safishamsi/graphify` 迁至 [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify)（GitHub API 2026-07-20 实测），引用一律用新 URL。
- **graphify 引用基线：v0.9.x**（本文能力清单基于 v0.9.5 源码调研 + v0.9.6–v0.9.19 release notes）。上游已发布 **0.10.0**（npm graphifyy，2026-07-20 实测；PyPI 仍 0.9.20），**0.10.0 待评估**，评估前不引用其新能力（登记见 `docs/upstream-baseline.md`）。

## GitNexus（Node 生态，深度代码调用图）

### 安装
```bash
npm install -g gitnexus
# 或一次性（不安装）：
npx gitnexus@latest analyze
# 可选：跳过部分语法（Dart/Proto/Swift/Kotlin）
GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1 npm install -g gitnexus
```

### 核心命令
```bash
gitnexus setup                     # 一次性：为检测到的编辑器写 MCP 配置（-c 选择）
gitnexus analyze [path]            # 索引仓库（或更新过期索引）— 在仓库根运行
gitnexus analyze --force           # 全量重建
gitnexus analyze --embeddings [n]  # 启用语义嵌入（默认上限 50000 节点；0 禁用）
gitnexus analyze --skills          # 生成仓库专属 skill 文件
gitnexus mcp                       # 启动 MCP server（stdio）— 服务所有已索引仓库
gitnexus serve                     # 本地 HTTP server（多仓库）供 Web UI 桥接
gitnexus list                      # 列出所有已索引仓库
gitnexus status                    # 当前仓库的索引状态
gitnexus clean [--all --force]     # 删除索引
gitnexus wiki [path] [--model m]   # 从图谱生成仓库 wiki
gitnexus group create <name>       # 多仓库/monorepo 组 + 跨仓库契约同步
```

### 输入/输出
- **输入**：本地仓库路径（默认当前目录）。Tree-sitter 原生绑定解析多语言
- **输出**：持久本地知识图（LadybugDB，存于 `.gitnexus/`，gitignored）；`AGENTS.md`/`CLAUDE.md` 上下文文件；`.claude/skills/gitnexus/` skill 文件；MCP server 暴露图谱查询工具

### Agent 集成模式
1. `npm install -g gitnexus`
2. `gitnexus setup`（注册 MCP 到编辑器）或手动：`claude mcp add gitnexus -- npx -y gitnexus@latest mcp`
3. `gitnexus analyze`（在目标仓库根构建索引）
4. agent 调用 GitNexus MCP 工具（依赖查询、调用链遍历、簇查询）替代 grep
5. 索引过期（提交后）→ 重新 `gitnexus analyze`

## graphify（Python 生态，广谱知识图）

### 安装
```bash
# 推荐（隔离环境）：
uv tool install graphifyy
# 或：
pipx install graphifyy
```
> ⚠️ PyPI 包名是 `graphifyy`（双 y）。其他 `graphify*` 包不相关。
> ⚠️ `uvx graphify` 会失败——必须 `uvx --from graphifyy graphify install`。
> ⚠️ 若 `graphify: command not found`，运行 `uv tool update-shell`（或 `pipx ensurepath`）后重开终端。

### 核心命令
```bash
graphify install                       # 注册 skill 到 AI 助手（默认 Claude Code）
graphify install --platform agents     # 注册到 .agents/skills/（跨框架）
graphify install --project             # 安装到当前仓库而非用户 profile
graphify .                             # 构建图谱（当前文件夹）
graphify extract ./docs --backend claude  # 无头提取（非代码需 API key）
graphify query "什么连接了 auth 和数据库？"  # 自然语言查询 graph.json
graphify path "ComponentA" "ComponentB"    # 依赖链/最短路径
graphify explain "RateLimiter"             # 节点邻域
graphify export callflow-html              # Mermaid 调用流 HTML
graphify hook install                      # git commit 时自动重建图
graphify hook-guard <search|read>          # hook 守卫子命令（跨平台，v0.9.8+）
graphify merge-graphs a.json b.json        # 合并图
python -m graphify.serve graphify-out/graph.json              # MCP server（stdio）
python -m graphify.serve graph.json --transport http --port 8080  # 共享 HTTP MCP
```

> ⚠️ **hook-guard 子命令（v0.9.8+）**：`PreToolUse` / `BeforeTool` hook 逻辑已移入 shell 无关的 `graphify hook-guard <search|read>` 子命令，Windows/macOS/Linux 行为字节一致。不再依赖 POSIX bash 内联（`case/esac`、`[ -f ]`），Windows 上 hook 不再静默失败。Gemini 的 `BeforeTool` 用 `graphify hook-guard gemini`，移除对 bare `python` 在 PATH 的依赖。

### ECC v2.0 Hook 治理（hook runtime governance）

> 来自 ECC v2.0.0。将 hook 管理从"静态 hooks.json"升级为"运行时 profile + env gating + dispatcher 架构"。

#### Hook Runtime Governance

ECC 的 hook 系统有 4 层治理：

| 层 | 机制 | 说明 |
|----|------|------|
| **Stable hook IDs** | `pre:bash:dispatcher` | 每个 hook 有稳定 ID，重装时 dedupe（不重复注册） |
| **Runtime profiles** | `ECC_HOOK_PROFILE=minimal\|standard\|strict` | 按 profile 启用不同 hook 集合（minimal=仅核心，strict=全量） |
| **Env gating** | `ECC_DISABLED_HOOKS` | 环境变量禁用特定 hook，不编辑文件 |
| **Consolidated dispatchers** | 一个 `PreToolUse(Bash)` 入口 fan-out 到多个检查 | 减少 hook 数量，降低开销 |

**在目标技能中的落地：**
- 生成的目标技能的 hooks.json 可增加 `hookProfile` 字段，支持 minimal/standard/strict
- 用 `ECC_DISABLED_HOOKS` 风格的 env 变量允许用户禁用特定 hook
- 用 dispatcher 模式：一个 PreToolUse 入口调用多个检查脚本（而非每个检查一个 hook）

#### Gateguard Fact-Forcing Gate（事实强制门禁）

ECC 的 `gateguard-fact-force.js` hook 在**首次 Edit/Write/MultiEdit** 时阻断，直到 agent 展示具体调查证据：

- 阻断条件：首次修改某文件
- 放行条件：agent 在 prompt 中展示：importers 分析 / data schemas 分析 / 用户明确指令

**在目标技能中的落地：**
- 生成的目标技能的 PreToolUse(Write|Edit) hook 可引用此模式：首次修改前须展示调查证据
- 这防止 agent 盲目修改未调查的文件

#### Config Protection（配置保护）

ECC 的 `config-protection.js` hook 阻断**削弱 linter/formatter 配置的编辑**：

- 阻断：减少 lint 规则 / 禁用 formatter / 降低严格度
- 放行：修复代码以通过 lint（而非放松 lint）

**在目标技能中的落地：**
- 生成的目标技能的 PreToolUse(Write|Edit) hook 可引用此模式：防止 agent 通过放松配置来"修复"问题
- 引导 agent 修复代码而非放松配置

#### MCP Health Check（MCP 健康检查）

ECC 的 `mcp-health-check.js` hook 在 MCP 调用前检查 server 健康：

- 阻断：MCP server 不健康（unreachable / error）
- 放行：MCP server 健康

**在目标技能中的落地：**
- 若目标技能依赖 MCP，可在 PreToolUse(mcp__*) hook 中加健康检查
- 防止调用不健康的 MCP server（避免超时/错误）

### graphify v0.9.13–v0.9.19 新增能力

> 来自 graphify v0.9.13 → v0.9.19 release notes。correctness + privacy + strict hook 批次。

| 能力 | 版本 | 描述 | swarm-yuan 落点 |
|------|------|------|----------------|
| **`--strict` PreToolUse 硬阻断** | v0.9.19 | `graphify install --strict` 安装的 hook 首次 raw source read 时 `permissionDecision: "deny"` 阻断 + 重定向到 `graphify query`，然后降级为 soft nudge（每会话最多一次，不会 strand agent） | 目标技能的 hook 可引用此 strict 模式 |
| **原子 JSON 写入** | v0.9.18 | `graph.json`/`manifest.json` 等写入 temp 文件 + `os.replace` 原子替换（写穿 symlink），kill/OOM/ENOSPC 不留截断文件 | 图完整性可引用 |
| **不完整提取不覆盖完整图** | v0.9.18 | 崩溃/部分失败/权限拒绝的提取拒绝覆盖更大的已有图（exit 1，除非 `--allow-partial`）；不可解析的已有图 fail-closed | 图完整性可引用 |
| **查询日志默认关闭** | v0.9.13 | `querylog` 不再默认开启（原默认写 `~/.cache/graphify-queries.log` 明文），须 `GRAPHIFY_QUERY_LOG=1` 显式开启 | 隐私可引用 |
| **`.git/info/exclude` 遵守** | v0.9.14 | 检测遵守 `.git/info/exclude`（git worktree 记录嵌套 worktree 路径处），不再走入 worktree 副本（避免图膨胀 20x） | worktree 项目可引用 |
| **嵌套 `.gitignore` 作用域** | v0.9.15/v0.9.16 | 嵌套 `.gitignore`/`.graphifyignore` 的 `*` 只作用于自己的子树，不吞整棵树 | 图正确性可引用 |
| **graph.html stored XSS 修复** | v0.9.15 | 导出的 `graph.html` 邻居链接的 node id 现在用 HTML-escaped `data-nid` 属性 + 单一 delegated listener，防止 stored XSS | 安全可引用 |
| **原子 GraphML 导出** | v0.9.14 | `graphify export graphml` 不再因 dict/list 属性崩溃；非标量 JSON 序列化；原子写 | 导出可靠性可引用 |
| **hyperedge-only 文档 stamping** | v0.9.17 | hyperedge-only 文档在 manifest 中 stamp，不再每次运行重提取 | 增量效率可引用 |
| **Ruby `.rake` + Bash `source` 边** | v0.9.13 | 新语言覆盖：Ruby `.rake` 文件 + 跨文件 Bash script execution 边 | 语言覆盖可引用 |
| **`--strict` 运行时切换** | v0.9.19 | `GRAPHIFY_HOOK_STRICT=1/0` 运行时切换 strict 模式，无需重装 | 用户体验可引用 |

**`--strict` hook 模式详解（v0.9.19）：**
- 默认安装：soft nudge（advisory `additionalContext`，模型可忽略）
- strict 安装（`--strict`）：首次 raw source read 时 `permissionDecision: "deny"` 硬阻断 + 重定向到 `graphify query`
- 阻断后降级：下次 read 自动放行（即使 `graphify query` 失败也不 strand agent）
- "recently oriented" stamp：运行任何 `graphify query`/`explain`/`path` 后刷新短期 stamp，抑制阻断
- 仅 Claude Code 支持硬阻断（Bash-grep 和 Glob 仍 nudge-only；Gemini/Codex/OpenCode 无法硬阻断）

**在目标技能中的落地：**
- 生成的目标技能若用 graphify，hooks.json 可提供 strict 模式选项
- precheck.sh 的 `--graph` 子命令可校验 `graph.json` 是否原子写入（检查是否有 `.tmp` 残留）

### 输入/输出
- **输入**：文件夹路径。代码（36 种 tree-sitter 语法）本地离线解析；文档/PDF/图片/视频需 LLM backend（`--backend claude|gemini|openai|deepseek|kimi|azure|bedrock|ollama`）
- **输出**：`graphify-out/` 目录（可提交）：`graph.html`（交互可视化）、`GRAPH_REPORT.md`（god nodes、surprising connections、建议问题、置信度标签 EXTRACTED/INFERRED/AMBIGUOUS）、`graph.json`（完整图，默认 512MiB 上限）；可选 Mermaid/Obsidian/SVG/GraphML/Neo4j 导出；可选 MCP server

### Agent 集成模式
1. `uv tool install graphifyy` + `graphify install --platform agents`
2. 在目标项目运行 `graphify .`
3. agent 读 `graphify-out/GRAPH_REPORT.md` 获取架构概览
4. 用 `graphify query/path/explain` 查具体依赖链，或启 MCP server 用结构化工具（`get_neighbors`、`shortest_path`）
5. `graphify export callflow-html` 生成 Mermaid 调用流（用于 reference-manual.md 的"组件依赖链路"段）
6. `graphify hook install` 保持图谱新鲜

## 两者对比与选择

| 维度 | GitNexus | graphify |
|------|----------|---------|
| 运行时 | Node.js / TypeScript | Python 3.10+ |
| 安装 | `npm i -g gitnexus` | `uv tool install graphifyy` |
| 解析 | Tree-sitter 原生 | Tree-sitter（代码离线）+ LLM（文档/媒体） |
| 存储 | LadybugDB（持久本地图） | `graphify-out/graph.json`（可提交） |
| Agent 接口 | MCP server（stdio）+ HTTP 桥 + Web UI | MCP server + `query/path/explain` CLI + IDE skill |
| 依赖链查询 | MCP 图工具；`gitnexus group query`（多仓库） | `graphify path A B`、`graphify explain X`、MCP `shortest_path` |
| 主要输出 | 知识图 + MCP 工具 + wiki + AGENTS/CLAUDE.md | `graph.html` + `GRAPH_REPORT.md` + `graph.json` + Mermaid |

**选择建议（按技术能力，决策 18：不做授权驱动的降级）：**
- 侧重深度调用图、持久 DB、多仓库 → GitNexus
- 侧重广谱（代码+文档+媒体）、需可提交的图、Mermaid 导出 → graphify
- 两者可并用：GitNexus 做深度调用图，graphify 做广谱知识图 + Mermaid 可视化

## 在目标技能中的落地

目标技能的 `references/code-graph-tools.md` 应：
1. 引用上述安装与命令（按项目实际选择 GitNexus/graphify/两者）
2. 在探查阶段（Step 1）先运行图谱工具索引仓库
3. 在 `reference-manual.md` 的"组件依赖链路"段引用图谱输出（`GRAPH_REPORT.md` / Mermaid 调用流）
4. 在 workflow 节点⑤编码时，agent 查图谱查依赖（`graphify path` / GitNexus MCP）而非 grep
5. **只引用命令，不复制工具源码**

## GitNexus v1.6 全量能力（swarm-yuan 须知道但可选引用）

> 来自 GitNexus v1.6.9 源码调研。44 节点类型 + 21 关系类型，14 语言支持。

### 17 个 MCP 工具

| 工具 | 用途 | swarm-yuan 落点 |
|------|------|----------------|
| `query` | 混合搜索（BM25 + 语义 + RRF） | 探查阶段找稳定单元 |
| `context` | 360 度符号上下文 | 依赖链路段 |
| `impact` | 爆炸半径分析（depth grouping + confidence + risk） | `--impact` 门禁可引用 |
| `trace` | 最短有向路径（调用 + 类成员边） | `--link-depth` 可引用 |
| `detect_changes` | git diff → 受影响进程 | `--stable-diff` 可引用 |
| `check` | 健康检查 | 自检阶段 |
| `rename` | 多文件协调重命名（dry_run） | 重构时引用 |
| `cypher` | 原始 Cypher 查询 | 高级分析 |
| `route_map` | API 路由图 | `--api` 可引用 |
| `tool_map` | MCP/RPC 工具映射 | `--contract` 可引用 |
| `shape_check` | API 响应结构校验 | `--api` 可引用 |
| `api_impact` | 变更前 API 影响报告 | `--impact` 可引用 |
| `explain` | 污点/数据流解释（需 `--pdg`） | `--security` 可引用 |
| `pdg_query` | 语句级控制/数据依赖（需 `--pdg`） | 安全审查可引用 |
| `group_list/sync` | 多仓库组 + 契约注册 | 微服务跨仓库可引用 |

### 关键能力

- **`--pdg` CFG/PDG/taint 基质**（TS/JS）：`explain` 做源→汇污点流分析，`pdg_query` 做语句级依赖——安全审查利器
- **`gitnexus wiki`**：LLM 生成每模块文档 + 交叉引用
- **`--skills`**：Leiden 社区检测 → 每功能域一个 `SKILL.md`（`.claude/skills/generated/`）
- **Claude Code PostToolUse hook**：commit/merge/rebase 后自动检测 stale index → 提示 reindex
- **Codex 全支持**（v1.6.9+）：hooks + plugin marketplace + `gitnexus setup` 自动检测 Codex 并写入 MCP 配置
- **CodeBuddy + Qoder 集成**（v1.6.9+）：`gitnexus setup -c codebuddy,qoder` 扩展 IDE 支持
- **MCP prompts**：`detect_impact`（提交前变更分析）+ `generate_map`（架构文档 + Mermaid）
- **多仓库组**：Contract Registry → 跨仓库爆炸半径 + 跨仓库 trace

### 支持的 AI 平台（v1.6.9+）

| 平台 | 集成深度 | setup 方式 |
|------|---------|-----------|
| **Claude Code** | MCP + skills + PreToolUse/PostToolUse hooks | `gitnexus setup`（自动检测） |
| **Codex** | MCP + skills + hooks（v1.6.9 新增全支持） | `gitnexus setup -c codex` |
| **Cursor** | MCP + skills + postToolUse hook | `gitnexus setup -c cursor` |
| **Antigravity/Google** | MCP + skills + AfterTool hook | `gitnexus setup -c antigravity` |
| **OpenCode** | MCP + skills | `gitnexus setup -c opencode` |
| **Windsurf** | MCP only | `gitnexus setup -c windsurf` |
| **CodeBuddy** | MCP + skills（v1.6.9 新增） | `gitnexus setup -c codebuddy` |
| **Qoder** | MCP + skills（v1.6.9 新增） | `gitnexus setup -c qoder` |

## graphify v0.9 全量能力（swarm-yuan 须知道但可选引用）

> 来自 graphify v0.9.5 源码调研。36 tree-sitter 语法，22 平台集成。

### 关键能力（swarm-yuan 可能没用到）

| 能力 | 描述 | swarm-yuan 落点 |
|------|------|----------------|
| **Work memory + reflection loop** | `save-result` 记录 Q&A 结果 → `reflect` 聚合为 `LESSONS.md` + `.graphify_learning.json`（preferred/tentative/contested 标签 + recency 加权 + provenance） | 记忆闭环可引用 |
| **PR 情报套件** | `graphify prs` → CI 状态 + review 状态 + worktree→branch→PR 映射 + AI triage 排名 + merge-order 冲突检测 | `--impact` 可引用 |
| **跨项目全局图** | `graphify global add/remove/list` → `~/.graphify/global-graph.json` | 多项目可引用 |
| **Callflow HTML 导出** | `graphify export callflow-html` → Mermaid 架构/调用流 HTML | `--mermaid` 可引用 |
| **MCP 工具** | `query_graph`/`get_node`/`get_neighbors`/`shortest_path`/`list_prs`/`get_pr_impact`/`triage_prs` | 探查+审查可引用 |
| **共享 HTTP MCP** | `--transport http --host 0.0.0.0 --api-key` → 团队共享一个图 URL | 团队协作可引用 |
| **Git merge driver** | `graph.json` union-merge → 并发 commit 无冲突标记 | 团队协作可引用 |
| **语义缓存** | `--update` 只重新提取变更文件 | 增量探查可引用 |
| **`--exclude-hubs N`** | 抑制工具超级枢纽节点出 god-node 排名 | 更清晰的依赖分析 |
| **多 LLM 后端** | Gemini/Kimi/Claude/OpenAI/DeepSeek/Azure/Bedrock/Ollama + `claude-cli`（用订阅，免 API key） | 按项目环境选择 |
| **Obsidian vault 导出** | `--obsidian` → 可被 agent 爬取的文档 | 文档方向可引用 |
| **36 tree-sitter 语法** | 含 CUDA/Metal/SystemVerilog/Fortran/Pascal/Delphi/Lua/Zig/Elixir/Julia/Vue/Svelte/Astro | 更广语言覆盖 |
| **MCP 配置作为一等节点** | `.mcp.json` 提取 server 节点 + 包引用 + env-var 需求 | MCP 工具盘点可引用 |
| **包清单作为枢纽节点** | `pyproject.toml`/`go.mod`/`pom.xml` → `depends_on` 边 | `--deps` 可引用 |

### graphify v0.9.6–v0.9.12 新增能力

> 来自 graphify v0.9.6 → v0.9.12 release notes。

| 能力 | 版本 | 描述 | swarm-yuan 落点 |
|------|------|------|----------------|
| **`hook-guard` 跨平台 hook 子命令** | v0.9.8 | hook 逻辑移入 shell 无关的 `graphify hook-guard` 子命令，Windows/macOS/Linux 行为字节一致 | 目标技能的 hook 安装可引用 |
| **不静默丢弃：无 extractor 的代码文件** | v0.9.9 | `.r`/`.ejs`/`.ets` 等被分类为代码但无 AST extractor 的文件，现在 print grouped warning 而非静默消失 | 探查阶段可引用（图完整性） |
| **不静默丢弃：`os.walk` 错误** | v0.9.11 | `os.walk` 的 `os.scandir` 失败（权限/并发写入）现在记录每个跳过的子树 + warn，而非吞掉整棵子树 | 探查阶段可引用（图完整性） |
| **anti-shrink guard** | v0.9.11 | 非空但不可读的旧 `graph.json` 拒绝覆盖（须 `force=True`），空文件仍继续 | 图完整性可引用 |
| **幻影边防御：builtin-typed receivers** | v0.9.10 | TS/JS `x: Date; x.getTime()` 不再绑定到同名用户 `class DATE` | 图正确性可引用 |
| **幻影边防御：跨语言 calls** | v0.9.10 | 禁止跨语言 `calls` 边（按 interop family 过滤候选） | 图正确性可引用 |
| **语义超边保留** | v0.9.12 | `graphify update` 不再在 AST 重建时删除 doc-sourced hyperedges | 增量探查可引用 |
| **PostgreSQL 只读 FK 内省** | v0.9.12 | `--postgres` 从 `pg_catalog.pg_constraint` 读 FK，只读角色也能得 `references` 边 | DB 项目可引用 |
| **`json_config` 依赖边** | v0.9.12 | `package.json` 依赖 + `tsconfig.json` `extends`/`$ref` 创建 `concept` 目标节点再连边 | 依赖图可引用 |
| **Ruby `mixes_in` 边** | v0.9.7 | `include`/`extend`/`prepend <Module>` → `mixes_in` 边，Rails concern 可见 | Ruby 项目可引用 |
| **rationale/doc_ref 节点** | v0.9.7 | JS/TS `// NOTE:` 注释与 ADR/RFC 引用成为 `rationale`/`doc_ref` 节点 | 文档关联可引用 |
| **`pascal` 可选 extra** | v0.9.7 | Delphi 提取（AST-quality） | Delphi 项目可引用 |
| **大小写不敏感扩展名分发** | v0.9.7 | `App.PY`/`script.JS` 不再被跳过 | 跨平台文件名可引用 |
| **`affected <Class>` 成员种子** | v0.9.7 | `affected` 从类的成员节点种子反向遍历 | 影响分析可引用 |

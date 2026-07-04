# 代码图谱工具引用 (Code-Graph Tools Reference)

> 本文件指导目标技能如何**引用调用** [GitNexus](https://github.com/abhigyanpatwari/GitNexus) 与 [graphify](https://github.com/safishamsi/graphify) 构建代码知识图谱。
> **铁律：只引用调用工具命令，不复制其源码，不重新实现其功能。**

## 为什么用代码图谱

AI agent 理解代码库时，传统方式是 grep + 读文件——易遗漏关系、上下文爆炸。代码图谱工具将整个代码库索引为知识图（依赖、调用链、簇、执行流），agent 查询图谱而非 grep，**不漏关系、省上下文**。

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
graphify merge-graphs a.json b.json        # 合并图
python -m graphify.serve graphify-out/graph.json              # MCP server（stdio）
python -m graphify.serve graph.json --transport http --port 8080  # 共享 HTTP MCP
```

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

**选择建议：**
- 侧重代码调用图、需持久 DB、多仓库 → GitNexus
- 侧重广谱（代码+文档+媒体）、需可提交的图、Mermaid 导出 → graphify
- 两者可并用：GitNexus 做深度调用图，graphify 做广谱知识图 + Mermaid 可视化

## 在目标技能中的落地

目标技能的 `scripts/code-graph-tools.md` 应：
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
- **MCP prompts**：`detect_impact`（提交前变更分析）+ `generate_map`（架构文档 + Mermaid）
- **多仓库组**：Contract Registry → 跨仓库爆炸半径 + 跨仓库 trace

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

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

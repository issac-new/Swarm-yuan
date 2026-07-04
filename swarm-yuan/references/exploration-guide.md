# 仓库探查指南 (Repository Exploration Guide)

生成目标技能前，必须先探查目标仓库。本指南说明如何高效探查各类项目，**包括环境依赖、外部资源、MCP 工具**。

## 探查策略

**用 Agent 子代理并行探查**（Explore 类型），三路并行：

- **路 A：结构与构建** — 顶层目录、package.json/构建文件、scripts、端口、构建系统、测试体系
- **路 B：开发规范 + 项目知识** — 读取并解析项目既有知识文件（见下方"项目知识读取"），提取规则写入特征卡
- **路 C：代码组织与外部资源** — 源码目录、组件库、接口、数据模型、安全机制、**环境依赖、外部资源（DB/缓存/MQ）、MCP 工具、静态资源、样例数据**

每路子代理的 prompt 要明确"报告具体路径、命令名、版本号、文件名、连接串格式、端口"。

## Step -1: 项目知识读取（先于一切探查，最高优先级）

> **铁律：探查代码前，先读取项目既有的知识文件和记忆。** 这些文件是项目团队积累的规则、约定、教训——不读就生成 skill = 重复造轮子 + 违反既有约定。

### 读取清单（按优先级从高到低）

| 优先级 | 文件/目录 | 提取什么 | 写入特征卡哪项 |
|--------|----------|---------|--------------|
| **P0** | `AGENTS.md` | AI agent 工作区规则：可改范围、只读区、改造分类、分支策略 | 第 2/3/6 项 |
| **P0** | `CLAUDE.md` | Claude Code 指导：项目概述、开发命令、端口约定、架构说明、A类/B类改造 | 第 1/4/5/10 项 |
| **P1** | `.zcode/memories/` 或 `~/.zcode/cli/memories/projects/*/` | 项目级记忆：用户偏好、全局规则、历史教训（如"release 仅上传 arm64.dmg + x64.zip"） | 第 6/7 项 |
| **P1** | `.claude/` 或 `~/.claude/` | Claude 配置+记忆：skills/plugins/settings、claude-mem 记忆库 | 第 7/10 项 |
| **P2** | `CONTRIBUTING.md` | 贡献规范：代码风格、PR 流程、commit 格式 | 第 6/8 项 |
| **P2** | `README.md` | 项目概述、快速开始、技术栈 | 第 1/4 项 |
| **P2** | `.github/` | PR 模板、CI workflow、issue 模板 | 第 6/8 项 |
| **P3** | `docs/` | 设计文档、specs、plans、ADR | 第 8/11 项 |
| **P3** | `.editorconfig` / `.gitignore` | 编码约定、忽略规则 | 第 8 项 |

### 读取流程（AI 自动执行）

```
1. 扫描项目根目录 + 父目录，按上表清单检测哪些文件存在
2. 逐文件读取，提取规则条目（每条规则记录：来源文件 + 规则内容 + 适用范围）
3. 合并去重（同一规则在多个文件出现的，保留最高优先级来源）
4. 写入特征卡对应项（不是复制原文，是提取结构化规则）
5. 生成的目标技能的 SKILL.md 铁律段须引用来源（如"见 AGENTS.md"），不重复写死规则值
```

### 记忆复用机制

项目记忆（.zcode/memories / claude-mem）中的规则分三类，AI 须区别处理：

| 记忆类型 | 处理方式 | 示例 |
|---------|---------|------|
| **全局规则**（type: project） | 写入生成 skill 的铁律段，标注来源 | "release 仅上传 arm64.dmg + x64.zip" |
| **用户偏好**（type: preference） | 写入 dev-guide.md 的"开发偏好"段 | "不自动推送 github" |
| **历史教训**（type: rollout_summary） | 写入 reference-manual.md 的"注意事项"段 | "dev server 运行期间不得 git checkout upstream" |

> **生成的 skill 须能反向写入项目记忆**：当 AI 在开发过程中发现新规则/教训时，通过 claude-mem 或 .zcode/memories 写入，下次生成 skill 时自动读取。形成"记忆→生成→开发→记忆"闭环。

### 读取 AI Agent 运行时（如 hermes-agent）

> 如果项目包含 AI agent 运行时（如 `upstream/hermes-agent/`），AI 须读取其工作内容，理解 agent 的能力边界、工具链、配置方式。生成的目标技能须能指导开发者正确配置和使用 agent。

| 读取项 | 路径模式 | 提取什么 | 写入特征卡哪项 |
|--------|---------|---------|--------------|
| Agent 概述 | `upstream/hermes-agent/README.md` | agent 版本、能力、架构 | 第 1 项（项目类型） |
| Agent 配置 | `upstream/hermes-agent/AGENTS.md` | agent 工作规则、工具链、安全约束 | 第 2/7 项 |
| Agent 工具 | `upstream/hermes-agent/src/tools/` 或 `tools/` | agent 可调用的工具清单（工具名/参数/用途） | 第 11 项（可复用稳定单元） |
| Agent 插件 | `custom/hermes-agent-plugins/` 或 `plugins/` | 项目自定义的 agent 插件 | 第 11 项 |
| Agent 版本 | `upstream/hermes-agent/pyproject.toml` 或 `package.json` | agent 运行时版本 | 第 4 项（技术栈） |

> 生成的目标技能的 reference-manual.md 须含"AI Agent 运行时"段，记录 agent 版本、能力清单、工具链、配置方式、插件清单。dev-guide.md 须含"如何配置 agent"指引。

## Step 0: 代码图谱构建（优先，方法论整合）

探查前，**先用代码图谱工具索引目标仓库**，让后续探查基于图谱而非 grep。组件依赖链路优先从图谱读取。

**GitNexus（Node 生态，深度代码调用图）：**
```bash
npm install -g gitnexus && gitnexus analyze   # 在目标仓库根构建知识图
gitnexus mcp                                    # 启动 MCP server 供 agent 查询
```

**graphify（Python 生态，广谱知识图）：**
```bash
uv tool install graphifyy && graphify .         # 构建 → graphify-out/GRAPH_REPORT.md + graph.json
graphify path "ComponentA" "ComponentB"          # 查依赖链/最短路径
graphify export callflow-html                    # Mermaid 调用流（用于组件依赖链路段）
```

探查时读 `graphify-out/GRAPH_REPORT.md` 获取架构概览（god nodes、surprising connections），用 `graphify path/explain` 查具体依赖链。详见 `references/code-graph-tools.md`。**只引用调用，不复制实现。**

> 若目标仓库无 Node/Python 环境，或图谱工具失败，降级为 grep+读文件探查（传统方式）。

## 探查清单（通用）

> **工具使用原则**：每项探查优先用运行时工具（gitnexus/graphify/claude-mem/ocr/gsd-tools）+ Claude Code 原生能力（Read/Glob/Grep/LSP/WebSearch/Task），降级到 grep+读文件。以下是 14 项特征卡的工具使用矩阵。

### 特征卡工具使用矩阵（每项探查的工具优先级 + 降级策略）

| # | 特征项 | 优先工具 | 降级策略 |
|---|--------|---------|---------|
| 1 | 项目类型 | gitnexus `query "architecture"` + graphify `explain` | Read package.json / Glob 目录 |
| 2 | 可改范围 | claude-mem `search "project rules"` + Read AGENTS.md/CLAUDE.md | Glob + Grep 目录权限 |
| 3 | 改造分类 | gitnexus `query "layer structure"` + Read CLAUDE.md | Grep import 模式分析 |
| 4 | 技术栈 | gitnexus `query "tech stack"` + graphify `explain "dependencies"` | Read package.json/go.mod/pyproject.toml |
| 5 | 构建发布命令 | Read package.json scripts / Makefile | Grep "scripts" + Glob *.config.* |
| 6 | 分支规范 | claude-mem `search "branch rules"` + Read AGENTS.md | Grep .git/config + Read .github/ |
| 7 | 安全规则 | claude-mem `search "security rules"` + Read AGENTS.md/security-spec.md | Grep "password\|secret\|token" |
| 8 | 文档约定 | Read CONTRIBUTING.md + Glob docs/ | Grep "spec\|plan\|design" in docs/ |
| 9 | 测试体系 | gitnexus `query "test files"` + Read vitest.config/jest.config | Glob "**/*.test.*" + Grep "describe\|it\(" |
| 10 | 环境与外部资源 | gitnexus `route_map` + gitnexus `tool_map` + Read .env/docker-compose | Grep "host\|port\|url\|connection" |
| 11 | 可复用稳定单元 | **gitnexus `context <symbol>`**（360 度上下文）+ **graphify `query "stable units"`** | Grep "export\|module.exports" + Read 组件目录 |
| 12 | 数据规范 | gitnexus `query "data models"` + Read schema/migration/ORM | Grep "CREATE TABLE\|schema\|model" |
| 13 | 四层认知基底 | graphify `explain "god nodes"` + claude-mem `search "cognition baseline"` | 手动盘点（Read + Grep） |
| 14 | 领域知识 | gitnexus `query "domain entities"` + claude-mem `search "domain knowledge"` + WebSearch 行业标准 | Read 领域模型 + Grep 业务关键词 |

> **Dynamic Workflows 场景**：如果项目大型（>100 文件），探查阶段可用 Dynamic Workflow 并行扇出三路子代理（结构/规范/代码组织），每路用不同的运行时工具，最后交叉验证特征卡。降级：传统 Task(subagent) 三路并行。

### A. 结构与构建

```
必查：
- 顶层目录结构（识别 monorepo/overlay/upstream/submodule）
- 包描述文件：package.json / pyproject.toml / go.mod / Cargo.toml / pom.xml
  → name, version, scripts/targets, engines/runtime, type, 依赖列表
- 构建系统：vite/webpack/rollup/esbuild/Makefile/CMake/docker/electron-builder
- 构建配置文件：*.config.ts / tsconfig.json / Dockerfile / docker-compose
- 开发命令：dev/build/test/lint/release 命令及端口约定
- 测试框架与配置：vitest/jest/pytest/go test/cargo test，测试目录，setup 文件
- 产物位置：dist/ build/ target/ release/
```

### B. 开发规范

```
必读（如存在）：
- AGENTS.md / CLAUDE.md / GEMINI.md — AI agent 工作区规则（最高优先级）
- CONTRIBUTING.md — 贡献规范
- README.md — 项目概述、快速开始
- .github/ — PR 模板、CI workflow、issue 模板
- docs/ — 设计文档、specs、plans
- .editorconfig / .gitignore — 编码与忽略约定
- 记忆文件（如 .zcode/memories/）— 项目级规则

必提取：
- 可改范围（哪些目录可改、哪些只读、只读区修改机制）
- 改造分类（A类/B类、core/plugin、src/lib——决定编码节点怎么写）
- 分支规范：命名（feat/fix/refactor）、合入策略（merge --no-ff/squash/rebase）、保护分支、推送规则
- 文档约定：spec/plan 存放位置、命名格式（如 YYYY-MM-DD-<topic>-design.md）
- 安全规则：脱敏、密钥管理、网络白名单、框架安全基线
```

### C. 代码组织与外部资源（含可复用稳定单元盘点 + 版本基线 + 安全机制 + 平台差异）

```
必查：
- 源码目录结构、模块划分
- 组件库清单：主要组件模块、关键组件名、store/状态管理位置、组件计数
- 组件依赖链路：从 App 入口到子组件的挂载树/依赖关系
- 接口清单：API 入口（控制器/路由文件）、OpenAPI 生成方式（tsoa/swagger/正则扫描）、认证机制
- 数据模型：schema 定义位置（SQL/migration/ORM model）、数据流、业务规则
- 安全机制：SSRF 防御、XSS、CSRF、认证授权、密钥管理

★必查（版本锁定铁律——核心依赖版本基线）：
- 列出 package.json/pyproject.toml/go.mod/Cargo.toml 全部依赖及其精确版本
- 标注哪些是核心技术（框架/runtime/构建工具）哪些是基础组件（UI库/状态/路由）
- 记录到特征卡第 4 项（技术栈）→ codebase.md 技术栈版本表（precheck.sh --deps 的对比基线）
- 任何后续版本变更须经用户确认 + 在 spec 版本约束声明段声明理由

★必查（安全规范覆盖——盘点既有安全机制）：
- 认证授权机制：JWT/Session/OAuth/API Key 的实现位置与校验中间件
- 输入校验：是否用 zod/joi/express-validator/pydantic 参数校验
- 输出编码：XSS 防护（是否用 DOMPurify / 框架自动转义）
- 密钥管理：密钥来源（环境变量/配置中心/密钥管理服务）、是否硬编码
- 传输安全：TLS 配置、HSTS、CSP、CORS 策略
- 日志安全：是否过滤敏感字段、是否记录完整请求体
- 依赖安全：是否用 npm audit / pip-audit / snyk / dependabot

★必查（三平台兼容——Windows/macOS/Linux 差异）：
- 脚本兼容：是否有 .sh + .ps1 双版本、是否用跨平台工具（node 脚本替代 sed/awk）
- 路径分隔符：是否硬编码 / 或 \、是否用 path.join / pathlib
- 平台特定逻辑：是否有 process.platform / os.name 分支
- 原生模块：是否含 node-gyp / native addon（须三平台预编译或构建）
- 文件系统：大小写敏感（Linux）vs 大小写不敏感（macOS/Windows）、符号链接行为差异
- 行尾符：CRLF(Windows) vs LF(macOS/Linux) 的 .gitattributes 配置
- 端口/权限：<1024 端口需 root（Linux/macOS）、Windows UAC


★必查（拼装式开发核心——可复用稳定单元盘点）：
- 可复用 API 接口：列出全部稳定 API（方法/路径/签名/用途/认证/复用方式）
- 可复用组件：列出全部稳定 UI 组件（组件名/路径/Props/用途/复用方式）
- 可复用类/函数/方法：列出全部稳定类/函数/方法/composable（签名/路径/用途/复用方式）
- 可复用 Store：列出全部状态管理 store（路径/暴露的状态和方法/复用方式）
- 可复用类型定义：列出全部 TS interface/type（路径/定义/复用方式）
- 稳定性标注：区分稳定层（推荐复用）/不稳定层（慎用）/禁止改层
  → 用 gitnexus mcp 或 graphify path 系统性盘点调用链/依赖链，而非随机 grep
  → 每个稳定单元记录：签名、路径、用途、复用方式（供 dev-guide.md 引用）
- 测试体系：框架、目录、运行命令、测试案例数据

必查（环境与外部资源——材料 assets 段要求）：
- 开发环境依赖：node/python/go/java 版本要求（engines/runtime）
- 外部资源：数据库（MySQL/PostgreSQL/SQLite/MongoDB）、缓存（Redis）、消息队列（Kafka/RabbitMQ/RocketMQ）、搜索（ES/ELK）
  → 连接方式（连接串格式、端口、env 变量名）
  → 是否有 MCP 工具接入（DB 查询工具、ELK 查询、Redis 访问）
- 静态资源：图片/字体/配置文件位置、下载/填充方式
- 样例数据：seed/fixture/mock 数据位置与格式
- CI/CD：.github/workflows、Jenkinsfile、部署流程
```

## 各语言项目探查要点

### Node.js / 前端
- package.json: name, version, scripts, engines, type, dependencies/devDependencies 关键框架
- 构建配置：vite.config / webpack.config / tsconfig / electron-builder.yml
- 目录：src/ packages/ apps/ monorepo?
- overlay-fork 类：overlay/ upstream/ 分离、patch 机制（patches/series? inject 脚本?）、符号链接、alias 链

### Python
- pyproject.toml / setup.py / requirements.txt: 依赖、版本、entry points
- 构建：poetry / pip / setup.py / Makefile
- 目录：src/ pkg/ tests/ scripts/
- 测试：pytest / unittest，conftest.py
- lint：ruff / black / mypy / flake8

### Go
- go.mod: module path, go version, 关键依赖
- Makefile: build/test/lint/run targets
- 目录：cmd/ internal/ pkg/ api/
- 测试：*_test.go，go test 命令

### Rust
- Cargo.toml: name, edition, dependencies, [[bin]]/[lib]
- 构建：cargo build/test/run，features
- 目录：src/ examples/ tests/ benches/
- workspace 成员（monorepo）

### Java
- pom.xml / build.gradle: groupId, artifactId, version, 依赖
- 构建：maven / gradle
- 目录：src/main/java, src/test/java
- 框架：Spring Boot? 需查 application.yml/properties（DB/Redis/MQ 连接配置）

### Monorepo
- 根 package.json (workspaces) / pnpm-workspace.yaml / turbo.json / nx.json
- 各子包的 scripts，包间依赖关系
- 哪些包可改、哪些 vendored/只读

## 环境与资源检测探查（材料 assets §1/§2）

探查时必须确认开发环境与外部资源的可检测性，供目标技能的 `env-setup.sh` 使用：

```bash
# 运行时版本
node --version; python --version; go version; java -version; rustc --version

# 外部资源连通性（按项目实际，探查连接方式）
# 数据库
# 缓存
# 消息队列
# 搜索引擎

# 工具权限
git --version; gh --version; docker --version
```

探查到的连接方式（连接串格式、env 变量名、端口）写入目标技能的 `env-setup.sh` 和 `mcp-tools.md`。

## MCP 工具探查（材料 scripts §2）

探查项目是否有可接入的 MCP 工具（数据库、ELK、Redis、MQ、dubbo、union、CMDB 等）：

- 项目是否依赖外部服务 → 是否有现成的 MCP/CLI 查询工具
- 数据库：是否有 psql/mysql/mongosh CLI？是否有 MCP DB 工具？
- ELK：是否有 kibana API？curl 查询样例？
- Redis：是否有 redis-cli？连接方式？
- MQ：是否有管理 API（Kafka topics、RabbitMQ management）？
- dubbo/union：是否有注册中心查询接口？
- CMDB：是否有资产查询 API？

探查到的 MCP 工具接入方式写入目标技能的 `scripts/mcp-tools.md`。无外部资源的，标注"本项目无外部 MCP 资源"。

## 提取项目特征卡

探查完成后，整理成结构化特征卡（供 Step 3 填充模板用）：

```markdown
## 项目特征卡：<项目名>

### 1. 项目类型
（单体/monorepo/overlay-fork/微服务/库）

### 2. 可改范围
- 可改：<目录列表>
- 只读：<目录列表>
- 只读区修改机制：<patch/overlay/插件机制，或"不允许修改">

### 3. 改造分类
（项目特有的改动分类。若无明确分类，标注"默认：按目录分区"）

### 4. 技术栈摘要（含版本基线——版本锁定铁律依据）
（一句话：语言 + 主框架 + 构建 + 测试）

> ★版本基线表（precheck.sh --deps 的对比基线，必须精确到版本号）：
> | 依赖名 | 版本 | 类型(核心/基础/开发) |
> |--------|------|---------------------|
> （从 package.json/pyproject.toml/go.mod/Cargo.toml 提取全部依赖精确版本）

### 5. 构建发布命令
| 用途 | 命令 |
|------|------|
| dev | |
| build | |
| test | |
| release | |
端口约定：（如有）

### 6. 分支规范
- 命名：feat/* | fix/* | ...
- 合入策略：merge --no-ff / squash / rebase
- 保护分支：<列表>
- 推送规则：自动/需确认

### 7. 安全规则
- 脱敏：<规则来源>
- 密钥管理：<方式>
- 网络白名单：<机制>

### 8. 文档约定
- spec 位置：<路径>，命名：<格式>
- plan 位置：<路径>，命名：<格式>

### 9. 测试体系
- 框架：<vitest/jest/pytest/go test>
- 目录：<路径>
- 运行：<命令>

### 10. 环境与外部资源
- 运行时版本要求：<node>=23 / python>=3.11 / ...>
- 外部资源：DB=<类型+连接方式> / 缓存=<...> / MQ=<...> / 搜索=<...>
- MCP 工具：<有的列出，无则"无">

### 11. 可复用稳定单元清单（拼装式开发的核心依据）

> 这是拼装式开发的关键。研发人员基于既有稳定单元（接口/组件/类/函数/方法）进行拼装，而非重复造轮子或侵入式重构。特征卡必须**准确、全面、完整**地盘点可复用单元，供目标技能的 dev-guide.md 和 spec-template.md 引用。

#### 11a. 可复用 API 接口
| 接口签名 | 方法 | 路径 | 用途 | 认证 | 复用方式 |
|----------|------|------|------|------|---------|
| `GET /api/xxx/:id` | GET | /api/xxx/:id | 查询单个 | Bearer | 前端 @/api 调用 |
| `POST /api/xxx` | POST | /api/xxx | 创建 | Bearer | 前端 @/api 调用 |
（列出项目全部稳定 API，含控制器/路由文件位置）

#### 11b. 可复用组件
| 组件名 | 路径 | Props | 用途 | 复用方式 |
|--------|------|-------|------|---------|
| `<Button>` | @/components/... | type,onClick | 按钮 | import 直接用 |
（列出项目全部稳定 UI 组件，含 props 签名）

#### 11c. 可复用类/函数/方法
| 名称 | 类型 | 签名 | 路径 | 用途 | 复用方式 |
|------|------|------|------|------|---------|
| `useAuth` | composable | `() => { user, login, logout }` | composables/useAuth | 认证 | import 调用 |
| `formatDate` | 函数 | `(ts: number) => string` | utils/date | 格式化日期 | import 调用 |
| `DatabaseSync` | 类 | `new DatabaseSync(path)` | node:sqlite | DB | 内置 |
（列出项目全部稳定类/函数/方法/composable/store/工具函数，含完整签名）

#### 11d. 可复用 Store（状态管理）
| Store | 路径 | 暴露的状态/方法 | 复用方式 |
|-------|------|----------------|---------|
| `useCockpitStore` | store/cockpit | tasks, addTask, removeTask | 组件中调用 |
（列出项目全部 Pinia/Vuex/Redux store）

#### 11e. 可复用类型定义
| 类型 | 路径 | 定义 | 复用方式 |
|------|------|------|---------|
| `TraceNode` | adapters/... | `{ id, name, cluster }` | import type |
（列出项目全部 TS interface/type，供新功能直接引用）

#### 11f. 稳定性标注
- **稳定层**（推荐复用）：公共 API、公共组件、工具函数、类型定义、store 接口
- **不稳定层**（慎用）：内部实现细节、私有方法、实验性代码、标注 @deprecated 的
- **禁止改层**：upstream 骨架、第三方依赖、框架核心

> 探查时用 `gitnexus analyze` + `gitnexus mcp` 或 `graphify .` 构建图谱，用图谱查询调用链/依赖链，**系统性盘点**而非随机 grep。对每个稳定单元记录：签名、路径、用途、复用方式。

### 12. 数据规范
- schema 位置：<路径>
- 样例数据：<位置/格式>
- 业务规则：<关键规则>
- 勾稽关系：<外键/聚合/关联>

### 13. 四层认知基底（探查时记录基线，供 --cognition 体检对比）
> 此项不是"额外填写"，而是把前 12 项的认知状态做一次总结，形成可对比趋势的基线。

#### 13a. 认知映射表（六阶认知链落点）
| 认知阶 | 项目落点 | 文件 |
|--------|---------|------|
| ①概念 | 领域实体/稳定单元 | reference-manual §4/5/6 |
| ②结构 | 分层依赖方向 | dev-guide 分层图 |
| ③空间 | 服务/组件目录 | codebase.md |
| ④映射 | 术语↔代码↔目录 | glossary+codebase |
| ⑤规律 | 项目铁律 | dev-guide §7 |
| ⑥处理 | fail/warn/spec/ADR | precheck+spec |

#### 13b. 六维动力学基线（探查时记录值，后续 --cognition 对比趋势）
| 维度 | 基线值 | 观测方式 |
|------|--------|---------|
| 速度 | 单次变更 X 文件 | git diff --name-only |
| 聚散 | N 服务/M 组件 | find dirs |
| 趋势 | 依赖深度 X | graphify/madge |
| 强度 | 同步调用 X 处 | grep fetch/axios |
| 能耗 | store X 行/props X 个 | wc -l/awk |
| 累积量 | TODO X 处/技术债 X 条 | grep TODO |

#### 13c. 四层认知状态（探查时标注是否已建立）
- 第一层 认知递进：☐已建立（特征卡 12 项完整 + 认知映射表）☐未建立
- 第二层 思维语言：☐已建立（spec 含 §14 交付衰减/§15 蓝图段）☐未建立
- 第三层 认知辩证：☐已建立（workflow 4-Phase + 逻辑剃刀审查）☐未建立
- 第四层 偏差防范：☐已建立（spec §16 偏差自检 + 谬误图谱）☐未建立
```

### 14. 领域知识识别（技术领域 + 业务领域）
> 探查时必须识别项目所属的技术领域与业务领域，补充该领域的专业知识规则。
> 防范达克效应：不懂领域就生成 skill = 过度自信。领域知识是"稳定单元清单"的上层——不了解领域，就无法判断哪些单元是稳定的。

#### 14a. 技术领域识别
| 识别项 | 探查方法 | 示例 |
|--------|---------|------|
| 技术栈类别 | 读 package.json/go.mod/Cargo.toml 的依赖 | 前端(Vue/React)、后端(Node/Go/Java)、桌面(Electron)、移动(Flutter) |
| 数据存储类别 | 读 ORM/DB 配置/迁移文件 | 关系型(SQLite/PostgreSQL)、文档型(MongoDB)、缓存(Redis)、搜索(ES) |
| 通信模式 | 读 API/消息/MQ 配置 | REST/GraphQL/gRPC、同步/异步、长连接/WebSocket |
| 部署模式 | 读 Dockerfile/CI/构建脚本 | 单体/微服务/Serverless/桌面应用/嵌入式 |
| 安全模型 | 读认证/授权/加密代码 | Session/JWT/OAuth、RBAC/ABAC、传输层(TLS)/存储层(加密) |

#### 14b. 业务领域识别
| 识别项 | 探查方法 | 示例 |
|--------|---------|------|
| 业务类别 | 读领域模型/表名/API路径/文档 | 电商/IM通讯/CRM/ERP/监控/DevOps/教育/金融 |
| 业务核心实体 | 从领域模型/ORM/DB schema 提取 | Order/Customer/Message/Task/Report |
| 业务规则 | 从代码注释/测试用例/文档提取 | "订单金额=Σ明细×单价×折扣"、"消息已读后不重发" |
| 合规约束 | 从文档/代码中的 license/隐私/审计 | GDPR/等保/PCI-DSS/数据脱敏/审计日志 |
| 行业标准 | 从依赖/文档/代码模式识别 | OAuth2.0/OIDC/FHIR/MQTT/HL7/SOLID/CLEAN |

#### 14c. 领域深入分析（动态识别后推导客观规律，非套用静态清单）
> 识别领域后，必须对该领域做**深入分析**，推导出该领域在本项目中的**具体客观规律**。
> 这些规律不是从通用清单复制的——而是从项目的实际代码、数据流、业务规则、约束条件中**分析得出**的。
> **铁律：领域规则不得违反通用常识和客观规律。** 推导出的每条规律须标注其依据（代码证据/文档证据/行业常识）。

**分析流程（每步须产出具体结果，不可跳过）：**

```
Step 1: 动态识别领域边界
  → 从 14a/14b 的识别结果，确定项目涉及哪些技术领域 + 业务领域
  → 产出："本项目涉及以下领域：[领域A, 领域B, ...]"

Step 2: 逐领域深入分析
  → 对每个识别出的领域，回答以下问题（须有代码/文档证据）：
    (1) 该领域在本项目中的核心实体是什么？（从代码提取，非猜测）
    (2) 这些实体间的因果关系是什么？（A 导致 B，B 依赖 C）
    (3) 该领域有哪些不可违反的物理/逻辑约束？（从代码模式+行业常识推导）
    (4) 当前代码是否遵循了这些约束？有无违反迹象？
    (5) 这些约束在本次变更中是否可能被破坏？

Step 3: 推导客观规律
  → 基于 Step 2 的分析，推导出该领域在本项目中的客观规律
  → 每条规律格式："因为 [代码证据/文档证据/行业常识]，所以 [客观规律]，违反则 [后果]"
  → 产出：写入 reference-manual.md "领域知识"段
```

**分析示例（以 IM 通讯领域为例，展示"动态分析→推导"过程）：**

| 分析步骤 | 具体产出 |
|---------|---------|
| Step 1 识别 | 识别到项目含 IM 通讯领域（依据：custom/client/chat/ 目录 + Matrix 协议依赖 + gateway-notice.ts） |
| Step 2(1) 核心实体 | Message（消息）、Thread（会话线程）、Gateway（网关）——从代码类名提取 |
| Step 2(2) 因果关系 | Gateway 状态变化 → 触发 Notice → 展示 Banner → 用户感知；消息发送 → 经过网关 → 落库 → 推送 |
| Step 2(3) 客观约束 | 因为消息有时序性（代码证据：timeline 排序逻辑），所以消息顺序不可乱；因为已读状态会被多端同步（代码证据：多端 ACK 逻辑），所以已读须幂等；因为网关可能断线（代码证据：重连逻辑），所以离线消息须缓存 |
| Step 2(4) 遵循情况 | 当前代码遵循时序（timeline 按 timestamp 排序）✓；已读状态无幂等键 ⚠ |
| Step 2(5) 变更风险 | 本次变更如改消息发送逻辑，须保证时序不乱；如改已读逻辑，须加幂等键 |
| Step 3 推导规律 | "因为消息有时序性（timeline 排序），所以消息发送/存储须保序，违反则消息错乱"；"因为已读状态多端同步，所以已读更新须幂等（idempotency-key），违反则重复通知" |

> **关键区别：** 上面的规律不是从通用清单复制的"消息有序性须保证"——而是从项目实际代码（timeline 排序逻辑）分析得出的**具体约束**（"因为 timeline 按 timestamp 排序，所以须保序"）。通用清单只做参考，具体规律须从代码证据推导。

**通用领域约束参考（仅作分析起点，不直接复制到 reference-manual）：**

| 领域 | 分析起点（须结合项目代码验证后写入） |
|------|--------------------------------------|
| 数据库 | 事务边界在哪？外键关系是什么？哪些查询是 N+1？索引策略？ |
| 网络 | 通信协议是什么？无状态如何维持会话？超时/重试策略？ |
| 安全 | 认证流程？密钥存储方式？输入验证在哪层？ |
| 并发 | 共享状态在哪？锁策略？有无竞态条件？ |
| 前端 | 渲染策略？状态管理？性能瓶颈在哪？ |
| 分布式 | 一致性模型？分区容忍策略？幂等设计？ |
| IM/通讯 | 消息时序保证？已读幂等？离线缓存？推送去重？ |
| 电商 | 库存扣减方式？价格版本化？订单状态机？ |
| DevOps | 构建可重复性？回滚机制？配置分离？监控覆盖？ |

> 探查时从上表选取涉及领域作为**分析起点**，但每条规律须从项目代码证据推导，不可直接复制通用条目。precheck `--domain` 检查：reference-manual 领域知识段的每条规律是否标注了依据（代码证据/文档证据/行业常识）。
```

## 探查不到时的处理

某项探查不到时：
1. 先确认是否真的没有（换关键词再搜）
2. 确实没有 → 填合理默认值，在目标技能中标注 `（默认约定，可调整）`
3. 默认值参考：
   - 分支命名：`feat/*` `fix/*` `refactor/*`
   - 合入：`git merge --no-ff`
   - 推送：不自动推送（需确认）
   - spec/plan：`docs/specs/` `docs/plans/`，命名 `YYYY-MM-DD-<feature>.md`
   - 测试目录：`tests/` 或 `__tests__/`
   - 环境/资源/MCP：无则标注"本项目无此项"

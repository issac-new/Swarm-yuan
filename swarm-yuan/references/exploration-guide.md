# 仓库探查指南 (Repository Exploration Guide)

生成目标技能前，必须先探查目标仓库。本指南说明如何高效探查各类项目，**包括环境依赖、外部资源、MCP 工具**。

## 探查策略

**用 Agent 子代理并行探查**（Explore 类型），三路并行：

- **路 A：结构与构建** — 顶层目录、package.json/构建文件、scripts、端口、构建系统、测试体系
- **路 B：开发规范** — AGENTS.md/CLAUDE.md/CONTRIBUTING/README、分支策略、文档约定、改造分类
- **路 C：代码组织与外部资源** — 源码目录、组件库、接口、数据模型、安全机制、**环境依赖、外部资源（DB/缓存/MQ）、MCP 工具、静态资源、样例数据**

每路子代理的 prompt 要明确"报告具体路径、命令名、版本号、文件名、连接串格式、端口"。

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

### C. 代码组织与外部资源

```
必查：
- 源码目录结构、模块划分
- 组件库清单：主要组件模块、关键组件名、store/状态管理位置、组件计数
- 组件依赖链路：从 App 入口到子组件的挂载树/依赖关系
- 接口清单：API 入口（控制器/路由文件）、OpenAPI 生成方式（tsoa/swagger/正则扫描）、认证机制
- 数据模型：schema 定义位置（SQL/migration/ORM model）、数据流、业务规则
- 安全机制：SSRF 防御、XSS、CSRF、认证授权、密钥管理
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

### 4. 技术栈摘要
（一句话：语言 + 主框架 + 构建 + 测试）

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

### 11. 组件库与接口
- 主要组件模块：<列表>
- API 入口：<控制器/路由文件>
- OpenAPI 生成：<方式>
- 认证机制：<方式>

### 12. 数据规范
- schema 位置：<路径>
- 样例数据：<位置/格式>
- 业务规则：<关键规则>
- 勾稽关系：<外键/聚合/关联>
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

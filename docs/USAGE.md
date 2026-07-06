# swarm-yuan 使用说明

> 对 AI 说"为这个项目生成 skill"，AI 全自动探查 → 生成 → 配置 → 验证，你拿到一套零占位符的项目专属开发技能。

---

## 1. 它解决什么问题

| 痛点 | swarm-yuan 怎么解决 |
|------|-------------------|
| 接手新项目要花一周摸索结构/规则/组件 | AI 5 分钟自动探查，生成 14 项特征卡（每项落到真实路径） |
| AI 写代码不知道项目规则 | 生成的目标技能内置铁律+门禁，AI 编码时自动遵守 |
| 代码审查靠人工漏检率高 | 25 个门禁自动检查（分支→安全→复用→领域知识） |
| 每次提交前手动检查一堆东西 | `bash precheck.sh --all` 一条命令跑完核心 10 门禁 |

## 2. 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

| 选项 | 安装到 |
|------|--------|
| （无参数） | 自动检测（检测到多个时交互选择） |
| `--claude` | `~/.claude/skills/` |
| `--codex` | `~/.codex/skills/` |
| `--cursor` | `~/.cursor/skills/` |
| `--windsurf` | `~/.codeium/windsurf/skills/` |
| `--opencode` | `~/.config/opencode/skills/` |
| `--gemini` | `~/.gemini/skills/` |
| `--kimi` | `~/.kimi/skills/` |
| `--all` | 所有已检测到的环境 |
| `--list` | 仅列出检测到的环境 |

## 3. 生成项目技能

对 AI 说："为 /path/to/my-project 生成 skill"

或用 slash 命令：`/swarm-yuan /path/to/my-project`

AI 自动执行 11 步流程，**不允许中途停在骨架阶段**：

| 步骤 | 做什么 |
|------|--------|
| 0 | 自检 10 个运行时工具 |
| 0.5 | 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / hermes-agent） |
| 1 | 三路并行探查代码库（结构 / 规范 / 代码组织） |
| 2 | **提取 14 项特征卡**（每项落到真实路径，不用占位符） |
| 3 | 创建骨架（含 hooks / commands / precheck.conf） |
| 4 | AI 填充全部文件——**消除全部占位符** |
| 5 | AI 配置 precheck.conf（45 个变量从特征卡推导） |
| 5.5 | AI 生成 hooks / commands / MCP 集成 |
| 6 | AI 运行门禁验证（`--all` → `--all-full`） |
| 7 | AI 写回项目记忆（闭环） |
| 8 | AI 最终检查——grep 确认**零占位符残留** |

完成后你拿到：

```
你的项目/.claude/skills/my-project-dev/
├── SKILL.md                  ← 已填充（项目定位/铁律/命令速查/门禁）
├── hooks/hooks.json          ← Claude Code 钩子
├── commands/                 ← slash 命令
├── scripts/
│   ├── precheck.sh           ← 25 个门禁
│   ├── precheck.conf         ← 45 个变量（AI 自动填充）
│   └── ...
├── assets/
│   └── spec-template.md      ← spec 模板
└── references/               ← 全部已填充（零占位符）
```

## 4. 特征卡：项目的"认知 DNA"

特征卡是 swarm-yuan 的核心产物——它是 AI 探查项目后提取的**14 项项目特征**，每项落到真实路径和版本号。特征卡不是独立文件，而是**分散承接进目标 skill 的各个文件中**，驱动后续的门禁配置和开发流程。

### 14 项特征卡

| # | 特征项 | 提取什么 | 承接到哪个文件 | 驱动哪个门禁 |
|---|--------|---------|--------------|-------------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | SKILL.md + codebase.md | `--cognition` ①概念 |
| 2 | 可改范围 | 哪些目录能改、哪些只读、只读区修改机制 | SKILL.md 铁律 + dev-guide.md + precheck.conf | `--scope` |
| 3 | 改造分类 | A类/B类、core/plugin、src/lib | SKILL.md + dev-guide.md | `--layer` |
| 4 | 技术栈摘要 | 语言+主框架+构建+测试（含版本基线） | codebase.md 版本表 | `--deps` |
| 5 | 构建发布命令 | dev/build/test/release 真实命令 + 端口 | SKILL.md 命令速查 + release.md + precheck.conf | `--build` `--test` |
| 6 | 分支规范 | 命名格式、合入策略、保护分支、推送规则 | SKILL.md 铁律 + branch-setup.sh + precheck.conf | `--branch` |
| 7 | 安全规则 | 脱敏规则、密钥管理、网络白名单 | reference-manual.md §2 + precheck.conf SCAN_DIRS | `--sensitive` `--security` |
| 8 | 文档约定 | spec/plan 位置、命名格式 | workflow.md + spec-template.md | — |
| 9 | 测试体系 | 框架、目录、运行命令 | reference-manual.md check §1 + precheck.conf TEST_CMD | `--test` |
| 10 | 环境与外部资源 | 运行时版本、DB/缓存/MQ、MCP 工具 | env-setup.sh + codebase.md + mcp-tools.md + precheck.conf | `--service` |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（签名+路径+用途+复用方式+稳定性标注） | reference-manual.md §4/5/6 + dev-guide.md §7 + spec-template §5.5 + precheck.conf STABLE_GLOBS | `--reuse` |
| 12 | 数据规范 | schema 位置、样例数据、业务规则、勾稽关系 | reference-manual.md §8 + data-sample-template.md | `--consistency` |
| 13 | 四层认知基底 | 认知映射表 + 六维动力学基线（速度/聚散/趋势/强度/能耗/累积量） | reference-manual.md + precheck.conf COG_* | `--cognition` |
| 14 | 领域知识 | 技术+业务领域识别 → 推导客观规律（防达克效应） | reference-manual.md 领域知识段 + spec-template §18 | `--domain` |

### 特征卡的关键特性

**每项落到真实值，不用占位符。** 特征卡不是"填表"——AI 用代码图谱工具（gitnexus/graphify）系统性盘点，而非随机 grep。第 11 项"可复用稳定单元"是**最重要的一项**，它盘点的全部稳定单元（接口/组件/类/函数/store/类型定义，每个含签名/路径/用途/复用方式/稳定性标注）是拼装式开发的核心依据。

**特征卡驱动门禁配置。** precheck.conf 的 45 个配置变量从特征卡推导：WRITABLE_DIRS 来自第 2 项、TEST_CMD 来自第 5 项、LAYER_DEFS 来自第 3 项、SERVICE_DIRS 来自第 10 项、STABLE_GLOBS 来自第 11 项……特征卡是门禁的"大脑"。

**特征卡驱动文件填充。** SKILL.md 的铁律来自第 2/6 项、codebase.md 的技术栈来自第 4 项、dev-guide.md 的改造分类来自第 3 项、reference-manual.md 的组件库来自第 11 项……特征卡是目标 skill 所有文件的"数据源"。

### 特征卡探查工具矩阵

每项探查优先用运行时工具，无则降级：

| # | 特征项 | 优先工具 | 降级 |
|---|--------|---------|------|
| 1 | 项目类型 | gitnexus `query "architecture"` + graphify `explain` | Read package.json |
| 2 | 可改范围 | claude-mem `search "project rules"` + Read AGENTS.md | Glob + Grep |
| 4 | 技术栈 | gitnexus `query "tech stack"` + graphify `explain` | Read package.json |
| 9 | 测试体系 | gitnexus `query "test files"` | Glob `**/*.test.*` |
| 10 | 环境资源 | gitnexus `route_map` + `tool_map` | Grep "host/port/url" |
| 11 | 可复用单元 | **gitnexus `context <symbol>`**（360 度上下文） | Grep `export` |
| 12 | 数据规范 | gitnexus `query "data models"` | Grep `CREATE TABLE` |
| 14 | 领域知识 | gitnexus `query "domain entities"` + claude-mem + WebSearch | Read 领域模型 |

大型项目（>100 文件）可用 Dynamic Workflow 并行扇出三路子代理，每路用不同工具，最后交叉验证特征卡。

### 落地示例（SwarmStudio overlay 项目）

| # | 特征项 | 真实值 |
|---|--------|--------|
| 1 | 项目类型 | overlay 注入式二次开发（Vue 3 + Electron 桌面应用） |
| 2 | 可改范围 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | 改造分类 | A类（custom/ 纯新增，Vite alias）+ B类（patches/ 骨架修改，git apply） |
| 4 | 技术栈 | Vue 3 + TypeScript + Vite + NaiveUI + Vitest + SQLite + Koa + Electron |
| 5 | 构建命令 | `npm run dev`(:8649) / `npm run build` / `npm test` / `npm run inject` |
| 11 | 可复用单元 | CockpitWorkspace / CockpitKanban / CockpitChatPane / GatewayNoticeBanner / KanbanMarkdown 等 15+ 组件 |
| 14 | 领域知识 | IM 通讯（Matrix 协议）+ DevOps 监控（cockpit 看板） |

## 5. 日常使用

### 开始新需求

对 AI 说："开始新需求：给 cockpit 添加通知面板"

AI 自动：创建 spec 文件 → 判断规模 → 预填复用约束（从特征卡第 11 项检索可复用单元）→ 验证。

或用 slash 命令：`/my-project-dev:spec <需求描述>`

| 规模 | 填哪些段 | 典型场景 |
|------|---------|---------|
| 简单 | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 |
| 标准 | §1-§13 + §5.5/§5.6/§5.7 约束段 | 新功能 / 改接口 |
| 完整 | 全部 18 段（含 §14-§18 认知/辩证/领域） | 架构变更 / 跨服务 |

### 提交前自检

对 AI 说："跑门禁"

或直接运行：

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁（~5 秒）
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 全部 25 门禁（~30 秒）
```

**结果解读**：`✓` 通过 / `✗` 必须修复 / `⚠` 人工评估

### 单独跑某个门禁

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse
bash .claude/skills/my-project-dev/scripts/precheck.sh --cognition
bash .claude/skills/my-project-dev/scripts/precheck.sh --domain
```

## 6. 25 个门禁

### 核心门禁（`--all` 跑 10 个）

| 门禁 | 检查什么 | fail 条件 |
|------|---------|----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 |
| `--scope` | 改动范围（可改 vs 只读） | 只读目录有改动 |
| `--build` | 构建通过 | 构建失败 |
| `--sensitive` | 敏感信息脱敏 | 密码 / 密钥 / token 明文 |
| `--consistency` | 业务规则 + 数据勾稽 | 人工核对项（提示性） |
| `--review` | 代码审查（5 维度） | ocr 检测到 High 级问题 |
| `--reuse` | 复用合规（拼装式开发） | spec 缺 §5.5 / 新增单元与既有重名 |
| `--deps` | 依赖版本锁定 | 依赖版本变更但 spec 未声明 |
| `--security` | 安全规范（OWASP Top 10） | 注入 / eval / XSS / 硬编码密钥 / TLS 关闭 |
| `--test` | 测试通过 | 测试失败 |

### 架构门禁（`--all-full` 额外跑 15 个，未配置则静默跳过）

| 门禁 | 检查什么 | 需要配置 |
|------|---------|---------|
| `--layer` | DDD 分层边界 | LAYER_DEFS |
| `--stable-diff` | 稳定单元篡改 | STABLE_GLOBS |
| `--link-depth` | 调用链深度 | MAX_LINK_DEPTH |
| `--adr` | 架构决策记录 | ADR_DIR |
| `--contract` | 接口契约 + ACL | CONTRACT_DIR |
| `--consistency-cross` | BDAT 一致性 | GLOSSARY_FILE |
| `--impact` | 变更影响分析 | — |
| `--service` | 微服务架构 | SERVICE_DIRS |
| `--api` | API 契约与幂等 | API_SPEC_DIR |
| `--state` | 前端状态管理 | STORE_DIR |
| `--frontend` | 前端组件架构 | COMPONENT_DIR |
| `--cognition` | 认知递进体检 | — |
| `--domain` | 领域知识违规检测 | — |
| `--knowledge` | 项目知识复用 | — |
| `--mermaid` | Mermaid 可视化 | — |

### 降级策略

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | gitnexus → graphify → madge | 转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--review` | ocr review / `claude ultrareview` | AI 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |

## 7. precheck.conf 配置

AI 生成目标技能时自动从特征卡推导 45 个变量。如需手动调整，编辑 `scripts/precheck.conf`：

```bash
# 基础（必填）
PROJECT_DIR="/path/to/project"           # ← 特征卡第 1 项
WRITABLE_DIRS=("src" "lib")              # ← 特征卡第 2 项
TEST_CMD="npm test"                      # ← 特征卡第 5 项
BUILD_CMD="npm run build"                # ← 特征卡第 5 项

# DDD 分层（← 特征卡第 3 项，可选）
LAYER_DEFS=("presentation=src/controllers/**" "domain=src/domain/**")
STABLE_GLOBS=("src/domain/**")           # ← 特征卡第 11 项

# 微服务（← 特征卡第 10 项，可选）
SERVICE_DIRS=("services/order" "services/payment")

# 前端（← 特征卡第 10 项，可选）
STORE_DIR="src/store"                    # ← 特征卡第 11 项
```

> 留空的配置项对应门禁在 `--all-full` 中静默跳过。

## 8. 升级

对 AI 说："升级 my-project-dev skill"

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板 / 保留项目特定文件 / 自动备份 / AI 重新填充 precheck.conf。

## 9. FAQ

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"，AI 自动分析+调整+重跑。也可直接编辑 `precheck.conf`。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。核心约束：先声明复用了什么，再写代码。

**Q: 不需要微服务/前端/TOGAF？** → AI 自动识别项目类型，不适用门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。AI 重新探查 → 更新特征卡 → 更新 precheck.conf。

**Q: hooks/commands 是什么？** → `hooks/hooks.json`（SessionStart + PreToolUse）+ `commands/`（/spec, /precheck, /explore）。

## 10. 流程

```
首次：
  bash install.sh --claude
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动（11 步，零占位符）
    → 特征卡 14 项驱动全部文件+门禁配置

日常：
  对 AI 说 "开始新需求：xxx"
    → AI 创建 spec + 判断规模 + 预填复用约束
    → 编码（AI 查特征卡第 11 项可复用单元，拼装优先）
      → 提交前：对 AI 说 "跑门禁"
        ├→ 全 ✓ → 提交
        ├→ 有 ✗ → 修复重跑
        └→ 有 ⚠ → 评估

架构审查：
  对 AI 说 "跑全量门禁"

升级：
  对 AI 说 "升级 skill"
```

## 11. 数字一览

| 维度 | 数值 |
|------|------|
| 特征卡 | **14 项**（驱动全部文件+门禁配置） |
| 质量门禁 | 25（核心 10 + 架构 15） |
| 运行时工具 | 10 |
| spec 模板 | 22 段（分级填写） |
| reference 文档 | 13 个 |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 配置变量 | 45 个（从特征卡推导） |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |

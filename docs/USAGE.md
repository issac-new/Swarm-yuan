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

install.sh 自动检测已安装的 AI 工具，安装到对应目录：

| 选项 | 安装到 | 说明 |
|------|--------|------|
| （无参数） | 自动检测 | 检测到多个时交互选择 |
| `--claude` | `~/.claude/skills/` | Claude Code |
| `--codex` | `~/.codex/skills/` | Codex |
| `--cursor` | `~/.cursor/skills/` | Cursor |
| `--windsurf` | `~/.codeium/windsurf/skills/` | Windsurf |
| `--opencode` | `~/.config/opencode/skills/` | OpenCode |
| `--gemini` | `~/.gemini/skills/` | Gemini CLI |
| `--kimi` | `~/.kimi/skills/` | Kimi |
| `--all` | 所有已检测到的 | 一次装到所有环境 |
| `--list` | — | 仅列出检测到的环境 |

安装后自动注册 slash command（`/swarm-yuan`）并运行 10 个运行时工具的自检。

## 3. 生成项目技能

对 AI 说：

```
为 /path/to/my-project 生成 skill
```

或用 slash 命令：

```
/swarm-yuan /path/to/my-project
```

AI 自动执行 11 步流程，**不允许中途停在骨架阶段**：

| 步骤 | 做什么 |
|------|--------|
| 0 | 自检 10 个运行时工具 |
| 0.5 | 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / hermes-agent） |
| 1 | 三路并行探查代码库（结构 / 规范 / 代码组织） |
| 2 | 提取 14 项特征卡（每项落到真实路径，不用占位符） |
| 3 | 创建骨架（含 hooks / commands / precheck.conf） |
| 4 | AI 填充全部文件——**消除全部占位符** |
| 5 | AI 配置 precheck.conf（45 个变量从特征卡推导） |
| 5.5 | AI 生成 hooks / commands / MCP 集成 |
| 6 | AI 运行门禁验证（`--all` → `--all-full`） |
| 7 | AI 写回项目记忆（闭环） |
| 8 | AI 最终检查——grep 确认**零占位符残留**，有则回填 |

完成后你拿到：

```
你的项目/.claude/skills/my-project-dev/
├── SKILL.md                  ← 已填充（项目定位/铁律/命令速查/门禁）
├── hooks/hooks.json          ← Claude Code 钩子（SessionStart + PreToolUse）
├── commands/                 ← slash 命令（/spec, /precheck, /explore）
├── scripts/
│   ├── precheck.sh           ← 25 个门禁（已配置好）
│   ├── precheck.conf         ← 45 个变量（AI 自动填充）
│   ├── state-machine.sh      ← 阶段状态机
│   └── self-check.sh         ← 运行时自检
├── assets/
│   └── spec-template.md      ← spec 模板（22 段分级填写）
└── references/               ← 全部已填充（零占位符）
```

## 4. 日常使用

### 开始新需求

对 AI 说："开始新需求：给 cockpit 添加通知面板"

AI 自动：创建 spec 文件 → 判断规模 → 预填复用约束 → 验证。

或用 slash 命令：`/my-project-dev:spec <需求描述>`

或手动复制（CI 场景）：

```bash
cp .claude/skills/my-project-dev/assets/spec-template.md specs/$(date +%Y-%m-%d)-my-feature.md
```

按变更规模分级填写：

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

或用 slash 命令：

```
/my-project-dev:precheck --all
/my-project-dev:precheck --all-full
```

**结果解读**：`✓` 通过 / `✗` 必须修复 / `⚠` 人工评估

### 单独跑某个门禁

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse
bash .claude/skills/my-project-dev/scripts/precheck.sh --cognition
bash .claude/skills/my-project-dev/scripts/precheck.sh --domain
bash .claude/skills/my-project-dev/scripts/precheck.sh --knowledge
```

## 5. 25 个门禁

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
| `--layer` | DDD 分层边界（穿透/倒置/领域污染） | LAYER_DEFS / LAYER_ORDER |
| `--stable-diff` | 稳定单元篡改 | STABLE_GLOBS |
| `--link-depth` | 调用链深度 | MAX_LINK_DEPTH |
| `--adr` | 架构决策记录 | ADR_DIR / TECH_DEBT_FILE |
| `--contract` | 接口契约 + ACL | CONTRACT_DIR / ACL_DIR |
| `--consistency-cross` | BDAT 一致性 | GLOSSARY_FILE / SOR_FILE |
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

每个门禁优先用已安装的运行时工具，无则降级到内置 grep：

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | gitnexus trace → graphify → madge | 纯转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--layer` | gitnexus query | grep import + realpath |
| `--review` | ocr review / `claude ultrareview` | AI 按 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |
| `--frontend` 循环 | madge --circular | grep 互引检测 |

## 6. precheck.conf 配置说明

AI 生成目标技能时自动填充 45 个变量。如需手动调整，编辑 `scripts/precheck.conf`：

```bash
# 基础配置（必填）
PROJECT_DIR="/path/to/project"           # 项目根目录
WRITABLE_DIRS=("src" "lib")              # 允许改动的目录
READONLY_DIRS=("vendor" "third-party")   # 只读目录（改动=违规）
TEST_CMD="npm test"                      # 测试命令
BUILD_CMD="npm run build"                # 构建命令

# DDD 分层（可选，不填则跳过 --layer）
LAYER_DEFS=("presentation=src/controllers/**" "domain=src/domain/**")
LAYER_ORDER=("presentation" "domain" "infrastructure")
STABLE_GLOBS=("src/domain/**")           # 稳定层文件（改动须 spec 声明）

# 微服务（可选，不填则跳过 --service）
SERVICE_DIRS=("services/order" "services/payment")

# 前端（可选，不填则跳过 --state/--frontend）
STORE_DIR="src/store"
COMPONENT_DIR="src/components"
MAX_STORE_LINES=300                      # 超过=巨型 store warn
MAX_COMPONENT_DEPTH=7                    # 超过=嵌套过深 warn

# 架构产物（可选，不填则跳过对应门禁）
ADR_DIR="docs/adr"
GLOSSARY_FILE="docs/glossary.md"
```

> 留空的配置项对应门禁在 `--all-full` 中静默跳过（不报 warn）。

## 7. 升级已有技能

swarm-yuan 自身迭代后，对 AI 说：

```
升级 /path/to/project 的 my-project-dev skill
```

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

| 操作 | 说明 |
|------|------|
| ✅ 覆盖 | precheck.sh / precheck.conf / spec-template / 13 个 reference |
| ✅ 保留 | SKILL.md / codebase / dev-guide / release / reference-manual / workflow |
| ✅ 备份 | 旧文件 → `.upgrade-backup-<timestamp>/` |
| ✅ 版本戳 | `.swarm-yuan-version` |
| ⚠ 重置 | precheck.conf 被重置为占位符 — AI 自动重新填充 |

## 8. 常见问题

### Q: 门禁报误报怎么办？

对 AI 说"precheck 报了误报"。AI 自动分析原因 → 调整 precheck.conf 或修复检测逻辑 → 重跑确认。

也可直接编辑 `precheck.conf` 调整配置变量（如 WRITABLE_DIRS / SCAN_DIRS）。

### Q: `--reuse` 总是 fail？

`--reuse` 要求 spec 含 §5.5 复用约束段。每次变更前写 spec（即使简单变更也填 §5.5 的 4 个 checkbox）。

核心约束：**先声明复用了什么，再写代码。**

### Q: 不需要微服务 / 前端 / TOGAF 门禁？

AI 生成 skill 时自动识别项目类型——不适用门禁留空配置，`--all-full` 中静默跳过。

### Q: 项目结构变了？

对 AI 说"重新探查并更新 skill"。AI 重新探查 → 更新特征卡 → 更新 precheck.conf 和项目特定文件。

### Q: 如何只检查安全？

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
```

所有 25 个门禁都支持单独运行。

### Q: generate-skill.sh 报"目标技能已存在"？

```bash
# 升级
bash generate-skill.sh --upgrade my-project-dev /path/to/project
# 或删除重建
rm -rf .claude/skills/my-project-dev && bash generate-skill.sh my-project-dev /path/to/project
```

### Q: hooks 和 commands 是什么？

生成目标技能时自动创建：
- `hooks/hooks.json` — SessionStart 注入阶段状态 + PreToolUse(Write) 检查改动范围
- `commands/` — `/my-project-dev:spec`（创建 spec）/ `/my-project-dev:precheck`（运行门禁）/ `/my-project-dev:explore`（探查项目）

## 9. 日常使用流程

```
首次使用：
  bash install.sh --claude
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动（11 步，零占位符）

日常开发：
  对 AI 说 "开始新需求：xxx"
    → AI 创建 spec + 判断规模 + 预填复用约束
    → 编码（AI 查 reference-manual §4/5/6 复用清单，拼装优先）
      → 提交前：对 AI 说 "跑门禁"（或 bash precheck.sh --all）
        ├→ 全 ✓ → 可提交
        ├→ 有 ✗ → 修复后重跑
        └→ 有 ⚠ → 人工评估

架构审查日：
  对 AI 说 "跑全量门禁"（或 bash precheck.sh --all-full）

skill 过时：
  对 AI 说 "升级 my-project-dev skill"
    → AI 自动更新模板 + 重新探查 + 重新配置
```

## 10. 数字一览

| 维度 | 数值 |
|------|------|
| 质量门禁 | 25（核心 10 + 架构 15） |
| 运行时工具 | 10 |
| 特征卡 | 14 项 |
| spec 模板 | 22 段（分级填写） |
| reference 文档 | 13 个 |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 配置变量 | 45 个（AI 自动填充） |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ 生成完成时 grep 确认 |

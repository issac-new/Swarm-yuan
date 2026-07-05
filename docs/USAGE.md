# swarm-yuan 使用说明

> **一句话**：对 AI 说"为这个项目生成 skill"，AI 全自动探查代码库 → 生成项目专属开发技能（25 个质量门禁 + spec 模板 + 14 项特征卡），你直接用。

---

## 1. 它是什么

swarm-yuan 是一个 **skill 生成器**。给它任意代码仓库，它自动：

1. 读取项目既有知识（AGENTS.md / CLAUDE.md / 项目记忆 / hermes-agent 配置）
2. 三路并行探查代码库（结构 / 规范 / 代码组织），优先用代码图谱工具索引
3. 提取 14 项项目特征卡（项目类型 → 可改范围 → 技术栈 → 可复用稳定单元 → 领域知识）
4. 生成六段式技能骨架（SKILL.md + references + assets + scripts + hooks + commands）
5. AI 自动填充全部文件 + 自动配置 45 个门禁变量
6. 运行 25 个门禁验证，有误报自动修复后重跑
7. 将探查结果写回项目记忆，形成"记忆 → 生成 → 开发 → 记忆"闭环

**生成 skill 时零手动配置。** 日常使用时，你可以对 AI 说，也可以直接跑命令。

## 2. 安装

### 自动安装（推荐）

```bash
# 克隆仓库
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan

# 自动检测运行环境 + 安装
bash install.sh
```

install.sh 会自动检测已安装的 AI 工具（Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi），安装到对应的 skill 默认目录。

### 指定环境安装

```bash
bash install.sh --claude      # → ~/.claude/skills/swarm-yuan/
bash install.sh --cursor      # → ~/.cursor/skills/swarm-yuan/
bash install.sh --codex       # → ~/.codex/skills/swarm-yuan/
bash install.sh --windsurf    # → ~/.codeium/windsurf/skills/swarm-yuan/
bash install.sh --opencode    # → ~/.config/opencode/skills/swarm-yuan/
bash install.sh --gemini      # → ~/.gemini/skills/swarm-yuan/
bash install.sh --kimi        # → ~/.kimi/skills/swarm-yuan/
bash install.sh --all         # 安装到所有已检测到的环境
bash install.sh --list        # 仅列出检测到的环境
```

### 验证安装

```bash
# 检查 skill 是否被发现
ls ~/.claude/skills/swarm-yuan/SKILL.md    # Claude Code
ls ~/.claude/commands/swarm-yuan.md        # slash command

# 运行时自检（10 个工具）
bash ~/.claude/skills/swarm-yuan/scripts/self-check.sh
```

## 3. 生成项目技能

对 AI 说：

```
为 /path/to/my-project 生成 skill
```

或用 slash command：

```
/swarm-yuan /path/to/my-project
```

AI 全自动完成后，你拿到：

```
你的项目/.claude/skills/my-project-dev/
├── SKILL.md                  ← 技能入口（AI 读取，自动触发）
├── hooks/hooks.json          ← Claude Code 生命周期钩子
├── commands/                 ← slash 命令（/spec, /precheck, /explore）
├── scripts/
│   ├── precheck.sh           ← 25 个门禁（已配置好，直接运行）
│   ├── precheck.conf         ← 45 个配置变量（AI 自动填充）
│   ├── state-machine.sh      ← 阶段状态机
│   └── self-check.sh         ← 10 个运行时自检
├── assets/
│   ├── spec-template.md      ← spec 模板（18 段分级填写）
│   └── ...                   ← 分支/环境/库表/状态机模板
└── references/               ← 13 个参考文档（AI 填充项目内容）
```

> 目标技能安装到哪个目录由 generate-skill.sh 自动检测运行环境决定（与 install.sh 同逻辑）。

## 4. 日常使用

日常使用有两种方式：**对 AI 说**（推荐）或 **直接跑命令**（排查/CI 用）。

### 开始新需求

**方式 1：对 AI 说**（推荐）

```
开始新需求：给 cockpit 添加一个通知面板
```

AI 自动创建 spec 文件 + 判断规模 + 预填复用约束 + 验证。

**方式 2：用 slash 命令**

```
/my-project-dev:spec 给 cockpit 添加一个通知面板
```

**方式 3：手动复制模板**（CI/脚本场景）

```bash
cp .claude/skills/my-project-dev/assets/spec-template.md specs/$(date +%Y-%m-%d)-my-feature.md
```

按变更规模分级填写：

| 规模 | 填哪些段 | 典型场景 |
|------|---------|---------|
| **简单** | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 / 调样式 |
| **标准** | §1-§13 + §5.5/§5.6/§5.7 约束段 | 新功能 / 改接口 / 加组件 |
| **完整** | 全部 18 段（含 §14-§18 认知/辩证/领域） | 架构变更 / 跨服务 / 新上下文 |

### 提交前自检

**对 AI 说**："跑门禁" 或 "提交前检查"

**或直接运行**：

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 全部 25 门禁
```

**结果解读**：`✓` 通过 / `✗` fail 必须修复 / `⚠` warn 人工评估

### 单独跑某个门禁

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --security    # 安全
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse       # 复用合规
bash .claude/skills/my-project-dev/scripts/precheck.sh --cognition   # 认知体检
bash .claude/skills/my-project-dev/scripts/precheck.sh --domain      # 领域知识
bash .claude/skills/my-project-dev/scripts/precheck.sh --knowledge   # 项目知识复用
```

## 5. 25 个门禁速查

### 核心门禁（`--all` 默认跑这 10 个）

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

### 架构门禁（`--all-full` 才跑，未配置则静默跳过）

| 门禁 | 检查什么 |
|------|---------|
| `--layer` | DDD 分层边界 |
| `--stable-diff` | 稳定单元篡改 |
| `--link-depth` | 调用链深度 |
| `--adr` | 架构决策记录 |
| `--contract` | 接口契约 + ACL |
| `--consistency-cross` | BDAT 一致性 |
| `--impact` | 变更影响分析 |
| `--service` | 微服务架构 |
| `--api` | API 契约与幂等 |
| `--state` | 前端状态管理 |
| `--frontend` | 前端组件架构 |
| `--cognition` | 认知递进体检 |
| `--domain` | 领域知识违规检测 |
| `--knowledge` | 项目知识复用 |
| `--mermaid` | Mermaid 可视化 |

### 门禁工具优先级 + 降级策略

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | gitnexus trace → graphify explain → madge | 纯转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--layer` | gitnexus query | grep import |
| `--review` | ocr review / `claude ultrareview` | AI 按 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |
| `--frontend` 循环 | madge --circular | grep 互引 |

## 6. 升级已有技能

对 AI 说：

```
升级 /path/to/project 的 my-project-dev skill
```

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

- ✅ 覆盖通用模板 / 保留项目特定文件 / 自动备份 / 写版本戳
- ⚠ 升级后 `precheck.conf` 重置为占位符 — AI 自动重新填充

## 7. 常见问题

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"，AI 自动分析+调整+重跑。也可直接编辑 `precheck.conf`。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。先声明复用什么，再写代码。

**Q: 不需要微服务/前端/TOGAF 门禁？** → AI 自动识别项目类型，不适用门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。

**Q: generate-skill.sh 报"已存在"？** → 用 `--upgrade` 升级，或删除重建。

**Q: hooks 和 commands 是什么？** → 自动创建的 Claude Code 集成件：`hooks/hooks.json`（SessionStart + PreToolUse）+ `commands/`（/spec, /precheck, /explore）。

## 8. 日常使用流程

```
首次使用：
  bash install.sh --claude          # 安装 swarm-yuan
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动探查 + 生成 + 配置 + 验证

日常开发：
  对 AI 说 "开始新需求：xxx"
    → AI 自动创建 spec + 判断规模 + 引导填写 + 预填复用约束
    → 编码（AI 查 reference-manual §4/5/6 复用清单，拼装优先）
      → 提交前：对 AI 说 "跑门禁"（或 bash precheck.sh --all）
        ├→ 全 ✓ → 可提交
        ├→ 有 ✗ → 修复后重跑
        └→ 有 ⚠ → 人工评估

架构审查日：
  对 AI 说 "跑全量门禁"（或 bash precheck.sh --all-full）

skill 过时：
  对 AI 说 "升级 my-project-dev skill"
```

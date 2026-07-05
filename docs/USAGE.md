# swarm-yuan 使用说明

> 对 AI 说"为这个项目生成 skill"，AI 全自动探查 → 生成 → 配置 → 验证，你拿到一套零占位符的项目专属开发技能。

---

## 1. 它是什么

swarm-yuan 是一个 **skill 生成器**。给它任意代码仓库，AI 全自动完成 11 步流程：

1. 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / hermes-agent）
2. 三路并行探查代码库（结构 / 规范 / 代码组织）
3. 提取 14 项特征卡
4. 生成骨架（含 hooks / commands / precheck.conf）
5. AI 填充全部文件——**消除全部占位符**
6. AI 配置 45 个门禁变量
7. AI 生成 hooks / commands / MCP 集成
8. AI 运行 25 个门禁验证
9. AI 写回项目记忆（闭环）
10. AI 最终检查——**grep 确认零占位符残留，有则回填**
11. 生成完成，用户直接用

**零手动配置。零占位符残留。**

## 2. 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

install.sh 自动检测已安装的 AI 工具，安装到对应 skill 目录：

| 选项 | 安装到 |
|------|--------|
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

对 AI 说：

```
为 /path/to/my-project 生成 skill
```

或用 slash 命令：

```
/swarm-yuan /path/to/my-project
```

AI 完成后，你拿到：

```
你的项目/.claude/skills/my-project-dev/
├── SKILL.md                  ← 已填充（项目定位/铁律/命令速查/门禁）
├── hooks/hooks.json          ← Claude Code 钩子
├── commands/                 ← slash 命令（/spec, /precheck, /explore）
├── scripts/
│   ├── precheck.sh           ← 25 个门禁
│   ├── precheck.conf         ← 45 个变量（AI 自动填充）
│   ├── state-machine.sh      ← 阶段状态机
│   └── self-check.sh         ← 10 个运行时自检
├── assets/
│   └── spec-template.md      ← spec 模板（18 段分级填写）
└── references/               ← 全部已填充（零占位符）
```

## 4. 日常使用

### 开始新需求

对 AI 说："开始新需求：给 cockpit 添加一个通知面板"

AI 自动创建 spec + 判断规模 + 预填复用约束 + 验证。

或用 slash 命令：`/my-project-dev:spec <需求描述>`

或手动复制（CI 场景）：

```bash
cp .claude/skills/my-project-dev/assets/spec-template.md specs/$(date +%Y-%m-%d)-my-feature.md
```

| 规模 | 填哪些段 | 典型场景 |
|------|---------|---------|
| 简单 | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 |
| 标准 | §1-§13 + 约束段 | 新功能 / 改接口 |
| 完整 | 全部 18 段 | 架构变更 / 跨服务 |

### 提交前自检

对 AI 说："跑门禁"

或直接运行：

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 全部 25 门禁
```

**结果**：`✓` 通过 / `✗` 必须修复 / `⚠` 人工评估

### 单独跑门禁

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse
bash .claude/skills/my-project-dev/scripts/precheck.sh --cognition
bash .claude/skills/my-project-dev/scripts/precheck.sh --domain
```

## 5. 25 个门禁

### 核心门禁（`--all` 跑 10 个）

| 门禁 | 检查什么 |
|------|---------|
| `--branch` | 分支命名 + 保护分支 |
| `--scope` | 改动范围（可改 vs 只读） |
| `--build` | 构建通过 |
| `--sensitive` | 密码/密钥明文 |
| `--review` | 代码审查（ocr 5 维度） |
| `--reuse` | 复用合规（禁止重复造轮子） |
| `--deps` | 依赖版本锁定 |
| `--security` | OWASP Top 10 |
| `--test` | 测试通过 |
| `--consistency` | 业务规则 + 数据勾稽 |

### 架构门禁（`--all-full` 跑 15 个）

DDD 分层 / 稳定单元篡改 / 调用链深度 / 架构决策 / 接口契约 / 变更影响 / 微服务 / 前端状态 / 组件架构 / 认知体检 / 领域知识 / 项目知识复用 / Mermaid 可视化

### 降级策略

每个门禁优先用运行时工具，无则降级：

| 门禁 | 优先 | 降级 |
|------|------|------|
| `--link-depth` | gitnexus → graphify → madge | 转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--review` | ocr review / ultrareview | AI 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |

## 6. 升级

对 AI 说："升级 my-project-dev skill"

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板 / 保留项目特定文件 / 自动备份 / AI 重新填充 precheck.conf。

## 7. FAQ

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"，AI 自动分析+调整+重跑。也可直接编辑 `precheck.conf`。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。

**Q: 不需要微服务/前端/TOGAF？** → AI 自动识别项目类型，不适用门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。

**Q: hooks/commands 是什么？** → 自动创建：`hooks/hooks.json`（SessionStart + PreToolUse）+ `commands/`（/spec, /precheck, /explore）。

## 8. 流程

```
首次：
  bash install.sh --claude
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动（零占位符）

日常：
  对 AI 说 "开始新需求：xxx"
    → AI 创建 spec + 引导填写 + 预填复用
    → 编码（拼装优先）
    → 对 AI 说 "跑门禁"
      ├→ 全 ✓ → 提交
      ├→ 有 ✗ → 修复重跑
      └→ 有 ⚠ → 评估

架构审查：
  对 AI 说 "跑全量门禁"

升级：
  对 AI 说 "升级 skill"
```

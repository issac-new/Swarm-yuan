# swarm-yuan — AI 驱动的项目开发技能生成器

> 给我一个代码仓库，还你一套贴合该项目的全流程开发技能。
>
> 对 AI 说"为这个项目生成 skill"，5 分钟后你拿到：25 个质量门禁 + 18 段 spec 模板 + 14 项项目特征卡 + Claude Code 深度集成。零手动配置。

[![Release](https://img.shields.io/badge/release-v2026.07.04-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.07.04)
[![Gates](https://img.shields.io/badge/gates-25-green)]()
[![Runtimes](https://img.shields.io/badge/runtimes-10-orange)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 它是什么

swarm-yuan 是一个 **AI 驱动的 skill 生成器**。它不是帮你写代码的工具——它帮你的 AI **在正确的约束下写代码**。

你给它一个代码仓库路径，AI 全自动：

```
读取项目知识 → 探查代码库 → 提取14项特征卡 → 生成六段式技能 → 自动配置45个门禁变量 → 运行25个门禁验证 → 写回项目记忆
```

生成的技能包含：
- **SKILL.md** — 项目专属技能入口（AI 自动加载）
- **25 个质量门禁** — 从分支命名到安全规范到领域知识客观规律
- **18 段 spec 模板** — 按变更规模分级填写（简单/标准/完整）
- **hooks + slash 命令** — Claude Code 深度集成（SessionStart 注入状态 + PreToolUse 范围检查）
- **13 个参考文档** — 方法论 + 认知框架 + 32 领域知识速查

**你不需要手动编辑任何配置文件。** AI 探查项目后自动推导全部配置。

---

## 快速开始

### 安装

```bash
# 1. 下载 Release zip 或克隆仓库
git clone https://github.com/issac-new/Swarm-yuan.git
cp -r Swarm-yuan/swarm-yuan ~/.agents/skills/

# 2. 注册 slash command（Claude Code）
cp -r ~/.agents/skills/swarm-yuan/.claude/commands/ ~/.claude/commands/

# 3. 自检运行时（10 个工具，缺失的自动安装）
bash ~/.agents/skills/swarm-yuan/scripts/self-check.sh
```

### 生成项目技能

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
你的项目/.agents/skills/my-project-dev/
├── SKILL.md                  ← 技能入口
├── hooks/hooks.json          ← Claude Code 生命周期钩子
├── commands/                 ← slash 命令（/spec, /precheck, /explore）
├── scripts/
│   ├── precheck.sh           ← 25 个门禁（已配置好，直接运行）
│   ├── precheck.conf         ← 45 个配置变量（AI 自动填充）
│   └── state-machine.sh      ← 阶段状态机
├── assets/
│   └── spec-template.md      ← spec 模板（18 段分级填写）
└── references/               ← 13 个参考文档
```

### 日常使用

```bash
# 提交前自检：核心 10 门禁（~5 秒）
bash .agents/skills/my-project-dev/scripts/precheck.sh --all

# 架构审查：全部 25 门禁（~30 秒）
bash .agents/skills/my-project-dev/scripts/precheck.sh --all-full
```

---

## 25 个质量门禁

### 核心门禁（`--all` 默认跑这 10 个）

| 门禁 | 检查什么 |
|------|---------|
| `--branch` | 分支命名 + 保护分支 |
| `--scope` | 改动范围（可改 vs 只读） |
| `--build` | 构建通过 |
| `--sensitive` | 密码/密钥明文扫描 |
| `--review` | 代码审查（调用 ocr，5 维度） |
| `--reuse` | 复用合规（禁止重复造轮子） |
| `--deps` | 依赖版本锁定 |
| `--security` | OWASP Top 10 |
| `--test` | 测试通过 |
| `--consistency` | 业务规则 + 数据勾稽 |

### 架构门禁（`--all-full` 才跑，未配置则静默跳过）

| 门禁 | 检查什么 |
|------|---------|
| `--layer` | DDD 分层边界 |
| `--stable-diff` | 稳定单元篡改 |
| `--link-depth` | 调用链深度 |
| `--adr` | 架构决策记录 |
| `--contract` | 接口契约 + ACL |
| `--impact` | 变更影响分析 |
| `--service` | 微服务架构 |
| `--cognition` | 认知递进体检 |
| `--domain` | 领域知识违规检测 |
| `--knowledge` | 项目知识复用 |
| `--mermaid` | Mermaid 可视化 |
| …… | 共 15 个架构门禁 |

每个门禁优先用已安装的运行时工具（gitnexus/graphify/ocr/claude-mem），无则降级到内置 grep。

---

## 五层认知基底

swarm-yuan 不只是门禁堆砌——它背后是一套认知方法论：

| 层 | 解决什么 |
|----|---------|
| 第一层 **认知递进** | 如何认识项目（概念→结构→空间→映射→规律→处理） |
| 第二层 **思维语言** | 如何思考（三元演化 + 四导向 + 七推理） |
| 第三层 **认知辩证** | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） |
| 第四层 **偏差防范** | 如何纠偏（五维偏差 + 思维模型 8 类） |
| 第五层 **辩证认知** | 如何统一前四层（7 对辩证范畴） |

> 核心理念：**呈现递进的关系，而非仅关注计算。**

---

## 10 个运行时工具

| 工具 | 能力 | 版本 |
|------|------|------|
| OpenSpec | spec-driven 开发 | v1.5.0 |
| superpowers | subagent-driven 编排 | v6.1.1 |
| comet | 脚本背书状态机 | v0.3.9 |
| GitNexus | 代码知识图谱（17 MCP 工具） | v1.6.9 |
| graphify | 广谱知识图（36 语法） | v0.9.6 |
| gsd-core | phase-loop + goal-backward | v1.6.1 |
| claude-mem | 跨会话记忆持久化 | v13.10.1 |
| open-code-review | 确定性代码审查 | v1.3.13 |
| gstack | 8 审查维度 | v1.58.5 |
| Ruflo | agent swarm + federation | v3.21.1 |

只引用调用，不重新实现、不复制源码。

---

## Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| Hooks | SessionStart 注入状态 + PreToolUse(Write) 范围检查 |
| Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| MCP | 自动注册 gitnexus / claude-mem / graphify |
| Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| LSP | go-to-definition / find-references |
| Subagent | 每任务新 subagent + 两阶段审查 |
| ultrareview | 云端多 agent 审查（可选） |

联网/云端功能不可用时自动降级为本地工具。

---

## 仓库结构

```
Swarm-yuan/
├── README.md                     ← 本文件
├── USAGE.md                      ← 面向研发人员的详细使用说明
├── LICENSE
├── swarm-yuan/                   ← 生成器 skill（安装到 ~/.agents/skills/）
│   ├── SKILL.md                  ← 技能入口（108 行，渐进式披露）
│   ├── .claude/commands/
│   │   └── swarm-yuan.md         ← /swarm-yuan slash command 定义
│   ├── assets/
│   │   ├── precheck.sh           ← 25 个门禁（2255 行）
│   │   ├── precheck.conf         ← 45 个配置变量模板
│   │   ├── spec-template.md      ← spec 模板（18 段分级）
│   │   └── ...                   ← 分支/环境/库表/状态机模板
│   ├── references/               ← 13 个参考文档
│   │   ├── claude-code-capabilities.md  ← Claude Code 全量能力
│   │   ├── exploration-guide.md         ← 14 项特征卡 + 工具矩阵
│   │   ├── domain-knowledge.md          ← 32 领域知识速查
│   │   ├── cognition-framework.md       ← 五层认知基底
│   │   └── ...                          ← 方法论 + 安全 + 审查
│   └── scripts/
│       ├── generate-skill.sh     ← 创建/升级目标技能
│       └── self-check.sh         ← 10 运行时自检
└── Swarm-studio/                 ← 项目示例（SwarmStudio overlay 项目生成物）
    ├── SKILL.md
    ├── hooks/hooks.json
    ├── commands/                 ← /spec, /precheck, /explore
    ├── assets/
    ├── references/
    └── scripts/
```

---

## 数字一览

| 维度 | 数值 |
|------|------|
| 质量门禁 | 25 个（核心 10 + 架构 15） |
| 运行时工具 | 10 个 |
| 项目特征卡 | 14 项 |
| spec 模板 | 22 段（分级填写） |
| reference 文档 | 13 个 |
| 领域知识速查 | 32 个领域 |
| 认知基底 | 5 层 |
| 三平台兼容 | macOS / Linux / Windows |
| 自举能力 | ✅ 用自身门禁检查自身 |

---

## 升级已有技能

```bash
bash ~/.agents/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板，保留项目特定文件，自动备份 + 写版本戳。

---

## License

MIT

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

swarm-yuan 是一个 **AI 驱动的 skill 生成器**。它不帮你写代码——它帮你的 AI **在正确的约束下写代码**。

给它任意代码仓库，AI 全自动：

1. 读取项目既有知识（AGENTS.md / CLAUDE.md / 项目记忆 / hermes-agent 配置）
2. 三路并行探查代码库（结构 / 规范 / 代码组织），优先用代码图谱工具索引
3. 提取 14 项项目特征卡（项目类型 → 可改范围 → 技术栈 → 可复用稳定单元 → 领域知识）
4. 生成六段式技能骨架（SKILL.md + references + assets + scripts + hooks + commands）
5. AI 自动填充全部文件 + 自动配置 45 个门禁变量
6. 运行 25 个门禁验证，有误报自动修复后重跑
7. 将探查结果写回项目记忆，形成"记忆 → 生成 → 开发 → 记忆"闭环

**你不需要手动编辑任何配置文件。**

---

## 快速上手

### 安装

```bash
# 1. 克隆仓库
git clone https://github.com/issac-new/Swarm-yuan.git
cp -r Swarm-yuan/swarm-yuan ~/.agents/skills/

# 2. 注册 /swarm-yuan slash command（Claude Code）
cp -r ~/.agents/skills/swarm-yuan/.claude/commands/ ~/.claude/commands/
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
├── SKILL.md                  ← 技能入口（AI 读取，自动触发）
├── hooks/hooks.json          ← Claude Code 生命周期钩子（SessionStart + PreToolUse）
├── commands/                 ← slash 命令（/spec, /precheck, /explore）
├── scripts/
│   ├── precheck.sh           ← 25 个门禁（已配置好，直接运行）
│   ├── precheck.conf         ← 45 个配置变量（AI 自动填充）
│   ├── state-machine.sh      ← 阶段状态机
│   └── self-check.sh         ← 10 个运行时自检
├── assets/
│   ├── spec-template.md      ← spec 模板（写需求时复制使用，18 段分级填写）
│   └── ...                   ← 分支/环境/库表/状态机模板
└── references/               ← 13 个参考文档（AI 填充项目内容）
```

---

## 日常使用

### 开始新需求

对 AI 说：

```
开始新需求：给 cockpit 添加一个通知面板
```

AI 自动完成：
1. 创建 spec 文件到 `specs/YYYY-MM-DD-<feature>.md`
2. 根据需求判断变更规模，只引导你填需要的段
3. 从 reference-manual §4/5/6 检索可复用稳定单元，预填 §5.5 复用约束
4. 填完后自动运行 `precheck.sh --reuse` 验证

| 规模 | AI 引导填哪些段 | 典型场景 |
|------|----------------|---------|
| **简单** | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 / 调样式 |
| **标准** | §1-§13 + §5.5/§5.6/§5.7 约束段 | 新功能 / 改接口 / 加组件 |
| **完整** | 全部 18 段（含 §14-§18 认知/辩证/领域） | 架构变更 / 跨服务 / 新上下文 |

> 复杂变更（>3 文件 / 跨模块）：AI 在 spec §4 标注"建议用 Dynamic Workflow 并行执行"。

### 提交前自检

```bash
# 日常开发：核心 10 门禁（~5 秒）
bash .agents/skills/my-project-dev/scripts/precheck.sh --all

# 架构审查：全部 25 门禁（~30 秒）
bash .agents/skills/my-project-dev/scripts/precheck.sh --all-full
```

**结果解读**：`✓` 通过 / `✗` fail 必须修复 / `⚠` warn 人工评估

### 单独跑某个门禁

```bash
bash .agents/skills/my-project-dev/scripts/precheck.sh --security    # 安全
bash .agents/skills/my-project-dev/scripts/precheck.sh --reuse       # 复用合规
bash .agents/skills/my-project-dev/scripts/precheck.sh --cognition   # 认知体检
bash .agents/skills/my-project-dev/scripts/precheck.sh --domain      # 领域知识
bash .agents/skills/my-project-dev/scripts/precheck.sh --knowledge   # 项目知识复用
```

### 用 slash 命令

```
/my-project-dev:spec my-feature      # 创建 spec
/my-project-dev:precheck --all       # 运行门禁
/my-project-dev:explore              # 探查项目
```

---

## 25 个门禁速查

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

| 门禁 | 检查什么 | 需要配置 |
|------|---------|---------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | LAYER_DEFS / LAYER_ORDER |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | STABLE_GLOBS |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | MAX_LINK_DEPTH |
| `--adr` | 架构决策记录（ADR + 技术债登记） | ADR_DIR / TECH_DEBT_FILE |
| `--contract` | 接口契约（version 字段 + ACL 防腐层） | CONTRACT_DIR / ACL_DIR |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | GLOSSARY_FILE / SOR_FILE |
| `--impact` | 变更影响分析（spec 须含影响范围段 + 消费方反查） | — |
| `--service` | 微服务架构（共享 DB / 同步链 / 网关 / trace） | SERVICE_DIRS |
| `--api` | API 契约与幂等（version / 幂等键 / 分布式事务） | API_SPEC_DIR |
| `--state` | 前端状态管理（巨型 store / prop drilling / 派生 useState） | STORE_DIR |
| `--frontend` | 前端组件架构（层级 / props / 循环依赖 / CSS 污染） | COMPONENT_DIR |
| `--cognition` | 认知递进体检（六阶认知链 + 六维动力学 + 五层总分） | — |
| `--domain` | 领域知识（技术+业务领域识别 + 客观规律违规检测） | — |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 是否引用） | — |
| `--mermaid` | Mermaid 可视化（架构图/流程图/调用链是否用 Mermaid） | — |

### 门禁工具优先级 + 降级策略

每个门禁优先用已安装的运行时工具，无则降级到内置 grep：

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | gitnexus trace → graphify explain → madge | 纯转发函数统计 |
| `--impact` | gitnexus detect_changes / impact | git diff + grep 反查 |
| `--layer` | gitnexus query（跨层依赖） | grep import + realpath |
| `--review` | ocr review --from --to / ocr scan / `claude ultrareview` | 手动 5 维度清单 |
| `--knowledge` | claude-mem search | 文件检测（AGENTS.md/CLAUDE.md） |
| `--frontend` 循环 | madge --circular | grep 互引检测 |

---

## 升级已有技能

```bash
bash ~/.agents/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

- ✅ 覆盖通用模板（precheck.sh / precheck.conf / spec-template / 13 个 reference）
- ✅ 保留项目特定文件（SKILL.md / codebase / dev-guide / release / reference-manual / workflow）
- ✅ 自动备份旧文件到 `.upgrade-backup-<timestamp>/`
- ✅ 写入版本戳 `.swarm-yuan-version`
- ⚠ 升级后 `precheck.conf` 被重置为占位符 — AI 会重新探查并填充

---

## 五层认知基底

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

## 常见问题

**Q: 门禁报误报怎么办？** → 对 AI 说"precheck 报了误报"，AI 自动分析+调整+重跑。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 复用约束的 4 个 checkbox。先声明复用了什么，再写代码。

**Q: 不需要微服务/前端/TOGAF 门禁？** → AI 自动识别项目类型，不适用门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。

**Q: generate-skill.sh 报"已存在"？** → 用 `--upgrade` 升级，或删除重建。

---

## 日常使用流程

```
首次使用：
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动探查 + 生成 + 配置 + 验证
    → 你获得可直接用的 skill（零手动配置）

日常开发：
  对 AI 说 "开始新需求：xxx"\n    → AI 自动创建 spec + 判断规模 + 引导填写 + 预填复用约束
    → 编码（查 reference-manual §4/5/6 复用清单，拼装优先）
      → 提交前：bash precheck.sh --all
        ├→ 全 ✓ → 可提交
        ├→ 有 ✗ → 修复后重跑
        └→ 有 ⚠ → 人工评估

架构审查日：
  bash precheck.sh --all-full（全部 25 门禁）

skill 过时：
  对 AI 说 "升级 my-project-dev skill"
    → AI 自动更新模板 + 重新探查 + 重新配置
```

---

## 仓库结构

```
Swarm-yuan/
├── README.md                     ← 本文件
├── USAGE.md                      ← 详细使用说明
├── LICENSE
├── swarm-yuan/                   ← 生成器 skill
│   ├── SKILL.md                  ← 技能入口（108 行，渐进式披露）
│   ├── .claude/commands/         ← /swarm-yuan slash command
│   ├── assets/                   ← 模板 + 门禁 + 状态机
│   ├── references/               ← 13 个参考文档
│   └── scripts/                  ← 生成器 + 自检
└── Swarm-studio/                 ← 项目示例（SwarmStudio overlay 生成物）
    ├── SKILL.md
    ├── hooks/ + commands/
    ├── assets/ + references/ + scripts/
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

## License

MIT

# swarm-yuan 使用说明

> **一句话**：对 AI 说"为这个项目生成 skill"，AI 全自动探查代码库 → 生成项目专属开发技能（含 25 个质量门禁 + spec 模板 + 14 项特征卡），你直接用。零手动配置。

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

**你不需要手动编辑任何配置文件。**

## 2. 快速上手

### 安装

```bash
# 注册 /swarm-yuan slash command（Claude Code）
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
│   ├── spec.md
│   ├── precheck.md
│   └── explore.md
├── scripts/
│   ├── precheck.sh           ← 25 个门禁（已配置好，直接运行）
│   ├── precheck.conf         ← 45 个配置变量（AI 自动填充）
│   ├── state-machine.sh      ← 阶段状态机
│   └── self-check.sh         ← 10 个运行时自检
├── assets/
│   ├── spec-template.md      ← spec 模板（写需求时复制使用，18 段分级填写）
│   ├── plan-template.md      ← 实施计划模板
│   └── ...                   ← 分支/环境/库表/状态机模板
└── references/               ← 13 个参考文档（AI 填充项目内容）
    ├── codebase.md           ← 代码库概况
    ├── dev-guide.md          ← 开发指南 + 拼装式开发原则
    ├── reference-manual.md   ← 参考手册（安全/组件/接口/数据/认知/领域知识）
    ├── workflow.md           ← 八节点开发流程
    └── ...                   ← 方法论 + 认知框架 + 领域知识速查
```

## 3. 日常使用

### 开始新需求

对 AI 说：

```
开始新需求：给 cockpit 添加一个通知面板
```

AI 自动完成：
1. 复制 spec-template.md 到 `specs/YYYY-MM-DD-<feature>.md`
2. 根据需求描述判断变更规模（简单/标准/完整），只引导你填需要的段
3. 从 reference-manual §4/5/6 检索可复用稳定单元，预填 §5.5 复用约束
4. 填完后自动运行 `precheck.sh --reuse` 验证 §5.5 合规

或用 slash 命令：

```
/my-project-dev:spec 给 cockpit 添加一个通知面板
```

| 规模 | AI 引导填哪些段 | 典型场景 |
|------|----------------|---------|
| **简单** | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 / 调样式 |
| **标准** | §1-§13 + §5.5/§5.6/§5.7 约束段 | 新功能 / 改接口 / 加组件 |
| **完整** | 全部 18 段（含 §14-§18 认知/辩证/领域） | 架构变更 / 跨服务 / 新上下文 |

> 复杂变更（>3 文件 / 跨模块）：AI 在 spec §4 标注"建议用 Dynamic Workflow 并行执行"。

### 提交前自检

对 AI 说"跑门禁"或"提交前检查"，AI 自动运行核心门禁。也可用 slash 命令：

```
/my-project-dev:precheck --all         # 日常：核心 10 门禁（~5 秒）
/my-project-dev:precheck --all-full    # 架构审查：全部 25 门禁（~30 秒）
```

**结果解读**：
- `✓` 通过
- `✗` fail — 必须修复才能提交
- `⚠` warn — 人工评估是否可忽略

### 单独跑某个门禁

对 AI 说"跑安全门禁"或"跑复用检查"，AI 自动执行对应门禁。也可直接用 slash 命令：

```
/my-project-dev:precheck --security    # 安全
/my-project-dev:precheck --reuse       # 复用合规
/my-project-dev:precheck --cognition   # 认知体检
/my-project-dev:precheck --domain      # 领域知识
/my-project-dev:precheck --knowledge   # 项目知识复用
```

### 用 slash 命令

```
/my-project-dev:spec my-feature      # 创建 spec
/my-project-dev:precheck --all       # 运行门禁
/my-project-dev:explore              # 探查项目
```

## 4. 25 个门禁速查

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
| `--review` | ocr review --from --to / ocr scan / `claude ultrareview` | AI 按 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测（AGENTS.md/CLAUDE.md） |
| `--frontend` 循环 | madge --circular | grep 互引检测 |

## 5. 升级已有技能

swarm-yuan 自身迭代后（新增门禁 / 修复误报 / 更新模板），对 AI 说：

```
升级 /path/to/project 的 my-project-dev skill
```

AI 自动完成：运行 `generate-skill.sh --upgrade` → 重新探查项目 → 自动填充 precheck.conf → 检查 SKILL.md/reference-manual 是否需补认知框架段 → 运行门禁验证。

**`--upgrade` 做什么**：
- ✅ 覆盖通用模板（precheck.sh / precheck.conf / spec-template / 13 个 reference）
- ✅ 保留项目特定文件（SKILL.md / codebase / dev-guide / release / reference-manual / workflow）
- ✅ 自动备份旧文件到 `.upgrade-backup-<timestamp>/`
- ✅ 写入版本戳 `.swarm-yuan-version`
- ⚠ 升级后 `precheck.conf` 被重置为占位符 — AI 会重新探查并填充

## 6. 常见问题

### Q: 门禁报误报怎么办？

对 AI 说"precheck 报了误报，帮我看看"。AI 会：
1. 分析误报原因（配置不准 / grep 模式过宽 / 项目特殊结构）
2. 自动调整 `precheck.conf` 或修复 `precheck.sh` 检测逻辑
3. 重跑门禁确认修复

你不需要手动编辑 precheck.conf 或理解 grep 模式。

### Q: `--reuse` 总是 fail？

`--reuse` 要求 spec 含 §5.5 复用约束段。每次变更前写 spec（即使简单变更也填 §5.5 的 4 个 checkbox）。这是拼装式开发的核心约束——**先声明复用了什么，再写代码**。

### Q: 不需要微服务 / 前端 / TOGAF 门禁？

AI 生成 skill 时自动识别项目类型——单体项目留空 SERVICE_DIRS，无前端项目留空 COMPONENT_DIR。留空的门禁在 `--all-full` 中静默跳过。你不用管。

### Q: 项目结构变了怎么办？

对 AI 说"重新探查 /path/to/project 并更新 skill"。AI 会重新跑探查 → 更新特征卡 → 更新 precheck.conf 和项目特定文件。

### Q: 如何只检查安全？

对 AI 说"跑安全检查"，或用 `/my-project-dev:precheck --security`。所有 25 个门禁都支持单独运行。

### Q: generate-skill.sh 报"目标技能已存在"？

对 AI 说"升级 my-project-dev skill"（AI 自动执行 --upgrade），或"删除重建 my-project-dev skill"（AI 自动删除+重新生成）。

### Q: hooks 和 commands 是什么？

生成目标技能时自动创建：
- `hooks/hooks.json` — Claude Code 生命周期钩子（SessionStart 注入状态 + PreToolUse(Write) 范围检查）
- `commands/` — slash 命令入口（`/my-project-dev:spec` 创建 spec / `/my-project-dev:precheck` 运行门禁 / `/my-project-dev:explore` 探查项目）

## 7. 日常使用流程

```
首次使用：
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 全自动探查 + 生成 + 配置 + 验证
    → 你获得可直接用的 skill（零手动配置）

日常开发：
  对 AI 说 "开始新需求：xxx"
    → AI 自动创建 spec 文件 + 判断规模 + 引导填写 + 预填复用约束
    → 编码（AI 查 reference-manual §4/5/6 复用清单，拼装优先）
      → 提交前：对 AI 说 "跑门禁"
        ├→ 全 ✓ → 可提交
        ├→ 有 ✗ → 修复后重跑
        └→ 有 ⚠ → 人工评估

架构审查日：
  对 AI 说 "跑全量门禁" → AI 执行 --all-full（全部 25 门禁）

skill 过时：
  对 AI 说 "升级 my-project-dev skill"
    → AI 自动更新模板 + 重新探查 + 重新配置
```

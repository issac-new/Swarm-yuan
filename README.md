# swarm-yuan 使用说明（面向研发人员）

## 一、它是什么

swarm-yuan 是一个**元技能（生成器）**。它不直接帮你写代码，而是**为任意代码仓库自动生成一个项目专属的开发技能**。生成的技能会贴合该项目的目录结构、技术栈、构建命令、分支策略、安全规则，供研发人员在日常开发中从需求到交付全流程使用。

```
swarm-yuan（生成器，装在 ~/.agents/skills/）
    │
    │  探查目标仓库 → 填充六段式模板
    ▼
项目专属技能（如 Swarm-studio，装在 <project>/.agents/skills/）
    │
    │  研发人员日常开发时使用
    ▼
需求理解 → 设计spec → 实施plan → 分支 → 编码 → 测试 → 合入 → 发布
```

**一句话定位：** 给我一个代码仓库，我还你一套贴合该项目的全流程开发技能。

---

## 二、安装位置与文件结构

```
~/.agents/skills/swarm-yuan/
├── SKILL.md                        # 主文档（触发条件 + 5步流程 + 7方法论）
├── references/                     # 7 份方法论参考（按需读，不一次性加载）
│   ├── template-spec.md            #   六段式填充规范（核心，273行）
│   ├── exploration-guide.md        #   仓库探查指南 + 12项特征卡模板
│   ├── subagent-orchestration.md   #   superpowers subagent 编排模式
│   ├── review-methodology.md       #   gstack/OCR 5维度审查方法论
│   ├── gsd-patterns.md             #   gsd-core phase-loop + goal-backward + 安装
│   ├── memory-persistence.md       #   claude-mem 跨会话记忆持久化
│   └── code-graph-tools.md         #   GitNexus/graphify 命令引用
├── assets/                         # 通用模板（拷贝进目标技能后按项目定制）
│   ├── spec-template.md            #   OpenSpec proposal 格式模板
│   ├── plan-template.md            #   OpenSpec tasks checkbox 格式模板
│   ├── branch-setup.sh             #   分支准备脚本模板
│   ├── env-setup.sh                #   环境检测脚本模板
│   ├── data-sample-template.md     #   库表样例模板
│   ├── state-machine.sh            #   comet 阶段状态机模板
│   ├── precheck.sh                 #   质量门禁检查模板
│   ├── snippets.md                 #   代码片段模板
│   └── mcp-tools.md                #   MCP 工具模板
└── scripts/
    ├── generate-skill.sh           # 脚手架生成器（创建目标技能骨架）
    └── self-check.sh               # 9 项目运行时自检 + 自动安装
```

---

## 三、第一次使用前：自检（必须先做）

swarm-yuan 整合了 9 个外部项目的运行时。**第一次使用前**（或换机器后）必须跑自检：

```bash
bash ~/.agents/skills/swarm-yuan/scripts/self-check.sh
```

### 自检做什么

1. 逐个检测 9 个项目运行时是否已安装
2. 缺失的**自动安装**（7 个可自动）
3. 无法自动安装的（2 个）**打印命令提示**
4. 安装后复查，确认就绪

### 9 个项目运行时

| # | 项目 | 检测方式 | 安装命令 | 自动安装 |
|---|------|---------|---------|---------|
| 1 | OpenSpec | `openspec --version` | `npm i -g @fission-ai/openspec` | ✅ |
| 2 | comet | `comet --version` | `npm i -g @rpamis/comet` | ✅ |
| 3 | GitNexus | `gitnexus --version` | `npm i -g gitnexus` | ✅ |
| 4 | gsd-core | `gsd-tools` | `npx @opengsd/gsd-core --claude --global` | ✅ |
| 5 | claude-mem | `claude-mem` / `~/.claude-mem` | `npx claude-mem install` | ✅ |
| 6 | open-code-review | `ocr --version` | `npm i -g @alibaba-group/open-code-review` | ✅ |
| 7 | graphify | `graphify --help` | `uv tool install graphifyy` | ✅ |
| 8 | superpowers | `~/.claude/plugins/superpowers` | `/plugin install superpowers@claude-plugins-official` | ❌ 手动 |
| 9 | gstack | `~/.claude/skills/gstack` | `git clone … ~/.claude/skills/gstack && ./setup` | ❌ 手动 |

### self-check.sh 子命令

| 命令 | 用途 |
|------|------|
| `self-check.sh` | 检测 + 自动安装缺失的 |
| `self-check.sh --check-only` | 仅检测，不安装 |
| `self-check.sh --install gitnexus` | 仅安装指定项目 |

> **graphify 特殊：** 需先有 `uv`（`curl -LsSf https://astral.sh/uv/install.sh | sh`）或 `pipx`。self-check 优先用 uv，降级 pipx，两者都无则提示先装 uv。
>
> **superpowers / gstack：** 因 `/plugin` 是 Claude Code 运行时命令、gstack 需 clone+setup，bash 无法自动完成。按提示手动安装后重跑 `self-check.sh` 确认。

---

## 四、核心使用：5 步生成流程

```
⓪自检（9 项目运行时） → ①探查目标仓库 → ②提取项目特征 → ③填充六段模板 → ④落盘目标技能 → ⑤验证
```

### Step 0：自检（见上文第三节）

### Step 1：探查目标仓库

**1a. 代码图谱构建（优先）：**

探查前，先用代码图谱工具索引目标仓库，让后续探查基于图谱而非 grep：

```bash
# GitNexus（深度代码调用图）
cd <目标仓库根目录>
gitnexus analyze          # 构建知识图谱
gitnexus mcp              # 启动 MCP server 供 agent 查询

# graphify（广谱知识图：代码+文档+依赖链）
graphify .                # 构建 → graphify-out/GRAPH_REPORT.md
graphify path "组件A" "组件B"  # 查依赖链/最短路径
```

> 若工具不可用，降级为 grep + 读文件（传统探查）。

**1b. 三路并行探查（AI agent 子代理）：**

| 路 | 探查内容 |
|----|---------|
| A 结构与构建 | 顶层目录、package.json/pyproject.toml、scripts、端口、构建系统、测试体系 |
| B 开发规范 | AGENTS.md/CLAUDE.md/CONTRIBUTING、分支策略、文档约定、改造分类 |
| C 代码与资源 | 组件库（从图谱读依赖链）、接口、数据模型、安全机制、环境依赖、外部资源、MCP 工具 |

### Step 2：提取项目特征卡

整理成 12 项特征卡（模板见 `references/exploration-guide.md` 末尾）：

| # | 特征项 | 说明 |
|---|--------|------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务/库 |
| 2 | 可改范围 | 哪些目录可改、哪些只读、只读区修改机制 |
| 3 | 改造分类 | A类/B类、core/plugin、src/lib |
| 4 | 技术栈摘要 | 语言+框架+构建+测试 |
| 5 | 构建发布命令 | dev/build/test/release + 端口 |
| 6 | 分支规范 | 命名、合入策略、保护分支、推送规则 |
| 7 | 安全规则 | 脱敏、密钥、网络白名单 |
| 8 | 文档约定 | spec/plan 存放位置、命名格式 |
| 9 | 测试体系 | 框架、目录、运行命令 |
| 10 | 环境与外部资源 | 运行时版本、外部服务、MCP 工具 |
| 11 | 组件库与接口 | 主要组件、API 入口、OpenAPI 生成方式 |
| 12 | 数据规范 | schema 位置、样例数据、业务规则、勾稽关系 |

### Step 3：填充六段式模板

用 `assets/` 模板逐段填充。**6 条填充原则：**

1. **具体优于通用** — 用真实路径/命令/版本，不用占位符
2. **引用规则而非写死** — 来自 AGENTS.md 的规则写"见 AGENTS.md"，不重复具体值
3. **specs as source of truth** — 节点②③用 OpenSpec proposal→spec(delta)→design→tasks
4. **subagent 隔离** — 节点⑤用 superpowers orchestrator+subagent
5. **状态机背书** — 节点间状态用 `state-machine.sh` 验证，非 prompt-only
6. **审查维度覆盖** — check 段含 5 审查维度 + goal-backward + AUTO-FIX/ASK

### Step 4：落盘目标技能

```bash
bash ~/.agents/skills/swarm-yuan/scripts/generate-skill.sh <skill-name> <project-dir>
```

生成 23 文件骨架到 `<project>/.agents/skills/<skill-name>/`，然后填充占位文件。

**生成的目标技能结构：**

```
<project>/.agents/skills/<skill-name>/
├── SKILL.md                      # meta：铁律、改造分类、流程总览、命令速查
├── references/
│   ├── workflow.md               # 8 节点 × 9 要素（需填充）
│   ├── codebase.md               # 目录结构+技术栈（需填充）
│   ├── dev-guide.md              # 改造分类+开发指南+组件填充（需填充）
│   ├── release.md                # 编译规则+构建发布（需填充）
│   ├── reference-manual.md       # 安全/组件/接口/数据/测试/审查（需填充）
│   ├── subagent-orchestration.md # (已就绪) superpowers 编排
│   ├── review-methodology.md     # (已就绪) gstack/OCR 审查
│   ├── gsd-patterns.md           # (已就绪) gsd-core 模式
│   ├── memory-persistence.md     # (已就绪) claude-mem 记忆
│   └── code-graph-tools.md       # (已就绪) GitNexus/graphify
├── assets/
│   ├── spec-template.md          # OpenSpec proposal 模板（按项目定制）
│   ├── plan-template.md          # tasks checkbox 模板（按项目定制）
│   ├── branch-setup.sh           # 分支准备（按项目定制）
│   ├── env-setup.sh              # 环境检测（按项目定制）
│   ├── data-sample-template.md   # 库表样例（按项目定制）
│   └── state-machine.sh          # 阶段状态机（按项目定制）
└── scripts/
    ├── precheck.sh               # 质量门禁（按项目定制，7 子命令）
    ├── state-machine.sh          # 状态机（按项目定制）
    ├── self-check.sh             # 9 项目自检（已就绪）
    ├── snippets.md               # 代码片段（按项目定制）
    ├── code-graph-tools.md       # 图谱工具引用（已就绪）
    └── mcp-tools.md              # MCP 工具（按项目定制）
```

> **5 个 reference 文件已就绪**（方法论通用，无需改）：subagent-orchestration.md、review-methodology.md、gsd-patterns.md、memory-persistence.md、code-graph-tools.md。
> **5 个 reference 文件需填充**（项目特定）：workflow.md、codebase.md、dev-guide.md、release.md、reference-manual.md。
> **6 个 assets/scripts 需定制**（替换通用变量为项目实际值）。

### Step 5：验证

用 `references/template-spec.md` 末尾的核对表逐项检查：

**材料要素覆盖：**
- [ ] workflow 9 要素（每节点：流程入口/参与方/准入/门禁/分支处理/产出物归档/流程控制/状态控制 + 完成检查表）
- [ ] reference 8 项（目录结构/安全检查/编译规则/组件库/依赖链路/接口清单/UI-UX/数据字典）
- [ ] assets 7 项（环境加载/资源检测/分支拉取/任务配置/静态资源/库表样例/组件填充）
- [ ] check 4 项（单测接口集成回归安全/业务规则案例/数据勾稽无多漏错重/UI脱敏日志）
- [ ] scripts 3 项（执行脚本/代码片段+组件参数/MCP工具）

**方法论整合（7 项）：**
- [ ] Spec-driven（OpenSpec）：proposal→spec(delta)→archive
- [ ] Subagent-driven（superpowers）：orchestrator+fresh subagent+两阶段审查
- [ ] State machine（comet）：state-machine.sh 阶段状态持久化
- [ ] Review（gstack/OCR）：5维度+AUTO-FIX/ASK+严重度
- [ ] Code-graph（GitNexus/graphify）：引用命令，探查先用图谱索引
- [ ] Phase-loop（gsd-core 可安装）：goal-backward 对抗验证+4类门禁
- [ ] Memory（claude-mem）：三层记忆方案

**质量：**
- [ ] 无占位符残留（`grep -r '待填充\|<项目根>' .`）
- [ ] 所有 .sh 通过 `bash -n`
- [ ] frontmatter description 含项目关键词
- [ ] 工具引用合规（只引用 GitNexus/graphify/ocr/claude-mem/gsd-core 命令，不重新实现）

---

## 五、整合的 7 大方法论

| 方法论 | 来源 | 借鉴的模式 | 在目标技能中的落地 |
|--------|------|-----------|-------------------|
| **Spec-driven** | OpenSpec | proposal→spec(delta:ADDED/MODIFIED/REMOVED)→design→tasks(checkbox)→archive | workflow 节点②③ + assets 模板 |
| **Subagent-driven** | superpowers | orchestrator + fresh subagent per task + 两阶段审查 + progress ledger | workflow 节点⑤ + subagent-orchestration.md |
| **State machine** | comet | 脚本背书阶段状态机 + 硬门禁 + 阻塞决策点 | state-machine.sh |
| **Review** | gstack + open-code-review | 5 审查维度 + AUTO-FIX/ASK + 严重度分级 | check 段 + review-methodology.md |
| **Code-graph** | GitNexus + graphify | 代码图谱索引，查询而非 grep | code-graph-tools.md |
| **Phase-loop** | gsd-core（可安装） | goal-backward 对抗验证 + 4类门禁 + wave并行 + capability | gsd-patterns.md + check + 运行时 `/gsd-*` |
| **Memory** | claude-mem | 跨会话记忆持久化 + detached observer + 3层检索 | memory-persistence.md + 状态控制 |

**工具引用铁律：** GitNexus / graphify / ocr / claude-mem / gsd-core **只引用调用命令，不重新实现，不复制源码**。gsd-core 安装：`npx @opengsd/gsd-core --claude --global` → 运行时 `/gsd:new-project` → `/gsd-execute-phase`/`gsd-tools`。与目标技能安全共存（只 prune `gsd-` 前缀）。**注意：没有 `gsd-core init` 命令。**

---

## 六、什么时候用 / 不用

**用：**
- "为某项目生成开发技能"
- "create a dev skill for this repo"
- "按模板生成 skill" / "六段式 skill" / "需求交付全流程 skill"
- 给了一个代码仓库 + 一份模板，要求产出研发用 skill

**不用：**
- 用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能，如 Swarm-studio，不是 swarm-yuan 本身）

---

## 七、常用命令速查

```bash
# 1. 自检（首次/换机器后）
bash ~/.agents/skills/swarm-yuan/scripts/self-check.sh

# 2. 生成目标技能骨架
bash ~/.agents/skills/swarm-yuan/scripts/generate-skill.sh <name> <project-dir>

# 3. 探查阶段构建图谱（在目标仓库根目录）
gitnexus analyze && gitnexus mcp        # 或
graphify . && graphify path "A" "B"

# 4. 验证生成的目标技能
cd <project>/.agents/skills/<name>
bash scripts/precheck.sh --all          # 质量门禁
bash scripts/self-check.sh              # 9 项目自检
bash -n scripts/*.sh                    # 语法检查
grep -r '待填充\|<项目根>' .            # 占位符检查
```

---

## 八、生成的目标技能怎么用（给研发人员）

目标技能（如 Swarm-studio）生成后，研发人员在日常开发中这样用：

```
①需求理解 → ②设计spec → ③实施plan → ④分支准备 → ⑤编码实现 → ⑥测试验证 → ⑦合入main → ⑧构建发布
```

### 研发人员的 4 个介入点

| 节点 | 研发人员做什么 | 其余谁做 |
|------|--------------|---------|
| ①需求理解 | 确认 agent 对需求的理解 | agent 复述+判定改造类型 |
| ②设计spec | review + 批准 spec | agent 写 OpenSpec proposal |
| ⑦合入main | 确认可以合入 | agent rebase + merge --no-ff |
| ⑧构建发布 | 确认是否发布 | agent 构建 + 验证产物 |

中间的 ③④⑤⑥ 由 agent 自动完成（subagent 编排 + goal-backward 验证 + 状态机持久化），**连续执行不 check-in**。

### 每次开发前的 3 个命令

```bash
cd <project>
bash .agents/skills/<skill>/assets/env-setup.sh           # 检测环境
bash .agents/skills/<skill>/scripts/state-machine.sh status  # 查当前阶段
bash .agents/skills/<skill>/scripts/precheck.sh --all       # 全门禁检查
```

### 中断恢复（context compaction 后）

```bash
git checkout feat/<feature-branch>
bash .agents/skills/<skill>/scripts/state-machine.sh status   # 查阶段状态
cat .swarm-yuan/sdd/progress.md                                # 查任务进度
# 从第一个未完成 Task 继续
```

> 如果装了 claude-mem，SessionStart(compact) hook 自动注入历史 observation，无需手动恢复。

### precheck.sh 各子命令

| 子命令 | 什么时候用 | 检查什么 |
|--------|-----------|---------|
| `--branch` | 建分支后 | 分支名规范、不在保护分支开发 |
| `--scope` | 编码中 | upstream 只读、无本地 commit |
| `--inject` | B类 patch 后 | manifest 存在、series 引用 patch 存在 |
| `--test` | 编码后 | 测试全绿 |
| `--sensitive` | 推送前 | 无硬编码密钥/私有 IP |
| `--consistency` | 测试阶段 | 业务规则 + 数据勾稽（无多漏错重） |
| `--review` | 测试阶段 | 5 审查维度 + goal-backward 对抗验证 |
| `--all` | 任意 | 全部上述检查 |

### state-machine.sh 各子命令

| 命令 | 用途 |
|------|------|
| `init <change>` | 初始化状态（节点①） |
| `transition <phase>` | 阶段转换（含门禁检查） |
| `get <field>` | 读取字段 |
| `set <field> <value>` | 设置字段 |
| `guard <phase>` | 检查阶段准入条件 |
| `next` | 显示下一阶段 |
| `status` | 显示当前状态 |

### 三层记忆方案

| 层 | 工具 | 管什么 | 载体 |
|----|------|--------|------|
| 阶段状态 | comet state-machine | phase / verify_result | `.swarm-yuan/state.yaml` |
| 任务进度 | superpowers progress ledger | 单会话任务完成状态 | `.swarm-yuan/sdd/progress.md` |
| 跨会话知识 | claude-mem（若装） | 决策/发现/gotcha/pattern | `~/.claude-mem/` |

---

## 九、阅读顺序建议

第一次掌握 swarm-yuan 时，按此顺序读：

| 顺序 | 文件 | 目的 |
|------|------|------|
| 1 | 本使用说明 | 整体认知 |
| 2 | `SKILL.md` | 触发条件 + 5 步流程 + 7 方法论映射表 |
| 3 | `references/template-spec.md` | 六段式每段的填充规范 + 生成后核对表 |
| 4 | `references/exploration-guide.md` | 如何探查仓库（含图谱工具用法 + 12 项特征卡） |
| 5 | `references/subagent-orchestration.md` | subagent 编排模式（节点⑤核心） |
| 6 | `references/review-methodology.md` | 5 审查维度 + goal-backward |
| 7 | `references/gsd-patterns.md` | gsd-core 安装 + phase-loop + 4 类门禁 |
| 8 | `references/memory-persistence.md` | claude-mem 跨会话记忆 |
| 9 | `references/code-graph-tools.md` | GitNexus/graphify 命令参考 |
| 10 | 实操 | 跑一遍 `self-check.sh` + `generate-skill.sh` |

---

## 十、一个完整示例

为 SwarmStudio 项目生成开发技能：

```bash
# Step 0: 自检
bash ~/.agents/skills/swarm-yuan/scripts/self-check.sh

# Step 1: 探查（图谱 + 子代理）
cd <project-root>/overlay
gitnexus analyze
# AI agent 三路并行探查

# Step 4: 生成骨架
bash ~/.agents/skills/swarm-yuan/scripts/generate-skill.sh Swarm-studio <project-root>

# Step 3+4: 填充 5 个 reference + 定制 6 个脚本（AI agent 用探查数据填充）

# Step 5: 验证
cd <project-root>/.agents/skills/Swarm-studio
bash scripts/precheck.sh --all        # 门禁
bash scripts/self-check.sh            # 9 项目自检
grep -r '待填充' .                     # 无占位符

# 日常使用（研发人员）
cd <project-root>/overlay
bash .agents/skills/Swarm-studio/assets/env-setup.sh
bash .agents/skills/Swarm-studio/scripts/state-machine.sh status
bash .agents/skills/Swarm-studio/scripts/precheck.sh --all
```

生成后，研发人员只需：**提需求 → 确认 spec → 确认合入 → 确认发布**。中间的编码、测试、审查由 agent 按 8 节点流程自动完成。

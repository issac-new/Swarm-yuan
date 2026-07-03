---
name: swarm-yuan
description: A meta-skill (generator) that produces a project-specific "requirements-to-delivery" development skill for ANY code repository. swarm-yuan integrates seven proven methodologies — OpenSpec spec-driven (proposal→spec→archive), superpowers subagent-driven (orchestrator+fresh-subagent+two-stage-review), comet script-backed state machine (resumable phase pipeline), gstack/open-code-review review dimensions (5-dimension+AUTO-FIX/ASK), GitNexus/graphify code-graph indexing (query graph not grep), gsd-core phase-loop+capability (goal-backward adversarial verification+4-gate taxonomy+wave-parallel), and claude-mem memory persistence (cross-session/cross-compaction SQLite+vector memory with detached observer). It explores a target repo, then generates a complete six-section skill (meta/workflow/reference/assets/check/scripts) guiding developers from requirement to release. Use whenever the user asks to "generate/create a dev skill", "为某项目生成开发技能", or references the XX场景模板/six-section template.
---

# swarm-yuan — 项目需求交付技能生成器 (Project Delivery Skill Generator)

本技能是一个**元技能（生成器）**。它针对任意代码仓库，整合五种已验证方法论，按六段式模板生成项目专属的开发技能（下称"目标技能"）。

> **与项目专属 skill 的关系：** 本技能是生成器；产出的目标技能是应用产物。本技能跨项目复用，**不依赖任何具体项目的内容**。

## 它整合的方法论（仅引用调用，不重新实现）

生成目标技能时，swarm-yuan 将以下方法论的**模式**编织进目标技能的六段结构。这些方法论本身是独立项目，swarm-yuan **只引用其方法与工具命令，不复制其代码**：

| 方法论 | 来源项目 | 借鉴的模式 | 在目标技能中的落地 |
|--------|---------|-----------|-------------------|
| **Spec-driven** | [OpenSpec](https://github.com/Fission-AI/OpenSpec) | proposal→spec(delta:ADDED/MODIFIED/REMOVED)→design→tasks(checkbox)→apply→archive(merge to main spec)；specs as source of truth；验证规则 | workflow 节点②③ + assets 模板 + check 验证 |
| **Subagent-driven** | [superpowers](https://github.com/obra/superpowers) | orchestrator 每任务派发新 subagent（上下文隔离）；两阶段审查（spec合规+质量）；progress ledger 持久化；文件交接（非粘贴）；连续执行不check-in | workflow 节点⑤ + references/subagent-orchestration.md |
| **State machine** | [comet](https://github.com/rpamis/comet) | 脚本背书的阶段状态机（非prompt-only）；阶段转换硬门禁；阻塞决策点（Red Flags 表）；handoff 包+哈希溯源 | workflow 状态控制 + scripts/state-machine.sh |
| **Review dimensions** | [gstack](https://github.com/garrytan/gstack) + [open-code-review](https://github.com/alibaba/open-code-review) | 5 审查维度（正确性/安全/性能/可维护/测试覆盖）；AUTO-FIX vs ASK 启发式；两遍清单（CRITICAL+INFORMATIONAL）；严格聚焦规则；严重度分级(High/Med/Low) | check 段 + references/review-methodology.md |
| **Code-graph indexing** | [GitNexus](https://github.com/abhigyanpatwari/GitNexus) + [graphify](https://github.com/safishamsi/graphify) | 构建代码知识图谱；agent 查询图谱而非 grep；依赖链/调用链/最短路径查询；MCP server 暴露图谱工具 | scripts/code-graph-tools.md + 探查阶段调用 |
| **Phase-loop + capability** | [gsd-core](https://github.com/open-gsd/gsd-core) | discuss→plan→execute→verify→ship 五步循环；12点 loop-host 契约；goal-backward 对抗验证（任务完成≠目标达成）；4类门禁（pre-flight/revision/escalation/abort）；wave并行+worktree隔离；capability 声明式插件（steps/fragments/gates）；context-monitor hook（agent 感知剩余上下文） | references/gsd-patterns.md + workflow 门禁 + check 对抗验证 + 运行时调用 gsd-tools / /gsd-* 命令 |
| **Memory persistence** | [claude-mem](https://github.com/thedotmack/claude-mem) | 跨会话/跨压缩记忆持久化（SQLite+向量）；detached observer agent（工作agent不写记忆）；3层渐进式检索（index→timeline→full）；两session-ID架构；Mode-JSON 分类法；`<private>` 隐私标签 | references/memory-persistence.md + workflow 状态控制 + check 状态恢复 |

> ⚠️ **工具引用规则（铁律）：** 目标技能中涉及代码图谱/索引/审查自动化/记忆持久化/phase-loop 引擎时，**只允许引用调用**以下工具（**不重新实现其功能，不复制其源码**）：
> - **GitNexus**：`npm i -g gitnexus` → `gitnexus analyze` → `gitnexus mcp`
> - **graphify**：`uv tool install graphifyy` → `graphify .` → `graphify path A B`
> - **open-code-review**：`ocr review`
> - **claude-mem**：`npx claude-mem install` → hook 自动注入记忆
> - **gsd-core**：`npx @opengsd/gsd-core --claude --global`（安装 gsd-* skills/agents/commands/hooks 到 `~/.claude/`）→ 运行时 `/gsd:new-project`（创建 `.planning/`）→ `/gsd-execute-phase` / `/gsd-verify` / `gsd-tools query init.<workflow>` / `gsd-tools loop render-hooks <point>` / capability gates
>
> **gsd-core 共存说明：** gsd-core 安装器只 prune `gsd-` 前缀的目录，**非 `gsd-` 前缀的 `.agents/skills/<custom>/` 安全共存**。目标技能（如 `<target-skill-name>`）与 gsd-core 的 `gsd-*` skills 互不干扰。目标技能的 workflow 可调用 gsd-core 的 `/gsd-*` 命令与 `gsd-tools` CLI 作为运行时引擎（phase-loop / capability gates / loop-host 校验），而非手写复刻。
>
> **注意：没有 `gsd-core init` 命令。** `gsd-core` bin 是 AI-runtime 工件安装器；项目初始化（`.planning/` 目录、STATE.md）由运行时 `/gsd:new-project` skill 创建；`gsd-tools init` 是 workflow-context 加载器（非 scaffolder）。

## 六段式模板（生成目标）

| 段 | 目录/文件 | 作用 | 整合的方法论 |
|----|----------|------|-------------|
| **meta** | `SKILL.md` | 元信息、铁律、改造分类、流程总览、命令速查 | 全部 |
| **workflow** | `references/workflow.md` | 节点化流程，每节点 9 要素 | OpenSpec + superpowers + comet |
| **reference** | `references/*.md` | 参考手册：目录/安全/编译/组件/依赖链路/接口/UI/数据 + subagent编排 + 审查方法论 + gsd模式 + 记忆持久化 | 全部 |
| **assets** | `assets/*` | 模板：spec(proposal)/plan(tasks)/分支/环境/库表 + 状态机脚本 | OpenSpec + comet |
| **check** | `scripts/precheck.sh` + reference-manual 检查段 | 验证：测试/业务规则/勾稽/脱敏 + 审查维度/严重度 + goal-backward 对抗验证 | gstack + OCR + gsd-core |
| **scripts** | `scripts/*` | 工具箱：门禁 + 状态机 + 代码片段 + 图谱工具 + MCP + 记忆工具 + gsd-tools 引用 | GitNexus + graphify + comet + claude-mem + gsd-core |

详细规范见 `references/template-spec.md`。

## ⚠️ 运行前自检规则（铁律）

**swarm-yuan 启动时（Step 1 探查前）必须先自检 9 个项目运行时是否已安装。** 未装的自动安装，装不了的手动提示。

```bash
bash scripts/self-check.sh              # 检测 + 自动安装缺失的
bash scripts/self-check.sh --check-only # 仅检测不安装
bash scripts/self-check.sh --install gitnexus  # 仅装指定项目
```

9 个项目运行时与安装方式：

| # | 项目 | 检测命令 | 安装方式 | 自动安装 |
|---|------|---------|---------|---------|
| 1 | OpenSpec | `openspec --version` | `npm i -g @fission-ai/openspec` | ✅ |
| 2 | comet | `comet --version` | `npm i -g @rpamis/comet` | ✅ |
| 3 | GitNexus | `gitnexus --version` | `npm i -g gitnexus` | ✅ |
| 4 | gsd-core | `gsd-tools` | `npx @opengsd/gsd-core --claude --global` | ✅ |
| 5 | claude-mem | `claude-mem` / `~/.claude-mem` | `npx claude-mem install` | ✅ |
| 6 | open-code-review | `ocr --version` | `npm i -g @alibaba-group/open-code-review` | ✅ |
| 7 | graphify | `graphify --help` | `uv tool install graphifyy` | ✅ |
| 8 | superpowers | `~/.claude/plugins/superpowers` | `/plugin install superpowers@claude-plugins-official` | ❌ Claude Code /plugin |
| 9 | gstack | `~/.claude/skills/gstack` | `git clone … ~/.claude/skills/gstack && ./setup` | ❌ 手动 clone |

> **自动安装的 7 个**：self-check.sh 检测到缺失后直接运行安装命令。
> **手动安装的 2 个**（superpowers / gstack）：self-check.sh 检测到缺失后**打印安装命令提示**，不自动执行（因 `/plugin` 是 Claude Code 运行时命令、gstack 需 clone+setup，bash 无法自动完成）。用户按提示安装后重跑 `self-check.sh` 确认。
> **graphify 特殊**：需先有 `uv`（`curl -LsSf https://astral.sh/uv/install.sh | sh`）或 `pipx`；self-check.sh 优先用 uv，降级 pipx，两者都无则提示先装 uv。

## 生成流程（5 步）

```
⓪自检（9 项目运行时） → ①探查目标仓库（含代码图谱构建） → ②提取项目特征 → ③填充六段模板 → ④落盘目标技能 → ⑤验证
```

### Step 0: 自检 9 项目运行时（铁律，先于 Step 1）

```bash
bash scripts/self-check.sh
```
检测 9 个项目运行时（OpenSpec/comet/GitNexus/gsd-core/claude-mem/ocr/graphify/superpowers/gstack）。缺失的自动安装（7 个可自动），手动安装的（superpowers/gstack）打印提示。全部就绪后进入 Step 1。

### Step 1: 探查目标仓库 (Explore)

**1a. 代码图谱构建（优先，材料 scripts 段要求）：**

探查前，先用代码图谱工具索引目标仓库，让后续探查基于图谱而非 grep：

```bash
# GitNexus（Node 生态，深度代码调用图）
npm install -g gitnexus          # 或 npx gitnexus@latest
gitnexus analyze                 # 在目标仓库根目录运行，构建知识图谱
gitnexus mcp                     # 启动 MCP server，供 agent 查询（依赖/调用链/簇）

# graphify（Python 生态，广谱知识图：代码+文档+依赖链）
uv tool install graphifyy        # 注意 PyPI 包名是 graphifyy（双 y）
graphify install --platform agents  # 安装 skill 到 .agents/skills/
graphify .                       # 构建图谱 → graphify-out/GRAPH_REPORT.md + graph.json
graphify path "ComponentA" "ComponentB"  # 查询依赖链/最短路径
```

> 两个工具可选其一或并用。GitNexus 重在代码调用图（持久 DB + MCP）；graphify 重在广谱（代码+文档+媒体，可提交的 graph.json + Mermaid 导出）。探查时读 `graphify-out/GRAPH_REPORT.md` 获取架构概览（god nodes、surprising connections），用 `graphify path/explain` 查具体依赖链。**只引用调用，不复制实现。**

**1b. 三路并行探查（Agent 子代理）：**

- **路 A：结构与构建** — 顶层目录、包描述文件、scripts、端口、构建系统、测试体系
- **路 B：开发规范** — AGENTS.md/CLAUDE.md/CONTRIBUTING、分支策略、文档约定、改造分类
- **路 C：代码组织与外部资源** — 组件库（从图谱读依赖链）、接口、数据模型、安全机制、环境依赖、外部资源、MCP 工具

**关键：** 让子代理报告**具体路径、命令名、版本号、文件名、连接串格式、端口**。组件依赖链路**优先从代码图谱工具的输出读取**（`graphify path` / GitNexus MCP），而非手工 grep。

详细探查清单见 `references/exploration-guide.md`。

### Step 2: 提取项目特征 (Extract)

整理成"项目特征卡"，必须回答 12 项（见 `references/exploration-guide.md` 末尾的特征卡模板）。关键新增：
- **第 10 项 环境与外部资源**：运行时版本、外部服务（DB/缓存/MQ/搜索）、连接方式、是否有 MCP 工具
- **第 11 项 组件库与接口**：主要组件模块（从图谱读依赖链）、API 入口、OpenAPI 生成方式
- **第 12 项 数据规范**：schema 位置、样例数据、业务规则、勾稽关系

### Step 3: 填充六段模板 (Fill)

用 `assets/` 模板逐段填充。**填充原则：**
- **具体优于通用**：用真实路径/命令/版本/连接串，不用占位符
- **引用规则而非写死**：来自 AGENTS.md/记忆的规则引用来源
- **specs as source of truth**：目标技能的 workflow 节点②③采用 OpenSpec 的 proposal→spec(delta)→design→tasks 模式，spec 文档是实现的唯一依据
- **subagent 隔离**：节点⑤编码实现采用 superpowers 的 orchestrator+subagent 模式（见 `references/subagent-orchestration.md`）
- **状态机背书**：节点间状态转换用脚本验证（`scripts/state-machine.sh`），非 prompt-only
- **审查维度覆盖**：check 段含 5 审查维度 + AUTO-FIX/ASK 启发式（见 `references/review-methodology.md`）
- **goal-backward 对抗验证**：check 用 gsd-core 的 goal-backward（任务完成≠目标达成，FORCE 立场，BLOCKER/WARNING）（见 `references/gsd-patterns.md`）
- **图谱工具引用**：scripts 段引用 GitNexus/graphify 命令，不重新实现
- **记忆持久化**：状态控制说明跨会话记忆方案（state-machine + progress ledger + claude-mem 若装）（见 `references/memory-persistence.md`）

### Step 4: 落盘目标技能 (Write)

目标技能目录结构（六段式，覆盖材料全部要素 + 方法论整合）：

```
<project>/.agents/skills/<target-skill-name>/
├── SKILL.md                      # meta 段
├── references/
│   ├── workflow.md               # workflow 段（9 要素/节点，OpenSpec+superpowers+comet 模式）
│   ├── codebase.md               # reference §1 目录结构+技术栈
│   ├── dev-guide.md              # reference §7 组件库代码填充 + 改造分类
│   ├── release.md                # reference §3 编译规则 + 构建发布
│   ├── reference-manual.md       # reference §2/4/5/6/7/8 + check §1/2/3/4 + 审查维度
│   ├── subagent-orchestration.md # ★superpowers subagent 编排模式
│   ├── review-methodology.md     # ★gstack/OCR 审查方法论
│   ├── gsd-patterns.md           # ★gsd-core phase-loop/goal-backward/gates/capability
│   └── memory-persistence.md     # ★claude-mem 跨会话记忆持久化
├── assets/
│   ├── spec-template.md          # assets §4/5（OpenSpec proposal 格式）
│   ├── plan-template.md          # assets §4（OpenSpec tasks checkbox 格式）
│   ├── branch-setup.sh           # assets §3 拉取分支
│   ├── env-setup.sh              # assets §1/2 环境+资源检测
│   ├── data-sample-template.md   # assets §6 库表样例
│   └── state-machine.sh          # ★新增：comet 风格阶段状态机脚本
└── scripts/
    ├── precheck.sh               # check 段（含 --consistency --review）
    ├── state-machine.sh          # 阶段状态机（init/get/set/transition/guard）
    ├── self-check.sh             # ★9 项目运行时自检 + 自动安装
    ├── snippets.md               # scripts §1/3 代码片段+组件参数
    ├── code-graph-tools.md       # GitNexus+graphify 引用说明
    └── mcp-tools.md              # scripts §2 MCP 工具
```

- 默认位置 `<project>/.agents/skills/`（项目级）
- 所有 `.sh` 设为可执行
- frontmatter `description` 写得"pushy"，含项目关键词
- **图谱工具说明（code-graph-tools.md）只引用 GitNexus/graphify 命令，不复制其源码**

### Step 5: 验证 (Verify)

1. **材料要素全覆盖**：workflow 9 / reference 8 / assets 7 / check 4 / scripts 3
2. **方法论整合核对（7 项）**：spec-driven（proposal→archive）、subagent 编排、状态机脚本、审查 5 维度、图谱工具引用、gsd goal-backward 对抗验证+4 类门禁+gsd-core 运行时调用、记忆持久化方案
3. **工具引用合规**：只引用 GitNexus/graphify/ocr/claude-mem/gsd-core 命令，无重新实现
4. **脚本可执行**：`bash -n` 通过，对真实项目运行不报错
5. **无占位符残留**、**触发词准确**、**命令可执行**
6. **演示**：1-2 个真实测试 prompt

## 何时使用本技能

- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"XX场景模板"、"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"、"subagent skill"
- 用户给了一个代码仓库 + 一份模板/材料，要求产出研发用 skill

**不适用：** 用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 使用说明

1. 确认目标项目路径与期望的 skill 名称
2. **运行 `bash scripts/self-check.sh` 自检 9 项目运行时**（未装的自动安装，手动装的打印提示）
3. 读 `references/template-spec.md` 了解六段式填充规范（含 7 方法论整合映射）
4. 读 `references/exploration-guide.md` 了解探查方法（含图谱工具用法）
5. 读 `references/subagent-orchestration.md` 了解 superpowers subagent 编排模式
6. 读 `references/review-methodology.md` 了解 gstack/OCR 审查方法论
7. 读 `references/code-graph-tools.md` 了解 GitNexus/graphify 引用方式
8. 读 `references/gsd-patterns.md` 了解 gsd-core phase-loop/goal-backward/gates 模式
9. 读 `references/memory-persistence.md` 了解 claude-mem 跨会话记忆持久化
9. 运行 `scripts/generate-skill.sh <name> <project-dir>` 创建骨架
10. 按 5 步流程执行，每段落盘后用 template-spec.md 末尾核对表验证

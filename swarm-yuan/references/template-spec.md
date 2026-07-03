# 六段式模板填充规范 (Six-Section Template Spec)

目标技能必须包含六段，覆盖材料模板的全部要素。每段的内容要求与填充规则如下。**生成后用本文件逐项核对，确保无遗漏。**

---

## 1. meta 段（SKILL.md）

**文件：** `<target-skill>/SKILL.md`

**结构：**
```markdown
---
name: <target-skill-name>
description: <项目名> 的需求交付全流程技能。当用户...都应使用本技能。涵盖...全流程。
---

# <skill-name> — <项目名> 需求交付全流程技能

## 核心理念
（项目最核心的铁律，来自 AGENTS.md/CONTRIBUTING/记忆，不超过 7 条）

## 改造分类（决定你怎么写代码）
（项目特有的改动分类表，如 A类/B类、core/plugin、src/lib）

## 全流程总览（N 节点）
（节点流程图 + 一句话说明每节点；标注流程入口顺序与并行关系）

## 六段式结构导航
（段 → 文件 → 用途 的映射表）

## 快速入口（按任务类型）
（任务类型 → 起始节点 → 关键参考 的表）

## 常用命令速查
（真实命令 + 端口约定）

## 质量门禁
（核心门禁清单，对应 check 段）

## 状态保存与恢复
（流程状态载体说明）

## 完成检查表
（任务完成前的 checkbox 清单）
```

**填充规则：**
- `description` 必须包含项目特有关键词（模块名、命令名、技术栈），写得"pushy"以提高触发率
- 核心理念只放最高优先级的铁律，不超过 7 条
- 改造分类必须反映项目实际（探查得出），不要套用通用模板
- 全流程总览的流程图要标注**入口顺序**（谁先做、谁后做、谁并行）——对应材料 workflow 要素 1
- 常用命令必须真实可执行
- **引用规则而非写死**：来自项目规则文件的约束，写"见 AGENTS.md / 项目记忆"，不重复具体值

---

## 2. workflow 段（references/workflow.md）— 9 要素/节点

**文件：** `<target-skill>/references/workflow.md`

**结构：** 节点化流程。**顶部**先画流程图（标注入口顺序与并行关系），然后每个节点含 **9 要素**：

```markdown
## 流程总览

（流程图，标注：①→②→③ 串行节点；并行节点用 └──┘ 标注）

---

## 节点①：需求理解

**① 流程入口（顺序/并行）：** （本节点在流程中的位置：前序节点、后续节点、可并行项）

**② 参与方：** （谁参与，谁是决策方，谁执行）

**③ 前序依赖检查（准入）：**
- （进入本节点前必须满足的条件）
- 信息不足时的处理（提问澄清，不臆测）

**④ 质量门禁：**
- （离开本节点前必须满足的条件，可被 precheck.sh 验证）

**⑤ 分支处理：**
- 成功：（对分支的处理）
- 失败/错误：（如何回退、重试）
- 信息不足：（暂停澄清还是降级处理）

**⑥ 产出物归档：**
- 持久化：（落盘到哪个路径）
- 临时上下文：（仅对话/草稿的产物）

**⑦ 流程控制：** （可否暂停/恢复/重启；恢复方式）

**⑧ 状态控制：** （状态保存在哪，如何恢复）

（其他节点同结构）

---

## ⑨ 流程完成检查表
（全流程完成前的 checkbox 清单，汇总所有节点的门禁）
```

**标准节点（可按项目裁剪）：**
1. 需求理解
2. 设计 spec（采用 OpenSpec proposal 模式：proposal.md + delta spec + design.md + tasks.md）
3. 实施 plan（采用 OpenSpec tasks checkbox 格式 + superpowers writing-plans bite-sized 步骤）
4. 分支准备
5. 编码实现（采用 superpowers subagent-driven：orchestrator + 每任务新 subagent + 两阶段审查）
6. 测试验证（含 gstack/OCR 5 审查维度 + AUTO-FIX/ASK）
7. 合入 main
8. 构建发布

> 项目可能有额外节点（如"代码审查"、"部署验证"），或无发布环节。按项目实际裁剪。
> **方法论整合：** 节点②③用 OpenSpec 的 proposal→spec(delta)→design→tasks 模式（specs as source of truth）；节点⑤用 superpowers 的 subagent 编排（见 subagent-orchestration.md）；节点间状态用 comet 风格脚本背书（state-machine.sh，非 prompt-only）；节点⑥含 gstack/OCR 审查维度（见 review-methodology.md）。

**填充规则（9 要素逐项）：**
1. **流程入口** — 每节点标注其在流程中的位置（前序/后续/并行），顶部流程图体现全局入口顺序
2. **参与方** — 明确每个节点的参与者与角色（执行/决策/确认）
3. **准入检查** — 具体可验证（如"git rev-parse HEAD == git rev-parse main"）
4. **质量门禁** — 可被 precheck.sh 验证的检查项
5. **分支处理** — 必须覆盖成功/失败/信息不足三种情况
6. **产出物归档** — 区分持久化（落盘）vs 临时上下文（对话/草稿）
7. **流程控制** — 标注可否暂停/恢复/重启及恢复方式
8. **状态控制** — 状态载体（git 分支/文件/对话上下文）与恢复方式
9. **完成检查表** — workflow.md 末尾，汇总所有节点门禁

**标注需要用户确认的节点**（通常是合入 main、发布）。

---

## 3. reference 段（references/*.md）— 8 项

**文件：** 多个，按主题拆分。

| 文件 | 覆盖材料项 | 内容 |
|------|-----------|------|
| `codebase.md` | §1 代码目录结构及配置信息 | 目录树、技术栈版本表、端口、配置、构建机制 |
| `dev-guide.md` | §7 组件库代码填充说明（部分） | 改造分类详解 + 开发指南 + 领域/实体对象域填充 + 接口参数填充 + 任务流程填充 |
| `release.md` | §3 项目编译规则清单 | 编译规则表 + 构建命令 + 产物位置 + 失败排查 |
| `reference-manual.md` | §2/4/5/6/7/8 + check §1/2/3/4 | 见下方 |

**reference-manual.md 必须包含的章节：**

| 章节 | 材料项 | 内容 |
|------|--------|------|
| §安全检查规则清单 | §2 | 脱敏、密钥、网络白名单、框架安全基线 |
| §项目组件库清单 | §4 | 主要组件模块 + 关键组件名 + store 位置 + 计数 |
| §组件依赖链路说明 | §5 | 组件挂载树/依赖关系图（从入口到子组件） |
| §应用接口清单 | §6 | API 入口、路由文件、OpenAPI 生成方式、认证机制 |
| §UI/UX设计资源清单 | §7 | 设计文档、主题、样式、品牌资源、i18n |
| §数据字典及数据规范 | §8 | schema 位置、数据流、业务规则、勾稽关系 |
| §测试案例（check §1） | check §1 | 单测/接口/集成/回归/安全测试案例及数据 |
| §业务规则案例（check §2） | check §2 | 业务规则 + 案例数据 |
| §数据勾稽核对（check §3） | check §3 | 无多漏错重核对项 |
| §UI展示核对（check §4） | check §4 | UI正确/脱敏/日志 |

**填充规则：**
- 全部用探查到的**真实路径、版本号、命令名、连接串格式**
- 组件依赖链路用树/图表示（从 App 入口到叶子组件）
- 接口清单列出 API 入口（控制器、路由文件、OpenAPI 生成方式、认证）
- 数据字典含 schema 定义位置、数据流、**勾稽核对项**（无多漏错重：无遗漏、无多余、记录正确、勾稽正确、一致性、幂等性）
- 业务规则案例：列出关键业务规则 + 对应的测试案例数据

---

## 4. assets 段（assets/*）— 7 项

**文件：** 模板、环境脚本、数据模版。

| 文件 | 材料项 | 内容 |
|------|--------|------|
| `spec-template.md` | §4 任务配置模版 + §5 静态资源 | 设计文档模板（含静态资源/页面元素段） |
| `plan-template.md` | §4 实施计划模版 | Task 拆分 + 起点核验 + 检查表 |
| `branch-setup.sh` | §3 拉取代码仓库分支 | 核验起点 + 建分支 + 记录基线 |
| `env-setup.sh` | §1 加载环境 + §2 检测资源连接/工具权限 | 环境加载 + 资源连通性 + 工具权限检测 |
| `data-sample-template.md` | §6 库表及数据结构、样例数据 | 库表 schema 模版 + 样例数据格式 |
| `state-machine.sh` | ★comet 风格阶段状态机 | 阶段状态持久化（init/get/set/transition/guard），survive compaction |

**填充规则：**
- `env-setup.sh` 必须检测：开发环境（node/python/go 版本）、外部资源连通性（DB/缓存/MQ，按项目实际）、工具权限（git/gh/docker）。检测项按项目探查结果定制，无对应资源的项跳过
- spec/plan 模板采用 OpenSpec 格式：spec-template = proposal.md（Why/What/Capabilities/Impact）+ delta spec（ADDED/MODIFIED/REMOVED/RENAMED + SHALL/MUST + Scenario WHEN/THEN）；plan-template = tasks.md（`- [ ] X.Y` checkbox，apply 阶段解析进度）
- branch-setup.sh 包含起点核验 + 保护分支检查
- data-sample-template.md 提供库表 schema + 样例数据的填写框架
- state-machine.sh 实现 comet 风格阶段状态机：`init <change>` / `get <field>` / `set <field> <val>` / `transition <phase>` / `guard <phase>` / `next`。状态存 `.swarm-yuan/state.yaml`（survive context compaction）。阶段转换有硬门禁（guard 验证产出物存在）

---

## 5. check 段（scripts/precheck.sh + reference-manual.md 检查段）— 4 项

**文件：** `scripts/precheck.sh` + `references/reference-manual.md` 的检查章节。

**precheck.sh 子命令：**
```bash
bash precheck.sh                  # 全部门禁
bash precheck.sh --branch         # 分支规范
bash precheck.sh --scope          # 改动范围（可改 vs 只读）
bash precheck.sh --build          # 构建状态
bash precheck.sh --test           # 测试（check §1）
bash precheck.sh --sensitive      # 敏感信息脱敏（check §4）
bash precheck.sh --consistency    # 业务规则 + 数据勾稽核对（check §2/§3）
bash precheck.sh --review         # ★代码审查（gstack/OCR 5 维度，调用 ocr review 若可用）
```

**reference-manual.md 检查段包含（对应 check 4 项 + 审查）：**

| check 项 | 内容 | precheck 子命令 |
|----------|------|----------------|
| §1 单测/接口/集成/回归/安全测试案例 | 测试框架、目录、案例数据、运行命令 | `--test` `--sensitive` |
| §2 业务规则案例及数据 | 关键业务规则 + 案例数据 + 预期结果 | `--consistency` |
| §3 数据勾稽核对（无多漏错重） | 无遗漏、无多余、记录正确、勾稽正确、一致性、幂等性 | `--consistency` |
| §4 UI展示核对 | 展示正确、敏感信息脱敏、请求响应日志已记录 | `--sensitive` |
| ★代码审查 | 5 维度（正确性/安全/性能/可维护/测试覆盖）+ 两遍清单 + AUTO-FIX/ASK + 严重度分级 | `--review` |

**填充规则：**
- scope 检查反映项目的可改/只读边界
- sensitive 扫描涵盖项目用到的密钥格式
- `--consistency` 检查业务规则完整性 + 数据勾稽（无多漏错重）
- `--review` 调用 `ocr review`（若已安装），否则提示手动审查清单（5 维度 + 两遍清单）。引用 `references/review-methodology.md`
- 测试检查调用项目真实的测试命令

---

## 6. scripts 段（scripts/*）— 3 项

**文件：** 工具箱脚本与文档。

| 文件 | 材料项 | 内容 |
|------|--------|------|
| `precheck.sh` | §1 执行命令脚本 | 质量门禁检查（见 check 段，含 --review） |
| `state-machine.sh` | ★comet 风格状态机 | 阶段状态持久化（init/get/set/transition/guard/next），survive compaction |
| `snippets.md` | §1 代码示例片段 + §3 组件详细参数配置说明 | 常用代码片段、命令示例、组件参数配置 |
| `code-graph-tools.md` | ★GitNexus+graphify 引用 | 代码图谱工具安装与命令（只引用，不复制源码） |
| `mcp-tools.md` | §2 MCP工具：DB/ELK/Redis/MQ/dubbo/union/CMDB | MCP 工具接入说明（按项目实际有的才填） |

**填充规则：**
- precheck.sh 是必选，含 `--review` 子命令（引用 review-methodology.md）
- state-machine.sh 实现 comet 风格阶段状态机（init/get/set/transition/guard/next），状态存 `.swarm-yuan/state.yaml`
- snippets.md 收录：高频命令组合、代码模板、组件参数配置表
- **code-graph-tools.md 引用 GitNexus/graphify**（见 `references/code-graph-tools.md`）：按项目语言生态选择，只写安装+命令+集成模式，**不复制工具源码**
- **mcp-tools.md 按项目实际填充**：项目有 DB/ELK/Redis/MQ → 填访问方式；无 → 写"本项目无外部 MCP 资源"
- 脚本必须 `chmod +x` 且 `bash -n` 语法检查通过
- 路径用绝对路径或基于脚本位置的相对路径，确保可移植

---

## 生成后核对清单

生成目标技能后，用本清单逐项核对材料要素覆盖 + 方法论整合：

**材料要素覆盖：**
- [ ] **meta**：铁律、改造分类、流程总览（含入口顺序）、命令速查、门禁、检查表
- [ ] **workflow 9 要素**：每节点都有 流程入口/参与方/准入/门禁/分支处理/产出物归档/流程控制/状态控制；末尾有完成检查表
- [ ] **reference 8 项**：目录结构/安全检查/编译规则/组件库/组件依赖链路/接口清单/UI-UX资源/数据字典
- [ ] **assets 7 项**：环境加载/资源检测/分支拉取/任务配置模版/静态资源/库表样例/组件填充说明
- [ ] **check 4 项**：单测接口集成回归安全/业务规则案例/数据勾稽(无多漏错重)/UI脱敏日志
- [ ] **scripts 3 项**：执行脚本/代码片段+组件参数/MCP工具

**方法论整合（7 项）：**
- [ ] **Spec-driven（OpenSpec）**：workflow 节点②③用 proposal→spec(delta)→design→tasks 模式；spec/plan 模板用 OpenSpec 格式（delta ADDED/MODIFIED + SHALL/MUST + Scenario WHEN/THEN；tasks `- [ ]` checkbox）
- [ ] **Subagent-driven（superpowers）**：workflow 节点⑤引用 subagent-orchestration.md（orchestrator + 每任务新 subagent + 两阶段审查 + progress ledger + 文件交接）
- [ ] **State machine（comet）**：scripts/state-machine.sh 实现阶段状态持久化 + 阶段转换硬门禁；workflow 状态控制段引用它
- [ ] **Review（gstack/OCR）**：check 段含 5 审查维度 + 两遍清单 + AUTO-FIX/ASK + 严重度分级；precheck.sh --review；引用 review-methodology.md
- [ ] **Code-graph（GitNexus/graphify）**：scripts/code-graph-tools.md 引用工具命令（只引用不复制）；探查阶段先用图谱索引；组件依赖链路从图谱读
- [ ] **Phase-loop + capability（gsd-core）**：引用 gsd-patterns.md；check 用 goal-backward 对抗验证（任务完成≠目标达成，FORCE 立场，BLOCKER/WARNING 分类）；门禁分 4 类（pre-flight/revision/escalation/abort）；workflow 可选 wave 并行；**若装了 gsd-core 则调用 `/gsd-execute-phase`/`/gsd-verify`/`gsd-tools` 运行时引擎，若未装则降级为 state-machine.sh + subagent 手动编排**
- [ ] **Memory persistence（claude-mem）**：引用 memory-persistence.md；状态控制段说明跨会话记忆方案（state-machine.sh 管阶段 + progress ledger 管任务 + claude-mem 若装则管跨会话知识）；3 层渐进式检索

**质量：**
- [ ] 无占位符残留（`<待填充>`/`<项目根>` 等）
- [ ] 所有 .sh 通过 `bash -n`
- [ ] frontmatter description 含项目关键词
- [ ] **工具引用合规**：只引用 GitNexus/graphify/ocr/claude-mem/gsd-core 命令，无重新实现

---
name: swarm-yuan
description: "Meta-skill generator: produces a project-specific dev skill for ANY code repo. Integrates 13 runtimes, 54 quality gates, 5-layer cognition framework, 32-domain knowledge. Core capability: exhaustive component inventory + call-chain analysis → orchestration constraints derivation. Use when user says '为某项目生成开发技能', 'create a dev skill', '六段式 skill'."
---

# swarm-yuan — 项目需求交付技能生成器

元技能（生成器）：针对任意代码仓库，按六段式模板生成项目专属开发技能（下称"目标技能"）。跨项目复用，不依赖任何具体项目内容。

> **docs/ 路径注**：本文引用的 `docs/paradigm-decisions.md`、`docs/paradigm-positioning.md`、`docs/upstream-baseline.md`、`docs/runtime-update-2026-07.md` 位于仓库根 `docs/`（swarm-yuan 父级），非 `swarm-yuan/docs/`；standalone 安装时不携带，核心内容已内联到 references/ 或 SKILL.md。
>
> **工具脚本路径注**：`trace-log.sh`/`state-machine.sh`/`memory-writeback.sh` 在**生成器侧**（本仓库/安装态 swarm-yuan 目录）物理位于 `assets/`；在**生成的目标技能侧**经 UNIVERSAL_FILES 映射为 `scripts/`。本文按目标技能路径书写为 `scripts/xxx.sh`；执行**生成流程**（Step 0-8）时应以 `assets/xxx.sh` 路径调用（`cost-report.sh`/`generate-skill.sh`/`self-check.sh` 等生成器工具本就位于 `scripts/`，不受影响）。
>
> **口径权威源**：`assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。
>
> **AI 判断边界**：质量类门禁（cognition/diagram/pr_quality/consistency/link_depth 等）运行 AI 判断引导模式——机械脚本不假装能判断质量，AI 按检查单自查并留痕 `notes/`（R13 后为唯一模式）。

**★核心能力（v2 增强）**：基于代码结构与调用链路分析，产出**详尽的组件库清单**（全量穷举，非代表性样本）与**编排调用关系及约束**（导入方向/注册顺序/路由挂载/状态所有权/测试边界，每条含代码证据），完善目标技能的研发 skill。方法论见 `references/exploration-guide.md` §C+。

**★核心能力（v3 左移）**：测试、变更影响、运维监控不等到测试/发布阶段才考虑，在 spec/plan 阶段就嵌入约束（spec §19 测试设计 + §20 变更影响 + §21 可观测性约束），编码阶段先测试后实现，合入前确认回滚预案，发布前确认灰度+告警+runbook。门禁 `--shift-left` 校验各阶段左移产出物。详见 `references/template-spec.md` §左移要求。

## 何时使用

- 用户输入 `/swarm-yuan <项目路径>`（slash command，详见 `.claude/commands/swarm-yuan.md`）
- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"
- 用户给了一个代码仓库，要求产出研发用 skill
- 用户要为「关节编排 / Articulated Orchestration」类汇报（如 AI 赋能研发、金融级清算核心交付）准备论据：swarm-yuan 的特征卡/门禁/verifier 可作为"凭什么可信"的机器执法兜底，落地案例映射见 `references/case-studies/articulation-orchestration.md`

**安装**：`bash install.sh`（自动检测运行环境 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi，安装到对应 skill 目录。详见 `install.sh --list`）

**不适用场景**（详见 `docs/paradigm-positioning.md`）：
- 个人脚本/一次性原型/学习用 demo——建议直接用 AI 裸写，不套范式
- 极小改动（改 typo/调样式）——直接改，不走 spec 流程
- 无 AI 辅助的纯人工开发——范式设计为 AI 驱动，纯人工无法消费
- 替代方案：单文件 `precheck.sh` 做门禁不套生成器；或传统 lint/test 工具链

**不适用**：用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 工作时的思考框架（R13：概念以指引式落地，非名词堆砌）

工作时按这些检查单思考（不再要求背概念名词——每条在对应环节被真实使用）：

- **探查时**：按认知六阶链逐层看项目——概念（术语表与代码命名一致吗）→结构（模块边界/循环依赖）→空间（目录布局）→映射（需求→组件→测试对应）→规律（隐性编排约束显式化）→处理（数据流走向）。判断留痕写 `.swarm-yuan/notes/cognition.md`。
- **思考时**：用思维语言推演（三元演化/七推理），用逻辑剃刀删冗余假设；每个方案过偏差自检（五维偏差 + 8 类思维模型——见 cognitive-bias.md 按需读）。
- **决策时**：三级分类（Mechanical 直接做 / Taste 给方案+推荐 / UserChallenge 必停五要素）——`scripts/trace-log.sh --decision` 落痕 `decisions.jsonl`，含备选对比与 rationale。
- **纠偏时**：辩证推演（7 对范畴）统一多视角冲突；领域知识防达克（32 领域速查 domain-knowledge.md 按需读）。

## 三条铁律

1. **版本锁定**：不随意升级核心依赖（除非用户要求/安全漏洞/性能/功能缺失）。`--deps` 检测。
2. **安全规范**：目标技能遵守 OWASP Top 10 / STRIDE / CWE。`--security` 检测。依据 `references/security-spec.md`。
3. **三平台兼容（生成器自身）**：bash 硬前置（Windows 走 Git Bash/WSL + .bat 包装）。脚本兼容约束：不用 `declare -A`；`sed -i.bak+rm`；`${var}` 防多字节；`$(cd+pwd)` 替代 `readlink -f`。

## 生成流程（AI 自动执行，用户提供项目路径即开始）

```
用户："为 /path/to/project 生成 skill"
⓪自检 → ⓪.5读项目知识 → ①探查（三路并行） → ①.5形态判定+组件库清单+调用链
→ ②特征卡 → ③骨架 → ④填充（消除全部占位符） → ④.5框架深化 → ⑤conf
→ ⑤.5hooks/commands/MCP → ⑥门禁验证 → ⑦.5门禁注入 → ⑦记忆写回 → ⑧终检
```

铁律：①完整流程后才算完成，draft 骨架不可交付（状态门：`--mark-active` 零占位符核验才翻 active；中断重跑断点续传）；②每步公告调用 `→ [节点X] 调用 …` + trace-log 节点级落盘；③门禁误报自动调 conf 重跑，每节点有降级策略；④不预设项目形态——先 §C+.0 判定再按维度全量穷举+计数核验（≥ 枚举×0.95），编排约束每条须代码证据；⑤任务类型路由避免全任务跑全量（task-methodology-router.md）。

> Step 详解按需读 `references/generation-flow.md`；探查方法论 `references/exploration-guide.md`。

## 六段式模板

meta（SKILL.md）/ workflow（8 节点×4 要素）/ reference（map + spec-template + 按需）/ assets（模板）/ check（precheck.sh 门禁族（真值见 facts.conf）+ rules.d 三值规则）/ scripts（工具箱）。

门禁：四族（核心/架构/合规/advisory，计数真值见 `assets/facts.conf`——文档不手抄数字，R13 后无漂移源）（全部有真实触发路径——序列/hooks/loop-hook，R13 接线）；规则数据在 `rules.d/*.rules`（三值 allow/prompt/forbid 取最严，FORBID 消息带替代方案）；审批可沉淀为持久规则。enforce 分层（strict/warn/advisory）是实现细节，模型只选执行序列（`--all`/`--all-full`/`--compliance-suite`）。

## 三层接线（13 运行时，调用不重实现）

| 层 | 运行时 | 接线 | 降级 |
|----|--------|------|------|
| 深度（4） | GitNexus/graphify/claude-mem/ocr | 门禁内真实子进程调用 | grep+madge 等 |
| CLI（4） | OpenSpec/comet/gsd-core/codex-security | 按需调用 CLI | 自带文档检查等 |
| 方法论（5） | superpowers/gstack/ECC/Ruflo/impeccable | AI 按节点引用模式 | 自带等价载体 |

代码图谱按技术能力平权选型（GitNexus 调用图 / graphify 知识图，可并用）。

**reference 清单（按需读取，40 份全带"何时读我"路由头）**：探查→exploration-guide；填充→template-spec；认知→cognition-framework 等 4 份；方法论→各 *-methodology.md；合规→standards-compliance + 7 行业 profile（`--industry` 真实加载）；安全→security-spec + frameworks/ 74 规则库按 ACTIVE_FRAMEWORKS 选读。孤儿资产由 self-check 扫描（=0）。

## 使用说明

1. 确认目标项目路径与 skill 名称
2. `bash scripts/self-check.sh` 自检
3. 按任务路由读对应 reference（各文件头部"何时读我"）
4. `scripts/generate-skill.sh <name> <project-dir>` 创建骨架（`--upgrade` 升级）
5. 按生成流程执行（铁律见上）
6. 填充完成后 `bash scripts/generate-skill.sh --mark-active <skill_dir>` 翻 active

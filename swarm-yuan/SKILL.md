---
name: swarm-yuan
description: "元技能生成器：为任意代码仓库生成项目专属开发技能（六段式：SKILL.md+workflow+references+assets+precheck+scripts）。核心能力：探查期全量组件库清单+调用链分析→编排约束推导；门禁三值规则（rules.d）；自成长链。何时用：用户说'为某项目生成开发技能'、'create a dev skill'、'六段式 skill'。计数真值见 assets/facts.conf（不手抄）。"
---

# swarm-yuan — 项目需求交付技能生成器

元技能（生成器）：针对任意代码仓库，按六段式模板生成项目专属开发技能（下称"目标技能"）。跨项目复用，不依赖任何具体项目内容。本文按五层递进组织：理念→设计→架构→实现→使用，引用路由收尾。

> **口径权威源**：`assets/facts.conf`（数字单一事实源，self-check 机器执法）；全部设计/决策/上游基线见仓库根 `README.md`（standalone 安装时不携带，核心已内联到本文与 references/）。
>
> **路径注**：`trace-log.sh`/`state-machine.sh`/`memory-writeback.sh` 在生成器侧位于 `assets/`，在目标技能侧映射为 `scripts/`；执行生成流程（Step 1-12）时以 `assets/xxx.sh` 调用（`cost-report.sh`/`generate-skill.sh`/`self-check.sh` 位于 `scripts/` 不受影响）。

## 第一层 理念

**先认识，再行动。** AI 写代码前必须先认识项目——认知不是看懂代码，是让拼装有依据：

- **拼装式开发**：新功能 = 既有稳定单元拼装 + 最小新增胶水。禁止重复造轮子/侵入式重构/破坏性改造——探查产出的"可复用稳定单元清单"就是零件目录。
- **特征卡是立法，门禁是执法，验证器是司法**：特征卡定义项目应然，门禁验证代码合规，verifier 独立证明门禁有效。三权分立。
- **诚实降级**：运行时未装不阻塞但显式披露；权限边界一律 fail-closed。
- **AI 全自动、零手动配置**：生成为 AI 一键完成；使用时用户对 AI 说话。

**何时使用**：用户说"为某项目生成开发技能"/"create a dev skill"/"六段式 skill"、给了仓库要研发 skill、或要为「关节编排」类汇报准备机器执法论据（案例映射见 `references/case-studies/articulation-orchestration.md`）。

**不适用**：个人脚本/一次性原型（AI 裸写即可）；typo 级小改（不走 spec）；纯人工开发（范式为 AI 驱动）；用户只是要在某项目里做开发任务（那用该项目的目标技能）。替代：单文件 precheck.sh 只做门禁，或传统 lint/test 工具链。

## 第二层 设计

**工作时的思考框架**（每条在对应环节被真实使用）：

- **探查**：认知六阶链逐层看项目——概念→结构→空间→映射→规律→处理；留痕 `.swarm-yuan/notes/cognition.md`。
- **思考**：思维语言推演 + 逻辑剃刀删冗余假设；方案过偏差自检（cognitive-bias.md 按需读）。
- **决策**：三级分类（Mechanical 直接做 / Taste 给方案+推荐 / UserChallenge 必停五要素）——`trace-log.sh --decision` 落痕 decisions.jsonl。
- **纠偏**：辩证推演统一多视角冲突；领域知识防达克（domain-knowledge.md 按需读）。
- **左移**：测试/变更影响/可观测性在 spec/plan 阶段就嵌入约束（spec §19/§20/§21），编码先测试后实现，合入前确认回滚，发布前确认灰度+告警。门禁 `--shift-left` 校验。

**三条铁律**：①版本锁定——不随意升级核心依赖（`--deps` 检测）；②安全规范——目标技能遵守 OWASP Top 10 / STRIDE / CWE（`--security`，依据 `references/security-spec.md`）；③三平台兼容——bash 硬前置（Windows 走 Git Bash/WSL + .bat），脚本约束：不用 `declare -A`、`sed -i.bak+rm`、`${var}` 防多字节、`$(cd+pwd)` 替代 `readlink -f`。

**AI 判断边界**：质量类门禁（cognition/diagram/pr_quality/consistency/link_depth）为 AI 判断引导模式——机械脚本不假装能判断质量，AI 按检查单自查并留痕 `notes/`。

## 第三层 架构

**六段式模板**：meta（SKILL.md）/ workflow（9 节点×4 要素）/ reference（map + spec-template + 按需）/ assets（模板）/ check（precheck 门禁族 + rules.d 三值规则）/ scripts（工具箱）。

**门禁四族**（计数真值见 `assets/facts.conf`，全部有真实触发路径——序列/hooks/loop-hook）：核心（随 `--all`）/ 架构（随 `--all-full`）/ 合规（随 `--compliance-suite`）/ advisory。规则数据在 `rules.d/*.rules`（三值 allow/prompt/forbid 取最严，FORBID 消息带替代方案）；审批可沉淀为持久规则。enforce 分层（strict/warn/advisory）是实现细节，模型只选执行序列。

**三层接线**（13 运行时，调用不重实现）：深度（GitNexus/graphify/claude-mem/ocr，门禁内真实子进程）/ CLI（OpenSpec/comet/gsd-core/codex-security，按需 CLI）/ 方法论（superpowers/gstack/ECC/Ruflo/impeccable，AI 按节点引用）——代码图谱平权选型可并用。清单与降级链详见 `references/subagent-orchestration.md`。

## 第四层 实现

**生成流程**（AI 自动执行，用户提供项目路径即开始）：

```
⓪自检 → ⓪.5读项目知识 → ①探查（三路并行） → ①.5形态判定+组件库清单+调用链
→ ②特征卡 → ③骨架 → ④填充（消除全部占位符） → ④.5框架深化 → ⑤conf
→ ⑤.5hooks/commands/MCP → ⑥编码验证（测试门禁）→ ⑦独立审查（review 门禁）
→ ⑦.5门禁注入 → ⑧记忆写回 → ⑨终检
```

铁律：①完整流程后才算完成，draft 骨架不可交付（`--mark-active` 零占位符核验才翻 active；中断重跑断点续传）；②每步公告 `→ [节点X] 调用 …` + trace-log 落盘；③门禁误报自动调 conf 重跑，每节点有降级策略；④不预设项目形态——先 §C+.0 判定再按维度全量穷举+计数核验（≥ 枚举×0.95），编排约束每条须代码证据；⑤任务类型路由避免全任务跑全量（task-methodology-router.md）。

**核心能力**：基于代码结构与调用链分析，产出**全量组件库清单**（穷举非抽样）与**编排调用关系及约束**（导入方向/注册顺序/路由挂载/状态所有权/测试边界，每条含代码证据）。方法论见 `references/exploration-guide.md` §C+。

## 第五层 使用

**安装**：`bash install.sh`（自动检测 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi；`install.sh --list` 详列）。slash 命令 `/swarm-yuan <项目路径>`（`.claude/commands/swarm-yuan.md`）。

**生成**：`scripts/generate-skill.sh <name> <project-dir>` 创建骨架 → 按生成流程执行 → `--mark-active` 翻 active（`--upgrade` 升级既有技能）。

## 引用路由（按需读取，全部带"何时读我"头）

探查→exploration-guide（含 §C+.0.6 四层架构视角）；填充→template-spec（spec §24 架构映射）；生成流程详解→generation-flow；认知→cognition-framework 等；方法论→各 *-methodology.md（cordis-composability / mea-loop / agent-skills / dsh-engineering / togaf-metamodel 等）+ context-engineering-layering；合规→standards-compliance + 行业 profile（`--industry` 真实加载）；安全→security-spec + frameworks/ 规则库按 ACTIVE_FRAMEWORKS 选读；编排→subagent-orchestration。

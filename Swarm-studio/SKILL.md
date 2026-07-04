---
name: ncwk-dev
description: （填充指引：写一句触发条件 + 项目特有关键词。例"SwarmStudio 二次开发全流程技能。触发关键词: hermes-overlay, cockpit, patch inject, vitest, 拼装式开发"）
---

# ncwk-dev — （填充指引：项目名 + 需求交付全流程技能）项目需求交付全流程技能

> 本技能由 swarm-yuan 生成器创建（2026-07-04T16:34:33Z），需 AI agent 探查项目后填充。
> 填充规范见 swarm-yuan/references/template-spec.md

## 填充指引（六段式 + 材料要素 + 方法论整合 + 五层认知基底核对）
- [ ] **★四层认知基底**: SKILL.md 含四层框架段（认知递进/思维语言/认知辩证/认知偏差防范）；spec-template 含 §14 交付衰减/§15 蓝图/§16 认知偏差自检；reference-manual 含逻辑谬误图谱 + 认知映射表 + 六维动力学基线；workflow 含 4-Phase 多轮交互 SOP；check 含逻辑剃刀对抗审查
- [ ] **meta**: 核心理念（四层认知基底 + 拼装式开发三条禁止性约束）、改造分类、全流程总览（含入口顺序）、命令速查、门禁、检查表
- [ ] **workflow** (9 要素/节点 + 4-Phase SOP): references/workflow.md
  - 节点②③用 OpenSpec proposal→spec(delta)→design→tasks 模式
  - 节点⑤用 superpowers subagent 编排（见 references/subagent-orchestration.md）
  - 4-Phase SOP（概念澄清→破局重构→七步推演→行动落地），每 Phase 暂停等确认
  - 状态控制引用 scripts/state-machine.sh（comet 风格脚本背书）
- [ ] **reference** (8 项 + 方法论 + 认知): codebase.md / dev-guide.md / release.md / reference-manual.md
  + subagent-orchestration.md / review-methodology.md / code-graph-tools.md / security-spec.md
  + cognition-framework.md / logic-razor.md / cognitive-bias.md（四层认知 reference，已就绪按需引用）
- [ ] **assets** (7 项): spec-template.md(OpenSpec proposal 含 §5.5复用约束/§5.6版本约束/§5.7安全约束/§14交付衰减/§15蓝图/§16认知偏差自检) / plan-template.md(tasks checkbox) /
  branch-setup.sh / env-setup.sh / data-sample-template.md / state-machine.sh
- [ ] **check** (22 门禁 + 审查 + 逻辑剃刀 + 铁律): scripts/precheck.sh
  --branch/--scope/--build/--test/--sensitive/--consistency/--review/--reuse/--deps/--security
  --layer/--stable-diff/--link-depth/--adr/--contract/--consistency-cross/--impact
  --service/--api/--state/--frontend/--cognition
  + reference-manual.md 检查段（含 5 审查维度 + 逻辑剃刀 6 步 + 谬误图谱）
- [ ] **scripts** (5 项): precheck.sh / state-machine.sh / snippets.md / code-graph-tools.md / mcp-tools.md
  - precheck.sh 22 个门禁子命令，配置变量按项目实际填充（DDD/TOGAF/微服务/前端/认知）
  - code-graph-tools.md 引用 GitNexus/graphify（只引用命令，不复制源码）
  - mcp-tools.md §2 MCP 工具(DB/ELK/Redis/MQ，按项目实际)

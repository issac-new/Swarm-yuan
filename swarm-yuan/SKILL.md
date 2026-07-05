---
name: swarm-yuan
description: "Meta-skill generator: produces a project-specific dev skill for ANY code repo. Integrates 10 runtimes (OpenSpec/superpowers/comet/GitNexus/graphify/gsd-core/claude-mem/ocr/gstack/Ruflo), 25 quality gates, 5-layer cognition framework, 32-domain knowledge. Use when user says '为某项目生成开发技能', 'create a dev skill', '六段式 skill'."
---

# swarm-yuan — 项目需求交付技能生成器

元技能（生成器）：针对任意代码仓库，按六段式模板生成项目专属开发技能（下称"目标技能"）。跨项目复用，不依赖任何具体项目内容。

## 何时使用

- 用户输入 `/swarm-yuan <项目路径>`（slash command，详见 `.claude/commands/swarm-yuan.md`）
- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"
- 用户给了一个代码仓库，要求产出研发用 skill

**安装**：`bash install.sh`（自动检测运行环境 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi，安装到对应 skill 目录。详见 `install.sh --list`）

**不适用**：用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 三条铁律

1. **版本锁定**：不允许随意升级核心依赖版本（除非用户要求/安全漏洞/性能隐患/功能缺失）。`--deps` 检测。
2. **安全规范**：目标技能须遵守 OWASP Top 10 / STRIDE / CWE。`--security` 检测。详见 `references/security-spec.md`。
3. **三平台兼容（swarm-yuan 自身）**：swarm-yuan 生成器自身的脚本（precheck.sh / generate-skill.sh / self-check.sh / state-machine.sh 等）必须兼容 Windows/macOS/Linux。具体：不用 `declare -A`（bash 3.2 不支持）；`sed -i.bak+rm`（非 `sed -i`）；`grep -E`（非 `-P`）；`date -u`（非 `-d`）；`$(cd+pwd)` 替代 `readlink -f`；`wc|xargs` 去空白；`$var中文` 须 `${var}` 防 C-locale 解析错误。详见 `references/security-spec.md` §六。

## 五层认知基底 + 执行准则

swarm-yuan 的 25 个门禁服务于一条认知递进链。核心理念：**呈现递进的关系，而非仅关注计算**。

| 层 | 解决什么 | 落点 |
|----|---------|------|
| 第一层 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） | 探查 + `--cognition` |
| 第二层 思维语言 | 如何思考（三元演化+三导向+七推理+7×7） | workflow + spec §14/§15 |
| 第三层 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） | workflow + check |
| 第四层 偏差防范 | 如何纠偏（五维偏差+思维模型 8 类） | spec §16 |
| 第五层 辩证认知 | 如何统一前四层（7 对辩证范畴） | spec §17 |
| 领域知识（贯穿五层） | 识别技术+业务领域，推导客观规律（防达克效应） | spec §18 + `--domain` |

**执行准则**：价值/目标/问题/结果四导向；质量优先>确保安全>兼顾效率>减少打扰>因地制宜；疑虑必确认（改只读/升级依赖/删稳定单元/多方案/安全冲突→暂停确认）。

> 完整框架详见 `references/cognition-framework.md`；逻辑剃刀+谬误图谱见 `references/logic-razor.md`；认知偏差+思维模型见 `references/cognitive-bias.md`；领域知识速查见 `references/domain-knowledge.md`。

## 生成流程（AI 自动执行，用户只需提供项目路径）

```
用户："为 /path/to/project 生成 skill"
  ↓ AI 自动执行（零手动配置）
⓪自检(10运行时) → ⓪.5读取项目知识(AGENTS.md/CLAUDE.md/记忆/hermes-agent) → ①探查仓库(三路并行+图谱工具) → ②提取14项特征卡 → ③create骨架 → ④AI填充全部文件 → ⑤AI配置precheck.conf → ⑤.5 AI生成hooks/commands/MCP集成 → ⑥AI运行门禁验证 → ⑦AI写回项目记忆(闭环)
```

1. **自检**：`bash scripts/self-check.sh`（10 个运行时检测+自动安装）
2. **读取项目知识**：AGENTS.md/CLAUDE.md/记忆/.zcode/hermes-agent → 提取规则写入特征卡（不读=重复造轮子）
3. **探查仓库**：三路并行子代理（结构/规范/代码组织），优先用 gitnexus/graphify/claude-mem/LSP，大型项目用 Dynamic Workflow 并行扇出。工具矩阵+降级策略见 `references/exploration-guide.md`
4. **特征卡**：14 项（项目类型→…→可复用稳定单元→领域知识），每项落到具体值不用占位符。映射表见 `references/template-spec.md` §3
5. **创建骨架**：`bash scripts/generate-skill.sh <name> <project-dir>`（含 hooks/ + commands/ 目录）
6. **AI 填充全部文件**：SKILL.md/codebase/dev-guide/release/reference-manual/workflow/snippets/mcp-tools。填充指引见 `references/template-spec.md`
7. **AI 配置 precheck.conf**：从特征卡推导 45 个变量（PROJECT_DIR/WRITABLE_DIRS/LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等）
8. **AI 集成 Claude Code**：生成 hooks/hooks.json + commands/ + settings.local.json + .mcp.json + workflow.md 节点标注。详见 `references/claude-code-capabilities.md`
9. **AI 运行门禁**：`precheck.sh --all`（核心 10）→ fail 自动修复重跑 → `--all-full`（全 25）
10. **AI 写回记忆**：claude-mem/.zcode/memories/.project-knowledge.md 三路写回，形成"记忆→生成→开发→记忆"闭环

> **铁律**：用户不编辑任何配置文件，不手动复制模板。开始新需求时对 AI 说"开始新需求 xxx"，AI 自动创建 spec 文件 + 引导填写 + 运行门禁。门禁误报 AI 自动调 conf 后重跑。每节点须有降级策略（联网/云端不可用→降级本地工具）。节点工具表+降级表见 `references/claude-code-capabilities.md` §十四。

## 六段式模板

生成的目标技能结构（六段式）：

| 段 | 文件 | 作用 |
|----|------|------|
| meta | `SKILL.md` | 元信息、铁律、流程总览、命令速查 |
| workflow | `references/workflow.md` | 节点化流程（9 要素/节点 + 4-Phase SOP）——生成时填充 |
| reference | `references/*.md` | 参考手册（目录/安全/编译/组件/接口/数据 + 方法论 + 认知 + 领域知识） |
| assets | `assets/*` | 模板（spec/plan/分支/环境/库表/状态机） |
| check | `scripts/precheck.sh` | 25 个门禁子命令 |
| scripts | `scripts/*` | 工具箱（门禁+状态机+图谱+MCP+self-check） |

## 它整合的方法论（只引用调用，不重新实现）

OpenSpec（spec-driven）/ superpowers（subagent-driven）/ comet（state machine）/ gstack+OCR（review）/ GitNexus+graphify（code-graph）/ gsd-core（phase-loop+goal-backward）/ claude-mem（memory persistence）。

> 工具引用铁律：只允许 `gitnexus` / `graphify` / `ocr` / `claude-mem` / `gsd-tools` 命令调用，不重新实现、不复制源码。

**reference 文件清单（按需读取）**：

| 用途 | 文件 |
|------|------|
| 探查指南（14 项特征卡 + 图谱工具） | `references/exploration-guide.md` |
| 六段式填充规范（生成后核对清单） | `references/template-spec.md` |
| 五层认知基底总览 | `references/cognition-framework.md` |
| 逻辑剃刀 + 谬误图谱 | `references/logic-razor.md` |
| 认知偏差 + 思维模型 | `references/cognitive-bias.md` |
| 领域知识速查（32 领域） | `references/domain-knowledge.md` |
| Claude Code 官方能力全量清单 | `references/claude-code-capabilities.md` |
| 安全规范（OWASP/STRIDE/CWE） | `references/security-spec.md` |
| subagent 编排模式 | `references/subagent-orchestration.md` |
| 代码审查方法论（5 维度） | `references/review-methodology.md` |
| 代码图谱工具引用 | `references/code-graph-tools.md` |
| gsd-core phase-loop/goal-backward | `references/gsd-patterns.md` |
| 跨会话记忆持久化 | `references/memory-persistence.md` |

## 使用说明

1. 确认目标项目路径与 skill 名称
2. `bash scripts/self-check.sh` 自检 10 项目运行时
3. 按需读 reference（探查→exploration-guide；填充→template-spec；方法论→各 reference 文件）
4. `scripts/generate-skill.sh <name> <project-dir>` 创建骨架（或 `--upgrade` 升级已有）
5. 按 5 步流程执行，每段落盘后用 `template-spec.md` 末尾核对表验证

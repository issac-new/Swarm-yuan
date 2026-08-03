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

**★核心能力（v2 增强）**：基于代码结构与调用链路分析，产出**详尽的组件库清单**（全量穷举，非代表性样本）与**编排调用关系及约束**（导入方向/注册顺序/路由挂载/状态所有权/测试边界，每条含代码证据），完善目标技能的研发 skill。方法论见 `references/exploration-guide.md` §C+。

**★核心能力（v3 左移）**：测试、变更影响、运维监控不等到测试/发布阶段才考虑，在 spec/plan 阶段就嵌入约束（spec §19 测试设计 + §20 变更影响 + §21 可观测性约束），编码阶段先测试后实现，合入前确认回滚预案，发布前确认灰度+告警+runbook。门禁 `--shift-left` 校验各阶段左移产出物。详见 `references/template-spec.md` §左移要求。

## 何时使用

- 用户输入 `/swarm-yuan <项目路径>`（slash command，详见 `.claude/commands/swarm-yuan.md`）
- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"
- 用户给了一个代码仓库，要求产出研发用 skill
- 用户要为「关节编排 / Articulated Orchestration」类汇报（如 AI 赋能研发、金融级清算核心交付）准备论据：swarm-yuan 的特征卡/门禁/verifier 可作为"凭什么可信"的机器执法兜底，落地案例映射见 `references/case-studies/articulation-orchestration.md`

**安装**：`bash install.sh`（自动检测运行环境 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi，安装到对应 skill 目录。详见 `install.sh --list`）

**不适用场景**（WP-P10 范式定位，详见 `docs/paradigm-positioning.md`）：
- 个人脚本/一次性原型/学习用 demo——建议直接用 AI 裸写，不套范式
- 极小改动（改 typo/调样式）——直接改，不走 spec 流程
- 无 AI 辅助的纯人工开发——范式设计为 AI 驱动，纯人工无法消费
- 替代方案：单文件 `precheck.sh` 做门禁不套生成器；或传统 lint/test 工具链

**不适用**：用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 三条铁律

1. **版本锁定**：不允许随意升级核心依赖版本（除非用户要求/安全漏洞/性能隐患/功能缺失）。`--deps` 检测。
2. **安全规范**：目标技能须遵守 OWASP Top 10 / STRIDE / CWE。`--security` 检测。详见 `references/security-spec.md`。
3. **三平台兼容（swarm-yuan 自身）**：swarm-yuan 生成器自身的脚本必须兼容 Windows/macOS/Linux（CI 全覆盖：ubuntu-latest + macos-latest + windows-latest）。Windows 上提供 `.bat` 包装器（`install.bat` / `generate-skill.bat` / `self-check.bat`）自动查找 Git Bash/WSL/MSYS2 运行对应 `.sh` 脚本（WSL 路径用 `/mnt/c/`，Git Bash 用 `/c/`）。bash 脚本兼容：不用 `declare -A`；`sed -i.bak+rm`；`grep -E`；`date -u`；`$(cd+pwd)` 替代 `readlink -f`；`wc|xargs`；`${var}` 防 C-locale。详见 `references/security-spec.md` §六。

## 五层认知框架 + 执行准则

swarm-yuan 的 54 个门禁服务于一条认知递进链。核心理念：**呈现递进的关系，而非仅关注计算**。

| 层 | 解决什么 | 落点 |
|----|---------|------|
| 第一层 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） | 探查 + `--cognition` |
| 第二层 思维语言 | 如何思考（三元演化+三导向[=四导向的 spec 落点子集，见执行准则]+七推理+7×7） | workflow + spec §14/§15 |
| 第三层 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） | workflow + check |
| 第四层 偏差防范 | 如何纠偏（五维偏差+思维模型 8 类） | spec §16 |
| 第五层 辩证认知 | 如何统一前四层（7 对辩证范畴） | spec §17 |
| 领域知识（贯穿五层） | 识别技术+业务领域，推导客观规律（防达克效应） | spec §18 + `--domain` |

**执行准则**：价值/目标/问题/结果四导向；质量优先>确保安全>兼顾效率>减少打扰>因地制宜；疑虑必确认（改只读/升级依赖/删稳定单元/多方案/安全冲突/架构变更/不确定意图→暂停确认）。

**AI 主导 + 用户决策原则**（G1 决策治理，对齐 ISO/IEC 42001 人工监督留痕）：所有环节均**优先以 AI 为主导生成建议项**，决策按**三级分类**（Mechanical 直接做 / Taste 给方案+推荐 / UserChallenge 必停五要素）治理，用户角色是**评估决策或修订后批准执行**。每条决策通过 `scripts/trace-log.sh --decision` 追加到 `.swarm-yuan/decisions.jsonl`（永不 fail 阻塞主流程）。详见 `references/decision-governance.md`（三级分类+五要素+七场景映射表+decisions.jsonl 格式）。

> 完整框架详见 `references/cognition-framework.md`；逻辑剃刀+谬误图谱见 `references/logic-razor.md`；认知偏差+思维模型见 `references/cognitive-bias.md`；领域知识速查见 `references/domain-knowledge.md`；决策治理（三级分类+五要素）见 `references/decision-governance.md`。

## 生成流程（AI 自动执行，用户只需提供项目路径）

**铁律：AI 必须执行完整流程（Step 0-8，含 5 个 .5 子步（⓪.5/①.5/④.5/⑤.5/⑦.5）共 13 节点（⑦.5 是 ⑥→⑦ 间的门禁注入子步，非独立节点；圆圈符号 14 个但 FACT_FLOW_STEPS=13 按独立节点计））后才算生成完成。不允许以 draft 骨架交付——骨架中的占位符必须全部被真实内容替换。生成完成时检查：目标技能中不得残留任何"待填充"/"填充指引"/占位符。**

**中断安全（状态门，决策 13）：流程可中断，但 draft ≠ 交付。** 骨架 frontmatter `status: draft` 期间，目标技能的 `--all-full`/`--compliance-suite` 被 precheck 机器禁用（exit 2）；中断后重跑 `generate-skill.sh` 同命令自动**断点续传**（幂等补齐缺失文件，不覆盖已有内容）；填充完成后 `bash scripts/generate-skill.sh --mark-active <skill_dir>`（零占位符核验通过才翻 `status: active`）才算生成完成。P1 特征卡项可「（P1 待补）」占位（WP-G），P0 六项必须填实。

**★调用追踪铁律（设计理念 2：全链路追踪）：生成流程与目标技能的使用流程中，每一步具体调用都必须有信息提示（无需用户确认），显示调用了何种工具及技能。** 双通道：① stdout 结构化公告——每 Step/节点开始时输出 `→ [Step N/节点X] 调用 <技能/子代理/工具> · <目的>`；② 落盘——**节点级默认**：每 Step/节点开始/结束时执行 `bash scripts/trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令>`，追加到 `<项目>/.swarm-yuan/trace.jsonl`；**调用级细节**（每个 CLI 工具/第三方调用的逐次落盘）仅在 `SWARM_YUAN_TRACE=verbose` 时启用（聚合分析见 `scripts/cost-report.sh`）。机器执法：`--verify-completeness` 校验目标技能的 workflow.md 每节点含「调用追踪」要素（template-spec §2 第 ⑨ 要素），缺则 exit 1。

**★核心铁律（详尽组件库清单 + 编排约束，按项目形态动态适配）：swarm-yuan 不预设项目是前端/后端/全栈/移动/桌面/库。** 必须先做 §C+.0 项目形态判定（探查文件类型/框架特征 → 判定含哪些维度），再按判定结果选择的维度做全量穷举 + 签名提取 + 计数核验（清单计数 ≥ 枚举计数 × 0.95）。特征卡第 15 项（编排调用关系及约束）必须从 §C+.2 按形态选择的链路模型（前端注册装配/后端请求管道/异步消息流/微服务跨服务链）推导得出，每条约束须有代码证据。两者配套：只列构件不推约束 = 未完成；维度错配（纯后端项目填 UI 组件表）= 未完成。

**★任务类型×方法论路由（借鉴 tanweai/pua methodology-router 改写，详见 `references/task-methodology-router.md`）：Step 0（开工）时按任务类型（新项目生成/框架规则注入/升级已有技能/合规审计/占位符修复/门禁fail修复/数字漂移修复/Oracle Gate循环）选择关键节点序列 + 门禁聚焦，避免所有任务都跑全量 13 节点。路由结果在 trace-log 公告：`→ [Step 0] 任务类型路由：X → 节点序列 Y → 门禁聚焦 Z`。**

```
用户："为 /path/to/project 生成 skill"
  ↓ AI 自动执行（零手动配置，不可中途停止）
⓪自检(13运行时) → ⓪.5读取项目知识(AGENTS.md/CLAUDE.md/记忆/agent运行时) → ①探查仓库(三路并行+图谱工具) → ①.5项目形态判定(§C+.0)+详尽组件库清单+调用链路分析(§C+.1-C+.5按维度动态适配) → ②提取17项特征卡 → ③create骨架 → ④AI填充全部文件(消除全部占位符) → ④.5框架深化(逐激活框架:按 references/frameworks/<fw>.md §1-§6 枚举+规律实例化+门禁清单对齐) → ⑤AI配置precheck.conf(消除全部占位符) → ⑤.5 AI生成hooks/commands/MCP集成 → ⑥AI运行门禁验证 → ⑦.5门禁注入(`scripts/generate-skill.sh --inject-frameworks` 将 assets/framework-gates/<fw>.sh 写入 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块；`--upgrade` 触发自动重注入) → ⑦AI写回项目记忆(闭环) → ⑧AI最终检查(零占位符+按维度计数核验+框架适配四要素核验)
```

> **Step 详解见 `references/generation-flow.md`（按需读取）**——上图为 13 节点总览，执行到对应 Step 时读该文件详解（含工具矩阵/降级策略/计数核验/框架四要素/Oracle Gate 循环等）。本节只列铁律：
> - 铁律 1：AI 必须执行完整流程（13 节点）后才算生成完成，不允许以 draft 骨架交付
> - 铁律 2：每步先公告调用（`→ [节点X] 调用 …`）+ `scripts/trace-log.sh` 节点级落盘 `.swarm-yuan/trace.jsonl`（`SWARM_YUAN_TRACE=verbose` 时含每次具体调用）
> - 铁律 3：门禁误报 AI 自动调 conf 后重跑；每节点须有降级策略（联网/云端不可用→降级本地工具，节点工具表+降级表见 `references/claude-code-capabilities.md` §十五）
> - 铁律 4：用户不编辑任何配置文件，不手动复制模板。开始新需求时对 AI 说"开始新需求 xxx"，AI 自动创建 spec + 引导填写 + 运行门禁

## 六段式模板

生成的目标技能结构（六段式）：

| 段 | 文件 | 作用 |
|----|------|------|
| meta | `SKILL.md` | 元信息、铁律、流程总览、命令速查 |
| workflow | `references/workflow.md` | 节点化流程（8 节点 × 每节点 10 要素，含★调用追踪 + 4-Phase SOP）——生成时填充 |
| reference | `references/*.md` | 参考手册（目录/安全/编译/**全量组件库**/**依赖链路+约束（按形态选模型）**/**全量接口端点**/**全量store+类型** + 数据 + 方法论 + 认知 + 领域知识） |
| reference | `references/framework-knowledge.md` | **按激活框架实例化的规律与门禁依据**（骨架由 AI 在 Step 4.5 框架深化阶段依据 `references/frameworks/<fw>.md` §3+§4 构建，逐条用项目代码验证实例化；`--inject-frameworks` 只注入门禁片段到 precheck.sh，不生成此文件骨架） |
| assets | `assets/*` | 模板（spec/plan/分支/环境/库表/状态机） |
| check | `scripts/precheck.sh` | 54 个门禁子命令（核心 10 + 架构 17 + 合规 17 + advisory-only 10：`--compliance` 标准合规矩阵核验 / `--docs-pack` 文档包清单 / `--sbom` SBOM 生成+许可证块名单 / `--privacy` 个人信息扫描 / `--authz` 授权类弱点 / `--requirements` 需求质量（29148）/ `--crypto` 密码算法合规（GB/T 39786）/ `--rtm` 需求追溯矩阵（29148 RTM）/ `--release-sign` 发布签名+provenance（SLSA L2 / SSDF PS.2）/ `--dengbao` 等保 2.0 控制点（GB/T 22239，fail-closed+豁免留痕）/ `--pia` 隐私影响评估（个保法 55-56，fail-closed）/ `--sast-deep` 深度 SAST（semgrep→opengrep→内置降级链）/ `--oss-eval` 开源代码安全评价（GB/T 43848，复用 --sbom 产物），随 `--all-full` 执行（标准 27：核心 10+架构 17）；合规 17 独立 `--compliance-suite` 按需执行，未配置静默跳过；另含 `--shift-left` 左移：测试设计/变更影响/可观测性） + **框架门禁片段注入区**（`# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块，由 `--inject-frameworks` 写入）。**门禁分层（决策 19）**：enforce 三档（strict/warn/advisory，按 fail() 数自动归类）与执行序列三档（core/standard/compliance）正交；enforce 档数字见 `assets/gate-enforce-level.conf`（`gen-enforce-level.sh` 自动生成）。模型只选"跑哪档执行序列"（`--all`/`--all-full`/`--compliance-suite`），enforce 是实现细节不对用户暴露。`--list-gates` 列执行序列三档 + 每门禁 enforce 属性。 |
| scripts | `scripts/*` | 工具箱（门禁+状态机+**调用追踪 trace-log.sh**+图谱+MCP+self-check） |

> **verifier 定位（诚实声明）**：`verifier/v1/`（仓库根，非 swarm-yuan/ 内）是验收驱动器，复用 `precheck.sh` 作引擎 + 独立 fixture（violating/compliant 双态）+ 独立 assertion 双层独立性，**非独立重实现**。`WP-P3 框架证据台账`：`scripts/framework-evidence.sh` 产出 TSV 供模型按需读，规律计数校验由 `verify-framework-ruleset.sh` 兜底。

## 它整合的方法论（只引用调用，不重新实现）

swarm-yuan 整合 13 个外部运行时，按**接线深度分三层**（每层有自带降级载体，不假装全深度接线）：

| 层 | 运行时 | 真实接线方式 | 降级载体 |
|----|--------|-------------|---------|
| **深度接线（4）** | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用（`gitnexus query`/`graphify explain`/`claude-mem search`/`ocr review`），带 `has_*` 守卫 + 多级降级链 | grep+madge / progress ledger / 5 维度手动清单 |
| **CLI 接线（4）** | OpenSpec / comet / gsd-core / codex-security | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`/`npx @openai/codex-security scan`），带 `has_*` 守卫，未装或项目未用时降级 | 自带文档检查 / 自带 state-machine.sh / ocr+手动清单 / semgrep+opengrep+内置词法 |
| **方法论引用（5）** | superpowers / gstack / ECC / Ruflo / impeccable | 作为方法论参考，AI 按 workflow 节点引用其模式（slash command 或文档指引）；swarm-yuan 自带等价降级载体 | 自带 subagent-orchestration.md / review-methodology.md / state-machine.sh / frontend-design-methodology.md |

OpenSpec（spec-driven）/ superpowers（subagent-driven）/ comet（state machine）/ gstack+OCR（review）/ graphify+GitNexus（code-graph）/ gsd-core（phase-loop+goal-backward）/ claude-mem（memory persistence）/ Ruflo（multi-agent swarm 编排）/ ECC（council 多声音认知扩展）/ impeccable（前端设计质量方法论）/ codex-security（语义级安全扫描 + 威胁模型 + 攻击路径分析）。

> **Palantir 理念映射吸收（决策 28/29，2026-07-31 R11 调研吸收）**：把 Palantir 工程哲学作为外部参照系审视 swarm-yuan 设计盲区（详见 `docs/research/R11-palantir-mapping.md`）。**决策 28** 标记沿调用链传播以方法论吸收（`--stable-diff` 传播 warn + 特征卡第 11 项 §11g 下游影响域 + G16 断言；Palantir "Mandatory controls propagate along lineage" 映射）。决策 29 三产物（语义/动能命名/组件标记驱动/FDE 反向传播）降为决策记录，见 `docs/paradigm-decisions.md`。

> **运行时升级整合吸收（决策 27）**：6 个运行时对齐最新稳定版后，概念以方法论吸收落地（不新增 `check_*` 门禁，守决策 26 预算）。吸收清单（gsd-core reversibility/broken-windows、superpowers 修复环/可证伪性、graphify honest-edge provenance、claude-mem version oracle、impeccable 前端设计方法论、context-engineering-layering、codex-security 语义级安全扫描）详见 `docs/runtime-update-2026-07.md` + 各 `references/<name>-methodology.md`。

> 工具引用铁律：深度+CLI 接线层（8 个）允许真实命令调用（`graphify`/`gitnexus`/`ocr`/`claude-mem`/`gsd-tools`/`openspec`/`comet`/`npx @openai/codex-security`），不重新实现、不复制源码；方法论引用层（5 个）只引用模式不调 CLI。**代码图谱工具按技术能力选型（GitNexus 深度调用图 / graphify 广谱知识图，平权可按项目并用），不做授权驱动的降级**（决策 18，详见 `references/code-graph-tools.md` §选型）。

**reference 文件清单（按需读取，35 文件 = 探查/填充/认知/方法论/合规/安全 6 类）**：

| 类别 | 文件（按需读） |
|------|--------------|
| 探查 | `exploration-guide.md`（17 项特征卡 + §C+ 组件库+调用链）、`code-graph-tools.md` |
| 填充 | `template-spec.md`（六段式填充规范+核对清单）、`claude-code-capabilities.md` |
| 认知 | `cognition-framework.md`、`logic-razor.md`、`cognitive-bias.md`、`domain-knowledge.md`（32 领域） |
| 方法论 | `decision-governance.md`、`governance-agents.md`、`subagent-orchestration.md`、`review-methodology.md`、`memory-persistence.md`、`gsd-patterns.md`、`task-methodology-router.md`、`frontend-design-methodology.md`、`context-engineering-layering.md`、`codex-security-methodology.md`、`mcp-governance.md`、`ai-process-records.md`、`canary-monitoring.md`、`generation-flow.md`（生成流程 Step 详解，决策 32 折叠） |
| 合规 | `standards-compliance.md`、`quality-management-standards.md`、`crypto-spec.md`、`industry-profile-{finance,medical,gov,automotive,energy,telecom,industrial}.md`（7 份）、`security-certification-profiles.md` |
| 安全 | `security-spec.md`、`cwe-database.md`（门禁内部数据）、`frameworks/`（74 框架规则库，按 ACTIVE_FRAMEWORKS 选读）、`case-studies/articulation-orchestration.md` |

> **注**：references/ 实际 35 文件（含 generation-flow.md）= 上表 33 + 门禁内部 2（`cwe-database.md`/`security-certification-profiles.md`）；`case-studies/` 子目录单独计，不在 35 内。落地案例（关节编排/Articulated Orchestration 类汇报论据，S18 补入索引）见 `references/case-studies/articulation-orchestration.md`。

## 使用说明

1. 确认目标项目路径与 skill 名称
2. `bash scripts/self-check.sh` 自检 13 项目运行时
3. 按需读 reference（探查→exploration-guide；填充→template-spec；方法论→各 reference 文件）
4. `scripts/generate-skill.sh <name> <project-dir>` 创建骨架（或 `--upgrade` 升级已有）
5. 按上方「生成流程」Step 0-8（13 节点）全量执行（铁律：不可中途停在骨架；每步先公告调用 + trace-log 落盘），每段落盘后用 `template-spec.md` 末尾核对表验证

# swarm-yuan 设计文档（终态完整版）

> **文档性质**：swarm-yuan 的**单一设计事实源**（single source of truth）。定位、理念、架构、规格、门禁、成长、决策原则、演化史、验收——全部设计决策在此文档结构化整合，不再散落。
> **版本**：v2（2026-08-21；v1 基于 R13 终态方案 v6 整理，v2 增 R14/R15 吸收条目 + §3.5 三层 Harness 总览 + §2.1 补第⑨条零手动配置 + 章节编号修正；历史文档标注降级为档案，见 §11）。
> **阅读方式**：先读 `docs/DESIGN-LOGIC.md`（设计本体论：自成长闭环流 + 四个正交坐标系 + 逐套层次语言的映射表——本文各章的每套层次语言都在映射表中有精确坐标）。全文自包含；按需深读用 §11 的证据与档案索引。

---

## 0. 文档元信息

### 0.1 本体与主线

swarm-yuan 的**本体是一条自成长闭环流**：代码仓库 →① 生成段（探查+装配）→② 产物段（目标技能，出口受税制预算门约束）→③ 使用段（AI 按需 grep 地图做拼装式开发，行为被条件实时拦截）→④ 账本段（全量留痕）→⑤ 回流段（审计+评测校验体系自身，改进写回生成器与技能）。**自成长不是特性，是闭环流的闭合条件**——砍掉回流边即退化为一次性脚手架生成器。

各章使用的每套层次语言（两体系统/税制/三层 Harness/三层接线/五层树/九条内核……）都是这条流在四个正交坐标系（时间轴/产物轴/校验轴/边界轴）上的观测——精确映射见 `docs/DESIGN-LOGIC.md` §三映射表，本文引用时不再重复解释坐标。

### 0.2 问题定义（五轮诊断从未动摇的内核）

**AI 编程工具的短板不在代码生成能力，而在项目认知。** 同行（spec-kit/BMAD/SuperClaude）只做 spec 生成或 prompt 工程；"质量门禁的规模化强制"是 swarm-yuan 的目标域。

**拼装式开发是应用层目的**（奠基期用户原话，sess_4782d626 2026-07-03）：认知不是为了看懂项目，是为了**基于稳定可靠的组件进行拼装式开发**——尽可能复用项目既存的接口/组件/类/函数/方法等稳定单元，规避破坏性改造、重复造轮子、浸入式重构。这是特征卡第 11 项"可复用稳定单元清单"与地图"稳定性标注"的存在理由：探查产出 = AI 拼装时的零件目录。

### 0.3 文档边界

- 本文件 = **设计层**（为什么这样做、做什么、做到什么程度算对）
- `swarm-yuan/references/` = **方法论层**（怎么做的细节指引，40 份全带"何时读我"路由头，按需读取）
- `docs/research/` = **证据与调研史**（R1-R13 调研报告，留档不删）
- 运行时机制（脚本/门禁/hook）不在本文档详述——它们的**设计规格**在 §4-§8，实现在仓库代码。

## 1. 定位与适用域

### 1.1 范式定位一句话

**swarm-yuan 是"生成器厚、生成物薄"的两体系统**——生成时刻允许厚（探查知识全量，一次性消费），生成物必须薄到近乎无形（每会话固定税 ≤8KB、概念体系 ≤5）。重量在生成器侧是投资，在生成物侧是税——税制有机器预算。

### 1.2 适用 / 不适用

| 适用 | 档位 | 不适用 | 替代 |
|------|------|--------|------|
| 团队协作（≥2 人） | standard | 个人脚本/一次性原型 | AI 裸写 |
| 中大型（≥80 文件） | standard | 极小改动（typo） | 直接改 |
| 强监管/合规交付 | compliance | 无 AI 辅助的纯人工开发 | 传统 lint/test |
| 长期维护（技能须跟项目演进） | 任意档 | 只要门禁不要认知设施 | 单文件 precheck.sh |
| 小项目要基础门禁 | lite | | |

### 1.3 与历史定位的差异（诚实记录）

2026-07（WP-P10）定位是"重量级范式，重量是设计选择"——那是真实，也是五轮"过重"诊断反复追问的对象。R13（2026-08-21）后修正为两体系统：**重量没有消失，只是归位**——生成器侧 ~68K 行自举仍在（一次性消费不算税），生成物侧 ~25 文件、概念负担从 150+ 记忆槽降到 5 个层次名词。

**起源（ncwk 孵育史，2026-07）**：swarm-yuan 诞生于 ncwk 项目工作区——2026-07-02 用户首次提出"根据材料模板生成 skill"（sess_b55848b0），原始需求一句话：为具体项目生成供研发人员开发使用的 skill、完成需求交付全流程；同日澄清分层——swarm-yuan 是 Skill A（元技能生成器），ncwk-dev（后改名 Swarm-studio）只是 Skill B（第一个示例产物）。2026-07-03 首次推送 issac-new/Swarm-yuan（68b609c）；2026-07-21 独立 project 开始主会话。**与 hermes-studio 的关系**：hermes-studio 是 ncwk 的第三方上游依赖（EKKOLearnAI/hermes-studio），swarm-yuan 诞生于 ncwk 但与其无代码依赖、无命名同义、无组件包含关系——swarm-yuan 是独立仓库本体。

## 2. 设计理念

### 2.1 稳定内核（九条，五轮从未动摇；第⑨条为 ncwk 奠基期深挖补录）

① 元技能生成器定位 + 六段式产物结构；② "AI 短板在项目认知不在代码生成"；③ 零占位符铁律 + draft/active 状态门；④ 单文件 precheck 可移植；⑤ 三层接线 + 降级链 + 调用不重实现；⑥ 自适应轻重（质量优先于效率）；⑦ facts.conf 单一事实源；⑧ "账面与实质一致"三层诚实化（数字/修辞/证据）；⑨ **AI 全自动、零手动配置**（奠基期铁律，sess_4782d626/sess_d466cc75 反复强化）：生成 skill 是 AI 一键完成（探查→填充→配置→验证全自动）；skill 使用时研发人员对 AI 说话而非手动跑命令——SKILL.md 是 AI 读的（写"零手动"铁律），USAGE 层保留 bash 双轨制（排查/CI/脚本场景需要）；安装的一次性 `cp -r` 不属于"日常使用"，允许手动。

### 2.2 R13 新增两条理念

**范式作为条件，而非内容**：机制分两类——**条件**（运行时约束行为、零认知占用、糊弄结构上不可能）与**内容**（要 AI 先读先记再自觉、每会话重复付税、糊弄结构上必然）。机器执法只保留"防 AI 说谎"的条件类；"给理解打分"与"防文档数字漂移"的内容类退役或转落地化。AI 的理解深度由行为证据兜底（测试过没过/门禁红不红/决策留没留痕），不由表格验证。

**落地优先于删除**：概念/门禁/profile/references 一概不删——病根是"没有正确落地"（机械打分/僵尸孤立/无路由），全部转为真实消费路径：概念→AI 判断引导+留痕；僵尸门禁→全接线；孤立 profile→conf-render 真实加载；无路由文档→"何时读我"路由头。

### 2.3 失败方向教义（条件类的补充原则）

权限边界一律 fail-closed（默认全拒、白名单放行）；**fail-open 只允许发生在还有下层强制兜底的地方**（如 hooks 失败不阻断，因命令还要过门禁；规则文件解析失败退最小规则集）。每个 SKIP/降级路径按此逐处复核。

### 2.4 对外叙事边界（祛魅红线，sess_fcc61435 外部评审校准）

对外讲 swarm-yuan 的不可逾越红线（外部评审曾点破浮夸风险——"内核合理的方案被过度营销语言包装"）：
1. **"100% 可靠"禁用**——verifier/v2 外部有效性未达成前，对外禁用 100%；用"已验证组件 + 受约束生成 + 独立校验"三段式。
2. **"10⁻¹⁰"标注**——使用方推演模型非工具输出；引用必须带出处说明。
3. **具体数字归属**——"103 组件"是某目标项目的枚举产物非 skill 硬数字；"90% 采纳率"若源自计划表必须标"计划口径"。
4. **"三权分立"**——是叙事隐喻，真实拓扑按治理 agent 实际；对外用时标注。
5. **本质表述**——swarm-yuan = **bash 脚本 + Markdown 挂在 AI 编码助手 hooks 上**（写代码前拦截、交差时独立验证）+ 本地观测；不是纯 PPT 工程，也不是集群平台。

### 2.5 平台分工教义

harness（宿主 CLI：Codex/Claude Code）管 agent loop/沙箱/审批通道；**应用侧（swarm-yuan 生成物）管项目上下文、业务规则、操作边界**。生成物不碰 harness 内部（会话管理/审批实现/OS 沙箱），只做应用侧资产（地图/规则/hooks 注册）。token 纪律即能力（官方实测 ARC-AGI-3 上下文纪律 13.3%→38.3%）——生成物每字节税稀释有效上下文占比，直接降能力。

## 3. 终态架构

### 3.1 两体系统总览

```
厚生成器（一次性消费，可厚）          薄生成物（每会话重复消费，必须薄）
  探查知识库（74 框架规则/40 references）   SKILL.md（≤8KB：何时用/约束摘要/入口/路由/元规则/自成长）
  行业 profile（7 份，conf-render 真实加载）  地图（≤32KiB：两列表 |路径|说明与约束|）
  探查/渲染/自检脚本                     spec 9 节核心 + workflow 8 节点×4 要素
  决策史/调研史（docs/）                 rules.d/*.rules + precheck + hooks（双宿主）
                                      scripts（按需调用的工具，不算税）
```

### 3.2 生成物文件级规格

```
<skill-name>/
├── SKILL.md          # ≤8KB 预算（FACT_SKILLMD_BYTES_BUDGET=8192 断言）
├── references/
│   ├── map.md        # 项目地图：两列 |路径|说明与约束|；32KiB 硬顶；stability 词在说明列
│   ├── spec-template.md  # 9 节核心必填（需求/决策记录/约束/测试/回滚/左移三节/合规）；仪式节 --task-type full 展开
│   ├── workflow.md   # 8 节点 × 4 要素（入口/参与方/门禁/产出物——追踪并入产出物）
│   └── （激活框架文档 + 任务路由命中的方法论文档，按需拷贝）
├── scripts/          # precheck.sh + gates + gate-rules.sh + inventory-verify/update + fingerprint + trace-log + state-machine
├── rules.d/          # *.rules 三值规则数据（allow/prompt/forbid，生成器产出+审批沉淀）
├── hooks/hooks.json  # 双宿主渲染：Claude Code（deny JSON）/ Codex（exit 2 经 codex-gate-wrapper）
└── settings.local.json  # 最小权限 + 沙箱通配符 deny（Read(**/.env) 等）
```

**读者双轨制**（奠基期 sess_4782d626 澄清）：SKILL.md 的读者是 **AI**（写"零手动配置"铁律——AI 自动探查/填充/配置/验证）；USAGE 文档的读者是**研发人员**（保留 bash 命令 + "对 AI 说"并存——排查/CI/脚本场景需要）。安装的一次性 `cp -r` 不属于日常使用，允许手动。

### 3.3 结构性保障（层依赖显式单向）

五层一棵树：生成 → 探查（产地图）/ 约束（rules.d+precheck+hooks）/ 演化（fingerprint+inventory-update）/ 留痕（trace+decisions）。单向边由目录物理隔离承载：references/ 不 import scripts/（self-check G19 反向引用=0 断言）；每层唯一入口命令；分层失败隔离（地图坏不影响约束；rules.d 缺失降级最小规则集）。

### 3.4 兄弟工具与装配关系（外部系统边界澄清）

swarm-yuan 独立运行（纯 bash+Markdown，不依赖任何宿主集群），但本机与其他三个工具并存且**不共享代码、不共享运行时**：

```
[分布式调度层]  Hermes Agent 集群（~/.hermes，profiles/teams/kanban 驱动）
     ↓ ACP 委托
[编码执行层]    Claude Code / Codex（在 worktree 写代码）
     ↓ 读规范
[项目规范层]    swarm-yuan（为每个目标项目生成专属 SKILL.md + 门禁）
     ↓ 观测/回传
[观测/协作层]   SwarmStudio（Electron 桌面，观测 Hermes 集群，与 swarm-yuan 无代码耦合）
```

- **hermes-studio**：ncwk 的第三方上游（EKKOLearnAI/hermes-studio），swarm-yuan 与其无代码依赖、无命名同义、无组件包含——ncwk 是 swarm-yuan 的诞生地（§1.3 起源段），不是宿主。
- **SwarmStudio**：ncwk 的对外公开应用（overlay 二次开发层），swarm-yuan 曾为其生成 ncwk-dev skill（dogfood 关系：ncwk 是 swarm-yuan 的一个目标项目）。
- 在金融级汇报场景里，四者被装配为"三套系统闭环"叙事（调度/编码/规范）——但那是**叙事层的组合**，不是架构层的依赖。

### 3.5 三层 Harness 总览（过程强制 + 工作流审计 + 评测）

| 层 | 职责 | 核心机制 | 落地版本 |
|----|------|----------|---------|
| 过程强制门禁层 | 开发过程中实时拦截违规 | 门禁四族（真值见 facts.conf）54/54 可达 + rules.d 三值（allow/prompt/forbid 取最严，FORBID 带替代）+ hooks 双宿主（Claude deny JSON / Codex exit 2）+ 沙箱通配符 deny | v2.0（R13） |
| 工作流审计层 | 事后复盘"工作流是否可信" | goal_id+closure（审计单元=一个用户目标+一个验收边界）+ 证据态分级（Present/Wired/Exercised/Outcome-supported）+ 双账本（当窗验证 vs 跨窗效果）+ repair_review | v2.2（R14） |
| 评测层 | 评测自身的可信度 | ref_trace_hash（三本账链式锚定，上游篡改全链 stale）+ missing_evidence（该测没测）+ gate-plan（选择即证据，负空间可审计）+ audit-closure（审计即完成条件） | v2.3（R15） |

三层关系：门禁层做事中拦截（条件），审计层做事后复盘（证据），评测层做评测自身可信（元证据）——每层消费下层的账本（gate-runs → goal 聚合 → 链式锚定），互补不竞争。

### 3.6 概念体系收敛

只允许 5 个层次名词为主轴：**探查 / 约束 / 演化 / 留痕 / 生成**。认知框架类概念（六阶链/六维动力学/三元演化/七推理/辩证范畴/五维偏差/思维模型）不删除不堆砌——以"工作时按此思考"的指引式表述融入对应层次，落地为 AI 判断引导（逐维自查 → `.swarm-yuan/notes/` 留痕，GATE_AI_JUDGMENT 唯一模式）。

## 4. 探查设计（认知层）

- **形态判定先行**（§C+.0）：backend/frontend/async/desktop/mobile/lib/common，维度适配由 `inventory-dimensions.conf` 承载；不预设项目类型。
- **全量穷举 + 计数核验**：组件清单 ≥ 枚举计数 × 0.95；`--path-check` 杀幻觉路径（HALLUCINATION 阻断 mark-active）；`--stability-audit` 三机械信号（git churn/fan-in/测试存在性）与标注冲突 → STABILITY_WARN（advisory）。
  > **实证来源（sess_733ff1c4, 2026-07-11）**：ncwk-dev 初版只列 10 个组件，真实代码库有 99 .vue + 8 store + 12 adapter + 17 loop 模块——样本化填充仅 10% 覆盖。0.95 红线由此定：强制穷举 + 三层调用链（注册装配/模块依赖矩阵/组件挂载树）+ 编排约束 6 类（导入方向/注册顺序/路由挂载/文件落位/状态所有权/测试边界，每条须代码证据）+ 接口全量枚举禁通配符。
- **两维表规范**：地图行 = `| 路径 | 说明与约束 |`。路径反引号包裹（path-check 校验存在性）；说明列写"它是什么+接口/约束+稳定性标注词"（"导出 add（禁止改）"——stability-audit 按行内字面词识别，与列位置无关）。维度/来源等纯记账列已退役（R13）。
- **特征卡**：P0 六项强制 / P1 十一项可增量（draft 期「（P1 待补）」允许，mark-active 前清零）；探查期产出，受检不自证。

## 5. 约束设计（门禁层）

### 5.1 门禁族与可达率

54 门禁（FACT_GATES_TOTAL，真值对账）= 核心 10 + 架构 17 + 合规 17 + advisory 10。**全部有真实触发路径（54/54 可达）**：cert/cwe-audit→compliance 序列、decision/state-phase→full 序列、upstream-baseline→precheck 启动、operate/pr-quality/supply-chain→PostToolUse、decision-audit/learnings→Stop hook、state-phase→SessionStart、loop-oracle→loop-hook。enforce 分层（strict/warn/advisory）是实现细节，模型只选执行序列（`--all`/`--all-full`/`--compliance-suite`）。

### 5.2 三值规则引擎（Codex Decision 架构 bash 落地）

- **规则即数据**：`rules.d/*.rules` 行格式 `<pattern(glob)> → <allow|prompt|forbid> # <justification>`；求值器 `scripts/gate-rules.sh`（多规则命中取最严 forbid > prompt > allow）；仓库零内置规则——项目规则由探查期生成 + 审批沉淀写入。
- **三值作用域**：只作用于"命令该不该跑"的判定（Bash 命令放行，那里有宿主审批通道）；门禁家族不重分类。
- **拒绝消息 = 给模型的 API**：`FORBID <rule-id>: <原因>；替代：<方案>`——拒绝携带替代方案，AI 能自动改道。
- **自指防护**：integrity-guard deny 保护 facts/trace/规则自身不被 AI 篡改（执行前哈希自校验）。
- **审批沉淀**：GATE_ENFORCE_DENY 临时放行可持久化为规则（写回 rules.d + justification + 日期 + decisions.jsonl 落痕——R14 起含 goal_id/closure/repair_review，R15 起含 ref_trace_hash 链式锚定）。

### 5.3 宿主下沉（双宿主真实拦截）

- **Claude Code**：fail-gate-hook（PreToolUse deny JSON + PostToolUse flag 捕获）+ settings.local.json 沙箱通配符 deny（`Read(**/.env)` 等，v2.1.236 防重命名绕过）。
- **Codex**：hooks.json PreToolUse → `codex-gate-wrapper.sh`（JSON deny 解析 → **exit 2 + stderr 透传**，v0.148 官方语义）。
- hooks fail-open 的合法性：有下层门禁兜底（§2.3 教义）。

### 5.4 conf 面收缩

物理变量 176 保留（兼容既有生成物）；**user 面必配 ≈ 20 项**（开关/路径/预算，`FACT_CONF_VARS_USERFACE=20`）——43 个框架 glob 阈值已迁 `rules.d/framework-globs.rules`（数据快照，conf 同名可覆盖）；行为参数留在模板/脚本内（Codex skills 全局配置仅 4 键的同构）。

## 6. 演化设计（成长层）

- **生成物自成长链**：fingerprint 感知（SessionStart/手动 --diff）→ 变化目录 scope 报告（局部重探查，不整仓重扫）→ inventory-update 单条更新（replace/delete/append §4/§6/§9，原子替换 + 决策落痕）→ last-good 红线（文件数骤降 >50% 拒绝 --write，需 --force）→ `--commit-fp` 落新基线。新增闭环：局部重探查产出的新组件自动进地图（探查即入账）。
- **生成器成长通道**：吸收一律走"调研报告（docs/research/）→ 三问评审 → 落地为条件/路由/引导之一"（phase=absorption 留痕 decisions.jsonl）；上游重核从全量改为破坏性变更驱动（breaking/major 触发 + 季度例行）。
- **成长的预算约束**：成长 = 预算内替换（新知识进来必须有旧知识出去或税不增），否则只是膨胀。

## 7. 留痕设计（追踪层）

- **trace.jsonl**：节点级调用落盘（stdout 公告 `→ [节点X] 调用 …` + `trace-log.sh --node/--key-node/--decision`）；永不 fail 阻塞主流程。
- **decisions.jsonl**：G1 决策治理（三级分类 Mechanical/Taste/UserChallenge + outcome 生命周期 proposed/implemented/rejected/superseded + 未采纳决策照常落盘 + 回放规则不可变——旧行无 outcome 视 implemented）。R14 增 `goal_id`+`closure`（审计单元目标闭环化：一个用户目标+一个验收边界，change↔validation 链接才 closed）+ `repair_review`（修复复核位：verified/partial/blocked，空=pending）。
- **gate-audit.jsonl**：fail-gate 全量决策审计（invoked/result 单行自包含 + 稳定 handler id + target 截断 500 + 休眠不写）；`--report` 四段（最近决策/拦截率按 handler/deny 聚合/工具分布）。R14：gate-report 增证据态分级（配置≠使用≠有效：Present/Wired/Exercised/Outcome-supported）；gate-trends 双账本（当窗验证 repair_verified_rate + guardrail 配对 vs 跨窗效果 Loop Effectiveness——后者需两次执行对比，诚实声明登记候选）。
- **key-nodes.jsonl**：八节点关键调用看板。
- **gate-plan.json**（R15 评测层）：任务开工的门禁选择声明（enable/skip + 理由，负空间可审计）；`scripts/gate-plan.sh --plan/--diff` 收口对比计划 vs 实际触发（missing_evidence/计划外/skip 违反，advisory）。
- **decisions.jsonl `ref_trace_hash`**（R15 评测层）：decisions 记录引用 trace.jsonl 末行 cksum——三本账从并列升级为**链式**（上游篡改 → 失配 → 全链 stale 可检出；HarnessEval evidence tree 的 bash 最小切片）。
- **audit-closure 完备性**（R15 评测层）：`scripts/audit-closure.sh` 按 goal_id 全集重走 closure 完备性（open/closed 分布 + open goals 列表）；`--strict` 有 open 时 exit 2，串 mark-active advisory 门（审计即完成条件）。

## 8. spec 设计规则（生成物模板规范）

- **spec-template 9 节核心必填**：背景与目标 / 决策记录 / 复用·版本·安全三约束 / 测试策略 / 风险与回滚 / 左移三节（§19 测试设计/§20 变更影响/§21 可观测性） / 标准合规。其余节（详细设计/分层设计/参考/§14-18 认知仪式/运营）**默认折叠**——`--task-type full` 的复杂变更才展开。
- **workflow 4 要素**：入口（顺序/并行）/ 参与方 / 质量门禁 / 产出物与追踪（含 trace-log 调用）；原 10 要素中分支/流程控制/状态控制并入产出物说明。
- **生成后核对清单 12 项**：机器验证四件套（零占位符/path-check/计数覆盖/mark-active）+ P0 核心映射八项；历史 96 项细目在折叠区保留为方法论参考（非 mark-active 前置）。
- **plan-template**：任务条目须含完成判据（test/命令/可观察结果/交付物——"Implement the thing"不算计划）。

## 9. 决策原则与演化史

### 9.1 防复胖四制度（生成器侧条件）

1. **概念落地问责**：新概念进 SKILL.md/生成物必须给出落地路径（接线/AI 判断引导/路由，不接受"先放着"）。
2. **吸收三问**：①能否落到运行时条件？②替换还是叠加？③六个月后谁引用？——不过只留调研报告，不进 references。
3. **生成物税制**：进 UNIVERSAL_FILES 的审核问题 = "目标 AI 每会话为它付多少税"；机器载体 = 体积/字节预算断言。
4. **五维复审**：季度跑 §10 指标 8-12（结构/连接/有效/适配/成长），与 gate-trends 季度报告合并，不新增例程。

### 9.2 决策史索引

- **奠基期（ncwk，2026-07-02 ~ 07-19，决策 0 域）**：特征卡 9→12→13→14→16 项演化（12 项=用户首次明确"全部 12 项"；13/14=+认知基底/辩证范畴；15/16=+编排约束/详尽组件库清单——为修复"样本化填充 10% 覆盖"缺陷专门加入）；"左移"三节由用户一句话加入（2026-07-11）；三平台兼容硬约束由"脚本在 Windows 下不可用"触发（_resolve_path 可移植函数 + .bat 包装器全覆盖）；框架规则引擎方案 A 选型（内置框架库+门禁片段+生成时注入，2026-07-17，详见 `docs/2026-07-17-framework-rules-engine-design.md`；ncwk-dev 手写的 7 框架 28 项检查反向收割为片段库种子——从成功实践反哺范式库）；skill 上传四项规则（脱敏/路径泛化/去内部代号/推送前确认，首次发布确立）；运行时管理规则（research/ 仓库永远 checkout 最新 stable release tag，detached HEAD，永不 push）
- **决策 1-17**（早期，2026-07-20 后）：`docs/paradigm-decisions-archive.md`
- **决策 18-29**（自适应/诚实化/Palantir 期）：`docs/paradigm-decisions.md` 前部
- **决策 30-32**（自适应偏置/门禁分层/上下文压缩）：同上
- **决策 33**（范式作为条件而非内容——R13 去抽象化重构与落地优先原则）：同上
- **决策 34**（概念落地问责 + 吸收三问 + 生成物税制——防复胖三制度）：同上
- **R14 吸收**（阿里云 Qoder Better Harness，2026-08-21）：审计/复盘/趋势三层机制落地——审计单元目标闭环化（decisions.jsonl 增 goal_id+closure）、证据态分级（gate-report §4.2：Present/Wired/Exercised/Outcome-supported + 分数上限）、双账本（gate-trends：Repair Progress 当窗验证 + guardrail 配对指标）、修复复核位（decisions.jsonl 增 repair_review）。与过程强制层（门禁）互补不竞争。详见 `docs/research/R14-better-harness-absorption.md`。
- **R15 吸收**（MirroS HarnessEval，2026-08-21）：评测层 Harness 落地——digest 链式锚定（decisions.jsonl 增 ref_trace_hash：三本账从并列升级为链式，上游篡改全链 stale 可检出）、missing_evidence 态（gate-report 证据态加"该测没测"≤59）、gate-plan 选择即证据（`scripts/gate-plan.sh`：启用/跳过理由负空间可审计，收口 diff 计划 vs 实际触发）、audit-closure 审计即完成条件（`scripts/audit-closure.sh`：goal 闭环完备性重走，串 mark-active advisory 门）。三层 Harness 拼图完整：过程强制门禁层（R13 前）+ 工作流审计层（R14）+ 评测层（R15）。详见 `docs/research/R15-harnesseval-absorption.md`。

演化模式定型为"吸收→膨胀→诊断→减重"五轮循环；R13 是第一个以落地化（而非加法治理）收口的循环。

### 9.3 吸收边界（明确不做）

OS 沙箱（宿主职责，吸收决策架构不复制实现）/ Guardian LLM 分类器（bash 层不建，只留形态约定）/ Starlark 解释器（行格式规则即可）/ 会话 SQLite 投影（trace.jsonl 够用）/ 迁移工具（手工升级一次）/ harness 内部（exec/SDK/app-server 是宿主集成层）。

## 10. 验收与复审

| # | 指标 | 终态 | 度量方式 |
|---|------|------|----------|
| 1 | 每会话固定税（SKILL.md+hooks+settings+conf） | ≤8KB | self-check 断言 |
| 2 | 生成物概念体系 | ≤5 | 人工评审 |
| 3 | 冷启动到读项目代码动作数 | ≤3 步 | 定义：mark-active 后新会话到首个 Read/Grep 项目源码 |
| 4 | 门禁可达率 | 100%（54/54） | 默认执行序列可触达 / FACT_GATES_TOTAL |
| 5 | 地图预算 | 32KiB 硬顶 | self-check 断言 |
| 6 | description ≤1024 字符 / SKILL.md 正文 ≤8KB | 达标 | self-check 断言 |
| 7 | 认知面体积（references 拷贝） | ≤256KB | self-check 断言（当前 252KB） |
| 8 | 结构性：反向引用数 | 0 | G19 断言 |
| 9 | 连接性：孤儿资产数 | 0 | G18 扫描 |
| 10 | 有效性：恒零拦截门禁 | 季度质疑清单 | gate-trends |
| 11 | 适配性：三档差异化 | gen-e2e 断言（lite 无 hooks.json / compliance 含 industry 注入） | gen-e2e |
| 12 | 成长性：吸收落地率 | 100%（decisions.jsonl phase=absorption） | decision-audit 抽样 |

治理节奏：批次之间至少间隔一个真实使用周期（用当前形态生成真实项目技能验证后再进下一批）——慢本身就是防复胖。

## 11. 档案与证据索引

**历史设计文档**（内容已并入本文件，原文降级为档案，保留不删——查历史演变用）：
- `docs/paradigm-positioning.md`（v2 定位，并入 §1）
- `docs/design-philosophy-consistency.md`（理念一致性，并入 §2/§9）
- `docs/2026-07-17-framework-rules-engine-design.md` / `2026-07-20-*`（历史专题设计）
- `docs/q2-heavy-review.md`（机械 vs AI 边界复盘）

**决策史原文**：`docs/paradigm-decisions.md`（18-34）+ `docs/paradigm-decisions-archive.md`（1-17）——本文件 §9.2 是索引，原文是详情。

**调研证据**：`docs/research/`（R1-R13；R13 三份：final-plan 方案 v6 / codex-deep-dive Codex 源码证据 / de-abstraction 复盘草稿）——调研报告是证据的合法归宿，不晋升 references（吸收三问）。

**运行时文档**：`swarm-yuan/references/`（40 份，全部带"何时读我"路由头）——方法论细节按需读取，本文件不再复制其内容。

**对外案例**：`swarm-yuan/references/case-studies/articulation-orchestration.md`（关节编排对外汇报的论点→能力映射）；temppt 四个会话（PPT V41→V81 迭代史 + sess_fcc61435 外部评审祛魅记录）是 §2.4 对外叙事红线的来源。

**已知边界**（登记待修，非设计内容）：`detect-profile-drift.sh` 在 worktree 场景的路径推导误报（把 worktree 内 README 副本误判为目标项目升档信号）——main 分支无此问题，worktree 内跑 self-check 时可能出现"假漂移"；处置候选：识别自身处于 swarm-yuan 仓 worktree 时跳过，或拆分"扫描目标项目"与"扫描自身"两命令。

---

> **修订纪律**：本文件是单一设计事实源——新设计决策追加到对应章节（或 §9 决策史索引新增条目），不再新建散落设计文档；references/ 的运行时指引继续按需维护在各文件内。任何"数字/计数"表述引用 `assets/facts.conf` 真值，本文不内联（R13：不手抄即无漂移）。

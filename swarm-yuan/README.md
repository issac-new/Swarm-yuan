# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。

[![Release](https://img.shields.io/badge/release-v2.6.1-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6.1)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 全文骨架

> 本文是 swarm-yuan 的**终态设计文档**：只描述系统**现在是什么**与**为什么这样设计**。单一事实源。
>
> **主旨一句话**：让 AI 先懂项目再写代码——用"特征卡立法 + 门禁执法"把项目认知变成可机器校验的契约。

**文档边界（本文件只含设计内核）**：过程性内容已物化移出——
- 决策史全文 + 历史档案 A1-A14（演化过程、WP/批次/轮次施工记录）→ `docs/design-evolution.md`
- 使用手册 + 术语边界（操作层）→ `docs/usage-manual.md`
- 上游运行时基线登记表（16 行供应链机器锚）→ `docs/upstream-baseline.md`

**阅读顺序**：§1 理念 → §2 原则（含决策要点）→ §3 架构 → §4 机制 → §5 使用 → §6 本体论（深读）→ §7 验收。改设计前先读 §2 决策要点——每条原则背后都有决策编号可溯源。

# 设计内核

> 以下七章是 swarm-yuan 的全部设计定稿。

## §1 理念与定位

> 判断：AI 编码的瓶颈已从"会不会写"转为"懂不懂项目"。本章确立系统存在的根本理由与五条执政理念——它们是全文一切机制的立法依据。

### 1.1 问题：AI 写代码很强，认识项目很弱

AI 的代码生成能力已经很强，但「项目认知」仍是被多数工具忽视的环节——改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子、检查靠人工逐行 review。缺陷不在生成，在认知：AI 不认识你的项目就动手。

### 1.2 核心理念

**先认识，再行动。** AI 写代码前必须先认识项目——认知不是看懂代码，是为了让行动有依据。由此派生五条执政理念：

1. **拼装式开发**——新功能 = 既有稳定单元拼装 + 最小新增胶水。禁止重复造轮子、侵入式重构、破坏性改造。这是整个系统存在的应用层目的：探查产出的"可复用稳定单元清单"就是 AI 拼装时的零件目录。
2. **特征卡是立法，门禁是执法，验证器是司法**——特征卡定义「项目应该是什么样的」，门禁验证「代码是否符合」，独立验证器用 fixture 双态 + 字节级等价证明门禁本身有效。三权分立，互不越界。
3. **诚实降级**——运行时未装不阻塞（fail-open + 降级链），但降级必须显式披露，不假装全深度接线；权限边界一律 fail-closed。
4. **呈现递进的关系**——门禁不是"数 import 数"，每个计数背后指向一条关系规律；认知呈现的是结构关系而非符号堆。
5. **AI 全自动、零手动配置**——生成技能是 AI 一键完成；使用时研发人员对 AI 说话而非手动跑命令。

### 1.3 理念的自证要求

范式声称帮项目降复杂度，因此自身的复杂度必须有上限（负向预算，见 2.4）；范式声称门禁有效，因此必须被独立验证（司法层，见 4.5）；范式声称认知项目，因此认知结果必须落到真实路径与版本号、可机器核验（见 4.1）。**每条理念都要求一个可验证的兑现机制**——这是下一层（设计）的任务。

---

### 1.4 定位与适用域
#### 1.4.1 范式定位一句话

**swarm-yuan 是"生成器厚、生成物薄"的两体系统**——生成时刻允许厚（探查知识全量，一次性消费），生成物必须薄到近乎无形（每会话固定税 ≤8KB、概念体系 ≤5）。重量在生成器侧是投资，在生成物侧是税——税制有机器预算。

#### 1.4.2 适用 / 不适用

| 适用 | 档位 | 不适用 | 替代 |
|------|------|--------|------|
| 团队协作（≥2 人） | standard | 个人脚本/一次性原型 | AI 裸写 |
| 中大型（≥80 文件） | standard | 极小改动（typo） | 直接改 |
| 强监管/合规交付 | compliance | 无 AI 辅助的纯人工开发 | 传统 lint/test |
| 长期维护（技能须跟项目演进） | 任意档 | 只要门禁不要认知设施 | 单文件 precheck.sh |
| 小项目要基础门禁 | lite | | |

**范式外轻量方案**（不套本范式的替代）：① 单文件 precheck.sh——直接拷 `swarm-yuan/assets/precheck.sh` 到项目，配 precheck.conf 跑 `--all` 核心门禁，不建 skill 目录；② 传统工具链——ESLint/Prettier/golangci-lint/pylint + Git hooks；③ AI 原生裸写——一次性任务直接对 AI 说需求。

#### 1.4.3 与历史定位的差异（诚实记录）

2026-07（WP-P10）定位是"重量级范式，重量是设计选择"——那是真实，也是五轮"过重"诊断反复追问的对象。R13（2026-08-21）后修正为两体系统：**重量没有消失，只是归位**——生成器侧 ~68K 行自举仍在（一次性消费不算税），生成物侧 ~25 文件、概念负担从 150+ 记忆槽降到 5 个层次名词。

**起源（ncwk 孵育史，2026-07）**：swarm-yuan 诞生于 ncwk 项目工作区——2026-07-02 用户首次提出"根据材料模板生成 skill"（sess_b55848b0），原始需求一句话：为具体项目生成供研发人员开发使用的 skill、完成需求交付全流程；同日澄清分层——swarm-yuan 是 Skill A（元技能生成器），ncwk-dev（后改名 Swarm-studio）只是 Skill B（第一个示例产物）。2026-07-03 首次推送 issac-new/Swarm-yuan（68b609c）；2026-07-21 独立 project 开始主会话。**与 hermes-studio 的关系**：hermes-studio 是 ncwk 的第三方上游依赖（EKKOLearnAI/hermes-studio），swarm-yuan 诞生于 ncwk 但与其无代码依赖、无命名同义、无组件包含关系——swarm-yuan 是独立仓库本体。

### 1.5 设计理念细则
#### 1.5.1 稳定内核（九条，五轮从未动摇；第⑨条为 ncwk 奠基期深挖补录）

① 元技能生成器定位 + 六段式产物结构；② "AI 短板在项目认知不在代码生成"；③ 零占位符铁律 + draft/active 状态门；④ 单文件 precheck 可移植；⑤ 三层接线 + 降级链 + 调用不重实现；⑥ 自适应轻重（质量优先于效率）；⑦ facts.conf 单一事实源；⑧ "账面与实质一致"三层诚实化（数字/修辞/证据）；⑨ **AI 全自动、零手动配置**（奠基期铁律，sess_4782d626/sess_d466cc75 反复强化）：生成 skill 是 AI 一键完成（探查→填充→配置→验证全自动）；skill 使用时研发人员对 AI 说话而非手动跑命令——SKILL.md 是 AI 读的（写"零手动"铁律），USAGE 层保留 bash 双轨制（排查/CI/脚本场景需要）；安装的一次性 `cp -r` 不属于"日常使用"，允许手动。

#### 1.5.2 奠基理念四条（README 对外口径的四个理念，ncwk 期确立）

| 理念 | 含义 |
|------|------|
| **先认识，再行动** | AI 写代码前必须先认识项目。特征卡完成认知，门禁守护行动——"认知 DNA"（特征项是项目认知的基因图谱） |
| **呈现递进的关系** | 门禁不是"数 import 数"——每个计数背后指向一条关系规律（计数核验 0.95 是表征覆盖度的关系性度量） |
| **分层整合，诚实降级** | 运行时按深度接线（4 深度子进程/4 CLI/5 方法论引用）三层整合，每层有自带降级载体，未装不阻塞，不假装全深度接线 |
| **领域知识防达克** | 领域知识库（`references/domain-knowledge.md`，计数真值 facts.conf）——AI 探查时识别技术+业务领域、推导客观规律驱动 `--domain` 违规检测，防止对不熟悉领域自信地写出错误代码 |

#### 1.5.3 R13 新增两条理念

**范式作为条件，而非内容**：机制分两类——**条件**（运行时约束行为、零认知占用、糊弄结构上不可能）与**内容**（要 AI 先读先记再自觉、每会话重复付税、糊弄结构上必然）。机器执法只保留"防 AI 说谎"的条件类；"给理解打分"与"防文档数字漂移"的内容类退役或转落地化。AI 的理解深度由行为证据兜底（测试过没过/门禁红不红/决策留没留痕），不由表格验证。

**落地优先于删除**：概念/门禁/profile/references 一概不删——病根是"没有正确落地"（机械打分/僵尸孤立/无路由），全部转为真实消费路径：概念→AI 判断引导+留痕；僵尸门禁→全接线；孤立 profile→conf-render 真实加载；无路由文档→"何时读我"路由头。

#### 1.5.4 失败方向教义（条件类的补充原则）

权限边界一律 fail-closed（默认全拒、白名单放行）；**fail-open 只允许发生在还有下层强制兜底的地方**（如 hooks 失败不阻断，因命令还要过门禁；规则文件解析失败退最小规则集）。每个 SKIP/降级路径按此逐处复核。

#### 1.5.5 对外叙事边界（祛魅红线，sess_fcc61435 外部评审校准）

对外讲 swarm-yuan 的不可逾越红线（外部评审曾点破浮夸风险——"内核合理的方案被过度营销语言包装"）：
1. **"100% 可靠"禁用**——verifier/v2 外部有效性未达成前，对外禁用 100%；用"已验证组件 + 受约束生成 + 独立校验"三段式。
2. **"10⁻¹⁰"标注**——使用方推演模型非工具输出；引用必须带出处说明。
3. **具体数字归属**——"103 组件"是某目标项目的枚举产物非 skill 硬数字；"90% 采纳率"若源自计划表必须标"计划口径"。
4. **"三权分立"**——是叙事隐喻，真实拓扑按治理 agent 实际；对外用时标注。
5. **本质表述**——swarm-yuan = **bash 脚本 + Markdown 挂在 AI 编码助手 hooks 上**（写代码前拦截、交差时独立验证）+ 本地观测；不是纯 PPT 工程，也不是集群平台。

#### 1.5.6 平台分工教义

harness（宿主 CLI：Codex/Claude Code）管 agent loop/沙箱/审批通道；**应用侧（swarm-yuan 生成物）管项目上下文、业务规则、操作边界**。生成物不碰 harness 内部（会话管理/审批实现/OS 沙箱），只做应用侧资产（地图/规则/hooks 注册）。token 纪律即能力（官方实测 ARC-AGI-3 上下文纪律 13.3%→38.3%）——生成物每字节税稀释有效上下文占比，直接降能力。

## §2 设计原则
上层确立了"先认识再行动 + 三权分立 + 诚实"。本层回答：这些价值观在工程上以什么原则兑现。

### 2.1 两体系统：生成器厚、生成物薄

为兑现"认知充分"与"每会话低税"的矛盾要求，系统切成两个体：

- **生成器（厚）**：探查知识全量（79 框架规则、41 references、行业 profile、决策史）——只在生成时刻消费一次，允许厚。
- **生成物（薄）**：每会话重复消费，必须薄——SKILL.md ≤8KB、概念体系 ≤5 个、认知面 references 拷贝 ≤256KB，全部有机器预算断言。

### 2.2 生成物的三件套：地图 + 条件 + 演化链

薄生成物不是"少"，是"只装该装的"：

- **地图**（认知的承接）：组件/接口/约束清单，两列表 `| 路径 | 说明与约束 |`——路径供机器执法，说明列写 AI 的理解与稳定性标注；会话中按需 grep，不全量预读。
- **条件**（行动的守卫）：precheck 门禁 + hooks 强制 + draft/active 状态门——做错就被拦，不占认知预算。
- **演化链**（时间的承接）：项目变了技能跟着变——指纹感知 → 变化域局部重探查 → 单条更新 → 落新基线。

### 2.3 三层 Harness：强制、审计、评测

单靠门禁挡不住"绕过"，需要纵深：

| 层 | 管什么 | 兑现哪条理念 |
|----|--------|-------------|
| 过程强制 | rules.d 三值规则（allow/prompt/forbid 取最严）+ hooks 双宿主真实拦截（Claude Code deny / Codex exit 2） | 门禁执法 |
| 工作流审计 | 目标闭环（一个用户目标 + 一个验收边界，change↔validation 链接才 closed）+ 证据态分级（配置≠使用≠有效） | 诚实 |
| 评测 | digest 链式锚定（上游篡改全链可检出）+ 选择即证据 + 审计即完成条件 | 司法 |

### 2.4 范式作为条件而非内容 + 复杂度负向预算

- **条件而非内容**：机器执法只保留"防 AI 说谎"的条件类（路径存在性/计数核验/last-good 红线/状态门）；概念性内容不靠删除靠落地——每个机制必须有真实消费路径。
- **负向预算**（决策 26，追认于决策 26.2）：门禁数 ≤55、conf 变量 ≤200、认知面 ≤256KB——范式自身的膨胀被自己的门禁管住，兑现"帮你降复杂度的东西自己不能失控"。

---

### 现行守恒律（贯穿全文的硬约束——跨四维度成立）

> 以下是设计文档自约束的守恒律，self-check 机器执法。演化依据见 `docs/design-evolution.md`。

1. **概念落地问责**：新概念进 SKILL.md/生成物必须给出落地路径（接线/AI 判断引导/路由，不接受"先放着"）。
2. **吸收三问**：①能否落到运行时条件？②替换还是叠加？③六个月后谁引用？——不过只留调研报告，不进 references。
3. **生成物税制**：进 UNIVERSAL_FILES 的审核问题 = "目标 AI 每会话为它付多少税"；机器载体 = 体积/字节预算断言。
4. **五维复审**：季度跑结构/连接/有效/适配/成长五指标，与 gate-trends 季度报告合并，不新增例程。
5. **刻意不修原则**：修复会改变门禁判定行为且无 fixture 覆盖时，不贸然"唤醒沉睡门禁"——先补 fixture 再评估苏醒影响。
6. **不 vendor 上游核心插件**：方法论引用不 vendor、运行时调用才考虑深度整合——"调用不重实现"的最低成本形态（体积/维护面/许可证敞口/生态四理由）。
7. **机械 vs AI 边界**：探索式判定（taste/质量/cognition）转 AI 自觉判断而非机械 grep；"假装可机器"的门禁降 warn；机械只在信号可信处。
8. **宿主职责不复制**：OS 沙箱、LLM 审批分类器、供应链检测、解释器等——吸收其决策架构，实现复用宿主/既有工具（调用不重实现）。

### 决策要点（设计原则的根——每条标注溯源编号，全文见 docs/design-evolution.md）

> 设计的现行原则由历次决策沉淀而来。下表是**决策蒸馏出的要点**（终态），非历史记录——每条只保留"它确立了什么现行约束"。决策全文（问题/理由/演化）在 `docs/design-evolution.md` 决策史卷。

**生成物形态**
- **生成器厚、生成物薄**（决策 19/26/32）：生成物的认知面有硬预算——SKILL.md ≤8KB、references 拷贝 ≤256KB、conf 变量 ≤200、门禁 ≤55（决策 26.2 追认）；数字单一事实源 `facts.conf`，self-check 机器执法。
- **门禁分层 enforce_level**（决策 31/21）：strict（≥3 fail 阻断）/ warn / advisory 三级，随 profile 分档；advisory 不阻断但留痕。

**自适应与诚实**
- **自适应轻重**（决策 18/22/24/30）：profile 由项目信号驱动（合规 > 技术栈复杂度 > 规模），只升不降、信号明确才升；spec 三级机器执法（决策 23）。
- **诚实化**（决策 12/25/35）：不适用场景显式声明；未创建且未运行的机制不得声称；门禁 fail 阈值不实装则不假装。
- **全链路留痕**（决策 15/16）：trace-log 真接线、state-machine 自动流转——理念必须落到机制，不停在口号。

**吸收与约束**
- **吸收优先于新增门禁**（决策 27）：上游新概念优先以方法论吸收（references/叙事/断言），不新增 `check_*`；self-check G<N> 断言是合规扩展点。
- **范式作为条件而非内容**（决策 33）：去抽象化——认知框架落地为 AI 判断的检查单 + 留痕，不机械计分；落地优先。
- **概念落地问责 + 吸收三问 + 生成物税制**（决策 34）：新概念进文档必须同时给落地路径（接线/AI 判断/路由三选一）；吸收前问三问；产出受税制预算约束。

**本体与传播**
- **标记沿调用链传播**（决策 28）：禁止改的稳定单元，其下游改动须 warn——依赖方不能装作不知道契约。
- **语义/动能二分显式命名**（决策 29）：特征卡（语义）+ 门禁（动能），动作授权锚定组件标记。

**断点与降级**
- **draft 状态门**（决策 13）：断点续传不用一次性否决令，用 draft/active 状态门——draft 可继续、active 须全绿。
- **运行时全可选降级**（决策 9/10/11）：13 运行时未装自动降级且显式披露；三平台 CI 真实化；测试覆盖进 CI。
- **离线包治理**（决策 14）：offline-cache 大件（whl/tgz/zip）迁 GitHub Release 附件、git 索引只留 UPSTREAM.md；`fetch-offline-cache.sh` 从 Release 拉取——分发体积不进 git。

**质量与审查纪律**
- **可证伪性门禁**（R10 吸收）：测试须"说出会让它失败的生产改动"，期望独立于被测代码推导 + 闭合 Mutation Check；硬止 string-presence/change-detector 两类伪造可证伪的陷阱。
- **破窗台账**（R10 吸收）：stubs/TODOs/skipped tests/unrun verifies 跨阶段累积入台账，ship 门禁在有 open 条目时阻断——半成品不许带着出厂。
- **resume 修复环 + 五轮熔断**（R10 吸收）：修复环 R1-3 resume 原实现者、R4-5 fresh 派更强模型、R=5 熔断由 controller 逐条 adjudicate 每个 open finding（禁止静默丢弃）。

## §3 架构
上层原则在本层变成可见的系统结构。

### 3.1 总览

```
厚生成器（一次性消费）                薄生成物（每会话消费）
  探查知识库（79 框架规则/41 refs）     SKILL.md（≤8KB）
  行业 profile（conf-render 加载）      地图（≤32KiB 两列表）
  决策史/调研史                         rules.d 三值规则 + precheck + hooks（双宿主）
  generate-skill.sh（12 步生成流）      scripts 工具（按需调用，不算税）
                                              │
                                        目标项目（任意仓库）
```

### 3.2 门禁四族与执行面

55 个门禁分四族，各有真实触发路径（可达率 55/55 机器对账）：

| 族 | 数量 | 触发面 |
|----|------|--------|
| 核心 | 10 | `--all`（日常） |
| 架构 | 18 | `--all-full`（结构变更） |
| 合规 | 19 | `--compliance-suite`（强监管交付） |
| 专项/advisory | 8 | decision-audit/state-phase 专项（FULL-only 2）+ 宿主 hook 执行（advisory-only 6：loop-oracle 为 strict 档可阻断，其余 advisory，真值 facts.conf） |

执行面三道：单命令（precheck）、hooks 强制（fail-gate-hook 双宿主拦截）、状态机阶段守卫（open→design→build→verify→archive→operate，每阶段核验前序产出物存在）。

### 3.3 运行时三层接线（13 个外部运行时）

只引用不重写，按接线深度分层，每层自带降级载体：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度（4） | GitNexus / graphify / claude-mem / ocr | 门禁内真实子进程 + 多级降级链 |
| CLI（4） | OpenSpec / comet / gsd-core / codex-security | 按需调用 CLI，降级自带载体 |
| 方法论（5） | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用模式 |

### 3.4 工作流：六阶段 ↔ 九节点

粗粒度状态（state-machine 六阶段）与细粒度执行（workflow 九节点）一体两面：open=①需求理解+②探查 ｜ design=③spec+④plan ｜ build=⑤编码 ｜ verify=⑥测试+⑦独立审查 ｜ archive=⑧合入 ｜ operate=⑨发布。spec-first 是硬前置——写源码而无已批准 spec 会被 hook 直接拒绝。

---

### 3.5 终态架构详图
#### 3.5.1 两体系统总览

```
厚生成器（一次性消费，可厚）          薄生成物（每会话重复消费，必须薄）
  探查知识库（79 框架规则/41 references）   SKILL.md（≤8KB：何时用/约束摘要/入口/路由/元规则/自成长）
  行业 profile（7 份，conf-render 真实加载）  地图（≤32KiB：两列表 |路径|说明与约束|）
  探查/渲染/自检脚本                     spec 9 节核心 + workflow 9 节点×4 要素
  决策史/调研史（§12）                  rules.d/*.rules + precheck + hooks（双宿主）
                                      scripts（按需调用的工具，不算税）
```

#### 3.5.2 生成物文件级规格

```
<skill-name>/
├── SKILL.md          # ≤8KB 预算（FACT_SKILLMD_BYTES_BUDGET=8192，锚点=gen-e2e §7.6 对生成物实测）
├── references/
│   ├── reference-manual.md  # 项目地图载体：§4/§6/§9 两列 |路径|说明与约束|；32KiB 硬顶（FACT_MAP_BYTES_BUDGET，gen-e2e §7.7 锚）；stability 词在说明列
│   ├── codebase.md / dev-guide.md / release.md / workflow.md  # 探查填充件（workflow=9 节点 × 4 要素：入口/参与方/门禁/产出物）
│   └── （激活框架文档 + 任务路由命中的方法论文档，按需拷贝）
├── assets/spec-template.md  # 24 节模板（9 节核心必填：需求/决策记录/约束/测试/回滚/左移三节/合规；仪式节 --task-type full 展开）
├── scripts/          # precheck.sh + gates + gate-rules.sh + inventory-update + fingerprint + trace-log + state-machine（inventory-verify 是生成器侧核验，不进生成物）
├── rules.d/          # *.rules 三值规则数据（allow/prompt/forbid，生成器产出+审批沉淀）
├── hooks/hooks.json  # 双宿主渲染：Claude Code（deny JSON）/ Codex（exit 2 经 codex-gate-wrapper）
└── settings.local.json  # 最小权限 + 沙箱通配符 deny（Read(**/.env) 等）
```

**读者双轨制**（奠基期 sess_4782d626 澄清）：SKILL.md 的读者是 **AI**（写"零手动配置"铁律——AI 自动探查/填充/配置/验证）；USAGE 文档的读者是**研发人员**（保留 bash 命令 + "对 AI 说"并存——排查/CI/脚本场景需要）。安装的一次性 `cp -r` 不属于日常使用，允许手动。

#### 3.5.3 结构性保障（层依赖显式单向）

五层一棵树：生成 → 探查（产地图）/ 约束（rules.d+precheck+hooks）/ 演化（fingerprint+inventory-update）/ 留痕（trace+decisions）。单向边由目录物理隔离承载：references/ 不 import scripts/（self-check G19 反向引用=0 断言）；每层唯一入口命令；分层失败隔离（地图坏不影响约束；rules.d 缺失降级最小规则集）。五层各有章节着落：§8 生成 / §4 探查 / §5 约束 / §6 演化 / §7 留痕。

#### 3.5.4 兄弟工具与装配关系（外部系统边界澄清）

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

#### 3.5.5 三层 Harness 总览（过程强制 + 工作流审计 + 评测）

| 层 | 职责 | 核心机制 | 落地版本 |
|----|------|----------|---------|
| 过程强制门禁层 | 开发过程中实时拦截违规 | 门禁四族（真值见 facts.conf）55/55 可达 + rules.d 三值（allow/prompt/forbid 取最严，FORBID 带替代）+ hooks 双宿主（Claude deny JSON / Codex exit 2）+ 沙箱通配符 deny | v2.0（R13） |
| 工作流审计层 | 事后复盘"工作流是否可信" | goal_id+closure（审计单元=一个用户目标+一个验收边界）+ 证据态分级（Present/Wired/Exercised/Outcome-supported）+ 双账本（当窗验证 vs 跨窗效果）+ repair_review | v2.2（R14） |
| 评测层 | 评测自身的可信度 | ref_trace_hash（三本账链式锚定，上游篡改全链 stale）+ missing_evidence（该测没测）+ gate-plan（选择即证据，负空间可审计）+ audit-closure（审计即完成条件） | v2.3（R15） |

三层关系：门禁层做事中拦截（条件），审计层做事后复盘（证据），评测层做评测自身可信（元证据）——每层消费下层的账本（gate-runs → goal 聚合 → 链式锚定），互补不竞争。

#### 3.5.6 工程一致性三矩阵（宣称→可核对的事实）

**运行时接线明细**（历史快照表见归档 design-philosophy-consistency；权威计数 facts.conf）：每层每运行时的"真实接线方式（脚本里会执行的命令）/降级载体/self-check 可安装/验证 fixture"四列对账——深度 4（GitNexus 子进程调用等，调用点计数以代码为准）/CLI 4/方法论 5。

**研发全流程 7 阶段 × 门禁映射**（每阶段四件套核对，无空壳）：

| 阶段 | spec 章节（spec-template 节号） | workflow 节点 | 门禁函数（代表） | 双态 fixture |
|------|----------|--------------|-----------------|-------------|
| 需求 | §1/§4 | ①② | check_requirements（+openspec validate） | ✅ |
| 分析（左移） | §19/§20/§21 | ②③★ | check_shift_left / check_impact | ✅ |
| 设计 | §3/§5/§5.5 | ②③ | check_layer/stable_diff/link_depth/reuse/deps/security/cognition/domain | ✅ |
| 开发 | plan Tasks | ④⑤ | check_build / check_framework（79 框架动态分发） | ✅ |
| 测试 | §11/§19 | ⑥ | check_test（TEST_CMD 退出码 + 0 用例检出——"空跑通过"warn）/ check_review（+gsd-tools health + 审查留痕核验：docs/reviews/<日期>.md 三要素） | ✅ |
| 交付 | §12/§22 | ⑦⑧ | check_branch / check_release_sign / --compliance-suite 族 | ✅ |

**三平台 CI 矩阵**：Linux ubuntu-latest 全覆盖（74 ruleset + 74 fixture + 48 gate-fixture + e2e + verifier + shellcheck + generator-self-gate）；macOS/windows 轻量腿（windows-syntax bash -n + .bat 冒烟，全量降频周跑——bash 硬前置下的诚实分层）。

**两条奠基理念的落实状态**：① 连贯动作（一键生成+一键使用，`/swarm-yuan <路径>` 全自动；7 处用户决策点保留确认属设计性例外）；② 全链路追踪（stdout 公告 + trace-log 落盘 + gate-runs + hooks 摘要 + 第三方工具调用点 trace_tool 桥——工具×调用点以 `grep -rh 'trace_tool "' assets/*.sh` 机械计数，不手抄数字）——机器执法：verify-completeness 校验 workflow 每节点含调用追踪。

#### 3.5.7 概念体系收敛与方法论承载

只允许 5 个层次名词为主轴：**探查 / 约束 / 演化 / 留痕 / 生成**。认知框架类概念（六阶链/六维动力学/三元演化/七推理/辩证范畴/五维偏差/思维模型）不删除不堆砌——以“工作时按此思考”的指引式表述融入对应层次，落地为 AI 判断引导（逐维自查 → `.swarm-yuan/notes/cognition.md` 留痕，GATE_AI_JUDGMENT 唯一模式；骨架的“工作时的思考框架”表四行：探查按六阶链/思考用逻辑剃刀/决策三级分类/纠偏辩证+领域防达克）。本体层词汇（17 类型/10 关系/11 动作，§0.4）不占这 5 个概念预算——它是机器对账的类型事实源（§0.2 冲程一），不是叙事概念体系：AI 只在设计新机制/演进本体/对账时经“何时读我”路由读取，不进每会话认知面。

**方法论 references 承载表**（41 份全带“何时读我”路由头，核心 10 份职责）：

| reference | 层次 | 职责 |
|-----------|------|------|
| exploration-guide.md | 探查 | §C+ 探查方法论（形态判定/全量穷举/三层调用链/编排约束/五维字段定义） |
| template-spec.md | 探查→产物 | 六段式填充规范 + 生成后核对清单 + 96→12 项核对规则 |
| generation-flow.md | 生成 | 生成流程 Step 1-12 详解（决策 32 折叠，按需读；唯一编号口径见 §8.1） |
| workflow 模板 | 使用 | 九节点 × 4 要素骨架 |
| decision-governance.md | 留痕 | G1 决策治理（三级分类/五要素/decisions.jsonl 格式/ISO 42001 对齐） |
| review-methodology.md | 留痕 | 代码审查方法论（rubric 判定/P0-P3/规则溯源） |
| memory-persistence.md | 留痕 | 记忆持久化（claude-mem 吸收/version oracle） |
| subagent-orchestration.md | 使用 | 子代理编排（comet/gstack/ECC/Ruflo 四源方法论） |
| cognition-framework.md | 使用 | 五层认知基底详表（认知递进/思维语言/辩证/偏差/统一——工程启发式框架，非心理测量学构念） |
| domain-knowledge.md | 探查 | 领域知识库（防达克） |
| task-methodology-router.md | 使用 | 任务类型×方法论路由（8 类任务选关键节点序列+门禁聚焦，避免全任务跑全量 12 步） |
| logic-razor.md / cognitive-bias.md | 使用 | 逻辑剃刀删冗余假设 / 认知偏差防范（五维偏差+思维模型） |

**references 全承载索引**（41 份全列，按六类——每份都是真实消费路径，孤儿=0 由 self-check G18 执法）：

| 类 | 文件 |
|----|------|
| 探查方法论（4） | exploration-guide.md / template-spec.md / generation-flow.md / code-graph-tools.md（图谱工具选型平权） |
| 认知框架（4） | cognition-framework.md（五层基底）/ logic-razor.md / cognitive-bias.md / domain-knowledge.md（领域防达克） |
| 编排与审查（4） | subagent-orchestration.md / review-methodology.md / task-methodology-router.md / gsd-patterns.md |
| 外部吸收方法论（10） | codex-methodology.md / codex-security-methodology.md / claude-code-capabilities.md / dsh-engineering-methodology.md / cordis-composability-methodology.md / mea-loop-methodology.md / agent-skills-methodology.md / frontend-design-methodology.md / context-engineering-layering.md / memory-persistence.md |
| 治理与合规（11） | decision-governance.md / governance-agents.md / standards-compliance.md / quality-management-standards.md / crypto-spec.md / cwe-database.md（门禁内部数据）/ security-spec.md / security-certification-profiles.md / mcp-governance.md / ai-process-records.md / canary-monitoring.md |
| 行业 profile（7） | industry-profile-finance.md / industry-profile-medical.md / industry-profile-gov.md / industry-profile-automotive.md / industry-profile-energy.md / industry-profile-industrial.md / industry-profile-telecom.md（法规依据文档，与 conf 配对——conf-render --industry 真实加载） |
| 案例与骨架 | case-studies/articulation-orchestration.md（对外汇报论据）/ workflow.md·reference-manual.md 等骨架由生成器产出 |

## §4 核心机制
上层结构在本层落到具体机制与代码。

### 4.1 探查实现

- **框架规则引擎**：79 份框架规则（每份六段式：探查信号/构件枚举/领域规律≥10 条/门禁清单/跨框架交互/深化材料），探测激活后注入对应门禁片段。
- **特征卡防幻觉**：清单登记的每个路径由 `--path-check` 机器核验存在性；计数核验防虚报；mark-active 三关（零占位符 + 路径存在 + 决策留痕）才解锁全量门禁。
- **探查方法**：extraction-guide 全量穷举（非抽样），稳定单元五维字段（签名/路径/用途/复用方式/稳定性标注）。

### 4.2 约束实现

- **门禁实现**：三档 enforce（strict/warn/advisory）由 conf 声明、self-check 对账；fixture 双态（violating 必检出 / compliant 必通过）+ golden 向量锁行为。
- **hooks 双宿主**：Claude Code（hooks.json + CLAUDE_PLUGIN_ROOT 解析）与 Codex（`.codex/hooks.json` 嵌套 schema + exit 2 + stderr 透传）——schema 均对宿主源码逐字段核验。
- **三值规则**：rules.d/*.rules 随生成物分发，FORBID 无条件且必带替代方案。

### 4.3 演化实现

项目指纹（文件数/扩展名分布/骨架 cksum）秒级感知变化 → 变化目录即重探查范围（scope 局部） → inventory 单条更新（原子替换，条目骤降 >50% 触发 last-good 红线拒绝写坏清单）→ 落新基线。

### 4.4 留痕与审计实现

调用留痕（trace.jsonl）、决策留痕（decisions.jsonl，方向性决策须带 alternatives/代价）、digest 链（三本账链式锚定，上游篡改全链 stale 可检出）、gate-deny 落盘（每次拦截可复盘）。

### 4.5 自举与验证（司法层实现）

- **自举**：swarm-yuan 用自身门禁检查自身（CI generator-self-gate 三档 RC=0）——只证明内部自洽。
- **独立验证**：`verifier/v1`——79 fixture 双态、48 合规 gate-fixture、cli A/B 逐字节等价（HEAD↔工作区行为漂移检出）、golden 向量；外部有效性另由真实项目回归覆盖（见 6.7 证据链）。
- **质量基线真值**（机器执法）：门禁 55/55 可达 · references 孤儿资产 0 · 19 测试脚本 + gen-e2e + self-check RC=0 · CI ubuntu/macos/windows 三平台 · 双重点栈（vue+element 前端、SpringBoot+MySQL 后端）九节点真实交付验证。

---

### 4.6 探查机制（认知层）
- **形态判定先行**（§C+.0）：backend/frontend/async/desktop/mobile/lib/common，维度适配由 `inventory-dimensions.conf` 承载；不预设项目类型。
- **全量穷举 + 计数核验**：组件清单 ≥ 枚举计数 × 0.95；`--path-check` 杀幻觉路径（HALLUCINATION 阻断 mark-active）；`--stability-audit` 三机械信号（git churn/fan-in/测试存在性）与标注冲突 → STABILITY_WARN（advisory）。
  > **实证来源（sess_733ff1c4, 2026-07-11）**：ncwk-dev 初版只列 10 个组件，真实代码库有 99 .vue + 8 store + 12 adapter + 17 loop 模块——样本化填充仅 10% 覆盖。0.95 红线由此定：强制穷举 + 三层调用链（注册装配/模块依赖矩阵/组件挂载树）+ 编排约束 6 类（导入方向/注册顺序/路由挂载/文件落位/状态所有权/测试边界，每条须代码证据）+ 接口全量枚举禁通配符。
- **两维表规范**：地图行 = `| 路径 | 说明与约束 |`。路径反引号包裹（path-check 校验存在性）；说明列写"它是什么+接口/约束+稳定性标注词"（"导出 add（禁止改）"——stability-audit 按行内字面词识别，与列位置无关）。维度/来源等纯记账列已退役（R13）。说明列执行**语义/动能两区纪律**（R16 本体层口径，是/应当不混写）：说明列是表征区——只写"是什么"（组件/接口/依赖/稳定性标注词的引用）；"应当怎样"的规范执行体只落 rules.d/*.rules 与门禁，地图至多引用规范词、不承载执行逻辑（地图骨架自带该纪律说明，links.md 使用纪律第 3 条同口径）。
- **特征卡**：P0 六项强制 / P1 十一项可增量（draft 期「（P1 待补）」允许，mark-active 前清零）；探查期产出，受检不自证。

#### 4.6.1 框架规则引擎格式契约（79 框架规则的结构约定，方案 A 选型 2026-07-17；74→79 见 WP-P2-extension）

**规则文件 `references/frameworks/<fw>.md` 六段式**：frontmatter（ruleset_id/适用版本/最后调研来源）→ §1 探查信号（依赖/注解/文件/配置四类，各带置信度——§C+.0.5 激活依据）→ §2 特定构件枚举（命令+计数核验基准）→ §3 领域规律（≥10 条，每条五要素：适用版本/规律/违反后果（挂 CWE 或官方 issue）/验证方法（具体 grep 命令）/对应门禁 id）→ §4 门禁清单（id/级别/实现逻辑/依赖 conf 变量）→ §5+ 深化材料。

**门禁片段 `assets/framework-gates/<fw>.sh`**：与规则 md 1:1 配对（框架证据台账对账），注入目标 precheck.sh 标记区块（`# >>> swarm-yuan:framework-gates >>>`），生成与 --upgrade 共用幂等注入，区块 sha 记录漂移检测。

**生成时数据流**（步骤编号用 §8.1 唯一口径）：§C+.0.5 探查 → ACTIVE_FRAMEWORKS+版本 → ④.5 框架深化（Step 7 填充期内：逐框架读 md，信号确认→构件枚举→规律种子实例化附证据）→ ⑦.5 门禁注入（Step 10.5 独立审查后：--inject-frameworks 注入门禁片段+生成 framework-knowledge.md 骨架+填 conf 变量）→ Step 12 最终检查四要素量化验收（规律数≥门槛且 100% 含证据字段，不过回 ④.5）。

**ncwk-dev 反哺机制**：已实战验证的手写框架检查（vue/naiveui/pinia/koa/socketio/vite/vitest 7 框架 28 项）先反向收割进片段库作种子，再经注入回灌——"从成功实践反哺范式库"，片段库起步即有高质量样本。

### 4.7 约束机制（门禁层）
#### 4.7.1 逻辑错误的兜底链（field-feedback 2026-08-26 补）

门禁是词法/结构模式匹配——抓"不懂规矩"，不抓"想错逻辑"。逻辑错误的兜底是**测试+审查**，且机器层对兜底本身有核验（不假装"提示了就算做了"）：

| 兜底 | 机器核验点 | 产物载体 |
|------|-----------|---------|
| 测试 | check_test：TEST_CMD 退出码 + 0 用例检出（"0 passed"输出 warn）；check_shift_left：spec §11 测试策略段非占位核验 + test 先于 impl 提交 | spec §11 测试策略表 + 测试套件本身 |
| 审查 | check_review：docs/reviews/<YYYY-MM-DD>.md 存在（三要素：评审人/日期/结论）；合规档 check_review_record 全要素+零 TBD | docs/reviews/<日期>.md（模板 assets/review-record-template.md 随生成物分发） |

#### 4.7.2 门禁族与可达率

55 门禁（FACT_GATES_TOTAL，真值对账）= FULL 49 + advisory-only 6；FULL 49 = 标准 28（核心 10 + 架构 18）+ 合规 19 + FULL-only 2（decision/state-phase）。**全部有真实触发路径（55/55 可达）**：cert/cwe-audit→compliance 序列、decision/state-phase→full 序列、upstream-baseline→precheck 启动、operate/pr-quality/supply-chain→PostToolUse、decision-audit/learnings→Stop hook、state-phase→SessionStart、loop-oracle→loop-hook。enforce 分层（strict/warn/advisory）是实现细节，模型只选执行序列（`--all`/`--all-full`/`--compliance-suite`）。**双口径**：静态分层 17/22/16（gate-enforce-level.conf 按 fail() 计数，gen-enforce-level 生成）；有效分层 17/17/21=静态+precheck `_ENFORCE_OVERRIDE`（WP-Q2H：stable_diff/framework/knowledge/metrics/crypto 五门禁 warn→advisory 转 AI 判断，generation-flow.md 有记录）——两口径分别由 FACT_ENFORCE_* 与 FACT_ENFORCE_EFFECTIVE_* 登记，self-check check_enforce_facts 重放 override 对账。（audit-claims-reality 修正：旧分解"核心 10 + 架构 17 + 合规 17 + advisory 10"未随 cert/cwe 入列与序列迁移同步，子族计数漂移——facts.conf 已补闭合方程机器断言。）

**核心工具入口**（生成器侧 `scripts/`，按流段归类）：

| 流段 | 工具 | 职责 |
|------|------|------|
| ①生成 | generate-skill.sh | 主生成器（create=默认模式非 flag；子命令 --upgrade/--refresh/--mark-active/--inject-frameworks/--rollback-frameworks/--verify-completeness/--render-tools） |
| ①生成 | detect-frameworks.sh | 框架探查（package.json/pom/go.mod/pyproject → ACTIVE_FRAMEWORKS） |
| ①生成 | conf-render.sh | conf 初稿渲染（嗅探+溯源注释+--industry 行业注入） |
| ①生成 | extract-feature-cards.sh | 特征卡结构化字段提取 |
| ①生成 | gen-framework-index.sh / gen-enforce-level.sh | 框架索引/enforce 分层自动生成 |
| ②产物 | split-gates.sh | precheck 三文件拆分（strict/warn/advisory） |
| ③使用 | gate-rules.sh | rules.d 三值求值器 + --persist 审批沉淀 |
| ④账本 | trace-log.sh | 三模式落盘（--node/--key-node/--decision） |
| ④账本 | cost-report.sh | 调用成本汇总（调用次数 TopN + wall-clock 耗时；trace.jsonl 无 token 采集，耗时是模型处理时间代理） |
| ④账本 | state-machine.sh | 阶段状态追踪（status/restore-journal/dump-journal） |
| ⑤回流 | project-fingerprint.sh | 结构指纹（--write/--diff/--force） |
| ⑤回流 | inventory-verify.sh | 计数核验+--path-check+--stability-audit |
| ⑤回流 | inventory-update.sh | 地图单条更新（replace/delete/append） |
| ⑤回流 | gate-plan.sh / audit-closure.sh | 选择即证据/闭环完备性 |
| ⑤回流 | ontology-verify.sh | 六锚健康检查 |
| 治理 | self-check.sh | 24 个命名断言段（`grep -c 'echo "▶ '` 机械可数）+ 18 个本体对账点（含 G18 孤儿/G19 反向引用/类型对账/G20 多字节铁律 + 尾部死代码防线：exit 后无可执行行） |
| 治理 | adaptive-gating.sh / task-scale.sh / detect-spec-scale.sh / detect-profile-drift.sh | 自适应四维（profile/任务规模/spec 规模/档位漂移） |
| 治理 | framework-evidence.sh / verify-framework-ruleset.sh | 框架证据台账/规则集验证 |
| 治理 | compare-baseline.sh / context-surface.sh / to-sarif.sh / gate-report.sh / gate-trends.sh / profile-threshold-survey.sh / migrate-verify-blocks.sh / release-src-packages.sh | 基线对比/上下文预算/SARIF 输出/门禁报告/趋势/阈值调查/verify 块迁移/发布打包 |

**关键资产**（`assets/`）：gates-strict.sh、gates-warn.sh、gates-advisory.sh（门禁物理文件三件套——物理位置与 enforce 分档正交：strict 档 18 函数中 4 个 enforce=warn，warn 档 21 函数中 2 个 enforce=strict，头注自披露）+ gate-enforce-level.conf（分层配置，gen-enforce-level 自动生成）+ industry-profiles/（7 行业 conf，conf-render --industry 真实加载）+ framework-gates/（79 门禁片段）+ facts.conf（数字事实源：FACT_GATES_TOTAL/FACT_REFERENCES/FACT_ARTIFACT_BYTES_BUDGET/FACT_SKILLMD_BYTES_BUDGET/FACT_CONF_VARS_USERFACE 等预算断言键）+ ontology/（R16 类型事实源三份：objects/links/actions，带路由头随生成物分发）+ rules.d/（底座规则两套 + framework-globs 默认值快照，§5.2/§5.4）+ hooks/ 五件套（failure-detector SPINNING 检测+L1 提示 / integrity-guard 自指防护 / fail-gate-hook 门禁拦截 / setup-loop / loop-hook，§5.3）。

**验证器（司法层）**：`verifier/v1/`——fixture 双态（violating/compliant 各一套最小样例，79 框架规则各一对；WP-Q2H-B 后 check_framework=advisory，violating 断言 = 检测命中 expected-fail-ids 而非退出码非零——违规不阻断是设计语义，检出能力才是被验证物）+ golden-vector（79 条框架 FIXTURE 预期向量 + 1 汇总行=80 行，回归基线）+ cli A/B 沙箱逐字节等价断言（历史 131 次调用一致性）。**诚实边界（R9 教训）**：fixture 是构造样例，5 个真实项目测试曾漏 3 个 P0/P1 bug——fixture + 真实项目双轨制；外部有效性立项稿 `verifier/v2/external-validity.md`（未达阈值前不得宣称"守护代码合规"）。

#### 4.7.3 三值规则引擎（Codex Decision 架构 bash 落地）

- **规则即数据**：`rules.d/*.rules` 行格式 `<pattern(glob)> → <allow|prompt|forbid> # <justification>`；求值器 `scripts/gate-rules.sh`（多规则命中取最严 forbid > prompt > allow）。规则来源四层：①底座两套内置示例（bash-advance 推进态 / readonly-safe 只读白名单——全档位随生成物分发，见 §5.3）；②探查期生成的项目特有规则；③审批沉淀写入（见下）；④`framework-globs.rules` 是 conf glob 默认值快照、非三值规则（运行时消费者 = self-check G21 对账锚，见 §5.4 与 §11 已修复边界②）。
- **三值作用域**：只作用于"命令该不该跑"的判定（Bash 命令放行，那里有宿主审批通道）；门禁家族不重分类。
- **拒绝消息 = 给模型的 API**：`FORBID <rule-id>: <原因>；替代：<方案>`——拒绝携带替代方案，AI 能自动改道。
- **自指防护**：integrity-guard 双层保护——deny 层拦机器维护区/司法层/规则自身（framework-gates/gate-enforce-level.conf/verifier/rules.d/*.rules/gate-rules.sh，改了就是治理绕过）；advisory 层提醒 facts.conf/账本（decisions/trace）——账本必须可被留痕机制写入，deny 会自锁，故只提醒重跑（无"执行前哈希自校验"机制，旧表述已废）。
- **审批沉淀**：临时放行持久化为规则——`gate-rules.sh --persist "<pattern>" <verdict> "<justification>" [--goal <id>]`（写 rules.d/approved.rules + 沉淀日期；同步 trace-log --decision 落痕 UserChallenge 决策，R14 起含 goal_id/closure/repair_review、R15 起含 ref_trace_hash 链式锚定）。校验三防：verdict 白名单/forbid 须含替代/同 pattern 幂等拒绝（改判先删旧行）。fail-gate-hook 的 deny 消息携带该命令（FORBID 消息 = 给模型的 API——拒绝即指路）。

#### 4.7.4 宿主下沉（双宿主真实拦截）

- **Claude Code**：fail-gate-hook（PreToolUse deny JSON + PostToolUse flag 捕获）+ settings.local.json 沙箱通配符 deny（`Read(**/.env)` 等，v2.1.236 防重命名绕过）。
- **Codex**：hooks.json PreToolUse → `codex-gate-wrapper.sh`（JSON deny 解析 → **exit 2 + stderr 透传**，v0.148 官方语义）。
- hooks 五件套：failure-detector.sh（SPINNING 检测+L1 提示）、integrity-guard.sh（自指防护）、fail-gate-hook.sh（门禁拦截）、setup-loop.sh（Oracle Gate 初始化）、loop-hook.sh（Stop 时 loop-oracle 接线 + 30 分钟超时）。
- rules.d 内置两个示例规则集随生成物分发：bash-advance.rules（推进态命令：git push/commit/merge→prompt，npm publish/rm -rf/git reset --hard/sudo→forbid 各带替代方案）、readonly-safe.rules（只读白名单：git status/log/diff、ls/cat/grep、precheck 自身→allow）。
- hooks fail-open 的合法性：有下层门禁兜底（§2.3 教义）。

#### 4.7.5 conf 面收缩

物理变量 184（含兼容别名）（兼容既有生成物）；**user 面必配 ≈ 20 项**（开关/路径/预算，`FACT_CONF_VARS_USERFACE=20`）——43 个框架 glob 阈值从 user 面摘出（运行时仍读 conf 同名变量，后赋值胜出），默认值快照存 `assets/rules.d/framework-globs.rules`（conf 风格数据、非三值规则；运行时消费者 = self-check G21 对账锚——原"无消费者"边界已闭环，登记 §11 已修复边界②）；行为参数留在模板/脚本内（Codex skills 全局配置仅 4 键的同构）。

**core conf 语义分组**（precheck.conf 16 变量，完整清单以 conf 文件自身为准——设计文档只列语义分组）：
- 路径类（6）：PROJECT_DIR / WRITABLE_DIRS / READONLY_DIRS / SCAN_DIRS / CONSISTENCY_DIRS / BRANCH_REGEX+PROTECTED_BRANCHES（分支规范）
- 命令类（2）：TEST_CMD / BUILD_CMD（真实可执行命令，AUTO:detected 嗅探）
- 工具选择类（2）：SENSITIVE_TOOL / SECURITY_TOOL（auto→builtin/gitleaks/semgrep 降级链）
- 执法开关类（3）：GATE_ENFORCE_DENY / GATE_ENFORCE_DENY_BASH（默认空=关，UserChallenge 决策）/ GATE_AI_JUDGMENT（R13 后恒 1 唯一模式）
- 证据类（1）：GATE_RUNS_DIR（非空时 gate-runs.jsonl 落盘，SARIF 证据链）
- 分层加载：core→arch→compliance→industry→patch（后 source 胜出；patch 是用户覆盖层，根治升级漂移）

**facts.conf 键分类法**（数字单一事实源，self-check 机械对账——完整键集以文件自身为准）：
- 预算断言类（5，已逐一列于上文关键资产段）：FACT_GATES_TOTAL / FACT_REFERENCES / FACT_ARTIFACT_BYTES_BUDGET / FACT_SKILLMD_BYTES_BUDGET / FACT_MAP_BYTES_BUDGET（FACT_CONF_VARS_USERFACE 是"约 20"估算值非机械可数，不设等值断言，归参考类）
- 预算上限类（3）：FACT_GATES_BUDGET=55（门禁数负向预算；决策 26.2 追认上调并冻结于 55，新增仍须等额删除）/ FACT_CONF_VARS_BUDGET=200 / FACT_CONTEXT_SURFACE_BUDGET
- 分层计数类（~20）：FACT_GATES_{CORE,ARCH,COMPLIANCE,ADVISORY_ONLY,STANDARD} / FACT_CONF_VARS_{CORE,ARCH,COMPLIANCE} / FACT_RUNTIMES{,_DEEP,_CLI,_METHOD} / FACT_ENFORCE_{STRICT,WARN,ADVISORY} / FACT_COMPAT_{TIERS,DEEP,CLI} 等
- 结构计数类（~15）：FACT_FEATURE_CARDS{,_P0,_P1} / FACT_FRAMEWORKS / FACT_FLOW_{STEPS,NODES} / FACT_SPEC_SECTIONS / FACT_DOMAINS / FACT_COGNITION_LAYERS / FACT_UNIVERSAL_FILES{,_CORE} 等
- 机制存在类（~8）：FACT_LOOP_ORACLE / FACT_COMPACTION_JOURNAL / FACT_FAILURE_DETECTOR / FACT_INTEGRITY_GUARD / FACT_DECISION_{TYPES,LOG} / FACT_BOOTSTRAP_GATES / FACT_STABLE_PROPAGATE{,_HOPS} 等
- 原则类（2）：FACT_VERSION_ORACLE_RULE（G10 版本单源真值）/ FACT_MEASURE_METADATA_REQUIRED（GB/T 测度元数据覆盖）

### 4.8 演化机制（成长层）
- **生成物自成长链**：fingerprint 感知（SessionStart/手动 --diff）→ 变化目录 scope 报告（局部重探查，不整仓重扫）→ inventory-update 单条更新（replace/delete/append §4/§6/§9，原子替换 + 决策落痕）→ last-good 红线（文件数骤降 >50% 拒绝 --write，需 --force）→ `--commit-fp` 落新基线。局部重探查产出的新组件经 `inventory-update append` 入地图（AI 按自成长链操作显式入账，非隐式自动写——探查产出先给 AI 判稳，再登记，决策落痕）。
- **生成器成长通道**：吸收一律走"调研报告（docs/research/）→ 三问评审 → 落地为条件/路由/引导之一"（phase=absorption 留痕 decisions.jsonl）；上游重核从全量改为破坏性变更驱动（breaking/major 触发 + 季度例行）。
- **生成器演进协议**（R16 起，本体先行——§0.2 冲程三的工程化）：新机制/新概念先过冲程二四问——新实体进 objects.md、新关系进 links.md（必配机器锚）、新动作进 actions.md；再派生实现；收尾跑 self-check 类型对账 + ontology-verify 六锚。吸收三问（准入评审：要不要吸收）与本体四问（设计方法：怎么落地）串联——先三问、后四问。
- **成长的预算约束**：成长 = 预算内替换（新知识进来必须有旧知识出去或税不增），否则只是膨胀。

### 4.9 留痕机制（追踪层）
- **trace.jsonl**：节点级调用落盘（stdout 公告 `→ [节点X] 调用 …` + `trace-log.sh --node/--key-node/--decision`）；永不 fail 阻塞主流程。
- **decisions.jsonl**：G1 决策治理（三级分类 Mechanical/Taste/UserChallenge + outcome 生命周期 proposed/implemented/rejected/superseded + 未采纳决策照常落盘 + 回放规则不可变——旧行无 outcome 视 implemented）。R14 增 `goal_id`+`closure`（审计单元目标闭环化：一个用户目标+一个验收边界，change↔validation 链接才 closed）+ `repair_review`（修复复核位：verified/partial/blocked，空=pending）。
- **gate-audit.jsonl**：fail-gate 全量决策审计（invoked/result 单行自包含 + 稳定 handler id + target 截断 500 + 休眠不写）；`--report` 四段（最近决策/拦截率按 handler/deny 聚合/工具分布）。R14：gate-report 增证据态分级（配置≠使用≠有效）——落地三级（Present/Exercised/missing_evidence；Wired/Outcome-supported 由 gate-trends 双账本承载，未落地，登记候选）；gate-trends 双账本（当窗验证 repair_verified_rate + guardrail 配对 vs 跨窗效果 Loop Effectiveness——后者需两次执行对比，诚实声明登记候选）。
- **gate-runs.jsonl**：门禁执行流水（每次 precheck 运行追加一行带 run 序号，`GATE_RUNS_DIR` 非空启用）——SARIF 证据链、连续零发现统计（metrics 门禁）、gate-trends 趋势的数据源。
- **key-nodes.jsonl**：九节点关键调用看板。
- **gate-plan.json**（R15 评测层）：任务开工的门禁选择声明（enable/skip + 理由，负空间可审计）；`scripts/gate-plan.sh --plan/--diff` 收口对比计划 vs 实际触发（missing_evidence/计划外/skip 违反，advisory）。
- **decisions.jsonl `ref_trace_hash`**（R15 评测层）：decisions 记录引用 trace.jsonl 末行 cksum——三本账从并列升级为**链式**（上游篡改 → 失配 → 全链 stale 可检出；HarnessEval evidence tree 的 bash 最小切片）。
- **audit-closure 完备性**（R15 评测层）：`scripts/audit-closure.sh` 按 goal_id 全集重走 closure 完备性（open/closed 分布 + open goals 列表）；`--strict` 有 open 时 exit 2，串 mark-active advisory 门（审计即完成条件）。

**落盘全景**（`.swarm-yuan/`）：四本账 = trace / decisions / gate-runs / gate-audit（objects.md `Ledger` 类型的四个实例）；辅助存盘 = key-nodes 看板 + gate-plan 声明 + 指纹快照 + notes/。

### 4.10 生成机制（流程 + 模板规范）
#### 4.10.1 生成流程（Step 1-12 唯一编号口径）

生成流程的**唯一编号口径** = `references/generation-flow.md` 的详解号（Step 1-12，`grep '^## Step'` 机械可数）。分工视图 ⓪-⑨ 是同一流程的机械/AI 边界压缩标记，与详解号一一对应（⓪=Step 1、⓪.5=2、①=3、①.5=4、②=5、③=6、④=7、⑤=8、⑤.5=9、⑥=10、⑦=10.5、⑧=11、⑨=12）；④.5 框架深化、⑦.5 门禁注入是两个插入子阶段（⑦.5 在 ⑦ 独立审查之后、⑧ 写回之前）。历史文档里的"Step 0-8 / 13 节点"均为旧口径残留，以本节为准（FACT_FLOW_STEPS 真值已同步为 12）。

| Step | 职责 | 机械/AI 分工 | 关键产出 |
|------|------|--------------|----------|
| 1 自检 | self-check 运行时检测 | 机械 | 生成器健康报告 |
| 2 读项目知识 | 读 AGENTS.md/CLAUDE.md/记忆，自行提取规则 | AI（extract-feature-cards 只出模板） | 项目规则初稿 |
| 3 探查仓库 | 三路并行扇出 + 图谱工具调用 | 机械扇出 + AI 判断结构/规范 | 探查原始材料 |
| 4 形态判定+组件库+调用链 | §C+.0 形态判定 + 详尽组件库 + 三层调用链（★不可跳过） | AI 判断 + inventory-verify 计数核验 | reference-manual 清单 |
| 5 特征卡 | 17 项骨架逐项填具体值 | AI（脚本不猜） | 特征卡 |
| 6 创建骨架 | 拷 UNIVERSAL_FILES | 机械 | skill 骨架 |
| 7 填充全部文件 | 真实探查内容替换占位符；④.5 框架深化（framework-evidence grep 证据 + AI 判规律适用性） | AI 为主 | 全量填充产物 |
| 8 配置 precheck.conf | conf-render 嗅探初稿 → AI 审 + 补 `# TODO:model` | 机械初稿 + AI 审 | conf |
| 9 集成宿主 | hooks.json / commands / settings / .mcp.json 真生成；AI 审 hooks 适用性（不适用即删） | 机械生成 + AI 审 | 宿主接线 |
| 10 运行门禁 | precheck 机械跑；AI 判断 fail/warn 是否要修 | 机械跑 + AI 判 | gate-runs |
| 11 记忆写回 | memory-writeback 落盘（⑦.5 --inject-frameworks 门禁注入在 Step 10 后、本步前） | 机械 + AI 判沉淀 | 记忆 + 框架门禁 |
| 12 最终检查 | verify-completeness + inventory-verify；AI 终审清单覆盖项目真实形态 | 机械验 + AI 终审 | mark-active 候选 |

红线：机械脚本只在"信号可信误报少"的环节跑（骨架/conf 初稿/核验/mark-active/enforce 加载）；判断性环节（特征卡填值/框架规律实例化/hooks 适用性/warn 采纳）必须 AI（WP-Q2H 机械 vs AI 边界）。

#### 4.10.2 生成物模板规范

- **spec-template 9 节核心必填**：背景与目标 / 决策记录 / 复用·版本·安全三约束 / 测试策略 / 风险与回滚 / 左移三节（§19 测试设计/§20 变更影响/§21 可观测性） / 标准合规。其余节（详细设计/分层设计/参考/§14-18 认知仪式/运营）**默认折叠**——`--task-type full` 的复杂变更才展开。
- **workflow 4 要素**：入口（顺序/并行）/ 参与方 / 质量门禁 / 产出物与追踪（含 trace-log 调用）；原 10 要素中分支/流程控制/状态控制并入产出物说明。
- **生成后核对清单 12 项**：机器验证四件套（零占位符/path-check/计数覆盖/mark-active）+ P0 核心映射八项；历史 96 项细目在折叠区保留为方法论参考（非 mark-active 前置）。
- **plan-template**：任务条目须含完成判据（test/命令/可观察结果/交付物——"Implement the thing"不算计划）。

## §5 使用

> 前四章把系统立起来了；本章回答：机制如何变成研发人员的日常操作。判读标准是一条——使用是否零手动（对 AI 说话即可）。

### 5.1 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash install.sh        # 自动检测 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi
# Windows：先装 Git for Windows（或 WSL），再运行 install.bat——原生 cmd/PowerShell 不支持
```

### 5.2 生成与激活

```bash
# 对 AI 说："为 /path/to/project 生成开发技能"
bash scripts/generate-skill.sh <skill-name> <project-dir> [target-dir]   # 或命令行
bash scripts/generate-skill.sh --mark-active <skill-dir>                 # 三关核验后解锁全量门禁
```

### 5.3 日常（对 AI 说话，零手动）

"开始新需求：xxx"（触发 spec-first + 九节点流） / "跑门禁"（--all-full） / "升级 skill"（fingerprint 变化后 --upgrade） / "报了误报"（决策留痕豁免链）。

### 5.4 平台与运行时

- **三平台**：macOS（bash 3.2）/ Linux / Windows（Git Bash > WSL > MSYS2），CI 三平台矩阵背书；11 个 .bat 包装器随发。
- **运行时**：13 个外部运行时全部可选——未装自动降级且显式披露；安装后即真执行（v2.6 已实证全链）。口径区分（三个数字各有所指，不冲突）：13=接线运行时（深度 4+CLI 4+方法论 5）；上游基线登记 16 项（§6.4，含仅登记观察、未接线的条目）；self-check 自动检测 11 项（codex-security 经 npx 按需调用、impeccable 随 agents 技能目录，不在自动检测清单）。
- **命令手册**：完整命令级参考见 6.5 使用手册。

---

## §6 本体论驱动原理（发动机——一切机制的上游）

> 前五章自下而上把系统讲完了；本章上溯到最上游——为什么这些机制必然存在、为什么新机制从这里长出来。这是深读章，理解演进逻辑再来。

### 6.1 一句话

swarm-yuan 是被本体论驱动的生成系统：**先说清世界里有什么，一切机制从"存在"推导出来，一切演进从本体开始改，AI 的一切行为被本体约束**。本体不是对系统的描述，是系统的上游——机制是它的实现投影，演进是它的丰富过程，行为空间是它划出的边界。

### 6.2 引擎的四个冲程

##### 冲程一：本体生成机制（为什么有这些机制）

每个机制都不是发明出来的，是本体里某条**关系的实现**：

| 本体里的关系（先有） | 派生的机制（后有） |
|---------------------|-------------------|
| 地图**表征**仓库（represents） | path-check（验证表征指向真实存在）、计数核验 ≥0.95（验证表征覆盖够全）、stability-audit（验证表征没过时） |
| 账本**记录**过程（records） | trace-log（记录的工具）、gate-audit（记录的固化）、审计闭环（记录的复盘） |
| 指纹**快照**仓库时态（snapshot_of） | project-fingerprint --diff（快照 vs 当前态断裂检测）、last-good 红线（骤降 >50% 拒写——好基线不因坏状态失效） |
| 决策**闭环**目标（closes） | goal_id+closure 字段（末次决策定闭环态）、audit-closure 完备性重走 |
| 技能**生成自**生成器（generated_by） | .swarm-yuan-version 版本戳、--upgrade 升级机制 |
| 规则**治理**命令（governs） | 三值求值器（治理的判定）、FORBID 带替代（治理的表达方式）、审批沉淀（治理的演化通道） |
| 技能 hooks **挂载**宿主（mounted_in） | hooks.json 双宿主渲染、fail-gate-hook 拦截（挂载即生效） |
| 账本行**锚定**上游账本（anchors） | ref_trace_hash digest 链（上游篡改 → 失配 → 全链 stale） |
| 稳定性标注**传播**下游（propagates_to） | --stable-diff 下游传播 warn（决策 28，Palantir markings-propagate 映射） |
| 计划**声明**门禁选择（plans） | gate-plan.json 声明 + --diff 收口（选择即证据，负空间可审计） |

上表 = links.md 10 条关系**全量**（表征系 4 条落校验轴机制、依赖系 6 条落边界轴机制——§0.3 的 2×2 投影在此自证）；机制不派生自目录外关系（类型封闭性）。

**反推纪律（这条冲程的执法）**：每个机制必须能回答"我实现本体里的哪条关系"。答不出的机制是孤儿——要么删掉，要么先回本体补定义再实现。这一条直接继承 R13 的"概念落地问责"，但从"落地"深化到"从本体派生"。

**创造纪律（这条冲程的第二执法，费曼推论——audit-claims-reality 轮固化，即决策 35）**：反推纪律问"机制从哪条关系派生"，创造纪律问"机制是否被创建且被运行"——**声称的机制必须能被创建（可运行）且被运行（CI/断言接线），否则视为不理解、不得声称**。只存在于文档的机制不是实体，是传闻；机器锚是创造证明，CI 接线是占有证明。固化依据（2026-08-24 轮 44 项"声称-现实"裂缝全部可归约为两类创造缺失）：①设计了没实现——precheck 启动接线在 source 前死调用（exit 127 被吞）、生成物 hooks 装错目录 + `|| true` 兜底静默失效、G-cognition/SKILLMD 预算空头断言；②实现了没接线——`_count_advisory_only` 定义后零调用（最能抓漂移的函数自身是死代码）、九个测试写完即脱钩（CI 绿≠它们过）、sarif-fixture 无 runner、Windows .bat 步骤被 `|| echo` 吞成永绿。

##### 冲程二：本体驱动设计（新需求来了怎么想）

传统思路：新需求 → 想加什么功能 → 实现功能清单。
本体驱动思路：新需求 → 四问推导 → 功能只是推导链末端的投影：

1. **这引入什么新实体？**（进 objects.md——本体论节俭：想清楚它跟已有类型的区别）
2. **实体间产生什么新关系？**（进 links.md——这条关系的语义是什么）
3. **新关系的机器锚是什么？**（没有锚的关系 = 未来的漂移 bug——历史上全部漂移 bug 的统一根源）
4. **锚怎么检测失效？**（进 self-check 对账或 ontology-verify 健康检查）

四问答完，实现是水到渠成的；四问没答就写代码，就是 R13 之前五轮膨胀的老路。

**示例（四问走一遍——R15 ref_trace_hash 的实际推导）**：需求"决策记录与执行证据要可配对"→①新实体？无——复用既有 Decision/Ledger 类型；②新关系？有：`anchors`（decisions 行 → trace 末行，进 links.md）；③机器锚？`ref_trace_hash` 字段 = trace.jsonl 末行 cksum；④锚失效怎么检测？ontology-verify 锚四抽验 digest 链——失配即全链 stale 可检出。四问走完，实现收敛为 trace-log.sh 一个字段 + 对账点两处，没有多余设计。

##### 冲程三：本体驱动演进（系统怎么成长）

成长史 = 本体的丰富史 + 依赖的锚定史。这个视角把整个演化过程串成一条线：

- **R13 之前**：本体是隐式的（没人写下"存在什么"），机制凭感觉加——机制与本体漂移，声称的关系没有锚（12 vs 13、6355 vs 6393 这类漂移 bug 全是这么来的）
- **R13**：清理"机制↔本体"的错位——机械打分退役，因为它声称测"理解"，但本体里根本没有"理解"这个实体，只有行为记录
- **R14**：补关系——goal 闭环、证据态、双账本（"账本记录过程"这条关系的深化）
- **R15**：补锚——digest 链、gate-plan、audit-closure（给无锚关系配上断裂检测）
- **R16**：本体显式化——assets/ontology/ 三目录成为事实源，机制↔本体可机器对账
- **以后每次演进**：先改本体目录 → 派生实现 → 对账验证收尾。本体先行，实现跟随。

##### 冲程四：本体约束行为（AI 怎么被管住）

Palantir 的一句话在这个系统里的对应："你建不出绕过治理的看板，因为看板读的是受治理的对象" ↔ **AI 做不出绕过门禁的操作，因为操作过的是受治理的规则和账本**。

- AI 读到的不是一堆散文档，是类型名词（17 类型）+ 封闭动作空间（11 动作——每个都有治理载体和留痕载体）——三份类型目录带"何时读我"路由头随生成物分发，设计新机制/演进本体/对账时读取，不占每会话认知面
- 想直接改文件？挂载在宿主上的 hooks 拦（mounted_in 关系生效）
- 想改账本抹痕迹？integrity-guard 的自指防护拦（Ledger 是受治理对象）
- 想跑危险命令？rules.d 三值判 forbid，FORBID 消息带替代方案——**在受约束空间里指路，而不是在自由空间里祈祷**

### 6.3 发动机与仪表盘（四冲程与四坐标系的本质关系）

发动机（四冲程）是动力；效果需要在维度上**可观测**——这就是四坐标系（时间/产物/校验/边界）的位置。它们不是四个"视角"（此前表述的错误），而是**本体结构沿闭环流展开的必然测量维度**——本体有什么结构，流上就有什么维度可测：

| 本体结构 | 沿流展开为 | 测什么 |
|----------|-----------|--------|
| **实体二分 · 发生体**（occurrent：生成/会话/决策/审计） | → **时间轴** | 流段、相位、消费频次（"两体系统"是这里的观测） |
| **实体二分 · 持续体**（continuant：仓库/技能/规则/账本） | → **产物轴** | 载荷、出口预算、税（"税制"是这里的观测） |
| **关系二分 · 表征关系**（represents/records/snapshot_of/closes——aboutness 一系） | → **校验轴** | 表征可信度：指向/覆盖/时效（"三层 Harness"是校验点在此轴的相位分布） |
| **关系二分 · 依赖关系**（generated_by/governs/mounted_in/anchors/propagates_to/plans——dependence 一系） | → **边界轴** | 依赖连通：输入口/执行口/锚（"三层接线/宿主下沉"是这里的端口） |

**为什么恰好是四个**：实体有两大范畴（BFO 的 continuant/occurrent 顶级二分），关系有两大类（哲学两大关系传统：aboutness 与 dependence——links.md 的 10 条关系恰可完备二分为 4+6）。2×2=4，不多不少——**四坐标系是本体结构的投影定律，不是设计者的分类趣味**。

每个冲程的效果都落进这四个维度可验：冲程一派生的机制落在校验轴/边界轴（锚在哪、验什么）；冲程二的产出落在产物轴+时间轴（新实体进载荷、新过程进流段）；冲程三的演进轨迹四轴皆留（本体改了哪格、哪条锚补了）；冲程四的行为约束在校验轴（拦截率）+时间轴（会话过程）上可测。**没有仪表盘，发动机是否在做功无从知晓；没有发动机，仪表盘测的是一台停着的机器。**

### 6.4 本体本身（引擎的燃料）

- **实体**：17 类型（objects.md）——仓库/组件/技能/规则/账本/门禁/决策/目标...；刻意**不承诺**的：AI 的"理解"、认知分数（不可观测的东西不进本体，只承诺其行为记录）
- **关系**：10 条（links.md）——每条带机器锚（关系的实例可验证存在）
- **动作**：11 个（actions.md）——封闭空间，每个动作可审计

三份目录是事实源（与 facts.conf 的数字口径平行），self-check 对账 18 实存点，ontology-verify 六锚健康检查。

##### 范畴工具箱（附录：学术工具，非主体）

需要精细刻画时才用的工具（来源见文末）：continuant/occurrent 二分（持续体 vs 发生体——恰好解释了"两体系统 vs 闭环流"不是矛盾是两个范畴）；部分学（部分 ≠ 构成材料——税制管的是构成不是部分）；Quine 承诺（承诺 = 量化遍历的实体）。这些是**镜头**，引擎是上面四个冲程。

##### 调研来源

- BFO：[bfo-ontology.github.io](https://bfo-ontology.github.io/) / [Wikipedia](https://en.wikipedia.org/wiki/Basic_Formal_Ontology) / [IEEE 教程](http://ieeexplore.ieee.org/document/7288715/)
- 部分学与构成：[SEP: Mereology](https://plato.stanford.edu/entries/mereology/) / [Baker](https://people.umass.edu/lrb/files/bak02onmS.pdf) / [Evnine](https://kathrin-koslicki.squarespace.com/s/Simon-Evnine-Constitution-and-Composition.pdf)
- 本体论承诺：[SEP: Ontological Commitment](https://plato.stanford.edu/entries/ontological-commitment/)
- Palantir 本体论工程：[Ontology Overview](https://palantir.com/docs/foundry/ontology/overview/) / [Why create an Ontology?](https://palantir.com/docs/foundry/ontology/why-ontology/) / 本仓 R11 报告

### 6.5 闭环流（系统的过程形态）

```
代码仓库 →① 生成段（探查+装配）→② 产物段（目标技能，出口受税制预算门约束）
  →③ 使用段（AI 按需 grep 地图做拼装式开发，行为被条件实时拦截）
  →④ 账本段（全量留痕）→⑤ 回流段（审计+评测校验体系自身，改进写回①②）
```

**自成长是闭环流的闭合条件**——砍掉回流边，系统退化为一次性脚手架生成器。

### 6.6 流上的流速与流量

- **厚薄**：①段知识一次性消费（厚是投资），③段产物每会话重复消费（厚是税）——"两体系统"就是这个消费频次差的旧名
- **流量阀**：profile 四档参数化①段装配多少
- **出口预算门**：②→③ 边界上，固定税 ≤8KB / 认知面 ≤256KB / 概念 ≤5（机器断言）
- **校验相位**：③段事中门禁、④段事后审计、⑤段对校验器自身的元评测——"三层 Harness"就是校验点在流上的三个相位
- **对外端口**：①段输入端口（三层接线取外部证据）、③段执行端口（hooks 挂宿主）

### 6.7 四个测量维度（本体结构沿流的投影定律）

闭环流被发动机驱动（§0.2 四冲程）做功，做功效果在四个维度上可测——**四维不是选出来的视角，是本体 2×2 结构的必然展开**（实体二分 × 关系二分，推导见 §0.3"发动机与仪表盘"）：

| 维度 | 从本体哪格展开 | 测什么 | 在此维度上的历史语言 |
|------|---------------|--------|---------------------|
| **时间轴** | 发生体（occurrent） | 流段/相位/消费频次 | 两体系统（厚薄=频次差）、四档 profile（流量阀）、三层 Harness 的相位分布 |
| **产物轴** | 持续体（continuant） | 载荷/出口预算/税 | 税制（≤8KB/≤256KB/概念≤5）、五层一棵树（载荷拓扑） |
| **校验轴** | 表征关系（aboutness） | 表征可信：指向/覆盖/时效 | 三层 Harness（门禁=事中/审计=事后/评测=元）、path-check/计数核验/stability-audit |
| **边界轴** | 依赖关系（dependence） | 依赖连通：输入口/执行口/锚 | 三层接线（①段输入口）、宿主下沉（③段执行口）、digest 链（锚） |

**历史层次语言的归位由此成立**：每套语言都是对某个维度的观测记录（两体系统=时间轴频次观测、税制=产物轴出口观测、三层 Harness=校验轴相位观测、三层接线=边界轴端口观测）——它们不冲突，因为本体的 2×2 结构只有四格，每套语言各守一格。九条内核与贯穿原则跨格（不变量与守恒律，见 §2.1 与 §9.1）。

---

### 6.8 文档元信息

##### 本体与主线

本体 = 一条自成长闭环流（图与闭合条件见 §0.5）；各章层次语言（两体系统/税制/三层 Harness/三层接线/五层树/九条内核……）都是本体 2×2 结构沿闭环流的投影观测（§0.7 四维表逐套归位）。

##### 问题定义（五轮诊断从未动摇的内核）

**AI 编程工具的短板不在代码生成能力，而在项目认知。** 同行（spec-kit/BMAD/SuperClaude）只做 spec 生成或 prompt 工程；"质量门禁的规模化强制"是 swarm-yuan 的目标域。

**拼装式开发是应用层目的**（奠基期用户原话，sess_4782d626 2026-07-03）：认知不是为了看懂项目，是为了**基于稳定可靠的组件进行拼装式开发**——尽可能复用项目既存的接口/组件/类/函数/方法等稳定单元，规避破坏性改造、重复造轮子、浸入式重构。这是特征卡第 11 项"可复用稳定单元清单"与地图"稳定性标注"的存在理由：探查产出 = AI 拼装时的零件目录。

##### 文档边界

- 本文件 = **设计层**（为什么这样做、做什么、做到什么程度算对）
- `swarm-yuan/references/` = **方法论层**（怎么做的细节指引，41 份全带"何时读我"路由头，按需读取）
- `docs/research/` = **证据与调研史**（R1-R13 调研报告，留档不删）
- 运行时机制（脚本/门禁/hook）不在本文档详述——它们的**设计规格**在 §4-§8，实现在仓库代码。

## §7 验收与复审

> 设计若不能被验收就是空谈。本章把前六章的声称收敛为 12 条可机器复核的终态指标——每条都有断言或例程兜底，不靠形容词。

| # | 指标 | 终态 | 度量方式 |
|---|------|------|----------|
| 1 | 每会话固定税（SKILL.md+hooks+settings+conf） | ≤8KB | gen-e2e §7.6 断言（产物 SKILL.md ≤ FACT_SKILLMD_BYTES_BUDGET） |
| 2 | 生成物概念体系 | ≤5 | 人工评审 |
| 3 | 冷启动到读项目代码动作数 | ≤3 步 | 定义：mark-active 后新会话到首个 Read/Grep 项目源码 |
| 4 | 门禁可达率 | 100%（55/55） | 默认执行序列可触达 / FACT_GATES_TOTAL |
| 5 | 地图预算 | 32KiB 硬顶 | self-check 断言 |
| 6 | description ≤1024 字符 / SKILL.md 正文 ≤8KB | 达标 | gen-e2e §7.6 断言（锚定生成物，非生成器自身 SKILL.md——工具入口不在此预算） |
| 7 | 认知面体积（references 拷贝） | ≤256KB | self-check 断言（当前 252KB） |
| 8 | 结构性：反向引用数 | 0 | G19 断言 |
| 9 | 连接性：孤儿资产数 | 0 | G18 扫描 |
| 10 | 有效性：恒零拦截门禁 | 季度质疑清单 | gate-trends |
| 11 | 适配性：三档差异化 | gen-e2e 断言（lite 无 hooks.json / compliance 含 industry 注入） | gen-e2e |
| 12 | 成长性：吸收落地率 | 100%（decisions.jsonl phase=absorption） | decision-audit 抽样 |

**测试资产矩阵**（tests/ 19 脚本 + CI 三平台）：

| 类 | 测试 | 守护 |
|----|------|------|
| 核心机制 | test-gate-rules / test-fail-gate-hook / test-failure-detector / test-ai-judgment | 三值求值+审批沉淀 15 态/hook 拦截/deny 审计/AI 判断引导模式（含机械退役确认） |
| 探查与自成长 | test-project-fingerprint / test-inventory-verify / test-inventory-update / test-detect-frameworks | 指纹+last-good 15 态/计数核验+path-check+stability 14 态/地图单条更新 9 态/框架检测 |
| 生成与模板 | test-conf-render / test-cost-report / test-context-surface / test-compare-baseline | conf 渲染+industry 注入/成本汇总/上下文预算/基线对比 |
| 门禁与规格 | test-framework-evidence / test-migrate-verify-blocks / test-signal-index / test-spec-task-type-gating / test-spec-template-gating | 框架证据台账/verify 块迁移/信号索引/任务类型门控/spec 模板门控 |
| E2E | tests/e2e/run-gen-e2e.sh + run-e2e.sh | 生成产物质量回归（含三档差异化断言）+ 全流程 |

CI：Linux 全覆盖（generator-self-gate 自举三档 + fixture 双态 + verifier + shellcheck + e2e）；macOS/windows 轻量腿（bash 硬前置下的诚实分层）。

治理节奏：批次之间至少间隔一个真实使用周期（用当前形态生成真实目标技能验证后再进下一批）——慢本身就是防复胖。

---

**这份文档自己就是证据。** 它声称"降复杂度的东西自己不能失控"，于是它把自己置于 §7 的 12 条机器断言之下——门禁数被预算冻结、认知面被字节封顶、孤儿资产被扫到零。一份能约束自己展开方式的设计文档，才有资格约束 AI 写代码的方式。读懂了这句话，就读懂了 swarm-yuan：它不是一套规则清单，是一台用自身证明"约束可以内生"的发动机。

## §8 证据与档案索引

> 设计文档之外的支撑材料（非设计主旨，按需查阅）：

| 材料 | 位置 | 内容 |
|---|---|---|
| 决策史 + 历史档案 | `docs/design-evolution.md` | 35 条决策全文 + A1-A14 施工档案（过程记录） |
| 使用手册 + 术语 | `docs/usage-manual.md` | 特征卡/门禁/生成流程/FAQ/数字一览（操作层） |
| 运行时基线登记 | `docs/upstream-baseline.md` | 16 运行时许可证/版本/drift 状态（供应链机器锚） |
| 调研证据链 | `docs/research/` | R1-R16 调研报告（决策史引用的外部项目调研过程档案） |

## License

MIT — see [LICENSE](../LICENSE)

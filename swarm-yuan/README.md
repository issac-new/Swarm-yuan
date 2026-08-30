# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。

[![Release](https://img.shields.io/badge/release-v2.6.1-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6.1)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 全文导读：五层递进 + 引用

本文档是 swarm-yuan 的**唯一文档**，按认知递进组织——每一层回答上一层引出的问题，逐层从"为什么"走到"怎么用"，最后以引用层收录全部证据原文：

| 层 | 回答的问题 | 对象 |
|----|-----------|------|
| 一、理念 | 它为什么存在？信仰什么？ | 所有人 |
| 二、设计 | 理念如何变成可执行的原则？ | 所有人 |
| 三、架构 | 原则如何落成系统结构？ | 用户与维护者 |
| 四、实现 | 结构如何成为真实机制？ | 维护者 |
| 五、使用 | 机制如何变成日常操作？ | 用户 |
| 六、引用 | 一切声称的证据在哪？ | 深读者 |

> 全部数字真值由 `assets/facts.conf` 机器执法（`scripts/self-check.sh`），本文不手抄维护——文中数字为发版时刻快照，以 facts.conf 为准。

---

# 第一层 理念——它为什么存在

## 1.1 问题：AI 写代码很强，认识项目很弱

AI 的代码生成能力已经很强，但「项目认知」仍是被多数工具忽视的环节——改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子、检查靠人工逐行 review。缺陷不在生成，在认知：AI 不认识你的项目就动手。

## 1.2 核心理念

**先认识，再行动。** AI 写代码前必须先认识项目——认知不是看懂代码，是为了让行动有依据。由此派生五条执政理念：

1. **拼装式开发**——新功能 = 既有稳定单元拼装 + 最小新增胶水。禁止重复造轮子、侵入式重构、破坏性改造。这是整个系统存在的应用层目的：探查产出的"可复用稳定单元清单"就是 AI 拼装时的零件目录。
2. **特征卡是立法，门禁是执法，验证器是司法**——特征卡定义「项目应该是什么样的」，门禁验证「代码是否符合」，独立验证器用 fixture 双态 + 字节级等价证明门禁本身有效。三权分立，互不越界。
3. **诚实降级**——运行时未装不阻塞（fail-open + 降级链），但降级必须显式披露，不假装全深度接线；权限边界一律 fail-closed。
4. **呈现递进的关系**——门禁不是"数 import 数"，每个计数背后指向一条关系规律；认知呈现的是结构关系而非符号堆。
5. **AI 全自动、零手动配置**——生成技能是 AI 一键完成；使用时研发人员对 AI 说话而非手动跑命令。

## 1.3 理念的自证要求

范式声称帮项目降复杂度，因此自身的复杂度必须有上限（负向预算，见 2.4）；范式声称门禁有效，因此必须被独立验证（司法层，见 4.5）；范式声称认知项目，因此认知结果必须落到真实路径与版本号、可机器核验（见 4.1）。**每条理念都要求一个可验证的兑现机制**——这是下一层（设计）的任务。

---

# 第二层 设计——理念如何变成原则

上层确立了"先认识再行动 + 三权分立 + 诚实"。本层回答：这些价值观在工程上以什么原则兑现。

## 2.1 两体系统：生成器厚、生成物薄

为兑现"认知充分"与"每会话低税"的矛盾要求，系统切成两个体：

- **生成器（厚）**：探查知识全量（79 框架规则、41 references、行业 profile、决策史）——只在生成时刻消费一次，允许厚。
- **生成物（薄）**：每会话重复消费，必须薄——SKILL.md ≤8KB、概念体系 ≤5 个、认知面 references 拷贝 ≤256KB，全部有机器预算断言。

## 2.2 生成物的三件套：地图 + 条件 + 演化链

薄生成物不是"少"，是"只装该装的"：

- **地图**（认知的承接）：组件/接口/约束清单，两列表 `| 路径 | 说明与约束 |`——路径供机器执法，说明列写 AI 的理解与稳定性标注；会话中按需 grep，不全量预读。
- **条件**（行动的守卫）：precheck 门禁 + hooks 强制 + draft/active 状态门——做错就被拦，不占认知预算。
- **演化链**（时间的承接）：项目变了技能跟着变——指纹感知 → 变化域局部重探查 → 单条更新 → 落新基线。

## 2.3 三层 Harness：强制、审计、评测

单靠门禁挡不住"绕过"，需要纵深：

| 层 | 管什么 | 兑现哪条理念 |
|----|--------|-------------|
| 过程强制 | rules.d 三值规则（allow/prompt/forbid 取最严）+ hooks 双宿主真实拦截（Claude Code deny / Codex exit 2） | 门禁执法 |
| 工作流审计 | 目标闭环（一个用户目标 + 一个验收边界，change↔validation 链接才 closed）+ 证据态分级（配置≠使用≠有效） | 诚实 |
| 评测 | digest 链式锚定（上游篡改全链可检出）+ 选择即证据 + 审计即完成条件 | 司法 |

## 2.4 范式作为条件而非内容 + 复杂度负向预算

- **条件而非内容**：机器执法只保留"防 AI 说谎"的条件类（路径存在性/计数核验/last-good 红线/状态门）；概念性内容不靠删除靠落地——每个机制必须有真实消费路径。
- **负向预算**（决策 26，追认于决策 26.2）：门禁数 ≤55、conf 变量 ≤200、认知面 ≤256KB——范式自身的膨胀被自己的门禁管住，兑现"帮你降复杂度的东西自己不能失控"。

---

# 第三层 架构——原则如何落成结构

上层原则在本层变成可见的系统结构。

## 3.1 总览

```
厚生成器（一次性消费）                薄生成物（每会话消费）
  探查知识库（79 框架规则/41 refs）     SKILL.md（≤8KB）
  行业 profile（conf-render 加载）      地图（≤32KiB 两列表）
  决策史/调研史                         rules.d 三值规则 + precheck + hooks（双宿主）
  generate-skill.sh（12 步生成流）      scripts 工具（按需调用，不算税）
                                              │
                                        目标项目（任意仓库）
```

## 3.2 门禁四族与执行面

55 个门禁分四族，各有真实触发路径（可达率 55/55 机器对账）：

| 族 | 数量 | 触发面 |
|----|------|--------|
| 核心 | 10 | `--all`（日常） |
| 架构 | 18 | `--all-full`（结构变更） |
| 合规 | 19 | `--compliance-suite`（强监管交付） |
| 专项/advisory | 8 | decision-audit/state-phase 专项（FULL-only 2）+ 宿主 hook 建议（advisory-only 6，真值 facts.conf） |

执行面三道：单命令（precheck）、hooks 强制（fail-gate-hook 双宿主拦截）、状态机阶段守卫（open→design→build→verify→archive→operate，每阶段核验前序产出物存在）。

## 3.3 运行时三层接线（13 个外部运行时）

只引用不重写，按接线深度分层，每层自带降级载体：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度（4） | GitNexus / graphify / claude-mem / ocr | 门禁内真实子进程 + 多级降级链 |
| CLI（4） | OpenSpec / comet / gsd-core / codex-security | 按需调用 CLI，降级自带载体 |
| 方法论（5） | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用模式 |

## 3.4 工作流：六阶段 ↔ 九节点

粗粒度状态（state-machine 六阶段）与细粒度执行（workflow 九节点）一体两面：open=①需求理解+②探查 ｜ design=③spec+④plan ｜ build=⑤编码 ｜ verify=⑥测试+⑦独立审查 ｜ archive=⑧合入 ｜ operate=⑨发布。spec-first 是硬前置——写源码而无已批准 spec 会被 hook 直接拒绝。

---

# 第四层 实现——结构如何成为机制

上层结构在本层落到具体机制与代码。

## 4.1 探查实现

- **框架规则引擎**：79 份框架规则（每份六段式：探查信号/构件枚举/领域规律≥10 条/门禁清单/跨框架交互/深化材料），探测激活后注入对应门禁片段。
- **特征卡防幻觉**：清单登记的每个路径由 `--path-check` 机器核验存在性；计数核验防虚报；mark-active 三关（零占位符 + 路径存在 + 决策留痕）才解锁全量门禁。
- **探查方法**：extraction-guide 全量穷举（非抽样），稳定单元五维字段（签名/路径/用途/复用方式/稳定性标注）。

## 4.2 约束实现

- **门禁实现**：三档 enforce（strict/warn/advisory）由 conf 声明、self-check 对账；fixture 双态（violating 必检出 / compliant 必通过）+ golden 向量锁行为。
- **hooks 双宿主**：Claude Code（hooks.json + CLAUDE_PLUGIN_ROOT 解析）与 Codex（`.codex/hooks.json` 嵌套 schema + exit 2 + stderr 透传）——schema 均对宿主源码逐字段核验。
- **三值规则**：rules.d/*.rules 随生成物分发，FORBID 无条件且必带替代方案。

## 4.3 演化实现

项目指纹（文件数/扩展名分布/骨架 cksum）秒级感知变化 → 变化目录即重探查范围（scope 局部） → inventory 单条更新（原子替换，条目骤降 >50% 触发 last-good 红线拒绝写坏清单）→ 落新基线。

## 4.4 留痕与审计实现

调用留痕（trace.jsonl）、决策留痕（decisions.jsonl，方向性决策须带 alternatives/代价）、digest 链（三本账链式锚定，上游篡改全链 stale 可检出）、gate-deny 落盘（每次拦截可复盘）。

## 4.5 自举与验证（司法层实现）

- **自举**：swarm-yuan 用自身门禁检查自身（CI generator-self-gate 三档 RC=0）——只证明内部自洽。
- **独立验证**：`verifier/v1`——79 fixture 双态、48 合规 gate-fixture、cli A/B 逐字节等价（HEAD↔工作区行为漂移检出）、golden 向量；外部有效性另由真实项目回归覆盖（见 6.7 证据链）。
- **质量基线真值**（机器执法）：门禁 55/55 可达 · references 孤儿资产 0 · 19 测试脚本 + gen-e2e + self-check RC=0 · CI ubuntu/macos/windows 三平台 · 双重点栈（vue+element 前端、SpringBoot+MySQL 后端）九节点真实交付验证。

---

# 第五层 使用——机制如何变成操作

## 5.1 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash install.sh        # 自动检测 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi
# Windows：先装 Git for Windows（或 WSL），再运行 install.bat——原生 cmd/PowerShell 不支持
```

## 5.2 生成与激活

```bash
# 对 AI 说："为 /path/to/project 生成开发技能"
bash scripts/generate-skill.sh <skill-name> <project-dir> [target-dir]   # 或命令行
bash scripts/generate-skill.sh --mark-active <skill-dir>                 # 三关核验后解锁全量门禁
```

## 5.3 日常（对 AI 说话，零手动）

"开始新需求：xxx"（触发 spec-first + 九节点流） / "跑门禁"（--all-full） / "升级 skill"（fingerprint 变化后 --upgrade） / "报了误报"（决策留痕豁免链）。

## 5.4 平台与运行时

- **三平台**：macOS（bash 3.2）/ Linux / Windows（Git Bash > WSL > MSYS2），CI 三平台矩阵背书；11 个 .bat 包装器随发。
- **运行时**：13 个外部运行时全部可选——未装自动降级且显式披露；安装后即真执行（v2.6 已实证全链）。口径区分（三个数字各有所指，不冲突）：13=接线运行时（深度 4+CLI 4+方法论 5）；上游基线登记 16 项（§6.4，含仅登记观察、未接线的条目）；self-check 自动检测 11 项（codex-security 经 npx 按需调用、impeccable 随 agents 技能目录，不在自动检测清单）。
- **命令手册**：完整命令级参考见 6.5 使用手册。

---

# 第六层 引用——证据与深读

本层收录全部原文：设计规格、零背景导读、决策史、上游基线、使用手册、历史档案、调研证据链。各件导读如下。

| 节 | 内容 | 何时读 |
|----|------|--------|
| 6.1 | 设计规格（DESIGN） | 单一设计事实源：本体论原理、架构规格、探查/约束/留痕/评测设计、验收——维护者逐条对账用。 |
| 6.2 | 零背景导读（PRIMER） | 写给零背景读者：术语首现即定义，读完能看懂系统为什么长这样。 |
| 6.3 | 决策史（paradigm-decisions） | 每个决策的完整记录（问题/决策/理由/后果）——查"为什么这么定"。 |
| 6.4 | 上游运行时基线（upstream-baseline） | 16 个上游运行时的许可证/版本基线/drift 状态登记表。 |
| 6.5 | 使用手册（USAGE） | 命令级使用参考：生成/激活/升级/门禁/审计全命令行手册。 |
| 6.6 | 历史档案 A1-A13 | 演化过程原文（定位/本体论/评审/升级报告等）。 |
| 6.7 | 调研证据链 | `docs/research/` 16 份调研报告（R1-R15）——决策史引用的外部项目调研过程档案，未整合。 |

## 6.1 设计规格（DESIGN）

> 单一设计事实源：本体论原理、架构规格、探查/约束/留痕/评测设计、验收——维护者逐条对账用。

> **文档性质**：swarm-yuan 的**单一设计事实源**——本体论驱动原理、闭环流动力学、定位理念、架构规格、决策演化史、验收，全部整合于此一份。原 DESIGN-ONTOLOGY.md / DESIGN-LOGIC.md 已并入本文档 §6.1 §0，历史原稿见 §6.6 A2/A3。
> **阅读顺序**：零背景读者先读本文 §6.2（零背景导读：术语首次出现即定义、易混概念辨析），再读 §6.1（设计规格）。
> **版本**：**终态 v4**（2026-08-21/22；v1=R13 终态整理，v2=+R14/R15，v3=并入本体论驱动原理与闭环流+8 份归档文档内容，v4=十轮排查修复＋设计一致性收口——数字虚报/工具入口表/references 全索引/奠基理念/测试矩阵/口径/仓库结构/读者可用性；收口=派生表 10 关系全量化、规则来源四层澄清、生成流程唯一编号 Step 1-12、本体层消费路径、账本落盘全景；2026-08-24 增量：audit-claims-reality 轮——44 项"声称-现实"裂缝四类修复 + 决策 35 创造纪律入 §0.2 冲程一，演进按四问协议追加的实例）。终态的含义：结构完整（§0 原理 → §1-9 设计 → §10 验收 → §11 档案）、与实现一致性机器可验（self-check 全绿项覆盖）、单一事实源地位确立——但**不是冻结**：演进按 §0.2 冲程二四问与 §6 演进协议追加，已知边界两项均已修复并登记于 §11 已修复边界（audit-claims-reality 同步：头部此前与 §11"已知边界：无"自相矛盾）。
> **证据基础**：zcode 会话库 32 个主会话全量提取（五轮"过重"诊断史）｜仓库病理量化诊断｜openai/codex 源码深挖（锚定 file:line）｜多轮排查与设计一致性收口的执行者自省。
> **方案总承诺**：R13 重构期（v2.0）每个迁移单元的 diff 必须为净减法或等量替换（新增 ≤ 删除，`git diff --stat` 机器验证）；R16 起新概念须过本体驱动四问（§0.2 冲程二——新实体进 objects.md 前想清区别、新关系必配机器锚），不设"永不新增"的绝对禁令——演进纪律从"数量冻结"升级为"结构约束"。

### 0. 本体论驱动原理（发动机——一切机制的上游）
#### 0.1 一句话

swarm-yuan 是被本体论驱动的生成系统：**先说清世界里有什么，一切机制从"存在"推导出来，一切演进从本体开始改，AI 的一切行为被本体约束**。本体不是对系统的描述，是系统的上游——机制是它的实现投影，演进是它的丰富过程，行为空间是它划出的边界。

#### 0.2 引擎的四个冲程

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

#### 0.3 发动机与仪表盘（四冲程与四坐标系的本质关系）

发动机（四冲程）是动力；效果需要在维度上**可观测**——这就是四坐标系（时间/产物/校验/边界）的位置。它们不是四个"视角"（此前表述的错误），而是**本体结构沿闭环流展开的必然测量维度**——本体有什么结构，流上就有什么维度可测：

| 本体结构 | 沿流展开为 | 测什么 |
|----------|-----------|--------|
| **实体二分 · 发生体**（occurrent：生成/会话/决策/审计） | → **时间轴** | 流段、相位、消费频次（"两体系统"是这里的观测） |
| **实体二分 · 持续体**（continuant：仓库/技能/规则/账本） | → **产物轴** | 载荷、出口预算、税（"税制"是这里的观测） |
| **关系二分 · 表征关系**（represents/records/snapshot_of/closes——aboutness 一系） | → **校验轴** | 表征可信度：指向/覆盖/时效（"三层 Harness"是校验点在此轴的相位分布） |
| **关系二分 · 依赖关系**（generated_by/governs/mounted_in/anchors/propagates_to/plans——dependence 一系） | → **边界轴** | 依赖连通：输入口/执行口/锚（"三层接线/宿主下沉"是这里的端口） |

**为什么恰好是四个**：实体有两大范畴（BFO 的 continuant/occurrent 顶级二分），关系有两大类（哲学两大关系传统：aboutness 与 dependence——links.md 的 10 条关系恰可完备二分为 4+6）。2×2=4，不多不少——**四坐标系是本体结构的投影定律，不是设计者的分类趣味**。

每个冲程的效果都落进这四个维度可验：冲程一派生的机制落在校验轴/边界轴（锚在哪、验什么）；冲程二的产出落在产物轴+时间轴（新实体进载荷、新过程进流段）；冲程三的演进轨迹四轴皆留（本体改了哪格、哪条锚补了）；冲程四的行为约束在校验轴（拦截率）+时间轴（会话过程）上可测。**没有仪表盘，发动机是否在做功无从知晓；没有发动机，仪表盘测的是一台停着的机器。**

#### 0.4 本体本身（引擎的燃料）

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

#### 0.5 闭环流（系统的过程形态）

```
代码仓库 →① 生成段（探查+装配）→② 产物段（目标技能，出口受税制预算门约束）
  →③ 使用段（AI 按需 grep 地图做拼装式开发，行为被条件实时拦截）
  →④ 账本段（全量留痕）→⑤ 回流段（审计+评测校验体系自身，改进写回①②）
```

**自成长是闭环流的闭合条件**——砍掉回流边，系统退化为一次性脚手架生成器。

#### 0.6 流上的流速与流量

- **厚薄**：①段知识一次性消费（厚是投资），③段产物每会话重复消费（厚是税）——"两体系统"就是这个消费频次差的旧名
- **流量阀**：profile 四档参数化①段装配多少
- **出口预算门**：②→③ 边界上，固定税 ≤8KB / 认知面 ≤256KB / 概念 ≤5（机器断言）
- **校验相位**：③段事中门禁、④段事后审计、⑤段对校验器自身的元评测——"三层 Harness"就是校验点在流上的三个相位
- **对外端口**：①段输入端口（三层接线取外部证据）、③段执行端口（hooks 挂宿主）

#### 0.7 四个测量维度（本体结构沿流的投影定律）

闭环流被发动机驱动（§0.2 四冲程）做功，做功效果在四个维度上可测——**四维不是选出来的视角，是本体 2×2 结构的必然展开**（实体二分 × 关系二分，推导见 §0.3"发动机与仪表盘"）：

| 维度 | 从本体哪格展开 | 测什么 | 在此维度上的历史语言 |
|------|---------------|--------|---------------------|
| **时间轴** | 发生体（occurrent） | 流段/相位/消费频次 | 两体系统（厚薄=频次差）、四档 profile（流量阀）、三层 Harness 的相位分布 |
| **产物轴** | 持续体（continuant） | 载荷/出口预算/税 | 税制（≤8KB/≤256KB/概念≤5）、五层一棵树（载荷拓扑） |
| **校验轴** | 表征关系（aboutness） | 表征可信：指向/覆盖/时效 | 三层 Harness（门禁=事中/审计=事后/评测=元）、path-check/计数核验/stability-audit |
| **边界轴** | 依赖关系（dependence） | 依赖连通：输入口/执行口/锚 | 三层接线（①段输入口）、宿主下沉（③段执行口）、digest 链（锚） |

**历史层次语言的归位由此成立**：每套语言都是对某个维度的观测记录（两体系统=时间轴频次观测、税制=产物轴出口观测、三层 Harness=校验轴相位观测、三层接线=边界轴端口观测）——它们不冲突，因为本体的 2×2 结构只有四格，每套语言各守一格。九条内核与贯穿原则跨格（不变量与守恒律，见 §2.1 与 §9.1）。

---

#### 0.8 文档元信息

##### 本体与主线

本体 = 一条自成长闭环流（图与闭合条件见 §0.5）；各章层次语言（两体系统/税制/三层 Harness/三层接线/五层树/九条内核……）都是本体 2×2 结构沿闭环流的投影观测（§0.7 四维表逐套归位）。

##### 问题定义（五轮诊断从未动摇的内核）

**AI 编程工具的短板不在代码生成能力，而在项目认知。** 同行（spec-kit/BMAD/SuperClaude）只做 spec 生成或 prompt 工程；"质量门禁的规模化强制"是 swarm-yuan 的目标域。

**拼装式开发是应用层目的**（奠基期用户原话，sess_4782d626 2026-07-03）：认知不是为了看懂项目，是为了**基于稳定可靠的组件进行拼装式开发**——尽可能复用项目既存的接口/组件/类/函数/方法等稳定单元，规避破坏性改造、重复造轮子、浸入式重构。这是特征卡第 11 项"可复用稳定单元清单"与地图"稳定性标注"的存在理由：探查产出 = AI 拼装时的零件目录。

##### 文档边界

- 本文件 = **设计层**（为什么这样做、做什么、做到什么程度算对）
- `swarm-yuan/references/` = **方法论层**（怎么做的细节指引，40 份全带"何时读我"路由头，按需读取）
- `docs/research/` = **证据与调研史**（R1-R13 调研报告，留档不删）
- 运行时机制（脚本/门禁/hook）不在本文档详述——它们的**设计规格**在 §4-§8，实现在仓库代码。

### 1. 定位与适用域

#### 1.1 范式定位一句话

**swarm-yuan 是"生成器厚、生成物薄"的两体系统**——生成时刻允许厚（探查知识全量，一次性消费），生成物必须薄到近乎无形（每会话固定税 ≤8KB、概念体系 ≤5）。重量在生成器侧是投资，在生成物侧是税——税制有机器预算。

#### 1.2 适用 / 不适用

| 适用 | 档位 | 不适用 | 替代 |
|------|------|--------|------|
| 团队协作（≥2 人） | standard | 个人脚本/一次性原型 | AI 裸写 |
| 中大型（≥80 文件） | standard | 极小改动（typo） | 直接改 |
| 强监管/合规交付 | compliance | 无 AI 辅助的纯人工开发 | 传统 lint/test |
| 长期维护（技能须跟项目演进） | 任意档 | 只要门禁不要认知设施 | 单文件 precheck.sh |
| 小项目要基础门禁 | lite | | |

**范式外轻量方案**（不套本范式的替代）：① 单文件 precheck.sh——直接拷 `swarm-yuan/assets/precheck.sh` 到项目，配 precheck.conf 跑 `--all` 核心门禁，不建 skill 目录；② 传统工具链——ESLint/Prettier/golangci-lint/pylint + Git hooks；③ AI 原生裸写——一次性任务直接对 AI 说需求。

#### 1.3 与历史定位的差异（诚实记录）

2026-07（WP-P10）定位是"重量级范式，重量是设计选择"——那是真实，也是五轮"过重"诊断反复追问的对象。R13（2026-08-21）后修正为两体系统：**重量没有消失，只是归位**——生成器侧 ~68K 行自举仍在（一次性消费不算税），生成物侧 ~25 文件、概念负担从 150+ 记忆槽降到 5 个层次名词。

**起源（ncwk 孵育史，2026-07）**：swarm-yuan 诞生于 ncwk 项目工作区——2026-07-02 用户首次提出"根据材料模板生成 skill"（sess_b55848b0），原始需求一句话：为具体项目生成供研发人员开发使用的 skill、完成需求交付全流程；同日澄清分层——swarm-yuan 是 Skill A（元技能生成器），ncwk-dev（后改名 Swarm-studio）只是 Skill B（第一个示例产物）。2026-07-03 首次推送 issac-new/Swarm-yuan（68b609c）；2026-07-21 独立 project 开始主会话。**与 hermes-studio 的关系**：hermes-studio 是 ncwk 的第三方上游依赖（EKKOLearnAI/hermes-studio），swarm-yuan 诞生于 ncwk 但与其无代码依赖、无命名同义、无组件包含关系——swarm-yuan 是独立仓库本体。

### 2. 设计理念

#### 2.1 稳定内核（九条，五轮从未动摇；第⑨条为 ncwk 奠基期深挖补录）

① 元技能生成器定位 + 六段式产物结构；② "AI 短板在项目认知不在代码生成"；③ 零占位符铁律 + draft/active 状态门；④ 单文件 precheck 可移植；⑤ 三层接线 + 降级链 + 调用不重实现；⑥ 自适应轻重（质量优先于效率）；⑦ facts.conf 单一事实源；⑧ "账面与实质一致"三层诚实化（数字/修辞/证据）；⑨ **AI 全自动、零手动配置**（奠基期铁律，sess_4782d626/sess_d466cc75 反复强化）：生成 skill 是 AI 一键完成（探查→填充→配置→验证全自动）；skill 使用时研发人员对 AI 说话而非手动跑命令——SKILL.md 是 AI 读的（写"零手动"铁律），USAGE 层保留 bash 双轨制（排查/CI/脚本场景需要）；安装的一次性 `cp -r` 不属于"日常使用"，允许手动。

#### 2.1.1 奠基理念四条（README 对外口径的四个理念，ncwk 期确立）

| 理念 | 含义 |
|------|------|
| **先认识，再行动** | AI 写代码前必须先认识项目。特征卡完成认知，门禁守护行动——"认知 DNA"（特征项是项目认知的基因图谱） |
| **呈现递进的关系** | 门禁不是"数 import 数"——每个计数背后指向一条关系规律（计数核验 0.95 是表征覆盖度的关系性度量） |
| **分层整合，诚实降级** | 运行时按深度接线（4 深度子进程/4 CLI/5 方法论引用）三层整合，每层有自带降级载体，未装不阻塞，不假装全深度接线 |
| **领域知识防达克** | 领域知识库（`references/domain-knowledge.md`，计数真值 facts.conf）——AI 探查时识别技术+业务领域、推导客观规律驱动 `--domain` 违规检测，防止对不熟悉领域自信地写出错误代码 |

#### 2.2 R13 新增两条理念

**范式作为条件，而非内容**：机制分两类——**条件**（运行时约束行为、零认知占用、糊弄结构上不可能）与**内容**（要 AI 先读先记再自觉、每会话重复付税、糊弄结构上必然）。机器执法只保留"防 AI 说谎"的条件类；"给理解打分"与"防文档数字漂移"的内容类退役或转落地化。AI 的理解深度由行为证据兜底（测试过没过/门禁红不红/决策留没留痕），不由表格验证。

**落地优先于删除**：概念/门禁/profile/references 一概不删——病根是"没有正确落地"（机械打分/僵尸孤立/无路由），全部转为真实消费路径：概念→AI 判断引导+留痕；僵尸门禁→全接线；孤立 profile→conf-render 真实加载；无路由文档→"何时读我"路由头。

#### 2.3 失败方向教义（条件类的补充原则）

权限边界一律 fail-closed（默认全拒、白名单放行）；**fail-open 只允许发生在还有下层强制兜底的地方**（如 hooks 失败不阻断，因命令还要过门禁；规则文件解析失败退最小规则集）。每个 SKIP/降级路径按此逐处复核。

#### 2.4 对外叙事边界（祛魅红线，sess_fcc61435 外部评审校准）

对外讲 swarm-yuan 的不可逾越红线（外部评审曾点破浮夸风险——"内核合理的方案被过度营销语言包装"）：
1. **"100% 可靠"禁用**——verifier/v2 外部有效性未达成前，对外禁用 100%；用"已验证组件 + 受约束生成 + 独立校验"三段式。
2. **"10⁻¹⁰"标注**——使用方推演模型非工具输出；引用必须带出处说明。
3. **具体数字归属**——"103 组件"是某目标项目的枚举产物非 skill 硬数字；"90% 采纳率"若源自计划表必须标"计划口径"。
4. **"三权分立"**——是叙事隐喻，真实拓扑按治理 agent 实际；对外用时标注。
5. **本质表述**——swarm-yuan = **bash 脚本 + Markdown 挂在 AI 编码助手 hooks 上**（写代码前拦截、交差时独立验证）+ 本地观测；不是纯 PPT 工程，也不是集群平台。

#### 2.5 平台分工教义

harness（宿主 CLI：Codex/Claude Code）管 agent loop/沙箱/审批通道；**应用侧（swarm-yuan 生成物）管项目上下文、业务规则、操作边界**。生成物不碰 harness 内部（会话管理/审批实现/OS 沙箱），只做应用侧资产（地图/规则/hooks 注册）。token 纪律即能力（官方实测 ARC-AGI-3 上下文纪律 13.3%→38.3%）——生成物每字节税稀释有效上下文占比，直接降能力。

### 3. 终态架构

#### 3.1 两体系统总览

```
厚生成器（一次性消费，可厚）          薄生成物（每会话重复消费，必须薄）
  探查知识库（79 框架规则/41 references）   SKILL.md（≤8KB：何时用/约束摘要/入口/路由/元规则/自成长）
  行业 profile（7 份，conf-render 真实加载）  地图（≤32KiB：两列表 |路径|说明与约束|）
  探查/渲染/自检脚本                     spec 9 节核心 + workflow 9 节点×4 要素
  决策史/调研史（§6.3）                  rules.d/*.rules + precheck + hooks（双宿主）
                                      scripts（按需调用的工具，不算税）
```

#### 3.2 生成物文件级规格

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

#### 3.3 结构性保障（层依赖显式单向）

五层一棵树：生成 → 探查（产地图）/ 约束（rules.d+precheck+hooks）/ 演化（fingerprint+inventory-update）/ 留痕（trace+decisions）。单向边由目录物理隔离承载：references/ 不 import scripts/（self-check G19 反向引用=0 断言）；每层唯一入口命令；分层失败隔离（地图坏不影响约束；rules.d 缺失降级最小规则集）。五层各有章节着落：§8 生成 / §4 探查 / §5 约束 / §6 演化 / §7 留痕。

#### 3.4 兄弟工具与装配关系（外部系统边界澄清）

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

#### 3.5 三层 Harness 总览（过程强制 + 工作流审计 + 评测）

| 层 | 职责 | 核心机制 | 落地版本 |
|----|------|----------|---------|
| 过程强制门禁层 | 开发过程中实时拦截违规 | 门禁四族（真值见 facts.conf）55/55 可达 + rules.d 三值（allow/prompt/forbid 取最严，FORBID 带替代）+ hooks 双宿主（Claude deny JSON / Codex exit 2）+ 沙箱通配符 deny | v2.0（R13） |
| 工作流审计层 | 事后复盘"工作流是否可信" | goal_id+closure（审计单元=一个用户目标+一个验收边界）+ 证据态分级（Present/Wired/Exercised/Outcome-supported）+ 双账本（当窗验证 vs 跨窗效果）+ repair_review | v2.2（R14） |
| 评测层 | 评测自身的可信度 | ref_trace_hash（三本账链式锚定，上游篡改全链 stale）+ missing_evidence（该测没测）+ gate-plan（选择即证据，负空间可审计）+ audit-closure（审计即完成条件） | v2.3（R15） |

三层关系：门禁层做事中拦截（条件），审计层做事后复盘（证据），评测层做评测自身可信（元证据）——每层消费下层的账本（gate-runs → goal 聚合 → 链式锚定），互补不竞争。

#### 3.6 工程一致性三矩阵（宣称→可核对的事实）

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

#### 3.7 概念体系收敛与方法论承载

只允许 5 个层次名词为主轴：**探查 / 约束 / 演化 / 留痕 / 生成**。认知框架类概念（六阶链/六维动力学/三元演化/七推理/辩证范畴/五维偏差/思维模型）不删除不堆砌——以“工作时按此思考”的指引式表述融入对应层次，落地为 AI 判断引导（逐维自查 → `.swarm-yuan/notes/cognition.md` 留痕，GATE_AI_JUDGMENT 唯一模式；骨架的“工作时的思考框架”表四行：探查按六阶链/思考用逻辑剃刀/决策三级分类/纠偏辩证+领域防达克）。本体层词汇（17 类型/10 关系/11 动作，§0.4）不占这 5 个概念预算——它是机器对账的类型事实源（§0.2 冲程一），不是叙事概念体系：AI 只在设计新机制/演进本体/对账时经“何时读我”路由读取，不进每会话认知面。

**方法论 references 承载表**（40 份全带“何时读我”路由头，核心 10 份职责）：

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

**references 全承载索引**（40 份全列，按六类——每份都是真实消费路径，孤儿=0 由 self-check G18 执法）：

| 类 | 文件 |
|----|------|
| 探查方法论（4） | exploration-guide.md / template-spec.md / generation-flow.md / code-graph-tools.md（图谱工具选型平权） |
| 认知框架（4） | cognition-framework.md（五层基底）/ logic-razor.md / cognitive-bias.md / domain-knowledge.md（领域防达克） |
| 编排与审查（4） | subagent-orchestration.md / review-methodology.md / task-methodology-router.md / gsd-patterns.md |
| 外部吸收方法论（10） | codex-methodology.md / codex-security-methodology.md / claude-code-capabilities.md / dsh-engineering-methodology.md / cordis-composability-methodology.md / mea-loop-methodology.md / agent-skills-methodology.md / frontend-design-methodology.md / context-engineering-layering.md / memory-persistence.md |
| 治理与合规（11） | decision-governance.md / governance-agents.md / standards-compliance.md / quality-management-standards.md / crypto-spec.md / cwe-database.md（门禁内部数据）/ security-spec.md / security-certification-profiles.md / mcp-governance.md / ai-process-records.md / canary-monitoring.md |
| 行业 profile（7） | industry-profile-finance.md / industry-profile-medical.md / industry-profile-gov.md / industry-profile-automotive.md / industry-profile-energy.md / industry-profile-industrial.md / industry-profile-telecom.md（法规依据文档，与 conf 配对——conf-render --industry 真实加载） |
| 案例与骨架 | case-studies/articulation-orchestration.md（对外汇报论据）/ workflow.md·reference-manual.md 等骨架由生成器产出 |

### 4. 探查设计（认知层）

- **形态判定先行**（§C+.0）：backend/frontend/async/desktop/mobile/lib/common，维度适配由 `inventory-dimensions.conf` 承载；不预设项目类型。
- **全量穷举 + 计数核验**：组件清单 ≥ 枚举计数 × 0.95；`--path-check` 杀幻觉路径（HALLUCINATION 阻断 mark-active）；`--stability-audit` 三机械信号（git churn/fan-in/测试存在性）与标注冲突 → STABILITY_WARN（advisory）。
  > **实证来源（sess_733ff1c4, 2026-07-11）**：ncwk-dev 初版只列 10 个组件，真实代码库有 99 .vue + 8 store + 12 adapter + 17 loop 模块——样本化填充仅 10% 覆盖。0.95 红线由此定：强制穷举 + 三层调用链（注册装配/模块依赖矩阵/组件挂载树）+ 编排约束 6 类（导入方向/注册顺序/路由挂载/文件落位/状态所有权/测试边界，每条须代码证据）+ 接口全量枚举禁通配符。
- **两维表规范**：地图行 = `| 路径 | 说明与约束 |`。路径反引号包裹（path-check 校验存在性）；说明列写"它是什么+接口/约束+稳定性标注词"（"导出 add（禁止改）"——stability-audit 按行内字面词识别，与列位置无关）。维度/来源等纯记账列已退役（R13）。说明列执行**语义/动能两区纪律**（R16 本体层口径，是/应当不混写）：说明列是表征区——只写"是什么"（组件/接口/依赖/稳定性标注词的引用）；"应当怎样"的规范执行体只落 rules.d/*.rules 与门禁，地图至多引用规范词、不承载执行逻辑（地图骨架自带该纪律说明，links.md 使用纪律第 3 条同口径）。
- **特征卡**：P0 六项强制 / P1 十一项可增量（draft 期「（P1 待补）」允许，mark-active 前清零）；探查期产出，受检不自证。

#### 4.1 框架规则引擎格式契约（79 框架规则的结构约定，方案 A 选型 2026-07-17；74→79 见 WP-P2-extension）

**规则文件 `references/frameworks/<fw>.md` 六段式**：frontmatter（ruleset_id/适用版本/最后调研来源）→ §1 探查信号（依赖/注解/文件/配置四类，各带置信度——§C+.0.5 激活依据）→ §2 特定构件枚举（命令+计数核验基准）→ §3 领域规律（≥10 条，每条五要素：适用版本/规律/违反后果（挂 CWE 或官方 issue）/验证方法（具体 grep 命令）/对应门禁 id）→ §4 门禁清单（id/级别/实现逻辑/依赖 conf 变量）→ §5+ 深化材料。

**门禁片段 `assets/framework-gates/<fw>.sh`**：与规则 md 1:1 配对（框架证据台账对账），注入目标 precheck.sh 标记区块（`# >>> swarm-yuan:framework-gates >>>`），生成与 --upgrade 共用幂等注入，区块 sha 记录漂移检测。

**生成时数据流**（步骤编号用 §8.1 唯一口径）：§C+.0.5 探查 → ACTIVE_FRAMEWORKS+版本 → ④.5 框架深化（Step 7 填充期内：逐框架读 md，信号确认→构件枚举→规律种子实例化附证据）→ ⑦.5 门禁注入（Step 10.5 独立审查后：--inject-frameworks 注入门禁片段+生成 framework-knowledge.md 骨架+填 conf 变量）→ Step 12 最终检查四要素量化验收（规律数≥门槛且 100% 含证据字段，不过回 ④.5）。

**ncwk-dev 反哺机制**：已实战验证的手写框架检查（vue/naiveui/pinia/koa/socketio/vite/vitest 7 框架 28 项）先反向收割进片段库作种子，再经注入回灌——"从成功实践反哺范式库"，片段库起步即有高质量样本。

### 5. 约束设计（门禁层）

#### 5.0 逻辑错误的兜底链（field-feedback 2026-08-26 补）

门禁是词法/结构模式匹配——抓"不懂规矩"，不抓"想错逻辑"。逻辑错误的兜底是**测试+审查**，且机器层对兜底本身有核验（不假装"提示了就算做了"）：

| 兜底 | 机器核验点 | 产物载体 |
|------|-----------|---------|
| 测试 | check_test：TEST_CMD 退出码 + 0 用例检出（"0 passed"输出 warn）；check_shift_left：spec §11 测试策略段非占位核验 + test 先于 impl 提交 | spec §11 测试策略表 + 测试套件本身 |
| 审查 | check_review：docs/reviews/<YYYY-MM-DD>.md 存在（三要素：评审人/日期/结论）；合规档 check_review_record 全要素+零 TBD | docs/reviews/<日期>.md（模板 assets/review-record-template.md 随生成物分发） |

#### 5.1 门禁族与可达率

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

#### 5.2 三值规则引擎（Codex Decision 架构 bash 落地）

- **规则即数据**：`rules.d/*.rules` 行格式 `<pattern(glob)> → <allow|prompt|forbid> # <justification>`；求值器 `scripts/gate-rules.sh`（多规则命中取最严 forbid > prompt > allow）。规则来源四层：①底座两套内置示例（bash-advance 推进态 / readonly-safe 只读白名单——全档位随生成物分发，见 §5.3）；②探查期生成的项目特有规则；③审批沉淀写入（见下）；④`framework-globs.rules` 是 conf glob 默认值快照、非三值规则（运行时消费者 = self-check G21 对账锚，见 §5.4 与 §11 已修复边界②）。
- **三值作用域**：只作用于"命令该不该跑"的判定（Bash 命令放行，那里有宿主审批通道）；门禁家族不重分类。
- **拒绝消息 = 给模型的 API**：`FORBID <rule-id>: <原因>；替代：<方案>`——拒绝携带替代方案，AI 能自动改道。
- **自指防护**：integrity-guard 双层保护——deny 层拦机器维护区/司法层/规则自身（framework-gates/gate-enforce-level.conf/verifier/rules.d/*.rules/gate-rules.sh，改了就是治理绕过）；advisory 层提醒 facts.conf/账本（decisions/trace）——账本必须可被留痕机制写入，deny 会自锁，故只提醒重跑（无"执行前哈希自校验"机制，旧表述已废）。
- **审批沉淀**：临时放行持久化为规则——`gate-rules.sh --persist "<pattern>" <verdict> "<justification>" [--goal <id>]`（写 rules.d/approved.rules + 沉淀日期；同步 trace-log --decision 落痕 UserChallenge 决策，R14 起含 goal_id/closure/repair_review、R15 起含 ref_trace_hash 链式锚定）。校验三防：verdict 白名单/forbid 须含替代/同 pattern 幂等拒绝（改判先删旧行）。fail-gate-hook 的 deny 消息携带该命令（FORBID 消息 = 给模型的 API——拒绝即指路）。

#### 5.3 宿主下沉（双宿主真实拦截）

- **Claude Code**：fail-gate-hook（PreToolUse deny JSON + PostToolUse flag 捕获）+ settings.local.json 沙箱通配符 deny（`Read(**/.env)` 等，v2.1.236 防重命名绕过）。
- **Codex**：hooks.json PreToolUse → `codex-gate-wrapper.sh`（JSON deny 解析 → **exit 2 + stderr 透传**，v0.148 官方语义）。
- hooks 五件套：failure-detector.sh（SPINNING 检测+L1 提示）、integrity-guard.sh（自指防护）、fail-gate-hook.sh（门禁拦截）、setup-loop.sh（Oracle Gate 初始化）、loop-hook.sh（Stop 时 loop-oracle 接线 + 30 分钟超时）。
- rules.d 内置两个示例规则集随生成物分发：bash-advance.rules（推进态命令：git push/commit/merge→prompt，npm publish/rm -rf/git reset --hard/sudo→forbid 各带替代方案）、readonly-safe.rules（只读白名单：git status/log/diff、ls/cat/grep、precheck 自身→allow）。
- hooks fail-open 的合法性：有下层门禁兜底（§2.3 教义）。

#### 5.4 conf 面收缩

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

### 6. 演化设计（成长层）

- **生成物自成长链**：fingerprint 感知（SessionStart/手动 --diff）→ 变化目录 scope 报告（局部重探查，不整仓重扫）→ inventory-update 单条更新（replace/delete/append §4/§6/§9，原子替换 + 决策落痕）→ last-good 红线（文件数骤降 >50% 拒绝 --write，需 --force）→ `--commit-fp` 落新基线。局部重探查产出的新组件经 `inventory-update append` 入地图（AI 按自成长链操作显式入账，非隐式自动写——探查产出先给 AI 判稳，再登记，决策落痕）。
- **生成器成长通道**：吸收一律走"调研报告（docs/research/）→ 三问评审 → 落地为条件/路由/引导之一"（phase=absorption 留痕 decisions.jsonl）；上游重核从全量改为破坏性变更驱动（breaking/major 触发 + 季度例行）。
- **生成器演进协议**（R16 起，本体先行——§0.2 冲程三的工程化）：新机制/新概念先过冲程二四问——新实体进 objects.md、新关系进 links.md（必配机器锚）、新动作进 actions.md；再派生实现；收尾跑 self-check 类型对账 + ontology-verify 六锚。吸收三问（准入评审：要不要吸收）与本体四问（设计方法：怎么落地）串联——先三问、后四问。
- **成长的预算约束**：成长 = 预算内替换（新知识进来必须有旧知识出去或税不增），否则只是膨胀。

### 7. 留痕设计（追踪层）

- **trace.jsonl**：节点级调用落盘（stdout 公告 `→ [节点X] 调用 …` + `trace-log.sh --node/--key-node/--decision`）；永不 fail 阻塞主流程。
- **decisions.jsonl**：G1 决策治理（三级分类 Mechanical/Taste/UserChallenge + outcome 生命周期 proposed/implemented/rejected/superseded + 未采纳决策照常落盘 + 回放规则不可变——旧行无 outcome 视 implemented）。R14 增 `goal_id`+`closure`（审计单元目标闭环化：一个用户目标+一个验收边界，change↔validation 链接才 closed）+ `repair_review`（修复复核位：verified/partial/blocked，空=pending）。
- **gate-audit.jsonl**：fail-gate 全量决策审计（invoked/result 单行自包含 + 稳定 handler id + target 截断 500 + 休眠不写）；`--report` 四段（最近决策/拦截率按 handler/deny 聚合/工具分布）。R14：gate-report 增证据态分级（配置≠使用≠有效）——落地三级（Present/Exercised/missing_evidence；Wired/Outcome-supported 由 gate-trends 双账本承载，未落地，登记候选）；gate-trends 双账本（当窗验证 repair_verified_rate + guardrail 配对 vs 跨窗效果 Loop Effectiveness——后者需两次执行对比，诚实声明登记候选）。
- **gate-runs.jsonl**：门禁执行流水（每次 precheck 运行追加一行带 run 序号，`GATE_RUNS_DIR` 非空启用）——SARIF 证据链、连续零发现统计（metrics 门禁）、gate-trends 趋势的数据源。
- **key-nodes.jsonl**：九节点关键调用看板。
- **gate-plan.json**（R15 评测层）：任务开工的门禁选择声明（enable/skip + 理由，负空间可审计）；`scripts/gate-plan.sh --plan/--diff` 收口对比计划 vs 实际触发（missing_evidence/计划外/skip 违反，advisory）。
- **decisions.jsonl `ref_trace_hash`**（R15 评测层）：decisions 记录引用 trace.jsonl 末行 cksum——三本账从并列升级为**链式**（上游篡改 → 失配 → 全链 stale 可检出；HarnessEval evidence tree 的 bash 最小切片）。
- **audit-closure 完备性**（R15 评测层）：`scripts/audit-closure.sh` 按 goal_id 全集重走 closure 完备性（open/closed 分布 + open goals 列表）；`--strict` 有 open 时 exit 2，串 mark-active advisory 门（审计即完成条件）。

**落盘全景**（`.swarm-yuan/`）：四本账 = trace / decisions / gate-runs / gate-audit（objects.md `Ledger` 类型的四个实例）；辅助存盘 = key-nodes 看板 + gate-plan 声明 + 指纹快照 + notes/。

### 8. 生成设计（流程 + 生成物模板规范）

#### 8.1 生成流程（Step 1-12 唯一编号口径）

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

#### 8.2 生成物模板规范

- **spec-template 9 节核心必填**：背景与目标 / 决策记录 / 复用·版本·安全三约束 / 测试策略 / 风险与回滚 / 左移三节（§19 测试设计/§20 变更影响/§21 可观测性） / 标准合规。其余节（详细设计/分层设计/参考/§14-18 认知仪式/运营）**默认折叠**——`--task-type full` 的复杂变更才展开。
- **workflow 4 要素**：入口（顺序/并行）/ 参与方 / 质量门禁 / 产出物与追踪（含 trace-log 调用）；原 10 要素中分支/流程控制/状态控制并入产出物说明。
- **生成后核对清单 12 项**：机器验证四件套（零占位符/path-check/计数覆盖/mark-active）+ P0 核心映射八项；历史 96 项细目在折叠区保留为方法论参考（非 mark-active 前置）。
- **plan-template**：任务条目须含完成判据（test/命令/可观察结果/交付物——"Implement the thing"不算计划）。

### 9. 决策原则与演化史

#### 9.1 防复胖四制度（贯穿原则——跨四维度成立的现行守恒律；生成器侧条件）

1. **概念落地问责**：新概念进 SKILL.md/生成物必须给出落地路径（接线/AI 判断引导/路由，不接受"先放着"）。
2. **吸收三问**：①能否落到运行时条件？②替换还是叠加？③六个月后谁引用？——不过只留调研报告，不进 references。
3. **生成物税制**：进 UNIVERSAL_FILES 的审核问题 = "目标 AI 每会话为它付多少税"；机器载体 = 体积/字节预算断言。
4. **五维复审**：季度跑 §10 指标 8-12（结构/连接/有效/适配/成长），与 gate-trends 季度报告合并，不新增例程。

#### 9.2 决策史索引

- **奠基期（ncwk，2026-07-02 ~ 07-19，决策 0 域）**：特征卡 9→12→13→14→16 项演化（12 项=用户首次明确"全部 12 项"；13/14=+认知基底/辩证范畴；15/16=+编排约束/详尽组件库清单——为修复"样本化填充 10% 覆盖"缺陷专门加入）；"左移"三节由用户一句话加入（2026-07-11）；三平台兼容硬约束由"脚本在 Windows 下不可用"触发（_resolve_path 可移植函数 + .bat 包装器全覆盖）；框架规则引擎方案 A 选型（内置框架库+门禁片段+生成时注入，2026-07-17，详见 §6.6 A6（原 2026-07-17 框架规则引擎设计）；ncwk-dev 手写的 7 框架 28 项检查反向收割为片段库种子——从成功实践反哺范式库）；skill 上传四项规则（脱敏/路径泛化/去内部代号/推送前确认，首次发布确立）；运行时管理规则（research/ 仓库永远 checkout 最新 stable release tag，detached HEAD，永不 push）
- **决策 1-17**（早期，2026-07-20 后）：本文 §6.6 A5 归档卷
- **决策 18-29**（自适应/诚实化/Palantir 期）：本文 §6.3 前部
- **决策 30-32**（自适应偏置/门禁分层/上下文压缩）：同上
- **决策 33**（范式作为条件而非内容——R13 去抽象化重构与落地优先原则）：同上
- **决策 34**（概念落地问责 + 吸收三问 + 生成物税制——防复胖三制度）：同上
- **决策 35**（创造纪律——未创建且未运行的机制不得声称，audit-claims-reality 轮）：同上
- **R12 调研**（DeepSeek Harness dsh rc.8 重调研，2026-08-20）：产品层四簇机制识别——决策审计/状态韧性/增量自成长/工程纪律；WP-R12-A/B/C/D 四批落地（fail-gate deny-only→全量决策审计 + 方法论四载体 + dir_cksums scope 感知 + decisions.jsonl outcome 生命周期）；guard/ 澄清为循环卫生非权限守卫。详见 `docs/research/R12-dsh-rc8-resurvey.md`。
- **R13 重构**（去抽象化，2026-08-21，即决策 33/34 + 终态方案 v6）：五批次落地——落地化接线（认知计分退役转 AI 判断引导/十门禁全接线 54-54/industry 真实加载/40 references 路由头）、模板减负（spec 仪式节折叠/workflow 10→4 要素/核对清单 96→12/五维表→两维表）、条件化（rules.d 三值/FORBID 带替代/G18/G19 断言）、生成器瘦身（SKILL.md 142→93 行/facts 21 键退役/check_doc 434→70 行/税制断言）、宿主下沉（Codex hooks/settings 沙箱 deny）。方案全文 `docs/research/R13-final-plan.md`（v6）。
- **R14 吸收**（阿里云 Qoder Better Harness，2026-08-21）：审计/复盘/趋势三层机制落地——审计单元目标闭环化（decisions.jsonl 增 goal_id+closure）、证据态分级（gate-report.sh 输出的"§4.2 证据状态分级"段：Present/Wired/Exercised/Outcome-supported + 分数上限）、双账本（gate-trends：Repair Progress 当窗验证 + guardrail 配对指标）、修复复核位（decisions.jsonl 增 repair_review）。与过程强制层（门禁）互补不竞争。详见 `docs/research/R14-better-harness-absorption.md`。
- **R15 吸收**（MirroS HarnessEval，2026-08-21）：评测层 Harness 落地——digest 链式锚定（decisions.jsonl 增 ref_trace_hash：三本账从并列升级为链式，上游篡改全链 stale 可检出）、missing_evidence 态（gate-report 证据态加"该测没测"≤59）、gate-plan 选择即证据（`scripts/gate-plan.sh`：启用/跳过理由负空间可审计，收口 diff 计划 vs 实际触发）、audit-closure 审计即完成条件（`scripts/audit-closure.sh`：goal 闭环完备性重走，串 mark-active advisory 门）。三层 Harness 拼图完整：过程强制门禁层（R13 前）+ 工作流审计层（R14）+ 评测层（R15）。详见 `docs/research/R15-harnesseval-absorption.md`。
- **实现符合性收口**（impl-conformance，2026-08-23）：DESIGN 宣称 vs 实现逐章对账后的补齐——①审批沉淀从宣称变实现（gate-rules.sh --persist：写 approved.rules + decisions.jsonl 落痕 + 三重校验，§5.2）；②CI 长红修复：WP-Q2H-B 降 check_framework=advisory 后三层断言（fixture 双态退出码/E2E fail 链/verifier 判据）未跟上新语义，统一改为"检测命中 expected-fail-ids"（检出能力是被验证物，违规不阻断是设计语义），golden-vector 重建；③facts.conf 三键真值同步（SCRIPT_LOC 5917/UNIVERSAL_FILES 58/UNIVERSAL_FILES_CORE 30——R14-R16 新增条目后长期漂移，C1 与行数断言终于全绿）；④G14/G17 absorb 三载体补齐（SKILL.md 引用行）；⑤G21 新增：framework-globs 快照对账锚；⑥detect-profile-drift 自扫守卫（关 §11 边界①）。
- **audit-claims-reality 轮**（第一性原理审计 + 修复，2026-08-24）：三路并行审计（设计↔实现/脚本质量/测试-CI-verifier）发现 44 项"声称-现实"裂缝，MECE 四类修复 6 commit——A 功能断裂 11（precheck 启动接线复活/生成物 hooks 归一 scripts/ 并补 gen-e2e mounted_in 锚/BSD sed 破窗等）+ B 口径 7 组（合规 19/advisory-only 6/FULL 48 闭合方程、conf 176/16、自检 11、Step 1-12）+ C 执法 7（self-check 子族六键+conf 变量四键+G-cognition 等值断言接线、SKILLMD 预算首个消费者、九孤儿测试接 CI、Windows .bat 步骤真断言化、test-to-sarif）+ D 卫生 7（根级 tests/ 出册、DESIGN 头/§11 矛盾闭环、死代码清理、date -u 统一）。固化决策 35（创造纪律，§0.2 冲程一第二执法）。
- **R16 重构**（本体论驱动，2026-08-21）：显式本体层落地——`assets/ontology/` 三份类型目录（objects 17 类型含负面承诺/links 10 关系各配机器锚/actions 11 受治理动作）作为与 facts.conf 平行的**类型事实源**；self-check 类型对账（18 实存点）；`scripts/ontology-verify.sh` 六锚一站式健康检查；地图骨架语义/动能两区纪律（是/应当不混写）；本体层带"何时读我"路由头随生成物分发（G18 孤儿扫描覆盖 assets/ontology/）。设计闭环：本体论驱动原理（本文 §0）→ 类型事实源 → 机器对账 → 运行时健康检查。

演化模式定型为"吸收→膨胀→诊断→减重"五轮循环；R13 是第一个以落地化（而非加法治理）收口的循环。

#### 9.3 历史专题决策的存续原则（三份决策文档的有效结论）

**范式审计五类因果削弱与修复原则**（2026-07-20 审计，10 项已修 + 刻意不修清单）：算术骨架成立但因果链被四类问题削弱——①崩溃（set -e+pipefail+空数组，修复原则：grep 管线加 `|| true`、空数组 `${ARR[@]+"${ARR[@]}"}` 防护）；②静默跳过（未配置门禁跳过仍显绿，修复原则：SKIP 显式披露）；③存在性自证（对范式自带模板判 pass，修复原则：模板自证闭合）；④文档数字漂移（修复原则：facts.conf 单源+机械对账）。**刻意不修原则**：修复会改变门禁判定行为且无 fixture 覆盖时，不贸然"唤醒沉睡门禁"——先补 fixture 再评估苏醒影响（五层认知基底装饰性叙事的处置即循此原则，直至 R13 以"机械计分退役"根治）。

**不 vendor 上游核心插件决策**（superpowers v6.1.1 案例，2026-07-20）：四理由——①体积（offline zip 已 44MB，vendor 20+ skills 本体进一步膨胀分发成本）；②维护面（vendor 即承担逐版重核，上游六周 5 tag 迭代快，而文档级方法论引用无运行时收益——纯为引用背维护负担）；③许可证敞口（marketplace 编目 10 插件各有独立 license，不 vendor 则收敛在单 MIT 元数据）；④生态（正规获取路径是插件市场在线安装，vendor 静态副本脱离更新通道）。**存续原则：方法论引用不 vendor、运行时调用才考虑深度整合——"调用不重实现"的最低成本形态**。

**机械 vs AI 边界评审结论**（q2-heavy-review，2026-07）：D1 探索式 gate（cognition/diagram/pr_quality 等）应转 AI 自觉判断——机械 grep 误报高；D2 "假装可机器"的门禁（taste 判定类）降 warn；D4 生成流程过度脚本化环节让 AI 判断。**R13 全量落地**：GATE_AI_JUDGMENT 唯一模式 + 机械计分退役 + spec 仪式节转按需——评审结论已从建议变为现状。

OS 沙箱（宿主职责，吸收决策架构不复制实现）/ Guardian LLM 分类器（bash 层不建，只留形态约定）/ 重实现供应链检测工具（复用 --deps 版本锁定 + SBOM 许可证块名单——调用不重实现）/ Starlark 解释器（行格式规则即可）/ 会话 SQLite 投影（trace.jsonl 够用）/ 迁移工具（手工升级一次）/ harness 内部（exec/SDK/app-server 是宿主集成层）。

### 10. 验收与复审

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

### 11. 档案与证据索引

**历史设计文档**（内容已并入本文件，原文降级为档案，保留不删——查历史演变用）：
- §6.6 A3 = 原 `docs/DESIGN-ONTOLOGY.md`（本体论驱动原理 v1-3 稿，已并入 §6.1 §0.1-0.4/0.8）
- §6.6 A2 = 原 `docs/DESIGN-LOGIC.md`（闭环流+四维度 v1-3 稿，已并入 §6.1 §0.5-0.7）
- §6.1 §1 = 原 `docs/paradigm-positioning.md`（v2 定位，已并入）
- §6.1 §2/§9 = 原 `docs/design-philosophy-consistency.md`（理念一致性，已并入）
- §6.6 A6-A8 = 原 `docs/2026-07-17-framework-rules-engine-design.md` / `2026-07-20-*`（历史专题设计，已并入）
- §6.6 A9 = 原 `docs/q2-heavy-review.md`（机械 vs AI 边界复盘，已并入）

**决策史原文**：本文 §6.3（决策 18-35）+ §6.6 A5 归档卷（决策 1-17）——§6.1 §9.2 是索引，§6.3/A5 是详情。

**调研证据**：`docs/research/`（R1-R9、R11-R15，R10 无报告——仅 v2 立项稿提及待测品类；R13 三份：final-plan 方案 v6 / codex-deep-dive Codex 源码证据 / de-abstraction 复盘草稿；R14/R15 吸收报告各一份）——调研报告是证据的合法归宿，不晋升 references（吸收三问）。

**按需参考文档**：`swarm-yuan/references/`（41 份，全部带"何时读我"路由头）——方法论细节按需读取，本文件不再复制其内容。

**对外案例**：`swarm-yuan/references/case-studies/articulation-orchestration.md`（关节编排对外汇报的论点→能力映射）；temppt 四个会话（PPT V41→V81 迭代史 + sess_fcc61435 外部评审祛魅记录）是 §2.4 对外叙事红线的来源。

**仓库全量结构地图**（第九轮 find 全量枚举对账——每个目录在文档中的定位）：

| 位置 | 内容 | 定位 |
|------|------|------|
| 本文 §6.1（原 docs/DESIGN.md） | 设计规格（单一设计事实源 v4，规格层） | 设计层 |
| 本文 §6.2（原 docs/DESIGN-PRIMER.md） | 设计入门（零背景版：解释层——术语首次出现即定义、易混概念辨析、阅读地图；不承载规格，数字指向 facts.conf） | 解释层（第 0 读） |
| 本文 §6.3 + §6.6 A5（原 docs/paradigm-decisions{,-archive}.md） | 决策史原文（1-35） | §9.2 索引的详情 |
| 仓库根 docs/research/ | R1-R9、R11-R15 调研报告（R10 无报告——仅 v2 立项稿提及待测品类） | 证据层（吸收三问的合法归宿） |
| （原 docs/plans/，已随单一文档整合删除） | 4 份历史计划文档（framework-rules-engine / research-plan / standards-gap / paradigm-slimming，2026-07） | 历史计划存档（已执行完毕，不维护） |
| `swarm-yuan/SKILL.md` | 生成器入口（AI 读） | 产品文档（§3.2 读者双轨制） |
| 本文 §6.5（原 swarm-yuan/docs/USAGE.md） | 使用手册（研发人员读——bash 双轨制的落地文件） | §3.2 读者双轨制 |
| §6.6 A13（原 swarm-yuan/docs/PROMO.md） | 推广文案存档 | 对外口径（受 §2.4 祛魅红线约束） |
| §6.6 A12（原 swarm-yuan/docs/FIVE_DIMENSIONS.md） | 五维审查详表存档 | 方法论层附件 |
| `swarm-yuan/assets/` + `scripts/` + `references/` + `tests/` | 门禁/脚本/方法论/测试（§5.1 工具入口表+references 全索引+测试矩阵已覆盖） | 实现层 |
| `swarm-yuan/ci/self-precheck.conf` | CI 自举最小 conf（generator-self-gate job 用） | §3.6 三平台 CI 矩阵 |
| `swarm-yuan/install.sh` + `.bat` | 安装器（检测 7 个 AI 工具环境） | 入口工具 |
| `swarm-yuan/assets/hooks/`（源）→ 生成物 `scripts/`（hooks.json 配置在 `hooks/`） | hooks 五件套源文件 | §5.3 宿主下沉 |
| `verifier/v1/` + `v2/` | 司法层（v1 现行：golden-vector 79 + cli A/B；v2 外部有效性立项稿） | §5.1 验证器 |
| `verifier/baselines/` + `runs/` | 基线快照与运行记录 | 证据层 |
| `swarm-yuan/offline-cache/` | 离线包（仅 marketplace 元数据，不 vendor 核心插件） | §9.3 vendor 决策 |
| `.github/workflows/ci.yml` | CI 三平台（Linux 全覆盖 + mac/win 轻量腿） | §3.6 |
| `.swarm-yuan/`（项目级，运行时生成） | 四本账（trace/decisions/gate-runs/gate-audit）+ key-nodes 看板 + gate-plan 声明 + 指纹 + notes | §7 留痕设计的落盘位置 |

**已知边界**（登记待修，非设计内容；已修复的移入下条修复记录）：无。

**已修复边界**（impl-conformance，2026-08-23）：① `detect-profile-drift.sh` worktree 自扫误报——加自扫守卫（识别 swarm-yuan 仓布局即跳过）；② `framework-globs.rules` 快照无消费者——self-check G21 对账锚（快照 43 变量 vs arch.conf 集与值一致，漂移可检出）。

---

> **本文自身的验证边界**：本文是设计叙述——"对错"是叙述与实现是否一致、映射是否牵强，只能靠人工对照代码与 self-check 对账审阅；测试套件（单测/gen-e2e）测不到"设计是否讲清楚了"。真正的检验是 §0.2 冲程二的四问能否被后续每轮改动无歧义地回答。
>
> **修订纪律**：本文件是单一设计事实源——新设计决策追加到对应章节（或 §9 决策史索引新增条目），不再新建散落设计文档；references/ 的运行时指引继续按需维护在各文件内。任何"数字/计数"表述引用 `assets/facts.conf` 真值，本文不内联（R13：不手抄即无漂移）。


## 6.2 零背景导读（PRIMER）

> 写给零背景读者：术语首现即定义，读完能看懂系统为什么长这样。

> **这份文档是什么**：swarm-yuan 的完整设计说明，写给**没有任何项目背景**的读者——不需要读过任何历史文档，按顺序往下看就能看懂整个系统为什么长这样。
> **它在文档体系里的位置**：本文是"第 0 读"（解释层，负责让人理解）。另有两份权威载体分工不同：本文 §6.1 是规格书（维护者逐条对账用，原 docs/DESIGN.md），`swarm-yuan/assets/facts.conf` 是所有数字的权威来源。三者冲突时，数字以 facts.conf 为准，规格以 §6.1 为准，本文负责"让人能读懂那两份"。
> **阅读约定**：每个术语在**第一次出现**时就用一句话定义，全文同一个概念只用同一个名字；文末 §7 有易混概念辨析，§8 有术语词典。

---

### 1. 一句话与三分钟版

**一句话**：swarm-yuan 是一个用 bash 写的"技能生成器"——对着任意一个代码仓库运行一次，它就产出这个项目专属的 AI 编码助手规则包（称为**目标技能**），这个规则包先教 AI 认识这个项目（立法），再在 AI 每次动手改代码之前检查规则（执法）。

**三分钟版**：

1. **问题**：AI 编程助手的短板不在"写代码"，在"不认识项目"——它不知道这个项目的分支规矩、目录分层、哪些文件是稳定资产不能乱碰、改动会影响谁。给 AI 一篇规矩文档没有用，因为文档没有强制力，AI 读完会忘、会糊弄。
2. **解法**：swarm-yuan 把"认识项目"做成一张**特征卡**（17 项探查清单，从项目类型到稳定单元清单——这是立法），再把特征卡翻译成一个可执行的规则包（目标技能），规则包里有一组**门禁**（机器检查脚本，AI 每次改代码前自动运行——这是执法）。立法和执法分离：规矩是数据，检查是机器。
3. **例子**：指着某个 Spring Boot 仓库跑一次生成器，得到的目标技能会知道"这是 Maven 多模块、MyBatis 持久层、master 分支保护"，之后 AI 每次要改代码，门禁会自动检查：分支名合不合规、有没有碰声明为"稳定"的模块、MyBatis 的写法有没有踩这个仓库的坑——不合规就拦下或警告。

它的本质形态（祛魅，有一说一）：**bash 脚本 + Markdown 文件，挂在 AI 编码助手的 hooks 上**（hooks = 宿主助手提供的"在特定时机自动执行脚本"的机制，比如"写文件前""会话结束时"）。不是平台，不是集群，不联网。

---

### 2. 它解决什么问题（为什么存在）

**① AI 的短板在项目认知，不在代码生成**（设计的第二公理）。大模型写代码能力很强，但它第一次见到你的仓库。它会写出语法正确但违反项目惯例的代码：在该用工厂的地方 new、在稳定模块里加依赖、把分支推错地方。这类错误的共同点是"不懂规矩"，不是"不会写"。

**② 规矩必须执法，不能只立法**。很多项目有 CONTRIBUTING.md / 开发规范文档，但 AI（以及新人）不读、读不全、读完不遵守。swarm-yuan 的立场：规则只有变成"每次行动前自动运行的机器检查"才存在。所以目标技能里最重要的资产是门禁，不是文档。

**③ 每个项目的规矩都不一样，手写规则包太贵**。给每个项目手工写一套 AI 规则，维护成本不可持续。所以做一个**生成器**：探查一个仓库的客观事实（技术栈、结构、约定），自动生成该项目专属的规则包。生成器只做一次重活，产出的规则包要足够轻（AI 每次会话都要加载它，重了就是税）。

**④ 任何"声称"都必须机器可验**。这是本项目最独特的自我约束：设计文档里写的每一个机制、每一个数字，都必须有一个会自动运行的检查来证明它真的存在、真的是这个数。这条约束的来源和含义见 §3.5 和 §3.6。

---

### 3. 核心设计思路（七个大想法，按理解依赖排序）

#### 3.1 立法-执法分离：特征卡定规矩，门禁做检查

整个系统的第一性结构是"立法"与"执法"分离：

- **特征卡**（17 项探查清单）= 立法。它回答"这个项目是什么样子的"：项目类型、可改范围、技术栈、构建命令、分支规范、测试体系、稳定单元清单、合规基线……17 项由 AI 探查仓库后填写，探查结果沉淀为目标技能的配置文件（**conf**，一组 KEY=VALUE 变量，当前 178 个）。
- **门禁**（机器检查函数）= 执法。每个门禁是一个 bash 函数（如 `check_branch` 查分支规范、`check_stable_diff` 查稳定单元有没有被改），读 conf 里的规矩，对当前改动给出四种结果之一：**pass**（通过）/ **fail**（阻断，必须修）/ **warn**（警告，不阻断）/ **skip**（未配置该规矩，明示跳过——跳过不等于通过，单独计数，防止"没配规矩"被当成"规矩都满足"）。

为什么是分离的？因为规矩随项目变（数据），检查逻辑不随项目变（代码）。同一个门禁函数，在不同目标技能里读不同的 conf，就检查不同的规矩。

> 数字口径：17 项特征卡、184 个 conf 变量、55 个门禁——均以 facts.conf 为准。

#### 3.2 生成而非手写：一个生成器，产出 N 个目标技能

swarm-yuan 自己是**生成器**（也叫"元技能"——生成技能的技能）。它对着某个项目跑一次**生成流程**（12 个主步骤，唯一口径见 `swarm-yuan/references/generation-flow.md`），产出该项目的**目标技能**。生成流程是"脚本做机械节点 + AI 做判断节点"的分工：自检、骨架生成、占位符核验由脚本做；探查仓库、填特征卡、配置 conf 由 AI 做（AI 全自动、零手动配置是奠基期铁律——研发人员对 AI 说一句话，而不是自己跑命令）。

目标技能生成出来是 **draft**（草稿态：骨架已建但特征卡未填满，此时禁用全量门禁，防止"半成品看起来很完整"），AI 填充并验证无占位符后转 **active**（激活态，全量门禁解锁）。

#### 3.3 重量级显式可选 + 两体系统

本系统不假装轻量。它把"重"拆成两半并各自管理：

- **生成器侧厚**：79 个框架的规则库、41 份方法论文档、生成/自检脚本——这些只在"生成目标技能"时消费一次，厚不构成税。
- **生成物侧薄**：目标技能是被 AI **每次会话**加载的，每字节都是税（稀释 AI 的有效上下文）。所以生成物有硬预算：入口文件 SKILL.md ≤8KB、项目地图 ≤32KiB（预算由 facts.conf 键值定义，生成流水线里有机器实测）。

轻重的程度用 **profile 档位**显式选择：**lite**（小项目，核心门禁+最小文件集）/ **standard**（默认）/ **compliance**（强监管交付，加合规矩阵与 19 个合规门禁）/ **auto**（按项目规模+合规信号+技术栈复杂度自动判定，判定偏置是"质量优先"——拿不准就往重档走）。

#### 3.4 本体论驱动：先说清世界里有什么，机制只是投影

这是全部机制的"上游"。本系统先把"世界里有什么"写成三份**本体**文件（本体 = 对系统涉及的全部概念的类型化声明，在 `swarm-yuan/references/ontology/`）：

- **objects.md**：有什么东西（17 个类型，如 地图/账本/指纹/门禁/规则/技能……）；
- **links.md**：东西之间有什么关系（10 条关系，如"地图**表征**仓库""账本**记录**过程""规则**治理**命令"）；
- **actions.md**：能发生什么动作（11 个，如 生成/核验/审计）。

然后规定两条纪律（DESIGN §0.2 称为"冲程"，即引擎的工作节拍）：

- **反推纪律**：每个机制必须能回答"我实现本体里的哪条关系"。答不出来的是孤儿机制——要么删，要么先回本体补定义。例：本体里有"地图表征仓库"这条关系，于是派生出"地图里的路径必须真实存在"这个机器检查（path-check）。
- **创造纪律**（2026-08-24 新增，决策 35）：**声称的机制必须能被创建（可运行）且被运行（CI/断言接线），否则视为不理解、不得声称**。只存在于文档的机制不是实体，是传闻；机器锚是创造证明，CI 接线是占有证明。这条来自费曼的两句话（What I cannot create, I do not understand / 知道每个已解问题怎么解），也来自一次 44 项"文档声称了但实现没做或做了没接线"的审计教训（见 §3.6）。

演进规则：新概念要进系统，先过本体四问（是什么新实体？跟已有类型什么区别？配什么机器锚？谁消费它？）——纪律是"结构约束"而不是"数量冻结"。

#### 3.5 机器可验与诚实化：单一事实源 + 三层诚实

系统对自己的数字和声称极度较真，机制是：

- **单一事实源**：所有"招牌数字"（55 门禁 / 79 框架 / 17 特征卡 / 184 变量 / 13 运行时整合……）只写在 `swarm-yuan/assets/facts.conf` 一处；`scripts/self-check.sh` 把这些数字与代码真值做**机械对账**（数函数、数文件、数数组元素），不符即失败——文档不允许手抄数字，"无手抄即无漂移"。
- **三层诚实化**：数字诚实（上面）+ 修辞诚实（对外文案禁用绝对化表述，扫描执法）+ 证据诚实（"配置了"≠"使用了"≠"有效了"，门禁报告里证据分级呈现）。
- **独立验收**：`verifier/` 是一套自我验收线（79 个框架夹具的双态测试、A/B 逐字节对比、核心门禁序列基线），CI 每次推送全量运行。

#### 3.6 创造纪律：为什么"能跑"才算"懂"

2026-08-24 的审计发现，系统里最危险的不是写错的机制，而是**声称了却从未真正运行的机制**：一个接线步骤在函数定义之前就调用（从没执行过，被容错吞掉）；六个宿主 hooks 装到了错误的目录，引用路径全部落空（被容错吞掉）；一个专为抓数字漂移而写的函数，自己从未被接线（死代码）；九个测试写完从没接进 CI（"CI 绿"因此是假象）。

这四类问题的共同形态是"理解了设计，没创造实现"——正是费曼说的"What I cannot create, I do not understand"。修复它们的不是再打补丁，而是把"创造"本身变成机器检查：接线存在性断言（hooks 引用的每个文件必须真实存在）、产物再生断言（入库的生成物必须能被生成器逐字节重新生成）、规则违规扫描（已被修过三次的同类 bug 配 lint，第四次复发即最后一次）。这些检查现在都跑在 CI 里。

#### 3.7 条件优于内容 + 落地优先

2026-08-21（R13 轮）定下的两条理念，约束所有新机制：

- **范式作为条件，而非内容**：机制分两类——**条件**（运行时自动约束行为，AI 不用记不用读，想糊弄结构上不可能，如 hooks 拦截）与**内容**（要 AI 先读先记再自觉遵守，每会话重复付税，糊弄结构上必然）。机器执法只做条件类；"给理解打分"这类内容类机制已退役——AI 的理解深度由行为证据兜底（测试过没过、门禁红不红、决策留没留痕），不由表格验证。
- **落地优先于删除**：概念/门禁/profile/文档一概不删——病根从来都是"没有正确落地"（设计了没接线），处置一律是补上真实消费路径：僵尸门禁接到真实触发点、孤立配置真实加载、无路由文档加"何时读我"的路由头。

---

### 4. 系统全景：一次完整旅程

```
安装与自检                生成（每个项目一次）              日常使用（每次开发）
┌─────────────────┐   ┌──────────────────────────┐   ┌──────────────────────────┐
│ install.sh       │   │ ① 自检（生成器健康）        │   │ AI 对研发人员服务：        │
│ 检测 7 个 AI 宿主 │──▶│ ② 探查（AI 读仓库+工具）    │──▶│ · 写代码前：门禁预检、hooks │
│ 安装生成器到    │   │ ③ 骨架生成（脚本）          │   │   拦截（稳定资产/禁区）     │
│ 助手的 skills/   │   │ ④ AI 填特征卡（立法）       │   │ · 行动中：范围/依赖/安全    │
└─────────────────┘   │ ⑤ AI 配 conf（184 变量推导）│   │   门禁、三值规则判定        │
                      │ ⑥ 门禁验证（执法自检）       │   │ · 交差时：独立 Oracle 验证  │
                      │ ⑦ 框架门禁注入（79 选 N）    │   │   （不信"完成了"四个字）    │
                      │ ⑧ draft→active 状态翻转     │   │ · 全程留痕：四本账落盘      │
                      └──────────────────────────┘   └──────────────────────────┘
```

逐步说明（括号里是执行者）：

1. **安装**：`install.sh` 检测本机装了哪些 AI 编码助手（7 个安装目标：Claude Code 深度集成；Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi 目录复制），把生成器拷进去。
2. **自检**（脚本）：生成器先检查自己——11 个可检测的外部工具在不在、数字口径漂没漂、本体锚点全不全。
3. **探查**（AI）：AI 读仓库（代码、文档、配置），可调用外部工具（代码图谱等，装了就用、没装就降级到 grep+读文件——降级不阻塞）。
4. **骨架生成**（脚本）：按 profile 档位拷出目标技能骨架（状态=draft）。
5. **填特征卡**（AI）：17 项探查清单逐项填写——这是"立法"环节，产出项目的规矩。
6. **配 conf**（AI）：把特征卡翻译成 178 个配置变量（三件套 conf 文件）。
7. **门禁验证**（脚本）：跑核心门禁自验；框架门禁按探测到的技术栈从 79 个片段库选 N 个注入。
8. **激活**（脚本）：核验零占位符后 draft→active。
9. **日常使用**（宿主 hooks + 门禁）：AI 每次写代码前，预检门禁自动跑；写代码时，门禁红期间 hooks 拦截写操作与推进态命令；遇到危险命令（`rm -rf`、`git reset --hard`、`sudo`、`npm publish`），三值规则直接拒绝并给出替代方案；AI 声称"完成了"时，Oracle 机制独立重跑验证命令，通不过就打回继续。
10. **留痕**（账本）：所有关键行为写进四本账（见 §5.5），落盘在项目 `.swarm-yuan/` 目录。

---

### 5. 关键机制图解（最能体现思路的六个）

#### 5.1 门禁的三轴模型（全系统最容易混的一张表，务必看）

"55 个门禁"这一句话背后其实是**三个互相独立的分类轴**，任何两轴都不等同：

| 轴 | 取值 | 回答的问题 |
|----|------|-----------|
| **① 家族**（按执行序列归谁管） | 核心 10 / 架构 18 / 合规 19 / FULL-only 2 / advisory-only 6（合计 55） | "这个门禁在哪个运行套餐里？" |
| **② 严格度**（enforce 分层） | 静态 strict 17 / warn 22 / advisory 16（按 fail() 调用数归）；**有效** 17/17/21（5 个误报高的 warn 门禁经 WP-Q2H 决策降级为 advisory 观测——运行时以有效口径为准） | "这个门禁会阻断交付吗？" |
| **③ 执行序列**（用户怎么触发） | `--all`（核心 10）/ `--all-full`（标准 28=核心+架构）/ `--compliance-suite`（合规 19）/ 单门禁 flag（55 个都可单独跑） | "我这次跑哪些？" |

例：`check_crypto`（加密合规）家族上属合规族（③只在 --compliance-suite 或单跑时执行），严格度上是 warn（②不阻断只警告）。三轴正交——不能说"合规门禁都是 strict"，也不能说"核心门禁都会 fail"。（这组数字历史上漂移过，现在由 self-check 对每个轴做等值断言，漂移即失败。）

#### 5.2 79 框架三件套：规则库为什么可靠

系统内置 79 个技术框架（Vue、Django、Spring Boot、Kafka……）的规则。每个框架有**三件必须一致的资产**：规则文档（`references/frameworks/<fw>.md`，写清规律和最低条数门槛）、门禁片段（`assets/framework-gates/<fw>.sh`，可执行的检查函数）、双态夹具（`tests/fixtures/<fw>/`：一个"必然违规"样本必须被检出 + 一个"合规"样本必须通过）。三件套一致性由 CI 逐框架机器核验——规则不是"文档说它有就有"，是"夹具证明它拦得住"。

#### 5.3 rules.d 三值规则：规则是数据，拒绝要带替代方案

除门禁外还有一层更轻的规则：**rules.d/*.rules**，每行一条：`命令模式 → allow/prompt/forbid # 理由`。求值器（`gate-rules.sh`）对 AI 要执行的 bash 命令做三值判定：放行 / 提示（有门禁红时拦）/ 拒绝。**拒绝消息必须带替代方案**（如 `rm -rf *` 被拒时给出"先 `git clean -n` 预览再逐项删"）——因为拒绝消息是给 AI 看的操作指南，不是给人看的报错。规则命中取最严（forbid > prompt > allow）。用户也可以把一次"特许放行"沉淀为新规则（审批留痕）。

#### 5.4 hooks 宿主接线：约束在行动之前生效

目标技能挂到 AI 助手的 hooks 上（双宿主：Claude Code 用 deny JSON 协议，Codex 用 exit 2 协议）。五个钩子各司其职：门禁红期间拦写文件/推进态命令（fail-gate-hook，以白名单 conf 划定拦截面；rules.d 三值规则拦危险命令是无条件面）、防 AI 伪造验证（integrity-guard）、检测失败模式原地打转（failure-detector）、会话结束时独立验证"完成"声明（loop-hook 的 Oracle）、恢复上下文（状态续传）。布局纪律：目标技能里**可执行文件全在 `scripts/` 目录，`hooks/` 目录只放 hooks.json 配置**（曾因装错目录导致钩子全部静默失效，现在有机器断言引用路径必须真实存在）。

#### 5.5 四本账与链式锚定：一切留痕，且篡改可检出

`.swarm-yuan/` 目录下落四本账（JSONL 格式，每行一条）：

- **trace.jsonl**：调用流水（AI 每次调工具/子代理一行）；
- **decisions.jsonl**：决策流水（分三级：机械类/品味类/须人裁决类，含采纳与否、目标闭环状态）；
- **gate-runs.jsonl**：门禁运行流水（每次 precheck 一行，趋势与证据链的数据源）；
- **gate-audit.jsonl**：拦截审计流水（hooks 判定一行：放行/拦截；休眠态——无门禁红 flag、draft 骨架期——不写，DESIGN §9 口径）。

关键设计：decisions 账的每行记录引用**写入那一刻** trace 账末行的校验和（digest）——账与账从"并列"升级为"链式"。检出语义（ontology-verify 锚 4 机器执法）：凡被 decisions 引用过的 trace 行，事后遭篡改则其 cksum 变化、锚失配，即报"全链自该点 stale"；正常追加新行不误报（锚指向历史行而非当前末行）。注意锚定面=被引用行，未被引用的行不在保护内（抽样式锚定，非全量防篡改）。**账本不是日志，是可审计证据**。

#### 5.6 生成物税制：每字节都是成本

目标技能被 AI 每次会话加载，体积直接稀释有效上下文。所以生成物有明确预算并由生成流水线实测：入口 SKILL.md ≤8192 字节、项目地图 ≤32KiB、概念负担压到个位数名词。进生成物清单的审核问题永远是："目标 AI 每会话要为它付多少税？"行为参数一律留在包内，不进全局配置。

---

### 6. 端到端：研发人员的一天（使用视角）

1. 新需求来了，对 AI 说"开始新需求 ×××"。目标技能生成 **spec**（任务规格：需求/决策/约束/测试/回滚，24 节模板按任务类型裁减——小任务不必填完整仪式节）。
2. AI 干活过程中：写代码前门禁预检；碰到稳定单元会提示或拦截；用了危险命令会被三值规则拦下并给替代方案。
3. AI 说"做完了"：Oracle 独立重跑验证命令（比如核心门禁全集），过了才算完，不过就打回——"完成了"四个字不算证据。
4. 全程的调用、决策、门禁结果、拦截事件落进四本账；之后可随时出趋势报告（哪些门禁最近老红、修复后是否真的不再红）。

---

### 7. 易混概念辨析（歧义消除专场）

| 易混对 | 辨析 |
|--------|------|
| **生成器 vs 目标技能** | 生成器 = swarm-yuan 本身（造规则包的）；目标技能 = 生成物（某项目专属的规则包，"生成物"是同义通称，多用于税制/厚薄语境）。两者各有一份 `SKILL.md` 和 `scripts/`——生成器的 SKILL.md 是生成器的入口说明书；目标技能的 SKILL.md 是目标技能的入口说明书（≤8KB 预算管的是**后者**）。 |
| **"自检"一词三义** | ①生成器自检 = 生成器仓库的 `scripts/self-check.sh`（生成流程 Step 1，检查生成器健康）；②目标技能门禁运行 = 目标技能的 `scripts/precheck.sh`（执法检查，日常"提交前自检"指的是它）；③conf 诊断 = 目标技能的 `precheck.sh --doctor`（配置 lint，不判门禁）。三者是三份不同脚本/模式，分属两体。 |
| **.swarm-yuan/ 目录 vs swarm-yuan 仓库** | `.swarm-yuan/`（带点）是**目标技能在目标项目根**落下的运行时数据目录（四本账等）；`swarm-yuan/`（不带点）是生成器仓库/目录。同名是历史沿用，一指数据一指代码。 |
| **门禁家族 vs 严格度 vs 执行序列** | 见 §5.1。家族=归哪个套餐管；严格度=会不会阻断；执行序列=怎么触发。三轴正交，互不推出。 |
| **运行时三口径** | "13"=外部运行时**整合**总数（深度接线 4 + CLI 接线 4 + 纯方法论引用 5）；"11"=自检**可检测可安装**的工具数（codex-security 无独立包可装、impeccable 是纯方法论，不在 11 内）；"7"=**安装目标**（生成器可以装进哪几个 AI 助手——install.sh 装的是生成器，不是目标技能；目标技能是在目标项目里生成的，不经 install.sh）。三个数答三个不同问题。 |
| **pass / fail / warn / skip** | pass=通过；fail=阻断（退出非零，必须修）；warn=警告（计数不阻断）；skip=未配置该规矩**明示跳过**——skip 不计入 warn 更不算 pass，防止"没配规矩"被当成"合规"。**fail-open** 是另一回事：指某机制失败时不阻塞主流程（只允许在有下层强制兜底的地方使用）。 |
| **特征卡 vs conf vs spec** | 特征卡=17 项**探查清单**（项目是什么样）；conf=特征卡翻译成的**配置变量**（门禁读它执法）；spec=每个开发任务的**任务规格**（本次需求/决策/测试，24 节模板）。三者是"项目立法 → 执法配置 → 任务合同"。 |
| **门禁 vs rules.d 规则** | 门禁=检查**代码与仓库状态**的 bash 函数（55 个，四结果）；rules.d=判定**命令该不该执行**的数据规则（三值）。前者管"代码合不合规矩"，后者管"命令让不让跑"。 |
| **hooks/ 目录 vs scripts/ 目录** | 目标技能里：`scripts/` 放全部可执行脚本（含 5 个钩子脚本）；`hooks/` 只放 `hooks.json`（宿主钩子注册配置）。 |
| **draft vs active** | 目标技能的两个生命周期状态：draft=骨架未填满（禁全量门禁，防半成品错觉）；active=验证零占位符后激活（全量解锁）。 |
| **WP-/R-/决策编号** | 历史工作包/调研轮/决策记录的**考古标签**（如 WP-Q2H-B、R13、决策 35），用于追溯"为什么改成这样"。它们不是系统概念，新人无需记忆——正文出现的概念一律以本语文义为准。 |
| **verifier v1 vs v2** | v1=内部自洽验收（改动前后行为一致吗——CI 强制）；v2=外部有效验收（门禁能拦真实 bug 吗——测量脚本已落地、语料待采集，未达阈值前对外禁用"100% 可靠"）。 |

---

### 8. 术语词典（首次定义汇总，按拼音排序）

- **本体（ontology）**：对系统全部概念的类型化声明（有什么东西、什么关系、什么动作），三份文件 objects/links/actions，是一切机制的上游。
- **账本（ledger）**：目标项目根 `.swarm-yuan/` 下的 JSONL 留痕文件，四本：trace / decisions / gate-runs / gate-audit。
- **档位（profile）**：生成物的轻重配置：lite / standard / compliance / auto。
- **生成器（generator）**：swarm-yuan 本身，元技能——生成目标技能的技能。
- **目标技能（project skill / 生成物）**：生成器为某个项目产出的规则包（含 SKILL.md、references、scripts、rules.d、hooks 配置）。"生成物"是同义通称。
- **门禁（gate）**：检查代码与仓库状态的 bash 函数，55 个，结果为 pass/fail/warn/skip 之一。
- **骨架（skeleton）**：生成器产出的未填充目标技能（draft 态），AI 填充后转 active。
- **骨架铁律（零占位符）**：draft 转 active 前必须无"待填充"占位符——防止半成品被当成品。
- **框架三件套**：一个技术框架的规则文档 + 门禁片段 + 双态夹具，三者一致性由 CI 核验。
- **hooks / 宿主 hooks**：AI 编码助手提供的时机钩子机制（写文件前/会话结束等），目标技能把检查脚本挂在上面。
- **夹具（fixture）**：最小测试样本项目，分 violating（必被检出）与 compliant（必通过）双态。
- **闭环流 / 四本账链式锚定**：账本行间用校验和互相引用，上游篡改导致全链失效可检出。
- **特征卡（feature card）**：17 项项目探查清单，立法产物。
- **外部运行时（runtime）**：被整合的外部工具/方法论，13 个，分深度接线/CLI 接线/方法论引用三层，未装自动降级不阻塞。
- **项目地图（map）**：生成物 references/map.md，两列"路径|说明与约束"，≤32KiB。
- ** Oracle（预言机验证）**：AI 声称完成时由 hook 独立重跑验证命令的机制，"完成了"需经独立验证才算数。
- **facts.conf**：全部招牌数字的唯一权威文件；self-check 用代码真值机械对账。
- **FAIL-open / fail-closed**：失败时放行 / 失败时拒绝。权限边界一律 fail-closed；fail-open 只用于有下层兜底处。
- **五层认知（cognition）**：`references/cognition-framework.md` 定义的五层框架（认知递进/思维语言/认知辩证/偏差防范/辩证认知），特征卡第 13 项的认知基底；属建议性体检（`--cognition` 出报告不判违规），不是门禁家族。
- **spec / spec 模板**：任务规格（每次开发任务的合同），模板 24 节按任务类型裁减。

---

### 9. 边界与诚实声明（它不做什么）

1. **不替代宿主**：AI 助手（Claude Code/Codex 等）管会话循环、沙箱、审批通道；本系统只管项目上下文、业务规则、操作边界。
2. **Windows 硬前置 bash**：原生 cmd/PowerShell 不支持——Windows 用户须先装 Git for Windows（自带 Git Bash）或 WSL。
3. **重量级是设计选择**：小项目请用 lite 档或更轻的替代（单拷 precheck.sh / 传统 lint 工具链 / 直接对 AI 说需求），不必强上本系统。
4. **外部有效性未达成**：verifier v2（门禁能否拦截真实缺陷）的语料评测未完成前，对外不说"100% 可靠"；已验证的是"组件测试 + 受约束生成 + 独立校验"三段。
5. **降级是常态不是异常**：外部工具未装就降级（图谱工具→grep），合规规矩未配置就明示 skip——系统不假装满配运行。
6. **门禁不抓逻辑错误**：55 个门禁全是词法/结构模式匹配（import 方向、注解模式、文件存在性、命令黑名单）——它们抓"不懂规矩"，不抓"想错逻辑"。逻辑错误的兜底是**测试+审查**，且机器层对兜底本身有核验：①测试兜底要求 spec §11 测试策略段有实质内容（check_shift_left 核验非占位）+ 测试命令 0 用例检出（check_test 对"空跑通过"warn）；②审查兜底要求留痕（check_review 核验 docs/reviews/<日期>.md 存在，三要素：评审人/日期/结论；模板随生成物分发 assets/review-record-template.md）。这是设计边界，不是缺陷（SKILL.md:16"机械脚本不假装能判断质量"）——但"该做的兜底没做"是机器可查的。
7. **流程强制的覆盖边界**：spec 前置门（SPEC_REQUIRED=1）拦"无 spec 写源码区"，门禁失败捕获门（GATE_ENFORCE_DENY）拦"fail 未修复继续写"——但流程节点的**判断质量**（spec 写得对不对、plan 是否合理）仍是 AI/人的责任，机器只管"顺序与存在性"，不管"内容好坏"。

---

### 10. 阅读地图（接下来读什么）

| 想深入了解 | 去读 |
|-----------|------|
| 全部设计规格（本体论/架构/验收/档案） | 本文 §6.1（规格层，§0 原理 → §11 档案） |
| 每个数字的权威值 | `swarm-yuan/assets/facts.conf` |
| 为什么门禁长这样（改动前必读） | 本文 §6.3 决策史（决策 1-35；1-17 见 §6.6 A5） |
| 生成流程逐步口径 | `swarm-yuan/references/generation-flow.md`（Step 1-12） |
| 79 框架各自的规则 | `swarm-yuan/references/frameworks/` |
| 使用手册（研发人员视角） | 本文 §6.5（原 USAGE） |
| 验收体系怎么运作 | `verifier/README.md` 与 `verifier/v1/acceptance-criteria.md` |
| 调研证据（方案怎么长出来的） | `docs/research/`（R1-R9、R11-R15，R10 无报告） |

> 维护注记：本文是解释层，不承载规格——若与 §6.1 冲突以规格为准，并视为本文需要修订；发现歧义请按"术语词典"先对齐命名再讨论。


## 6.3 决策史（paradigm-decisions）

> 每个决策的完整记录（问题/决策/理由/后果）——查"为什么这么定"。

> **角色标注（2026-08-21）**：本文件是决策史**原文档**（每个决策的完整记录）；本文 §6.1 §9.2（决策史索引）是索引与归纳——查"为什么决定"用 §6.1 索引，查"决策全文"用本文件。


> 活跃决策（决策 18+）。决策 1-17（建议 1-7 + 8 条建议表 + 决策 9-17）已归档至 §6.6 A5 归档卷（原 docs/paradigm-decisions-archive.md；均已落地稳定，纯历史记录；决策 12/13 除外，二者仍是当前行为权威依据，归档件保留活跃锚点）。
> **口径权威源**：`swarm-yuan/assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

> **决策 13 指针锚点**（活跃决策）：决策 13（断点续传否决令废止→draft 状态门，2026-07-21 WP-H）是当前 draft/active 状态门行为的权威依据，已随决策 1-17 归档至 §6.6 A5 归档卷决策 13 段。外部引用（state-machine.sh 等）指回该归档卷。

#### 决策 18：自适应轻重 + 质量优先偏置 + 授权无关化（2026-07-21 用户方针）

**用户方针**：①swarm-yuan 应为不同项目及任务自适应轻重，避免过轻或过重；②优先保障开发交付质量而非效率；③不考虑开源组件商业授权，不据此调整功能优先级。

**决策**：
1. **项目级自适应**：`generate-skill.sh --profile` 默认值 standard → `auto`（合规关键词 → compliance；文件数 <80 → lite；其余 standard）。偏置方向**只升不降**：探测失败/边界不确定一律按更重档处理，auto 打印判定依据供用户评估，显式 `--profile` 始终优先。
2. **任务级自适应**：spec 三级映射门禁集——简单 → `--all`；标准 → `--all-full`；完整（架构/跨服务/公共接口/数据模型/权限）→ `--all-full` + `--shift-left`，compliance 档项目追加 `--compliance-suite`。规模判断不确定按更大规模处理；compliance 档无"简单任务"豁免。
3. **授权无关化**：撤销 GitNexus 许可证驱动的降级（原"PolyForm 禁商用 → 非默认"），GitNexus/graphify 按技术能力平权选型（深度调用图 vs 广谱知识图，可并用）；self-check 移除许可证忠告。授权合规评估属使用方组织责任，许可证信息仅作事实登记保留（code-graph-tools.md 表）。upstream-vendor 决策的其余理由（体积/维护面/版本追踪）仍然有效，仅撤销授权条款作为决策因子。
4. **质量 > 效率**落实点：auto 阈值偏置（<80 才 lite）、任务门禁映射的强制升级条款（公共接口/数据模型/权限改动无"简单"档）、draft 状态门（半成品无法伪装交付）——效率类优化（trace 降级/Windows CI 降频）不触碰任何质量判定逻辑。

**与减重批（决策 12-14）的关系**：减重不是"做轻"而是"恰当的重量"——三档 profile 让重量显式可选，auto 让选择自动化且偏向重的一侧。

---

#### 决策 19：catchphrase 单一事实源 facts.conf（2026-07-21 减重 WP-P1）

**问题**：36 门禁/27+9、179 变量、16 特征卡、11 运行时、32 领域、13 步流程 等口径在 8+ 文件手抄，`self-check.sh check_doc_consistency` 用 6 类正则扫描 5 份文档兜底——手动同步已不可靠，`docs/PROMO.md:215` 曾长期残留"11 步"旧口径（决策 17 已修，但同类漂移会复发）。

**决策**：
1. 新增 `swarm-yuan/assets/facts.conf`（bash 可 source 的 KEY=value），穷举所有 catchphrase 数字的权威值（FACT_GATES_TOTAL=36 / FACT_GATES_CORE=10 / FACT_GATES_ARCH=17 / FACT_GATES_COMPLIANCE=9 / FACT_GATES_STANDARD=27 / FACT_CONF_VARS=179 / FACT_FEATURE_CARDS=16 / FACT_RUNTIMES=11 / FACT_DOMAINS=32 / FACT_FLOW_STEPS=13 / FACT_FRAMEWORKS=61 / FACT_REFERENCES=18 等）
2. `self-check.sh check_doc_consistency` 开头 `source facts.conf`，先用代码真值对账 facts.conf 自身（GATES_TOTAL/CORE/ARCH/COMPLIANCE/CONF_VARS/FRAMEWORKS/REFERENCES 七项），漂移即 FAIL；再用 `${FACT_*}` 值扫描散文文档（原有 6 类正则降级为"叙事漂移检测"，逻辑不变）
3. 8 份文档（README/SKILL/USAGE/PROMO/template-spec/standards-compliance/CLAUDE/paradigm-decisions）头部加 `> 口径权威源：assets/facts.conf` 引用行，指向单一事实源
4. 修 `PROMO.md:215` 残留"11 步"→"13 步"

**理由**：catchphrase 手抄导致数字漂移是范式"过重"观感的一部分——文档与代码脱节会让外部观察者误以为"全是空壳"。单一事实源把"改一处→全局同步"自动化，self-check 机器执法先对账 facts.conf 自身（防 facts.conf 漂移），再扫描文档（防文档漂移），双向兜底。

**边界**：文档头部引用行不替换正文数字（保留可读性），仅声明权威源；facts.conf 只声明"会变的数字"（门禁数/变量数/框架数等），不声明"稳定的架构"（六段式/五层认知基底等）；facts.conf 自身漂移由 self-check 机器执法（改门禁数必须同步改 facts.conf，否则 FAIL）。

---

#### 决策 20：任务类型维度实装（2026-07-21 减重 WP-P4）

**问题**：`template-spec.md:32-33`「快速入口（按任务类型）」是空占位表——只有"（任务类型 → 起始节点 → 关键参考 的表）"一行，无实际映射。分支命名有 feat/fix/refactor 但无对应门禁集差异化。spec 三级（简单/标准/完整）按变更规模分级，与任务类型正交——一个 fix 可能是"完整"级（跨服务 fix），一个 feature 可能是"简单"级（加字段）。

**决策**：
1. 新增 `swarm-yuan/assets/task-type-gates.conf`（bash 可 source），7 类任务映射（对齐用户级 AGENTS.md 分支命名）：
   - feature → `--all-full`（无豁免）
   - fix → `--all --reuse`（§14-§18 认知段可免）
   - refactor → `--all-full --reuse --stable-diff`（§14-§18 可免）
   - chore → `--all`（spec 全段可免）
   - docs → `--docs-pack`（其他门禁免）
   - test → `--all --shift-left`（§14-§18 可免；§19 必填）
   - exp → `--all`（合入前须转 feature/fix）
2. `template-spec.md` L32-33 填实任务类型映射表 + 引用 task-type-gates.conf
3. `generate-skill.sh` 生成的 `commands/spec.md` 指引改为"先判任务类型后判规模，两者取并集（更重档）"
4. `self-check.sh` 加 task-type-gates.conf 一致性断言（7 类必须齐全）

**与 spec 规模维度的关系（正交，取并集）**：
- 任务类型决定门禁子集（哪些门禁跑/豁免）
- spec 规模决定档位（--all/--all-full/--all-full+--shift-left）
- 两者取并集（更重档，质量优先，决策 18）

**边界**：
- compliance 档项目无"简单任务"豁免（决策 18）
- 公共接口/数据模型/权限改动无"简单"档（强制 ≥ --all-full）
- exp 任务合入前须转 feature/fix 正式流程（不阻塞合入是探查期特权，非交付特权）

---

#### 决策 21：WP-P5 enforce_level 随 profile 调整——延后到 WP-Q1 合入后（2026-07-21）

**问题**：WP-P5 计划让 enforce_level（strict/warn/advisory）随 profile 调整——lite 档降一档（strict→warn，保护核心 strict 不降）、compliance 档升一档（advisory→warn，纯观测类保留 advisory）。

**事实核查**：enforce_level 机制（`gen-enforce-level.sh` + `gate-enforce-level.conf` + `_enforce_of`）目前仅在 `wp-q1-gate-stratification` 分支，**未合入 origin/main**。WP-P5 的实现依赖该机制存在。

**决策**：WP-P5 延后——不在本 worktree 实施 enforce_level 随 profile 调整，等 WP-Q1 合入 main 后作为独立 WP 处理。本 worktree 的自适应减重聚焦：
- 项目级（profile auto + 动态升档 WP-P6 + 技术栈反作用 WP-P9）
- 任务级（任务类型 WP-P4 + spec 三级机器执法 WP-P7）
- 阶段级（per-phase profile WP-P8）
- 结构性（catchphrase 单一事实源 WP-P1 + 冗余合并 WP-P2 + arch.conf 懒生成 WP-P3）

enforce_level 随 profile 调整是"门禁内部分级随项目档变化"的维度，与上述"项目/任务/阶段"三级自适应正交，且依赖未合入的 WP-Q1 基础设施，故延后。

**边界**：本决策不否定 WP-P5 的价值，仅记录依赖约束与延后理由。WP-Q1 合入后应优先补做。

---

#### 决策 22：profile 动态升档——detect-profile-drift 只升不降（2026-07-21 减重 WP-P6）

**问题**：profile 在 `generate-skill.sh` create/upgrade 时写入 frontmatter 后固化；项目演进（<80 文件长到 >80，或新接入合规要求）不会自动升档，需手动 `--upgrade --profile`。固定 profile 与项目实际状态脱节是范式"不自适应"的典型表现。

**决策**：
1. 新增 `swarm-yuan/scripts/detect-profile-drift.sh`：重跑 `auto_detect_profile` 逻辑对比 frontmatter profile，漂移则输出建议
2. 偏置规则（质量优先，只升不降）：
   - 合规信号新增（docs/README 出现等保/密评/个保法/金融/医疗关键词）→ 强制提示升 compliance
   - 规模信号升档（文件数从 <80 涨到 ≥80）→ 提示升 standard
   - 规模信号降档（文件数从 ≥80 降到 <80）→ **不提示降 lite**（只升不降）
   - 探测失败/边界不确定 → 不提示（保守不误报）
3. 触发点：
   - precheck.sh `--all`/`--all-full` 启动时调用（轻量，stderr 输出，不阻塞主流程）
   - self-check.sh `check_profile_drift` 子检查（warn 不 fail）

**理由**：profile 固化是范式"生成时一次定死"的局限。动态升档让范式持续感知项目演进——文件数增长或新增合规要求时主动提示升级。只升不降是质量优先偏置的延续（决策 18）：降档可能放过原本被门禁覆盖的风险，升档只是增加保护。

**边界**：
- 漂移检测是 warn 不 fail（不阻塞 precheck 主流程；仅提示用户评估）
- 不自动执行升级（升级是用户决策，detect 只给建议命令）
- 合规信号优先于规模信号（合规最强，与 auto_detect_profile 一致）
- 降档不提示（避免项目临时减文件后误降档）

---

#### 决策 23：spec 三级机器执法——detect-spec-scale 从 spec 推断规模（2026-07-21 减重 WP-P7）

**问题**：spec 三级（简单/标准/完整）由 AI 按 `commands/spec.md` 文本指引判定，无脚本执法——一旦判"简单"选 `--all`，中途规模变化（如编码期发现实际跨模块）不会自动升档到 `--all-full + --shift-left`。文本指引依赖 AI 自觉，无机器兜底。

**决策**：
1. 新增 `swarm-yuan/scripts/detect-spec-scale.sh`：解析 spec.md 结构化字段，推断规模等级（简单/标准/完整）
2. 推断规则（质量优先，不确定升档）：
   - 侵入点 ≤3 文件（反引号路径计数）且 无风险信号 → 简单
   - 侵入点 4-10 文件 或 含任一风险信号 → 标准
   - 侵入点 >10 文件 或 含 ≥2 风险信号 或 架构变更 → 完整
   - 风险信号：跨服务 / 公共接口 / 数据模型 / 权限 / 架构变更 / 新上下文
3. precheck.sh `--all`/`--all-full` 启动时：若 SPEC_FILE 存在，跑 detect-spec-scale，当前 MODE < 推断等级 → warn 提示升档（只升不降）
4. commands/spec.md 指引改为"填完 spec 跑 detect-spec-scale 确认规模"

**与 WP-P4 任务类型正交**：任务类型决定门禁子集（哪些门禁跑/豁免），spec 规模决定档位（--all/--all-full/--all-full+--shift-left），两者取并集（更重档，决策 18）。

**边界**：
- 规模检测是 warn 不 fail（不阻塞 precheck 主流程）
- 只升不降（spec 判"完整"但跑 `--all` → warn 提示升；spec 判"简单"但跑 `--all-full` → 不提示降）
- 无法解析侵入点保守按标准（不降简单）
- 架构变更信号强制完整档（最高优先级）

---

#### 决策 24：技术栈复杂度反作用 profile——形态/框架/微服务信号升档（2026-07-21 减重 WP-P9）

**问题**：C+.0 形态判定 + C+.0.5 框架探查只影响枚举维度和 ACTIVE_FRAMEWORKS，不影响 profile 档——纯前端小项目 <80 文件判 lite，Spring 全栈大项目 >80 文件判 standard，但形态差异不进入 profile 判定。技术栈复杂度是项目"重量"的真实信号，仅按文件数判定会漏掉"小而复杂"的项目（如 50 文件的微服务多形态项目）。

**决策**：
1. `auto_detect_profile` 追加技术栈复杂度信号（在合规/规模信号之后，优先级：合规 > 技术栈复杂度 > 规模）：
   - **形态信号**：同时含 ≥3 种形态（前端 .vue/.jsx/.tsx + 后端 .py/.java/.go/.rb/.php/.kt + 异步 consumer/listener/subscriber + 微服务 services/多服务 + 桌面 electron/tauri/android/ios）→ 升 standard
   - **框架信号**：依赖文件中框架数 ≥20（package.json dependencies + pom.xml artifactId + go.mod require 粗计）→ 升 standard
   - **微服务信号**：services/ 目录存在且含 ≥2 子目录 → 升 standard
2. 偏置：技术栈复杂度信号触发时**只升不降**（与决策 18 一致）
3. auto 判定输出 reason 含技术栈信号详情（供用户评估）

**理由**：文件数是项目"体积"信号，技术栈复杂度是项目"结构"信号——两者正交。一个 50 文件的微服务多形态项目，其认知负担和门禁需求远高于 100 文件的单体前端项目。技术栈复杂度反作用 profile 让自适应从"单维（规模）"升级为"双维（规模+结构）"，更贴合项目实际重量。

**边界**：
- 技术栈复杂度信号只升不降（不因形态少而降档）
- 形态判定是粗粒度（按文件扩展名 + 目录结构），不替代 §C+.0 的精细形态判定（后者影响枚举维度）
- 框架数粗计（依赖文件行数），不替代 §C+.0.5 的框架探查（后者激活规则集）

---

#### 决策 25：范式定位声明——适用/不适用场景显式化（2026-07-21 减重 WP-P10）

**问题**：无"适用规模门槛"声明，"过重"被外部观察者视为缺陷而非显式适用域。范式定位不清晰导致：(1) 小项目用户套范式后抱怨"太重"；(2) 大项目用户不知道范式能帮他们减负。

**决策**：
1. 新增 `docs/paradigm-positioning.md`（该文件后随单一文档整合删除，内容现 §6.1 §1）：显式声明适用/不适用场景 + 轻量替代方案 + "过重"的诚实评估
2. README.md 加"适用场景"章节（链接定位文档）
3. SKILL.md 加"不适用场景"段（扩展既有"不适用"一句话）
4. CLAUDE.md 加范式定位段

**适用场景**：团队协作（≥2 人）、中大型项目（≥80 文件或 ≥3 形态）、强监管交付（合规要求）、长期维护项目（需沉淀记忆）、多技术栈混合项目（微服务/全栈）。

**不适用场景**：个人脚本/一次性原型、学习用 demo、极小改动（改 typo/调样式）、无 AI 辅助的纯人工开发。

**轻量替代**：
- 范式内：`--profile lite`（只建三目录 + 核心门禁最小集）
- 范式外：单文件 `precheck.sh` 做门禁不套生成器；传统 lint/test 工具链；AI 原生开发

**定位声明**："swarm-yuan 是重量级范式，重量是设计选择不是缺陷——通过 profile 自适应让重量显式可选。"

**理由**：范式定位显式化是"诚实化"的延续——不假装适合所有项目，明确告诉用户何时该用、何时不该用。这既是对用户的尊重（避免小项目用户踩坑），也是对范式价值的保护（避免在不适用场景被误判为"无用"）。

#### 决策 30：auto_detect_profile 偏置方向修正——只升不降→信号明确才升（2026-07-21 WP-Q2）

**背景**：决策 18 的"只升不降"让 lite 档几乎不被自动选中——auto 实际输出被压缩到 standard/compliance 二选一。一个 79 文件的小项目若没有合规关键词但 find 探测稍有不稳（SIGPIPE/head 截断）就走 standard。这与"自适应避免过重"的目标直接矛盾：把自适应退化成"自动选重档"。

**决策**：修正偏置方向，从"不确定即升档"改为"信号明确才升档，模糊走默认 standard"：
1. **明确升档**（不变）：合规关键词命中 → compliance；形态 ≥3 / 框架 ≥20 / 微服务 / monorepo → standard
2. **明确降档**：文件数 <80 且无合规关键词且非 monorepo 且依赖数 <20 → lite（WP-Q2 新增：允许降 lite）
3. **模糊走默认**：find 探测失败、依赖数不可读、边界不确定 → standard（不升不降，非"一律升"）
4. **质量优先的正确落实**：在该 fail 的地方严格 fail（strict 门禁真 fail），不在档位选择上"宁可偏重"——一个 79 文件小项目该跑 lite 就跑 lite，但 lite 档的 strict 门禁必须真 fail，不是 warn。既轻又硬，而非"lite 档藏重量"。

**与决策 18 的关系**：决策 18 的"只升不降"是当时的保守选择（advisory 门禁尚未分层，降 lite 怕放过风险）。决策 31（门禁分层）已让 advisory 显式化（6 个永不 fail），lite 档跑 strict 子集即可保证硬门禁不丢——此时"只升不降"的保守前提不再成立，修正为"明确才升"是顺势而为。

**与决策 22（detect-profile-drift）的关系**：决策 22 的"只升不降"指运行时漂移检测（项目从 lite 演进到 standard 时提示升级，不提示降级）——这是单向演进假设，仍然保留。本决策 30 修正的是生成时 auto 判定的偏置，两者作用域不同：生成时允许降 lite（信号明确），运行时漂移只升不降（演进假设）。

#### 决策 31：门禁分层 enforce_level（strict/warn/advisory）—— 2026-07-21 WP-Q1

**背景**：分析发现 precheck.sh 36 门禁中 `fail()` 调用仅 2 次（非门禁函数体内的 `fail()`），其余 34 个靠 echo/pass/warn 走流程——"门禁是执法"宣称与实际行为有系统性落差。check_cognition 275 行函数 fail=0（决策 12 已诚实化为 warn-only），但仍在 36 这个数字里被宣称"门禁"。

**决策**：引入 `enforce_level` 横切分层维度，与 core/standard/compliance 正交（一个门禁同时属于 core + strict，或 standard + advisory）：
- **strict（12 个，≥3 fail）**：真 fail 阻断交付——branch/layer/reuse/security/shift-left/compliance/sbom/privacy/authz/requirements/rtm/release-sign
- **warn（18 个，1-2 fail）**：能 fail 但触发窄，混合 warn
- **advisory（6 个，0 fail）**：永不 fail，只 warn/pass（观测/认知类）——cognition/consistency/consistency-cross/link-depth/state/mermaid

**机器化**：
1. `scripts/gen-enforce-level.sh` 扫 precheck.sh 每个 check_* 函数的 fail() 调用数，按 ≥3/1-2/0 自动归类，生成 `assets/gate-enforce-level.conf`（幂等可重跑）
2. `precheck.sh` `_enforce_of()` 读 conf（bash 3.2 兼容：换行分隔字符串 + awk 查表，不用 declare -A）；`_ENFORCE_OVERRIDE_K/V` 数组支持手动覆盖（如 check_review 从 warn 升 strict）
3. `_gate_exec()` 内 advisory 路径：子 shell 内重定义 `fail()`/`warn()`/`pass()` 为纯 echo，advisory 门禁的 fail/warn 调用变成纯输出行，永不进 FAIL_COUNT/WARN_COUNT——"advisory 是观测类，不阻断交付"语义机器化
4. `--list-gates` 子命令：输出 flag/gate_fn/enforce/tier 四列（横切维度可视化）
5. `self-check.sh` 加两断言：①gate-enforce-level.conf 与 precheck.sh fail() 数一致（防漂移）②strict 门禁必含 ≥1 fail()（防 strict 声明空壳）+ advisory 必须是 0 fail（防分类矛盾）

**理由**：
1. 诚实化——advisory 6 个门禁明确"永不 fail"，不再混在 36 里让读者以为都是硬门禁；strict 12 个是真执法，数量清晰
2. 自适应基础——后续 lite 档可只跑 strict 子集（真 fail 的），advisory 在 lite 档降级为跳过，实现"既轻又硬"而非现在的"lite 档藏重量"（不拷架构 17 门禁文件）
3. 自动归类——按 fail() 能力机械分类，不靠人工主观判断；改 fail() 即自动更新 enforce_level；self-check 防漂移
4. 手动覆盖逃生口——_ENFORCE_OVERRIDE 让语义判断优先于机械分类（如 check_review 1 fail 但语义上该 strict）

**与决策 12（check_cognition 诚实化）的关系**：决策 12 把 check_cognition 从"宣称 fail"改成"诚实 warn-only"，本决策把它从"warn-only 但仍算门禁"进一步归类为 advisory——分层更清晰。决策 12 是单门禁诚实化，本决策是全部门禁系统性分层。

**与决策 5（不拆 precheck.sh）的关系**：本决策不拆 precheck.sh（保留单文件 cp 铁律），只在内部加 enforce 机制。后续 Q1.3 拆分 36 门禁为 strict/warn/advisory 三文件是独立决策（install.sh 打包保留单文件 cp）。

#### 决策 26：复杂度负向预算--门禁/变量数冻结上限（2026-07-26 WP-rhetoric-honesty）

**问题**：范式声称帮项目降复杂度，但自身复杂度轨迹是单向膨胀--门禁数 27（初版）-> 52 -> 54（v2026.07.24），conf 变量数持续上升，框架规则 27 -> 74。若无约束，软件熵增将使范式自身复杂度不可控，与"帮项目降复杂度"的定位自相矛盾--范式可信度会被自身的演化曲线证伪。paradigm-positioning.md:8 已把"重量是设计选择不是缺陷"作为定位，但该定位只在"重量有上限"时才成立；无上限的"设计选择"等于无约束的熵增。

**决策**：自 v2026.07.26 起引入"复杂度负向预算"--

1. `facts.conf` 新增 `FACT_GATES_BUDGET=54`（门禁数上限，冻结于当前规模）与 `FACT_CONF_VARS_BUDGET=200`（变量数上限，当前 170 预留 30 增长空间）
2. `self-check.sh` 新增断言：`FACT_GATES_TOTAL > FACT_GATES_BUDGET` 则 **fail**（非 warn）--门禁数超预算是硬契约违反，须阻断合并
3. **新增须等额删除**：每个新 check_* 须在同一 WP 内删除 ≥1 个低价值 check_*（合并/废弃），保持总数 ≤ 预算
4. **例外机制**：合规强制（如新增国标映射需新门禁族）可申请预算上调，须在本决策记录追加"决策 26 修订 N"并说明理由 + 新预算值 + 上调期限
5. 变量数 `FACT_CONF_VARS` 同理受 `FACT_CONF_VARS_BUDGET` 约束，超预算同样 fail

**理由**：
1. 反熵增--软件熵增律表明无约束的复杂度增长不可逆；负向预算是把"减重"从口号变为机器执法（与 self-check 数字漂移检测同源机制）
2. 保护范式可信度--"帮项目降复杂度"的工具若自身复杂度无上限上升，其范式主张被自身演化曲线证伪；预算是"言行一致"的机器保障
3. 强制取舍--新增须等额删除，迫使每个新门禁证明其价值高于被删的旧门禁，避免"只加不减"的渐进式膨胀
4. 例外留逃生口--合规等硬需求可上调预算，但须显式记录理由，避免暗箱膨胀

**与决策 25（范式定位）的关系**：决策 25 把"过重"从缺陷转为"显式可选"的适用域声明；本决策给"显式可选"加了上限--"重量是设计选择"成立的前提是"重量有预算"。无预算的"设计选择"等于无约束膨胀，决策 25 的定位会沦为修辞。本决策是决策 25 的诚实化补丁。

**与 self-check 现有断言的关系**：现有 `check_doc_consistency` 守"数字漂移"（声明 vs 真值）；本决策的预算断言守"数字膨胀"（真值 vs 预算）。前者防"说错"，后者防"长太多"，两者互补。

##### 决策 26.1：等价替换 check_canary → check_loop_oracle（2026-07-27 WP-loop）

**问题**：E1（Oracle Gate 循环）提供了脚本层 `setup-loop.sh` + `loop-hook.sh`，但无门禁化兜底——AI 不主动跑 loop 时，无机械门检查「是否有未完成的 loop」。`check_canary`（advisory 档，0 fail）在生成器自身仓库无实际 canary 环境（无发布产物/无线上指标），形同虚设：未配 `CANARY_LATENCY_MS/CANARY_ERROR_RATE` 时直接 `return 0`，从未 fail。

**决策**：等价替换 `check_canary`（advisory）→ `check_loop_oracle`（strict）——
1. 删除 `gates-advisory.sh` 的 `check_canary()` 函数体（保留占位注释供计数核验）
2. 新增 `gates-strict.sh` 的 `check_loop_oracle()`：3 fail 调用（required/no_history/incomplete）→ strict 档
3. `precheck.sh` `GATE_FLAGS` 替换 `--canary` → `--loop-oracle`
4. `gate-enforce-level.conf` 重生成（gen-enforce-level.sh 幂等）：strict 21→21，advisory 14→14，总数维持 54
5. canary 监控能力保留为 `references/canary-monitoring.md` 文档 + Oracle Gate 循环形式（`setup-loop.sh --verify '<canary 验证命令>'`）
6. `FACT_GATES_ADVISORY_ONLY` 10→9（canary 是 advisory-only 10 之一）

**理由**：
1. **门禁预算守恒**——决策 26 要求新增须等额删除；canary（advisory，从未 fail）→ loop_oracle（strict，3 fail）是"低价值换高价值"的等价替换，总门禁数 54 不变
2. **强制力升级**——canary 是 advisory（0 fail，永不阻塞），loop_oracle 是 strict（3 fail，可阻塞 RC）；从"观测不阻断"升级为"机器执法阻断"
3. **能力保留**——canary 监控未消失，改为 Oracle Gate 循环形式落地（`setup-loop.sh --verify`），比原 advisory 门禁的 warn 强制力更强（promise 被拒则 loop 继续）
4. **填补缺口**——E1 的脚本层 Oracle 只有 AI 主动启动 loop 才生效；`check_loop_oracle` 是门禁级 backstop，`LOOP_ORACLE_REQUIRED=1` 时强制要求走 Oracle 验证

**与 E1（Oracle Gate 循环）的关系**：E1 是脚本层（`setup-loop.sh` + `loop-hook.sh`），本决策是门禁层（`check_loop_oracle`）。两层互补：脚本层管"loop 怎么跑"，门禁层管"loop 是否跑完"。

**Z3 fail-closed**：`LOOP_ORACLE_REQUIRED=1` 时，无 loop 状态文件且无 `LOOP_ORACLE_EXEMPT_REASON` → fail（与 sbom/crypto/dengbao 等 7 项 strict 合规门禁同 fail-closed 语义）。

##### 决策 26.2：预算上调 54→55（check_method_size 入编追认，2026-08-27 R10 回归收口）

**问题**：field-feedback 轮（632feff，2026-08-26）新增 `check_method_size`（方法粒度——单方法行数上限，语言无关启发式）时把 `FACT_GATES_TOTAL` 54→55，但未同步 `FACT_GATES_BUDGET` 也未等额删除——自该日起 self-check 预算断言悬挂 fail（55 > 54）跨五个合并批次至今，违反"新增须等额删除"的硬契约却未被收口，预算机制自身成了带病运行。

**决策**：按决策 26 条款 4 例外机制追认预算上调——
1. `FACT_GATES_BUDGET` 54→55，与新真值对齐（`facts.conf` 同步）
2. 上调性质为**追认既有事实**（门禁已存在且有消费者：`--method-size` flag + `GATE_FLAGS` 注册 + R7 双栈演练真实执行），非为未来新增预留空间
3. 新预算冻结于 55：后续新增门禁仍须等额删除或按条款 4 另行修订，本修订不构成"预算随门禁自动增长"先例

**理由**：
1. **等额删除无候选**：五维整合轮（2026-08-26）后 55 门禁逐项核验均有真实覆盖面（fixture 双态在案 79 组 + gate-fixture 48 组 + cli-ab 逐字节锁行为）；删除任一门禁均为真实覆盖损失，为守数字而删覆盖是本末倒置
2. **check_method_size 属"流程性约束缺失"的根因修复**（field-feedback 六反馈之一）：方法粒度是词法可判定的硬规则面（>60 行 warn），符合决策 27 条款 3 的"③ 概念无法以方法论吸收且不机器执法会致范式失真"——纯文档自觉无法防方法膨胀
3. **悬挂 fail 的制度成本**：预算断言长期带病运行会驯化"self-check RC=1 属正常"的肌肉记忆，掏空 fail-closed 执法可信度——收口比悬挂更符合预算机制的立意

**上调期限**：无期限（冻结于 55）；若后续合规强制需新门禁族，按条款 4 另行修订。

**与 26.1 的区别**：26.1 是等价替换（总数守恒，不动预算）；26.2 是预算上调（总数+1，追认）。两者都是"预算变动须留痕"的不同形态。

#### 决策 27：运行时升级整合纪律--吸收优先于新增门禁（2026-07-26 runtime-update-2026-07）

**问题**：`swarm-yuan/research/` 下 11 个外部运行时仓库需定期对齐上游最新稳定版，以保持深度/CLI/方法论三层接线的有效性。但每次升级挖出的新功能概念（如 gsd-core v1.8.0 的 reversibility tagging、superpowers v6.2.0 的 resume-based fix loop）会自然引诱"新增门禁"的冲动--若每次升级都加门禁，决策 26 的复杂度负向预算会被上游版本节奏绑架（上游发版越快、swarm-yuan 门禁越膨胀）。

**决策**：自 v2026.07.26 起确立"运行时升级整合纪律"--

1. **定期对齐**：`research/` 下 11 个运行时仓库定期对齐上游最新稳定版（非 rc/beta/alpha）；升级留底按 §6.6 A10/A11 系列格式在本文档追加"运行时升级报告"。
2. **吸收优先于新增门禁**：升级挖出的新功能概念，**优先以方法论吸收**（references 文档 / SKILL.md 叙事 / state-machine warn 分支 / trace-log 字段 / 新增 G<N> self-check 断言）落地，**不新增 `check_*` 门禁**（守决策 26 的 `FACT_GATES_BUDGET=54` 上限）。
3. **新增门禁的最后手段**：仅当满足以下任一条件才允许新增门禁--① 等额删除旧门禁（守决策 26）；② 合规强制（如新增国标映射需新门禁族，按决策 26 修订流程申请预算上调）；③ 概念无法以方法论吸收且不机器执法会致范式失真。
4. **self-check 断言不受门禁预算约束**：G<N> 断言（如 G10 版本 oracle 单源真值）是 `self-check.sh` 的自检逻辑，不计入 `FACT_GATES_TOTAL=54`（54 = `precheck.sh` 的 `check_*` 函数数）。新增 G<N> 断言是合规的扩展点。
5. **conf 变量有余量**：`FACT_CONF_VARS_BUDGET=200` vs 当前 170，预留 30 槽位；新增 precheck.conf 变量在预算内。

**理由**：
1. **解耦上游节奏**：把"对齐上游"与"门禁膨胀"解耦--上游发版是外部节奏，门禁数是内部复杂度，后者不应被前者绑架。
2. **方法论吸收的充分性**：多数运行时新概念是"模式指引"（如 reversibility 评级、resume-based fix loop），由 AI 引用执行即可，无需机器执法；硬门禁化是过度工程。
3. **守决策 26 可信度**：决策 26 把"门禁数有上限"作为范式可信度的机器保障；本决策给"升级时如何不破上限"的操作纪律，两者互补。
4. **self-check 断言是轻量扩展点**：G<N> 断言守的是 swarm-yuan 自身的健康（修辞诚实/复杂度预算/版本 oracle 单源），非项目门禁；它不受 54 预算约束，是吸收"运行时新概念催生的自检需求"的合规出口。

**与决策 26 的关系**：决策 26 确立"门禁数有预算上限"；本决策确立"运行时升级时如何守预算"--吸收优先、新增最后。本决策是决策 26 在升级场景的操作化。

**首次应用（2026-07-26）**：本轮升级 6 个运行时（claude-mem/graphify/gsd-core/open-code-review/ruflo/superpowers），挖出 6 项整合吸收（reversibility 评级 / broken-windows ledger / honest-edge provenance / resume-based 修复环 / 可证伪性纪律 / version oracle 单源），全部以方法论吸收 + G10 断言落地，**门禁数保持 54**（G9 通过）。详见 §6.6 A10（原 runtime-update-2026-07）。

---

### 决策 28：标记沿调用链传播（Palantir markings-propagate 映射，R11 调研吸收，2026-07-31）

**问题**：R11 调研（`docs/research/R11-palantir-mapping.md` §4.1）把 Palantir 工程哲学作为外部参照系审视 swarm-yuan 设计盲区，发现首要缺口——稳定单元标注（稳定/不稳定/禁止改，`exploration-guide.md` §11f）是 **file-glob 级静态属性**（`STABLE_GLOBS`），不沿调用链向下传播。`--stable-diff` 门禁只检测"是否直接改了 STABLE_GLOBS 内文件"（`gates-warn.sh` `check_stable_diff` §1-§2），**检测不到"是否改了依赖禁止改单元的下游文件"**。例：

```
UserRepo (禁止改, 在 STABLE_GLOBS) ← UserService (无标注) ← UserController (无标注)
现状：改 UserService 不触发 --stable-diff → 但可能破坏 UserRepo 调用契约
```

这与决策 31（门禁分层）发现"36 门禁仅 2 fail"同性质——"标记是执法"宣称与实际行为有系统性落差。Palantir 的对应机制是 `/docs/foundry/security/overview/` 的 "Mandatory controls propagate along lineage"：标记是数据本身的属性，沿计算传播；新建看板不会"忘记"加安全，因为看板读的对象自带标记。

**决策**：扩展 `--stable-diff` 语义加传播段（下游改动只 **warn** 不 **fail**，保持 enforce_level 归类不变），**不新增 `check_*` 门禁**（守决策 26：门禁预算 54 不变）——

1. **`assets/precheck.arch.conf`** +`STABLE_PROPAGATE=1`/`STABLE_PROPAGATE_HOPS=1`（开关+跳数，默认开启 1 跳）
2. **`assets/precheck.sh` `_default_conf`** 兜底补同名变量（防 set -u 崩 + 目标技能 conf 缺时降级）
3. **`assets/gates-warn.sh` `check_stable_diff` §3 传播段**：本次变更触及"调用 STABLE_GLOBS 文件的下游文件"时 warn "依赖禁止改单元 X，改动可能破坏其契约，须在 spec §MODIFIED 声明"。下游影响域来源优先从 `reference-manual.md §5` 的机器可读标记 `<!-- stable-propagate: <stable> → <downstream> -->` 提取，降级为 grep import 反查（best-effort）
4. **`references/exploration-guide.md` §11g** 新增"下游影响域"段（特征卡第 11 项 P0 子项）：每个"禁止改层"稳定单元须记录 1 跳下游影响域（用 graphify path / gitnexus trace 提取），作为传播 warn 的数据源
5. **`scripts/self-check.sh` G16 断言**（不计入 FACT_GATES_TOTAL=54，守决策 27 第 4 条）：守 absorb 四载体一致性（arch.conf 开关 + exploration-guide 填充指引 + facts.conf 口径 + gates-warn.sh 传播段），缺失才 fail，叙事漂移只 warn
6. **`assets/facts.conf`** +`FACT_STABLE_PROPAGATE=1`/`FACT_STABLE_PROPAGATE_HOPS=1`（口径同步）+ `FACT_CONF_VARS` 169→171 / `FACT_CONF_VARS_ARCH` 109→111（机械计数真值）

**预算核算**：

| 项 | 变更前 | 变更后 | 预算 | 余量 |
|----|--------|--------|------|------|
| FACT_GATES_TOTAL | 54 | 54（扩展现有 `check_stable_diff` 语义，不加 `check_*`） | 54 | 0 |
| FACT_CONF_VARS | 169 | 171（+STABLE_PROPAGATE/STABLE_PROPAGATE_HOPS） | 200 | 29 |
| G<N> 断言 | G15 | G16（不计入 54） | — | — |

✅ 全部合规决策 26（门禁预算）+ 决策 27（吸收优先于新增门禁）。

**理由**：
1. **诚实化**——`--stable-diff` 宣称"防范破坏 Repository 接口"，现状只防"直接改 Repository"，防不了"改 Service 间接破坏 Repository 契约"；传播段把后者纳入 warn，消除"宣称 vs 实际行为"的落差（与决策 31 同性质诚实化）
2. **warn 不 fail**——下游改动是"风险提示"（warn 级），直接改稳定单元才是"硬执法"（strict 级，§2 的 fail 不变）；warn 不增 fail 计数 → 不改变 `--stable-diff` 的 enforce_level 归类（保持原档），与决策 31"advisory/warn/strict 横切分层"一致
3. **方法论吸收**——Palantir "markings propagate along lineage" 不硬搬为 `check_marking_propagation` 新门禁，而是扩展现有 `--stable-diff` 的语义 + 特征卡填充指引 + G16 断言三载体吸收，守决策 26/27
4. **1 跳邻域防爆炸**——默认 `STABLE_PROPAGATE_HOPS=1`（仅 1 跳下游），避免大型项目（如 yudao-cloud 5564 java 文件，R9 样本）图遍历爆炸；2+ 跳列为 R12 待测项（R11 §8）

**与决策 31（门禁分层）的关系**：决策 31 把 54 门禁按 fail 能力分 strict/warn/advisory 三档；本决策扩展 `--stable-diff`（warn 档）的语义，不改变其 enforce_level 归类（下游 warn 不增 fail 计数）。两者正交：决策 31 是"按 fail 数分层"，本决策是"按传播深度分层 warn"。

**与决策 27（吸收优先于新增门禁）的关系**：本决策是 R11 调研（外部参照系）催生的改进，Palantir "markings propagate" 概念以方法论吸收（门禁语义扩展 + 填充指引 + G16 断言三载体）落地，**0 新 `check_*` 门禁**——验证决策 27 纪律不仅适用于"上游运行时升级"，也适用于"外部理念调研"场景。

**可信度声明**：Palantir "markings propagate along lineage" 一手来源 `/docs/foundry/security/overview/`（高可信，R11 §0.3）。swarm-yuan 的"file-glob 级不传播"现状是 2026-07-31 工作树实测（`gates-warn.sh:254-336` + `precheck.arch.conf:9`）。

---

### 决策 29：语义/动能二分显式命名 + 动作授权锚定组件标记 + FDE 反向传播形式化（Palantir ontology/FDE 映射，R11 调研吸收，2026-07-31）

**问题**：R11 调研（§4.2/§4.3/§4.4）发现三个次要缺口：
- **§4.2 语义/动能二分未显式命名**：swarm-yuan 的"特征卡（语义）+ 门禁（动能）"二分与 Palantir "semantic/kinetic primitives"二分**结构性同构**，但只用"立法/执法/司法"三权隐喻命名，未显式命名语义/动能分层——导致"组件清单（语义）"与"门禁规则（动能）"的耦合关系（门禁依据来自特征卡，`README.md:107` 立法→执法映射表）不清晰。
- **§4.3 动作授权未锚定组件标记**：动作授权（决策三级分类 + 四权分离）是"资产路径驱动"（改 precheck.conf/facts.conf 要 policy-guardian，改普通源码不要），**不取决于组件的稳定性标注或上游依赖**——存在治理盲区（改依赖禁止改单元的下游文件既不触发 `--stable-diff`，也不触发 UserChallenge）。
- **§4.4 FDE 反向传播通道未形式化**：forward deploy 强（每项目生成专属技能 + memory-writeback 三路写回），backprop 弱/手工（R1-R9 调研 + WP-* 批次都是人工捕获）；R9 已暴露"5 项目清一色 Java/JS Web"样本偏倚，反向传播弱会加剧偏倚。

**决策**（纯文档变更，0 新门禁，0 新变量）：

1. **`references/cognition-framework.md` 新增 §7** "语义层/动能层二分（Palantir 本体论映射）"：
   - 语义层 = 特征卡 17 项 + 详尽组件库清单（§C+.1）+ 调用链路（§C+.2）+ 编排约束（§C+.3）
   - 动能层 = 54 门禁（check_*）+ 决策治理三级分类 + 四权分离 agent 拓扑 + 状态机
   - 继承关系：动能层规则继承自语义层（门禁依据来自特征卡，`README.md:107` 立法→执法映射表）
   - 与立法/执法/司法三权隐喻的关系：正交（三权描述权力分立，语义/动能描述结构分层）
2. **`references/decision-governance.md` §2.2 升级规则补一条**"组件标记驱动升级"：
   - AI 记录决策时，若拟改文件在某个"禁止改"稳定单元的下游影响域（决策 28 的 1 跳邻域），自动评 `costly` 可逆性（§2.4 已有 costly 评级，此处补"何时判 costly"的规则）
   - `cost_if_wrong` 字段须反映"可能破坏上游稳定单元契约"
   - 这不改变三级分类（Mechanical/Taste/UserChallenge），只在 `reversibility` 横切属性上体现
3. **`references/fde-backprop.md` 新建**（方法论引用层，非门禁）：定义"反向传播纪律"——每 N 个 forward deploy 后（N 可配，建议 5），跑 `scripts/cost-report.sh` 聚合 N 个项目的 `decisions.jsonl`/`trace.jsonl`，提取高频 UserChallenge 模式与高频门禁 fail 模式，作为 WP-* 批次的输入（人工审阅后落地，非自动改核心模板——守"AI 主导+用户决策"原则）。借鉴 Palantir FDE = "human equivalent of backpropagation"。
4. **`swarm-yuan/SKILL.md`** "它整合的方法论"表方法论引用层补一行：FDE-backprop（本仓库自创，借鉴 Palantir FDE=human backpropagation）

**预算核算**：0 新门禁，0 新变量，1 新 references 文件（`fde-backprop.md`，FACT_REFERENCES 34→35，references 不受决策 26 门禁预算管）。

**理由**：
1. **设计清晰度**——语义/动能二分是结构性切分（描述"是什么"vs"能做什么"），与三权隐喻（权力分立）正交；显式命名两层让"组件清单→门禁规则"的继承关系可见，非"立法/执法"单一隐喻所能表达
2. **治理盲区**——决策 28 的传播 warn（§4.1）+ 本决策的动作授权锚定组件标记（§4.3）双通道补"改下游依赖禁止改单元"的治理缺口：门禁层 warn + 决策层 `costly` 评级
3. **FDE 反向传播形式化**——swarm-yuan 的 forward deploy 强（每项目生成专属技能 + memory-writeback 三路写回），backprop 弱/手工（R1-R9 调研 + WP-* 批次都是人工捕获）；R9 已暴露"5 项目清一色 Java/JS Web"样本偏倚，反向传播弱会加剧"核心模板只反映 Java/JS Web 品类"偏倚
4. **纯方法论吸收**——0 新门禁 0 新变量，守决策 26/27；Palantir 本体论/AIP/FDE 概念以 references 文档吸收，不硬搬为机器门禁

**与决策 28 的关系**：决策 28 补"标记沿调用链传播"的门禁层缺口（`--stable-diff` 传播 warn）；本决策补"动作授权锚定组件标记"的决策层缺口（`costly` 评级规则）+ 语义/动能显式命名的设计清晰度缺口 + FDE 反向传播的形式化缺口。两者共同落地 R11 调研的 P1-P3 建议。

**可信度声明**：Palantir 本体论（semantic/kinetic 二分）/ AIP（AI 经本体论行动）/ FDE = human backpropagation 均一手来源（`/docs/foundry/ontology/overview/` + `/docs/foundry/aip/overview/` + Architecture Center，高可信，R11 §0.3/§1.1/§1.5/§1.7）。

---

### 决策 32：上下文窗口自适应压缩——SKILL.md 分层折叠 + frontmatter 精简 + 预算门禁（2026-08-01）

**问题**：`context-surface.sh --gen`（生成期必读三件套：SKILL.md + exploration-guide.md + template-spec.md）当前 170,709 字节，已从 post-opt 基线 156,992 膨胀回涨（+13,717 字节，+8.7%），逼近 pre-opt 基线 193,226。SKILL.md 200 行/37KB 是常驻硬成本，其中约 90 行是"按需展开"段（Step 详解 :90-107、方法论吸收记录 :141-150、reference 清单表 :154-192），但它们常驻 SKILL.md 正文，每次 skill 加载都进上下文。`FACT_CONTEXT_SURFACE_PRE_OPT=193226` 是孤儿事实（self-check 不校验）。

**决策**：三层压缩 + 预算门禁，0 新门禁 0 新 G<N> 断言（预算检查并入现有 G9 `check_complexity_budget()`）——

1. **第一层 SKILL.md 正文分层折叠**（主战场）：
   - Step 1-12 详解（:90-107，~8KB）移到新建 `references/generation-flow.md`，正文只留 ASCII 节点总览流程图 + 4 条铁律摘要 + 指针
   - 方法论吸收记录（Palantir + 运行时升级 6 条，:141-150，~3KB）折叠为 1 句话指针指向 `docs/runtime-update-2026-07.md`（现 §6.6 A10）
   - reference 清单表 33 行（:154-192，~3KB）压缩为 6 行分类索引（探查/填充/认知/方法论/合规/安全）
   - AI 主导 7 条决策分类（:59-66，~2KB）折叠为 1 句话指针指向 `references/decision-governance.md`
   - verifier 定位 + WP-P3 框架台账（:101-103，~1KB）折叠为 1 句话指针
2. **第二层 frontmatter description 精简**：删门禁子分类细节（27 via --all-full: core 10 + architecture 17; compliance 17...）+ shift-left/rtm/release-sign 细节，保留触发词 + 核心能力 + 13/54/5/32 四个主 catchphrase。931B → ~350B（-62%）
3. **第三层 上下文预算门禁**：
   - `facts.conf` +`FACT_CONTEXT_SURFACE_BUDGET=180000`（当前压缩后 ~120000，预留余量）
   - `self-check.sh` `check_complexity_budget()`（G9）追加上下文表面预算 **warn** 断言（跑 `context-surface.sh --gen` 取 TOTAL，超预算只 warn 不 fail，渐进式对齐 MEASURE 模式）
   - CI 已跑 `--check-only`，预算 warn 进 CI 输出防回涨
   - `FACT_CONTEXT_SURFACE_PRE_OPT` 保留为历史基线（不动），新预算是独立键

**预算核算**：

| 项 | 变更前 | 变更后 | 预算 |
|----|--------|--------|------|
| FACT_GATES_TOTAL | 54 | 54（不改门禁） | 54 |
| FACT_CONF_VARS | 171 | 171（FACT_CONTEXT_SURFACE_BUDGET 在 facts.conf 非三件套，不计入） | 200 |
| FACT_REFERENCES | 34 | 35（+generation-flow.md） | — |
| context-surface --gen | 170,709B | ~120,000B（-30%） | 180,000（warn） |
| G<N> 断言 | G16 | G16（并入 G9，不加新） | — |

✅ 合规决策 26/27。

**理由**：
1. **按需展开段常驻是上下文浪费**——Step 详解只在执行到对应 Step 时需要，不该常驻 SKILL.md；references 设计意图本就是按需读取（SKILL.md:154"按需读取"），Step 详解同理
2. **frontmatter 是不可压缩硬成本**——skill 被 skill-finder 匹配时强制进上下文，931B 含门禁子分类细节属过度信息，精简到"被匹配"的最小集
3. **预算门禁防回涨**——post-opt→当前的 +8.7% 回涨无人守；warn 断言让回涨可见，CI 输出形成软约束
4. **0 新门禁 0 新断言**——预算检查复用 G9 `check_complexity_budget()`，不加新 `check_*`/G<N>（守决策 26/27）

**与决策 26（复杂度负向预算）的关系**：决策 26 守"门禁数/conf 变量数"预算；本决策补"上下文表面字节"预算——三者同源（负向预算防膨胀），但维度不同（数量 vs 字节）。字节预算 warn-only（渐进式），数量预算 fail（已达标）。

**与 generate-skill.sh 目标技能 SKILL.md 的关系**：目标技能侧已实现按 profile 档过滤 SKILL.md 索引表（`generate-skill.sh:1328` WP-P5），本决策给 swarm-yuan 自身 SKILL.md 加同层级的"按需折叠"——生成器自身先做到精简，生成的目标技能才能继承精简模式。


### 决策 33：范式作为条件而非内容——去抽象化重构与落地优先原则（2026-08-21，R13）

**决定**：swarm-yuan 从"内容驱动"重构为**两体系统（厚生成器 + 薄生成物）**，全部机制按"条件 vs 内容"判别式归位；总原则确立 **落地优先于删除**。

**背景**：R13 根本性复盘（zcode 会话库 32 主会话全量还原五轮"过重"诊断史 + 仓库病理量化 + Codex 源码级对照）确诊：范式被编码为要 AI 阅读、记忆、自觉执行的内容——40+ 概念体系靠机械打分落地（0 fail）、10/54 门禁默认不可触达、7 份行业 profile 无脚本加载、生成物 AI 读代码前先消费 5 万 token。维护者三问纠正：①概念体系不删除、完善落地；②门禁不下调；③industry-profile 必须真实加载。

**判别式**：机制分两类——**条件**（运行时约束行为、零认知占用、糊弄结构上不可能）与**内容**（要 AI 先读先记再自觉、每会话重复付税、糊弄结构上必然）。保护清单全部在条件侧；病灶清单全部在内容侧。补充教义：权限边界 fail-closed；fail-open 只允许在有下层强制兜底处。

**关键落地**（五批次，批次合计净 -653 行，diff 铁律机器验证）：
- 认知框架落地化：check_cognition 机械计分退役 → AI 判断引导 + `.swarm-yuan/notes/` 留痕（概念不删除，落地为"AI 判断的检查单"）
- 十门禁全接线：cert/cwe-audit→compliance 序列、decision/state-phase→full 序列、upstream-baseline→precheck 启动、其余挂宿主 hooks/loop-hook（可达率 54/54，FACT_GATES_TOTAL 保持 54）
- industry-profile 真实加载：`conf-render.sh --industry` 渲染 precheck.industry.conf 挂 source 链
- 模板减负：spec 仪式节折叠按需（9 核心节）/ workflow 10→4 要素 / 核对清单 96→12 / 五维表→两维表
- 门禁条件化：`scripts/gate-rules.sh` 三值求值器（allow/prompt/forbid 取最严）+ `rules.d/*.rules` 规则即数据 + FORBID 消息带替代方案
- 生成器瘦身：SKILL.md 重写为工作指引式（142→93 行/8.7KB，决策号/WP 号退出正文）/ facts 21 记账键退役 / check_doc_consistency 434→70 行（散文数字扫描退役——不手抄即无漂移）/ 税制断言（认知面 ≤256KB）
- 宿主下沉：Codex hooks 渲染（v0.148 exit 2=deny 经 codex-gate-wrapper.sh 协议适配）+ settings 沙箱通配符 deny（**/.env 防重命名绕过）+ failure-detector 叙事剧场退役

**验收（§6 进 self-check 断言）**：固定税 ≤8KB｜概念 ≤12｜可达率 54/54｜认知面 252KB<256KB｜孤儿资产=0（G18）｜反向引用=0（G19）｜吸收落地率 100%。

**预算变更**：FACT_GATES_TOTAL 54（不下调）/ FACT_ARTIFACT_BYTES_BUDGET=262144（新增）/ FACT_SKILLMD_BYTES_BUDGET=8192（新增）/ FACT_CONF_VARS_USERFACE=20（新增）。

### 决策 34：概念落地问责 + 吸收三问 + 生成物税制（防复胖三制度，2026-08-21，R13）

**决定**：三条防复胖制度成为生成器侧条件（self-check 机器可查），替代决策 26 的纯数量预算（数量预算只防新增，不防概念闲置——闲置才是棘轮失效的根因）。

1. **概念落地问责**：新概念体系进 SKILL.md 或生成物，必须同时给出落地路径（接线/AI 判断引导/路由——三选一，不接受"先放着"）。机器载体：self-check 概念消费路径断言。
2. **吸收三问**：①能否落到运行时条件（门禁/hook/脚本）？②替换既有机制还是叠加？③六个月后谁会引用？——三问不过只留调研报告（docs/research/），不进 references。R4 六段叠加吸收已按此回退（批次 0）。
3. **生成物税制**：进 UNIVERSAL_FILES 的审核问题 = "目标 AI 每会话为它付多少税"；行为参数留在包内不进全局配置（conf user 面收缩，43 glob 已迁 rules.d/framework-globs.rules）。机器载体：`FACT_ARTIFACT_BYTES_BUDGET` / `FACT_SKILLMD_BYTES_BUDGET` / `FACT_CONF_VARS_USERFACE` 三断言键。

**节奏注记**：批次之间至少间隔一个真实使用周期（用当前形态生成真实目标技能验证后再进下一批）——慢本身就是防复胖（07-21 一天 32 commit 曾被点名为"减重密度可疑"）。

**与决策 26 的关系**：决策 26 守"门禁数/conf 变量数"负向预算；本决策补"概念闲置/吸收纪律/生成物税"三个维度——同源（防膨胀）但覆盖存量与过程，不止数量。

**与决策 27 的关系**：决策 27（吸收优先于新增门禁）被三问强化——"吸收"不再自动成立，必须答出落地形态；方法论文档不再是合法归宿，条件是。

---

### 决策 35：创造纪律——未创建且未运行的机制不得声称（2026-08-24，audit-claims-reality 轮）

**决定**：§0.2 冲程一的反推纪律（机制必须答出派生自哪条本体关系）补第二条执法——**创造纪律：声称的机制必须能被创建（可运行）且被运行（CI/断言接线）；只存在于文档的机制不是实体，是传闻**。费曼两条的范式翻译：*What I cannot create, I do not understand*（未创建=不理解）；*Know how to solve every problem that has been solved*（已解未接线=未占有）。

**背景**：audit-claims-reality 轮三路并行审计发现 44 项"声称-现实"裂缝，全部可归约为两类创造缺失——①设计了没实现（precheck 启动接线在 source 前死调用、生成物 hooks 装错目录被 `|| true` 兜底静默失效、G-cognition/SKILLMD 预算空头断言）；②实现了没接线（`_count_advisory_only` 定义后零调用——最能抓漂移的函数自身是死代码、九个孤儿测试写完即脱钩、sarif-fixture 无 runner、Windows .bat 步骤被 `|| echo` 吞成永绿）。修复按 MECE 四类落地（A 功能断裂 11 / B 口径 7 组 / C 执法 7 / D 卫生 7，6 commit，verifier 八票绿）。

**执法载体**（防复发的结构性安排，不是一次性修复）：①facts.conf 每个 catchphrase 数字必须配 self-check 等值断言（子族六键/conf 变量四键模式）——新增数字不配断言即空头执法；②生成物接线由 gen-e2e mounted_in 锚机器守（hooks.json 引用路径实存断言）；③测试写完必须当批接 CI（孤儿测试=知识未占有）；④历史快照文档（decisions/research/verifier runs）旧数字刻意不同步——声称的边界清晰化也是纪律的一部分。

**与决策 34 的关系**：决策 34 的概念落地问责防"概念闲置"（新概念进 SKILL.md 须有落地路径）；本决策防"机制虚报"（既存声称须真被创建并运行）——一个管新增概念的入口，一个管既有声称的真值。

---

**决策索引（R13 后）**：决策 1-17 见 §6.6 A5 归档卷；决策 18-29 见本文前部；决策 30-32 自适应与压缩；决策 33-34 R13 重构与防复胖；决策 35 创造纪律（audit-claims-reality 轮）。


## 6.4 上游运行时基线（upstream-baseline）

> 16 个上游运行时的许可证/版本基线/drift 状态登记表。

> 用途：登记 swarm-yuan 引用/吸收的 **16 个上游运行时**的许可证与版本基线，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）与文档漂移治理。
> 数据来源：GitHub REST API + npm/PyPI registry **2026-08-21 实测**（本轮 R4 全量重核）；历史实测轮次见 `docs/research/R6-upstream-web.md` §0（2026-07-20）/ §6.6 A10（原 runtime-update-2026-07，2026-07-26）/ 2026-08-14 轮。
> **重核节奏（R13 批次3，§4.5.5）**：从"每轮全量重核 16 个"改为**破坏性变更驱动**——上游 GitHub release 标 breaking/major 时触发重核 + 季度例行一次。重核是维护不是成长，砍全量形态给成长腾带宽。
> 机器可读契约：每个 drifted 条目所在行必须含字面漂移标记（行尾「机器标记」列，格式 baseline_status=状态值）；self-check 的轻量基线忠告仅 grep 漂移标记所在行并 warn（不联网）。
> 状态取值：`synced`（基线≈最新）｜`drifted`（基线落后，需重核）｜`watch`（迭代极快，持续观察）｜`license-risk`（许可证合规风险）。
>
> **本地缓存建议**：`swarm-yuan/research/` 下的上游 clone 仅供 AI 阅读源码（已 gitignored，不入 git），无需 commit 历史。建议用 `git clone --depth 1` 浅克隆——12 个 clone 的 `.git` 历史合计约 1.1GB，浅克隆可省 ~1GB 本地磁盘（ruflo/claude-mem/gsd-core/open-code-review 四个 `.git` 占比最高）。

### 一、16 运行时登记表

> **口径注（2026-08-21 R4）**：本表 16 行 = 供应链登记总口径（13 整合运行时 + dsh 纯方法论源 + claude-code/codex 两个核心安装目标 CLI）。SKILL.md 的"整合 13 个外部运行时"（`FACT_RUNTIMES=13`）是**接线分层口径**（深度 4 + CLI 4 + 方法论 5），两者语义不同：claude-code/codex 是 swarm-yuan 生成技能的**宿主**而非被整合对象，dsh 是方法论源而非运行时接线——三者不进 FACT_RUNTIMES 分层计数。

| 名称 | 仓库 | 许可证 | 引用基线 | 2026-08-21 最新版 | 状态 | 机器标记 |
|------|------|--------|----------|--------------------|------|----------|
| openspec | Fission-AI/OpenSpec | MIT | v1.10.0（2026-08-21 升级；`references/review-methodology.md:130`） | npm 1.10.0 | synced（2026-08-21 升级；吸收 v1.10 task plan 强制完成判据 + 诊断输出一律走 stderr 纪律） | baseline_status=synced |
| claude-code | anthropics/claude-code | 专有（Anthropic Commercial Terms；CLI 二进制分发，源码不开） | v2.1.232（2026-08-13 调研基线；`references/claude-code-capabilities.md` 全 159 版调研） | npm @anthropic-ai/claude-code 2.1.237（2026-08-20） | synced（2026-08-21 R4 补核 v2.1.233-237 五版；吸收 Todo/Task 工具默认移除（Sonnet 5+/Opus 4.8+，`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 兜底）+ `ANTHROPIC_DEFAULT_MODEL` + `notify_when_idle` 跨会话通知 + "Concise" output style + 沙箱通配符 read-deny 防重命名绕过） | baseline_status=synced |
| codex-cli | openai/codex | Apache-2.0 | v0.146.0（2026-08-14 调研基线；`references/codex-methodology.md` 省 token 三件套/review rubric/测试哲学执行纪律） | npm @openai/codex 0.148.0（2026-08-18 rust-v0.148.0；v0.149.0-alpha.4 2026-08-20 预告） | synced（2026-08-21 R4 补核 v0.147/v0.148 两 stable + v0.149-alpha 预告；吸收 v0.147 Agent Plugins 四类目录 + `--approve-for-me` 审批自动化 + v0.148 `/export` 会话导出 + hooks 异步命令 + MCP 工具调用 + skill-creator validation 拒绝 TODO 占位符；**破坏性**：v0.147 移除 `codex exec --full-auto` 改用 `--sandbox workspace-write`；v0.149-alpha 移除技能模型委托） | baseline_status=synced |
| comet | rpamis/comet | MIT | v0.3.9（`references/subagent-orchestration.md:118`） | npm 0.4.0-beta.18（2026-08-21 重核；仍 beta 通道） | drifted（观望——0.4.0-beta 已发到 beta.18 仍无正式版；等 0.4.0 正式版发布后升级引用基线） | baseline_status=drifted |
| GitNexus | abhigyanpatwari/GitNexus | **PolyForm Noncommercial 1.0.0**（禁商用，API 返回 NOASSERTION，LICENSE 原文实测） | npm 1.6.9（引用 `context/trace`） | npm 1.6.9（2026-08-21 重核，仍停滞于 2026-07-04） | license-risk（降级为非默认，仅非商用可选） | baseline_status=license-risk |
| gsd-core | open-gsd/gsd-core | MIT | v1.11.0（2026-08-21 升级；`references/gsd-patterns.md` + `references/decision-governance.md` §2.4 + `references/review-methodology.md:311`） | npm 1.11.0（next 分支 tag） | synced（2026-08-21 升级；吸收 v1.11 guard 必须能观测自身失败分支 + STATE.md 盖 commit 戳新鲜度检测 + validator 收敛统一 envelope） | baseline_status=synced |
| claude-mem | thedotmack/claude-mem | Apache-2.0 | v13.15.3（2026-08-21 升级；`references/memory-persistence.md` sensitive 观察类型吸收 + G10 版本 oracle 吸收） | npm 13.15.3 | watch（迭代极快；2026-08-21 升级 + 吸收 v13.15.x 错误信封分类 quota 不重试 + 多界面文案单一事实源） | baseline_status=watch |
| ocr | alibaba/open-code-review | Apache-2.0 | v1.9.8（2026-08-21 升级；`references/review-methodology.md`） | v1.9.8（Go） | synced（2026-08-21 升级；吸收 v1.9.3-8 JSON/SARIF 输出时进度走 stderr + 非 TTY 关颜色 + api_key 从命令解析 + SARIF 输出 + resume 可信校验） | baseline_status=synced |
| graphify | Graphify-Labs/graphify（原 safishamsi/graphify，已迁移） | Apache-2.0（2026-07-18 MIT->Apache 2.0，v0.9.25） | v0.9.47（2026-08-21 升级，origin/v8 线；`references/code-graph-tools.md` Windows 可移植性吸收 + `references/memory-persistence.md` 知识溯源三标吸收） | npm graphifyy 0.10.0 / PyPI 0.9.47 | synced（2026-08-21 升级 research 仓库到 v0.9.47；**v1.0.0 是异源旧分支不取**——2026-04-05 发布，与 v0.9.47 diverged；吸收 v0.9.43-47 OCaml/CommonLisp 语言扩展 + no-op 产物字节一致幂等写入 + 超时二分降级） | baseline_status=synced |
| superpowers | obra/superpowers | MIT | v6.3.0（2026-08-14 升级；`references/subagent-orchestration.md` 修复环+5轮熔断 + brainstorming 仪式按任务规模缩放吸收 + `references/review-methodology.md` 可证伪性纪律吸收；**核心插件未 vendor**，离线包仅 marketplace 元数据；不 vendor 决策见 §6.6 A8） | v6.3.0（2026-08-21 重核，无新版） | synced（2026-08-14 升级；吸收 v6.3 brainstorming 仪式按任务规模缩放 + controller 冲突不卡住 + resume-fix-loop/scoped-re-review/falsifiability） | baseline_status=synced |
| gstack | garrytan/gstack | MIT | v1.68.2.0（2026-08-21 升级，master commit 51932ec；offline-cache vendor `offline-cache/gstack/VERSION:1`） | v1.68.2.0（2026-08-20 commit；无 release 无 tag，版本靠 VERSION 文件递增） | synced（2026-08-21 升级；吸收 v1.60-68 pipeline guard 全部可证明触发 + evidence ledger + fail-closed hooks + issue/PR 关闭附 receipt 证据） | baseline_status=synced |
| ruflo | ruvnet/ruflo（原 Claude Flow） | MIT | v3.38.12（2026-08-21 升级；`references/subagent-orchestration.md:277`、`references/review-methodology.md:208-209`） | npm 3.38.12（npm 领先 GitHub release 3.38.9，以 npm 为准） | synced（2026-08-21 升级；3.38.10-12 为 patch 列车 + SynthID-Text 水印 crate 新方向（本仓不吸收——与运行时无关）；方法论引用层，无运行时调用） | baseline_status=synced |
| ECC | affaan-m/ECC | MIT | v2.1.0（2026-08-14 升级；`references/subagent-orchestration.md:149`；Plan Canvas 可视化 plan review + Kimi Code harness） | v2.1.0（2026-08-21 重核，仍 2026-07-27 版） | synced（2026-08-14 升级；吸收 Plan Canvas 可视化审查） | baseline_status=synced |
| impeccable | pbakaus/impeccable | Apache-2.0 | v4.1.1（2026-08-21 升级；`references/frontend-design-methodology.md`，方法论引用层第 5 对象；Modes/三层权威/craft-floor/59 反模式字典/finish_reviewer 完工审查模式 + v4.1 对抗性 verdict 多候选先内部比较再呈交 + 平台感知验证 + 证据坏则重取证重跑；G13 断言守引用存在性） | v4.1.1（2026-08-14 GitHub 实测，tag 名 skill-v4.1.1） | synced（2026-08-21 升级；吸收 v4.1 对抗性 verdict + 平台感知验证 + 拒绝假证据纪律） | baseline_status=synced |
| codex-security | openai/codex-security | Apache-2.0（完全开源） | v0.1.16（2026-08-21 升级；`references/codex-security-methodology.md`，CLI 接线层第 4 对象；**AI 约束推理扫描（非传统 SAST——OpenAI 官方明确「不包含 SAST 报告」）** + source→sink 数据流 + 静态评估七元组 + 威胁模型五要素 + 攻击路径分析 + SECURITY.md 策略合并 + scan contract 三件套 + 14 bundled skills + Docker 沙箱范式；v0.1.16 Linear 深度集成 + 交互式修复闭环 + verify-fix 只读命令 + bulk-scan 每仓库成本上限；`--sast-deep` 门禁 `SAST_DEEP_TOOL=codex-security` 时显式调用，**非降级链一环（非 SAST，auto 降级链不变，两者正交可并行）**；开源 Apache-2.0，Trusted Access 非付费门槛（推荐的身份审核），API 按 token 计费；G15 断言守 CLI 接线存在性） | v0.1.16（2026-08-20 GitHub 实测） | synced（2026-08-21 升级；吸收 v0.1.12-16 Linear 深度集成 + 交互式修复闭环 + verify-fix + bulk 成本上限） | baseline_status=synced |
| dsh | deepseek-ai/deepseek-harness | MIT | dsh-v0.1.0-rc.8（2026-08-20 R12 重调研；`references/dsh-engineering-methodology.md` 四簇吸收——决策审计/状态韧性/增量自成长/工程纪律） | dsh-v0.1.0-rc.8（2026-08-21 重核，master HEAD=141eb6f 2026-08-19 与 rc.8 对齐） | synced（2026-08-20 R12 重调研落地；rc.8 无新版） | baseline_status=synced |

### 二、关键结论

1. **许可证风险（最高优先）**：GitNexus = PolyForm Noncommercial 1.0.0，禁止商业使用。冻结措辞（全仓库统一引用）：**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（Apache-2.0，2026-07-18 MIT->Apache 2.0）提为默认代码图谱工具。**
2. **版本漂移（1 项 drifted，2026-08-21 重核后）**：comet 0.3.9→0.4.0-beta.18（仍观望——beta 已发到 beta.18 但无 0.4.0 正式版；等正式版发布后升级引用基线）。本轮 2026-08-21 全量重核把 openspec/gsd-core/claude-mem/ocr/graphify/gstack/ruflo/impeccable/codex-security 9 项升级到最新并吸收对应方法论（详见各条目吸收注记 + §6.6 A11 运行时升级报告）。
3. **watch（1 项）**：claude-mem 迭代极快（13.15.0->13.15.3，3 天 3 个 patch），持续观察；2026-08-21 升级 research 仓库到 v13.15.3 并吸收错误信封分类 + 多界面文案单一事实源纪律。
4. **org 迁移**：graphify 仓库已迁至 Graphify-Labs/graphify，引用一律用新 URL。
5. **存续风险**：16 个运行时中个人/小团队项目占比高（comet/GitNexus/claude-mem/gsd-core），上游存续监测纳入审计例程；GSD v1 上游（gsd-build/get-shit-done）已于 2026-06-26 归档，引用 open-gsd/gsd-core 为既定应对。
6. **gstack 版本递增节奏**：v1.60.1.0（2026-08-14 基线）→ v1.68.2.0（2026-08-20 master HEAD）7 天 8 个 minor——大批量 tracker 清理波（v1.64.0 90 修复 + v1.64.1 净删 24,943 行 + v1.68.0 16 验证修复）；本仓引用为 vendor 离线包，离线包内容不升级（vendor 决策见 §6.6 A8），只升引用基线。

### 三、CLI 侧版本差异专题（2026-08-21 R4 补核：Claude Code + Codex）

两个 AI CLI 是 swarm-yuan 的核心安装目标（install.sh 检测 7 工具中最重要的两个），单列差异分析：

#### 3.1 Claude Code v2.1.232 → v2.1.237（五版，2026-08-14 至 08-20）

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Todo/Task 工具默认移除** | v2.1.233 | TaskCreate/Get/Update/List、TodoWrite 在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 及更新模型上默认不可用；`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 恢复 | **破坏性**：生成的 SKILL.md 若依赖 TodoWrite 跟踪门禁进度，在新模型上会失效——目标技能的进度跟踪须走 trace-log.sh（本仓自有链路），不依赖 CLI Todo 工具 |
| `ANTHROPIC_DEFAULT_MODEL` | v2.1.236 | 设定新会话起始模型（区别于 `ANTHROPIC_MODEL` 的强制语义）；`/model` 选择可覆盖并跨重启持久 | install.sh 检测后可为不同能力档模型生成不同强度的门禁提示（登记候选） |
| `notify_when_idle`（SendMessage） | v2.1.236 | 请求本机另一个 Claude Code 会话在下次空闲时发一条通知——opt-in、一次性、无轮询 | 跨会话异步协作原语：未来"门禁长跑完成后通知主会话"可走官方机制而非轮询（登记候选） |
| **"Concise" output style** | v2.1.237 | 内置简洁输出风格：直接给结果、跳过开场白和叙述 | 与门禁驱动开发契合（跑门禁-看结果-修复，无需叙述）；生成技能的使用文档可推荐 |
| 沙箱通配符 read-deny | v2.1.236 | macOS 沙箱 `**/.env` 类规则在 allowed read 区域内优先生效、无法通过重命名绕过 | 目标技能的敏感信息保护可利用（settings.local.json deny 规则更强了） |
| `claude-api` 技能 200k→25k | v2.1.234 | 参考文档改为按需加载，上下文成本降 87.5% | **样板**：swarm-yuan references/ 的"按需读取引用索引"（WP-P5）正是同构机制，方向验证 |
| Bash 工具内存限制 | v2.1.233 | Linux 上 `CLAUDE_CODE_TOOL_MEMORY_LIMIT` opt-in cgroup 限制，防失控 build 拖死会话 | 生成的 precheck.sh 若含大构建命令，可建议配置（目标技能文档提示） |
| 用量限额自动续会话 | v2.1.234 | 限额重置后自动继续（`/config` 可关） | 运维便利性，无直接吸收 |

**评估**：Claude Code 在把"过程管理"内化——Todo 工具移除（模型自身管任务）、Concise style（砍叙述）、权限精确化。swarm-yuan 的门禁进度跟踪走自有 trace-log 链路（不依赖 CLI Todo），方向正确。

#### 3.2 Codex v0.146.0 → v0.148.0（两 stable，2026-08-07 / 08-18）+ v0.149-alpha 预告

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Agent Plugins** | v0.147 | 可移植插件安装，跨 local/personal/workspace/remote 四类目录搜索 | 生成技能的分发新通道：打包为 Codex 插件而非仅放 `~/.codex`（登记候选） |
| **`--approve-for-me`** | v0.147 | CLI flag 自动审批的正式入口 | Guardian 审批体系入口；高危门禁命令可标注给自动审批分类器（观察项） |
| **hooks 异步命令 + MCP 工具调用** | v0.148 | Codex hooks 支持 async 执行 + 调 MCP 工具 | **重要机会**：precheck 门禁可注册为 Codex hook 而非仅靠 prompt 约定——门禁"执法"在 Codex 侧获得官方强制点（登记候选，下轮评估） |
| `/export` 会话导出 | v0.148 | TUI 会话完整导出 Markdown | 门禁验收记录可随会话导出留档（契合 ai-process-records 方法论） |
| 会话 fork/归档/排队消息 | v0.148 + v0.149-alpha | `codex exec fork`、归档恢复、排队消息分发 | 会话资产化；多会话工作流原语 |
| **skill-creator validation 拒绝 TODO 占位符** | v0.148 | 内置技能验证不再通过未完成 TODO | 本仓 `--verify-completeness` 零占位符检测同构，方向验证 |
| **移除 `codex exec --full-auto`** | v0.147（**破坏性**） | 改用 `--sandbox workspace-write` | install.sh 对 Codex 目标的检测逻辑应查版本 ≥0.147；生成脚本禁用 `--full-auto` |
| 移除技能模型委托 | v0.149-alpha（预告） | skills 不能再指定委托模型 | 生成的 SKILL.md 若有按子任务指定模型的设计需提前去依赖（本仓无此设计，无影响） |
| Guardian v2 审批体系 | v0.149-alpha | 风险分类改进、transcript 图像审查、风险评分 fail-closed、默认跳沙箱命令 | 审批自动化基础设施成形；观察 `--approve-for-me` 成熟度 |
| 安全加固密集波 | v0.149-alpha | apply_patch 不扩大写权限、Seatbelt 防重命名、AGENTS.md 加载权限校验、skill 安装防 symlink、"Git 命令不再天然安全" | 沙箱边界持续收紧；本仓 fail-gate-hook 的 Bash 推进态拦截方向一致 |

**评估**：Codex 在补"可信自动批准"基础设施（Guardian）+ 会话资产化（fork/归档/导出）。hooks 支持 MCP 工具调用是本仓门禁在 Codex 侧获得官方强制点的最重要机会。

#### 3.3 共同信号：过程管理从 prompt 约定下沉为运行时机制

两个 CLI 都在把"过程管理"（任务跟踪/审批/输出风格）从 prompt 约定下沉为运行时机制。swarm-yuan 的"特征卡立法 + 门禁执法"分层正依赖此方向——门禁从 bash 脚本 + prompt 约定逐步迁移到各 CLI 的官方 hook/审批机制，是未来 1-2 个版本最值得投入的适配线。

### 四、comet 0.4 能力重核结论（P1-7，2026-07-20 实测）

**结论：观望**——引用基线保持 v0.3.9，状态维持 drifted；待 0.4.0 正式版发布后升级为 v0.4.x 并同步修订 `references/subagent-orchestration.md` 的 v0.3.9 能力清单。

#### 4.1 重核事实（0.3.9 → 0.4.0-beta.x 的实际变化）

来源（均 2026-07-20 访问）：

- npm registry：dist-tag latest=0.4.0-beta.6（2026-07-20 发布；beta.1 始于 2026-07-07，14 天 6 个 beta）——https://registry.npmjs.org/@rpamis/comet
- 0.4.0-beta.1 全量说明——https://raw.githubusercontent.com/rpamis/comet/master/NEWS.md
- beta.2–beta.6 增量——https://raw.githubusercontent.com/rpamis/comet/master/CHANGELOG.md
- 0.3.x 系列发布说明——https://github.com/rpamis/comet/releases

**状态机**：Bash 脚本层 → 跨平台 Node 运行时（`.mjs` launcher + 共享 `comet-runtime.mjs`，不再要求 Git Bash/WSL）；机器检查点从 `.comet.yaml` 分离到 `.comet/run-state.json`（用户可编辑字段仍留 YAML）；新增稳定 CLI `comet state|guard|handoff|archive`（beta.4），agent 不再依赖内部安装脚本路径；`comet state rebind` + isolation 绑定分支漂移检测（beta.6）。

**硬前置**：verify-pass 仍要求 verification_report 指向存在文件 + branch_status=handled（0.3.9 语义保留）；新增 artifact 语言守卫 fail-closed（language 非法即拒，beta.1）；归档最终用户确认记入机器态、未确认拒绝变更性归档，防止直接调脚本绕过确认（beta.4）；isolation 漂移在 build/verify/archive 入口检查与写守卫处一律拦截（beta.6）。

**证据链**：阶段迁移写 `.comet/state-events.jsonl` 审计历史（beta.1）；无 npm/Maven/Cargo 推断命令的项目可登记可审计 build/verify 证据，替代原先未文档化的跳过路径（beta.4）；verify 失败自动回 Build 前 3 条可执行发现、连续失败计数跨恢复持久化、CRITICAL/IMPORTANT 不可豁免（beta.5）。

**吸收面之外的新能力**（登记备查，不构成本仓引用）：`/comet-any` Skill Creator、`comet eval`（pass@k/pass^k 评估）、`comet dashboard` 本地只读看板（beta.1 起）。

#### 4.2 观望理由

1. **0.4 仍在 beta 通道快速收敛**：14 天连发 6 个 beta，语义仍在变动（beta.3 移除自定义 guard 命令字段、beta.6 改 isolation 绑定语义），现在升级引用基线等于追移动目标。
2. **swarm-yuan 对 comet 是方法论级引用，非运行时调用**：`SKILL.md:108` 允许 CLI 清单不含 comet；`assets/state-machine.sh` 是自实现的「comet 风格」状态机。Bash→Node 迁移不造成功能性破坏；已吸收核心理念（脚本背书状态机、无证据不流转、handoff SHA256）在 0.4 全部保留且增强。
3. **能力清单形态已过时但语义未失效**：`references/subagent-orchestration.md:116-118` 登记的 7 个 `.sh` 脚本（comet-guard.sh 等）在 0.4 变为 `.mjs` launcher + 稳定 CLI；升级引用基线时需同步重写该清单，与正式版升级一并进行更经济。

**复审触发条件**：npm dist-tag latest 出现 0.4.0 正式版（非 beta）→ 升级引用基线为 v0.4.x、状态改 synced、重写能力清单（脚本形态 + run-state.json/state-events.jsonl + 稳定 CLI + isolation 绑定语义）。

**2026-08-21 R4 重核**：0.4.0-beta.18（2026-08-13）仍 beta 通道，14 天 6 beta → 38 天 18 beta，发版节奏加快但正式版未出。维持观望结论；beta.4-18 间新增 `.comet/run-state.json` 与 `.comet/state-events.jsonl` 分离、稳定 CLI `comet state|guard|handoff|archive`、verify 失败回 Build 前 3 条可执行发现 + 连续失败计数持久化、CRITICAL/IMPORTANT 不可豁免、isolation 漂移在 build/verify/archive 入口与写守卫处拦截——这些与本仓 fail-gate-hook.sh 的 flag 捕获模型 + R12-A 全量审计 + R3-2 last-good 红线机器执法语义对齐，理念已在自实现路径落地，无需追 beta。

### WP-Y：自动化 drift 检测

上述 `baseline_status=drifted` 的 1 项（comet，2026-08-21 重核后仍观望；其余 8 项本轮已升级为 synced）现在由 `--upstream-baseline` 门禁自动检测。
门禁扫描本文件的 `baseline_status=` 标记，drifted 项 warn 提示（advisory 级，不阻断交付）。

**处置策略**（2026-08-21 R4 更新）：
- **comet**：0.4.0 正式版发布后升级引用基线（swarm-yuan 对 comet 是方法论级引用，state-machine.sh 是自实现的 comet 风格状态机，升级不阻塞）
- **graphify**：2026-08-21 已升级 research 仓库到 v0.9.47（Apache 2.0，origin/v8 线）并吸收 OCaml/CommonLisp 语言扩展 + no-op 产物字节一致幂等写入 + 超时二分降级（**不取 v1.0.0 异源旧分支**——2026-04-05 发布，与 v0.9.47 diverged）
- **gstack**：2026-08-21 升引用基线到 v1.68.2.0（vendor 离线包内容不动——仍 v1.60.1.0 时代码快照；只升引用基线反映"跟踪到哪个上游版本"）
- **ruflo**：2026-08-21 升引用基线到 npm 3.38.12（npm 领先 GitHub release，以 npm 为准）

升级基线时：更新本表"引用基线"列版本号 → 将 `baseline_status=drifted` 改为 `baseline_status=synced` → 跑 `bash scripts/self-check.sh --check-only` 确认无 drift warn。


## 6.5 使用手册（USAGE）

> 命令级使用参考：生成/激活/升级/门禁/审计全命令行手册。

> 对 AI 说"为这个项目生成 skill"，AI 全自动探查 → 生成 → 配置 → 验证，你拿到一套零占位符的项目专属开发技能。
>
> **口径权威源**：`assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。
>
> **两体阅读提示**：本文覆盖两个对象——**生成器**（swarm-yuan 本身，"生成"段落操作它）与**目标技能**（生成器产出的项目专属规则包，"日常使用"段落操作它；亦称"生成物"）。17 项特征卡、55 个门禁、四本账都是**目标技能**的资产；生成器是它们的模板来源。

---

### 1. 核心设计理念

swarm-yuan 的设计基于三个关键理念：

#### 理念一：先认识，再行动（认知递进）

AI 写代码前必须先认识项目——概念→结构→空间→映射→规律→处理。不认识就写 = 盲动。swarm-yuan 生成的目标技能用 **17 项特征卡** 完成认知，用 **55 个质量门禁** 守护行动。

#### 理念二：拼装式开发（复用优先）

新功能 = 既有稳定单元的拼装 + 最小新增胶水代码。禁止重复造轮子、禁止侵入式重构、禁止破坏性改造。特征卡第 11 项盘点全部可复用单元，门禁 `--reuse` 验证复用合规。

#### 理念三：呈现递进的关系，而非仅关注计算

门禁不是"数 import 数"——每个计数背后指向一条关系规律。`--layer` 数 import 是为了验证"结构是否遵循依赖单向"；`--reuse` 数新增导出是为了验证"概念是否复用了既存稳定单元"。

---

### 2. 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

| 选项 | 安装到 |
|------|--------|
| `--claude` | `~/.claude/skills/` |
| `--codex` | `~/.codex/skills/` |
| `--cursor` | `~/.cursor/skills/` |
| `--windsurf` | `~/.codeium/windsurf/skills/` |
| `--opencode` | `~/.config/opencode/skills/` |
| `--gemini` | `~/.gemini/skills/` |
| `--kimi` | `~/.kimi/skills/` |
| `--all` | 所有已检测到的环境 |
| `--list` | 仅列出检测到的环境 |

---

### 3. 特征卡：项目的「认知 DNA」

#### 什么是特征卡

特征卡是 AI 探查项目后提取的 **17 项项目特征**，每项落到真实路径和版本号，不用占位符。它不是独立文件，而是**分散承接进目标技能的各个文件中**，是门禁配置和文件填充的「数据源」。

**没有特征卡，门禁就是无源之水——不知道项目边界在哪、哪些单元稳定、什么领域规律不能违反。**

#### 17 项特征卡详解

| # | 特征项 | AI 提取什么 | 为什么重要 |
|---|--------|-----------|-----------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务/库 | 决定后续探查策略和门禁配置方向 |
| 2 | **可改范围** | 可改目录列表 + 只读目录列表 + 只读区修改机制 | **安全铁律的依据**——改了只读区 = 违规 |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) 或 core/plugin 或 src/lib | **决定代码怎么写**——A类放 custom/，B类放 patches/ |
| 4 | 技术栈摘要 | 语言+主框架+构建+测试（含版本基线） | 版本锁定铁律的依据，`--deps` 门禁的对比基线 |
| 5 | **构建发布命令** | dev/build/test/release 真实命令 + 端口 | **门禁执行的基础**——`--build` 和 `--test` 跑这些命令 |
| 6 | 分支规范 | 命名格式/合入策略/保护分支/推送规则 | `--branch` 门禁的校验规则 |
| 7 | 安全规则 | 脱敏规则/密钥管理/网络白名单 | `--sensitive` `--security` 门禁的扫描范围 |
| 8 | 文档约定 | spec/plan 位置和命名格式 | spec 文件创建时的路径和命名 |
| 9 | 测试体系 | 框架/目录/运行命令 | `--test` 门禁的执行命令 |
| 10 | 环境与外部资源 | 运行时版本/DB/缓存/MQ/MCP 工具 | `--service` 门禁的微服务配置 |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（五维字段定义见 `references/exploration-guide.md` §11f） | **拼装式开发的核心依据**——`--reuse` 门禁的重名检测源 |
| 12 | 数据规范 | schema 位置/样例数据/业务规则/勾稽关系 | `--consistency` 门禁的勾稽核对项 |
| 13 | 认知框架 | 认知映射表 + 六维动力学基线（速度/聚散/趋势/强度/能耗/累积量） | `--cognition` 门禁的对比基线 |
| 14 | **领域知识** | 技术+业务领域识别 → 推导客观规律 | **防达克效应**——`--domain` 门禁的违规检测依据 |

#### 特征卡如何驱动一切

**特征卡 → 文件填充（Step 4）：** SKILL.md 的铁律来自第 2/6 项 → codebase.md 的技术栈来自第 4 项 → dev-guide.md 的改造分类来自第 3 项 → reference-manual.md 的组件库来自第 11 项 → release.md 的命令来自第 5 项……17 项特征卡是目标技能所有文件的「数据源」。

**特征卡 → 门禁配置（Step 5）：** precheck.conf 三件套 178 个变量（core 18 + arch 112 + compliance 48）从特征卡推导：

| 配置变量 | 来自特征卡第几项 |
|---------|----------------|
| PROJECT_DIR / WRITABLE_DIRS / READONLY_DIRS | 第 2 项（可改范围） |
| TEST_CMD / BUILD_CMD | 第 5 项（构建命令） |
| LAYER_DEFS / LAYER_ORDER / DOMAIN_LAYER | 第 3 项（改造分类） |
| STABLE_GLOBS | 第 11 项（可复用单元） |
| SERVICE_DIRS / DB_CONFIG_FILES | 第 10 项（环境资源） |
| STORE_DIR / COMPONENT_DIR | 第 11 项（可复用单元） |
| ADR_DIR / GLOSSARY_FILE | 第 7/8 项（安全/文档） |
| SCAN_DIRS / CONSISTENCY_DIRS | 第 7/12 项（安全/数据） |
| COG_SPEED_FILES / COG_CUMULATIVE_TODO | 第 13 项（认知框架） |

**特征卡 → 开发流程（日常使用）：** 开始新需求时，AI 从特征卡第 11 项检索可复用单元，预填 spec §5.5 复用约束。编码时 AI 查特征卡第 11 项的组件库清单，拼装优先。提交前 55 个门禁按特征卡配置的规则检查。

#### 特征卡探查工具矩阵

每项探查优先用运行时工具，无则降级到内置 grep：

| # | 特征项 | 优先工具 | 降级 |
|---|--------|---------|------|
| 1 | 项目类型 | gitnexus `query "architecture"` + graphify `explain` | Read package.json |
| 2 | 可改范围 | claude-mem `search "project rules"` + Read AGENTS.md | Glob + Grep |
| 4 | 技术栈 | gitnexus `query "tech stack"` + graphify `explain` | Read package.json |
| 9 | 测试体系 | gitnexus `query "test files"` | Glob `**/*.test.*` |
| 10 | 环境资源 | gitnexus `route_map` + `tool_map` | Grep "host/port" |
| 11 | 可复用单元 | **gitnexus `context <symbol>`**（360 度上下文） | Grep `export` |
| 12 | 数据规范 | gitnexus `query "data models"` | Grep `CREATE TABLE` |
| 14 | 领域知识 | gitnexus `query "domain"` + claude-mem + WebSearch | Read 领域模型 |

> 注：GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（MIT）提为默认代码图谱工具——商用场景请把上表 gitnexus 优先位替换为 graphify（依据见 `references/code-graph-tools.md` §许可证与选型）。

大型项目（>100 文件）可用 Dynamic Workflow 并行扇出三路子代理，交叉验证特征卡。

#### 落地示例（SwarmStudio overlay 项目）

| # | 特征项 | 真实值 |
|---|--------|--------|
| 1 | 项目类型 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改范围 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | 改造分类 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 4 | 技术栈 | Vue 3 + TypeScript + Vite + NaiveUI + Vitest + SQLite + Koa |
| 5 | 构建命令 | `npm run dev`(:8649) / `npm run build` / `npm test` / `npm run inject` |
| 11 | 可复用单元 | CockpitWorkspace / CockpitKanban / GatewayNoticeBanner 等 15+ 组件 |
| 14 | 领域知识 | IM 通讯（Matrix 协议）+ DevOps 监控（cockpit 看板） |

---

### 4. 质量门禁：特征卡的守卫者

#### 门禁与特征卡的关系

特征卡定义了「项目应该是什么样的」，55 个门禁验证「代码是否符合特征卡定义的规则」。

#### 门禁分层（决策 19，横切维度）

55 门禁按 `fail()` 调用能力分三档（strict 17 / warn 22 / advisory 16），与 core/standard/compliance 三档正交（一个门禁同时属于 core + strict，或 standard + advisory）：

| 分层 | 数量 | fail() 能力 | 行为 | 门禁清单 |
|------|------|------------|------|----------|
| **strict** | 16 | ≥3 fail | 真 fail 阻断交付 | branch / layer / reuse / security / shift-left / compliance / sbom / release-sign / dengbao / pia / quality-model / test-evidence / review-record / sast-deep / oss-eval / loop-oracle |
| **warn** | 23 | 1-2 fail | 能 fail 但触发窄，混合 warn | scope / build / test / sensitive / review / stable-diff / deps / adr / contract / impact / service / api / frontend / domain / knowledge / docs-pack / framework / metrics / privacy / authz / requirements / rtm / crypto |
| **advisory** | 15 | 0 fail | 永不 fail，只 warn/pass（认知/观测类） | consistency / link-depth / consistency-cross / state / diagram / operate / decision-audit / cognition / cwe-audit / cert-audit / learnings / pr-quality / skill-supply-chain / state-phase / upstream-baseline |

- **advisory 机器化**：子 shell 内重定义 `fail()`/`warn()` 为纯 echo，永不进 FAIL_COUNT/WARN_COUNT——"advisory 是观测类，不阻断交付"语义机器化
- **查看分层**：`bash scripts/precheck.sh --list-gates`（输出 flag / gate_fn / enforce / tier 四列）
- **自动归类**：`bash scripts/gen-enforce-level.sh` 扫 precheck.sh fail() 数，重生成 `assets/gate-enforce-level.conf`（幂等）
- **手动覆盖**：precheck.sh 顶部 `_ENFORCE_OVERRIDE_K`/`_ENFORCE_OVERRIDE_V` 数组（如 `check_review` 想从 warn 升 strict）
- **自检**：`self-check.sh` 校验 conf 与 precheck.sh fail 数一致 + strict 门禁必含 ≥1 fail()（防 strict 声明空壳）

**特征卡是立法，门禁是执法。**

| 特征卡项 | 立法定义 | 门禁执法 |
|---------|---------|---------|
| 第 2 项 可改范围 | overlay/ 可改，upstream/ 只读 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项 构建命令 | `npm run build` | `--build` 运行此命令，非零 = fail |
| 第 6 项 分支规范 | feat/fix/refactor | `--branch` 校验分支名是否匹配正则 |
| 第 7 项 安全规则 | 密钥不入代码库 | `--sensitive` `--security` grep 扫描密钥模式 |
| 第 11 项 可复用单元 | CockpitWorkspace 等稳定单元 | `--reuse` 检测新增单元是否与既有重名 |
| 第 11 项 稳定层 | STABLE_GLOBS 指定的文件 | `--stable-diff` 检测稳定层是否被改而未声明 |
| 第 14 项 领域知识 | 密码必须哈希 | `--domain` grep 检测密码明文存储 |

#### 核心门禁（`--all` 跑 10 个，通常 10-20 秒，取决于项目规模与 build/test 命令耗时）

| 门禁 | 检查什么 | fail 条件 | 特征卡依据 |
|------|---------|----------|-----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 | 第 6 项 |
| `--scope` | 改动范围（可改 vs 只读） | 只读目录有改动 | 第 2 项 |
| `--build` | 构建通过 | 构建失败 | 第 5 项 |
| `--sensitive` | 敏感信息脱敏 | 密码/密钥/token 明文 | 第 7 项 |
| `--consistency` | 业务规则 + 数据勾稽 | 人工核对项（提示性） | 第 12 项 |
| `--review` | 代码审查（5 维度） | ocr 检测到 High 级问题 | — |
| `--reuse` | 复用合规（拼装式开发） | spec 缺 §5.5 / 新增单元与既有重名 | **第 11 项** |
| `--deps` | 依赖版本锁定 | 依赖版本变更但 spec 未声明 | 第 4 项 |
| `--security` | 安全规范（OWASP Top 10） | 注入/eval/XSS/硬编码密钥/TLS 关闭 | 第 7 项 |
| `--test` | 测试通过 | 测试失败 | 第 5/9 项 |

#### 架构门禁（`--all-full` 额外跑 17 个，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | 第 3 项 |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | **第 11 项** |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | 第 13 项 |
| `--adr` | 架构决策记录（ADR + 技术债登记） | 第 8 项 |
| `--contract` | 接口契约（version + ACL 防腐层） | 第 10 项 |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | 第 12 项 |
| `--impact` | 变更影响分析（消费方反查） | — |
| `--service` | 微服务架构（共享 DB/同步链/网关/trace） | 第 10 项 |
| `--api` | API 契约与幂等 | 第 10 项 |
| `--state` | 前端状态管理（巨型 store/prop drilling） | **第 11 项** |
| `--frontend` | 前端组件架构（层级/props/循环依赖/CSS 污染） | **第 11 项** |
| `--cognition` | 认知递进体检（六阶+六维+五层总分） | 第 13 项 |
| `--domain` | 领域知识违规检测 | **第 14 项** |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 引用） | — |
| `--diagram` | 可视化（mermaid 结构图 + echarts/antv 数据图；`--mermaid` 为别名） | — |

#### 合规门禁（17 个，独立 `--compliance-suite` 按需执行；未配置静默跳过或 WP-Z3 豁免留痕）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--compliance` | 标准合规矩阵核验（六锚点 + 零占位符 + spec §22 标准合规段） | 第 8 项 |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档 + TBD 扫描） | 第 8 项 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（启用后 fail-closed） | 第 4 项 |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 第 7 项 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | 第 7 项 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式 fail-closed） | 第 8 项 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 → fail，国密白名单 SM2/SM3/SM4） | 第 7 项 |
| `--rtm` | 需求追溯矩阵（spec REQ- 编号须在测试目录或追溯矩阵可追溯；RTM_MATRIX_REQUIRED=1 时矩阵缺失 fail-closed） | 第 8 项 |
| `--release-sign` | 发布签名与 provenance（产物须带 .sig/.asc/.att/.bundle 伴随签名；cosign verify-blob 验签 + SLSA provenance fail-closed） | 第 5 项 |
| `--dengbao` | 等保 2.0 控制点（DENGBAO_LEVEL 二/三级分级：双因子/审计日志/审计字段/个人信息保护缺口，启用后 fail-closed + 豁免留痕） | 第 7 项 |
| `--pia` | 隐私影响评估（PIA 文档缺失 → fail，启用后 fail-closed） | 第 7 项 |
| `--sast-deep` | 深度 SAST（semgrep→opengrep→内置降级链，启用后 fail-closed） | 第 7 项 |
| `--oss-eval` | 开源代码安全评价（复用 --sbom 产物，成分清单/许可证纳入评价，启用后 fail-closed） | 第 4 项 |
| `--quality-model` | 质量特性剪裁核验（GB/T 25000.10 八特性：功能性/性能效率/兼容性/易用性/可靠性/安全性/维护性/可移植性，启用后 fail-closed） | 第 8 项 |
| `--test-evidence` | 测试证据留存（TEST_EVIDENCE_REQUIRED=1：每测试用例须有执行证据记录，启用后 fail-closed） | 第 5 项 |
| `--review-record` | 评审记录留存（REVIEW_RECORD_REQUIRED=1：spec/code 合入须留评审记录，启用后 fail-closed） | 第 8 项 |
| `--metrics` | 度量趋势（cognition-metrics.jsonl：认知层得分/门禁执行计数趋势，warn 为主，enforce=warn） | 第 13 项 |

#### 门禁工具优先级 + 降级策略

每个门禁优先用已安装的运行时工具，无则降级：

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | graphify path → gitnexus trace（仅非商用场景）→ madge | 转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--layer` | gitnexus query | grep import |
| `--review` | ocr review / `claude ultrareview` | AI 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |
| `--frontend` 循环 | madge --circular | grep 互引 |

---

### 5. 生成流程

对 AI 说："为 /path/to/my-project 生成 skill"

或用 slash 命令：`/swarm-yuan /path/to/my-project`

| 步骤 | 做什么 |
|------|--------|
| ⓪ | 自检（13 运行时接线口径 = 11 工具机械探测 + 2 方法论引用） |
| ⓪.5 | 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / agent 运行时） |
| ① | 三路并行探查代码库（结构 / 规范 / 代码组织） |
| ①.5 | **项目形态判定 + 详尽构件库清单 + 调用链路分析**（§C+.0-C+.5，按形态选维度，全量穷举 + 计数核验） |
| ② | **提取 17 项特征卡**（每项落到真实路径，不用占位符） |
| ③ | 创建骨架（含 hooks / commands / precheck.conf） |
| ④ | AI 填充全部文件——**特征卡驱动，消除全部占位符** |
| ④.5 | **框架深化**——逐激活框架按 `references/frameworks/<fw>.md` §1-§6 枚举 + 规律实例化 + 门禁清单对齐 |
| ⑤ | AI 配置 precheck.conf——**184 个变量从特征卡推导** |
| ⑤.5 | AI 生成 hooks / commands / settings.local.json / .mcp.json 集成（generate-skill.sh create 段自动产出骨架，AI 按项目已装运行时激活 MCP server） |
| ⑥ | AI 运行门禁（--all 核心 10 → --all-full 标准 28；合规 19 按需 --compliance-suite）——**特征卡定义规则，门禁验证合规** |
| ⑦ | AI 独立审查——`--review`（ocr 5 维度或 AI 清单）+ review-record 落盘 |
| ⑦.5 | **门禁注入**——`generate-skill.sh --inject-frameworks` 把激活框架门禁片段写入 precheck.sh 标记区块 |
| ⑧ | AI 写回项目记忆（闭环） |
| ⑨ | AI 最终检查——运行 `generate-skill.sh --verify-completeness` 脚本确认**零占位符残留 + workflow 每节点含「调用追踪」要素**（命中即列 file:line 并 exit 1，零命中才通过） |

> **全链路追踪（每步必做，无需确认）**：每步开始先公告 `→ [Step N] 调用 <技能/工具> · <目的>`，节点级落盘 `.swarm-yuan/trace.jsonl`（`SWARM_YUAN_TRACE=verbose` 时含每次具体调用）。

---

#### 三档骨架（--profile）

按项目规模与合规要求选择生成档位（**默认 `auto` 项目级自适应**：合规关键词 → compliance；文件数 <80 → lite；其余 standard；WP-Q2 偏置修正——信号明确才升档，模糊走默认 standard，判定依据会打印供你评估，显式 `--profile` 可覆盖。upgrade 自动继承既有档）：

| 档 | 适用 | 骨架内容 |
|----|------|---------|
| `auto`（默认） | 让生成器按项目信号判定 | 按下方三档之一产出，附判定依据 |
| `lite` | 小项目 / 试水 / 增量采用 | 特征卡 + reference-manual + 核心门禁脚本（precheck/state-machine/trace-log/self-check/cost-report）+ spec/plan 模板；无 hooks/commands/settings/.mcp.json |
| `standard` | 一般项目 | 全量骨架（hooks + commands + 方法论 references 全集） |
| `compliance` | 金融/医疗等强监管交付 | standard + 标准合规矩阵参考（`references/standards-compliance.md`，配套 `--compliance-suite` 合规 19 门禁） |

零占位符铁律按档适用：只要求当前档包含的文件零占位符。**自适应的偏置方向是质量优先：宁可偏重，不可偏轻**——auto 判定不确定时升档；后续开发中任务规模判断同样升档（见 §6 任务级门禁映射）。

### 6. 日常使用

#### 开始新需求

对 AI 说："开始新需求：给 cockpit 添加通知面板"

AI 自动：创建 spec → 判断规模 → **从特征卡第 11 项检索可复用单元，预填 §5.5 复用约束** → 验证。

**全程可见（全链路追踪，无需确认）**：AI 每进入一节点先公告 `→ [节点X] 调用 <技能/工具> · <目的>`，节点级落盘 `.swarm-yuan/trace.jsonl`（`scripts/trace-log.sh`；`SWARM_YUAN_TRACE=verbose` 时含每次具体调用）。你随时知道正在调用何种工具及技能。

| 规模 | 填哪些段 | 提交前门禁（任务级自适应，WP-N2） | 典型场景 |
|------|---------|---------|---------|
| 简单 | §1-§4 + §5.5 复用约束 + §12 风险回滚 | `--all`（核心 10） | 改 bug / 加字段 |
| 标准 | §1-§13 + §5.5/§5.6/§5.7 约束段 | `--all-full`（标准 28） | 新功能 / 改接口 |
| 完整 | spec 全 24 节（含 §14-§18 认知/辩证/领域，仅 compliance 档保留 §14-§18） | `--all-full` + `--shift-left`；compliance 档项目追加 `--compliance-suite` | 架构变更 / 跨服务 |

> **任务级自适应规则（质量优先偏置）**：规模判断不确定时**按更大规模处理**（升档不降级）；涉及公共接口/数据模型/权限的改动，无论规模一律按「完整」执行门禁集；compliance 档项目任意规模都追加 `--compliance-suite`（强监管场景无"简单任务"豁免）。

#### 提交前门禁检查

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 标准 28 门禁（核心 10 + 架构 18）
bash .claude/skills/my-project-dev/scripts/precheck.sh --compliance-suite  # 合规 19 门禁（强监管交付按需）
```

**结果**：`✓` 通过 / `✗` 必须修复 / `⚠` 人工评估

#### 门禁输出与证据（--doctor / --format json / GATE_RUNS_DIR）

```bash
bash scripts/precheck.sh --doctor              # conf 诊断 lint：路径/glob 可达/死变量/框架 requires_conf（非门禁，可带病启动）
bash scripts/precheck.sh --all --format json   # 门禁结果以 SARIF 2.1.0 子集 json 追加输出（GATE_JSON_OUT=<path> 可落盘）
GATE_RUNS_DIR=.gate-runs bash scripts/precheck.sh --all-full
# 证据落盘：gate-runs.jsonl（ts/门禁名/状态/fail id 数组/耗时）逐行写入 .gate-runs/
```

默认 text 模式输出与旧版逐字节一致；`--format json` 或 `GATE_RUNS_DIR` 仅在显式开启时生效。

#### 趋势可视化与运行报告（gate-trends / gate-report）

以 `GATE_RUNS_DIR` 落盘的 `gate-runs.jsonl` 为数据源（行格式 `{"ts","gate","status","ids","duration_s"}`）：

```bash
bash scripts/gate-trends.sh [gate-runs.jsonl] [N=10]        # 各门禁近 N 次通过率趋势表（终端文本）
bash scripts/gate-trends.sh --html report.html              # 自包含 HTML 报告（内联 SVG：通过率折线/状态色块/fail id TOP10，零外链）
bash scripts/gate-report.sh [gate-runs.jsonl] [输出.md]     # GB/T 15532 对齐的门禁运行报告（标识/概述/环境/执行结果/结论）
```

无 jsonl（或空/无有效行）时提示并 exit 0——与门禁族「未配置静默跳过」姿态一致。

#### 成本遥测（cost-report）

以 `.swarm-yuan/trace.jsonl`（trace-log.sh 落盘）为数据源，聚合每次生成/使用的调用成本——评估"流程重不重"的量化依据：

```bash
bash scripts/cost-report.sh                  # 写 .swarm-yuan/cost-report.md 并打印摘要
bash scripts/cost-report.sh --stdout         # 只打印不落盘
SWARM_YUAN_TRACE=verbose <生成/使用流程>      # 先收集调用级细节，再跑 cost-report 数据更全
```

输出：时间跨度 / 总调用数（含 fail 数）/ 按节点、执行者、工具的 Top10 聚合。无 trace.jsonl 时提示并 exit 0（fail-open）。

#### 多平台规则渲染（--render-tools）

从目标技能的 SKILL.md + precheck.conf 派生各 AI 工具原生规则文件（幂等，重渲染为 no-op）：

```bash
bash scripts/generate-skill.sh --render-tools <skill-dir> [project-root] [tool]
# Cursor .cursor/rules/<skill>.mdc；Windsurf .windsurf/rules/<skill>.md；
# Gemini/Codex/OpenCode/Kimi 的 GEMINI.md/AGENTS.md 标记区块段；Claude Code 已深度集成不渲染。
# tool 缺省渲染全部 7 工具；适配器见 assets/tool-adapters/<tool>.sh。install.sh 安装后自动调用。
```

#### 行业 profile（金融 / 医疗 / 政务）

行业立法文档 + 配套 conf 覆盖包，把行业法规条款转成门禁配置：

| 行业 | 立法文档 | 配置包 |
|------|---------|--------|
| 金融 | `references/industry-profile-finance.md`（网安法/数安法/个保法 + 人民银行/金监总局/证监会办法 + JR/T 系列 ↔ 门禁映射） | `assets/industry-profiles/finance.conf` |
| 医疗 | `references/industry-profile-medical.md`（个保法/数安法 + 卫健委办法/互联网诊疗细则 + GB/T 39725 ↔ 门禁映射） | `assets/industry-profiles/medical.conf` |
| 政务 | `references/industry-profile-gov.md`（网安法 21 条/密评/个保法 55-56 + GB/T 22239/39786/43848 ↔ 门禁映射） | `assets/industry-profiles/gov.conf` |

用法：`cat assets/industry-profiles/finance.conf >> <目标技能>/scripts/precheck.conf`，再按项目裁剪（逐行注释含条款依据）；追加后 `bash scripts/precheck.sh --doctor` 诊断应为 0 fail。医疗器械注册申报（SaMD/SiMD）场景不适用，见 standards-compliance.md §E.5 功能安全域占位。

---

### 7. 升级

对 AI 说："升级 my-project-dev skill"

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板 / 保留项目特定文件 / 自动备份 / AI 重新探查填充 precheck.conf。

---

### 8. FAQ

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"。AI 分析原因 → 调整 precheck.conf（特征卡配置）→ 重跑。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。核心约束：先声明复用了特征卡第 11 项的哪些单元，再写代码。

**Q: 不需要微服务/前端/TOGAF？** → 特征卡第 10/11 项留空 = 对应门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。AI 重新探查 → **更新特征卡** → 更新 precheck.conf。

---

### 9. 流程

```
首次：
  bash install.sh --claude
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 探查 → 提取 17 项特征卡 → 填充文件 → 配置门禁 → 验证 → 零占位符

日常：
  对 AI 说 "开始新需求：xxx"
    → AI 从特征卡第 11 项检索可复用单元 → 预填 §5.5
    → 编码（拼装优先，查特征卡第 11 项组件库清单）
      → 对 AI 说 "跑门禁"
        ├→ 全 ✓ → 提交
        ├→ 有 ✗ → 修复重跑
        └→ 有 ⚠ → 评估

架构审查：
  对 AI 说 "跑全量门禁"（55 个门禁全跑）

升级：
  对 AI 说 "升级 skill"（AI 重新探查 → 更新特征卡 → 更新门禁配置）
```

### 10. 数字一览

| 维度 | 数值 |
|------|------|
| **特征卡** | **17 项（驱动全部文件 + 184 个门禁变量 + 开发流程）** |
| **质量门禁** | **55 个（核心 10 + 架构 18 + 合规 19 + FULL-only 2 + advisory-only 6，特征卡立法 + 门禁执法）** |
| 运行时工具 | 13 |
| spec 模板 | 24 整数节（§1-§24，不含 §5.5/5.6/5.7 三个子节） |
| 领域知识 | 32 个领域 |
| 认知框架 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |

### 框架规则引擎

swarm-yuan 内置 79 个框架规则集（references/frameworks/*.md + assets/framework-gates/*.sh），覆盖 Java/Node/Python/Go/前端全栈。

#### 生成时激活

1. **框架探查**（§C+.0.5）：从 pom.xml/package.json/go.mod/pyproject.toml 提取依赖，识别 ACTIVE_FRAMEWORKS
2. **门禁注入**（--inject-frameworks）：按 ACTIVE_FRAMEWORKS 把对应门禁片段注入目标技能的 precheck.sh 标记区块
3. **四要素核验**（verify-framework-ruleset.sh）：每框架须通过 枚举+领域知识+门禁+约束 四要素
4. **fixture 双态**（run-framework-fixture.sh）：每框架含 violating→FAIL / compliant→PASS 测试

#### 扩展新框架

1. 复制 `references/frameworks/_template.md` 为 `<fw>.md`（六段式：§1 探查信号 + §2 构件枚举 + §3 领域规律≥10 + §4 门禁清单 + §5 跨框架交互 + §6 版本陷阱）
2. 创建 `assets/framework-gates/<fw>.sh`（`_fw_<id>_check()` 函数 + 头注释 `# ruleset:` + `# gates:`）
3. 创建 `tests/fixtures/<fw>/{violating,compliant}/`
4. 跑 `bash scripts/verify-framework-ruleset.sh <fw>` 核验
5. 跑 `bash scripts/gen-framework-index.sh` 更新索引（产物：assets/framework-signals.md + exploration-guide.md §C+.0.5 指针）

#### 门禁运行

```bash
bash scripts/precheck.sh --framework    # 运行所有激活框架门禁
bash scripts/precheck.sh --all-full     # 标准 28 门禁（核心 10 + 架构 18，含 --framework）
bash scripts/precheck.sh --compliance-suite  # 合规 19 门禁（强监管交付按需）
```

#### 时效检查

`bash scripts/self-check.sh` 末尾自动检查规则库时效（>180 天 warn，>365 天 warn 强烈建议重新核实）。


## 6.6 历史档案（A1-A13）

| 编号 | 档案 | 说明 |
|------|------|------|
| A1 | 范式定位 | 适用/不适用边界的原始论述。 |
| A2 | 设计逻辑简版 | 早期一页纸设计逻辑（已并入 DESIGN §0）。 |
| A3 | 本体论刻画 | BFO 范畴论/部分学正式刻画（已并入 DESIGN §0）。 |
| A4 | 理念一致性对照 | 设计理念与实现一致性对照表（归档版）。 |
| A5 | 决策史归档前卷 | 决策 1-20 原文（现行版含修订索引）。 |
| A6 | 框架规则引擎设计 | 框架规则引擎选型设计（方案 A；设计时点为 7 框架种子，现 79 框架）。 |
| A7 | 审计优化决策 | 审计轮优化决策记录。 |
| A8 | 上游引入决策 | 上游运行时引入边界决策。 |
| A9 | Q2 重量级审查 | 2026-08-19 分层实现评审报告。 |
| A10 | 运行时升级 2026-07 | 2026-07 运行时升级差异报告。 |
| A11 | 运行时升级 2026-08 | 2026-08 运行时升级差异报告。 |
| A12 | 五维稳定单元 | 稳定单元五维字段定义。 |
| A13 | 宣传文案 | 对外宣传口径（历史版本）。 |

### A1. 范式定位

> 适用/不适用边界的原始论述。（历史原文，不再单独维护）

> **归档标注**：本档案（范式定位 v2/v3 原稿）已并入本文档 §6.1 §1（定位与适用域，原 docs/DESIGN.md §1）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。



> 版本：v2（2026-08-21，R13 去抽象化重构后修订；v1 见 git 历史 WP-P10）
> 目的：显式声明 swarm-yuan 的适用/不适用场景与当前架构形态。
> 依据：R13 终态方案 `docs/research/R13-final-plan.md`（v6）——范式作为条件而非内容，厚生成器 + 薄生成物。

### 范式定位一句话

**swarm-yuan 是"生成器厚、生成物薄"的两体系统——生成时刻允许厚（探查知识全量），生成物必须薄到近乎无形（每会话固定税 ≤8KB、概念体系 ≤5）。重量在生成器侧是投资，在生成物侧是税——税制有机器预算。**

### 与 v1 定位的关键差异

v1（WP-P10）说"swarm-yuan 是重量级范式，重量是设计选择"——那是 2026-07 的真实，也是五轮"过重"诊断反复追问的对象。R13（2026-08-21）重构后，定位修正为：

| 维度 | v1（2026-07） | v2（2026-08，R13 后） |
|------|---------------|----------------------|
| 架构 | 单体重型 | 两体：厚生成器 + 薄生成物 |
| 范式形态 | 内容（要 AI 读记并自觉执行） | **条件**（运行时约束行为，零认知占用） |
| 重量表述 | 20k 文档 + 22k 脚本 = 设计选择 | 生成物每会话固定税 ≤8KB（机器断言）；生成器侧知识全量保留（一次性消费，不算税） |
| 概念体系 | 40+ 套编号概念 | 5 个层次名词（探查/约束/演化/留痕/生成）+ 认知框架落地为 AI 判断引导 |
| 门禁 | 54 门禁（10 个默认不可触达） | 54 门禁全部有真实触发路径（54/54 可达，不下调） |
| 自适应 | 三档 profile（lite 砍文件） | 项目档 × 任务档双维（砍文件不再发生——lite 无 hooks 生命周期，任务档只影响 spec 展开与门禁子集） |

### 适用场景

| 场景 | 为什么适用 | 推荐档 |
|------|-----------|--------|
| **团队协作项目（≥2 人）** | 项目地图让多人共享认知；门禁守护分支质量；运行时条件不依赖人自觉 | standard |
| **中大型项目（≥80 文件）** | 探查全量穷举 + 计数核验（≥0.95）保证组件清单可信；path-check 杀幻觉组件 | standard |
| **强监管/合规交付** | 合规门禁族 fail-closed + 行业 profile 真实注入（`conf-render.sh --industry`） | compliance |
| **长期维护项目** | 自成长链（fingerprint 感知 + scope 局部重探查 + last-good 红线）让技能跟项目演进 | 任意档 |
| **小项目但想要门禁** | lite 档 = 地图 + 约束 + 演化（无 hooks 生命周期，零常驻税之外的负担） | lite |

### 不适用场景

| 场景 | 为什么不适用 | 替代方案 |
|------|-------------|---------|
| 个人脚本/一次性原型 | 探查+门禁的开销远超脚本本身复杂度 | 直接 AI 裸写 |
| 极小改动（typo/调样式） | 不需走 spec 流程 | 直接改 |
| 无 AI 辅助的纯人工开发 | 范式设计为 AI 驱动（条件由 hook/门禁在 AI 会话中生效） | 传统 lint/test 工具链 |

### 范式外轻量方案

1. **单文件 precheck.sh**：直接拷 `swarm-yuan/assets/precheck.sh` 到项目，配 `precheck.conf`，跑 `--all` 核心门禁——不套生成器、不建 skill 目录。
2. **传统工具链**：ESLint/Prettier/golangci-lint/pylint + Git hooks。
3. **AI 原生开发**：直接对 AI 说"帮我改这个 bug"——不套任何范式。

### 当前架构的诚实评估

R13 后的真实状态（v2.1）：

- **生成物税有预算且被断言**：SKILL.md 骨架 8.7KB（≤8KB 预算）；认知面 references 拷贝 252KB（≤256KB 预算）；每会话固定税（SKILL.md+hooks+settings+conf）≤8KB——全部进 self-check 断言，超标即 fail。
- **重量没有消失，只是归位**：生成器侧 68K 行自举仍在（探查知识/框架规则/行业 profile——一次性消费，不算每会话的税）；生成物侧 ~25 文件，AI 读项目代码前的概念负担从 150+ 记忆槽降到 5 个层次名词。
- **治理由条件承载**：门禁输出三值（allow/prompt/forbid 取最严）、规则在 rules.d 数据文件（非 conf 硬编码）、FORBID 消息带替代方案（给模型的 API）、hooks 双宿主真实拦截（Claude Code deny JSON + Codex exit 2）。
- **吸收有纪律**：新概念进 SKILL.md 必须给出落地路径（接线/AI 判断引导/路由——不接受"先放着"）；吸收一律过三问（能否落到运行时条件/替换还是叠加/六个月后谁引用）。

**结论**：如果你的项目值得 AI 先懂再写（团队协作/中大型/长期维护/强监管），swarm-yuan 的生成器厚是合理投资——而生成物薄保证 AI 不被范式本身的重量拖住。

### 决策记录

v1 定位：决策 25（2026-07-21）。v2 修订：R13 终态方案 + 决策 33/34（见本文 §6.3 决策史）。


### A2. 设计逻辑简版

> 早期一页纸设计逻辑（已并入 DESIGN §0）。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §0.5-0.7（闭环流+流速流量+四测量维度，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。


> 本体论驱动原理见本文 §6.1 §0.1-0.4+0.8（原 docs/DESIGN-ONTOLOGY.md；发动机——机制从关系派生、设计走四问、演进先改本体、行为被本体约束）。本文只讲**流动**：过程如何展开、账本如何回流。

### 闭环流（系统的过程形态）

```
代码仓库 →① 生成段（探查+装配）→② 产物段（目标技能，出口受税制预算门约束）
  →③ 使用段（AI 按需 grep 地图做拼装式开发，行为被条件实时拦截）
  →④ 账本段（全量留痕）→⑤ 回流段（审计+评测校验体系自身，改进写回①②）
```

**自成长是闭环流的闭合条件**——砍掉回流边，系统退化为一次性脚手架生成器。

### 流上的流速与流量

- **厚薄**：①段知识一次性消费（厚是投资），③段产物每会话重复消费（厚是税）——"两体系统"就是这个消费频次差的旧名
- **流量阀**：profile 四档参数化①段装配多少
- **出口预算门**：②→③ 边界上，固定税 ≤8KB / 认知面 ≤256KB / 概念 ≤5（机器断言）
- **校验相位**：③段事中门禁、④段事后审计、⑤段对校验器自身的元评测——"三层 Harness"就是校验点在流上的三个相位
- **对外端口**：①段输入端口（三层接线取外部证据）、③段执行端口（hooks 挂宿主）

### 四个测量维度（本体结构沿流的投影定律）

闭环流被发动机驱动（§6.1 §0.1-0.4"四冲程"，原 DESIGN-ONTOLOGY.md）做功，做功效果在四个维度上可测——**四维不是选出来的视角，是本体 2×2 结构的必然展开**（实体二分 × 关系二分，推导见 §6.1 §0"发动机与仪表盘"节）：

| 维度 | 从本体哪格展开 | 测什么 | 在此维度上的历史语言 |
|------|---------------|--------|---------------------|
| **时间轴** | 发生体（occurrent） | 流段/相位/消费频次 | 两体系统（厚薄=频次差）、四档 profile（流量阀）、三层 Harness 的相位分布 |
| **产物轴** | 持续体（continuant） | 载荷/出口预算/税 | 税制（≤8KB/≤256KB/概念≤5）、五层一棵树（载荷拓扑） |
| **校验轴** | 表征关系（aboutness） | 表征可信：指向/覆盖/时效 | 三层 Harness（门禁=事中/审计=事后/评测=元）、path-check/计数核验/stability-audit |
| **边界轴** | 依赖关系（dependence） | 依赖连通：输入口/执行口/锚 | 三层接线（①段输入口）、宿主下沉（③段执行口）、digest 链（锚） |

**历史层次语言的归位由此成立**：每套语言都是对某个维度的观测记录（两体系统=时间轴频次观测、税制=产物轴出口观测、三层 Harness=校验轴相位观测、三层接线=边界轴端口观测）——它们不冲突，因为本体的 2×2 结构只有四格，每套语言各守一格。九条内核与贯穿原则跨格（不变量与守恒律，见本体文档）。


### A3. 本体论刻画

> BFO 范畴论/部分学正式刻画（已并入 DESIGN §0）。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §0.1-0.4+0.8（本体论驱动原理+燃料+工具箱，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。


> 本体论在这个系统里是**发动机**，不是标本柜。它不回答"这个东西该归哪个类"，它回答：**这个系统为什么长这样、下一步怎么长、凭什么信它**。
> 之前两稿的毛病：我把本体论讲成了范畴分类学（四大切面/四个坐标系/投影映射）——那是在给系统拍照，不是在给系统点火。本稿重写为驱动原理：本体论如何生成机制、如何驱动每一次设计与演进、如何约束 AI 的行为。

---

### 一句话

swarm-yuan 是被本体论驱动的生成系统：**先说清世界里有什么，一切机制从"存在"推导出来，一切演进从本体开始改，AI 的一切行为被本体约束**。本体不是对系统的描述，是系统的上游——机制是它的实现投影，演进是它的丰富过程，行为空间是它划出的边界。

### 引擎的四个冲程

#### 冲程一：本体生成机制（为什么有这些机制）

每个机制都不是发明出来的，是本体里某条**关系的实现**：

| 本体里的关系（先有） | 派生的机制（后有） |
|---------------------|-------------------|
| 地图**表征**仓库 | path-check（验证表征指向真实存在）、计数核验 ≥0.95（验证表征覆盖够全）、stability-audit（验证表征没过时） |
| 规则**治理**命令 | 三值求值器（治理的判定）、FORBID 带替代（治理的表达方式）、审批沉淀（治理的演化通道） |
| 账本**记录**过程 | trace-log（记录的工具）、gate-audit（记录的固化）、审计闭环（记录的复盘） |
| 技能**依赖**生成器版本 | .swarm-yuan-version 版本戳、--upgrade 升级机制 |
| 决策**锚定**trace | ref_trace_hash digest 链 |
| 好基线**不因坏状态**失效 | last-good 红线（骤降 >50% 拒写） |

**反推纪律（这条冲程的执法）**：每个机制必须能回答"我实现本体里的哪条关系"。答不出的机制是孤儿——要么删掉，要么先回本体补定义再实现。这一条直接继承 R13 的"概念落地问责"，但从"落地"深化到"从本体派生"。

#### 冲程二：本体驱动设计（新需求来了怎么想）

传统思路：新需求 → 想加什么功能 → 实现功能清单。
本体驱动思路：新需求 → 四问推导 → 功能只是推导链末端的投影：

1. **这引入什么新实体？**（进 objects.md——本体论节俭：想清楚它跟已有类型的区别）
2. **实体间产生什么新关系？**（进 links.md——这条关系的语义是什么）
3. **新关系的机器锚是什么？**（没有锚的关系 = 未来的漂移 bug——历史上全部漂移 bug 的统一根源）
4. **锚怎么检测失效？**（进 self-check 对账或 ontology-verify 健康检查）

四问答完，实现是水到渠成的；四问没答就写代码，就是 R13 之前五轮膨胀的老路。

#### 冲程三：本体驱动演进（系统怎么成长）

成长史 = 本体的丰富史 + 依赖的锚定史。这个视角把整个演化过程串成一条线：

- **R13 之前**：本体是隐式的（没人写下"存在什么"），机制凭感觉加——机制与本体漂移，声称的关系没有锚（12 vs 13、6355 vs 6393 这类漂移 bug 全是这么来的）
- **R13**：清理"机制↔本体"的错位——机械打分退役，因为它声称测"理解"，但本体里根本没有"理解"这个实体，只有行为记录
- **R14**：补关系——goal 闭环、证据态、双账本（"账本记录过程"这条关系的深化）
- **R15**：补锚——digest 链、gate-plan、audit-closure（给无锚关系配上断裂检测）
- **R16**：本体显式化——assets/ontology/ 三目录成为事实源，机制↔本体可机器对账
- **以后每次演进**：先改本体目录 → 派生实现 → 对账验证收尾。本体先行，实现跟随。

#### 冲程四：本体约束行为（AI 怎么被管住）

Palantir 的一句话在这个系统里的对应："你建不出绕过治理的看板，因为看板读的是受治理的对象" ↔ **AI 做不出绕过门禁的操作，因为操作过的是受治理的规则和账本**。

- AI 读到的不是一堆散文档，是类型名词（21 类型）+ 封闭动作空间（11 动作——每个都有治理载体和留痕载体）
- 想直接改文件？挂载在宿主上的 hooks 拦（mounted_in 关系生效）
- 想改账本抹痕迹？integrity-guard 的自指防护拦（Ledger 是受治理对象）
- 想跑危险命令？rules.d 三值判 forbid，FORBID 消息带替代方案——**在受约束空间里指路，而不是在自由空间里祈祷**

### 发动机与仪表盘（四冲程与四坐标系的本质关系）

发动机（四冲程）是动力；效果需要在维度上**可观测**——这就是四坐标系（时间/产物/校验/边界）的位置。它们不是四个"视角"（此前表述的错误），而是**本体结构沿闭环流展开的必然测量维度**——本体有什么结构，流上就有什么维度可测：

| 本体结构 | 沿流展开为 | 测什么 |
|----------|-----------|--------|
| **实体二分 · 发生体**（occurrent：生成/会话/决策/审计） | → **时间轴** | 流段、相位、消费频次（"两体系统"是这里的观测） |
| **实体二分 · 持续体**（continuant：仓库/技能/规则/账本） | → **产物轴** | 载荷、出口预算、税（"税制"是这里的观测） |
| **关系二分 · 表征关系**（represents/records/snapshot_of/closes——aboutness 一系） | → **校验轴** | 表征可信度：指向/覆盖/时效（"三层 Harness"是校验点在此轴的相位分布） |
| **关系二分 · 依赖关系**（generated_by/governs/mounted_in/anchors/propagates_to/plans——dependence 一系） | → **边界轴** | 依赖连通：输入口/执行口/锚（"三层接线/宿主下沉"是这里的端口） |

**为什么恰好是四个**：实体有两大范畴（BFO 的 continuant/occurrent 顶级二分），关系有两大类（哲学两大关系传统：aboutness 与 dependence——links.md 的 10 条关系恰可完备二分为 4+6）。2×2=4，不多不少——**四坐标系是本体结构的投影定律，不是设计者的分类趣味**。

每个冲程的效果都落进这四个维度可验：冲程一派生的机制落在校验轴/边界轴（锚在哪、验什么）；冲程二的产出落在产物轴+时间轴（新实体进载荷、新过程进流段）；冲程三的演进轨迹四轴皆留（本体改了哪格、哪条锚补了）；冲程四的行为约束在校验轴（拦截率）+时间轴（会话过程）上可测。**没有仪表盘，发动机是否在做功无从知晓；没有发动机，仪表盘测的是一台停着的机器。**

### 本体本身（引擎的燃料，简洁版）

- **实体**：21 类型（objects.md）——仓库/组件/技能/规则/账本/门禁/决策/目标...；刻意**不承诺**的：AI 的"理解"、认知分数（不可观测的东西不进本体，只承诺其行为记录）
- **关系**：10 条（links.md）——每条带机器锚（关系的实例可验证存在）
- **动作**：11 个（actions.md）——封闭空间，每个动作可审计

三份目录是事实源（与 facts.conf 的数字口径平行），self-check 对账 18 实存点，ontology-verify 六锚健康检查。

### 范畴工具箱（附录：刻画时用的学术工具，非主体）

需要精细刻画时才用的工具（来源见文末）：continuant/occurrent 二分（持续体 vs 发生体——恰好解释了"两体系统 vs 闭环流"不是矛盾是两个范畴）；部分学（部分 ≠ 构成材料——税制管的是构成不是部分）；Quine 承诺（承诺 = 量化遍历的实体）。这些是**镜头**，引擎是上面四个冲程。

### 调研来源

- BFO：[bfo-ontology.github.io](https://bfo-ontology.github.io/) / [Wikipedia](https://en.wikipedia.org/wiki/Basic_Formal_Ontology) / [IEEE 教程](http://ieeexplore.ieee.org/document/7288715/)
- 部分学与构成：[SEP: Mereology](https://plato.stanford.edu/entries/mereology/) / [Baker](https://people.umass.edu/lrb/files/bak02onmS.pdf) / [Evnine](https://kathrin-koslicki.squarespace.com/s/Simon-Evnine-Constitution-and-Composition.pdf)
- 本体论承诺：[SEP: Ontological Commitment](https://plato.stanford.edu/entries/ontological-commitment/)
- Palantir 本体论工程：[Ontology Overview](https://palantir.com/docs/foundry/ontology/overview/) / [Why create an Ontology?](https://palantir.com/docs/foundry/ontology/why-ontology/) / 本仓 R11 报告


### A4. 理念一致性对照

> 设计理念与实现一致性对照表（归档版）。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §2/§9（理念一致性，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。



> 日期：2026-07-21 ｜ 单一事实源：本文表与 `swarm-yuan/scripts/self-check.sh` 的 `check_doc_consistency` 机械解析互证。
> 目的：让"目标技能 在实际项目中可用、研发全流程 7 阶段真实可执行、13 运行时非花架子、三平台 CI 全覆盖"从宣称变成可核对的事实。

### 一、13 运行时接线分层（WP1）

> 注：本表为 WP1 时点快照（11 运行时：4 深 + 3 CLI + 4 方法论）。后续吸收 impeccable（方法论第 5）+ codex-security（CLI 第 4）后扩为 13（4 深 + 4 CLI + 5 方法论），权威数见 `swarm-yuan/assets/facts.conf`（FACT_RUNTIMES=13）。本表保留历史接线明细，计数以 facts.conf 为准。

| 层 | 运行时 | 真实接线方式（脚本里会执行的） | 降级载体 | self-check 可安装 | 验证 fixture |
|----|--------|------------------------------|---------|------------------|-------------|
| **深度接线（4）** | GitNexus | precheck.sh `gitnexus status`/`query`/`trace`/`detect_changes`（19 处子进程调用） | graphify → grep+madge | ✅ 源码+npm | check_layer/link-depth/impact gate-fixture |
| **深度接线（4）** | graphify | precheck.sh `graphify explain`（7 处） | grep+madge | ✅ uv/pipx | check_link-depth gate-fixture 降级路径 |
| **深度接线（4）** | claude-mem | precheck.sh `claude-mem search "project rules conventions"` | progress ledger + decisions.md | ✅ 源码(bun)+npx | check_knowledge gate-fixture |
| **深度接线（4）** | ocr | precheck.sh `ocr review --from --to --audience agent` + 降级 `ocr scan` | 5 维度手动清单 | ✅ npm i -g | review gate-fixture（mock bin/ocr） |
| **CLI 接线（3）** | OpenSpec | check_requirements `openspec validate --all --strict`（WP1.1 新增） | 自带文档检查（TBD/ID/EARS） | ✅ 源码+npm | requirements-openspec gate-fixture（mock bin/openspec） |
| **CLI 接线（3）** | comet | state-machine.sh `comet guard`（WP1.2 新增） | 自带 state-machine.sh 文件检查 | ✅ 源码+npm | state-machine guard 实测（mock bin/comet） |
| **CLI 接线（3）** | gsd-core | check_review `gsd-tools validate health`（WP1.3 新增，warn 级） | ocr + 手动清单 | ✅ 源码 build+npx | review-gsd gate-fixture（mock bin/gsd-tools） |
| **方法论引用（4）** | superpowers | 无 CLI；AI 按 subagent-orchestration.md 引用其 14 skills 模式 | 自带 subagent-orchestration.md 手动编排 | ❌ 需 `/plugin install` | 无（方法论层不接线 CLI） |
| **方法论引用（4）** | gstack | precheck.sh `if [[ -d ~/.claude/skills/gstack ]]; then echo 提示`（不执行 gstack 命令） | ocr + 手动清单 | ❌ 需 git clone + setup | 无 |
| **方法论引用（4）** | Ruflo | 无脚本调用；文档明说"不要求安装" | superpowers+claude-mem+gsd-core | ✅ npm i -g（但装上无脚本调用） | 无 |
| **方法论引用（4）** | ECC | 无 CLI；AI 按 review-methodology.md 引用其 hook profile 模式 | 自带 precheck + state-machine | ❌ 需 `/plugin install` | 无 |

**核对结论**：13 运行时按 4 深 + 4 CLI + 5 方法论分层（WP1 时点 11：4 深 + 3 CLI + 4 方法论；后吸收 impeccable + codex-security），每层有自带降级载体，未装不阻塞（fail-open）。深度+CLI 层在 precheck.sh/state-machine.sh 有真实命令调用 + fixture 验证；方法论层诚实标注为模式引用，不假装深度接线。

### 二、研发全流程 7 阶段 × 门禁映射

| 阶段 | spec 章节 | workflow 节点 | 门禁函数 | 双态 fixture | 真实可执行 |
|------|----------|--------------|---------|-------------|-----------|
| 需求 | §1 背景目标 / §4 Spec Delta | ①需求理解 → ②设计 spec | check_requirements（+openspec validate） | requirements / requirements-openspec | ✅ |
| 分析（左移） | §19 测试设计 / §20 变更影响 / §21 可观测性 | ②spec ★左移 / ③plan ★左移 | check_shift_left / check_impact | shift-left / impact | ✅ |
| 设计 | §3 改造类型 / §5 详细设计 / §5.5 复用 / §14-§18 | ②-③ design+tasks | check_layer / check_stable_diff / check_link_depth / check_reuse / check_deps / check_security / check_cognition / check_domain | layer/stable-diff/link-depth/reuse/deps/security/cognition/domain | ✅ |
| 开发 | plan Task 1..N / §20 变更影响 | ④分支 → ⑤编码（subagent-driven） | check_build / check_framework（79 框架动态分发） | build / 79 framework-fixture | ✅ |
| 测试 | §11 测试策略 / §19 用例骨架 | ⑥测试验证（ocr 5 维度） | check_test / check_review（+gsd-tools health） | test / review / review-gsd | ✅ |
| 部署/发布 | §20.3 灰度 / §21.5 告警+Runbook | ⑧构建发布（★运维左移） | check_build / check_release_sign / check_sbom / check_privacy | build / release-sign / sbom / privacy | ✅ |
| 运维/合规交付 | §21 可观测性 / §22 标准合规 | ⑦合入 + ⑧发布 + ⑨完成检查 | check_compliance / check_docs_pack / check_shift_left §21 | compliance / docs-pack / shift-left | ✅ |

**核对结论**：7 阶段无空壳，每阶段有 spec 章节 + workflow 节点 + 门禁函数 + 双态 fixture。

### 三、三平台 CI 矩阵（WP2）

| 平台 | CI Job | 覆盖 | 状态 |
|------|--------|------|------|
| Linux | ubuntu-latest（verify-framework-rulesets / fixture-double-state / generator-self-gate / self-check / shellcheck / e2e / verifier） | 79 ruleset + 79 fixture + 48 gate-fixture + e2e + verifier all + shellcheck 18 脚本 | ✅ 全覆盖 |
| macOS | macos-latest（macos-bsd-compat） | bash 3.2 语法 + 79 ruleset + 79 fixture + 48 gate-fixture（BSD grep/awk 兼容） | ✅ 全覆盖 |
| Windows | windows-latest（windows-compat，WP2.1 新增） | Git Bash bash -n + 79 fixture + 48 gate-fixture + .bat 烟雾测试 | ✅ WP2.1 新增 |

**核对结论**：三平台 CI 全覆盖，Windows 不再是虚假声称。.bat WSL 路径转换 bug 已修（WP2.2）。离线包 wheel 三平台覆盖（WP2.3）。

### 四、测试覆盖矩阵（WP3）

| 测试体系 | CI Job | 覆盖 | 状态 |
|---------|--------|------|------|
| 79 framework fixture（id 级双态） | fixture-double-state + macos + windows | 79 框架 × violating/compliant/expected-fail-ids | ✅ 三平台 |
| 48 gate-fixture（全量双态） | fixture-double-state + macos + windows + verifier | 48 门禁组（WP3.3 从 6 组扩到全量） | ✅ 全量 |
| e2e（四框架注入全链路） | e2e + verifier all | Java demo mybatis/lombok/spring-batch/sharding | ✅ WP3.1 进 CI |
| verifier all（C1-C8 验收） | verifier（WP3.2 新增） | fixtures + gate-fixtures + e2e + cli-ab + metrics-assert | ✅ WP3.2 进 CI |
| shellcheck | shellcheck（WP3.4 扩展） | 18 个核心+verifier+tests 脚本 | ✅ WP3.4 扩展 |

**核对结论**：测试覆盖缺口补齐，e2e/verifier/48 gate-fixture 全进 CI。

### 五、两条设计理念落实（WP4，2026-07-21）

| 理念 | 落实点 | 机器执法 | 状态 |
|------|--------|---------|------|
| **1. 连贯动作**（一键生成 + 一键使用，无需用户指定阶段/工具） | `/swarm-yuan <项目路径>` → Step 0-8（13 节点）全自动；目标技能用户只说"开始新需求 xxx" → 8 工作流节点自动驱动；hooks.json 自动接线（SessionStart 状态恢复 + PreToolUse 范围门禁）；工具选择走 has_* 守卫 + 降级链（gitnexus→graphify→madge→启发式） | `--verify-completeness` 零占位符；骨架铁律禁中途停止 | ✅ 已落实（设计性例外：特征卡/spec/合入/发布等 7 处用户决策点保留确认——确认≠指定阶段/工具） |
| **2. 全链路追踪**（每步调用有信息提示，显示调用了何种工具及技能，无需用户确认） | ① stdout 公告：每 Step/节点输出 `→ [Step N/节点X] 调用 <技能/工具> · <目的>`；② 落盘：`scripts/trace-log.sh` 追加 `.swarm-yuan/trace.jsonl`（ai-process-records §2.4 第四级调用留痕）；③ 门禁执行层：每门禁 `=== 检查 ===` 横幅 + pass/warn 归因工具 + gate-runs.jsonl + SARIF；④ hooks 单行摘要（原 `--quiet` 为无效参数已移除，改为一行 ✓/✗ 提示）；⑤ **第三方工具调用点全接线（WP-D1/D3）**：`trace_tool()` 桥（precheck.sh + state-machine.sh）——gitnexus query/trace/detect_changes、graphify explain、claude-mem search、ocr review/scan、openspec validate、gsd-tools validate health、comet guard 共 7 工具 10 个调用点逐一接入，输出走 **stderr**（cli-ab stdout 逐字节契约不破），守卫探测（has_*/indexed）不 trace 防噪音 | `--verify-completeness` 校验 workflow.md 每节点含「调用追踪」要素（template-spec §2 第 ⑨ 要素），缺则列 file:line + exit 1 | ✅ 已落实 |

**核对结论**：理念 1 此前已落实；理念 2 的缺口（AI 行为层无调用公告铁律、无机器校验、hooks 静默）由 WP4 补齐——workflow 10 要素（新增第 ⑨ 调用追踪）+ trace-log.sh 双通道 + verify-completeness 机器执法 + hooks 单行摘要。

---

### 五之二：R13 后的一致性修订（2026-08-21，v2.0/v2.1）

| 理念 | R13 后形态 | 状态 |
|------|-----------|------|
| **1. 连贯动作** | 不变（Step 0-8 全自动 + 8 工作流节点）；workflow 骨架从 10 要素精简为 **4 要素**（入口/参与方/门禁/产出物——其余 6 要素并入产出物说明，80 槽→32 槽） | ✅ 持续落实（verify-completeness 的「调用追踪」检查已同步为 ⑥ 产出物与追踪段含 trace-log.sh 调用） |
| **2. 全链路追踪** | 不变（stdout 公告 + trace-log.sh + gate-runs + SARIF + hooks 摘要）；failure-detector 的 L2-L4 叙事剧场退役（保留 L1 简短提示 + SPINNING brief——hooks 输出从叙事降为条件提示） | ✅ 持续落实（test-failure-detector 已同步新形态断言） |
| **3. 范式作为条件（R13 新增）** | 机制分条件/内容两类：条件（运行时约束，零认知占用）保留并强化（path-check/计数核验/last-good/状态门/三值规则/FORBID 带替代）；内容类转落地化（概念框架→AI 判断引导+notes 留痕）或接线（10 门禁全接线 54/54）/路由（40 references 何时读我） | ✅ R13 批次 0-4 + 增量全部收口（五维断言 G18/G19 守护） |
| **4. 落地优先于删除（R13 总原则）** | 概念/门禁/profile/references 一概不删——病根是"没有正确落地"（机械打分/僵尸孤立/无路由），全部转为真实消费路径 | ✅ 认知框架落地化、industry-profile conf-render 真实加载、装饰文档路由化、methodology 执法载体提取 |

**R13 后一致性自检入口**：`bash swarm-yuan/scripts/self-check.sh --check-only`（含 G18 孤儿资产扫描 + G19 层间反向引用 + 认知面税制断言 252KB<256KB + FACT_GATES_TOTAL=55 真值对账）。

### 六、自检命令

```bash
# 文档一致性（数字口径机械核对，含根 CLAUDE.md）
bash swarm-yuan/scripts/self-check.sh --check-only

# 全量验收（79 fixture id 级 + 48 gate-fixture + e2e + cli-ab + metrics-assert）
bash verifier/v1/run-verifier.sh all

# 理念 2 机器执法（workflow 调用追踪要素 + 零占位符）
bash swarm-yuan/scripts/generate-skill.sh --verify-completeness <skill_dir>

# trace-log 双通道实测（stdout 公告 + trace.jsonl 落盘）
bash swarm-yuan/assets/trace-log.sh --node "Step 4" --actor graphify --tool "graphify explain"

# 三平台 CI（推到 GitHub 后自动跑 ubuntu + macos + windows）
git push
```


### A5. 决策史归档前卷

> 决策 1-20 原文（现行版含修订索引）。（历史原文，不再单独维护）

> **角色标注（2026-08-21）**：本文件是决策史**原文档**（每个决策的完整记录）；本文档 §6.1 §9.2（决策史索引）是索引与归纳——查"为什么决定"用 §6.1 索引，查"决策全文"用本归档卷。


> 归档日期：2026-07-31 ｜ 来源：§6.3 决策史主文件（原 docs/paradigm-decisions.md）决策 1-17（建议 1-7 + 8 条建议表 + 决策 9-17）
> 归档原因：决策 1-17 均已落地稳定，是纯历史记录（决策 12/13 除外，二者仍是当前行为的权威依据，主文件保留指针锚点）。
> 活跃决策见本文 §6.3（决策 18+）。

---

> 日期：2026-07-20 ｜ 分支：`chore/leftover-suggestions`
> 记录 7 项遗留建议的处置决策与理由，供后续版本维护参考，避免重复调研。
> **口径权威源**：`swarm-yuan/assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

### 处置总览

| # | 建议 | 决策 | commit |
|---|------|------|--------|
| 1 | `_resolve_path` 左结合 bug | ✅ 修 | `d31ca48` |
| 2 | GNU grep -E 下 `\|` 字面 | ❌ 不修（保留原始行为） | — |
| 3 | 测试覆盖扩展（26 门禁 fixture + CI） | 🟡 部分（CI 骨架做，26 fixture 留长期） | `74bb244` |
| 4 | offline-cache 迁移 Release | ✅ 做（不做 filter-repo 瘦身） | `1c412f2` + `2e7b...` |
| 5 | 片段内既存小瑕疵 | 🟡 部分（dubbo/seata/vue 修，sentinel 不修） | `f893f73` |
| 6 | 生成器增强（SKIP_BAT） | ✅ 做 | `2f37607` |
| 7 | 本决策文档 | ✅ 做 | 本 commit |

### 逐项决策理由

#### 建议 1：`_resolve_path` 左结合 bug —— ✅ 修

**问题**：`cd "$dir" && pwd -P || cd "$dir" && pwd` 在 bash 左结合下解析为 `((cd && pwd -P) || cd) && pwd`，正常路径执行两次 pwd 返回两行值，`-f "$cand"` 永远 false，`check_layer §3/§6`、`check_contract §2` 沉睡。

**修复**：方案 C 直接 `cd && pwd -P`（POSIX -P 三平台兼容），失败走原回退。

**苏醒后发现的第二个 bug**：修复 _resolve_path 后 `check_layer §3` 苏醒，立即暴露 §1 的 glob 解析 bug——`base=${g%%/\**}` 最长匹配把 `overlay/custom/client/*/components/**` 误截成 `overlay/custom/client`，find 扫整个 client 目录，把 `__tests__/adapters/composables` 全归入 component 层，§3 误报 249 个假违规。改 `base=${g%/\**}` 最短匹配 + compgen -d 展开 glob。修复后 ncwk-dev `--layer` 从 249 假违规降到 0。

**教训**：沉睡门禁修复后会暴露下游 bug，需用真实项目样本验证苏醒后行为。

#### 建议 2：GNU grep -E 下 `\|` 字面 —— ❌ 不修

**问题**：`ROLLBACK_KEYWORDS` 等 5 个变量用 `\|` 在 `grep -E` 下是字面 `|`，部分匹配永不命中。

**决策**：保留原始行为。修复会改变门禁判定（让沉睡匹配苏醒），与建议 1 同性质但影响面更大（5 个变量 × 多处 grep），且无样本可预测苏醒后行为。

**后续**：留独立版本决策，若要修需逐变量评估苏醒影响 + 补 fixture。

#### 建议 3：测试覆盖扩展 —— 🟡 部分做

**做了**：`.github/workflows/ci.yml` CI 骨架 4 个 Job（57 verify + 57 fixture + self-check + shellcheck）。触发：push/PR 到 main。

**未做**：26 个非框架门禁（`--scope/--sensitive/--layer` 等）的 fixture。工作量大（每个门禁要造 violating+compliant 双态），留长期扩展，按同范式补齐。

**理由**：CI 骨架能防回归是高 ROI；26 门禁 fixture 是长期工程。

#### 建议 4：offline-cache 迁移 Release —— ✅ 做（部分）

**做了**：
1. 打包 `swarm-yuan-offline-cache.zip`（44MB，含 graphify-wheels + npm + gstack + superpowers）
2. 上传到 GitHub Release `v2026.07.20-offline`（https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.07.20-offline）
3. `install-offline-win.sh（已废弃）` 开头加降级链：本地 cache 不存在 → curl 从 Release 下载 → 降级在线安装
4. `.gitignore` 忽略 `*.whl/*.tgz/gstack/superpowers/`；`git rm --cached` 停止跟踪 37 文件（本地保留）

**未做**：`git filter-repo` 历史瘦身（改写历史 + force push 风险高，留独立决策）。历史 blob 32MB 保留在 .git，但今后不再增长。

**与 memory 全局规则关系**：不冲突。"仅 arm64.dmg + x64.zip" 针对 SwarmStudio 桌面应用；swarm-yuan 是 skill 仓库，现有 8 个 Release 全为 .zip，本附件延续 .zip 惯例（与 `v2026.07.12-offline` 的 59MB zip 先例一致）。

#### 建议 5：片段内既存小瑕疵 —— 🟡 部分修

**修了**：
- dubbo.sh:25 / seata.sh:27 删 `|pom.xml`（被 `*.xml` 遮蔽，死分支，机械等价）
- vue.sh 10 处消息前缀 `vue:` → `fw_vue_<id>:`（与 vue.md §4 命名规范一致，退出码等价）

**未修**：sentinel.sh 内联 grep。A/B 类收益小（19 处单文件 if grep -qE 强改收益小），C 类 5 处 `-qiE` 不等价（`_fw_grep_count` 不支持 `-i`），D 类 4 处需要文件列表/行号/匹配内容（`_fw_grep_count` 只给计数无法替代）。整体非必要。

#### 建议 6：生成器增强 —— ✅ 做

**做了**：`generate-skill.sh` 的 `copy_universal_templates` 加 `SKIP_BAT` 环境变量，设 1 跳过 .bat 复制（macOS/Linux 用户无需 .bat，让 skill 目录更干净）。默认 0 保持兼容（仍复制 7 个 .bat）。

**未做**：snippets.md / mcp-tools.md 是静态参考文档（非模板），create 模式仍复制，upgrade 模式若用户已修改则保留（现状已如此，无需改）。

#### 建议 7：本决策文档 —— ✅ 做

记录上述 6 项决策，供后续版本维护参考。

### 不做的事（汇总）

- 建议 2（grep `\|` 字面）：保留原始行为，留独立版本决策
- 建议 3 的 26 门禁 fixture：工作量大，留长期扩展
- 建议 4 的 `git filter-repo` 历史瘦身：force push 风险高，留独立决策
- 建议 5 的 sentinel 内联 grep：收益小/有风险

### 重构报告（2026-07-20）评估的 8 条建议处置

外部重构报告提出 8 条建议，评估后处置如下：

| # | 建议 | 决策 | 理由 |
|---|------|------|------|
| 1 | precheck.sh 拆分为模块化（precheck/lib/gates/） | ❌ 不做 | 范式核心约束：单文件可移植（目标技能 只需 cp 一个 precheck.sh）。拆分会破坏 install.sh 的"复制即用"设计 |
| 2 | 分层配置 schema + local | ❌ 不做 | 已用 `_default_conf()` + `${VAR+x}` 兜底解决 set -u 崩溃；schema 文件增加复杂度但收益有限 |
| 3 | Shell 可移植性（install.sh 加严格模式） | ✅ 部分做 | install.sh 已有 `set -euo pipefail`（报告不属实）；已加 `--version` + bash 版本校验 |
| 4 | 框架片段 META 头标准化 | 🟡 标注 | 需改 57 片段，工作量大。当前注释约定 + verify-framework-ruleset.sh 已兜底四要素核验 |
| 5 | bats-core 测试框架 | 🟡 标注 | 引入 bats-core 是大工程。已做 CI 骨架（ci.yml 4 Job）+ self-check 文档一致性检查这种轻量项 |
| 6 | 文档一致性检查 | ✅ 做 | self-check.sh 加 `check_doc_consistency`（片段数/门禁数/conf 变量数/references 数）；已发现并修复 SKILL.md "45 变量"→"146 变量"漂移 |
| 7 | 降级策略可观测性 | 🟡 标注 | 改降级函数是大重构（涉及多个 check_* 门禁），先标注，后续版本评估 |
| 8 | 状态机持久化（断点续传） | ❌ 不做 | SKILL.md 明确"不允许中途停在骨架阶段"是设计哲学，断点续传违背零占位符铁律 |

### 风险与缓解

- **建议 1 苏醒 check_layer §3**：已用 ncwk-dev 实证（249 假违规 → 0），且修复了连带暴露的 glob 解析 bug
- **建议 4 Release 迁移**：不删历史 blob（只停止跟踪），install-offline-win.sh 加本地 cache 优先逻辑保证已有 cache 不受影响
- **建议 6 SKIP_BAT**：默认 0 保持兼容，只影响显式设 1 的用户
- **重构报告建议 1/2/8 不做**：保护范式核心设计（单文件可移植 / 已有兜底 / 零占位符铁律）

---

### 2026-07-21 设计理念落地一致性整改决策

> 触发：用户要求"整理项目设计理念，确保落地实现与设计一致，目标技能 要能在实际项目中使用，运行时要真实使用不能是花架子，三平台自测回归集成测试"。
> 三路并行探查（运行时接线 / 全流程覆盖 / 跨平台兼容）后，3 项决策。

#### 决策 9：11 运行时半接线→真接线（OpenSpec/comet/gsd-core）—— ✅ 做

**问题**：探查发现 11 运行时里 4 个深度接线（GitNexus/graphify/claude-mem/ocr，precheck.sh 真实命令调用）、3 个半接线（OpenSpec/comet/gsd-core，self-check 能装但 precheck/hooks 不调用，靠 AI 自主用 slash）、4 个纯文档引用（superpowers/gstack/ECC/Ruflo）。与"整合 11 运行时"宣称有落差。

**决策**：把 3 个半接线提升为 CLI 真接线——OpenSpec 接进 check_requirements（`openspec validate --all --strict`）、comet 接进 state-machine guard_phase（`comet guard`）、gsd-core 接进 check_review（`gsd-tools validate health`，warn 级）。全部带 `has_*` 守卫 + 降级到自带载体，未装不阻塞。4 个纯文档引用保持方法论引用层，诚实标注不假装深度接线。

**理由**：用户明确选"提升半接线为真接线"。3 个运行时都有真实 CLI（本机实测 comet/openspec/gsd-tools 子命令），接线后目标技能 在装了这些运行时的项目里能真实调用其能力，不再是花架子。降级设计保护未装场景。

**fixture**：requirements-openspec（mock bin/openspec）、review-gsd（mock bin/gsd-tools）、state-machine comet guard 实测（mock bin/comet）。36 gate-fixture 全量验证无回归。

#### 决策 10：Windows 平台真实化（CI + .bat + 离线包）—— ✅ 做

**问题**：Windows 是虚假声称——CI 无 windows-latest、.bat 包装器从未测试、离线包 wheel 全是 macosx arm64 却叫 `-win`、.bat 的 WSL 路径转换有 bug（WSL 用 `/mnt/c/` 但 .bat 用 `/c/`）。

**决策**：
1. CI 加 windows-latest Job（bash -n + 61 fixture + 36 gate-fixture + .bat 烟雾测试）
2. 修 8 个 .bat 的 WSL 路径转换（`echo !BASH_CMD! | findstr /i "wsl"` 判断，WSL 用 `/mnt/c/`，Git Bash 用 `/c/`）
3. build-offline-win.sh（已废弃） 加多平台 wheel 下载（`pip3 download --platform macosx_11_0_arm64/manylinux2014_x86_64/win_amd64 --only-binary=:all:`）
4. UPSTREAM.md 补离线包平台覆盖说明

**理由**：用户明确选"补 Windows CI + 修离线包"。这是最实的虚假声称，必须让"三平台"名副其实。.bat WSL 路径 bug 是 bash 3.2 全角字符 bug 同类（平台相关沉睡），CI 实跑才能现形。

**风险**：Windows CI 可能暴露既有 bash 兼容问题——缓解：windows Job 初期 bash -n + fixture 双态 + .bat 烟雾，发现问题逐个修；不追求一次全绿，先让问题现形。

#### 决策 11：测试覆盖补齐（e2e + verifier + 36 gate-fixture 进 CI）—— ✅ 做

**问题**：CI 不跑 e2e、不跑 verifier、36 gate-fixture 只跑 6 组、shellcheck 只查 6 个脚本。验收体系（C1-C8）形同虚设——CI 不执行验收器。

**决策**：
1. CI 加 e2e Job（四框架注入全链路）
2. CI 加 verifier all Job（C1-C8 全量：fixtures + gate-fixtures + e2e + cli-ab + metrics-assert，timeout 15min）
3. run-verifier.sh 的 gate_fixtures 从硬编码 6 组改为全量遍历 36 组；CI 的 fixture-double-state Job 同步改全量
4. shellcheck 覆盖从 6 个脚本扩展到 18 个（含 verifier/v1/* + tests/* + state-machine.sh + offline 脚本）

**理由**：用户明确选"全补"。验收体系不进 CI 等于没有验收——本次让 C1-C8 真正生效。36 gate-fixture 全量覆盖所有门禁组（含 WP1 新增的 openspec/gsd fixture）。

**教训**：验收体系（verifier/）和 CI 长期脱节是组织缺陷——verifier 是 P1 重构时建的验收器，但只手动跑过（runs/ 留 7 个日志），从未进 CI。本次补齐后，任何门禁语义变更都会被 verifier all 的 cli-ab 逐字节等价断言抓住。

#### 决策 12：check_cognition 诚实化（不实装 fail 阈值）—— ✅ 做（2026-07-21 减重 WP-B）

**问题**：check_cognition 被 2026-07-20 审计自认"装饰性叙事"（0 个 fail() 调用、裸 `echo "⚠"` 不计 WARN_COUNT 不受 SILENT 控制、COGNITION_MAP 是死变量），作为 36 门禁之一账面虚增执法强度。

**决策**：不实装 fail 阈值（维持"刻意不重设计"的既有决策），做三点诚实化：
1. 函数入口明示性质：「认知体检报告（warn-only，永不 fail，不参与门禁否决）」
2. 裸 `echo "    ⚠"` 统一为 `warn()`（计 WARN_COUNT、受 SILENT 控制；④映射/①概念/②结构/第二层共 5 处）
3. 死变量 COGNITION_MAP 接入：_default_conf 补声明，④映射段配置且文件存在时纳入检查输入（不改变 /3 计分口径）

**理由**：审计已判定其实质是"只读体检报告"。诚实化 = 账面与实质一致，而非强行赋予它不具备的执法语义。装 fail 阈值的风险（计分口径未经真实项目校准，误报即淹没）大于收益。

**联动**：同日 WP-A 合规 9 门禁拆出 --all-full 为 --compliance-suite（27+9），门禁总数 36 不变、函数不变，self-check 机械一致性断言不受影响。

#### 决策 13：断点续传否决令废止——draft 状态门替代一次性铁律（2026-07-21 减重 WP-H）

**问题**：决策档曾否决状态机断点续传（理由：违背零占位符铁律）。但该否决使生成流程成为 all-or-nothing——12 步管线必须一次走完，是范式"过重"的最大采用门槛；且长流程中断后只能整体重来。

**新论据**：原否决针对的是"断点续传 = 中途交付半成品"。状态门方案把"可中断"与"可交付"解耦：
1. 骨架 frontmatter `status: draft`（机器可识别），draft 期间 `--all-full`/`--compliance-suite` 被 precheck 禁用（exit 2）——半成品无法以"门禁全绿"伪装成交付物
2. `--mark-active` 以严格零占位符核验（--strict）为翻转前提——零占位符铁律从"流程纪律"升级为"状态迁移的机器准入"
3. 断点续传幂等（只补缺失文件，不覆盖已有内容），与 upgrade 路径语义清晰分离

**决策**：正式废止"断点续传违背零占位符铁律"的否决，以 draft/active 状态门替代。零占位符铁律的适用点从"流程结束"移到"draft→active 迁移"。

**联动**：WP-E 三档 profile（零占位符按档适用）+ WP-G 特征卡 P0/P1 分级（P1 可「（P1 待补）」，--mark-active 前清零）+ WP-A 合规门禁拆出（27+9）。

> **★活跃决策（2026-07-31 归档时标注）**：决策 13 仍是当前 draft/active 状态门行为的权威依据，主文件（现 §6.3）保留指针锚点。外部引用（state-machine.sh 等）指回本归档卷。

#### 决策 14：offline-cache 治理收口（2026-07-21 减重 WP-J）

**事实核查**：git 索引内 offline-cache 实际只剩 UPSTREAM.md（8KB）——whl/tgz/zip 自 v2026.07.20 起已迁 GitHub Release 附件（install-offline-win.sh 的降级链自动下载），196MB 均为本地 ignored 内容。根 .gitignore 旧注释"已故意纳入 git 跟踪"是迁移前的表述残留，与 swarm-yuan/.gitignore 矛盾。

**决策**：
1. 根 .gitignore 矛盾注释重写（指向 Release 迁移事实与 fetch 脚本）
2. 新增 scripts/fetch-offline-cache.sh（从 Release v2026.07.20-offline 拉取，已存在跳过，失败附手工指引）
3. 无索引手术可做（索引早已只有 UPSTREAM.md）——本项为表述与工具收口，非新决策方向

#### 决策 15：连贯动作理念落实——generate-skill 真生成 settings/.mcp + fail 诊断 + state-machine auto（2026-07-21）

**问题**：设计理念 1（连贯动作）3 处虚假——SKILL.md Step 9 宣称生成 settings.local.json/.mcp.json 但 generate-skill.sh 不生成；precheck fail 仅 exit 1 无诊断修复建议；state-machine guard 占位直接 pass、transition 需显式传阶段。

**决策**：
1. generate-skill.sh create + upgrade 段真生成 settings.local.json（最小权限模板）+ .mcp.json（MCP server 接入模板，默认空 mcpServers，AI 按已装运行时激活）
2. precheck.sh fail() 收集 FAIL_IDS + _fix_suggest 映射表（30+ 常见 fail id → 建议文案）+ --fix-suggest 子命令（只输出建议不 exit 1）
3. state-machine.sh guard_phase 实装产出物检查（design 查 proposal.md/SPEC_FILE、verify 查 tasks.md 全勾）+ auto 子命令（自动判下一阶段 + guard + transition，免去记阶段名）

**理由**：用户要求"连贯动作落实"。3 处虚假让"一键全流程"名不副实。修复后生成器真产出全套配置、fail 有修复建议、状态机自动流转。

**边界**：fail 修复建议只建议不自动执行（与"用户决策"原则一致）；auto 不跳过 guard（守卫仍检查产出物）；settings/.mcp 是模板带占位符由 AI 填充（配置模板允许占位符，--verify-completeness 不扫这两文件）。

#### 决策 16：全链路追踪理念落实——trace-log 孤儿转真接线（2026-07-21）

**问题**：设计理念 2（全链路追踪）3 处虚假——trace-log.sh 功能完整但 precheck/state-machine/generate-skill/self-check 四脚本无一处调用（孤儿）；9 个第三方工具调用点调用前无公告、空结果时静默；探查阶段无进度提示。

**决策**：
1. precheck.sh _gate_exec 门禁级接 trace-log（每门禁 started + done/fail/warn/pass 双状态，输出 stderr 不污染 stdout/cli-ab）
2. 新增 trace_tool() 辅助函数，9 个工具调用点（gitnexus query/trace/detect_changes、graphify explain、ocr review、claude-mem search、openspec validate、gsd-tools validate health、comet guard）调用前各加一行 trace_tool
3. check_layer 空结果加 pass（修静默：gitnexus 无跨层问题时不再完全静默）
4. state-machine.sh / generate-skill.sh 各接 trace_tool（comet guard / create / upgrade / inject / verify）
5. SKILL.md Step 1 探查进度 prompt 补强（三路子代理每路启动前调 trace-log）

**理由**：用户要求"全链路追踪落实"。trace-log 设计正确却自己是孤儿是最大虚假。修复后每步调用有 `→ [节点] 调用 actor · tool（status）` 公告 + trace.jsonl 落盘。

**边界**：trace 输出 stderr（stdout 纯净不破坏 cli-ab 逐字节等价）；trace-log 落盘失败仅 warn 不阻塞主流程；探查阶段进度靠 prompt 约束 AI（无脚本强制，因探查是 AI 行为非脚本）。

#### 决策 17：全局一致性收口——文档口径与实现对齐（2026-07-21）

**问题**：全局排查发现文档残留过时口径——acceptance-criteria.md 仍写 57 fixture/31 flag/六组（实际 61/36/全量 36 组）；USAGE.md "hermes-agent"（应为 agent 运行时）；README "11 步"（实际 13 节点 0~8）；README 目录树未列 settings.local.json/.mcp.json。

**决策**：
1. acceptance-criteria.md 全量更新：57→61、31→36、六组→全量 36 组、C3 补 Swarm-studio ABSENT、C4 补严格层/信息层分离、C8 补全量 36 组
2. USAGE.md 步骤表 5.5 补 settings.local.json/.mcp.json 生成；hermes-agent→agent 运行时
3. README（根 + swarm-yuan/）11 步→13 步；目录树后补"生成的目标技能含"清单（含 settings.local.json/.mcp.json）
4. 本决策 15/16/17 记录入 paradigm-decisions.md

**理由**：用户要求"全局排查并彻底完成"。文档口径与实现脱节会让外部观察者误以为"全是空壳"。本次把所有过时数字/术语/清单与当前实现对齐。



### A6. 框架规则引擎设计

> 79 框架规则引擎选型设计（方案 A）。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §4-§6（探查/约束/演化，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。



> 日期：2026-07-17 ｜ 分支：`feat/framework-rules-engine` ｜ 状态：待评审
> 解决问题：实测中 swarm-yuan 生成的目标技能 对特定开发框架（lombok、spring-batch、mybatis、sharding-jdbc 等）适应性不足——框架知识是否产出、产出多深、门禁有无实现，全凭生成时 AI 临场发挥，质量不可控。

### 1. 背景与根因诊断

swarm-yuan 在 commit `6114ad8` 已建立 v1 框架适配（§C+.0.5 框架探查 + 20 个框架规则集 + precheck.conf 框架变量段），但存在 5 个断层：

| # | 断层 | 证据 |
|---|------|------|
| 1 | **门禁断层**：precheck.conf 定义了 ACTIVE_FRAMEWORKS 等 8 个框架变量，但模板 `assets/precheck.sh` 完全未消费（0 处 framework 匹配） | 生成时门禁全靠 AI 即兴手写。ncwk-dev 碰巧手写了 28 项检查（`_fw_vue_check` 等），Java 项目生成时无章可循 |
| 2 | **产物断层**：`framework-knowledge.md` 不在六段式模板内（template-spec.md / generate-skill.sh / SKILL.md 均未提及） | ncwk-dev 的该文件是生成时即兴发明，是否产出、多深全凭运气 |
| 3 | **深度断层**：domain-knowledge.md 每框架仅 5-6 条"分析起点"规律 | 无最低深度标准（枚举/约束/门禁/领域知识四要素不齐）、无 §C+.1 式计数核验 |
| 4 | **覆盖断层**：仅 20 个框架规则集，偏 Java 后端 + 少量前端 UI 库 | 缺 NestJS/Express/Fastify/Django/Flask/FastAPI/Gin/Gorm/Angular/Next.js 等；Java 侧缺 Spring Cloud/Security/JPA/MapStruct/XXL-Job/Seata/Sentinel；数据侧缺 Kettle/Flink/Paimon |
| 5 | **验证闭环断层**：生成流程 Step 12 最终检查不含框架适配验证；`--domain` 门禁只 grep"因为/证据"关键字 | 框架维度错配/浅填充无法被自动发现 |

**根因一句话**：ncwk-dev 的高质量框架适配是"那次生成时 AI 认真即兴手写"的产物，范式本身没有把它制度化。

### 2. 设计目标与验收标准

#### 2.1 目标（用户已确认）

- **落点**：改 swarm-yuan 范式仓库（本分支），并用增强后的范式 `--upgrade` 回灌已生成的 ncwk-dev（作为升级路径的实测验证）
- **深度标准**：每个激活框架**四要素齐备 + 量化门槛**——①特定构件枚举（带计数核验）②开发约束（写入 dev-guide §10）③门禁实现（precheck.sh 真实代码，非占位）④领域规律（≥10 条带代码证据）。缺一项 = 生成未完成
- **覆盖**：全栈均衡 ~56 框架（见 §6）
- **调研方式**：联网调研官方文档 + 版本区间标注；规律标注适用版本；无法确认的标"待验证"而非臆造

#### 2.2 非目标

- 不改动 swarm-yuan 的 26 门禁总体结构与五层认知框架
- 不追求框架数量凑整；质量门槛（≥10 规律/框架）优先于数量
- 不在生成时联网（规则库全内置，离线可用）；联网调研只发生在范式自身维护时

### 3. 总体架构与数据流（方案 A）

新增两个库 + 改造七个既有文件：

```
swarm-yuan/
├── references/frameworks/          ★新增：框架规则库（~56 个 .md，每框架 1 文件）
│   ├── _template.md                   规则文件模板（六段式，见 §4.1）
│   ├── mybatis.md / spring-batch.md / lombok.md / sharding.md / ...
├── assets/framework-gates/         ★新增：门禁片段库（~56 个 .sh，每框架 1 片段）
│   ├── mybatis.sh                   含 _fw_mybatis_check() 真实实现
│   └── ...
├── assets/precheck.sh              改造：内置 check_framework() 调度器 +
│                                    _fw_resolve_globs/_fw_grep_count 公共函数
│                                    （从 ncwk-dev 反哺的已验证实现）
├── assets/precheck.conf            改造：框架变量段通用化（约定式命名，见 §5.4）
├── scripts/generate-skill.sh       改造：新增 --inject-frameworks 注入逻辑
├── references/exploration-guide.md 改造：§C+.0.5 信号表迁移为索引，指向规则库
├── references/domain-knowledge.md  改造：20 框架段瘦身→索引，指向 frameworks/
└── references/template-spec.md     改造：framework-knowledge.md 正式入六段式模板
    SKILL.md                        改造：六段式表格 reference 行补 framework-knowledge.md
```

生成时数据流：

```
§C+.0.5 框架探查 → ACTIVE_FRAMEWORKS=[mybatis, lombok, sharding, ...] + 各框架版本号
   ↓
逐框架读 references/frameworks/<fw>.md（Step 4.5 框架深化）
  ①信号确认 ②执行构件枚举命令(计数核验) ③规律种子→项目代码验证→实例化(附证据)
   ↓
generate-skill.sh --inject-frameworks（Step 7.5，生成/--upgrade 共用，幂等）
  → assets/framework-gates/<fw>.sh 片段注入目标 precheck.sh 标记区块
  → 生成 references/framework-knowledge.md 骨架（规律种子，AI 实例化后填充）
  → precheck.conf 填充框架变量
   ↓
Step 12 验收闭环（四要素量化核验，不过 → 回 Step 4.5）
```

**ncwk-dev 反哺**：ncwk-dev 手写的 7 个框架检查函数（vue/naiveui/pinia/koa/socketio/vite/vitest）是已实战验证的实现，先反向收割进 `assets/framework-gates/` 作为片段库种子（仅补契约头注释），再经注入机制回灌 ncwk-dev——回灌零回归，片段库起步即有 7 个高质量样本。

### 4. 格式契约

#### 4.1 规则文件 `references/frameworks/<fw>.md` —— 六段式结构

```markdown
---
ruleset_id: mybatis
适用版本: MyBatis 3.5.x / MyBatis-Plus 3.5+（差异单独标注）
最后调研: 2026-07-17（来源：官方文档 3.5.19 / MP 3.5.12）
---

# <Framework> 规则集

## §1 探查信号（→ §C+.0.5 激活依据，含置信度）
| 信号类型 | 模式 | 置信度 |
| 依赖 | mybatis-spring-boot-starter / mybatis-plus-boot-starter | 高 |
| 注解 | @Mapper / @MapperScan / @TableName | 高 |
| 文件 | **/*Mapper.xml | 中（需排除他用） |
| 配置 | mybatis.mapper-locations / configuration: 节点 | 高 |

## §2 特定构件枚举（命令 + 计数核验方式）
- Mapper 接口 / XML 映射（计数核验基准）/ TypeHandler / 拦截器 / 分页插件 ...

## §3 领域规律（≥10 条，每条五要素）
### 规律：<标题>
- **适用版本**: 如"全版本"或"MP 3.5.7+"
- **规律**: ……
- **违反后果**: ……（尽量挂 CWE/官方 issue 依据）
- **验证方法**: 具体 grep/read 命令（即"代码证据"的采集方式）
- **对应门禁**: fw_<ruleset_id>_<rule>（fail/warn 级）或"人工检查"

## §4 门禁清单（id / 级别 / 实现逻辑 / 依赖 conf 变量）
| 门禁 id | 级别 | 实现逻辑 | 依赖变量 |
（门禁 id 命名规范：fw_<ruleset_id>_<rule>）

## §5 跨框架交互规则
| 交互对 | 规则 | 理由 |
（如 mybatis × sharding：DML WHERE 须含分片键；lombok × jpa：@Data 排除懒加载关联字段）

## §6 版本陷阱速查
| 版本 | 变化 | 影响 |
```

三条硬约束：

1. §3 每条规律**必须挂门禁 id 或标注"人工检查"**——不允许"写了规律但没有执法"
2. §4 每个门禁 id 必须在 `assets/framework-gates/<fw>.sh` 中有**同名实现**（命名一一对应，可被脚本机械核验）
3. §3 规律数 **≥10**；部分框架规律更成熟，门槛更高（如 spring-boot/mybatis/vue/react ≥15）。具体门槛由各规则文件头部 `深度门槛` 字段显式声明，未声明时默认 ≥10，避免歧义

#### 4.2 门禁片段 `assets/framework-gates/<fw>.sh` —— 注入契约

```bash
# ruleset: mybatis  requires_conf: MYBATIS_MAPPER_DIRS SQL_INJECTION_WHITELIST
# gates: fw_mybatis_dollar(fail) fw_mybatis_binding(fail) fw_mybatis_foreach(warn)
_fw_mybatis_check() {
  echo "  [mybatis] MyBatis 框架规律"
  # 实现只准使用：precheck.sh 公共函数（pass/fail/warn/
  # _fw_resolve_globs/_fw_grep_count）+ bash 3.2 兼容语法（三平台铁律）
  # 每条检查与规则文件 §4 的门禁 id 一一对应
}
```

**函数命名约定**：`_fw_<ruleset_id>_check`，其中 ruleset_id 的连字符转下划线（如 `spring-boot` → `_fw_spring_boot_check`）；片段文件名保留连字符（`spring-boot.sh`）。

注入机制（`generate-skill.sh --inject-frameworks`，生成/--upgrade 共用）：

- 目标 `precheck.sh` 内设标记区块 `# >>> swarm-yuan:framework-gates >>> ... # <<< swarm-yuan:framework-gates <<<`（仅目标文件有区块标记，片段文件自身不带嵌套标记），注入 = 幂等替换区块内容
- `check_framework()` 采用**动态分发**：遍历 ACTIVE_FRAMEWORKS，函数名经 `tr '-' '_'` 转换后用 `declare -f` 探测——存在则调用，**缺失则 fail**（探查到但没实现 = 范式缺陷，必须暴露）。无需重生成 case 分支，天然幂等
- 片段头部 `requires_conf` 注释被解析，自动核对 precheck.conf 是否声明对应变量，缺失则注入占位 + warn

#### 4.3 反哺与回灌的零回归保障

ncwk-dev 现有 `_fw_vue_check` 等 7 个函数**原样收割**为片段库种子（仅补契约头注释）；回灌 ncwk-dev 时其手写实现被同名片段**等价替换**（内容相同，仅位置迁入标记区块）。回灌后 `--all-full` 26 门禁 + `--framework` 检查项逐项比对，**只允许增多不允许减少**。

### 5. 流程改造与验收闭环

#### 5.1 生成流程 Step 增量改造

| 环节 | 现状 | 改造 |
|------|------|------|
| Step 4 §C+.0.5 框架探查 | 信号表 20 框架硬编码在 exploration-guide | 信号表迁移至各 `frameworks/<fw>.md §1`，exploration-guide 只留**信号汇总索引**（由脚本机械生成）；探查时**额外记录各框架版本号**（pom.xml/package.json/go.mod），用于规律版本区间匹配 |
| **Step 4.5（新增）框架深化** | 无 | 逐激活框架：读规则文件 §2 执行构件枚举+计数核验 → §3 规律种子逐条用项目代码验证（成立→实例化附证据；不成立→剔除并记录原因；区间外→标"待验证"）→ 产出填入 framework-knowledge.md |
| Step 7 填充 | framework-knowledge.md 不在模板 | template-spec.md 正式定义该文件：`--inject-frameworks` 生成骨架（规律种子），AI 在 Step 4.5 实例化后填充；**残留未实例化种子 = 占位符，零容忍** |
| **Step 7.5（新增）门禁注入** | 无（靠 AI 手写） | `generate-skill.sh --inject-frameworks`：片段注入标记区块 + 重生成 case 调度 + 校验 precheck.conf 变量声明 |
| Step 12 最终检查 | 无框架适配核验 | 新增**四要素量化核验**（见 §5.2） |

#### 5.2 验收闭环——四要素量化核验

对 ACTIVE_FRAMEWORKS 中每个框架逐项核验，任一不过 = 生成未完成（回 Step 4.5）：

| # | 要素 | 核验规则 | 核验方式 |
|---|------|---------|---------|
| 1 | **枚举** | 框架特定构件枚举计数 ≥ 实际计数 × 0.95（沿用 §C+.1 系数） | 重跑规则文件 §2 枚举命令 vs framework-knowledge/reference-manual 清单行数 |
| 2 | **领域知识** | framework-knowledge.md 该框架节规律数 ≥ 规则文件头部声明的 `深度门槛`（默认 10），100% 含"证据:"字段；0 条残留"待验证"种子 | grep 计数比对 |
| 3 | **门禁** | precheck.sh 含 `_fw_<id>_check` 函数；函数内检查项数 = 规则文件 §4 门禁清单条数；`--framework` 实跑该框架分支 exit 0 | grep 存在性 + 条数比对 + 实跑 |
| 4 | **约束** | dev-guide.md §10 含该框架约束段（≥3 条，每条标注来源规律 id） | grep 段标题 + 条数 |

`--framework` 门禁自身两处收紧：已激活框架但 `_fw_<id>_check` 函数缺失 → **fail**（动态分发，declare -f 探测）；ACTIVE_FRAMEWORKS 未配置但探查信号明显（如存在 `*Mapper.xml`）→ warn 提示"疑似漏配 <规则集>"。

#### 5.3 错误处理与边界

| 场景 | 处理 |
|------|------|
| 探查到框架但范式无对应规则文件（长尾框架） | 生成时 warn 明确列出"未覆盖框架清单"，写入目标技能 framework-knowledge.md §待补；**不静默跳过**；引导用户按 `_template.md` 贡献新规则集（扩展机制正式化） |
| 框架版本超出规律标注区间 | 该规律标"待验证"而非直接实例化；`--framework` 对"待验证"规律 warn（提示人工确认），不 fail |
| 片段注入冲突（用户手改了标记区块内代码） | 检测区块哈希与上次注入不符 → 暂停并要求用户裁决（遵守"疑虑必确认"），裁决结果记入 `.swarm-yuan-version` |
| 跨框架规则冲突 | 以规则文件 §5 交互段为准；framework-knowledge.md 中冲突规律须互相引用说明取舍 |
| 离线环境生成 | 规则库/片段库全内置，不依赖联网；联网调研只发生在范式自身维护时 |

#### 5.4 precheck.conf 变量段通用化

现有 8 个框架变量（MYBATIS_MAPPER_DIRS 等 mybatis/lombok/sharding/spring-batch 专用硬编码）改造为**约定式命名**：`<RULESET_ID>_<VAR>`（如 `MYBATIS_MAPPER_DIRS`、`VUE_FILE_GLOBS`、`KAFKA_TOPIC_PATTERNS`）。片段头部 `requires_conf` 声明依赖，注入时自动核对。既有 8 个变量保留兼容。

### 6. 框架清单（~56 个，按生态分组）

| 组 | 框架（ruleset_id） | 数量 |
|----|-------------------|------|
| **Java 核心** | spring-boot, spring-cloud, spring-security, spring-batch, spring-data-jpa, mybatis（含 MyBatis-Plus）, lombok, mapstruct, validation（hibernate-validator）, jackson, junit5-mockito | 11 |
| **Java 分布式/中间件** | sharding, dubbo, seata, sentinel, nacos, xxl-job, elasticsearch, netty | 8 |
| **数据集成/流计算**（新增组） | kettle（PDI ETL）, flink（含 flink-sql / flink-cdc 差异标注）, paimon（Apache Paimon 流式数据湖） | 3 |
| **MQ/缓存/调度**（已有，深化） | rocketmq, kafka, rabbitmq, redis, quartz, elasticjob | 6 |
| **数据库**（已有，深化） | mysql, postgresql, sqlserver | 3 |
| **Node 后端** | express, koa, nestjs, fastify, typeorm, prisma | 6 |
| **Python** | django, flask, fastapi, sqlalchemy, celery, pytest | 6 |
| **Go** | gin, gorm | 2 |
| **前端核心** | vue, react, angular, nextjs, nuxt | 5 |
| **前端 UI/工程** | element, antd, naiveui, vite, webpack, tailwind | 6 |
| **前端测试** | jest-vitest | 1 |
| **合计** | | **57** |

说明：

- 7 个（vue/naiveui/pinia/koa/socketio/vite/vitest）门禁实现从 ncwk-dev 反哺；socketio 可归入 Node 组，pinia 随 vue、vitest 随 jest-vitest 合并管理，最终数量以 **56±4** 浮动，不重凑数而重质量门槛（每框架 ≥10 规律）
- 现有 20 个规则集全部按新六段式模板重写深化
- kettle/flink/paimon 为用户指定补充（2026-07-17）：kettle 覆盖 ETL 作业/转换工程规律（kettle 已停止活跃演进，重点标注 Pentaho CE 9.x 与 Hop 分叉）；flink 覆盖 checkpoint/savepoint 状态语义、watermark、exactly-once 两阶段提交、Table API/SQL 与 DataStream 选型；paimon 覆盖主键表 Changelog 语义、Compaction、与 Flink 读写协同

### 7. 调研分批计划

每批：联网调研（官方文档/changelog 现行版本，2026-07 时点，来源 URL 记入规则文件头部）→ 写规则文件 + 门禁片段 → 自核验（四要素 + 片段双态测试）。

| 批次 | 内容 | 验收 |
|------|------|------|
| P0 | 基建：`_template.md` + precheck.sh 调度器/公共函数 + 注入机制 + conf 通用化 + **收割 ncwk-dev 7 片段** + 信号索引生成脚本 | 收割后 ncwk-dev 回灌零回归（26 门禁全 pass、`--framework` ≥28 项） |
| P1 | 实测踩坑组：mybatis, lombok, spring-batch, sharding（最高优先） | 每个过四要素核验 + 双态测试 |
| P2 | Java 核心其余 7 个 | 同上 |
| P3 | Java 分布式 8 + 数据集成/流计算 3（kettle/flink/paimon）+ MQ/缓存/调度深化 6 | 同上 |
| P4 | 数据库 3 + Node 6 + Python 6 | 同上 |
| P5 | Go 2 + 前端 12 + 流程/文档收尾（exploration-guide/domain-knowledge/template-spec/SKILL.md 改造） | 全量回归 |

### 8. 验证策略

#### 8.1 ncwk-dev 回灌验证（P0 后即做，范式首个实测）

1. 用新范式对 `/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev` 执行 `--upgrade`
2. **零回归断言**：`--all-full` 26 门禁全 pass；`--framework` 检查项 ≥ 原 28 项；手写 `_fw_*_check` 内容等价迁入标记区块
3. **新能力断言**：framework-knowledge.md 转为新模板结构；`.swarm-yuan-version` 记录升级

#### 8.2 测试策略

- **门禁片段双态测试**：每片段配 fixture（1 个违例 + 1 个合规样本），断言 fail/pass 两态——P1 起每批附带
- **端到端 fixture**：构造迷你 Java 项目（pom.xml 含 mybatis+lombok 依赖 + 故意违例的 `*Mapper.xml` / `@Data @Entity`），跑完整生成流程，断言四要素核验全部触发且 `--framework` 按预期 fail
- **范式自兼容**：全部脚本遵守三平台兼容铁律（无 `declare -A`、`sed -i.bak+rm`、`grep -E` 等现有约定）
- 全程在本仓库 `feat/framework-rules-engine` 分支开发；**不自动推送 GitHub**，推送前做敏感信息脱敏检查

#### 8.3 风险与缓解

| 风险 | 缓解 |
|------|------|
| 56 框架调研量大，单批质量滑坡 | 每批独立验收（四要素 + 双态测试），不达标不进入下一批；P1 四框架先行验证模板合理性后再放量 |
| 规律版本区间过时 | 文件头"最后调研"日期 + 来源 URL；范式发布流程增加"规则库时效检查"（>6 个月 warn） |
| precheck.sh 注入后体积膨胀 | 片段仅在激活时注入目标技能；范式自身的片段库不影响运行时性能 |
| ncwk-dev 回灌回归 | P0 验收硬门禁：检查项只增不减，26 门禁全 pass |


### A7. 审计优化决策

> 审计轮优化决策记录。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §5/§7（约束+留痕，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。



> 分支：`fix/audit-optimization`（已合入 main）｜ 触发：`/goal 全面分析 swarm-yuan skill，排查设计理念/实现机制/实现文件问题并迭代优化`
> 方法：4 个并行子代理审计（设计理念 / precheck 机制 / 生成器+生命周期 / 57 门禁+fixture），全部结论经主会话**独立复核**（读代码路径 + 实跑复现）后才处置。

### 审计结论总览

**算术骨架真实成立**（独立复核确认）：27 个门禁 flag ↔ 27 个 `check_*` 函数一一对应；核心 10 + 架构 17 = 27；precheck.conf = 146 变量；57 框架三件套（规则 md / 门禁片段 / fixture）1:1:1；32 领域；57/57 fixture 双态绿。

**但因果链在真实配置上被四类问题削弱**：① 沉睡/崩溃（set -e + pipefail + 空数组）；② 未配置门禁静默跳过，绿 ≠ 合规；③ 存在性门禁对范式自带模板自证；④ 文档头部数字无单一事实源 → 漂移。

### 已修复（5 批，均带验证）

| # | 严重级 | 问题 | 修复 | commit |
|---|--------|------|------|--------|
| 1 | CRITICAL | `check_shift_left` 三处 grep 缺 `|| true`，set -e+pipefail 下 `--all-full` 在 framework/test 门禁前中断（实测复现：输出停在「运维监控左移」，框架+测试门禁永不执行） | grep 管线末加 `|| true` | `61f2af6` |
| 2 | HIGH | `--all`/`--all-full` 分发循环中，单门禁 fail 路径非零返回（check_scope:339 等）触发 set -e，中断后续 8-9 个门禁 | 分发循环加 `|| true`（FAIL 全局仍正确汇总） | `61f2af6` |
| 3 | HIGH | 7 处空数组 `"${ARR[@]}"` 在 bash 3.2 崩溃（unbound variable），`_default_conf` 默认空数组时触发 | 改 `${ARR[@]+"${ARR[@]}"}` 防护 | `61f2af6` |
| 4 | MED | `check_stable_diff` glob 前缀 `%%` 最长匹配 bug（`paradigm-decisions.md` 已在 check_layer 修过的同款） | `%%` → `%` 最短匹配 | `61f2af6` |
| 5 | HIGH(fail-open) | `generate-skill.sh --inject-frameworks` 缺闭标记时 awk `skip=1` 到 EOF，静默删除区块后公共库+main 分发（无备份不可恢复） | 校验双标记，缺闭标记即中止不改动文件 | `61f2af6` |
| 6 | 文档漂移 | USAGE.md/PROMO.md 停留 14特征/25门禁/45变量/架构15/10运行时；SKILL.md 正文 10运行时（frontmatter 本就 11）；framework-signal-index 漂移（koa 缺 socket.io） | 全部同步至真值 16/27/146/11；索引重生成 | `2817185` |
| 7 | 机制 | `check_doc_consistency` 只 grep SKILL.md，抓不到 USAGE/PROMO 漂移；门禁函数计数 `[a-z]+` 漏数下划线（23≠27） | 新增跨文档数字一致性检查（从代码算真值扫散文）+ 索引时效检查 + 计数口径修复 | `2817185` |
| 8 | chore | Swarm-studio 通用文件过时（批次 1/2 修复未同步） | `SKILLS_PATH_REWRITE --upgrade` 重同步，恢复填充型文件，清理 backup/.bat | `d8568a8` |
| 9 | HIGH | verifier shellcheck 腿硬编码 `/mnt/agents/tools`，无 shellcheck 机器谎报 `SHELLCHECK_ERRORS 0` | 按 `$SHELLCHECK`→PATH→/tmp→/mnt 解析，均无则失败关闭报 `SHELLCHECK_UNAVAILABLE` | `7c8c69d` |
| 10 | HIGH | 修复 #1 移除崩溃掩盖后，ROLLBACK_KEYWORDS 的 `\|` 字面 bug 变成活跃误报（有回滚预案也 fail） | 单独修复 ROLLBACK_KEYWORDS 为 ERE 交替符（仅这个可达硬门禁；其余 4 处 warn-only 保留沉睡） | 本批 |

每批验证：`bash -n` 语法通过 + 57/57 fixture 双态绿 + e2e RC 0 + `--all-full` 最小 conf 实跑到 framework/test 门禁并正常汇总。

### 刻意不修（遵循范式「不贸然唤醒沉睡门禁」原则）

以下问题真实存在且为 HIGH，但修复会**改变门禁判定行为**，在无真实项目样本+fixture 覆盖的情况下，贸然修复可能「唤醒沉睡门禁 → 淹没真实项目误报」（`paradigm-decisions.md` 建议 1/2 的教训）。留作独立版本决策，每项需先补 fixture 再评估苏醒影响：

1. **五层认知基底是装饰性叙事**：`check_cognition` 含 **0 个 `fail()` 调用**（门禁永不 fail，仅对范式自带 spec-template 做关键词打分）；分数上限标注 `/11`（实际 14）`/19`（实际 22）错配。修复 = 重新设计该门禁的判定语义，不是改 bug。
2. **`\|` 交替符在 grep -E 下是字面**（5 处：ROLLBACK_KEYWORDS/BREAKING_DDL/METRIC/LOG/TRACE）：实测 `grep -ciE '回滚\|revert'` 对含两词的 spec 返回 0。**已部分修复**：ROLLBACK_KEYWORDS 经 `SPEC_FILE` 可达且是硬门禁，修复 #1 移除崩溃掩盖后实测会对「有回滚预案」的 spec 误报 fail（`✗ spec 无回滚预案声明`）——故单独修复为 ERE 交替符（见下「追加修复」）。BREAKING_DDL/METRIC/LOG/TRACE 四处是 warn-only 且已带 `|| true`，修复会让它们「苏醒」开始 warn（行为改变），按 `paradigm-decisions.md:31-36` 决策**保留沉睡**，留独立版本评估。
3. **存在性门禁对范式自带模板自证**：`--shift-left`/`--domain`/`--cognition`/`--impact` 在无项目 spec 时回退到 `assets/spec-template.md` 并对其空壳判 pass。`--reuse` 已修过同类（precheck.sh:830-836 注释），其余四处未修。
4. **SILENT 跳过洞**：`--all-full` 下未配置门禁静默消失（约 15 个），运行仍 conclude「✓ 门禁检查通过」，汇总不披露实际执行了几个。是「文档记录的设计」（precheck.sh:234），但汇总行过度声称。建议加跳过计数器（非破坏）。
5. **`check_link_depth` 兜底 GNU-only**（`grep -rzoP`，macOS/BSD 无效）→ pure_fwd 静默为 0（fail-open）；**madge 循环依赖 grep 可能永不命中**（verdict 走 stderr 被丢弃）。
6. **Swarm-studio 样例违反自家 v2 旗舰主张**：reference-manual §4 只 10 组件无签名/计数核验（README 称 15+），§6 用通配符 `/api/kanban/*`（template-spec 禁通配符），§9/辩证/领域段缺失；`precheck.conf:1` 硬编码作者机器绝对路径。修复 = 重填样例（内容工作，非 bug）。
7. **运行时数 9/10/11 三处漂移**（cognition-framework.md:116 说 9）——本次只统一了 SKILL/USAGE/PROMO 到 11；cognition-framework.md 的「9」涉及该文档自身叙事，留待确认是否同步。

### 遗留（低优先，未处置）

- `migrate_merged_frameworks` 写回多行 `ACTIVE_FRAMEWORKS` 会产生孤儿续行（MED，需非模板 conf 格式才触发）。
- `SKILLS_PATH_REWRITE` 会改写 self-check.sh 内运行时探测路径（MED，studio 实例 superpowers/ecc 检测受影响）。
- `state-machine.sh` 允许前向跳阶段（open→verify 守卫是占位 `pass`）。
- 5 个死 conf 变量（COGNITION_MAP/LOMBOK_ANNOTATIONS/TEST_DIR_PATTERNS/IMPL_DIR_PATTERNS/METRIC_ENDPOINTS）。
- 安装/自举层面：CI 从未对生成器仓库跑 27 门禁；26/27 非框架门禁无 fixture。

### 方法论备注

子代理审计的每条 HIGH/CRITICAL 结论，主会话都**独立复核**（读代码路径 + 写最小 conf 实跑复现）后才动手——子代理报告的「--all-full 中断」「空数组崩溃」「fail-open 注入」「USAGE 漂移」「认知门禁 0 fail」「\| 字面」六条全部经实跑确认属实。这避免了按二手报告误改门禁逻辑（本仓库的头号风险）。


### A8. 上游引入决策

> 上游运行时引入边界决策。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §3.3（接线）/§9.3（吸收边界）（原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。



> 日期：2026-07-20 ｜ 分支：`feat/standards-compliance`（P1-7）
> 记录 superpowers 核心插件 vendor 问题的正式决策与理由，供后续版本维护参考，避免重复调研。格式参照本文 §6.3 决策史。

### 处置总览

| # | 事项 | 决策 | 依据 |
|---|------|------|------|
| 1 | vendor superpowers 核心插件 v6.1.1 进 offline-cache | ❌ 不 vendor（维持 marketplace 元数据 + 空壳明示现状） | 本文件 §二 |
| 2 | 空壳误判治理（诚实检测 + 文案） | ✅ 已做（P0） | `self-check.sh` check_superpowers 实质检测、`offline-cache/UPSTREAM.md` §二 |

### 一、背景事实（2026-07-20 核实）

- offline-cache 内的 `superpowers/` 是 **superpowers-marketplace v1.0.13**（全目录仅 4 文件：`LICENSE`、`README.md`、`.claude-plugin/marketplace.json`、`.claude/settings.local.json`），核心插件 v6.1.1 本体不在包内；marketplace.json 以 URL source 指向 `https://github.com/obra/superpowers.git`（`docs/research/R5-upstream-local.md` §四，2026-07-20 本地实证）。
- 核心插件仓库 https://github.com/obra/superpowers ：**MIT** 许可证，最新 release **v6.1.1**（2026-07-02 发布；v6.0.0→v6.1.1 约六周内 5 个 tag）——GitHub REST API 实测，访问 2026-07-20。
- swarm-yuan 对 superpowers 的吸收是**文档级方法论引用**（14 个 skills 能力清单登记于 `swarm-yuan/references/subagent-orchestration.md:118-137`），不是运行时命令调用——`swarm-yuan/SKILL.md:108` 工具引用铁律的允许 CLI 清单（graphify/gitnexus/ocr/claude-mem/gsd-tools）不含 superpowers。
- P0 已完成诚实检测与文案：`scripts/self-check.sh` check_superpowers 实质检测（须含 `skills/` 子目录或 `.claude-plugin/plugin.json` 才判已安装；仅 marketplace 元数据判空壳 miss，fail-closed）；`scripts/install-offline-win.sh（已废弃，WP 瘦身后改用 Release 附件 + self-check install_from_src_release）:105` 文案改为「目录已复制，需在 Claude Code 中 /plugin enable」；`offline-cache/UPSTREAM.md` §二空壳明示。

### 二、决策理由

#### 1. zip 体积

offline zip 已 44MB（`docs/paradigm-decisions.md:49`）。核心插件含 20+ skills 本体及资源，vendor 将进一步膨胀 Release 附件；离线包的消费场景是 Windows 一次性落地 11 个运行时（`scripts/install-offline-win.sh:2,5-7`），体积直接决定分发成本。

#### 2. 维护面

vendor 即承担版本追踪与逐版重核义务。核心插件迭代快（v6.0.0→v6.1.1 约六周 5 个 tag），vendor 副本会立即开始漂移，须纳入本文 §6.4 上游基线审计例程；而 swarm-yuan 对 superpowers 没有运行时调用，vendor 不带来任何运行时收益——纯属为「文档级引用」背维护负担。

#### 3. 许可证

核心插件本身 MIT（允许再分发，保留 LICENSE 即可），不构成 vendor 障碍；但 marketplace 编目的 10 个插件各有独立 license（marketplace README 明示 "Individual plugins: See respective plugin licenses"），一旦开 vendor 口子，就须逐一核实并保留各子插件 LICENSE；elements-of-style 插件还内含 Strunk《The Elements of Style》(1918) 全文（美国公有领域，跨境分发宜标注来源与公版状态）。不 vendor 核心插件，即把许可证敞口收敛在 marketplace 元数据一个 MIT 文件上。

#### 4. plugin 生态

superpowers 的正规获取路径是插件市场在线安装（marketplace.json 的 URL source 机制本为在线拉取设计）；vendor 核心插件等于维护一份脱离市场更新通道的静态副本，与上游生态演进脱节。离线用户需要核心能力时的既定路径：在线环境 `/plugin install superpowers@claude-plugins-official`，或手动 clone 仓库并保留其 LICENSE（UPSTREAM.md §二已明示）。

### 三、风险与缓解

| 风险 | 缓解 |
|---|---|
| 离线用户误以为已装核心插件（空壳） | P0 已修：self-check 实质检测 fail-closed；install-offline-win.sh 文案不再宣称核心能力；UPSTREAM.md §二明示 |
| references 引用的 14 个 skills 能力离线不可得 | 接受。吸收物是方法论（已写进 references 供 AI 阅读），不依赖插件本体在场 |
| 未来 superpowers 能力变成运行时依赖 | 复审触发：若 `SKILL.md:108` 允许 CLI 清单新增 superpowers 系命令，或离线分发成为主要形态，重开本决策并连子插件许可证复核一并进行 |

### 不做的事（本决策明确）

- 不 vendor 核心插件 v6.1.1 及 marketplace 任何子插件
- 不改 install-offline-win.sh 的复制目标（仍复制 marketplace 目录，由实质检测兜底避免误判）
- 不逐版追 superpowers 更新（引用基线 v6.1.1 = 上游最新 release，本文 §6.4 状态 synced）


### A9. Q2 重量级审查

> 2026-08-19 分层实现评审报告。（历史原文，不再单独维护）

> **归档标注（2026-08-21 v3 整合）**：本档案已并入本文档 §6.1 §0 冲程三（机械 vs AI 边界，原 docs/DESIGN.md）——单一设计事实源现为本文档 §6.1；本段保留为历史原稿（不再单独维护，内容以 §6.1 为准）。

> **档案标注（2026-08-21）**：本档案已并入本文档 §6.1 §2.2（范式作为条件，原 docs/DESIGN.md）——内容以 §6.1 为准；本段保留为机械 vs AI 边界复盘历史原稿。


**评审背景**：Q2 报告（"机械门禁/脚本扫描破坏 AI 灵活性"）的深水区单独评审。WP-Q2-lite 已收
failure-detector 去重 + tone 软化 + trace-log --key-node 三件套，但还有三条更深的问题需要拍板。

**评审方法**：把 54 门禁按"机械信号 vs AI 判断"二分，给出三个维度（D1 探索式 / D2 假装可机器 /
D4 流程过度脚本化）的边界清单。

---

### D1：探索式 gate 移除/rewrite —— 哪些门禁应改为 AI 自觉判断

**判定原则**：门禁的输出是否确定可信？
- 可信（exit 0/1 与断言一致） → 保留机械
- 不可信（启发式/易误报/依赖工具版本） → 转 AI 自觉判断（advisory 级保留，不机械 run）

**转 AI 自觉判断的候选（advisory → 文档化提示，不再机械跑）：**

| 门禁 | 现状 | 问题 | 建议 |
|------|------|------|------|
| `check_cognition` | grep + wc -l 数 5 个维度 | 5 维度本质是认知框架清单，AI 读 reference 即可 | 转文档化（"检查 cognition 5 维度"），不再机械 grep |
| `check_consistency` | 术语↔代码 grep | 误报高（同名词多） | 保留但降为「提醒人工核对」模板 |
| `check_link_depth` | graphify/madge 深度 | 工具依赖重，未装降级统计纯转发函数 | 转可选（OFF=1 时不跑） |
| `check_diagram` | 检测 mermaid/plantuml | 启发式，AI 看图即可 | 转 AI 自觉判断 |
| `check_decision_audit` | decisions.jsonl 格式 | 格式机械可查，但"决策是否合理"是 AI 判断 | 保留格式校验，删"合理性"判断 |
| `check_state` | state.yaml 字段 | 字段机械可查，但状态是否合理是 AI 判断 | 保留字段校验 |
| `check_pr_quality` | 各种 wc -l + grep | 启发式强，AI 看 diff 即可 | 转 AI 自觉判断 |
| `check_operate` | HTTP/health-check 探活 | 探活机械可信，但"运营是否合理"是 AI 判断 | 保留探活，删"合理性"判断 |

**保留机械（信号可信，误报少）：**
- `check_layer` / `check_branch` / `check_security` / `check_sensitive` —— grep + 模式匹配确定
- `check_requirements` / `check_rtm` —— spec 结构化字段机械可查
- `check_test_evidence` / `check_review_record` / `check_release_sign` —— 文件存在性机械可查

---

### D2：taste vs mechanical —— 哪些门禁"假装可机器"

**判定原则**：fail/warn 是否每次都能指向真实问题？

**误报高的（应转 advisory 或重写信号）：**

| 门禁 | 误报成因 | 建议 |
|------|---------|------|
| `check_consistency_cross` | 术语↔代码 grep，同名词/缩写误报 | 转 advisory（已 advisory，但 warn 级别仍输出） |
| `check_stable_diff` | "稳定"标注 vs 实际改动 | 改 inventory-verify --stability-audit 接管（已做） |
| `check_adr` | ADR_DIR 不存在 fail 太硬 | 改 warn（已 advisory，但 ADR_DIR 还是 fail） |
| `check_framework` | 框架规则 grep 启发式 | 按 fw 分组，没装 fw 时跳过 |
| `check_knowledge` | 知识库存在性 + grep 规律 | 知识库缺失不算 fail，仅 warn |
| `check_sast_deep` | semgrep/lexical 启发式 | 未装时 warn，不 fail |
| `check_metrics` | 覆盖率/复杂度启发式 | 未配置时 skip_if_unconfigured |
| `check_crypto` | 加密配置 grep | 启发式强，AI 看代码即可 |
| `check_oss_eval` | SBOM/license 启发式 | 无 SBOM 工具时降级 |
| `check_docs_pack` | 文档存在性机械可查，但"文档质量"是 AI 判断 | 保留存在性，删质量判断 |

**taste 类（AI 判断，不应机械化）：**
- 组件复用是否重复造轮子（AI 看语义，不只 grep 重名）
- 架构决策是否合理（ADR 质量）
- spec 是否清晰可执行（不是结构化字段就能保证）
- 测试是否覆盖关键路径（不是文件存在性）

---

### D4：生成流程过度脚本化 —— 哪些环节应让 AI 判断

**现状**：generate-skill.sh 17 步骨架创建 + 8 节点 workflow + state-machine.sh 阶段追踪。
**问题**：有些环节是"AI 应该自己判断"（非机械流程），但目前脚本化了。

**应让 AI 判断的环节：**

| 环节 | 现状 | 问题 | 建议 |
|------|------|------|------|
| Step 2 特征卡提取 | extract-feature-cards.sh 机械 | 17 项特征卡本质是 AI 阅读 spec 后的判断 | 脚本只做"模板化输出"，特征值 AI 填 |
| Step 4 组件库清单 | inventory-verify 机械计数 | 已硬化（WP-Q1A）防幻觉 | 保留现状 |
| Step 5 conf 填充 | conf-render.sh 嗅探+模板 | 嗅探机械可信，但"是否需要该门禁"是 AI 判断 | conf-render 出初稿，AI 审 |
| Step 6 框架深化 | framework-evidence 机械 grep | 框架规律本质是 AI 对项目代码的理解 | 机械只做"证据存在性"，规律实例化 AI 做 |
| Step 7 hooks/commands 生成 | generate-skill 模板化 | 模板固定，但"目标技能 是否需要这些 hooks" 是 AI 判断 | 默认全开，AI 删 |

**保留机械的环节（确定性高）：**
- 骨架创建（generate-skill.sh 文件复制+占位符）—— 纯机械
- precheck.conf 模板渲染（conf-render.sh）—— 嗅探+模板机械
- 占位符清零（verify_completeness）—— 机械 grep
- 状态门（--mark-active）—— 机械规则
- 门禁分级 enforce_level 加载 —— 机械 conf 读

---

### 综合建议（不动代码，仅评审结论）

1. **advisory 档 15 个门禁里，5 个转 AI 自觉判断**（cognition/diagram/pr_quality/consistency/link_depth 中的"质量判断"部分），其余 10 个保留机械信号但删掉"合理性"判断（只报存在性/格式）。
2. **warn 档 25 个门禁里，7 个降级为 advisory**（consistency_cross/stable_diff/framework/knowledge/sast_deep/metrics/crypto），避免误报打断主流程。
3. **strict 档 20 个门禁不动**——这 20 个信号可信、误报少，机械运行合理。
4. **生成流程**保留机械骨架创建 + conf-render + verify_completeness + mark-active + enforce_level；特征卡提取/框架规律实例化/hooks 选择这三个环节转"机械出初稿 + AI 审"模式。

**下一步**：
- 用户拍板是否进入实施（Q2-heavy D1/D2/D4 改造）
- 若实施，预计 4 个 worktree（advisory 降级 / warn 降级 / 生成流程 AI 化 / 文档同步）
- WP-Enforce2/3 待 Q2-heavy 结论（若 advisory 大量降级，Enforce2/3 需要重新评估范围）


### A10. 运行时升级 2026-07

> 2026-07 运行时升级差异报告。（历史原文，不再单独维护）

> 本报告记录 `swarm-yuan/research/` 下 11 个外部运行时仓库的对齐情况：6 个升级到最新稳定版，5 个已最新。每个升级项附功能差异与**整合建议**（建议的落地情况见 §3"整合吸收落地清单"）。
>
> 口径：本报告是留底文档，不进 `facts.conf` 单一事实源（运行时版本号不在 catchphrase 口径内）。运行时仓库本身是 `research/` 下未追踪的嵌套 git 仓库，升级不产生 swarm-yuan 自身的 git diff--本报告是升级的唯一留底。

### 1. 升级总览

| 运行时 | 接线层 | 旧版本 | 新版本 | 范围 commit 数 | 状态 |
|---|---|---|---|---|---|
| claude-mem | 深度接线 | v13.11.0 | v13.12.4 | ~6 个 release | ✅ 升级 |
| graphify | 深度接线 | v0.9.19 | v0.9.27 | 108 | ✅ 升级（origin/v8 线性路径）|
| gsd-core | CLI 接线 | v1.7.0 | v1.8.0 | 91 | ✅ 升级 |
| open-code-review | 深度接线 | v1.7.12 | v1.7.17 | 67 | ✅ 升级 |
| ruflo | 方法论引用 | v3.32.4 | v3.32.9 | 8 个修复 | ✅ 升级 |
| superpowers | 方法论引用 | v6.1.1 | v6.2.0 | SDD 重构 + 压缩扫荡 | ✅ 升级 |
| ECC | 方法论引用 | v2.0.0 | v2.0.0 | -- | ⊙ 已最新 |
| comet | CLI 接线 | 0.3.9 | 0.3.9 | -- | ⊙ 已最新 |
| gitnexus | 深度接线 | v1.6.9 | v1.6.9 | -- | ⊙ 已最新 |
| openspec | CLI 接线 | v1.6.0 | v1.6.0 | -- | ⊙ 已最新 |
| gstack | 方法论引用 | （无 tag）| （无 tag）| -- | ⊙ 已最新（main 跟随）|

#### graphify 版本路径说明（重要）

`research/graphify` 存在两条无共同祖先的谱系：
- **v0.9.x 线**（`origin/v8`，生产主线）：40 语言 / 10+ IDE 平台 / strict PreToolUse hook / vs mem0/supermemory 基准。本次升级路径 v0.9.19 -> v0.9.27，`git merge-base v0.9.19 v0.9.27 = v0.9.19`，108 个 commit，2026-07-18 ~ 2026-07-26。
- **v1.0.0 线**（commit `0a31c08`，不在 `origin/v8`）：13 语言 / 单平台 / "Karpathy /raw folder" 框架，2026-04-05（比 v0.9.19 旧 3 个月），是独立且更不成熟的并行代码库。

**本次取 v0.9.27（v0.9.x 线），不取 v1.0.0**。理由：v1.0.0 与 v0.9.19 无共同祖先（`git merge-base` 返回空），是异源旧分支；取它会丢失当前生产线的 40 语言/10 平台能力。

### 2. 逐项功能差异

#### 2.1 claude-mem（v13.11.0 -> v13.12.4）

**核心用途**：Claude Code（及 Codex/Cursor/Antigravity CLI/Windsurf）的持久记忆压缩系统--自动捕获工具使用观察、生成语义摘要、通过 hooks（捕获）+ worker 服务（压缩）+ Chroma 语义搜索（检索）跨会话可用。

**新功能**：
- **v13.12.0 双车道云同步（SyncHub，PR #3333）**：6 阶段同步架构--(P1) 每用户 Cloudflare Durable Object 同步枢纽 `workers/sync-hub`；(P2) 客户端 apply 路径 + schema 迁移 v41；(P3) 枢纽 push/pull 传输 + mutation outbox（持久本地变更队列，离线/重试存活）；(P4) advisory WebSocket 速度层（"正确性从不依赖 socket 存活"）；(P5) 护栏 + 监控（kill switch / watchdog / canary / 全同步矩阵 E2E）；(P6) canonical v2 projection pipeline。**默认关闭**（`CLAUDE_MEM_CLOUD_SYNC_HUB_URL` 空）。
- **v13.11.0 worker 原生云同步（PR #3182）**：独立 `cloud-sync.mjs` daemon 退役，worker 自身同步记忆；schema v40 自修复。
- **v13.12.2 `docs/merge-rubric.md`**（新工件）：bug-fix PR 的验收门槛，从 54-PR 合并扫荡中提炼。
- **v13.12.2 54 社区 bug-fix PR 合并**：根因修正 ONLY，拒绝 guards/circuit-breakers/fallbacks/retries/fail-open/self-healing/truncation。

**关键修复**：
- **v13.12.1 版本 oracle 单源**：4 个 worker-script resolver 改为按**版本排序、永不按 mtime**，共享一个确定性 version oracle。此前 mtime 排序导致重启风暴（一天 2,424 次回收）。
- **v13.12.3 SIGKILL-the-corpse**：hook 不再委托垂死 worker 回收自己；版本不匹配时 hook 自身读 PID 文件 -> `SIGKILL` 旧 worker -> 等端口关闭 -> 自己 spawn 新版本。垂死 worker 的 successor handoff 仅服务 CLI 发起的 `claude-mem restart`。

**行为变更/弃用**：无顶层 CLI 子命令变化；技能集字节级不变（18 skills）；`/cloud-sync` skill 为 SyncHub 重写。

**整合建议**（落地见 §3.6）：
1. "单一 version oracle、永不按 mtime 排序"作为 self-check 断言（G10）--选版本/候选的路径必须用全序（version > capability > lexical）。
2. Merge Rubric 作为反模式门禁模板--拒绝"survive 失败而非 correct 根因"的 generated gate/skill。
3. 两车道同步（持久 outbox + advisory 快路径 + kill switch/watchdog/canary）作为多运行时/多设备同步模式参考。
4. SIGKILL-the-corpse 作为子代理/进程编排的生命周期模式--回收 stale worker 时由 supervisor 而非垂死进程 own kill+respawn。

#### 2.2 graphify（v0.9.19 -> v0.9.27）

**核心用途**：AI 编码助手的知识图谱构建器--`/graphify` 把项目（代码经 tree-sitter AST，文档/PDF/图片/视频经 LLM 语义 pass）映射为可查询图（`graph.json` + `graph.html` + `GRAPH_REPORT.md`）。查图而非 grep 文件。每条边标 `EXTRACTED`/`INFERRED`/`AMBIGUOUS`。本地优先（代码解析不用 LLM）。

**新功能**（v0.9.20-27）：
- **v0.9.27 C# 命名空间感知成员调用解析**（#1609）：typed receiver 经 `using`/scope 解析，`base.`/`this.field` receiver，经 `inherits` 链的继承成员查找。JS/TS 非相对 import 经 `jsconfig.json`/`tsconfig.json` `baseUrl`/`paths` 解析（#2153）。Python 装饰器创建图边（#2154）。
- **v0.9.26 Windows hook 重建超时武装**（#2148）：`threading.Timer` fallback（Windows 无 SIGALRM），`GRAPHIFY_REBUILD_TIMEOUT` 不再是静默 no-op。Bash `source` 文件调用得到 `calls` 边（#2141）。
- **v0.9.25 协议改 MIT -> Apache 2.0**（显式专利授权 + 专利报复 + 贡献条款；MIT 保留为 `LICENSE-MIT`）。移除死代码 `.graphifyinclude`（#2112）。
- **v0.9.24 MCP `get_neighbors`/`get_community` 遵守 `token_budget`（默认 2000）**，截断在顶部宣告（#2069）。
- **v0.9.23 `graphify path`/MCP `shortest_path` 确定性 + 每跳真实关系标注**（#2074）。`query` 不再丢弃超预算答案（种子按跳距排序，命名种子始终先渲染）。
- **v0.9.22 `graphify god-nodes` CLI 子命令**；`--output` 作为 `--out` 别名（#2004）。
- **v0.9.21 Ollama 自动检测 `OLLAMA_HOST`**（不仅 `OLLAMA_BASE_URL`）（#1940）。Barrel re-export 链解析（#1983）。
- **v0.9.20 graphify-first nudge 匹配 Claude Code 的 Grep 工具**（不仅 Bash）（#1986）。

**新 CLI/标志/hook**：新子命令 `graphify god-nodes`/`god_nodes`；新别名 `--output`；新 MCP 参数 `token_budget`；新 env `OLLAMA_HOST` 检测；`GRAPHIFY_REBUILD_TIMEOUT` 在 Windows 实装。strict PreToolUse hook（v0.9.19 引入，本范围细化）：`graphify install --project --strict` 装一个 PreToolUse hook，首次原始源码读取时 `permissionDecision: "deny"` 重定向到 `graphify query`，然后降级为软 nudge；每会话至多触发一次；fail open。

**行为变更/弃用**：协议 MIT -> Apache 2.0（向后兼容）；移除 `.graphifyinclude`（用 `.graphifyignore` 的 `!` 否定）；安装器不再覆盖不可解析的 settings 文件；`graphify uninstall` 不再删除用户自写的 `### graphify` 段。

**整合建议**（落地见 §3.3）：
1. **honest-edge provenance（EXTRACTED/INFERRED/AMBIGUOUS）作为记忆模式纪律**--每条 swarm-yuan 写回的记忆/断言应带溯源标签，`graphify diagnose` 对无源证据的 code-typed 节点标 `verification: "unverified"`。直接可移植的反幻觉机制。
2. **prompt-fingerprinted cache namespacing**--语义缓存条目按提取 prompt 的 fingerprint 命名空间化，prompt 变更只失效受影响条目。可移植到 swarm-yuan 的 cached 探查/分析。
3. **atomic-write + shrink-guard + fail-closed 作为工件完整性模式**--JSON 工件写临时文件再 `os.replace`；shrink guard 拒绝用更小的不完整图覆盖更大的完整图；不可解析文件 fail closed。
4. **token-budgeted、truncation-announced MCP/子代理输出**--每个工具/子代理响应声明 token 预算、按查询相关性排序、被查询目标保证不被截断、顶部宣告截断内容。
5. **strict PreToolUse "deny-then-downgrade" hook 模型**--hook deny 首次原始读取、重定向到结构化查询、然后降级为软 nudge、每会话至多一次、fail open。比 advisory `additionalContext` 更高带宽的门禁模型。

#### 2.3 gsd-core（v1.7.0 -> v1.8.0）

**核心用途**：GSD Core（"Git. Ship. Done."）是上下文工程 + spec 驱动开发框架，驱动 AI 编码代理经 5 步阶段循环：**Discuss -> Plan -> Execute -> Verify -> Ship**。通过在 fresh-context 子代理中跑重研究/规划/执行、保持主会话精简、结构化工件（STATE.md/CONTEXT.md）跨会话存活来解决上下文腐化。

**新功能**（91 commits）：
- **可逆性评级（reversibility tagging，#1951）**：plan 记录 `<reversibility rating="reversible|costly|one-way">`；`one-way` 自动插 `checkpoint:decision`；`costly` 标记但不阻断；"不确定时按 reversible"避免 checkpoint 疲劳。`--no-reversibility-gates` 覆盖。
- **`<precondition>` 任务元素（Design by Contract，#1949）**：任务前可选元素，未满足则 halt with `checkpoint:human-verify`。与后置条件（`<verify>`/`<done>`/`<acceptance_criteria>`）+ 不变量（`must_haves.truths`）配合。
- **破窗台账（broken-windows ledger，#1950）**：`WINDOWS.md` 工件跨阶段累积 stubs/TODOs/skipped tests/unrun verifies/unmet truths；`/gsd-ship` **在有 open 条目时阻断**（`ship:pre` 门禁，`artifact-frontmatter-equals` 谓词 on `open_count == 0`）。新 `gsd-tools windows status|append|waive|fixed` 子命令。
- **tracer-first planning 默认（#1945）**：每个 plan 默认 LEAD 一个生产质量端到端"tracer"切片；post-tracer 反馈门禁 halt-on-fail（自治）或 `checkpoint:human-verify`（交互）。
- **gsd-debugger 可靠性套件（Epic #1957）**：多信号 fix-acceptance 护栏（5 信号：目标测试 + mutation check Stryker + no-op/behavior-deleting detector + adjacent/held-out tests + revert-and-reconfirm）；Spectrum-based fault localization（Ochiai，#1959）；RCA 分支（fishbone + AND-gate，#1960）；bug-taxonomy 分类 + 策略路由（Bohrbug/Heisenbug-Mandelbug/Concurrency，#1961）；regression-test hardening PBT（#1962）；blameless-postmortem Prevention block（#1963）；semantic KB recall via MemPalace（#1964）。
- **Claude orchestration capability（BETA，默认关）**：采用 Claude Code 的 Workflow 工具（`/effort ultracode`）作为可选并行执行后端。
- **Honest verifier**：verify-phase 对非可推断的 `backstop` truths 弃权（不 false-pass）；直接跑声明的 probe 脚本（不信 SUMMARY 自报 PASS）；阻断 phase-modified 源文件含未追踪 `TBD`/`FIXME`/`XXX` 债务标记前进。

**新 CLI/标志**：`gsd-tools windows status|append|waive|fixed`；`gsd-tools claude-orchestration detect-backend|emit-workflow`；`gsd-tools state rebuild`；`--no-reversibility-gates`、`--no-tracer`、`--failure-class`。

**行为变更/弃用**：移除 Gemini CLI 运行时（"用 Antigravity CLI 代替"）；验证 staleness 改用 git commit time（非 fs mtime）；ReDoS 加固；phase-directory 解析对跨项目碰撞 fail loud。

**整合建议**（落地见 §3.1、§3.2）：
1. **reversibility-tagged 决策门禁**--把 `reversible/costly/one-way` 三级作为决策属性：one-way 决策自动升级到 UserChallenge（需人工 checkpoint）。
2. **broken-windows ledger 作为跨阶段 ship 门禁**--`WINDOWS.md` 风格缺陷登记，ship 前任何 open 条目阻断。
3. **multi-signal fix-acceptance 护栏（反过拟合）**--5 信号门禁，尤其"revert-and-reconfirm"信号捕捉只因偶然状态通过的修复。
4. **bug-taxonomy-routed debugging**--先分类失败类（Bohrbug/Heisenbug/Concurrency），再经显式表路由技术；SBFL 在 Heisenbug 上明确禁止（flaky 谱毒化排名）。
5. **honest-verifier 弃权 + 债务标记阻断**--对非可推断 truth 弃权而非 false-pass；直接跑 probe 脚本；阻断含未解 `TBD`/`FIXME`/`XXX` 的前进。

#### 2.4 open-code-review（v1.7.12 -> v1.7.17）

**核心用途**：OpenCodeReview（`ocr`）是 AI 驱动的代码审查 CLI（阿里巴巴内部工具开源）。读 Git diff，把变更文件发给可配置 LLM（经带 tool-use 的 agent），生成行级精度结构化审查评论。核心理念：**确定性工程 × agent 混合**--硬约束（精确文件选择、智能文件捆绑、细粒度规则匹配、外部定位/反思模块）处理"绝不能错"的；agent 处理动态决策与上下文检索。

**新功能**（67 commits）：
- **原生 OpenCode 集成（#498）**：`@opencode-ai/plugin` TS 插件，注册 `ocr_review` + `ocr_health` 工具 + `ocr-review` slash command。支持 `preview=true`（仅列将审查文件不用 LLM）。
- **iFlytek Spark 内置 LLM provider（#485）**：OpenAI 兼容端点。
- **GraphQL（.graphql/.gql）allowlist + 规则（#491）**：schema 演进/破坏性变更/命名/资源限制规则。
- **Julia（.jl）allowlist + 规则（#501）**：排除 Pkg `test-dir` 约定。
- **Rust 宏正确性检查（#475）**：`macro_rules!`/proc-macro 脚枪--`$expr` 双求值、缺 `$crate::`、未括号展开优先级、proc-macro panic 而非 `compile_error!`。仅在宏被定义时触发（保持精度优先）。
- **PO/Pot 代码审查规则（#404/#406）**：gettext `.po` 翻译文件 + `.pot` 模板。
- **Gerrit CI 集成示例（#401）**：stdlib-only `post_review.py`，一次批量 Gerrit POST。
- **Windows `install.ps1`（#397）**：校验和验证的一行安装。

**新 CLI/标志**：OpenCode 插件参数（`from`/`to`/`commit`/`resume`/`exclude`/`model`/`concurrency`/`timeoutMinutes`/`maxTools`/`maxGitProcesses`/`preview`）；新 slash command `ocr-review`；`--end-of-options` 守卫（git >= 2.24）。

**行为变更/弃用**：diff 解析修复（merge commit 对第一 parent 审查）；LLM 循环竞态修复（per-`RunPerFile` 会话作用域异步记忆压缩）；配置 round-trip 保留手编 `timeout_sec`。

**整合建议**：
1. **确定性工程 × agent 混合作为审查模式模板**--硬约束处理"绝不能错"的（精确文件选择、智能捆绑、细粒度规则匹配），agent 处理动态决策。
2. **四层规则优先级链 + `merge_system_rule`**--`--rule` flag > 项目 `.opencodereview/rule.json` > 全局 > 内嵌 `system_rules.json`，first-match-wins，可选合并。可移植到 swarm-yuan 的项目级门禁叠加框架默认。
3. **外部定位 + 反思模块**--position anchor 门禁（验证引用的行/文件匹配问题）+ reflection 门禁（复查评论内容对代码）作为两个质量门禁。
4. **per-language 规则文档注册表 + 精度优先偏置**--每语言规则文档，每规则"仅在 X 存在时触发"谓词守卫。
5. **async per-conversation 记忆压缩（竞态修复）**--每个 `RunPerFile` 会话 own 其压缩状态，防跨代理历史拼接。

#### 2.5 ruflo（v3.32.4 -> v3.32.9）

**核心用途**：Ruflo（前 Claude Flow）是 Claude Code 和 Codex 的 **agent meta-harness**--用 100+ agents、协调 swarm、自学习记忆（AgentDB + better-sqlite3）、federated 通讯、MCP server、hooks、密码学 witness/验证系统包装模型的执行层。

**新功能**（8 个修复，无新 CLI 命令/标志）：
- **跨平台（Windows 原生）plugin hooks（#2721）**：把每个 hook 命令从 `/bin/bash -c '...'`（Windows 原生失败）改成 `node -e` bootstrap 解析 `scripts/ruflo-hook.cjs`--"同一命令串在 Windows/macOS/Linux 不变运行"。
- **真 memory-DB 完整性检查进默认 `doctor`（#2748）**：之前仅 `existsSync()+statSync()`（任何文件都 PASSED）；现在默认跑 `checkMemoryStructuralIntegrity`（有界、WAL-aware `PRAGMA quick_check`）；确定性 malformed DB 映射到 `fail` 非 `warn`。
- **拒绝不安全 sql.js whole-image 写（live native WAL writer 下，#2749）**：memory CRUD 若回退到 sql.js read-modify-export-rename 路径，存在 `-wal`/`-shm` sidecar（live native 连接证据）时**拒绝**，返回 typed `success: false`。
- **statusline 真模型名 + worktree-aware 版本解析（#2747）**：`getUserInfo()` 不再硬编码 `'Opus 4.6 (1M context)'`；`getPkgVersion()` 加纯 fs worktree-root resolver（解析 worktree `.git` 文件指针恢复主仓根，无 `git rev-parse` spawn）。
- **`memory_search` namespace 修复（#2722）**：MCP 工具处理器把省略的 `namespace` 强制为字面 `'default'`，击败搜索层 `|| 'all'` 扇出回退。
- **defense-in-depth better-sqlite3 去重（#2746）**：强制单一去重 `better-sqlite3@12.9.0`（修补 SQLite 3.53.0，修复 SQLite WAL-Reset Bug）；close 前 `wal_checkpoint(TRUNCATE)`。

**新 hook 机制形态**：`node -e` bootstrap hook 模式（`process.argv=[...];require(path.join(CLAUDE_PLUGIN_ROOT,'scripts','ruflo-hook.cjs'))`）是新跨平台 hook 调用标准，替代 shell-based hooks。

**行为变更**：`checkMemoryDatabase` 报告行重标"Memory Database Presence"（诚实化存在-only 范围）；malformed unencrypted DB 现 fail（原 warn）；`better-sqlite3` 加到 `@claude-flow/cli` optionalDependencies，每条路径在 `MODULE_NOT_FOUND` 时降级 sql.js。

**整合建议**：
1. **witness-attested 质量门禁**--三层回归模型（行为 smoke + 密码学 SHA-256/marker-substring/Ed25519 witness manifest + 时序 `history.jsonl` for bisection）。每个 swarm-yuan 门禁可证明其载荷检查仍在位。
2. **sidecar-presence refusal 作为并发安全门禁**--"若 `-wal`/`-shm` 存在则拒绝不安全写"泛化为协作写入者检测门禁。
3. **`node -e` 跨平台 hook bootstrap**--生成带 hooks 的技能应采用此形式（无 shell 展开），直接关联 swarm-yuan 的"11 运行时整合"声明。
4. **tiered native->fallback doctor 检查**--"优先 native `integrity_check`，回退 sql.js main-image-only，各自诚实标注"分层是优雅降级验证门禁的模板。
5. **worktree-root resolver 无 `git` spawn**--纯 fs `.git` 文件指针解析器，延迟敏感模式可用。

#### 2.6 superpowers（v6.1.1 -> v6.2.0）

**核心用途**：跨 harness 技能包（Claude Code/Codex/Cursor/Kimi/Pi/Antigravity/OpenCode/Gemini）发~14 个行为塑造开发技能 + SessionStart bootstrap hook。技能以 markdown + prompt 模板 + shell 脚本形式；`evals/` harness 用 LLM 评判真实代理会话。

**新功能**：
- **SDD plan-scoped workspace**：`.superpowers/sdd/` 之前无 plan 身份或生命周期--后续 plan 会读前 plan 的进度账本当自己的（实战观察到"三轮污染"）。现 `sdd-workspace` 要求 plan 文件、解析 `.superpowers/sdd/<plan-basename>/`；ledger 首行命名其 plan；**最终审查干净后删除 workspace**（git 历史是持久记录）。
- **resume-based 修复环 + 五轮熔断**：修复环改用"resume 原实现者语义而非 fresh dispatch"：R1-3 resume 原实现者处理 open findings；R4-5 fresh dispatch 更强模型；R=5 熔断，controller **逐条 adjudicate** 每个 open finding（每条 adjudication 入 ledger；禁止静默丢弃）。
- **scoped re-review prompt**：新模板 `re-review-prompt.md`--re-reviewer 只验修复（per-finding verdicts ADDRESSED/NOT ADDRESSED）+ 检查 fix diff 新破坏，不重读全任务。out-of-scope 观察入 ledger 不入环。
- **`writing-good-tests.md`（替换 `testing-anti-patterns.md`）**：六规则正向目录，每条先给 GOOD 示例 + 吸收可证伪性纪律："说出会让该测试失败的生产改动，期望独立于被测代码推导"+ 闭合 **Mutation Check**。硬止两类陷阱：**string-presence trap**（grep 式测试伪造可证伪--可观察的是行为不是文本）+ **change-detector trap**（常量断言能失败却保护不了什么）。
- **Windows SessionStart hook via Git Bash**：hook 命令串以引号路径开头，破坏 PowerShell/cmd.exe；现声明 `shell: "bash"`，Claude Code ≥ 2.1.81 解析为 Git for Windows。
- **branch-wide 技能压缩扫荡**：recap/persuasion/social-proof 段跨~12 技能移除；guard 段转为 house **Excuse/Reality rationalization 表**。每次剪切经子代理探针微测；一次可测量降级行为的剪切（TDD 的"Why Order Matters"）被重作为 rationalization 行而非发布。
- **`finishing-a-development-branch` 不再提供丢弃工作**：完成菜单去掉"Discard this work"。

**新工件**（无新技能目录）：`skills/subagent-driven-development/re-review-prompt.md`（新文件）；`skills/test-driven-development/writing-good-tests.md`（新文件，替换 `testing-anti-patterns.md`）；`skills/using-superpowers/references/gemini-tools.md`（恢复）；新 hook 机制 `shell: "bash"` 声明。

**行为变更/弃用**：SDD workspace 改 per-plan 且最终审查干净后删除（breaking for 现有 scratch 目录）；修复环语义改 resume（R1-3）而非总 fresh dispatch；`testing-anti-patterns.md` 移除（折入 `writing-good-tests.md`）；`finishing-a-development-branch` Option 2 现真创建 PR/MR 并报告 URL。

**整合建议**（落地见 §3.4、§3.5）：
1. **plan-scoped 持久进度账本**--`.superpowers/sdd/<plan-basename>/` 模式：per-plan workspace、首行命名 plan、最终审查干净后删除、是 compaction 后的 resume map。
2. **resume-based 修复环 + 五轮熔断**--R1-3 resume / R4-5 fresh+更强模型 / R=5 adjudicate 模式，eval-验证的子代理模式。
3. **scoped re-review prompt 作为验证门禁**--re-reviewer 只判决 fix diff（ADDRESSED/NOT ADDRESSED per finding + 新破坏检查），out-of-scope 入 ledger。
4. **可证伪性门禁 + Mutation Check**--"说出会让该测试失败的生产改动"+"期望独立于被测代码推导"+ 闭合 mutation check + 硬止 string-presence/change-detector 陷阱。
5. **技能文本编辑的微测门控**--每次剪切经子代理探针微测；可测量降级行为的剪切被重作而非发布；rationalization 表形式（Excuse/Reality 行在代理 rationalization 中途触发处）。

### 3. 整合吸收落地清单

从上述 30+ 候选里精选 6 项落地。**全部不新增 `check_*` 门禁**（守决策 26 的 `FACT_GATES_BUDGET=54` 上限），以方法论吸收（references 文档 / SKILL.md 叙事 / state-machine warn 分支 / trace-log 字段 / 新增 G10 self-check 断言）为主。

| # | 来源 | 概念 | 落地点 | 类型 |
|---|---|---|---|---|
| 3.1 | gsd-core v1.8.0 | reversibility 分级 | `references/decision-governance.md` §2.4 + `decisions.jsonl` schema + `trace-log.sh` | 方法论 |
| 3.2 | gsd-core v1.8.0 | broken-windows ledger | `references/gsd-patterns.md` + `state-machine.sh` archive guard warn 分支 | 方法论 + warn 增强 |
| 3.3 | graphify v0.9.27 | honest-edge provenance（EXTRACTED/INFERRED/AMBIGUOUS）| `assets/trace-log.sh` confidence 字段 + `references/memory-persistence.md` | 方法论 + 字段扩展 |
| 3.4 | superpowers v6.2.0 | resume-based 5 轮熔断修复环 + scoped re-review | `references/subagent-orchestration.md` | 方法论 |
| 3.5 | superpowers v6.2.0 | 可证伪性 + Mutation Check | `references/review-methodology.md` | 方法论 |
| 3.6 | claude-mem v13.12.x | version oracle 单源真值 | `scripts/self-check.sh` G10 + `assets/facts.conf` `FACT_VERSION_ORACLE_RULE` | self-check 断言 |

**未落地但留作后续候选**（证据已记录，待预算或需求触发）：
- ruflo witness-attested 门禁（需新 check_*，超预算，待决策 26 修订）
- ruflo `node -e` 跨平台 hook bootstrap（待 hooks 实装时落地）
- graphify strict PreToolUse "deny-then-downgrade" hook 模型（待 hook 机制扩展）
- gsd-core multi-signal fix-acceptance 护栏（需新 check_*，超预算）
- ocr 四层规则优先级链（待 review 门禁重构）
- claude-mem 两车道同步模式（待多设备同步需求）

### 4. 验证

- 升级后各运行时 `git describe --tags --abbrev=0` 已对齐目标版本（见 §1 表）。
- graphify `git merge-base v0.9.19 v0.9.27 = v0.9.19`，确认线性路径（非异源 v1.0.0）。
- 整合落地不新增 `check_*` 函数，`FACT_GATES_TOTAL` 保持 54 ≤ `FACT_GATES_BUDGET` 54（G9 守住）。
- 新增 `FACT_VERSION_ORACLE_RULE` 是 `facts.conf` 变量（非 `precheck.conf` 变量），不计入 `FACT_CONF_VARS=169`。
- 落地验证见 self-check.sh G10 + shellcheck + bash -n + fixture 抽跑。


### A11. 运行时升级 2026-08

> 2026-08 运行时升级差异报告。（历史原文，不再单独维护）

> 触发：user message「更新所有运行时依赖及环境版本到最新版，分析与上次之间的版本差异，消化吸收融合其功能优势」
> 数据来源：GitHub REST API + npm registry（2026-08-21 实测）；sub-agent 调研报告（见 session 上下文）
> 历史轮次：`docs/research/R6-upstream-web.md` §0（2026-07-20）/ §6.6 A10（原 runtime-update-2026-07，2026-07-26）/ 2026-08-14 轮（未单写报告）

### 一、14 上游版本差异速览（基线 → 最新）

| 项目 | 基线 | 最新（2026-08-21） | 跨度 | 动作 |
|------|------|---------------------|------|------|
| openspec | v1.9.0 | **v1.10.0**（2026-08-19） | 1 minor | 升基线 + 吸收 |
| comet | v0.3.9 | 0.4.0-beta.18（2026-08-13） | beta 连发 | **仍观望**（无正式版） |
| GitNexus | npm 1.6.9 | 1.6.9（2026-07-04 停滞） | 无变化 | 保持 license-risk |
| gsd-core | v1.10.0 | **v1.11.0**（2026-08-19 next 分支） | 1 minor | 升基线 + 吸收 |
| claude-mem | v13.15.0 | **v13.15.3**（2026-08-20） | 3 patch | 升基线 + 吸收（watch） |
| ocr | v1.9.2 | **v1.9.8**（2026-08-20） | 6 patch | 升基线 + 吸收 |
| graphify | v0.9.42 | **v0.9.47**（2026-08-19） | 5 patch | 升基线 + 吸收 |
| superpowers | v6.3.0 | v6.3.0（2026-08-12） | 无变化 | 已同步 |
| gstack | v1.60.1.0 | **v1.68.2.0**（2026-08-20 commit 51932ec） | 8 minor | 升基线 + 吸收 |
| ruflo | v3.38.9 | **npm 3.38.12**（release 3.38.9） | 3 patch | 升基线（npm 为准） |
| ECC | v2.1.0 | v2.1.0（2026-07-27） | 无变化 | 已同步 |
| impeccable | v4.0.4 | **skill-v4.1.1**（2026-08-14） | 1 minor | 升基线 + 吸收 |
| codex-security | v0.1.11 | **v0.1.16**（2026-08-20） | 5 patch | 升基线 + 吸收 |
| dsh | rc.8 | rc.8（master=141eb6f 2026-08-19） | 无新版 | 已同步 |
| **claude-code** | v2.1.232（2026-08-13 调研基线） | **v2.1.237**（2026-08-20） | 5 patch | 升基线 + 吸收（R4 补核） |
| **codex-cli** | v0.146.0（2026-08-14 调研基线；本机 0.146.0） | **v0.148.0**（2026-08-18 stable）+ v0.149.0-alpha.4 预告 | 2 stable | 升基线 + 吸收（R4 补核；**破坏性**两处） |

**新增**：dsh（deepseek-harness）+ claude-code + codex-cli 三项入表——表从 13 扩到 16 个运行时。claude-code/codex 是核心安装目标（install.sh 检测），CLI 侧差异单列本文 §6.4 §三。

### 二、可吸收点 → 落地点

按 swarm-yuan 口径分两类：方法论文档（references/）与工程纪律（已有机制对齐强化）。

#### 2.1 openspec v1.10 → `references/review-methodology.md` / spec-template

- **task plan 强制"完成判据"**（test / 命令 / 可观察结果 / 交付物）——"Implement the thing"不再算计划。
  落地：spec-template §3 plan 部分加"完成判据必填"指引；`--verify-completeness` 已有占位符检测，可扩展检 plan 章节是否含完成判据字段（本轮不落地机器执法，仅文档强化）。
- **诊断输出一律走 stderr 不污染 stdout 管道**——与 swarm-yuan 既有 CLI 纪律一致，对齐确认。

#### 2.2 gsd-core v1.11 → `references/gsd-patterns.md` / `references/decision-governance.md`

- **guard 必须能观测自身失败分支**——不可观测的 guard 拒绝注册。落地：gsd-patterns.md 增"guard 可观测性"段；本仓 fail-gate-hook.sh 的 flag 捕获模型天然满足（PostToolUse precheck 退出码 → flag → PreToolUse 读 flag 决策）。
- **STATE.md 盖 commit 戳 + 新鲜度检测**——本仓 `.swarm-yuan-version` 已有 `source_repo` 盖戳；可扩展为 state.yaml 盖 commit 戳（本伦不落地，登记候选）。
- **validator 收敛统一 envelope + owner 分阶段 ratchet**——本仓 trace-log.sh 单 JSONL envelope 已对齐。

#### 2.3 claude-mem v13.15.x → `references/memory-persistence.md`

- **错误信封分类**（cmem.ai gateway `{code,message,action,url,request_id}`；402/quota 耗尽不重试，失败收敛单行日志）。
  落地：memory-persistence.md 增"错误信封分类"段（quota 类不重试 vs 网络瞬断可重试的区分）。
- **session-start 的 observer-health 告警**（observation 停止流入时提示）——本仓 SessionStart hook fingerprint 感知是同构机制，已落地。
- **多界面促销/提示文案单一事实源**（`src/shared/pro-promo.ts`）——本仓 facts.conf 单一事实源机器执法同构，已对齐。

#### 2.4 ocr v1.9.8 → `references/review-methodology.md`

- **JSON/SARIF 输出时 review 进度走 stderr、非 TTY 关颜色**——本仓 precheck.sh `--format json` 已对齐（SARIF 子集结果打印 stdout 末尾，进度走 stderr）。
- **api_key 从命令解析**（`api_key = "!op read ..."` 模式）避免明文落盘——本仓 precheck.conf 无 secret 字段，安全边界已对齐；登记候选供未来 AI 工具集成参考。
- **resume 可信校验 + transition lineage + Ctrl-C 保留 checkpoint**——本仓 state-machine.sh dump-journal/restore-journal 已对齐。

#### 2.5 graphify v0.9.47 → `references/code-graph-tools.md` / `references/memory-persistence.md`

- **no-op 运行产物字节一致 / 不触碰时间戳**（manifest 时间戳 no-op 时不重写，避免假 dirty commit）。
  落地：code-graph-tools.md 增"幂等写入纪律"段；本仓 project-fingerprint.sh `--diff` 无变化时不重写基线文件已对齐。
- **超时二分降级而非整体失败**（文件 chunk 超时二分拆分）——登记候选供未来 inventory-verify 大项目性能优化参考。
- **node id 不变 / 不重键既有图**（破坏性变更零容忍）——本仓 replay 规则不可变原则（WP-R12-D）同构。

#### 2.6 impeccable v4.1 → `references/frontend-design-methodology.md`

- **对抗性 verdict**（多候选先内部比较再呈交；safer/bolder 沿熟悉-大胆轴定向重掷）。
  落地：frontend-design-methodology.md 增"对抗性 verdict"段；本仓 decisions.jsonl `alternatives` 字段已对齐（须列备选）。
- **证据坏则重取证重跑**（截图坏/缺时重拍重跑评审；拒绝假抠图 mask 冒充 cutout）。
  落地：frontend-design-methodology.md 增"证据完整性"段；本仓 inventory-verify `--path-check` HALLUCINATION 阻断同构。

#### 2.7 codex-security v0.1.16 → `references/codex-security-methodology.md`

- **发现 → 外部 tracker 发布 → 关联持久化 → verify-fix 闭环**（Linear 深度集成 + 交互式修复 + 只读 verify-fix）。
  落地：codex-security-methodology.md 增"闭环管线"段；本仓 decisions.jsonl outcome 生命周期（WP-R12-D）+ trace-log.sh --decision 已对齐。
- **bulk-scan 每仓库强制 cost limit**——本仓无 bulk 场景，登记候选。

#### 2.8 gstack v1.68.2 → `references/review-methodology.md` / fail-gate-hook 设计哲学

- **每个 guard 必须可证明会触发（否则删除）**（v1.64.1 净删 24,943 行的 guard 收紧波）。
  落地：review-methodology.md 增"guard 可证伪触发"段；本仓 self-check.sh 各 check_* 函数与 facts.conf 数字机器执法已对齐（facts 漂移即 fail）。
- **issue/PR 关闭附 receipt 证据**（v1.68.0 90 个过期 PR 带证据关闭）——本仓 trace-log.sh + decisions.jsonl 已对齐。
- **fail-closed hooks 三件套**（v1.66.1 content binding）——本仓 fail-gate-hook.sh + integrity-guard.sh + failure-detector.sh 三件套同构，已对齐。

#### 2.9 ruflo 3.38.12 → 不吸收

SynthID-Text 风格的 LLM 文本水印（WASM crate + 浏览器/Deno ESM 入口）是新能力方向，但与 swarm-yuan 运行时无关（本仓无 LLM 文本生成场景）。仅升引用基线到 3.38.12（patch 列车跟随），不吸收。

#### 2.10 Claude Code v2.1.237 → `references/claude-code-capabilities.md`

- **Todo/Task 工具默认移除**（v2.1.233，破坏性）：Opus 4.8 / Sonnet 5 / Fable 5 / Mythos 5 及更新模型上 TaskCreate/TodoWrite 默认不可用（`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 兜底）。
  落地：claude-code-capabilities.md 增"Todo 工具移除与自有链路"注记——本仓目标技能的进度跟踪走 `trace-log.sh`（自有链路，不依赖 CLI Todo 工具），无兼容性风险；生成器提醒 SKILL.md 不依赖 TodoWrite 表述门禁进度。
- **`notify_when_idle` 跨会话通知**（v2.1.236）：本机另一 Claude Code 会话空闲时发一次性通知（opt-in 无轮询）。登记候选：未来"门禁长跑完成后通知主会话"可走官方机制。
- **"Concise" output style**（v2.1.237）：直接给结果跳叙述。与门禁驱动开发契合；生成技能使用文档可推荐。
- **`claude-api` 技能 200k→25k 按需加载**（v2.1.234）：swarm-yuan 的"按需读取引用索引"（WP-P5）同构机制，方向验证（不新增落地）。
- **沙箱通配符 read-deny 防重命名绕过**（v2.1.236）：目标技能 settings.local.json 的 `**/.env` deny 规则更强了（文档注记级吸收）。

#### 2.11 Codex v0.148.0 → `references/codex-methodology.md`

- **hooks 异步命令 + MCP 工具调用**（v0.148）：**重要机会**——precheck 门禁可注册为 Codex hook 而非仅靠 prompt 约定，门禁"执法"在 Codex 侧获得官方强制点。登记候选（下轮评估 hooks.json 的 Codex 等价物）。
- **Agent Plugins 四类目录**（v0.147）：local/personal/workspace/remote——生成技能的分发新通道（打包为 Codex 插件）。登记候选。
- **skill-creator validation 拒绝 TODO 占位符**（v0.148）：本仓 `--verify-completeness` 零占位符检测同构，方向验证。
- **`/export` 会话导出**（v0.148）：门禁验收记录随会话导出留档（契合 ai-process-records 方法论，文档注记级）。
- **破坏性两处**：① v0.147 移除 `codex exec --full-auto` → `--sandbox workspace-write`（本仓生成脚本无 `--full-auto` 引用，无影响；install.sh Codex 检测登记版本下限候选）；② v0.149-alpha 移除技能模型委托（本仓无按子任务指定模型设计，无影响）。

### 三、不吸收清单（显式登记）

| 能力 | 来源 | 不吸收理由 |
|------|------|-----------|
| LLM 文本水印 SynthID-Text | ruflo 3.38.12 | 本仓无 LLM 文本生成场景 |
| Linear 深度集成（直连 API） | codex-security v0.1.13-15 | 本仓不绑定特定 tracker；decisions.jsonl 是本地 JSONL 而非外部 SaaS |
| task plan 完成判据机器执法 | openspec v1.10 | 本仓已有 `--verify-completeness` 占位符检测；完成判据属语义判断，GATE_AI_JUDGMENT 原则下不机械 grep |
| STATE 文件 commit 戳新鲜度检测 | gsd-core v1.11 | 登记候选（下一轮 WP）；本仓 state.yaml 当前由 state-machine.sh 管理，无新鲜度告警需求场景 |
| `.graphifyrc` viz_node_limit 烘焙 | graphify v0.9.47 | 本仓无 graphify 配置文件场景（graphify 是方法论引用层） |

### 四、候选登记（下轮触发条件）

| 候选 | 触发条件 | 预估工作量 |
|------|----------|-----------|
| state.yaml 盖 commit 戳 + 新鲜度检测（gsd-core v1.11） | 用户报"state.yaml 过期导致流程错位" | 小（state-machine.sh status 增 stale 告警） |
| inventory-verify 大项目超时二分降级（graphify v0.9.47） | 用户报"inventory-verify 大项目跑超时" | 中（_enum_count 加 timeout + 二分） |
| plan 完成判据模板字段（openspec v1.10） | 用户反馈"plan 没写怎么算完成" | 小（plan-template.md 加字段 + 文档） |
| api_key 命令解析模式（ocr v1.9.8） | 本仓未来接入 AI 工具需 secret | 小（precheck.conf 加 SECRET_CMD 模式） |
| Codex hooks 注册 precheck 门禁（codex v0.148 hooks 异步命令 + MCP 工具调用） | 下轮适配评估——门禁在 Codex 侧获官方强制点 | 中（调研 Codex hooks.json 等价物 + 生成器支持） |
| Codex Agent Plugins 打包分发（codex v0.147 四类目录） | install.sh 对 Codex 目标增加插件形态选项 | 中（打包脚本 + 目录约定） |
| `notify_when_idle` 门禁长跑通知（claude-code v2.1.236） | 用户需要"门禁跑完通知主会话"场景 | 小（SendMessage 调用脚本） |
| install.sh Codex 版本下限检测（≥0.147，`--full-auto` 已移除） | 下次 install.sh 改动时顺带 | 小（版本比较 + 提示） |

### 五、落地清单（本轮已做）

- [x] §6.4 上游基线（原 docs/upstream-baseline.md）全表更新（13→14 运行时，9 项升基线 + 1 项仍 drifted + 1 项仍 license-risk + 3 项已同步）
- [x] §6.4 §二 关键结论 2026-08-21 重写
- [x] §6.4 §三 comet 观望状态 2026-08-21 重核注记
- [x] §6.4 §WP-Y 处置策略 2026-08-21 更新
- [x] 本报告即 §6.6 A11（原 docs/runtime-update-2026-08.md）
- [ ] `references/review-methodology.md` 吸收 openspec/gsd-core/gstack 三点（下一 WP）
- [ ] `references/memory-persistence.md` 吸收 claude-mem 错误信封分类（下一 WP）
- [ ] `references/code-graph-tools.md` 吸收 graphify 幂等写入纪律（下一 WP）
- [ ] `references/frontend-design-methodology.md` 吸收 impeccable 对抗性 verdict + 证据完整性（下一 WP）
- [ ] `references/codex-security-methodology.md` 吸收 codex-security 闭环管线（下一 WP）
- [ ] `references/gsd-patterns.md` 吸收 gsd-core guard 可观测性（下一 WP）

### 六、验证

- `bash scripts/self-check.sh --check-only` 无 drift warn（除 comet 仍 drifted 为预期）
- 14 个 baseline_status 标记行齐全（13  synced/watch/license-risk + 1 drifted）


### A12. 五维稳定单元

> 稳定单元五维字段定义。（历史原文，不再单独维护）

### 什么是五维字段

特征卡第 11 项"可复用稳定单元"中，每个单元用五个维度完整描述：

| 维度 | 含义 | 作用 |
|------|------|------|
| **签名** | 单元的技术标识（函数名/组件名/类名/接口名） | 精确定位，避免歧义 |
| **路径** | 单元在代码库中的文件位置 | 快速查找，确认存在 |
| **用途** | 单元的功能描述（做什么、解决什么问题） | 理解价值，判断是否可复用 |
| **复用方式** | 如何引用这个单元（import/alias/注册/API 调用） | 指导编码，避免错误引用 |
| **稳定性标注** | 单元的稳定性等级（核心稳定/可演进/实验性） | 评估风险，决定是否依赖 |

---

### 真实项目示例

#### 示例 1: Vue 组件

**签名**: `CockpitWorkspace`

**路径**: `custom/client/cockpit/components/CockpitWorkspace.vue`

**用途**: 
- Cockpit 主工作区容器组件
- 整合看板、聊天、文件面板、协作图谱四大功能区
- 提供三段联动式布局（全貌→聚焦→处理）
- 管理用户决策流（WorkDecision）和任务状态

**复用方式**:
```typescript
// 在 registries/client/bootstrap.ts 中注册
import('./../custom/client/cockpit').then(({ registerCockpit }) => registerCockpit(app))

// 在其他组件中引用
import CockpitWorkspace from '@/custom/cockpit/components/CockpitWorkspace.vue'
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 位于 cockpit 模块顶层，被多个子组件依赖
- 接口稳定（props/emit 未变）
- 测试覆盖完整（cockpit-store.test.ts）
- 禁止侵入式重构

---

#### 示例 2: TS 函数

**签名**: `isGatewayNotice(content: unknown): boolean`

**路径**: `custom/client/chat/gateway-notice.ts`

**用途**:
- 判断文本是否为网关关闭/重启告警
- 识别 swarm-agent gateway 推送的系统事件消息
- 命中后由 chat store 打 `systemType: 'gateway'` 标记
- 渲染层据此折叠为紧凑系统提示

**复用方式**:
```typescript
// 在 chat store 中调用
import { isGatewayNotice } from '@/custom/chat/gateway-notice'

if (isGatewayNotice(message.content)) {
  message.systemType = 'gateway'
}
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 纯函数，无副作用
- 正则模式稳定（`/^⚠️\s*Gateway\s+(shutting down|restarting)\b/i`）
- 被 vitest 单测覆盖
- 可安全依赖

---

#### 示例 3: Pinia Store

**签名**: `useCockpitStore()`

**路径**: `custom/client/cockpit/store/cockpit.ts`

**用途**:
- Cockpit 全局状态管理
- 整合看板（kanban）、聊天（chat）、Matrix 客户端状态
- 提供任务搜索、注意力管理、协作图谱、历史记录、通知等功能
- 管理用户待办（UserTodo）和租户过滤

**复用方式**:
```typescript
// 在组件中调用
import { useCockpitStore } from '@/custom/cockpit/store/cockpit'

const cockpitStore = useCockpitStore()
const tasks = cockpitStore.filteredTasks
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 被 CockpitWorkspace 等多个组件依赖
- 接口稳定（computed/ref 未变）
- 测试覆盖（cockpit-store.test.ts）
- 禁止修改签名（新增字段可以，改字段不行）

---

#### 示例 4: API 接口

**签名**: `kanbanApi.getTasks(params: KanbanTaskQuery): Promise<KanbanTask[]>`

**路径**: `custom/client/cockpit/api/kanban-extras.ts`

**用途**:
- 获取看板任务列表
- 支持分页、过滤、排序
- 返回标准化的 KanbanTask 类型

**复用方式**:
```typescript
// 在 store 或组件中调用
import * as kanbanApi from '@/custom/cockpit/api/kanban-extras'

const tasks = await kanbanApi.getTasks({ status: 'open', limit: 50 })
```

**稳定性标注**: **可演进** ⭐⭐
- 接口参数可能扩展（新增过滤条件）
- 返回类型稳定（KanbanTask 未变）
- 调用方需处理分页逻辑
- 可依赖，但需关注版本变更

---

#### 示例 5: 适配器（Adapter）

**签名**: `taskAdapter.mapToViewModel(task: KanbanTask): TaskViewModel`

**路径**: `custom/client/cockpit/adapters/task-adapter.ts`

**用途**:
- 将后端 KanbanTask 转换为前端 TaskViewModel
- 处理字段映射、默认值、计算属性
- 解耦后端 API 与前端渲染

**复用方式**:
```typescript
// 在 store 中调用
import * as taskAdapter from '@/custom/cockpit/adapters/task-adapter'

const viewModel = taskAdapter.mapToViewModel(rawTask)
```

**稳定性标注**: **可演进** ⭐⭐
- 映射逻辑可能随后端字段变化
- 接口稳定（mapToViewModel 签名未变）
- 被 cockpit-store 依赖
- 可依赖，但需关注后端变更

---

### 五维字段的作用

#### 1. 签名：精确定位

- **避免歧义**：`useCockpitStore` vs `useKanbanStore` 是两个不同的 store
- **支持搜索**：IDE 可快速跳转到定义
- **支持重构**：重命名时全局替换

#### 2. 路径：快速查找

- **确认存在**：`custom/client/cockpit/store/cockpit.ts` 确实存在
- **理解结构**：路径反映模块划分（cockpit/store/ vs cockpit/components/）
- **支持导航**：点击路径直接打开文件

#### 3. 用途：理解价值

- **判断复用**：这个单元解决什么问题？我的需求是否匹配？
- **避免重复**：已有 `isGatewayNotice` 就不需要再写一个
- **指导设计**：新单元应该放在哪里？如何命名？

#### 4. 复用方式：指导编码

- **正确引用**：`import { useCockpitStore } from '@/custom/cockpit/store/cockpit'`
- **避免错误**：不要用 `@/stores/hermes/cockpit`（路径错误）
- **支持注册**：在 bootstrap.ts 中注册组件

#### 5. 稳定性标注：评估风险

- **核心稳定** ⭐⭐⭐：可安全依赖，禁止侵入式重构
- **可演进** ⭐⭐：可依赖，但需关注版本变更
- **实验性** ⭐：谨慎依赖，可能大幅变更

---

### 特征卡第 11 项的完整示例

```markdown
## 11. 可复用稳定单元清单

### 组件库

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| CockpitWorkspace | custom/client/cockpit/components/CockpitWorkspace.vue | 主工作区容器 | import + registerCockpit | ⭐⭐⭐ 核心稳定 |
| CockpitKanban | custom/client/cockpit/components/CockpitKanban.vue | 看板面板 | import | ⭐⭐⭐ 核心稳定 |
| CockpitChatPane | custom/client/cockpit/components/CockpitChatPane.vue | 聊天面板 | import | ⭐⭐⭐ 核心稳定 |
| GatewayNoticeBanner | custom/client/chat/components/GatewayNoticeBanner.vue | 网关通知横幅 | import | ⭐⭐⭐ 核心稳定 |

### 函数库

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| isGatewayNotice | custom/client/chat/gateway-notice.ts | 判断网关告警 | import | ⭐⭐⭐ 核心稳定 |
| renderMarkdown | custom/client/cockpit/components/CockpitWorkspace.vue | Markdown 渲染 | 组件内使用 | ⭐⭐ 可演进 |

### Store

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| useCockpitStore | custom/client/cockpit/store/cockpit.ts | Cockpit 全局状态 | import + 调用 | ⭐⭐⭐ 核心稳定 |
| useKanbanStore | custom/client/kanban/store/kanban.ts | 看板状态 | import + 调用 | ⭐⭐⭐ 核心稳定 |

### API

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| kanbanApi.getTasks | custom/client/cockpit/api/kanban-extras.ts | 获取看板任务 | import + 调用 | ⭐⭐ 可演进 |

### 适配器

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| taskAdapter.mapToViewModel | custom/client/cockpit/adapters/task-adapter.ts | 任务数据转换 | import + 调用 | ⭐⭐ 可演进 |
```

---

### 五维字段在门禁中的应用

#### `--reuse` 门禁

检测新增单元是否与既有单元重名：

```bash
# 检查新增的 isGatewayNotice 是否与既有单元重名
grep -r "export function isGatewayNotice" custom/
# 如果找到多个定义 → fail（重复造轮子）
```

#### `--stable-diff` 门禁

检测稳定层是否被改而未声明：

```bash
# 检查 STABLE_GLOBS 指定的稳定单元是否被修改
git diff custom/client/cockpit/store/cockpit.ts
# 如果有改动但 spec §3 未声明 MODIFIED → fail
```

#### `--layer` 门禁

检测依赖方向是否违反分层规则：

```bash
# 检查 domain 层是否导入了 presentation 层
grep "import.*from.*components" custom/client/cockpit/store/cockpit.ts
# 如果 store 导入了 components → fail（依赖倒置）
```

---

### 总结

五维字段是特征卡第 11 项的核心——它完整描述了每个可复用稳定单元的技术标识、位置、功能、引用方式和稳定性。

**特征卡是立法，门禁是执法。** 五维字段定义了"哪些单元可以复用、如何复用"，`--reuse` / `--stable-diff` / `--layer` 门禁验证"代码是否遵守这些规则"。


### A13. 宣传文案

> 对外宣传口径（历史版本）。（历史原文，不再单独维护）

**从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施**

一句话摘要：swarm-yuan 为你的项目生成专属技能（目标技能）——它用 17 项特征卡让 AI 认识你的项目，用 55 个质量门禁守护代码合规——特征卡是立法，门禁是执法，两者构成从认知到交付的完整闭环。
（边界声明：门禁外部有效性目前在 Java/JS Web 品类上验证（R9），跨品类见 `verifier/v2/external-validity.md` 立项稿。）

> **口径权威源**：`assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

---

### 一、为什么「AI 写代码」已经不够了？

大模型普及两年，几乎每个开发者都在用 AI 写代码。但当我们审视真实的生产现场，会发现一个尴尬的事实：

**AI 的代码生成能力已被充分释放，但项目认知几乎为零。**

#### 三个结构性瓶颈

**瓶颈 1：AI 不知道你的项目规则。** AI 不知道哪些目录不能改、依赖版本不能升级、哪些组件可以复用。产出的代码经常违反项目规则。

**瓶颈 2：AI 不懂你的领域。** 密码必须哈希、SQL 必须参数化、消息有时序性——这些是客观规律，违反就是硬伤。AI 不知道。

**瓶颈 3：检查靠人工，过程不可见。** 没有自动化检查就没有信任，没有信任就只能逐行人工 review。

**核心论断：AI 的代码生成能力已经很强，但「项目认知」——对项目规则、结构、领域知识、可复用单元的理解——还停留在零。**

---

### 二、swarm-yuan 的关键设计理念

#### 理念一：先认识，再行动

AI 写代码前必须先认识项目。swarm-yuan 生成的目标技能用 **17 项特征卡** 完成认知，用 **55 个质量门禁** 守护行动。不认识就写 = 盲动。

#### 理念二：拼装式开发

新功能 = 既有稳定单元的拼装 + 最小新增胶水代码。三条禁止：禁止重复造轮子、禁止侵入式重构、禁止破坏性改造。特征卡第 11 项盘点全部可复用单元，门禁 `--reuse` 验证复用合规。

#### 理念三：呈现递进的关系，而非仅关注计算

门禁不是"数 import 数"——每个计数背后指向一条关系规律。`--layer` 数 import 是为了验证"结构是否遵循依赖单向"；`--reuse` 数新增导出是为了验证"概念是否复用了既存稳定单元"。

#### 理念四：特征卡是立法，门禁是执法

> 📌 **隐喻边界**：三权分立为教学类比，非政治学严格对应--门禁无法律普遍约束力，verifier/v1 与门禁同仓库同 CI、无司法独立裁量权。详见本文 §1.2 与 §2.3。

17 项特征卡定义「项目应该是什么样的」，55 个门禁验证「代码是否符合」。两者构成闭环——特征卡驱动门禁配置，门禁验证特征卡定义的规则。**门禁还按执法强度分三档（决策 19）**：strict 17（真 fail 阻断）/ warn 22（混合）/ advisory 16（永不 fail，观测类）——让"门禁是执法"不再是一句宣称，而是机器可核验的分层。

---

### 三、17 项特征卡：项目的「认知 DNA」

#### 什么是特征卡

特征卡是 AI 探查项目后提取的 **17 项项目特征**，每项落到真实路径和版本号，不用占位符。它不是独立文件，而是**分散承接进目标技能的各个文件中**，是门禁配置和文件填充的「数据源」。

**没有特征卡，门禁就是无源之水——不知道项目边界在哪、哪些单元稳定、什么领域规律不能违反。**

#### 17 项特征卡

| # | 特征项 | AI 提取什么 | 为什么重要 |
|---|--------|-----------|-----------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | 决定探查策略和门禁方向 |
| 2 | **可改范围** | 可改目录 + 只读目录 + 只读区修改机制 | **安全铁律依据**——改了只读区 = 违规 |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) | **决定代码怎么写** |
| 4 | 技术栈 | 语言+框架+构建+测试（含版本基线） | 版本锁定依据，`--deps` 对比基线 |
| 5 | **构建命令** | dev/build/test/release 真实命令 | **门禁执行基础**——`--build` `--test` 跑这些 |
| 6 | 分支规范 | 命名/合入/保护分支/推送 | `--branch` 校验规则 |
| 7 | 安全规则 | 脱敏/密钥/白名单 | `--sensitive` `--security` 扫描范围 |
| 8 | 文档约定 | spec/plan 位置和命名 | spec 文件路径 |
| 9 | 测试体系 | 框架/目录/命令 | `--test` 执行命令 |
| 10 | 环境资源 | 运行时/DB/缓存/MQ/MCP | `--service` 配置 |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（五维字段定义见 `references/exploration-guide.md` §11f） | **拼装式开发核心依据**——`--reuse` 重名检测源 |
| 12 | 数据规范 | schema/样例/业务规则/勾稽 | `--consistency` 核对项 |
| 13 | 认知框架 | 认知映射表 + 六维动力学基线 | `--cognition` 对比基线 |
| 14 | **领域知识** | 技术+业务领域 → 推导客观规律 | **防达克效应**——`--domain` 违规检测 |

**第 11 项是核心中的核心。** AI 用 graphify `query` / gitnexus `context` 系统性盘点全部稳定单元（GitNexus 因 PolyForm Noncommercial 禁商用降级为非默认，graphify（MIT）提为默认代码图谱工具）——不是随机 grep，而是基于代码图谱的 360 度上下文查询。每个单元记录五维字段（定义见 `references/exploration-guide.md` §11f）。

#### 特征卡如何驱动一切

**→ 文件填充：** SKILL.md 铁律 ← 第 2/6 项 → codebase.md 技术栈 ← 第 4 项 → dev-guide.md 改造分类 ← 第 3 项 → reference-manual.md 组件库 ← 第 11 项 → release.md 命令 ← 第 5 项……

**→ 门禁配置：** precheck.conf 三件套 178 个变量（core 18 + arch 112 + compliance 48）从特征卡推导——WRITABLE_DIRS ← 第 2 项、TEST_CMD ← 第 5 项、LAYER_DEFS ← 第 3 项、STABLE_GLOBS ← 第 11 项、SERVICE_DIRS ← 第 10 项……

**→ 开发流程：** 开始新需求时 AI 从第 11 项检索可复用单元 → 预填 spec §5.5 → 编码时查第 11 项组件库拼装优先 → 提交前 55 个门禁按特征卡规则检查。

#### 落地示例（SwarmStudio overlay）

| # | 真实值 |
|---|--------|
| 1 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 5 | `npm run dev`(:8649) / `npm test` / `npm run inject` |
| 11 | CockpitWorkspace / CockpitKanban / GatewayNoticeBanner 等 15+ 组件 |
| 14 | IM 通讯（Matrix 协议）+ DevOps 监控 |

---

### 四、55 个质量门禁：特征卡的守卫者

#### 门禁与特征卡的关系

**特征卡是立法，门禁是执法。**

| 特征卡项（立法） | 门禁（执法） |
|----------------|-------------|
| 第 2 项：overlay/ 可改，upstream/ 只读 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项：`npm run build` | `--build` 运行此命令，非零 = fail |
| 第 6 项：feat/fix/refactor | `--branch` 校验分支名是否匹配正则 |
| 第 7 项：密钥不入代码库 | `--sensitive` `--security` grep 扫描密钥模式 |
| 第 11 项：CockpitWorkspace 等稳定单元 | `--reuse` 检测新增单元是否与既有重名 |
| 第 11 项：STABLE_GLOBS 指定的稳定层 | `--stable-diff` 检测稳定层被改而未声明 |
| 第 14 项：密码必须哈希 | `--domain` grep 检测密码明文存储 |

#### 核心门禁（`--all`，10 个，通常 10-20 秒）

| 门禁 | 检查什么 | fail 条件 |
|------|---------|----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 |
| `--scope` | 改动范围 | 只读目录有改动 |
| `--build` | 构建通过 | 构建失败 |
| `--sensitive` | 敏感信息 | 密码/密钥明文 |
| `--review` | 代码审查（5 维度） | ocr 检测到 High |
| `--reuse` | 复用合规 | spec 缺 §5.5 / 新增单元与既有重名 |
| `--deps` | 依赖锁定 | 版本变更但 spec 未声明 |
| `--security` | OWASP Top 10 | 注入/XSS/eval/硬编码密钥 |
| `--test` | 测试通过 | 测试失败 |
| `--consistency` | 业务规则 + 勾稽 | 人工核对项 |

#### 架构门禁（`--all-full`，17 个，通常 15-40 秒，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | 第 3 项 |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | 第 11 项 |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | 第 13 项 |
| `--adr` | 架构决策记录（ADR + 技术债登记） | 第 8 项 |
| `--contract` | 接口契约（version + ACL 防腐层） | 第 10 项 |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | 第 12 项 |
| `--impact` | 变更影响分析（消费方反查） | — |
| `--service` | 微服务架构（共享 DB/同步链/网关/trace） | 第 10 项 |
| `--api` | API 契约与幂等（version/幂等键/分布式事务） | 第 10 项 |
| `--state` | 前端状态管理（巨型 store/prop drilling/派生 useState） | 第 11 项 |
| `--frontend` | 前端组件架构（层级/props/循环依赖/CSS 污染） | 第 11 项 |
| `--cognition` | 认知递进体检（六阶+六维+五层总分） | 第 13 项 |
| `--domain` | 领域知识违规检测（密码明文/SQL 拼接/XSS/并发竞态） | 第 14 项 |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 引用） | — |
| `--diagram` | 可视化（mermaid 结构图：架构/流程/调用链 + echarts/antv 数据图：统计/分布/趋势） | — |

#### 合规门禁（17 个，独立 `--compliance-suite` 按需执行，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--compliance` | 标准合规矩阵核验（六锚点 + 零占位符 + spec §22 标准合规段） | 第 8 项 |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档 + TBD 扫描） | 第 8 项 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（启用后 fail-closed） | 第 4 项 |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 第 7 项 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | 第 7 项 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式 fail-closed） | 第 8 项 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 → fail，国密白名单 SM2/SM3/SM4） | 第 7 项 |
| `--rtm` | 需求追溯矩阵（spec REQ- 编号须在测试目录或追溯矩阵可追溯；RTM_MATRIX_REQUIRED=1 时矩阵缺失 fail-closed） | 第 8 项 |
| `--release-sign` | 发布签名与 provenance（产物须带 .sig/.asc/.att/.bundle 伴随签名；cosign verify-blob 验签 + SLSA provenance fail-closed） | 第 5 项 |
| `--dengbao` | 等保 2.0 控制点（DENGBAO_LEVEL 二/三级分级：双因子/审计日志/审计字段/个人信息保护缺口，启用后 fail-closed + 豁免留痕） | 第 7 项 |
| `--pia` | 隐私影响评估（PIA 文档缺失 → fail，启用后 fail-closed） | 第 7 项 |
| `--sast-deep` | 深度 SAST（semgrep→opengrep→内置降级链，启用后 fail-closed） | 第 7 项 |
| `--oss-eval` | 开源代码安全评价（复用 --sbom 产物，成分清单/许可证纳入评价，启用后 fail-closed） | 第 4 项 |

#### 降级策略

每个门禁优先用运行时工具，无则降级：

```
graphify explain（知识图，默认）→ gitnexus trace（代码图谱，仅非商用场景）→ madge（依赖树）→ 纯转发统计
ocr review（diff 审查）→ ocr scan（全文件）→ AI 5 维度审查
claude-mem search（记忆库）→ 文件检测
```

**有能力就用，无能力降级——不浪费工具，也不因缺失崩溃。**

---

### 五、五层认知框架：特征卡和门禁的哲学根基

| 层 | 解决什么 | 与特征卡/门禁的关系 |
|----|---------|-------------------|
| 认知递进 | 如何认识项目 | 特征卡 17 项 = 认知递进的产物 |
| 思维语言 | 如何思考 | spec §14-§18 = 思维语言在 spec 中的落地 |
| 认知辩证 | 如何推演+自证伪 | 门禁 `--cognition` = 认知辩证的验证工具 |
| 偏差防范 | 如何纠偏 | spec §16 偏差自检 = 偏差防范的工程落地 |
| 辩证认知 | 如何统一前四层 | 门禁 `--domain` = 辩证认知的违规检测 |

> 门禁不是"数 import 数"——`--layer` 数 import 是为了验证"结构是否遵循依赖单向规律"；`--reuse` 数新增导出是为了验证"概念是否复用了特征卡第 11 项的既存稳定单元"。每个计数背后指向一条关系规律。

---

### 六、13 个运行时 + 32 个领域

**运行时工具**（只引用调用不重新实现）：OpenSpec / superpowers / comet / GitNexus / graphify / gsd-core / claude-mem / ocr / gstack / Ruflo / ECC / impeccable / codex-security

**领域知识速查**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……32 个领域的客观规律。

**铁律：领域规则不得违反通用常识和客观规律。违反就是硬伤。**

---

### 七、Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| ⚡ Hooks | SessionStart 注入状态 + PreToolUse(Write) 检查范围 |
| / Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| 🔌 MCP | 自动注册 gitnexus / claude-mem / graphify |
| 🌊 Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| 🔍 LSP | go-to-definition / find-references |
| 🤖 Subagent | 每任务新 subagent + 两阶段审查 |

---

### 八、零占位符 + 自举

**零占位符：** AI 执行完整 12 步流程后由脚本机器执法（`bash scripts/generate-skill.sh --verify-completeness <skill_dir>`）——零残留才算完成。

**自举：** swarm-yuan 能用自身的 55 个门禁检查自身（CI 三档 RC=0）。**自举只证明内部自洽，不证明外部有效**--详见 README.md §自举（S17 去重：此处不再重复完整论证，PROMO 仅声明要点，完整诚实声明在 README）。

---

### 九、一键安装，兼容 7 个 AI 工具

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi——自动检测，安装到对应目录。

---

### 数字一览

| 维度 | 数值 |
|------|------|
| **特征卡** | **17 项（驱动全部文件 + 184 个门禁变量 + 开发流程）** |
| **质量门禁** | **55 个（核心 10 + 架构 18 + 合规 19 + FULL-only 2 + advisory-only 6，特征卡立法 + 门禁执法）** |
| 运行时工具 | 13 |
| 领域知识 | 32 个领域 |
| 认知框架 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |
| 自举 | ✅ |

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**使用说明**：本文 §6.5（原 USAGE）

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 生成的目标技能用 17 项特征卡让 AI 先懂你的项目，用 55 个质量门禁守护代码合规——特征卡是立法，门禁是执法。


## 6.7 调研证据链

> `docs/research/` 保留 16 份调研报告（R1-R15）——它们是决策史引用的外部项目调研过程档案（对象是外部项目而非本系统设计），按"证据链不整合、指针可达"原则保留在仓库中。

---

## License

MIT — see [LICENSE](../LICENSE)

# Changelog

All notable changes to swarm-yuan are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes per version are also available at [GitHub Releases](https://github.com/issac-new/Swarm-yuan/releases).

## [v2.11.0] - 2026-09-10

> 审计收账轮（决策 38）+ R22 运行时补核。按用户级 AGENTS.md 规则全面排查：代码与验证体系实测全绿，23+4 项裂缝全部集中在文档与口径层，本轮全修并为其中两类（版本口径、认知面预算）建立机器执法。

### Added
- **版本口径三面机器锚（决策 38 决定一）**：self-check 文档一致性段新增第 6 项断言——CHANGELOG 首行版本 = 根 README badge = 技能 README badge，漂移即 warn + FAIL；安装态（无 CHANGELOG.md）显式跳过。根治 v2.8.0 起四次发版漏改根 badge 的过程根因（旧 checklist 未指明哪份 README）；CONTRIBUTING 发版步骤同步指明两处 badge。
- **认知面预算例外登记（决策 38 决定二）**：FACT_ARTIFACT_BYTES_BUDGET 262144→266336（+4KiB）。实测超 35B 的成因考证为修复两处静默失效的必要税（standards-map.conf 补随发、framework-globs.rules 补随发），非内容膨胀；例外不构成先例，下次超标仍须逐例登记。

### Fixed
- usage-manual 结构修复：尾部节号 8/9/10 双轮与层级混用消除（术语区无号化，§1-§9 连续）；§9 流程并入 §6 全旅程速查；§10 数字一览指针化到 README 附录 A（速览表单一事实源）；6 处悬空指针清零（决策史/设计内核/§5.1/map.md/调研范围/自指行）；头部过程性标记删除。
- 手抄数字漂移五处：184 变量族（178→184 + 三件套分解）、门禁分层静态 17/22/16 + 有效 17/17/21（55 名单表三度漂移后删除，改 `--list-gates` 实查）、架构门禁表补 method-size/shift-left/framework 三行（17→18）、合规门禁表补 cert-audit/cwe-audit 两行（17→19）、precheck.sh 三处内注释 27(10+17)→28(10+18)。
- 版本口径三面失同步：根 README badge v2.7.0→v2.10.1（四次漏改）；SECURITY.md v2.6.1 锚定改指 CHANGELOG/Releases（去版本号免再漂移）。
- facts.conf 还账：FACT_SCRIPT_LOC 6291→6315（self-check warn 执法再次实证）；FACT_UNIVERSAL_FILES 注释考古链补段（5170a0a 61→65 改值未改链）。
- 生成器模板去污染：`.claude/commands/swarm-yuan.md` 删 hermes-agent 项目特定路径，泛化为「只读上游快照区按 AGENTS.md 声明」；jest-vitest.md ncwk 契约条目改通用规律先行 + 实例锚点后置（五要素与 verify 块不变）。
- 次口径：CLAUDE.md 生成器侧行数 ~68K→~74K；capabilities 版本注记头部同步至 v2.1.267；baseline「159 版」与 capabilities「223 版」表观矛盾消除（改指首行计数口径）；根 tests/ 空壳目录清理。

### Changed
- R22 运行时基线补核：claude-code v2.1.267（maxEffortLevel 治理原语 + prompt-cache 工具动态性族 + managed fail-closed 第四实证）、codex rust-v0.154.0（实验性 worktree 支持 + inline 追问 + plugin/skill 热刷新）、dsh 0.1.5-rc.1、openspec 1.13.0（delta parser 不再静默改写）等九行；档案 `docs/research/R22-runtime-refresh.md`。

## [v2.10.1] - 2026-09-09

### Added
- quality:full 十步模式吸收（决策 37 追记）：workflow 节点⑥增「质量门禁序列」指引——十步串行建议（build→test→contract→reuse→consistency→layer/link-depth→docs-pack→security→deps）+ fail-fast 语义（任一步 fail 即停）+ 全部映射 precheck 既有 flag 不新增门禁；节点⑦审查范围扩到序列运行证据（gate-runs.jsonl 当次 run 记录）；commands/precheck.md 增常用序列建议

## [v2.10.0] - 2026-09-09

> R21 核心链条补强轮（决策 37）：对照用户核心思路链条十环全面复盘——①②③④⑨⑩六环已实现有测试背书，本轮补齐四个真缺口并修复一个升级丢数据缺陷。核心思路不变，能力沿链条补强。

### Added
- **任务配方层（⑤+③）**：目标技能新增 `references/recipes.md`（项目特定文件）——§A 业务功能清单（功能→入口→复用组件→接口→数据→测试编目）+ §B 任务配方五要素（触发场景/前置查询/复用件/胶水/门禁与验证）；探查方法论新增 §C+.6 业务功能盘点 / §C+.7 配方提取（三源：既有实现/git 同类任务历史/开发者文档）；verify-completeness 五要素结构执法 + inventory-verify path-check 扩展核验配方引用复用件；standard/compliance 档生成，lite 不生成
- **开发者行为吸收（⑥）**：新增 `scripts/mine-habits.sh` 六维机械统计（提交前缀/分支命名/提交规模分桶/共变文件对/热点文件/测试提交占比）→ `.swarm-yuan/notes/habits.md` 初稿，AI 审读三去向（SKILL.md 铁律引用 / dev-guide 开发偏好节 / reference-manual 注意事项+配方佐证）；dev-guide 骨架固定「开发偏好」节（无来源写"暂无已记录偏好"诚实降级，节存在性执法）；配套 test-mine-habits.sh
- **关系边集（①）**：新增 `scripts/relations-extract.sh` 机械 import 边提取（TS/JS/Vue 相对说明符扩展名/index 解析、py 相对导入、go module 剥离、java 包路径映射，零外部依赖）→ `references/relations.jsonl`；--stable-diff 1 跳下游传播优先读边集（精确于 basename grep 启发式）；--mark-active 抽样核验断边（advisory）；配套 test-relations-extract.sh 四态
- **验证资产化（⑨）**：inventory-dimensions 新增 DIM_TESTFILES 测试文件维度（测试资产一等清单对象，锚 §测试案例）；check_test 未配置 TEST_CMD 且探到测试文件 → 显式 warn（消除静默跳过；enforce 档不动零 FACT 涟漪）+ gate-fixture compliant-unconfigured 回归锁
- **问题驱动沉淀通道（⑩）**：生成的目标技能 SKILL.md 自成长段增第⑤环——使用中解决的新问题三选一沉淀（inventory-update 入清单 / recipes.md 加配方或注意事项 / gate-rules --persist 入规则）+ trace-log --decision 留痕；成长触发从"结构变化"单通道扩为"结构+问题"双通道
- **项目 rules.d 探查期生成（②）**：generation-flow Step 8 从编排约束+只读判定推导项目特有三值规则初稿（求值器消费已存在，零新机制）
- 生成器 SKILL.md 概念↔实物追踪表 +4 行（任务配方/开发偏好/关系边集/问题沉淀）；README/usage-manual/design-evolution 四载体同步；决策 37 登记

### Fixed
- **--upgrade 覆盖丢失已填充模板**：snippets.md / mcp-tools.md 属 UNIVERSAL_FILES（升级即覆盖）但 Step 7 要求 AI 填入项目实际内容——新增 USER_FILLABLE_FILES 守卫（已非占位骨架则跳过覆盖并提示），gen-e2e 回归锁
- inventory-verify `_list_count` 锚定支持中文节名锚（index() 固定串四形态匹配，BSD awk 字节类坑规避）

## [v2.9.0] - 2026-09-09

### Added
- R19 四论合一方法论：`references/four-theories-methodology.md`（由 engineering-cybernetics-methodology 扩为四论闭环单载体并改名）——总纲四元框架表 + 系统论/信息论两篇新增，控制论十律原位保留；FACT_REFERENCES 42 守恒

### Changed
- 去教条化轮（design-evolution 决策 36"恰当应用"）：dsh-engineering-methodology §七/§八 版本注记压缩为指针（操作原则各留一句，细节留 refresh 调研档）——止住上游发布节奏驱动本仓文档膨胀；upstream-baseline 补执行纪律（patch 零增量不登记/同日复核废止/细节留调研档），R16-R18 四段口径注各压一行
- four-theories-methodology 同标准手术（决策 36 追记）：机制对照表一/二与落地桥表删除（纯重命名/判据全为既有断言复写），十律编号与权威叙事框架退场、五篇内容平实化保留，系统论七手段对账表改写为结构七问检查单；文档 197→156 行，四论框架与 R18 一手复核成果保留

### Fixed
- gate-trends 恒零清单 → 零拦截清单名副其实化：原实现测"零执行"却自称"恒零拦截"，窗口口径与 N 无关且恒零集由运行档位结构性决定；修正为"窗口内全 pass（零 fail 零 warn）= 从未发现问题"语义（warn 档按设计不阻断、全 skip 沉睡信号归 adaptive-gating，均不入列）；新增 `tests/test-gate-trends.sh` 钉死四态语义并接 CI；four-theories-methodology 7 处"恒零"表述同步咬合
- README §7 指标 10 改双信号：gate-trends 零拦截清单（零拦截）+ adaptive-gating 活跃度报告（沉睡）
- SKILL.md 第六层标题粘连修复（`## 第六层 引用## 第六层 引用`）；README 调研报告计数 18→22、历史档案索引 A1-A14→A1-A16

## [v2.8.0] - 2026-09-07

### Added
- R17 工程控制论方法论吸收：`references/engineering-cybernetics-methodology.md`——五条系统设计纪律 + 机制对照表（FACT_REFERENCES 41→42）
- R18《控制论与科学方法论》认知方法论吸收：控制论文档扩为上下两篇十律；同日原书 PDF OCR 一手复核（tesseract chi_sim 243 页扫描件）四律确认 + 三处精化（控制能力连乘/范围控制律/可观察可控制变量对）
- R17-ops 五律操作化：gate-trends 恒零清单 + 十条律落地桥表

### Changed
- R17/R18 运行时补核两轮：claude-code v2.1.263 / codex rust-v0.153.4 / dsh v0.1.2-rc.1 升基线 + 外围九行；upstream-baseline 16 行全量重核

（注：v2.9.0 决策 36 轮对本版的恒零清单与十律文档形态做了纠正，见上。）

## [v2.7.0] - 2026-09-05

### Added
- SECURITY.md / CONTRIBUTING.md（企业级标准合规：漏洞报告流程与响应时限 + worktree 纪律 + commit 规范 + PR/Release 流程）
- docs/ 三档案物化：`docs/design-evolution.md`（决策史全文 + 历史档案 A1-A15）/ `docs/upstream-baseline.md`（16 运行时许可证/版本/drift 供应链机器锚）/ `docs/usage-manual.md`
- R16/R17 运行时升级调研档：`docs/research/R16-runtime-refresh.md`（全量 16 运行时）+ `docs/research/R17-runtime-refresh.md`（三件套补核 + 外围九项）

### Changed
- README 终态重构（骨架三层分离→决策蒸馏→公文笔法→四问主轴→全局概念统一→费曼两轮）：收敛为纯设计内核（只答"现在是什么/为什么这样设计"，零历史零理论），过程内容物化 docs/ 三档案
- R16 全量 16 运行时重核：11 项升基线吸收（八份 references 补核段）——gsd-core state.json 状态契约 + `<fails_when>` 强制验收失败信号、claude-mem 配额熔断器四规则 + 观察者 SILENT/NO CONTACT 契约、ocr 语义文件分组审查 + 跨 session findings 非行号匹配、gstack spawned 会话原语 + wiring 层 fail-open 案、ECC Plan Canvas 监听纪律、codex-security assess-patch-risk 五值裁决候选等
- R17 三件套补核：claude-code v2.1.261（`--permission-prompts none` 无头执法档 + 宿主 deny 语义漂移警示 + `/skill-doctor` 成本审计 + 提示词外置第四次验证）、codex rust-v0.153.4（Guardian 条件性兜底 + `request_user_input_async` 回合中结构化问答 + hooks 三层信任）、dsh v0.1.2-rc.1（跨版本读兼容三件套 + 删 SQLite 后端迁移纪律 + `<domain>/<reason>` 失败词表 + Agent Teams 孵化围栏 → dsh-engineering-methodology §八）；确立**宿主治理层条件性**教义——宿主 deny/审批层版本间不保证在场，执法确定性锚自持 55 门禁
- upstream-baseline 16 行基线全量重核（claude-code v2.1.261 / codex rust-v0.153.4 / dsh v0.1.2-rc.1 / openspec v1.12.0 / claude-mem v13.24.0 / ocr v1.11.4 / ruflo v3.38.21 / codex-security v0.1.25；comet 0.4.0-rc.4 仍观望 / GitNexus v1.6.11 stable 但 license-risk 不变）

### Fixed
- 决策 27 门禁预算 54→55 规范层三处对齐决策 26.2 追认值（历史决策记录保留原值）
- codex-security-methodology FACT_REFERENCES 34→41、code-graph-tools graphify 许可证 MIT→Apache-2.0 数字/事实裂缝
- R17 版本注记段瘦身：生成物认知面 264873B→261993B 回到 262144B 预算内（R13 税制断言；机制与意义留 references，全量细节在 docs/upstream-baseline.md §3.5 与 R17 调研档）

## [v2.6.1] - 2026-08-28

### Changed
- README 终态准确化：回归收口元描述 + 双宿主硬化表述 + 平台兼容显式段 + 运行时三层真执行实证口径 + 质量基线验证矩阵（fixtures 79 / gate-fixture 48 / cli-ab 逐字节 0 / 双重点栈九节点真实交付）

### Fixed
- test-conf-render 8 处 `echo|grep -q` 改 here-string——消 pipefail 下 SIGPIPE write error 噪音（ubuntu runner 首跑 flaky 实证驱动）

## [v2.6] - 2026-08-27

### Added
- **双宿主整合完整化**：Codex hooks.json 嵌套 schema 对源码逐字段核验（R11 #23）、命令绝对路径部署（#24）、旧扁平文件自动升级重写；Claude Code 侧 generate-skill.sh 转发垫片（#25，UNIVERSAL_FILES 计数 59→61 同步机器锚）
- **运行时全量接线实证**：13 个外部运行时（深度 4 + CLI 4 + 方法论 5）全部真执行抽检——graphify 建图谱→god-nodes 检出、claude-mem worker+search 命中、gsd-tools validate health 实跑、comet init/status 实跑；降级链辅助工具（syft/cdxgen/madge）全装齐
- **复杂度预算追认**：决策 26.2 门禁预算 54→55（check_method_size 入编），self-check 首次 RC=0 全绿

### Changed
- graphify god-nodes 从 gitnexus elif 遮蔽中解放为并行正交（#22，检测面正交不互斥）；降级 grep 补 java/vue include
- codex-security 接线 flag `--json`→`--format json`（#26，0.1.21 真源 CLI 核验）

### Fixed
- R6-R12 十一轮回归累计 28 项修复全部落库（#1-#28，每项带 fixture/测试/实证锁死）
- 文档零旧口径残留（DESIGN/case-studies/README 数字全部与 facts.conf 机器真值对账）
- 双重点栈（RuoYi 前 vue+element、后 SpringBoot+MySQL）九节点真实交付验证（jar 90MB 零错）

## [v2.5] - 2026-08-21

### Added
- R16 本体论驱动重构：显式类型层（assets/ontology/ 三目录=类型事实源）+ 六锚健康检查（scripts/ontology-verify.sh 一站式）
- 类型对账断言（self-check check_ontology_types，18 实存点逐一核验）
- 语义/动能两区纪律（地图骨架头部声明）

## [v2.4] - 2026-08-21

### Added
- R15 HarnessEval 吸收：digest 链式锚定（三本账从并列升级为链式，上游篡改全链 stale 可检出）+ missing_evidence 态（"该测没测"显式态）+ gate-plan 选择即证据（启用/跳过理由负空间可审计）+ audit-closure 审计即完成条件（goal 闭环完备性重走）

## [v2.3] - 2026-08-21

### Added
- R14 better-harness 吸收：工作流审计层（goal_id+closure 目标闭环化=一个用户目标+一个验收边界，change↔validation 链接才 closed）+ 证据态分级（Present/Wired/Exercised/Outcome-supported——配置≠使用≠有效）+ 双账本（当窗验证 repair_verified_rate + guardrail 配对）+ 修复复核位（repair_review）

## [v2.2] - 2026-08-21

### Changed
- R14 基础版：工作流审计层框架（goal/closure 目标闭环 + 证据态分级概念引入）

## [v2.1] - 2026-08-21

### Changed
- R13 去抽象化增量：条件化强化（rules.d 三值/FORBID 带替代/G18/G19 断言）+ 宿主下沉（Codex hooks/settings 沙箱 deny）

## [v2.0] - 2026-08-21

### Changed
- **R13 去抽象化重构**：概念以指引式落地（认知计分退役转 AI 判断引导+notes 留痕）/ 十门禁全接线 54-54 / industry 真实加载 / 40 references 路由头；模板减负（spec 仪式节折叠/workflow 10→4 要素/核对清单 96→12）；条件化（rules.d 三值/FORBID 带替代）；生成器瘦身（SKILL.md 142→93 行/facts 21 键退役/check_doc 434→70 行/税制断言）

---

[v2.6.1]: https://github.com/issac-new/Swarm-yuan/compare/v2.6...v2.6.1
[v2.6]: https://github.com/issac-new/Swarm-yuan/compare/v2.5...v2.6
[v2.5]: https://github.com/issac-new/Swarm-yuan/compare/v2.4...v2.5
[v2.4]: https://github.com/issac-new/Swarm-yuan/compare/v2.3...v2.4
[v2.3]: https://github.com/issac-new/Swarm-yuan/compare/v2.2...v2.3
[v2.2]: https://github.com/issac-new/Swarm-yuan/compare/v2.1...v2.2
[v2.1]: https://github.com/issac-new/Swarm-yuan/compare/v2.0...v2.1
[v2.0]: https://github.com/issac-new/Swarm-yuan/releases/tag/v2.0

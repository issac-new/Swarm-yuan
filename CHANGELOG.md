# Changelog

All notable changes to swarm-yuan are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes per version are also available at [GitHub Releases](https://github.com/issac-new/Swarm-yuan/releases).

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

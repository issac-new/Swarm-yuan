# Plan — swarm-yuan 研发范式 skill 深度调研 + 标准合规增强重构

> 日期：2026-07-20 ｜ 触发：深入调研分析当前项目 + 第三方运行时组件 → 补充完善 + 重构优化 → 交付物满足行业及国家质量/安全标准
> 执行模式：四阶段 Stage-Gate，研究/设计/实现/验证分离，子代理并行。

## 背景速览（主会话已探查）

- `swarm-yuan/`：元技能生成器。SKILL.md(135行入口) + assets/(precheck.sh 2667行27门禁 / precheck.conf 146变量 / spec-template 22段 / 58框架门禁片段) + references/(14方法论文档 + 58框架规则md) + scripts/(generate-skill/self-check/state-machine) + tests/(57 fixture双态 + e2e)
- `verifier/v1/`：验收体系（C1-C7 验收标准 + golden-vector + runs 记录）
- `docs/`：paradigm-decisions.md + audit-optimization-decisions.md（近期审计：沉睡门禁/fail-open/文档漂移已知问题清单）
- `offline-cache/`：gstack + superpowers 上游组件完整源码（第三方运行时中仅有的两个本地全量）
- 关键约束：precheck.sh 必须保持单文件可移植；数字（27门禁/146变量/58框架/14 references）在 SKILL.md/README/USAGE/PROMO/self-check 间有单一事实源一致性门禁（check_doc_consistency）；新增门禁/文档必须同步全部口径 + 补 fixture

## Stage 1 — 深度调研（8 个并行研究子代理，coder 型，各自产出 docs/research/R*.md）

| # | 角色 | 范围 | 产出 |
|---|------|------|------|
| R1 | 自身设计理念分析员 | SKILL.md/README/docs 理念层 + generate-skill.sh/install.sh/self-check.sh 机制层 | R1-self-design.md |
| R2 | 门禁引擎分析员 | precheck.sh 27门禁逐条 + precheck.conf + state-machine + framework-gates 注入 + verifier | R2-gates-engine.md |
| R3 | 方法论体系分析员 | references/ 14 篇方法论文档（认知五层/剃刀/偏差/领域/探查/模板/编排/审查/图谱/gsd/记忆/安全/claude能力） | R3-methodology.md |
| R4 | 框架规则库分析员 | 58 框架三件套（规则md/门禁片段/fixture）结构质量与覆盖缺口 | R4-frameworks.md |
| R5 | 上游组件调研员-本地 | offline-cache 下 gstack + superpowers 全量源码：理念/功能/设计原理 + swarm-yuan 吸收度 | R5-upstream-local.md |
| R6 | 上游组件调研员-网络 | OpenSpec/comet/GitNexus/graphify/gsd-core/claude-mem/open-code-review/Ruflo/ECC + 同类范式（spec-kit/BMAD/SuperClaude）前沿 | R6-upstream-web.md |
| R7 | 质量标准调研员 | GB/T 25000(SQuaRE)/8566(生存周期)/15532(测试)/8567(文档)/9386(测试文档)/11457(术语)、ISO 25010/5055/29148/12207、DevOps/交付验收标准 | R7-quality-standards.md |
| R8 | 安全标准调研员 | GB/T 22239(等保2.0)/28448/35273(个信)/38674(安全编程)/18336(CC)、ISO 27001/27034、NIST SSDF、OWASP ASVS、CWE Top25、SLSA/SBOM/OpenChain、GM/T 商密、网安法/数安法/个保法研发交付要求 | R8-security-standards.md |

Gate：8 份研究文档全部落盘 + 主会话抽检质量。

## Stage 2 — 差距分析与重构设计（1 个 plan 子代理）

- 输入：R1-R8 全文 + 当前项目
- 产出：`docs/plans/2026-07-20-standards-gap-and-refactor-plan.md`
  - 差距矩阵：现状门禁/特征卡/references × 标准要求逐条映射（已满足/部分/缺失）
  - 增强清单：新增门禁（如 SBOM/许可证/依赖漏洞/隐私/标准文档门禁）、新增 reference 标准合规矩阵、模板补章、框架库补缺口
  - 明确每条修改的文件归属（避免并行冲突）、数字口径同步点、fixture/verifier 配套
  - 遵循范式既有原则：不贸然唤醒沉睡门禁（paradigm-decisions.md 教训）、单文件可移植、零占位符、自举

Gate：主会话审阅计划，决定实施范围。

## Stage 3 — 实现（coder 子代理，按文件归属分区并行）

- I1：新增 references/standards-compliance.md（标准合规矩阵 + 与门禁/特征卡映射）
- I2：precheck.sh 新增门禁 + precheck.conf 新变量（单文件唯一负责人）
- I3：模板增强（spec-template/plan-template 标准合规章节）
- I4：文档同步（SKILL.md/README/USAGE/PROMO 数字口径）
- I5：frameworks/domain-knowledge 缺口补齐（视 Stage 2 结论）
- I6：fixture + verifier + self-check 配套更新

## Stage 4 — 验证收口（1 个 coder 子代理）

- 跑 self-check.sh（文档一致性）+ 57 fixture 双态 + e2e + verifier/v1 全量
- 新增门禁的双态 fixture 必须绿；bash -n 语法；shellcheck 不恶化
- 产出验收记录到 verifier/runs/

## 铁律

1. 不改 precheck.sh 既有 27 门禁的判定语义（除非 Stage 2 明确列出且带验证）
2. 所有数字口径变更必须同步 self-check 的 check_doc_consistency 真值来源
3. 新门禁默认 warn 或静默跳过（未配置时），不得 fail-open
4. 研究文档引用标准条款必须标注标准号+年号+条款号，禁止虚构

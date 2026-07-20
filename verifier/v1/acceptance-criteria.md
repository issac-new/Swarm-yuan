# 验收标准 v1 — Swarm-yuan 重构

重构 = 结构优化，**不改变门禁判定语义**。以下全部通过才算完成。

## C1 行为等价（最高优先级）
- 57 个 framework fixture 的判定结果（violating→FAIL / compliant→PASS）重构前后逐一相同。
- 度量：`run-verifier.sh fixtures` 输出每个 fixture 的原始退出码向量 (v,c)，重构前后 diff 必须为空（比 OK/BAD 更强：退出码逐值相等）。
- 前置修复 R0：fixture conf 硬编码 `/Volumes/...` 路径 → `__REPO_ROOT__` 占位符 + runner 替换，使套件在任意机器真实可跑。修复后基线应为 57/57 OK。

## C2 E2E 通过
- `swarm-yuan/tests/e2e/run-e2e.sh` 重构后退出码为 0。

## C3 重复消除
- 两份 precheck.sh（swarm-yuan/assets vs Swarm-studio/scripts）不再各自维护漂移副本：
  要么单一事实来源 + 同步/生成机制，要么提取公共核心。
- 度量：两文件逐行相似度 diff 行数显著下降，或存在可验证的同步机制（同步后 diff 仅含声明过的定制段）。

## C4 Shellcheck 不恶化
- 核心脚本（precheck.sh、generate-skill.sh、self-check.sh、state-machine.sh、全部 framework-gates）error 级总数 ≤ 基线；重构涉及文件目标为 0 error。

## C5 CLI 兼容
- precheck.sh 的既有用法（--branch/--scope/--build/--test/--sensitive/--consistency/--framework 等）在重构后保持可用；--list/--help 类输出不破坏。

## C6 可维护性提升（量化）
- precheck.sh 单文件行数下降或源级模块化（多文件 + 构建生成单文件产物），生成物与源一致可重建验证。
- framework-gates 重复样板行数下降（提取公共函数库）。

## C7 交付物
- 《全面分析与重构报告》含：架构分析、问题清单（分级）、重构项前后量化对比、验证记录索引。

## C8 合规门禁 fixture（双态 + id 级断言）
- `swarm-yuan/tests/gate-fixtures/` 六组（compliance/docs-pack/sbom/privacy/sensitive/summary）全部双态通过：violating* 退出非 0、compliant* 退出 0。
- id 级断言全绿：violating 侧 `expected-ids` 逐行命中（fail id 契约：gate_compliance_*/gate_docs_pack_*/gate_sbom_*/gate_privacy_*），compliant 侧 `forbidden-ids` 零命中；sensitive/summary 的 `expect-output` 字面串（warn 披露文案、执行汇总行）全部包含。
- 度量：`bash verifier/v1/run-verifier.sh gate-fixtures` 输出 `GATE_FIXTURES_FAILS 0` 且退出码为 0。

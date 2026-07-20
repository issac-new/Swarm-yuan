# Verifier 索引 — Swarm-yuan 重构验收

本文件为只增不改的索引，每个版本一条记录。

## v1（2026-07-19 创建）
- **测量什么**：fixture 行为等价（57 框架门禁，violating/compliant 双端退出码）、e2e 通过、shellcheck error/warning 计数、重复度与行数指标（precheck 双副本 diff、LOC、.DS_Store）。
- **入口**：`bash verifier/v1/run-verifier.sh all`（支持 fixtures/e2e/shellcheck/metrics 子模式）。
- **标准**：见 `v1/acceptance-criteria.md`（C1 行为等价 / C2 e2e / C3 重复消除 / C4 shellcheck 不恶化 / C5 CLI 兼容 / C6 可维护性量化提升 / C7 报告交付）。
- **运行记录**：`runs/` 目录，每次运行一条带时间戳的记录（命令 + 退出码 + 输出摘要）。

## 最终验收记录（2026-07-19，refactor/optimization 分支 HEAD=032bfa9）
- C1 行为等价 ✅：57/57 fixture，退出码向量与 v1/golden-vector.txt 逐行一致（runs/2026-07-19T1808-final-fixtures.log）；57 个门禁片段另经 v1/gate-ab-diff.sh 字节级 stdout 等价逐个 PASS
- C2 e2e ✅：RC 0（runs/2026-07-19T1805-final-metrics.log）
- C3 重复消除 ✅：precheck 双副本 diff 469→22（仅剩声明的路径定制），同步机制 SKILLS_PATH_REWRITE 建立
- C4 shellcheck ✅：error(-s bash)=0；warning 15→13（存量均为保行为有意保留项）
- C5 CLI 兼容 ✅：precheck.sh A/B 沙箱 131 次调用 stdout+退出码逐字节一致（唯一例外为授权的 check_test 空值守卫修复）
- C6 可维护性 ✅：framework-gates 15369→13168 行（-14.3%）；precheck.sh 提取 6 helper+8 家族公共剥离库；397 处报告尾收编 _fw_report；27 个嵌套重复函数删除
- 基线演进：R0 前 fixtures 57/57 BAD（conf 硬编码 /Volumes 路径，violating 为假阳性）→ R0 后 57/57 OK

## 终验记录（2026-07-20，standards-refactor 标准合规增强重构，工作区未提交）
- C1 行为等价 ✅：57/57 fixture，退出码向量与 v1/golden-vector.txt diff 为空（runs/2026-07-20T1606-standards-refactor-fixtures.log）；spring-boot POSIX 字符类修复未改变其向量（v=1 c=0），golden 无需更新
- C2 e2e ✅：`swarm-yuan/tests/e2e/run-e2e.sh` RC=0（四框架注入 + 4 fail id 断言全过）
- C3 重复消除 ✅：本轮未触及双副本机制，既有 SKILLS_PATH_REWRITE 同步机制维持
- C4 shellcheck ⚠️ 无法判定：本机无 shellcheck（PATH//tmp//mnt/agents/tools 均无），run-verifier.sh shellcheck 按 fail-closed 设计报 SHELLCHECK_UNAVAILABLE 退出 1（runs/2026-07-20T1606-standards-refactor-shellcheck.log），非代码回归；全部 13 个 shell 脚本 `bash -n` 语法通过
- C8 合规门禁 fixture ✅：6/6 组双态 + id 级断言全过（runs/2026-07-20T1606-standards-refactor-gate-fixtures.log，GATE_FIXTURES_FAILS 0）
- 真值核对 ✅：check_* 函数 31 = GATE_FLAGS 31；precheck.conf 变量 162；UNIVERSAL_FILES 24；references/*.md（不含 frameworks/）14
- 最小 conf A/B ✅：`--all` 核心 10 序列（调用 10/执行 9/跳过 1 check_reuse）不含 4 新门禁；`--all-full` 执行汇总行「调用 31，执行 21，跳过 10」且 check_compliance/check_docs_pack/check_sbom/check_privacy 均计入跳过
- self-check 修复 ✅：check_doc_consistency 的 conf 变量提取 grep -E 模式 `\|`→`|`（`\|` 在 ERE 下按字面管道解析永不命中，致「SKILL.md 声明 precheck.conf 变量漂移」活跃误报；paradigm-decisions.md 记录的 `\|` 字面 bug 家族又一例）。修复后未篡改态「✓ conf 变量数一致(162)」，篡改 162→163 复现 ⚠ 漂移告警，恢复后转绿
- 既有行为留档：`--check-only` 在工具缺失时于 doc_consistency 之前早期 exit（HEAD 既有，非本轮引入）；本环境 superpowers 未装（既有环境 miss，唯一 ✗），故 doc_consistency 段经等代码路径 harness（仅中和早期 exit）验证全绿：57 框架规则/31 门禁/conf 162/refs 14/四文档头部数字/framework-signal-index 全部一致；上游基线 drifted（comet/graphify/ruflo）为 warn-only 忠告不置 FAIL

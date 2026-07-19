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

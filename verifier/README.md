# Verifier 索引 — Swarm-yuan 重构验收

本文件为只增不改的索引，每个版本一条记录。

## v1（2026-07-19 创建）
- **测量什么**：fixture 行为等价（57 框架门禁，violating/compliant 双端退出码）、e2e 通过、shellcheck error/warning 计数、重复度与行数指标（precheck 双副本 diff、LOC、.DS_Store）。
- **入口**：`bash verifier/v1/run-verifier.sh all`（支持 fixtures/e2e/shellcheck/metrics 子模式）。
- **标准**：见 `v1/acceptance-criteria.md`（C1 行为等价 / C2 e2e / C3 重复消除 / C4 shellcheck 不恶化 / C5 CLI 兼容 / C6 可维护性量化提升 / C7 报告交付）。
- **运行记录**：`runs/` 目录，每次运行一条带时间戳的记录（命令 + 退出码 + 输出摘要）。

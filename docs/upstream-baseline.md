# 上游运行时版本与许可证基线登记表

> 用途：登记 swarm-yuan 引用/吸收的 **11 个上游运行时**的许可证与版本基线，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）与文档漂移治理。
> 数据来源：GitHub REST API + npm/PyPI registry **2026-07-20 实测**（见 `docs/research/R6-upstream-web.md` §0；gstack/superpowers 见 `docs/research/R5-upstream-local.md`）。
> 机器可读契约：每个 drifted 条目所在行必须含字面漂移标记（行尾「机器标记」列，格式 baseline_status=状态值）；self-check 的轻量基线忠告仅 grep 漂移标记所在行并 warn（不联网）。
> 状态取值：`synced`（基线≈最新）｜`drifted`（基线落后，需重核）｜`watch`（迭代极快，持续观察）｜`license-risk`（许可证合规风险）。

## 一、11 运行时登记表

| 名称 | 仓库 | 许可证 | 引用基线 | 2026-07-20 最新版 | 状态 | 机器标记 |
|------|------|--------|----------|--------------------|------|----------|
| openspec | Fission-AI/OpenSpec | MIT | v1.6.0（`references/review-methodology.md:130`） | npm 1.6.0 | synced | baseline_status=synced |
| comet | rpamis/comet | MIT | v0.3.9（`references/subagent-orchestration.md:118`） | npm 0.4.0-beta.5 | drifted（落后一个大版本，0.4 能力清单需重核） | baseline_status=drifted |
| GitNexus | abhigyanpatwari/GitNexus | **PolyForm Noncommercial 1.0.0**（禁商用，API 返回 NOASSERTION，LICENSE 原文实测） | npm 1.6.9（引用 `context/trace`） | npm 1.6.9 | license-risk（降级为非默认，仅非商用可选） | baseline_status=license-risk |
| gsd-core | open-gsd/gsd-core | MIT | v1.7.0（`references/review-methodology.md:311`） | npm 1.7.0 | synced | baseline_status=synced |
| claude-mem | thedotmack/claude-mem | Apache-2.0 | 13.4 时代三路写回（`swarm-yuan/SKILL.md:85`） | npm 13.11.0 | watch（迭代极快，13.4→13.11 小版本高频） | baseline_status=watch |
| ocr | alibaba/open-code-review | Apache-2.0 | v1.3.13→v1.7.12（`references/review-methodology.md:178,313`） | v1.7.x（Go） | synced（基本同步） | baseline_status=synced |
| graphify | Graphify-Labs/graphify（原 safishamsi/graphify，已迁移） | MIT | v0.9.x（v0.9.5 源码调研 + v0.9.6–v0.9.19 release notes，`references/code-graph-tools.md`） | npm graphifyy 0.10.0 / PyPI 0.9.20 | drifted（0.10.0 待评估） | baseline_status=drifted |
| superpowers | obra/superpowers | MIT | v6.1.1（`references/subagent-orchestration.md:118`；**核心插件未 vendor**，离线包仅 marketplace 元数据） | v6.x | synced | baseline_status=synced |
| gstack | garrytan/gstack | MIT | v1.60.1.0（offline-cache vendor，`offline-cache/gstack/VERSION:1`） | v1.60.1.0（vendor 版本；上游最新未实测） | synced | baseline_status=synced |
| ruflo | ruvnet/ruflo（原 Claude Flow） | MIT | v3.21.1 / v3.24–v3.25 方法论（`references/subagent-orchestration.md:277`、`references/review-methodology.md:208-209`） | npm 3.32.8 | drifted（落后 ~11 个小版本） | baseline_status=drifted |
| ECC | affaan-m/ECC | MIT | v2.0.0（`references/subagent-orchestration.md:149`） | v2.0.0（2026-06 稳定版） | synced | baseline_status=synced |

## 二、关键结论

1. **许可证风险（最高优先）**：GitNexus = PolyForm Noncommercial 1.0.0，禁止商业使用。冻结措辞（全仓库统一引用）：**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（MIT）提为默认代码图谱工具。**
2. **版本漂移（3 项 drifted）**：comet 0.3.9→0.4.0-beta.5；Ruflo 3.21.1→3.32.8；graphify 0.9.x→0.10.0。重核列入下一轮审计（P1-7）。
3. **watch（1 项）**：claude-mem 迭代极快（13.4→13.11），持续观察，不逐一追版。
4. **org 迁移**：graphify 仓库已迁至 Graphify-Labs/graphify，引用一律用新 URL。
5. **存续风险**：11 个运行时中个人/小团队项目占比高（comet/GitNexus/claude-mem/gsd-core），上游存续监测纳入审计例程；GSD v1 上游（gsd-build/get-shit-done）已于 2026-06-26 归档，引用 open-gsd/gsd-core 为既定应对。

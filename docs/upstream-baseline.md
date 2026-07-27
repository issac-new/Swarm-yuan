# 上游运行时版本与许可证基线登记表

> 用途：登记 swarm-yuan 引用/吸收的 **12 个上游运行时**的许可证与版本基线，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）与文档漂移治理。
> 数据来源：GitHub REST API + npm/PyPI registry **2026-07-20 实测**（见 `docs/research/R6-upstream-web.md` §0；gstack/superpowers 见 `docs/research/R5-upstream-local.md`）；impeccable 行为 2026-07-28 实测补入。
> 机器可读契约：每个 drifted 条目所在行必须含字面漂移标记（行尾「机器标记」列，格式 baseline_status=状态值）；self-check 的轻量基线忠告仅 grep 漂移标记所在行并 warn（不联网）。
> 状态取值：`synced`（基线≈最新）｜`drifted`（基线落后，需重核）｜`watch`（迭代极快，持续观察）｜`license-risk`（许可证合规风险）。

## 一、12 运行时登记表

| 名称 | 仓库 | 许可证 | 引用基线 | 2026-07-20 最新版 | 状态 | 机器标记 |
|------|------|--------|----------|--------------------|------|----------|
| openspec | Fission-AI/OpenSpec | MIT | v1.6.0（`references/review-methodology.md:130`） | npm 1.6.0 | synced | baseline_status=synced |
| comet | rpamis/comet | MIT | v0.3.9（`references/subagent-orchestration.md:118`） | npm 0.4.0-beta.6（2026-07-20 重核；初测 0.4.0-beta.5） | drifted（P1-7 已重核，结论=观望，见 §三；0.4 正式版发布后升级引用基线） | baseline_status=drifted |
| GitNexus | abhigyanpatwari/GitNexus | **PolyForm Noncommercial 1.0.0**（禁商用，API 返回 NOASSERTION，LICENSE 原文实测） | npm 1.6.9（引用 `context/trace`） | npm 1.6.9 | license-risk（降级为非默认，仅非商用可选） | baseline_status=license-risk |
| gsd-core | open-gsd/gsd-core | MIT | v1.8.0（2026-07-26 升级；`references/gsd-patterns.md` + `references/decision-governance.md` §2.4 + `references/review-methodology.md:311`） | npm 1.8.0（2026-07-22 release） | synced（2026-07-26 升级 research 仓库 + 吸收 reversibility/broken-windows） | baseline_status=synced |
| claude-mem | thedotmack/claude-mem | Apache-2.0 | v13.12.4（2026-07-26 升级；`swarm-yuan/SKILL.md:85` + G10 版本 oracle 吸收） | npm 13.12.4 | watch（迭代极快；2026-07-26 升级 research 仓库 + 吸收 version oracle 单源真值） | baseline_status=watch |
| ocr | alibaba/open-code-review | Apache-2.0 | v1.7.17（2026-07-26 升级；`references/review-methodology.md:178,313`） | v1.7.17（Go） | synced（2026-07-26 升级 research 仓库） | baseline_status=synced |
| graphify | Graphify-Labs/graphify（原 safishamsi/graphify，已迁移） | Apache-2.0（2026-07-18 MIT->Apache 2.0，v0.9.25） | v0.9.27（2026-07-26 升级，origin/v8 线；`references/code-graph-tools.md` + `references/memory-persistence.md` 知识溯源三标吸收） | npm graphifyy 0.10.0 / PyPI 0.9.27 | synced（2026-07-26 升级 research 仓库到 v0.9.27；0.10.0 是 npm 异源包待评估） | baseline_status=synced |
| superpowers | obra/superpowers | MIT | v6.2.0（2026-07-26 升级；`references/subagent-orchestration.md` 修复环+5轮熔断 + `references/review-methodology.md` 可证伪性纪律吸收；**核心插件未 vendor**，离线包仅 marketplace 元数据；不 vendor 决策见 `docs/2026-07-20-upstream-vendor-decision.md`） | v6.2.0（2026-07-22 release） | synced（2026-07-26 升级 research 仓库 + 吸收 resume-fix-loop/scoped-re-review/falsifiability） | baseline_status=synced |
| gstack | garrytan/gstack | MIT | v1.60.1.0（offline-cache vendor，`offline-cache/gstack/VERSION:1`） | v1.60.1.0（vendor 版本；上游最新未实测） | synced | baseline_status=synced |
| ruflo | ruvnet/ruflo（原 Claude Flow） | MIT | v3.32.9（2026-07-26 升级；`references/subagent-orchestration.md:277`、`references/review-methodology.md:208-209`） | npm 3.32.9 | synced（2026-07-26 升级 research 仓库；方法论引用层，无运行时调用） | baseline_status=synced |
| ECC | affaan-m/ECC | MIT | v2.0.0（`references/subagent-orchestration.md:149`） | v2.0.0（2026-06 稳定版） | synced | baseline_status=synced |
| impeccable | pbakaus/impeccable | Apache-2.0 | v4.0.2（2026-07-28 吸收；`references/frontend-design-methodology.md`，方法论引用层第 5 对象；Modes/三层权威/craft-floor/59 反模式字典/finish_reviewer 完工审查模式；G13 断言守引用存在性） | v4.0.2（2026-07-28 GitHub 实测） | synced（2026-07-28 clone research 仓库 + 方法论吸收，无 CLI 调用） | baseline_status=synced |

## 二、关键结论

1. **许可证风险（最高优先）**：GitNexus = PolyForm Noncommercial 1.0.0，禁止商业使用。冻结措辞（全仓库统一引用）：**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（Apache-2.0，2026-07-18 MIT->Apache 2.0）提为默认代码图谱工具。**
2. **版本漂移（1 项 drifted，2026-07-26 升级后）**：comet 0.3.9->0.4.0-beta.6（P1-7 已重核，结论=观望，见 §三）。2026-07-26 升级轮把 graphify（v0.9.27）、ruflo（v3.32.9）的 research 仓库对齐到上游最新稳定版并吸收方法论，引用基线同步更新为 synced（详见 `docs/runtime-update-2026-07.md`）。
3. **watch（1 项）**：claude-mem 迭代极快（13.4->13.12.4），持续观察；2026-07-26 升级 research 仓库到 v13.12.4 并吸收 version oracle 单源真值（G10）。
4. **org 迁移**：graphify 仓库已迁至 Graphify-Labs/graphify，引用一律用新 URL。
5. **存续风险**：12 个运行时中个人/小团队项目占比高（comet/GitNexus/claude-mem/gsd-core），上游存续监测纳入审计例程；GSD v1 上游（gsd-build/get-shit-done）已于 2026-06-26 归档，引用 open-gsd/gsd-core 为既定应对。

## 三、comet 0.4 能力重核结论（P1-7，2026-07-20 实测）

**结论：观望**——引用基线保持 v0.3.9，状态维持 drifted；待 0.4.0 正式版发布后升级为 v0.4.x 并同步修订 `references/subagent-orchestration.md` 的 v0.3.9 能力清单。

### 3.1 重核事实（0.3.9 → 0.4.0-beta.x 的实际变化）

来源（均 2026-07-20 访问）：

- npm registry：dist-tag latest=0.4.0-beta.6（2026-07-20 发布；beta.1 始于 2026-07-07，14 天 6 个 beta）——https://registry.npmjs.org/@rpamis/comet
- 0.4.0-beta.1 全量说明——https://raw.githubusercontent.com/rpamis/comet/master/NEWS.md
- beta.2–beta.6 增量——https://raw.githubusercontent.com/rpamis/comet/master/CHANGELOG.md
- 0.3.x 系列发布说明——https://github.com/rpamis/comet/releases

**状态机**：Bash 脚本层 → 跨平台 Node 运行时（`.mjs` launcher + 共享 `comet-runtime.mjs`，不再要求 Git Bash/WSL）；机器检查点从 `.comet.yaml` 分离到 `.comet/run-state.json`（用户可编辑字段仍留 YAML）；新增稳定 CLI `comet state|guard|handoff|archive`（beta.4），agent 不再依赖内部安装脚本路径；`comet state rebind` + isolation 绑定分支漂移检测（beta.6）。

**硬前置**：verify-pass 仍要求 verification_report 指向存在文件 + branch_status=handled（0.3.9 语义保留）；新增 artifact 语言守卫 fail-closed（language 非法即拒，beta.1）；归档最终用户确认记入机器态、未确认拒绝变更性归档，防止直接调脚本绕过确认（beta.4）；isolation 漂移在 build/verify/archive 入口检查与写守卫处一律拦截（beta.6）。

**证据链**：阶段迁移写 `.comet/state-events.jsonl` 审计历史（beta.1）；无 npm/Maven/Cargo 推断命令的项目可登记可审计 build/verify 证据，替代原先未文档化的跳过路径（beta.4）；verify 失败自动回 Build 前 3 条可执行发现、连续失败计数跨恢复持久化、CRITICAL/IMPORTANT 不可豁免（beta.5）。

**吸收面之外的新能力**（登记备查，不构成本仓引用）：`/comet-any` Skill Creator、`comet eval`（pass@k/pass^k 评估）、`comet dashboard` 本地只读看板（beta.1 起）。

### 3.2 观望理由

1. **0.4 仍在 beta 通道快速收敛**：14 天连发 6 个 beta，语义仍在变动（beta.3 移除自定义 guard 命令字段、beta.6 改 isolation 绑定语义），现在升级引用基线等于追移动目标。
2. **swarm-yuan 对 comet 是方法论级引用，非运行时调用**：`SKILL.md:108` 允许 CLI 清单不含 comet；`assets/state-machine.sh` 是自实现的「comet 风格」状态机。Bash→Node 迁移不造成功能性破坏；已吸收核心理念（脚本背书状态机、无证据不流转、handoff SHA256）在 0.4 全部保留且增强。
3. **能力清单形态已过时但语义未失效**：`references/subagent-orchestration.md:116-118` 登记的 7 个 `.sh` 脚本（comet-guard.sh 等）在 0.4 变为 `.mjs` launcher + 稳定 CLI；升级引用基线时需同步重写该清单，与正式版升级一并进行更经济。

**复审触发条件**：npm dist-tag latest 出现 0.4.0 正式版（非 beta）→ 升级引用基线为 v0.4.x、状态改 synced、重写能力清单（脚本形态 + run-state.json/state-events.jsonl + 稳定 CLI + isolation 绑定语义）。

## WP-Y：自动化 drift 检测

上述 `baseline_status=drifted` 的 1 项（comet，2026-07-26 升级后；graphify/ruflo 已升级为 synced）现在由 `--upstream-baseline` 门禁自动检测。
门禁扫描本文件的 `baseline_status=` 标记，drifted 项 warn 提示（advisory 级，不阻断交付）。

**处置策略**：
- **comet**：0.4.0 正式版发布后升级引用基线（swarm-yuan 对 comet 是方法论级引用，state-machine.sh 是自实现的 comet 风格状态机，升级不阻塞）
- **graphify**：2026-07-26 已升级 research 仓库到 v0.9.27（Apache 2.0，origin/v8 线）并吸收 honest-edge provenance 三标；npm 0.10.0 是异源包待评估（不取 v1.0.0 异源旧分支）
- **ruflo**：2026-07-26 已升级 research 仓库到 v3.32.9（方法论引用层，无运行时调用）

升级基线时：更新本表"引用基线"列版本号 → 将 `baseline_status=drifted` 改为 `baseline_status=synced` → 跑 `bash scripts/self-check.sh --check-only` 确认无 drift warn。

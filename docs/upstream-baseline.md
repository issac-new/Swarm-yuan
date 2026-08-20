# 上游运行时版本与许可证基线登记表

> 用途：登记 swarm-yuan 引用/吸收的 **14 个上游运行时**的许可证与版本基线，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）与文档漂移治理。
> 数据来源：GitHub REST API + npm/PyPI registry **2026-08-21 实测**（本轮 R4 全量重核）；历史实测轮次见 `docs/research/R6-upstream-web.md` §0（2026-07-20）/ `docs/runtime-update-2026-07.md`（2026-07-26）/ 2026-08-14 轮。
> 机器可读契约：每个 drifted 条目所在行必须含字面漂移标记（行尾「机器标记」列，格式 baseline_status=状态值）；self-check 的轻量基线忠告仅 grep 漂移标记所在行并 warn（不联网）。
> 状态取值：`synced`（基线≈最新）｜`drifted`（基线落后，需重核）｜`watch`（迭代极快，持续观察）｜`license-risk`（许可证合规风险）。
>
> **本地缓存建议**：`swarm-yuan/research/` 下的上游 clone 仅供 AI 阅读源码（已 gitignored，不入 git），无需 commit 历史。建议用 `git clone --depth 1` 浅克隆——12 个 clone 的 `.git` 历史合计约 1.1GB，浅克隆可省 ~1GB 本地磁盘（ruflo/claude-mem/gsd-core/open-code-review 四个 `.git` 占比最高）。

## 一、14 运行时登记表

| 名称 | 仓库 | 许可证 | 引用基线 | 2026-08-21 最新版 | 状态 | 机器标记 |
|------|------|--------|----------|--------------------|------|----------|
| openspec | Fission-AI/OpenSpec | MIT | v1.10.0（2026-08-21 升级；`references/review-methodology.md:130`） | npm 1.10.0 | synced（2026-08-21 升级；吸收 v1.10 task plan 强制完成判据 + 诊断输出一律走 stderr 纪律） | baseline_status=synced |
| comet | rpamis/comet | MIT | v0.3.9（`references/subagent-orchestration.md:118`） | npm 0.4.0-beta.18（2026-08-21 重核；仍 beta 通道） | drifted（观望——0.4.0-beta 已发到 beta.18 仍无正式版；等 0.4.0 正式版发布后升级引用基线） | baseline_status=drifted |
| GitNexus | abhigyanpatwari/GitNexus | **PolyForm Noncommercial 1.0.0**（禁商用，API 返回 NOASSERTION，LICENSE 原文实测） | npm 1.6.9（引用 `context/trace`） | npm 1.6.9（2026-08-21 重核，仍停滞于 2026-07-04） | license-risk（降级为非默认，仅非商用可选） | baseline_status=license-risk |
| gsd-core | open-gsd/gsd-core | MIT | v1.11.0（2026-08-21 升级；`references/gsd-patterns.md` + `references/decision-governance.md` §2.4 + `references/review-methodology.md:311`） | npm 1.11.0（next 分支 tag） | synced（2026-08-21 升级；吸收 v1.11 guard 必须能观测自身失败分支 + STATE.md 盖 commit 戳新鲜度检测 + validator 收敛统一 envelope） | baseline_status=synced |
| claude-mem | thedotmack/claude-mem | Apache-2.0 | v13.15.3（2026-08-21 升级；`references/memory-persistence.md` sensitive 观察类型吸收 + G10 版本 oracle 吸收） | npm 13.15.3 | watch（迭代极快；2026-08-21 升级 + 吸收 v13.15.x 错误信封分类 quota 不重试 + 多界面文案单一事实源） | baseline_status=watch |
| ocr | alibaba/open-code-review | Apache-2.0 | v1.9.8（2026-08-21 升级；`references/review-methodology.md`） | v1.9.8（Go） | synced（2026-08-21 升级；吸收 v1.9.3-8 JSON/SARIF 输出时进度走 stderr + 非 TTY 关颜色 + api_key 从命令解析 + SARIF 输出 + resume 可信校验） | baseline_status=synced |
| graphify | Graphify-Labs/graphify（原 safishamsi/graphify，已迁移） | Apache-2.0（2026-07-18 MIT->Apache 2.0，v0.9.25） | v0.9.47（2026-08-21 升级，origin/v8 线；`references/code-graph-tools.md` Windows 可移植性吸收 + `references/memory-persistence.md` 知识溯源三标吸收） | npm graphifyy 0.10.0 / PyPI 0.9.47 | synced（2026-08-21 升级 research 仓库到 v0.9.47；**v1.0.0 是异源旧分支不取**——2026-04-05 发布，与 v0.9.47 diverged；吸收 v0.9.43-47 OCaml/CommonLisp 语言扩展 + no-op 产物字节一致幂等写入 + 超时二分降级） | baseline_status=synced |
| superpowers | obra/superpowers | MIT | v6.3.0（2026-08-14 升级；`references/subagent-orchestration.md` 修复环+5轮熔断 + brainstorming 仪式按任务规模缩放吸收 + `references/review-methodology.md` 可证伪性纪律吸收；**核心插件未 vendor**，离线包仅 marketplace 元数据；不 vendor 决策见 `docs/2026-07-20-upstream-vendor-decision.md`） | v6.3.0（2026-08-21 重核，无新版） | synced（2026-08-14 升级；吸收 v6.3 brainstorming 仪式按任务规模缩放 + controller 冲突不卡住 + resume-fix-loop/scoped-re-review/falsifiability） | baseline_status=synced |
| gstack | garrytan/gstack | MIT | v1.68.2.0（2026-08-21 升级，master commit 51932ec；offline-cache vendor `offline-cache/gstack/VERSION:1`） | v1.68.2.0（2026-08-20 commit；无 release 无 tag，版本靠 VERSION 文件递增） | synced（2026-08-21 升级；吸收 v1.60-68 pipeline guard 全部可证明触发 + evidence ledger + fail-closed hooks + issue/PR 关闭附 receipt 证据） | baseline_status=synced |
| ruflo | ruvnet/ruflo（原 Claude Flow） | MIT | v3.38.12（2026-08-21 升级；`references/subagent-orchestration.md:277`、`references/review-methodology.md:208-209`） | npm 3.38.12（npm 领先 GitHub release 3.38.9，以 npm 为准） | synced（2026-08-21 升级；3.38.10-12 为 patch 列车 + SynthID-Text 水印 crate 新方向（本仓不吸收——与运行时无关）；方法论引用层，无运行时调用） | baseline_status=synced |
| ECC | affaan-m/ECC | MIT | v2.1.0（2026-08-14 升级；`references/subagent-orchestration.md:149`；Plan Canvas 可视化 plan review + Kimi Code harness） | v2.1.0（2026-08-21 重核，仍 2026-07-27 版） | synced（2026-08-14 升级；吸收 Plan Canvas 可视化审查） | baseline_status=synced |
| impeccable | pbakaus/impeccable | Apache-2.0 | v4.1.1（2026-08-21 升级；`references/frontend-design-methodology.md`，方法论引用层第 5 对象；Modes/三层权威/craft-floor/59 反模式字典/finish_reviewer 完工审查模式 + v4.1 对抗性 verdict 多候选先内部比较再呈交 + 平台感知验证 + 证据坏则重取证重跑；G13 断言守引用存在性） | v4.1.1（2026-08-14 GitHub 实测，tag 名 skill-v4.1.1） | synced（2026-08-21 升级；吸收 v4.1 对抗性 verdict + 平台感知验证 + 拒绝假证据纪律） | baseline_status=synced |
| codex-security | openai/codex-security | Apache-2.0（完全开源） | v0.1.16（2026-08-21 升级；`references/codex-security-methodology.md`，CLI 接线层第 4 对象；**AI 约束推理扫描（非传统 SAST——OpenAI 官方明确「不包含 SAST 报告」）** + source→sink 数据流 + 静态评估七元组 + 威胁模型五要素 + 攻击路径分析 + SECURITY.md 策略合并 + scan contract 三件套 + 14 bundled skills + Docker 沙箱范式；v0.1.16 Linear 深度集成 + 交互式修复闭环 + verify-fix 只读命令 + bulk-scan 每仓库成本上限；`--sast-deep` 门禁 `SAST_DEEP_TOOL=codex-security` 时显式调用，**非降级链一环（非 SAST，auto 降级链不变，两者正交可并行）**；开源 Apache-2.0，Trusted Access 非付费门槛（推荐的身份审核），API 按 token 计费；G15 断言守 CLI 接线存在性） | v0.1.16（2026-08-20 GitHub 实测） | synced（2026-08-21 升级；吸收 v0.1.12-16 Linear 深度集成 + 交互式修复闭环 + verify-fix + bulk 成本上限） | baseline_status=synced |
| dsh | deepseek-ai/deepseek-harness | MIT | dsh-v0.1.0-rc.8（2026-08-20 R12 重调研；`references/dsh-engineering-methodology.md` 四簇吸收——决策审计/状态韧性/增量自成长/工程纪律） | dsh-v0.1.0-rc.8（2026-08-21 重核，master HEAD=141eb6f 2026-08-19 与 rc.8 对齐） | synced（2026-08-20 R12 重调研落地；rc.8 无新版） | baseline_status=synced |

## 二、关键结论

1. **许可证风险（最高优先）**：GitNexus = PolyForm Noncommercial 1.0.0，禁止商业使用。冻结措辞（全仓库统一引用）：**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（Apache-2.0，2026-07-18 MIT->Apache 2.0）提为默认代码图谱工具。**
2. **版本漂移（1 项 drifted，2026-08-21 重核后）**：comet 0.3.9→0.4.0-beta.18（仍观望——beta 已发到 beta.18 但无 0.4.0 正式版；等正式版发布后升级引用基线）。本轮 2026-08-21 全量重核把 openspec/gsd-core/claude-mem/ocr/graphify/gstack/ruflo/impeccable/codex-security 9 项升级到最新并吸收对应方法论（详见各条目吸收注记 + `docs/runtime-update-2026-08.md`）。
3. **watch（1 项）**：claude-mem 迭代极快（13.15.0->13.15.3，3 天 3 个 patch），持续观察；2026-08-21 升级 research 仓库到 v13.15.3 并吸收错误信封分类 + 多界面文案单一事实源纪律。
4. **org 迁移**：graphify 仓库已迁至 Graphify-Labs/graphify，引用一律用新 URL。
5. **存续风险**：14 个运行时中个人/小团队项目占比高（comet/GitNexus/claude-mem/gsd-core），上游存续监测纳入审计例程；GSD v1 上游（gsd-build/get-shit-done）已于 2026-06-26 归档，引用 open-gsd/gsd-core 为既定应对。
6. **gstack 版本递增节奏**：v1.60.1.0（2026-08-14 基线）→ v1.68.2.0（2026-08-20 master HEAD）7 天 8 个 minor——大批量 tracker 清理波（v1.64.0 90 修复 + v1.64.1 净删 24,943 行 + v1.68.0 16 验证修复）；本仓引用为 vendor 离线包，离线包内容不升级（vendor 决策见 `docs/2026-07-20-upstream-vendor-decision.md`），只升引用基线。

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

**2026-08-21 R4 重核**：0.4.0-beta.18（2026-08-13）仍 beta 通道，14 天 6 beta → 38 天 18 beta，发版节奏加快但正式版未出。维持观望结论；beta.4-18 间新增 `.comet/run-state.json` 与 `.comet/state-events.jsonl` 分离、稳定 CLI `comet state|guard|handoff|archive`、verify 失败回 Build 前 3 条可执行发现 + 连续失败计数持久化、CRITICAL/IMPORTANT 不可豁免、isolation 漂移在 build/verify/archive 入口与写守卫处拦截——这些与本仓 fail-gate-hook.sh 的 flag 捕获模型 + R12-A 全量审计 + R3-2 last-good 红线机器执法语义对齐，理念已在自实现路径落地，无需追 beta。

## WP-Y：自动化 drift 检测

上述 `baseline_status=drifted` 的 1 项（comet，2026-08-21 重核后仍观望；其余 8 项本轮已升级为 synced）现在由 `--upstream-baseline` 门禁自动检测。
门禁扫描本文件的 `baseline_status=` 标记，drifted 项 warn 提示（advisory 级，不阻断交付）。

**处置策略**（2026-08-21 R4 更新）：
- **comet**：0.4.0 正式版发布后升级引用基线（swarm-yuan 对 comet 是方法论级引用，state-machine.sh 是自实现的 comet 风格状态机，升级不阻塞）
- **graphify**：2026-08-21 已升级 research 仓库到 v0.9.47（Apache 2.0，origin/v8 线）并吸收 OCaml/CommonLisp 语言扩展 + no-op 产物字节一致幂等写入 + 超时二分降级（**不取 v1.0.0 异源旧分支**——2026-04-05 发布，与 v0.9.47 diverged）
- **gstack**：2026-08-21 升引用基线到 v1.68.2.0（vendor 离线包内容不动——仍 v1.60.1.0 时代码快照；只升引用基线反映"跟踪到哪个上游版本"）
- **ruflo**：2026-08-21 升引用基线到 npm 3.38.12（npm 领先 GitHub release，以 npm 为准）

升级基线时：更新本表"引用基线"列版本号 → 将 `baseline_status=drifted` 改为 `baseline_status=synced` → 跑 `bash scripts/self-check.sh --check-only` 确认无 drift warn。

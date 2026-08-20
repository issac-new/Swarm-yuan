# R4 运行时依赖升级轮（2026-08-21）——14 个上游版本差异 + 吸收点落地

> 触发：user message「更新所有运行时依赖及环境版本到最新版，分析与上次之间的版本差异，消化吸收融合其功能优势」
> 数据来源：GitHub REST API + npm registry（2026-08-21 实测）；sub-agent 调研报告（见 session 上下文）
> 历史轮次：`docs/research/R6-upstream-web.md` §0（2026-07-20）/ `docs/runtime-update-2026-07.md`（2026-07-26）/ 2026-08-14 轮（未单写报告）

## 一、14 上游版本差异速览（基线 → 最新）

| 项目 | 基线 | 最新（2026-08-21） | 跨度 | 动作 |
|------|------|---------------------|------|------|
| openspec | v1.9.0 | **v1.10.0**（2026-08-19） | 1 minor | 升基线 + 吸收 |
| comet | v0.3.9 | 0.4.0-beta.18（2026-08-13） | beta 连发 | **仍观望**（无正式版） |
| GitNexus | npm 1.6.9 | 1.6.9（2026-07-04 停滞） | 无变化 | 保持 license-risk |
| gsd-core | v1.10.0 | **v1.11.0**（2026-08-19 next 分支） | 1 minor | 升基线 + 吸收 |
| claude-mem | v13.15.0 | **v13.15.3**（2026-08-20） | 3 patch | 升基线 + 吸收（watch） |
| ocr | v1.9.2 | **v1.9.8**（2026-08-20） | 6 patch | 升基线 + 吸收 |
| graphify | v0.9.42 | **v0.9.47**（2026-08-19） | 5 patch | 升基线 + 吸收 |
| superpowers | v6.3.0 | v6.3.0（2026-08-12） | 无变化 | 已同步 |
| gstack | v1.60.1.0 | **v1.68.2.0**（2026-08-20 commit 51932ec） | 8 minor | 升基线 + 吸收 |
| ruflo | v3.38.9 | **npm 3.38.12**（release 3.38.9） | 3 patch | 升基线（npm 为准） |
| ECC | v2.1.0 | v2.1.0（2026-07-27） | 无变化 | 已同步 |
| impeccable | v4.0.4 | **skill-v4.1.1**（2026-08-14） | 1 minor | 升基线 + 吸收 |
| codex-security | v0.1.11 | **v0.1.16**（2026-08-20） | 5 patch | 升基线 + 吸收 |
| dsh | rc.8 | rc.8（master=141eb6f 2026-08-19） | 无新版 | 已同步 |

**新增**：dsh（deepseek-harness）首次入表——R12 重调研后已作为第 14 个上游运行时（方法论吸收层，非运行时调用）。

## 二、可吸收点 → 落地点

按 swarm-yuan 口径分两类：方法论文档（references/）与工程纪律（已有机制对齐强化）。

### 2.1 openspec v1.10 → `references/review-methodology.md` / spec-template

- **task plan 强制"完成判据"**（test / 命令 / 可观察结果 / 交付物）——"Implement the thing"不再算计划。
  落地：spec-template §3 plan 部分加"完成判据必填"指引；`--verify-completeness` 已有占位符检测，可扩展检 plan 章节是否含完成判据字段（本轮不落地机器执法，仅文档强化）。
- **诊断输出一律走 stderr 不污染 stdout 管道**——与 swarm-yuan 既有 CLI 纪律一致，对齐确认。

### 2.2 gsd-core v1.11 → `references/gsd-patterns.md` / `references/decision-governance.md`

- **guard 必须能观测自身失败分支**——不可观测的 guard 拒绝注册。落地：gsd-patterns.md 增"guard 可观测性"段；本仓 fail-gate-hook.sh 的 flag 捕获模型天然满足（PostToolUse precheck 退出码 → flag → PreToolUse 读 flag 决策）。
- **STATE.md 盖 commit 戳 + 新鲜度检测**——本仓 `.swarm-yuan-version` 已有 `source_repo` 盖戳；可扩展为 state.yaml 盖 commit 戳（本伦不落地，登记候选）。
- **validator 收敛统一 envelope + owner 分阶段 ratchet**——本仓 trace-log.sh 单 JSONL envelope 已对齐。

### 2.3 claude-mem v13.15.x → `references/memory-persistence.md`

- **错误信封分类**（cmem.ai gateway `{code,message,action,url,request_id}`；402/quota 耗尽不重试，失败收敛单行日志）。
  落地：memory-persistence.md 增"错误信封分类"段（quota 类不重试 vs 网络瞬断可重试的区分）。
- **session-start 的 observer-health 告警**（observation 停止流入时提示）——本仓 SessionStart hook fingerprint 感知是同构机制，已落地。
- **多界面促销/提示文案单一事实源**（`src/shared/pro-promo.ts`）——本仓 facts.conf 单一事实源机器执法同构，已对齐。

### 2.4 ocr v1.9.8 → `references/review-methodology.md`

- **JSON/SARIF 输出时 review 进度走 stderr、非 TTY 关颜色**——本仓 precheck.sh `--format json` 已对齐（SARIF 子集结果打印 stdout 末尾，进度走 stderr）。
- **api_key 从命令解析**（`api_key = "!op read ..."` 模式）避免明文落盘——本仓 precheck.conf 无 secret 字段，安全边界已对齐；登记候选供未来 AI 工具集成参考。
- **resume 可信校验 + transition lineage + Ctrl-C 保留 checkpoint**——本仓 state-machine.sh dump-journal/restore-journal 已对齐。

### 2.5 graphify v0.9.47 → `references/code-graph-tools.md` / `references/memory-persistence.md`

- **no-op 运行产物字节一致 / 不触碰时间戳**（manifest 时间戳 no-op 时不重写，避免假 dirty commit）。
  落地：code-graph-tools.md 增"幂等写入纪律"段；本仓 project-fingerprint.sh `--diff` 无变化时不重写基线文件已对齐。
- **超时二分降级而非整体失败**（文件 chunk 超时二分拆分）——登记候选供未来 inventory-verify 大项目性能优化参考。
- **node id 不变 / 不重键既有图**（破坏性变更零容忍）——本仓 replay 规则不可变原则（WP-R12-D）同构。

### 2.6 impeccable v4.1 → `references/frontend-design-methodology.md`

- **对抗性 verdict**（多候选先内部比较再呈交；safer/bolder 沿熟悉-大胆轴定向重掷）。
  落地：frontend-design-methodology.md 增"对抗性 verdict"段；本仓 decisions.jsonl `alternatives` 字段已对齐（须列备选）。
- **证据坏则重取证重跑**（截图坏/缺时重拍重跑评审；拒绝假抠图 mask 冒充 cutout）。
  落地：frontend-design-methodology.md 增"证据完整性"段；本仓 inventory-verify `--path-check` HALLUCINATION 阻断同构。

### 2.7 codex-security v0.1.16 → `references/codex-security-methodology.md`

- **发现 → 外部 tracker 发布 → 关联持久化 → verify-fix 闭环**（Linear 深度集成 + 交互式修复 + 只读 verify-fix）。
  落地：codex-security-methodology.md 增"闭环管线"段；本仓 decisions.jsonl outcome 生命周期（WP-R12-D）+ trace-log.sh --decision 已对齐。
- **bulk-scan 每仓库强制 cost limit**——本仓无 bulk 场景，登记候选。

### 2.8 gstack v1.68.2 → `references/review-methodology.md` / fail-gate-hook 设计哲学

- **每个 guard 必须可证明会触发（否则删除）**（v1.64.1 净删 24,943 行的 guard 收紧波）。
  落地：review-methodology.md 增"guard 可证伪触发"段；本仓 self-check.sh 各 check_* 函数与 facts.conf 数字机器执法已对齐（facts 漂移即 fail）。
- **issue/PR 关闭附 receipt 证据**（v1.68.0 90 个过期 PR 带证据关闭）——本仓 trace-log.sh + decisions.jsonl 已对齐。
- **fail-closed hooks 三件套**（v1.66.1 content binding）——本仓 fail-gate-hook.sh + integrity-guard.sh + failure-detector.sh 三件套同构，已对齐。

### 2.9 ruflo 3.38.12 → 不吸收

SynthID-Text 风格的 LLM 文本水印（WASM crate + 浏览器/Deno ESM 入口）是新能力方向，但与 swarm-yuan 运行时无关（本仓无 LLM 文本生成场景）。仅升引用基线到 3.38.12（patch 列车跟随），不吸收。

## 三、不吸收清单（显式登记）

| 能力 | 来源 | 不吸收理由 |
|------|------|-----------|
| LLM 文本水印 SynthID-Text | ruflo 3.38.12 | 本仓无 LLM 文本生成场景 |
| Linear 深度集成（直连 API） | codex-security v0.1.13-15 | 本仓不绑定特定 tracker；decisions.jsonl 是本地 JSONL 而非外部 SaaS |
| task plan 完成判据机器执法 | openspec v1.10 | 本仓已有 `--verify-completeness` 占位符检测；完成判据属语义判断，GATE_AI_JUDGMENT 原则下不机械 grep |
| STATE 文件 commit 戳新鲜度检测 | gsd-core v1.11 | 登记候选（下一轮 WP）；本仓 state.yaml 当前由 state-machine.sh 管理，无新鲜度告警需求场景 |
| `.graphifyrc` viz_node_limit 烘焙 | graphify v0.9.47 | 本仓无 graphify 配置文件场景（graphify 是方法论引用层） |

## 四、候选登记（下轮触发条件）

| 候选 | 触发条件 | 预估工作量 |
|------|----------|-----------|
| state.yaml 盖 commit 戳 + 新鲜度检测（gsd-core v1.11） | 用户报"state.yaml 过期导致流程错位" | 小（state-machine.sh status 增 stale 告警） |
| inventory-verify 大项目超时二分降级（graphify v0.9.47） | 用户报"inventory-verify 大项目跑超时" | 中（_enum_count 加 timeout + 二分） |
| plan 完成判据模板字段（openspec v1.10） | 用户反馈"plan 没写怎么算完成" | 小（plan-template.md 加字段 + 文档） |
| api_key 命令解析模式（ocr v1.9.8） | 本仓未来接入 AI 工具需 secret | 小（precheck.conf 加 SECRET_CMD 模式） |

## 五、落地清单（本轮已做）

- [x] `docs/upstream-baseline.md` 全表更新（13→14 运行时，9 项升基线 + 1 项仍 drifted + 1 项仍 license-risk + 3 项已同步）
- [x] `docs/upstream-baseline.md` §二 关键结论 2026-08-21 重写
- [x] `docs/upstream-baseline.md` §三 comet 观望状态 2026-08-21 重核注记
- [x] `docs/upstream-baseline.md` §WP-Y 处置策略 2026-08-21 更新
- [x] `docs/runtime-update-2026-08.md` 本报告
- [ ] `references/review-methodology.md` 吸收 openspec/gsd-core/gstack 三点（下一 WP）
- [ ] `references/memory-persistence.md` 吸收 claude-mem 错误信封分类（下一 WP）
- [ ] `references/code-graph-tools.md` 吸收 graphify 幂等写入纪律（下一 WP）
- [ ] `references/frontend-design-methodology.md` 吸收 impeccable 对抗性 verdict + 证据完整性（下一 WP）
- [ ] `references/codex-security-methodology.md` 吸收 codex-security 闭环管线（下一 WP）
- [ ] `references/gsd-patterns.md` 吸收 gsd-core guard 可观测性（下一 WP）

## 六、验证

- `bash scripts/self-check.sh --check-only` 无 drift warn（除 comet 仍 drifted 为预期）
- 14 个 baseline_status 标记行齐全（13  synced/watch/license-risk + 1 drifted）

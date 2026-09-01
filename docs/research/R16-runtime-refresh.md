# R16：运行时四件套升级调研（claude-code / codex / dsh / better-harness，2026-09-01）

- 调研角色：R16 运行时升级分析员（swarm-yuan 项目深度调研团队）
- 调研日期：2026-09-01
- 触发：user message「更新 research 目录下运行时（包括 claude code、codex、deepseek harness 等工具的版本变化情况）到最新稳定版本，比较和上一版功能差异，然后整合吸收其功能理念，优化 swarm yuan skill 能力」
- 上轮基线：2026-08-21 A11 全量重核（claude-code v2.1.237 / codex v0.148.0 / dsh rc.8 / better-harness 0.6.4）
- 数据来源：npm registry dist-tags（2026-09-01 实测）、anthropics/claude-code CHANGELOG.md（raw 抓取）、本地克隆 git fetch + tag checkout + diff（codex@rust-v0.152.0 / dsh@dsh-v0.1.1-rc.2 / better-harness@v0.6.6）；codex 与 dsh 差异由两路子代理源码级调研（证据在其报告，本档为浓缩 + 裁定）
- 登记口径：本轮为**补核轮**（A11 系列运行时升级报告的 2026-09 篇 = README §6.6 A14），非新方法论轮——不新增 references 文档、不进 FACT_RUNTIMES 13/5、不新增 check_* 门禁（守 54 预算）

---

## 一、版本全景

| 运行时 | 上轮基线 | 最新稳定（2026-09-01） | 跨度 | 备注 |
|---|---|---|---|---|
| claude-code | v2.1.232 调研 / v2.1.237 R4 补核 | **v2.1.252**（npm latest，2026-08-31） | npm 15 版 / CHANGELOG 12 条 | **npm dist-tag 分裂：latest=2.1.252 / stable=2.1.236**（新发布通道） |
| codex-cli | v0.146.0 调研 / v0.148.0 R4 补核 | **v0.152.0**（2026-09-01 stable） | 4 stable，405 commits | v0.153.0-alpha.1 同日已出；docs/skills.md 零 diff |
| dsh | dsh-v0.1.0-rc.8（R12） | **dsh-v0.1.1-rc.2**（b150a551b，2026-08-21） | 207 commits | 功能线非修复线、无 breaking；master 已到 0.1.2-alpha.3（08-31，1430 commits） |
| better-harness | 0.6.4（R14） | 0.6.6（2026-08-31） | 2 patch | 纯方法论源，不入 16 运行时表 |

research/ 本地克隆已全部 checkout 到最新稳定 tag（gitignored 不入 git）。

## 二、Claude Code v2.1.238 → v2.1.252（CHANGELOG 全读）

**功能性新增**（纯修复版 240/241/245/250 不列）：

| 主题 | 版本 | 内容 |
|---|---|---|
| `--restricted` 锁定模式 | 248 | `CLAUDE_CODE_RESTRICTED=1`：移除执行类内置工具+WebFetch、文件工具限工作目录、拒绝 bypassPermissions、忽略 user/project/local settings |
| PreModelSwitch/PostModelSwitch hooks | 251 | 模型切换可 block/confirm/annotate；SessionStart resume hooks 增 staleness + re-cache 成本 |
| Workflow 工具 prompt 外置 | 248 | 工具描述 5.7k→1k token，脚本参考移入 bundled `workflow-authoring` skill |
| 子代理韧性/缓存 | 243/246/247/248/251 | maxTurns 撞限标 partial 可 SendMessage 续跑；404 走 fallback 模型链；frontmatter `experimental.cacheTtl`；settings `promptCacheTtl`/`subagentPromptCacheTtl`/`modelPicker`/`modelPricing`；`CLAUDE_CODE_SUBAGENT_MODEL` 改默认不覆盖；agent teams 队友终答达队长 |
| 沙箱/权限硬化波 | 246-252 | symlink TOCTOU（权限检查后换链读写越界）修复；沙箱 Bash 输出文件防重定向；`Bash(git * x)` 通配符告警；算术赋值/悬空算符畸形命令须批准；服务器托管设置弱化沙箱须批准；project settings `env` 禁设 `CLAUDE_CONFIG_DIR`/`TMPDIR` |
| hooks 错误可见化 | 246/248 | hook stdout 非法 JSON → 显式 hook error；后台会话点名失败 hook 与 schema 错误 |
| 跨会话/CLI 全面化 | 239/251 | Windows 补齐 SendMessage/ListAgents；`attach`/`logs`/`stop`/`respawn`/`rm` 子命令 |
| `/goal` 退避 | 239 | check-in 30min→1h→2h 退避（防检查成为负载） |
| SendFeedback 工具 | 247 | Claude 可起草反馈报告经用户审阅发送 |

## 三、Codex v0.149 → v0.152（子代理源码级调研浓缩）

- **Guardian v2 落地形态**：flag 默认 false 迭代；`--approve-for-me`（别名 `--not-so-yolo`）fail-closed 评审（90s 超时、严格 JSON）；**用户显式调用的 skills 受信任**（0.151，#41006）；过期风险分类权限变化后不授权（0.151）；跨 compaction 保留授权（0.152）。
- **skills token 预算**（0.149）：`[skills] max_context_tokens` 默认 2% 上下文、上限 10k（`codex-rs/config/src/skills_config.rs`）——技能目录进 prompt 前有截断 + 实验性路由（recent/character-routed/shadow）。
- **破坏性**：v0.150 untrusted 项目不加载项目级 AGENTS.md（#39837）；v0.152 planning 工具默认禁用需 `tools.update_plan.enabled`（#41744）。
- **Interrupt hook 事件**（0.150，#40511；hooks 共 11 事件，`codex-rs/hooks/src/schema.rs`）；extensions 可拦截/替换 MCP 工具结果（0.151）；安全波（config/sed 解析 fail-closed、Seatbelt/bubblewrap、app 签名校验）；会话资产化续（agents 仪表盘、queue、@mention 任务、per-tool `output_token_limit`）。

## 四、dsh rc.8 → 0.1.1-rc.2（子代理源码级调研浓缩）

1. **Authorization seam 三件套**（簇 A 补充）：键空间按所有者插件划界（`CredentialKey`=<scope>/<id>）/ flow 拥有写入（seam 校验提交而非存在性）/ 交互随请求走（headless 传 decline）/ 每 key 单飞（`ALREADY_IN_FLIGHT`）；`authorization/settled` 覆盖终态（`.agents/notes/implemented/architecture/2026-08-13-credential-records-and-authorization-flows.md`）。
2. **二版本模式**（簇 B 补充）：统一图片管线——历史存 provider 无关规范化附件（内容寻址），传输派生瞬态投影；批量"先全部验证再发布"（PR #2676）。
3. **投影态 schema 校验 + 坏态整 log 重建**（簇 B 升级论据）：`SessionProjectionStateMap` 带 `stateSchema`；persist opt-in 取消一律 checkpoint（#2702/#2730）。
4. **#2608 合而复撤**（簇 D 新样本）：permission PR 合入后 rc.2 整体回退+快照同步——"回退优先于带病修复"。
5. **0.1.2-alpha 方向**（alpha.1-3）：persistence per-record 布局 + 一对一迁移 + prepared sessions + **删 SQLite 后端（breaking）**；Agent Teams；api/*-controller + Remote 拆分；inspector。**裁定：等 0.1.2 rc 后另立一轮调研（R12 先例：rc 档才做产品层吸收）。**

## 五、better-harness 0.6.4 → 0.6.6（CHANGELOG 直读）

0.6.5/0.6.6 主体是 Harness Studio（双语工作台：Sessions/artifacts/Git 历史/Agent runs）与 Inspector 深化（Usage/Context 报告：模型调用数、cache reuse、上下文演进、compaction 边界）。可对账点：**"缺失证据不显示为零"**（unavailable evidence 不伪装成 0）——与本仓 gate-report missing_evidence 态"不插值不算分"（`scripts/gate-report.sh:118`）同语义，**对账通过，无新增落地单元**（R14 四单元已覆盖其审计面；Canvas/Studio 可视化维持不吸收裁定）。

## 六、吸收三问评审与落地

| # | 候选 | ①落到运行时条件？ | ②替换/叠加？ | ③六个月后谁引用？ | 裁定 |
|---|---|---|---|---|---|
| 1 | `--restricted` 环境前置诚实化 | 是——restricted 会话门禁全链失效，AI 须知交付断言不可作数 | 叠加（capabilities 文档补核段） | 生成技能时按环境前置引用 | 落地（文档层） |
| 2 | PreModelSwitch 挂点 | 条件未熟——无"弱模型越档"真实事故 | 候选登记 | adaptive-gating 升级轮 | 登记（触发条件写明） |
| 3 | Workflow 外置 skill 化 | 无实现——本仓 WP-P5 已同构 | 方向验证记录 | 引用层演进论证 | 落地（文档层注记） |
| 4 | Guardian 信任显式 skills | 是——结构化 PASS/FAIL 是宿主审批通用货币，gate-report 已产出 | 叠加（codex-methodology 补核段） | Codex hooks 接线轮 | 落地（文档层） |
| 5 | Codex 破坏性三处对账 | 是——逐条核实本仓无暴露面 | 对账结论 | install.sh/生成器维护者 | 落地（对账注记） |
| 6 | dsh 四项机制 | 三项为文档化原则、一项升级论据；二版本模式无独立渲染层可落 | 叠加（dsh-methodology §七） | 状态韧性/凭据治理演进轮 | 落地（文档层 + 1 候选） |
| 7 | bh missing≠zero | 已同构（missing_evidence 不插值） | 对账结论 | 证据态纪律引用 | 对账通过，零改动 |

**不吸收清单**：Harness Studio/Inspector 可视化（R14 裁定维持）；Codex Guardian 自动审批接线（flag 未默认开，等稳定）；dsh 0.1.2-alpha 全部（等 rc）；Claude Code Remote Control/ultrareview/自托管 runner（云端协作面，与本仓 bash+JSONL 链路正交）。

## 七、落地载体清单（本轮全部改动）

1. `references/claude-code-capabilities.md`：头部基线 v2.1.232→v2.1.252（口径精确化：npm 223 版/CHANGELOG 175 条 + stable 通道注记）+ §四 hooks 表 2 行（PreModelSwitch/PostModelSwitch）+ R16 补核段（8 小节）。
2. `references/codex-methodology.md`：R16 补核段（Guardian/skills 预算/破坏性两处/Interrupt/extensions/安全波/会话资产化）。
3. `references/dsh-engineering-methodology.md`：来源行升级（rc.8→补核至 0.1.1-rc.2）+ §七 0.1.1 增量（5 小节）+ §五候选表 +1 行（二版本模式）。
4. `README.md`：§6.7 17 份调研报告（R1-R16）；§6.4 表头日期口径化 + 重核口径注 + 三行（claude-code/codex-cli/dsh）升基线；§6.4 §三新增 3.4 R16 表；§6.6 档案 A1-A13→A1-A14 + A11 表加 R16 指针（原文不动）+ 新增 A14 报告。
5. `docs/research/R16-runtime-refresh.md`：本档。

## 八、验证

- `bash scripts/self-check.sh --check-only`：16 个 baseline_status 标记齐全、无新增 drift warn（R16 三行仍 synced）
- 吸收三问全过（§六）；门禁 54 不增；FACT_RUNTIMES 13/5、FACT_REFERENCES 41 均不变（补核轮不加新载体）
- research/ 三克隆 checkout 验证：`git describe` = rust-v0.152.0 / dsh-v0.1.1-rc.2 / v0.6.6

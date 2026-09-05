# 上游运行时基线（upstream-baseline）

> **物化注记（2026-09-01 终态重构）**：本表原在 `swarm-yuan/README.md` §9，随设计文档终态重构移出为独立登记表。
> 16 行 `baseline_status=` 机器锚逐字守恒；self-check 的漂移检测路径已同步指向本文件。

> 16 个上游运行时的许可证/版本基线/drift 状态登记表。

> 用途：登记 swarm-yuan 引用/吸收的 **16 个上游运行时**的许可证与版本基线，支撑供应链可审计性（ISO/IEC 5230 OpenChain 方向）与文档漂移治理。
> 数据来源：GitHub REST API + npm/PyPI registry **2026-08-21 实测**（本轮 R4 全量重核）；历史实测轮次见 `docs/research/R6-upstream-web.md` §0（2026-07-20）/ §13 历史档案 A10（原 runtime-update-2026-07，2026-07-26）/ 2026-08-14 轮。
> **重核节奏（R13 批次3，§4.5.5）**：从"每轮全量重核 16 个"改为**破坏性变更驱动**——上游 GitHub release 标 breaking/major 时触发重核 + 季度例行一次。重核是维护不是成长，砍全量形态给成长腾带宽。
> 机器可读契约：每个 drifted 条目所在行必须含字面漂移标记（行尾「机器标记」列，格式 baseline_status=状态值）；self-check 的轻量基线忠告仅 grep 漂移标记所在行并 warn（不联网）。
> 状态取值：`synced`（基线≈最新）｜`drifted`（基线落后，需重核）｜`watch`（迭代极快，持续观察）｜`license-risk`（许可证合规风险）。
>
> **本地缓存建议**：`swarm-yuan/research/` 下的上游 clone 仅供 AI 阅读源码（已 gitignored，不入 git），无需 commit 历史。建议用 `git clone --depth 1` 浅克隆——12 个 clone 的 `.git` 历史合计约 1.1GB，浅克隆可省 ~1GB 本地磁盘（ruflo/claude-mem/gsd-core/open-code-review 四个 `.git` 占比最高）。

### 一、16 运行时登记表

> **口径注（2026-08-21 R4）**：本表 16 行 = 供应链登记总口径（13 整合运行时 + dsh 纯方法论源 + claude-code/codex 两个核心安装目标 CLI）。SKILL.md 的"整合 13 个外部运行时"（`FACT_RUNTIMES=13`）是**接线分层口径**（深度 4 + CLI 4 + 方法论 5），两者语义不同：claude-code/codex 是 swarm-yuan 生成技能的**宿主**而非被整合对象，dsh 是方法论源而非运行时接线——三者不进 FACT_RUNTIMES 分层计数。
> **重核口径注（2026-09-01 R16）**：本轮为**全量重核**——16 行全部核实到最新稳定版（R16 初段四件套 + 用户要求扩展至 research/ 下全部第三方运行时）。结果：11 行升基线吸收（claude-code/codex-cli/dsh/gsd-core/claude-mem/ocr/graphify/gstack/ruflo/ECC/codex-security）、1 行仍 drifted 观望（comet 0.4.0-rc.1 正式版未出）、1 行仍 watch（claude-mem）、1 行仍 license-risk（GitNexus）、2 行对账通过无变化（superpowers/openspec 增量为 CLI 人体工学）、impeccable 有新 tag 但候选级暂不升基线。better-harness（纯方法论源，R14 起不入表）0.6.4→0.6.6 增量记入 `docs/research/R16-runtime-refresh.md`。
> **重核口径注（2026-09-05 R17）**：补核轮（距 R16 四天）——用户点名 claude-code/codex/dsh 三件套深审 + research/ 下其余克隆全量快审。结果：三件套升基线吸收（claude-code v2.1.261 / codex-cli rust-v0.153.4 / **dsh v0.1.2-rc.1——0.1.2 调研兑现 R16 预告**）+ 6 行升基线或登记（openspec v1.12.0 / claude-mem v13.24.0 / ocr v1.11.4 / ruflo v3.38.21 / codex-security v0.1.25 / GitNexus v1.6.11 stable 登记）+ comet 仍 drifted（rc.4 正式版未出）+ 5 行零增量（gsd-core/graphify/superpowers/gstack/ECC）+ impeccable 候选级维持（v4.1.3/v4.2.0 观察登记）。better-harness v0.7.0-alpha1 已出（证据上传端到端 + 原生 run streams，alpha 未稳维持 v0.6.6 不入表）。详见 `docs/research/R17-runtime-refresh.md`。

| 名称 | 仓库 | 许可证 | 引用基线 | 最新版（各行注明重核日期） | 状态 | 机器标记 |
|------|------|--------|----------|--------------------|------|----------|
| openspec | Fission-AI/OpenSpec | MIT | v1.12.0（2026-09-05 R17 升级；`references/review-methodology.md:130`） | npm 1.12.0（2026-09-03） | synced（2026-09-05 R17 重核；v1.12 增量仍为 CLI 人体工学（validate findings-only 批量报告/delta 合并冲突降级 informational/explore 引导先读代码/SourceCraft 适配/fast-uri 安全补丁），对账通过无方法论新机制） | baseline_status=synced |
| claude-code | anthropics/claude-code | 专有（Anthropic Commercial Terms；CLI 二进制分发，源码不开） | v2.1.261（2026-09-05 R17 补核；`references/claude-code-capabilities.md` 全量 159 版调研 + R4/R16/R17 三轮补核） | npm @anthropic-ai/claude-code latest 2.1.261（2026-09-04）/ stable 通道 2.1.236（dist-tag 分裂持续，stable 落后 25 patch，2026-09-05 观察） | synced（2026-09-05 R17 补核 v2.1.253-261（npm 9 版；253-256 无 changelog 条目）；吸收 `--permission-prompts none` 无头执法档（**prompt 档无人值守坍缩为 deny**——R13 三值化环境边界注记，双宿主无头对偶）+ **宿主 deny 语义漂移警示**（259 Read-deny 应用至 Bash 参数 260 即回退 + strict sandbox 下 `!` 命令出沙箱——自持门禁兜底教义再实证）+ `/skill-doctor` 技能成本审计（门禁预算宿主侧证据源）+ 子代理提示词外置/输出预算设置（上下文外置第四次验证）+ `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`（adaptive-gating 候选补全）+ Workflow schema 前置校验 + Containment Escape 规则） | baseline_status=synced |
| codex-cli | openai/codex | Apache-2.0 | rust-v0.153.4（2026-09-05 R17 补核；`references/codex-methodology.md` 省 token 三件套/review rubric/测试哲学执行纪律 + R4/R16/R17 三轮补核） | git tag rust-v0.153.4（2026-09-04）；npm @openai/codex latest 0.153.3（2026-09-04，npm 慢一 patch）；v0.154.0-alpha.3 在 alpha 通道 | synced（2026-09-05 R17 补核 v0.153.0-153.4（106 commits；0.153.1-4 共 7 个为 GPT-6-Astra 模型目录热修；docs/skills.md 连续第二轮零 diff；**无 v0.150 级破坏项**）；吸收 **Guardian 条件性兜底**（Full Access/User approval 模式跳过评分/评审——执法确定性论证必须落在自持门禁，宿主审批层不保证在场；与 Claude Code 260 deny 回退构成双宿主同向证据）+ `request_user_input_async` 回合中结构化问答原语（Interrupt 守护点候选正式参照，按模型可用性限定）+ hooks 内置白名单三层信任（builtin/managed/user——本仓用户级 PreToolUse 三能力接线对账零变化）+ context_management experimental_mode（ChatGPT 后端限定，登记观望）） | baseline_status=synced |
| comet | rpamis/comet | MIT | v0.3.9（`references/subagent-orchestration.md:118`） | 0.4.0-rc.4（2026-09-05 R17 核；rc.2-4 共 11 commits 全为稳定性修复，正式版未出） | drifted（观望维持——R17 复核：正式版仍未出，R16 裁决不变（rc 阶段 117k 行新子系统 churn + 升级破坏性大，等 stable 一次做对）） | baseline_status=drifted |
| GitNexus | abhigyanpatwari/GitNexus | **PolyForm Noncommercial 1.0.0**（禁商用，API 返回 NOASSERTION，LICENSE 原文实测） | npm 1.6.9（引用 `context/trace`） | GitHub v1.6.11 **stable**（2026-09-05 R17 核：rc.23→stable 收敛段 41 commits 含 Zig 语言支持/Spring 路由与消息目的地摄取/auto-sync 定时远程分析等实质功能；npm 停滞于 2026-06-09） | license-risk（stable 已出但 PolyForm 禁商用不变，仍非默认、不追；引用载体 `references/code-graph-tools.md` 许可证表已同步登记） | baseline_status=license-risk |
| gsd-core | open-gsd/gsd-core | MIT | v1.12.0（2026-09-01 R16 升级，next 分支；`references/gsd-patterns.md` + `references/decision-governance.md` R16 补核段） | npm 1.12.0（2026-08-30） | synced（2026-09-01 R16 升级；吸收 `.planning/state.json` 机器可读状态契约（planning inspect）+ `<fails_when>` 强制（**破坏性**：验收命令必须声明失败信号）+ 共识门证据加权（孤立 HIGH 须 source-grounded）+ 缺失≠VERIFIED 证据纪律 + 供应链 runtime-identity 断言；2026-09-05 R17 重核零增量） | baseline_status=synced |
| claude-mem | thedotmack/claude-mem | Apache-2.0 | v13.24.0（2026-09-05 R17 升级；`references/memory-persistence.md` R16 段 + R17 补核） | GitHub v13.24.0（2026-09-04；**npm latest 被回钉 12.4.7**——分发主通道切插件市场 `/plugin install claude-mem@thedotmack`，npm 为遗留/SDK 通道，oracle 以 GitHub tag 为准） | watch（迭代极快；2026-09-05 R17 升级 + 补核 v13.22-13.24：**#3838 熔断器事件形状修正**（rate_limit_event 判据与 SDK 真实消息形状不匹配——熔断判据须绑定上游真实事件形状，对账本仓门禁判据绑定真实退出码/产物，通过）+ Cursor/Grok Bot 多宿主分发不吸收） | baseline_status=watch |
| ocr | alibaba/open-code-review | Apache-2.0 | v1.11.4（2026-09-05 R17 升级；`references/review-methodology.md` R16 补核段） | v1.11.4（2026-09-04） | synced（2026-09-05 R17 重核：v1.11.2-4 基本纯修复（规则路由 ObjC++/.cxx/JS 模块、工具调用失败上报、SIGTERM 优雅退出、opt-in 原始 LLM 流量捕获 #1109），对账通过零改动；R16 语义分组/session compare/effort 三机制吸收不变） | baseline_status=synced |
| graphify | Graphify-Labs/graphify（原 safishamsi/graphify，已迁移） | Apache-2.0（2026-07-18 MIT->Apache 2.0，v0.9.25） | v0.9.53（2026-09-01 R16 升级，origin/v8 线；`references/code-graph-tools.md`） | GitHub v0.9.53（2026-08-30；npm 0.10.0 仍是 2026-06-06 异源旧分支不取，v1.0.0 同） | synced（2026-09-01 R16 升级 research 仓库到 v0.9.53（0.9.47→53 有 123 commits 持续活跃；升级引用基线，方法论载体无新机制不补段）；2026-09-05 R17 重核零增量，`code-graph-tools.md` 许可证事实同步 MIT→Apache-2.0） | baseline_status=synced |
| superpowers | obra/superpowers | MIT | v6.3.0（2026-08-14 升级；`references/subagent-orchestration.md` 修复环+5轮熔断 + brainstorming 仪式按任务规模缩放吸收 + `references/review-methodology.md` 可证伪性纪律吸收；**核心插件未 vendor**，离线包仅 marketplace 元数据；不 vendor 决策见 §13 历史档案 A8） | v6.3.0（2026-09-05 R17 重核，HEAD 仍 2026-08-12 b36e082 无新版） | synced（2026-09-01 R16 重核无变化，对账通过；2026-09-05 R17 重核零增量） | baseline_status=synced |
| gstack | garrytan/gstack | MIT | v1.77.0.0（2026-09-01 R16 升级，master commit e76f65a；offline-cache vendor `offline-cache/gstack/VERSION:1` 不动） | v1.77.0.0（2026-08-31 VERSION 文件递增；无 release 无 tag；2026-09-05 R17 重核 HEAD 仍 e76f65a 零增量） | synced（2026-09-01 R16 升级；吸收 v1.68.3-1.77 spawned 会话原语（GSTACK_SESSION_KIND=spawned 标记只信创建者/破坏性选项永不自动选/decisions 数组回执'nothing is decided invisibly'）+ ponytail 简化 lens 第八 lens + **fail-closed 的 wiring 层也会 fail-open**（GitHub run-step 默认无 pipefail，`PIPESTATUS[0]` 钉 wiring 测试）+ 门禁普查反不变式清幻影门禁；2026-09-05 R17 重核零增量） | baseline_status=synced |
| ruflo | ruvnet/ruflo（原 Claude Flow） | MIT | v3.38.21（2026-09-05 R17 升级；`references/subagent-orchestration.md:277`、`references/review-methodology.md` R16 补核段） | npm 3.38.21（2026-09-04，npm 与 git tag 对齐） | synced（2026-09-05 R17 升级；v3.38.21 单 patch（memory bridge registry 种子修复/meta-proxy 陈旧 owner 修复），对账通过；R16 dream cycle 候选登记不变；方法论引用层，无运行时调用） | baseline_status=synced |
| ECC | affaan-m/ECC | MIT | v2.2.0（2026-09-01 R16 升级；`references/subagent-orchestration.md` R16 补核段） | v2.2.0（2026-08-31） | synced（2026-09-01 R16 升级；吸收 Plan Canvas 监听纪律（await 真实驻留才可达/canvas 内必答/stop hook 兜底未投递反馈——上轮 Plan Canvas 吸收的机制补强）+ 'skills over MCP' 政策（默认 MCP 6→1 个）候选单行 + 安装所有权台账/发布 fail-closed（staging dist-tag 验证 registry 字节）；2026-09-05 R17 重核零增量） | baseline_status=synced |
| impeccable | pbakaus/impeccable | Apache-2.0 | v4.1.1（2026-08-21 升级；`references/frontend-design-methodology.md`，方法论引用层第 5 对象；Modes/三层权威/craft-floor/59 反模式字典/finish_reviewer 完工审查模式 + v4.1 对抗性 verdict 多候选先内部比较再呈交 + 平台感知验证 + 证据坏则重取证重跑；G13 断言守引用存在性） | skill-v4.2.0（2026-09-04 GitHub 实测；v4.1.3 2026-09-02） | synced（2026-09-05 R17 观察 v4.1.3/v4.2.0：Comps 可执行契约阶段门 + **录制回放钉行为**（830 命令 + 16058 函数调用逐字节比对——与本仓 cli-ab 逐字节等价断言同构）+ 统一规则引擎/无 Node 依赖单二进制——候选级维持，引用基线不升（R16 裁决沿用），候选登记 `references/review-methodology.md` R17 段） | baseline_status=synced |
| codex-security | openai/codex-security | Apache-2.0（完全开源） | npm-v0.1.25（2026-09-05 R17 升级；`references/codex-security-methodology.md`，CLI 接线层第 4 对象；**AI 约束推理扫描（非传统 SAST）** + source→sink 数据流 + 静态评估七元组 + 威胁模型五要素 + scan contract 三件套 + **15 bundled skills**（v0.1.17+ 新增 assess-patch-risk）+ Docker 沙箱范式；`--sast-deep` 门禁 `SAST_DEEP_TOOL=codex-security` 时显式调用，**非降级链一环（非 SAST，auto 降级链不变，两者正交可并行）**；G15 断言守 CLI 接线存在性） | npm-v0.1.25（2026-09-04） | synced（2026-09-05 R17 升级 v0.1.25：**跨扫描发现关系保留**（findings 生命周期跨扫描延续，new/persisting/resolved 关系不因重扫丢失）+ sealed 扫描目录去重 + 去重评审阶段加固——工程设施对账通过，methodology §十二版本注记；R16 assess-patch-risk 候选登记不变） | baseline_status=synced |
| dsh | deepseek-ai/deepseek-harness | MIT | dsh-v0.1.2-rc.1（2026-09-05 R17 升级；`references/dsh-engineering-methodology.md` 四簇吸收 + §七 0.1.1 + §八 0.1.2） | dsh-v0.1.2-rc.1（a66e47020，2026-09-03；0.1.3-alpha.1 已出现——主线继续） | synced（2026-09-05 R17 升级，0.1.2 调研兑现 R16 预告（1735 commits / 8 breaking，功能线）：**跨版本读兼容三件套**（compatibleVersions 按域声明 + backup-and-skip 坏记录改名跳过域照常打开 + 真实构建盘面归档夹具——缓存格式演代谱系）+ **删 SQLite 后端迁移纪律**（显式兼容切断 + 旧构建导出出口契约 + per-record 归档原子替换——簇 D"删减纪律"新样本）+ `<domain>/<reason>` 失败词表单点声明（簇 A 补强）+ Agent Teams 孵化围栏（experimental 私包机械排除发布集 + 晋升需具名 owner 接盘）；均方法论补核段落地，机械落地触发条件未变（§五候选挂真实事故）） | baseline_status=synced |

### 二、关键结论

1. **许可证风险（最高优先）**：GitNexus = PolyForm Noncommercial 1.0.0，禁止商业使用。冻结措辞（全仓库统一引用）：**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（Apache-2.0，2026-07-18 MIT->Apache 2.0）提为默认代码图谱工具。**
2. **版本漂移（1 项 drifted，2026-09-05 R17 重核后）**：comet 0.3.9→0.4.0-rc.4（仍观望——rc.2-4 全为稳定性修复，正式版未出；R16 裁决沿用）。R17（2026-09-05）补核轮把 claude-code/codex-cli/dsh 三件套升基线（dsh 0.1.2 调研兑现 R16 预告）+ openspec/claude-mem/ocr/ruflo/codex-security 5 项升级、GitNexus v1.6.11 stable 登记（详见各条目吸收注记 + §13 历史档案 A15 + `docs/research/R17-runtime-refresh.md`）。
3. **watch（1 项）**：claude-mem 迭代极快（13.15.3→13.24.0，15 天 9 个 minor），持续观察；**npm 通道异常已澄清（2026-09-01）**：npm `latest` dist-tag 被人为回钉 12.4.7，官方分发主通道切 Claude Code 插件市场（`/plugin install claude-mem@thedotmack`）+ cmem.ai，npm 为遗留/SDK 通道——版本 oracle 一律以 GitHub tag 为准，npm 引用须显式钉版本。
4. **org 迁移**：graphify 仓库已迁至 Graphify-Labs/graphify，引用一律用新 URL；npm `graphifyy` 0.10.0 仍是 2026-06-06 异源旧分支（与 v1.0.0 同族），**跟踪线以 GitHub v8 分支为准（v0.9.53，持续活跃）**。
5. **存续风险**：16 个运行时中个人/小团队项目占比高（comet/GitNexus/claude-mem/gsd-core），上游存续监测纳入审计例程；GSD v1 上游（gsd-build/get-shit-done）已于 2026-06-26 归档，引用 open-gsd/gsd-core 为既定应对；GitNexus 2026-09 恢复活跃（v1.6.11 stable 已出）但 license-risk 不变。
6. **gstack 版本递增节奏**：v1.60.1.0（2026-08-14 基线）→ v1.68.2.0（08-20）→ v1.77.0.0（08-31）18 天 17 个 minor；本仓引用为 vendor 离线包，离线包内容不升级（vendor 决策见 §13 历史档案 A8），只升引用基线。

### 三、CLI 侧版本差异专题（2026-08-21 R4 补核：Claude Code + Codex）

两个 AI CLI 是 swarm-yuan 的核心安装目标（install.sh 检测 7 工具中最重要的两个），单列差异分析：

#### 3.1 Claude Code v2.1.232 → v2.1.237（五版，2026-08-14 至 08-20）

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Todo/Task 工具默认移除** | v2.1.233 | TaskCreate/Get/Update/List、TodoWrite 在 Opus 4.8、Sonnet 5、Fable 5、Mythos 5 及更新模型上默认不可用；`CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 恢复 | **破坏性**：生成的 SKILL.md 若依赖 TodoWrite 跟踪门禁进度，在新模型上会失效——目标技能的进度跟踪须走 trace-log.sh（本仓自有链路），不依赖 CLI Todo 工具 |
| `ANTHROPIC_DEFAULT_MODEL` | v2.1.236 | 设定新会话起始模型（区别于 `ANTHROPIC_MODEL` 的强制语义）；`/model` 选择可覆盖并跨重启持久 | install.sh 检测后可为不同能力档模型生成不同强度的门禁提示（登记候选） |
| `notify_when_idle`（SendMessage） | v2.1.236 | 请求本机另一个 Claude Code 会话在下次空闲时发一条通知——opt-in、一次性、无轮询 | 跨会话异步协作原语：未来"门禁长跑完成后通知主会话"可走官方机制而非轮询（登记候选） |
| **"Concise" output style** | v2.1.237 | 内置简洁输出风格：直接给结果、跳过开场白和叙述 | 与门禁驱动开发契合（跑门禁-看结果-修复，无需叙述）；生成技能的使用文档可推荐 |
| 沙箱通配符 read-deny | v2.1.236 | macOS 沙箱 `**/.env` 类规则在 allowed read 区域内优先生效、无法通过重命名绕过 | 目标技能的敏感信息保护可利用（settings.local.json deny 规则更强了） |
| `claude-api` 技能 200k→25k | v2.1.234 | 参考文档改为按需加载，上下文成本降 87.5% | **样板**：swarm-yuan references/ 的"按需读取引用索引"（WP-P5）正是同构机制，方向验证 |
| Bash 工具内存限制 | v2.1.233 | Linux 上 `CLAUDE_CODE_TOOL_MEMORY_LIMIT` opt-in cgroup 限制，防失控 build 拖死会话 | 生成的 precheck.sh 若含大构建命令，可建议配置（目标技能文档提示） |
| 用量限额自动续会话 | v2.1.234 | 限额重置后自动继续（`/config` 可关） | 运维便利性，无直接吸收 |

**评估**：Claude Code 在把"过程管理"内化——Todo 工具移除（模型自身管任务）、Concise style（砍叙述）、权限精确化。swarm-yuan 的门禁进度跟踪走自有 trace-log 链路（不依赖 CLI Todo），方向正确。

#### 3.2 Codex v0.146.0 → v0.148.0（两 stable，2026-08-07 / 08-18）+ v0.149-alpha 预告

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Agent Plugins** | v0.147 | 可移植插件安装，跨 local/personal/workspace/remote 四类目录搜索 | 生成技能的分发新通道：打包为 Codex 插件而非仅放 `~/.codex`（登记候选） |
| **`--approve-for-me`** | v0.147 | CLI flag 自动审批的正式入口 | Guardian 审批体系入口；高危门禁命令可标注给自动审批分类器（观察项） |
| **hooks 异步命令 + MCP 工具调用** | v0.148 | Codex hooks 支持 async 执行 + 调 MCP 工具 | **重要机会**：precheck 门禁可注册为 Codex hook 而非仅靠 prompt 约定——门禁"执法"在 Codex 侧获得官方强制点（登记候选，下轮评估） |
| `/export` 会话导出 | v0.148 | TUI 会话完整导出 Markdown | 门禁验收记录可随会话导出留档（契合 ai-process-records 方法论） |
| 会话 fork/归档/排队消息 | v0.148 + v0.149-alpha | `codex exec fork`、归档恢复、排队消息分发 | 会话资产化；多会话工作流原语 |
| **skill-creator validation 拒绝 TODO 占位符** | v0.148 | 内置技能验证不再通过未完成 TODO | 本仓 `--verify-completeness` 零占位符检测同构，方向验证 |
| **移除 `codex exec --full-auto`** | v0.147（**破坏性**） | 改用 `--sandbox workspace-write` | install.sh 对 Codex 目标的检测逻辑应查版本 ≥0.147；生成脚本禁用 `--full-auto` |
| 移除技能模型委托 | v0.149-alpha（预告） | skills 不能再指定委托模型 | 生成的 SKILL.md 若有按子任务指定模型的设计需提前去依赖（本仓无此设计，无影响） |
| Guardian v2 审批体系 | v0.149-alpha | 风险分类改进、transcript 图像审查、风险评分 fail-closed、默认跳沙箱命令 | 审批自动化基础设施成形；观察 `--approve-for-me` 成熟度 |
| 安全加固密集波 | v0.149-alpha | apply_patch 不扩大写权限、Seatbelt 防重命名、AGENTS.md 加载权限校验、skill 安装防 symlink、"Git 命令不再天然安全" | 沙箱边界持续收紧；本仓 fail-gate-hook 的 Bash 推进态拦截方向一致 |

**评估**：Codex 在补"可信自动批准"基础设施（Guardian）+ 会话资产化（fork/归档/导出）。hooks 支持 MCP 工具调用是本仓门禁在 Codex 侧获得官方强制点的最重要机会。

#### 3.3 共同信号：过程管理从 prompt 约定下沉为运行时机制

两个 CLI 都在把"过程管理"（任务跟踪/审批/输出风格）从 prompt 约定下沉为运行时机制。swarm-yuan 的"特征卡立法 + 门禁执法"分层正依赖此方向——门禁从 bash 脚本 + prompt 约定逐步迁移到各 CLI 的官方 hook/审批机制，是未来 1-2 个版本最值得投入的适配线。

#### 3.4 R16 补核（2026-09-01）：Claude Code v2.1.238→252 + Codex v0.149→152 + dsh/better-harness

> 纯修复版不列；逐条细节在 `references/claude-code-capabilities.md` / `references/codex-methodology.md` / `references/dsh-engineering-methodology.md` R16 补核段。

**Claude Code v2.1.238 → v2.1.252（npm 15 版，2026-08-14 至 08-31；npm dist-tag 分裂 latest=2.1.252 / stable=2.1.236）**

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **`--restricted` 锁定模式** | v2.1.248 | 移除执行类内置工具+WebFetch、文件工具限工作目录、拒绝 bypassPermissions、忽略 user/project/local settings | **环境前置诚实化**：restricted 会话=门禁失能会话（全链依赖 Bash），交付断言不可作数；生成技能本就声明 Bash 前置，无需改 |
| **PreModelSwitch/PostModelSwitch hooks** | v2.1.251 | 模型切换前后可 block/confirm/annotate | 模型切换首次成为可治理点——adaptive-gating.sh 分档硬执法的官方挂点（登记候选，触发=弱模型越档真实场景） |
| **Workflow 工具 prompt 外置** | v2.1.248 | 工具描述 5.7k→1k token，脚本参考移入 bundled skill | 上下文外置 skill 化的第三次官方验证（v2.1.234 claude-api 200k→25k、本仓 WP-P5 同构） |
| 子代理韧性/缓存 | v2.1.243/246/247/251 | maxTurns 撞限标记 **partial** 可 SendMessage 续跑；404 走 fallback 模型链；frontmatter `cacheTtl` + `promptCacheTtl`/`subagentPromptCacheTtl`；`CLAUDE_CODE_SUBAGENT_MODEL` 改默认不覆盖 | "完成"与"中途停"不再混淆——gate-report 证据态分级（partial 语义）方向验证；子代理编排 references 更新 |
| 沙箱/权限硬化波 | v2.1.246-252 | symlink TOCTOU（权限检查后换链读写越界）修复；沙箱 Bash 输出文件防重定向；Bash 通配符 allow 规则告警；畸形命令一律须批准；project settings `env` 禁设 `CLAUDE_CONFIG_DIR`/`TMPDIR` | 目标技能 settings 模板禁用 `Bash(git * x)` 模式；与 Codex v0.150 硬化波同期同向 |
| hooks 错误可见化 | v2.1.246/248 | hook stdout 非法 JSON → 显式 hook error；后台会话点名失败 hook 与 schema 错误 | fail-gate-hook 输出纪律（纯文本/合法 JSON）对齐无虞 |
| `/goal` check-in 退避 | v2.1.239 | 30min→1h→2h 退避，防检查本身成为负载 | R14 goal_id/closure 闭环同构印证 |
| CLI 子命令扩充 | v2.1.251 | `attach`/`logs`/`stop`/`respawn`/`rm` 后台会话生命周期 | 运维便利，无直接吸收 |

**Codex v0.148.0 → v0.152.0（四 stable，08-20 至 09-01；v0.153.0-alpha.1 已出）**

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Guardian 落地形态** | v0.149-152 | flag 默认 false 迭代；`--approve-for-me`（别名 `--not-so-yolo`）fail-closed 评审；**用户显式调用 skills 受信任**（0.151）；过期分类不授权（0.151）；跨 compaction 保留授权（0.152） | 门禁产出的结构化 PASS/FAIL 结论可被 Guardian 引用为 trusted context——证据态输出与宿主审批体系咬合 |
| **skills token 预算** | v0.149 | `[skills] max_context_tokens`（默认 2% 上下文、上限 10k）+ 实验性技能路由 | 技能目录进 prompt 前有预算截断——生成技能 frontmatter 须紧凑（已满足），多技能项目须知目录 token 成本 |
| **untrusted 不加载项目 AGENTS.md** | v0.150（**破坏性**） | untrusted 项目忽略项目级 AGENTS.md | 本仓 install.sh 用户级（`~/.codex/skills`）安装无暴露面；生成器不写项目根 AGENTS.md |
| **planning 工具默认禁用** | v0.152（**破坏性**） | 需 `tools.update_plan.enabled = true` | 目标技能自备 spec/plan 文件不依赖宿主 plan 工具，无影响 |
| **Interrupt hook 事件** | v0.150 | 命令/MCP handler/顶层 turn 被打断时触发（11 事件之一） | "打断后半成品检查"守护点候选（与 R4 hooks 接线候选同批评估） |
| extensions 拦截 MCP 工具结果 | v0.151 | 插件可改造其他来源的工具输出 | 中间层治理位，观察项 |
| 安全加固波 | v0.150 | config/sed 解析 fail-closed、Seatbelt/bubblewrap 加固、app 签名校验 | 与 Claude Code 同期收紧沙箱，双宿主同向 |

**dsh rc.8 → 0.1.1-rc.2 + better-harness 0.6.6**：dsh 0.1.1 是功能线（207 commits）——Authorization seam 三件套 / 二版本模式（规范形 vs 派生投影）/ 投影态 schema 校验+坏态整 log 重建 / #2608 合而复撤；master 已到 0.1.2-alpha.3（persistence per-record + 删 SQLite + Agent Teams），**等 0.1.2 rc 后另立一轮调研**。better-harness 0.6.5/0.6.6（Harness Studio 双语工作台 + Inspector 用量/上下文报告）中"缺失证据不显示为零"与本仓 missing_evidence 态对账通过，无新增落地单元。

**评估**：CLI 双雄的 R16 信号是 §3.3 判断的延续与具体化——Claude Code 把"模型切换"和"restricted 降级"纳入治理面，Codex 把"审批信任"延伸到"用户显式调用的技能"。对 swarm-yuan 最实的两条：①生成的技能产出结构化证据（PASS/FAIL/证据态）正在成为宿主审批层的通用货币；②两个宿主同期收紧沙箱/权限边界，目标技能的 hooks/settings 模板须保持最保守形态。

#### 3.5 R17 补核（2026-09-05）：Claude Code v2.1.253→261 + Codex v0.153.0→153.4

> 纯修复版不列；逐条细节在 `references/claude-code-capabilities.md` / `references/codex-methodology.md` R17 版本注记段。dsh 0.1.2-rc.1 详审见 §八（dsh-engineering-methodology）与 `docs/research/R17-runtime-refresh.md`。

**Claude Code v2.1.253 → v2.1.261（npm 9 版，2026-09-01 至 09-04；latest/stable 分裂持续）**

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **无头执法档 `--permission-prompts none`** | 259 | 一切本会弹审批的操作自动拒绝 | Claude 侧无头执法入口，与 Codex exit-2-deny 组成双宿主对偶；**prompt 档无人值守坍缩为 deny**——R13 三值化的环境边界，登记 adaptive-gating 候选注记 |
| **宿主 deny 语义漂移** | 259→260 | 259 将 Read deny 应用至 Bash 参数，260 即回退（误伤 `npm run build`）；260 起 strict sandbox 下 `!` bash-mode 出沙箱 | **宿主治理层整体视为条件性、版本间不保证稳定**——自持 55 门禁是执法主体的教义再获实证；hooks/settings 模板不得把宿主 deny 当执法主体 |
| `/skill-doctor` 技能成本审计 | 261 | 报告未使用技能及其上下文成本 | 55 门禁预算与特征卡裁剪的宿主侧证据源（纯登记） |
| 提示词外置 + 输出预算 | 261 | `--append-subagent-system-prompt-file`；`bashOutputMaxChars`/`taskOutputMaxChars`（inline 上限 128K） | 上下文外置第四次官方验证；工具输出的上下文经济学成宿主一等配置 |
| 子代理模型强制/越界读取管控 | 257 | `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`；`permissions.blockReadsOutsideWorkingDirectories` | R16 模型切换治理挂点的强制档补全；worktree/子代理隔离宿主侧支撑 |
| Workflow schema 前置校验 | 260 | `agent({schema})` 拒绝永不可满足的 schema，retry 错误带最后校验失败 | 结构化输出 fail-fast，与 gate-report 证据态同向印证 |
| Containment Escape 规则 | 257 | auto mode 不自动批准元凭据抓取/出口规避 | 宿主红线收紧，与 last-good 红线同向 |

**Codex v0.153.0 → v0.153.4（106 commits；0.153.1-4 为 GPT-6-Astra 模型目录热修；无 v0.150 级破坏项）**

| 主题 | 版本 | 内容 | 对 swarm-yuan 的影响 |
|------|------|------|---------------------|
| **Guardian 条件性兜底** | 0.153.0 | Full Access/User approval 模式跳过 Guardian 评分/评审（活动中途切换亦然） | **执法确定性论证必须落在自持门禁**——宿主审批层不保证在场；与 Claude Code 260 deny 回退双宿主同向，R13 fail-open 兜底教义升级 |
| 回合中结构化问答 | 0.153.0 | `request_user_input_async`（带建议答案、回合继续、按模型可用性限定） | Interrupt 守护点候选的正式参照（打断→问答→续跑）；登记候选 |
| hooks 三层信任 | 0.153.0 | bundled cleanup hooks 标 `builtin: true`，直接 Trusted 且无视 per-hook enabled | 信任模型三层化（builtin/managed/user）；本仓用户级接线对账零变化 |
| context_management 实验模式 | 0.153.0 | token 预算上下文 + history notes + `new_context` 工具（仅 ChatGPT 后端） | 与 `[skills] max_context_tokens` 相邻的预算机制；experimental 观望 |

**评估**：R17 的双宿主信号收敛为一句话——**宿主的治理能力（审批/deny/评分）都在变得"条件性"**：Claude Code 的 deny 规则会回退、Codex 的 Guardian 会在宽松模式下缺席。目标技能的执法确定性只能锚在自持门禁上，宿主治理层一律按"可能有、可能没有"设计。这把 §3.3 的"下沉机会"补上了边界条件：下沉的是**挂点**（hook 事件/审批通道），不是**执法责任**。

### 四、comet 0.4 能力重核结论（P1-7，2026-07-20 实测）

**结论：观望**——引用基线保持 v0.3.9，状态维持 drifted；待 0.4.0 正式版发布后升级为 v0.4.x 并同步修订 `references/subagent-orchestration.md` 的 v0.3.9 能力清单。

#### 4.1 重核事实（0.3.9 → 0.4.0-beta.x 的实际变化）

来源（均 2026-07-20 访问）：

- npm registry：dist-tag latest=0.4.0-beta.6（2026-07-20 发布；beta.1 始于 2026-07-07，14 天 6 个 beta）——https://registry.npmjs.org/@rpamis/comet
- 0.4.0-beta.1 全量说明——https://raw.githubusercontent.com/rpamis/comet/master/NEWS.md
- beta.2–beta.6 增量——https://raw.githubusercontent.com/rpamis/comet/master/CHANGELOG.md
- 0.3.x 系列发布说明——https://github.com/rpamis/comet/releases

**状态机**：Bash 脚本层 → 跨平台 Node 运行时（`.mjs` launcher + 共享 `comet-runtime.mjs`，不再要求 Git Bash/WSL）；机器检查点从 `.comet.yaml` 分离到 `.comet/run-state.json`（用户可编辑字段仍留 YAML）；新增稳定 CLI `comet state|guard|handoff|archive`（beta.4），agent 不再依赖内部安装脚本路径；`comet state rebind` + isolation 绑定分支漂移检测（beta.6）。

**硬前置**：verify-pass 仍要求 verification_report 指向存在文件 + branch_status=handled（0.3.9 语义保留）；新增 artifact 语言守卫 fail-closed（language 非法即拒，beta.1）；归档最终用户确认记入机器态、未确认拒绝变更性归档，防止直接调脚本绕过确认（beta.4）；isolation 漂移在 build/verify/archive 入口检查与写守卫处一律拦截（beta.6）。

**证据链**：阶段迁移写 `.comet/state-events.jsonl` 审计历史（beta.1）；无 npm/Maven/Cargo 推断命令的项目可登记可审计 build/verify 证据，替代原先未文档化的跳过路径（beta.4）；verify 失败自动回 Build 前 3 条可执行发现、连续失败计数跨恢复持久化、CRITICAL/IMPORTANT 不可豁免（beta.5）。

**吸收面之外的新能力**（登记备查，不构成本仓引用）：`/comet-any` Skill Creator、`comet eval`（pass@k/pass^k 评估）、`comet dashboard` 本地只读看板（beta.1 起）。

#### 4.2 观望理由

1. **0.4 仍在 beta 通道快速收敛**：14 天连发 6 个 beta，语义仍在变动（beta.3 移除自定义 guard 命令字段、beta.6 改 isolation 绑定语义），现在升级引用基线等于追移动目标。
2. **swarm-yuan 对 comet 是方法论级引用，非运行时调用**：`SKILL.md:108` 允许 CLI 清单不含 comet；`assets/state-machine.sh` 是自实现的「comet 风格」状态机。Bash→Node 迁移不造成功能性破坏；已吸收核心理念（脚本背书状态机、无证据不流转、handoff SHA256）在 0.4 全部保留且增强。
3. **能力清单形态已过时但语义未失效**：`references/subagent-orchestration.md:116-118` 登记的 7 个 `.sh` 脚本（comet-guard.sh 等）在 0.4 变为 `.mjs` launcher + 稳定 CLI；升级引用基线时需同步重写该清单，与正式版升级一并进行更经济。

**复审触发条件**：npm dist-tag latest 出现 0.4.0 正式版（非 beta/rc）→ 升级引用基线为 v0.4.x、状态改 synced、重写能力清单（.mjs launcher + run-state.json/state-events.jsonl + 稳定 CLI `comet state|guard|handoff|archive` + Hook Router 架构 + isolation 绑定语义）。

**2026-09-01 R16 重核**：0.4.0-rc.1（2026-08-31，npm latest 已是 rc）正式版仍未出，维持观望。R16 裁决依据：①20 beta + 1 rc，rc 阶段仍落地 117k 行新子系统（Personal Memory/Project Knowledge/Agent Learning Loop，#353 squash 575 文件），rc→stable 大概率继续 churn；②升级破坏性大（`references/subagent-orchestration.md:116-118` 的 7 个 `.sh` 清单全失效变 `.mjs`+Hook Router），等 stable 一次做对；③发布节奏 weekly，等待成本低。0.4 机制级新增（Supervisor Change v2 多 session 依赖子图分派 / Portable State 跨设备换 agent 恢复 / Agent Learning Loop 结果记录→有界反思→偏好沉淀）登记候选，见 §13 历史档案 A14。

**2026-09-05 R17 重核**：0.4.0-rc.4（rc.2-4 共 11 commits 全为稳定性修复：Archive 续跑死循环、native 内存/清理、workflow 恢复），正式版仍未出，观望维持、裁决不变。本地克隆已 checkout 到 rc.4 供跟踪。

**2026-08-21 R4 重核**：0.4.0-beta.18（2026-08-13）仍 beta 通道，14 天 6 beta → 38 天 18 beta，发版节奏加快但正式版未出。维持观望结论；beta.4-18 间新增 `.comet/run-state.json` 与 `.comet/state-events.jsonl` 分离、稳定 CLI `comet state|guard|handoff|archive`、verify 失败回 Build 前 3 条可执行发现 + 连续失败计数持久化、CRITICAL/IMPORTANT 不可豁免、isolation 漂移在 build/verify/archive 入口与写守卫处拦截——这些与本仓 fail-gate-hook.sh 的 flag 捕获模型 + R12-A 全量审计 + R3-2 last-good 红线机器执法语义对齐，理念已在自实现路径落地，无需追 beta。

### WP-Y：自动化 drift 检测

上述 `baseline_status=drifted` 的 1 项（comet，2026-08-21 重核后仍观望；其余 8 项本轮已升级为 synced）现在由 `--upstream-baseline` 门禁自动检测。
门禁扫描本文件的 `baseline_status=` 标记，drifted 项 warn 提示（advisory 级，不阻断交付）。

**处置策略**（2026-08-21 R4 更新）：
- **comet**：0.4.0 正式版发布后升级引用基线（swarm-yuan 对 comet 是方法论级引用，state-machine.sh 是自实现的 comet 风格状态机，升级不阻塞）
- **graphify**：2026-08-21 已升级 research 仓库到 v0.9.47（Apache 2.0，origin/v8 线）并吸收 OCaml/CommonLisp 语言扩展 + no-op 产物字节一致幂等写入 + 超时二分降级（**不取 v1.0.0 异源旧分支**——2026-04-05 发布，与 v0.9.47 diverged）
- **gstack**：2026-08-21 升引用基线到 v1.68.2.0（vendor 离线包内容不动——仍 v1.60.1.0 时代码快照；只升引用基线反映"跟踪到哪个上游版本"）
- **ruflo**：2026-08-21 升引用基线到 npm 3.38.12（npm 领先 GitHub release，以 npm 为准）

升级基线时：更新本表"引用基线"列版本号 → 将 `baseline_status=drifted` 改为 `baseline_status=synced` → 跑 `bash scripts/self-check.sh --check-only` 确认无 drift warn。

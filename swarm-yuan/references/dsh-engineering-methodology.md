> **何时读我**：设计审计/状态韧性/增量自成长机制时。DeepSeek Harness rc.8 产品层吸收——配对决策审计/状态韧性/增量自成长/工程纪律。

# dsh 工程机制方法论（DeepSeek Harness 产品层吸收）

> 来源：[DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) @ `141eb6fe`（2026-08-19，tag `dsh-v0.1.0-rc.8`，developer preview）。调研报告：`docs/research/R12-dsh-rc8-resurvey.md`（证据到包/文件级）。
> 与 `cordis-composability-methodology.md` 的分工：那份吸收 Cordis **框架层**（时空可组合性：可逆效应 + 响应式依赖，论文级）；本文吸收 dsh **产品层**工程机制（决策审计/状态韧性/增量感知/工程纪律，源码级）。论文无新版（2026-08-13 草稿），理念层无增量。
> 纪律：只引用方法论模式与设计视角，不调任何上游 CLI/运行时；不复制源码（上游克隆在 `swarm-yuan/research/dsh/`，gitignored）。守决策 26/27：不新增 `check_*`，门禁总数保持 55（决策 26.2）。
> 适用场景：目标技能与生成器自身的 hook/门禁审计、状态机与日志韧性、自成长链（项目变化感知→清单更新）、复盘与决策治理设计。

---

## 一、决策审计（簇 A）

### 1.1 配对审计事件（✅ 已落地 -A）

dsh `hook-protocol/src/events.ts`：每次门禁触发写 `invoked` + 配对 `result` 两行，稳定 `handlerId`（配置派生，非随机 UUID）关联，决策派生规则统一 `output.decision ?? (continue===false?'stop':'pass')`——**解析失败也落一行 pass，不丢记录**；stderr 摘要截断 500 字符；全部 log-only 不进模型上下文。

bash 映射（本 hook 是同步单次进程，无异步生命周期，配对折叠为单行自包含记录）：`.swarm-yuan/gate-audit.jsonl` 每决策点一行 `{ts,handler,tool,decision,reason,target,gates}`，pass 也落行（豁免/非白名单），`--report` 输出拦截率。**关键纪律：审计总体 = "门禁红期间的决策点"，不是全量工具调用日志**（休眠不写，体积纪律）。

### 1.2 按秩折叠的最严合并（📖 文档化原则）

dsh `hook-protocol/src/merge.ts`：多规则命中同一拦截点，串行执行后按 `deny > ask > allow` 定秩折叠；**只有获胜秩的理由浮出水面**（deny 赢了不混入 warn 理由）；空输出折叠为中性 `none`。决策与注册顺序无关，审计可复现。

bash 映射：目标技能的 `hooks.json` 在同一 matcher 挂多个 hook（如 PreToolUse: precheck --scope / integrity-guard / fail-gate-hook）时，**文档约定**：各 hook 独立决策，宿主（Claude Code）任一 deny 即拦截；本仓 hook 的输出文案不应互相引用对方判定（各说各的理由，宿主取最严）。多 hook 合并语义属宿主实现侧，本仓不做聚合逻辑。

### 1.3 Total-function 输出解析 + 事件鉴别器（📖 文档化原则）

dsh `hook-protocol/src/codec.ts`：exit 2+stderr 与 exit 0 结构化 JSON 是**两个语义通道**；`hookSpecificOutput.permissionDecision` 覆盖顶层 legacy 字段；JSON 块的 `hookEventName` 与当前触发事件不符时**只丢弃事件作用域字段、保留顶层字段**。解析器是 total function：JSON 畸形当纯 stdout，执行器故障变非阻塞输出，**永不向 agent 循环抛异常**。

bash 映射：本仓 hook 生产 JSON 时的纪律——① `hookEventName` 必须与触发事件逐字一致（写错事件名，宿主侧会丢弃整个 `hookSpecificOutput` 作用域字段）；② 解析 stdin 失败一律放行（fail-open 已有）；③ deny JSON 走 `hookSpecificOutput` 通道，不依赖 stderr 文本通道。

### 1.4 审计追加失败 → 整体拒绝（📖 原则 + 显式取舍）

dsh `user-approval`：审批审计写不进去时**宁可拒绝也不返回未记录的决策**。

本仓取舍：**不采用**。我们的 deny 是安全侧动作，fail-open 纪律优先——审计写失败不阻塞主流程（`|| true`）。dsh 的审批是"用户授权"（记录缺失=授权无凭据必须拒绝），我们的 deny 是"门禁拦截"（拦截失效=安全退化）。原则留存：涉及"授权"语义的日志（decisions.jsonl 的 UserChallenge 决策）应向 dsh 看齐——授权留痕失败时提示用户重试，不静默继续。

## 二、状态韧性（簇 B）

### 2.1 整快照事件溯源 + CAS revision（📖 原则）

dsh `packages/goal`：每次状态迁移追加**完整事后快照**事件（含单调 revision），fold = last-wins；变更携 `{id, revision}` CAS，stale 修订直接拒绝；独立伴生校验器在事件**入日志前**校验形状/revision 连续性/合法迁移表/时间戳单调性，第一条损坏事件即停游标。

bash 映射（候选，见 §五已登记未实施）：`state-machine.sh` 的 `state.yaml` 迁移为 `state.jsonl` 整快照追加 + revision CAS。**触发条件**：真实出现并发写 state.yaml 损坏/竞态事故再机械化；当前单 AI 会话串行写，YAML 覆写够用。

### 2.2 持久态与进程本地"激活权"分离（📖 原则）

dsh `goal`：durable phase 与"本进程是否有权自动继续"（armed/disarmed）是两个维度；激活权**永不写盘**——重启/fork/恢复后一律 disarmed，必须显式 resume 重新授权。驱动侧：推进前先 flush → await 之后复核 revision 未变且无竞争输入 → CAS 预订下一轮（stale 预订不消耗序号）；flush 失败降级 disarm，不自动重试。

bash 映射：`state.json`/yaml 存阶段（durable），锁/PID 文件存"本轮执行权"（不持久化）；脚本崩溃后锁可清但**阶段不自动推进**——恢复时必须由 AI/用户显式确认当前阶段。这条已在 swarm-yuan 的 draft 状态门（`--mark-active` 人工翻转）精神内，文档化即可。

### 2.3 观测失败降级为合法前缀（📖 原则，trace-log.sh 自我约束）

dsh `tool-workflow`：观测记录写入失败时，**要么无记录、要么是合法的连续前缀，绝不改变主流程结果或清理路径**（首次 append 失败即禁用该 run 后续记录并告警一次）。

bash 映射：`trace-log.sh` 已是"永不 fail 阻塞主流程"；升级为更精确的语义——写 trace.jsonl 失败时打一条 stderr 告警（每进程一次），**之后不再重试写**（避免每节点都刷告警），主流程零影响。决策日志（decisions.jsonl）同理但语义更重（见 §1.4 授权取舍）。

### 2.4 回放规则不可变（📖 原则，已补 memory-persistence.md）

dsh `todo`：日志 invariant **故意不跟随**当前校验策略——策略收紧后旧日志必须仍能 replay。

bash 映射：**日志格式版本化第一原则**——`.swarm-yuan/*.jsonl`（trace/decisions/gate-audit/gate-deny）的**读取/回放逻辑**必须兼容所有历史格式版本；新增字段只加不删不改义；`--upgrade` 升级生成器后旧日志仍须可回放。校验规则（如决策五要素必填）只约束新写入，不回溯旧记录。

## 三、增量自成长（簇 C）

### 3.1 catalog/body 生命周期分离 + digest 驱动整体替换（📖 原则）

dsh `skill` 包：catalog（name+description 索引）与 body（正文按需重读）生命周期分离；每次 pre-step 对已渲染条目算 digest，变了就追加**完整替换目录**而非 diff——"上次发布的清单"自己就是对比基线。

bash 映射：目标技能 `reference-manual.md` 的组件清单段是 catalog，组件详情/签名是 body；自成长更新时**整体重写清单段**（不做行级 diff 合并），段头注释记录生成时间戳与源指纹 digest 作对比基线。

### 3.2 工具结果驱动的局部重探查（📖 原则，替代文件 watcher）

dsh `agent-instructions`：不靠 inotify，观察 read/write/edit 工具的 durable result——touch 到某 scope 才做该 scope 重探查；`{path, version, sha1 digest}` 缓存跳过未变文件。

bash 映射（部分落地 -C）：`project-fingerprint.sh` 增路径级 digest 缓存——结构指纹感知到变化后，AI 重探查**只针对 git diff 涉及的目录/维度**，SHA 未变的路径直接复用旧清单条目。增量且幂等。

### 3.3 fail-closed 解析 + last-good 保留（📖 原则）

dsh `skill-filesystem`：frontmatter 解析失败**整个条目带警告剔除**（坏数据不出现在禁用面）；发现过程 I/O 失败时快照标 `complete: false`、不缓存、消费者继续用 last-good。

bash 映射（红线已入骨架 SKILL.md 自成长段，-C 机械化）：清单更新**先完整生成到临时文件再原子替换**（`mv` 同目录原子性），探查中途失败绝不覆盖上一份好清单；探查输出本身畸形（条目数骤降 >50%）视为失败，保留 last-good 并告警。

## 四、工程纪律（簇 D）

### 4.1 defensive-patterns 六条（dsh `docs/defensive-patterns.md`，每条都是真实缺陷类）

| dsh 规则 | swarm-yuan 落点 |
|---------|----------------|
| 正交结果独立报告（绝不在一个 flag 的分支里嵌套另一个的报告——进程超时 AND exit 0 要分开报） | 门禁输出设计：fail 行一条一个原因，不嵌套；`--report` 聚合维度独立成段 |
| 回调异常收容在调度器内（一个坏 listener 不破坏核心生命周期） | hooks fail-open 的理论表述：任一 hook 崩不影响其他 hook 与主流程 |
| 不把不可信输出交给 ambient 环境或可预测路径（env 清洗 drop `*KEY*`/`*SECRET*`/`*TOKEN*`，0700 私有目录 + 随机名 + `wx` 独占创建） | hook/脚本写临时文件：`mktemp`（已做）；涉及凭据的 conf 加载不 export 到子进程环境 |
| dispose 必须到达 quiescence（kill 后 await 子进程真正退出；先关 listener 注册表再 kill） | 生成流程中断清理：worktree 收口前先确认无在途写；`--upgrade` 备份完成才覆盖 |
| 异步状态不是同步状态（`whenIdle` 不是单条消息的完成信号；等的迁移若永不会发生要显式处理"没得等"分支） | PostToolUse hook 语义：precheck 的 exit_code 是这次运行的结果，不是"门禁整体健康度"——flag 捕获模型本就如此设计，文档化 |
| unlink 链接形路径（lstat 判 symlink → unlink 只删链接不跟随） | 清理脚本删文件前 `[[ -L ]]` 判定（bash：`rm` 默认不跟随符号链接删目标，但 `rm -r` 会——清理逻辑避免 `rm -rf` 用户路径） |

### 4.2 解释性空实现契约（dsh `runtime-diagnostics/invariants`）

每包必须发布 `./invariant` 伴生模块；没有可检查关系的包必须写**以 `No runtime invariant:` 开头的注释解释为什么**；机械脚本 `verify-package-invariants` 拒绝无解释的空实现。断言只针对**可观察的事件关系/可变数据关系**，绝不断言服务/方法存在性（那是类型系统的事）。

bash 映射：swarm-yuan 已有同构——门禁 `skip_if_unconfigured` 必须带原因（SKIP 披露而非静默），Q2-heavy "机械只在信号可信处"同源于"只断言可观察关系"。强化点：self-check.sh 的每类检查若整类不适用，须输出 `No <check>: <原因>` 而非静默跳过。

### 4.3 Agent Notes 生命周期（✅ 已落地 -D）

dsh `.agents/notes/{proposed,implemented,rejected,archived}/<date>-<slug>.md`：决策笔记四态生命周期。关键增量是 **proposed/rejected 的未采纳决策留痕**——ISO/IEC 42001 审计视角下，被拒绝的方案同样是治理证据。

bash 映射：decisions.jsonl 增 `outcome` 字段（implemented/rejected/superseded），文档化不加机器执法——见 `references/decision-governance.md`。

### 4.4 postmortem 编号制（📖 可选借鉴）

dsh `docs/postmortem/NNNN-<slug>.md` 四篇编号事后分析。swarm-yuan 的复盘轮（R1-R12）有调研报告编号（docs/research/），事后分析目前口头化在 commit message 与 memory；如需对外交付事故复盘，可采用 NNNN 编号 + 固定骨架（现象/时间线/根因/教训/行动项）。当前不强制。

## 五、已登记未实施（触发条件写明）

| 候选 | 内容 | 触发条件 |
|------|------|---------|
| state.jsonl 事件溯源化 | state-machine.sh 的 state.yaml → 整快照 JSONL 追加 + revision CAS + 追加前校验器（§2.1/2.2 机械化） | 真实出现并发写损坏/竞态事故；或多 AI 并行操作同一项目状态成为常态 |
| gate-audit 拦截率阈值告警 | `--report` 输出拦截率异常（如 7 天内 deny 率 >80% = 门禁可能过严/误伤）时 warn | gate-audit.jsonl 积累 ≥2 周真实数据后再定阈值（当前无数据无真相） |
| hook 输出 schema 机械校验 | self-check 增断言：本仓 hook 输出的 deny JSON 的 hookEventName 与注册事件逐字一致（§1.3 机械化） | 出现一次因事件名写错导致宿主丢决策的真实事故 |

## 六、与上轮吸收（cordis 框架层）的关系

上轮（2026-08-14）吸收可逆效应/响应式依赖，落地 `--inject-frameworks` 快照+ledger+`--rollback-frameworks` 与 precheck.patch.conf 分层 patch。本轮产品层机制与框架层同根（都是"动态组合系统的可信度工程"），但回答的问题不同：框架层回答"组件加装/拆除是否可控"，产品层回答"决策是否可审计、状态是否可恢复、感知是否可持续"。两者在 swarm-yuan 的交点：自成长链+ fail-gate 审计。

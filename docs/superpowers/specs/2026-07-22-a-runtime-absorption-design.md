# A：运行时吸收转化设计

> 日期：2026-07-22 ｜ 分支：`feat/a-runtime-absorption`
> 范围：运行时吸收转化（A 方向）—— 把 4 个方法论引用运行时的关键机制从 advisory 固化为可执行门禁/生成器机制
> 理念：分层整合，诚实降级——但"方法论引用"层的关键防误报/度量驱动机制应有可执行落点
> 口径权威源：`swarm-yuan/assets/facts.conf`
> 调研依据：`docs/research/R5-upstream-local.md` §六（吸收度核实）+ §七（未吸收但值得吸收的机制）

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（R5 调研确认）

swarm-yuan 对 4 个方法论引用运行时（superpowers/gstack/ECC/Ruflo）的吸收是**"工作流形态级"且全部 advisory 化**——编排循环、两遍清单、Fix-First、Plan 完成度审计已忠实吸收进 references，但 **R5 评级 ❌ 未吸收的关键机制**全部没有可执行落点：

| 机制 | 来源 | 治什么 | R5 评级 |
|------|------|-------|---------|
| adaptive gating（门禁命中率统计，连续零发现自动降级，安全类 NEVER_GATE） | gstack review | 治沉睡门禁 | ❌ 未吸收 |
| pre-emit 引用门（finding 必须逐字引用动机代码行否则强制降级压出主报告） | gstack review #1539 | 治 fail-open/误报 | ❌ 未吸收 |
| 置信度标定 + 22 条 FP 硬排除 | gstack cso | 治误报 | ❌ 未吸收 |
| Decision Audit Trail（决策落盘） | gstack autoplan | 治决策黑箱 | ❌ 未吸收（**G1 已吸收**） |
| context-save bash 层输入消毒 + 仅追加 checkpoint | gstack context-save | 防注入 | ❌ 未吸收 |
| canary 基线对比监控（"alert on changes, not absolutes"） | gstack canary | 补发布后一环空白 | ❌ 未吸收 |
| SKILL.md 模板生成 + CI 新鲜度校验 | gstack ARCHITECTURE | 治文档漂移 | ❌ 未吸收 |

这些机制共同指向 swarm-yuan 已审计出的问题（沉睡门禁、fail-open、误报、文档漂移），但只停留在"AI 读了方法论才算数"的 advisory 层，无任何一条固化为 precheck.sh 可执行门禁或生成器机器机制。

**G1 已完成的部分**：Decision Audit Trail 已由 G1 吸收为 decisions.jsonl（本 spec 不重复）。

### 1.2 目标

把 R5 点名的 6 个未吸收机制中，对 swarm-yuan 已知问题针对性最强、且可机器化的 **3 个**固化为可执行门禁或生成器机制，让"方法论引用"层从"AI 读了才算数"升级为"有机器执法落点"。

### 1.3 方案选型（从 6 个未吸收项中选 3 个）

| 机制 | 可机器化程度 | 治已知问题针对性 | 误报风险 | 选择 |
|------|------------|----------------|---------|------|
| **pre-emit 引用门** | 高（finding 须引用代码行，可 grep 校验） | 强（治 fail-open/误报） | 低（只降级不 fail） | ✓ **选** |
| **adaptive gating** | 中（需命中率统计文件 + 阈值逻辑） | 强（治沉睡门禁） | 中（统计不准会误降级） | ✓ **选** |
| **context-save 输入消毒** | 高（bash 层允许表消毒） | 中（防注入） | 低（白名单只过滤） | ✓ **选** |
| 置信度标定 + FP 硬排除 | 中（需标定学习闭环） | 强（治误报） | 高（标定逻辑复杂） | ✗ 留后续 |
| canary 基线对比监控 | 低（需发布后监控基础设施） | 中（补空白） | 中 | ✗ 留后续 |
| SKILL.md 模板生成 + CI 新鲜度校验 | 中 | 中（治文档漂移，facts.conf 已部分解决） | 低 | ✗ facts.conf 已覆盖核心 |

**选这 3 个的理由**：
- **pre-emit 引用门**——直接治审计确认的 fail-open/误报问题，且实现是"finding 必须引用代码行"的可 grep 校验，低风险高针对。
- **adaptive gating**——直接治审计确认的沉睡门禁问题，gstack 给出了成熟范式（命中率统计 + NEVER_GATE 安全豁免），且有决策 19 的 enforce_level 三档作为基础。
- **context-save 输入消毒**——防注入是可移植的 bash 层模式（允许表消毒），对 swarm-yuan 的 state-machine.sh 与记忆写回直接可用，低风险。
- Decision Audit Trail 已由 G1 吸收；置信度标定/canary/模板生成留后续（标定复杂/需监控基础设施/facts.conf 已覆盖核心）。

---

## 2. 架构与组件

### 2.1 总体架构

```
gstack review/cso/context-save（方法论引用层）
        │  吸收转化
        ▼
┌─────────────────────────────────────────────────────┐
│  ① pre-emit 引用门                                   │
│     precheck.sh check_review 增强：                   │
│     finding 必须引用动机代码行（file:line）否则降级 warn  │
├─────────────────────────────────────────────────────┤
│  ② adaptive gating（门禁命中率统计）                   │
│     .swarm-yuan/gate-stats.jsonl 落盘每门禁命中率      │
│     连续 N 次零发现的 advisory 门自动降级提示           │
│     安全类 NEVER_GATE（安全门永不降级）                │
├─────────────────────────────────────────────────────┤
│  ③ context-save 输入消毒                             │
│     state-machine.sh + 记忆写回的 bash 层允许表消毒     │
│     用户输入永不进 LLM 层拼路径                       │
└─────────────────────────────────────────────────────┘
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 |
|---|------|------|---------|
| 1 | `swarm-yuan/references/review-methodology.md` | 改 | 新增 §pre-emit 引用门 + §置信度标定声明（引用 gstack #1539） |
| 2 | `swarm-yuan/assets/precheck.sh` | 改 | check_review 增强：finding 缺代码引用降级 warn（advisory，不 fail） |
| 3 | `swarm-yuan/assets/precheck.sh` | 改 | 新增 `--gate-stats` 子命令：记录每门禁命中率到 gate-stats.jsonl + adaptive gating 降级提示 |
| 4 | `swarm-yuan/assets/state-machine.sh` | 改 | 新增 bash 层输入消毒辅助函数（允许表消毒） |
| 5 | `swarm-yuan/assets/facts.conf` | 改 | 新增 FACT_ADAPTIVE_GATING 口径 |
| 6 | `swarm-yuan/references/subagent-orchestration.md` | 改 | 新增 §context-save 输入消毒模式（引用 gstack） |

### 2.3 三个机制的具体设计

#### 机制①：pre-emit 引用门（治 fail-open/误报）

**gstack 原型**（R5 §三.4.4）："凡不能逐字引用'动机代码行'的 finding 强制降到 4-5 并压出主报告"（review/SKILL.md:1241-1276）。"If you cannot quote the motivating line(s), the finding is unverified"。

**swarm-yuan 吸收**：check_review 的 AI 5 维度审查降级路径（无 ocr 时）增强——AI 产出的每条 finding 必须带 `file:line` 引用，否则降级为 warn 提示（advisory，不 fail）。

```
原：AI 5 维度审查 → 输出 finding 列表
新：AI 5 维度审查 → 每条 finding 校验含 file:line 引用 →
    含引用 → 正常输出
    缺引用 → 降级 warn "该 finding 未引用动机代码行，按 pre-emit 引用门降级（gstack #1539）"
```

**姿态**：advisory（不新增 fail），与 check_review 现有降级策略一致。ocr review 路径不变（ocr 自带严重度分级）。

#### 机制②：adaptive gating（治沉睡门禁）

**gstack 原型**（R5 §三.4.5）：specialist 命中率统计——连续 10+ 次派发零发现则标 `[GATE_CANDIDATE]` 自动跳过；Security 与 data-migration 标 `[NEVER_GATE]`（"insurance policy specialists — they should run even when silent"）。

**swarm-yuan 吸收**：新增 `--gate-stats` 子命令 + `.swarm-yuan/gate-stats.jsonl` 落盘——

```
每门禁执行后追加一行：
{"ts":"...","gate":"check_cognition","result":"pass|warn|fail","had_finding":true|false}

adaptive gating 判定（读 gate-stats.jsonl）：
- advisory 门连续 N 次（默认 10）had_finding=false → warn 提示
  "⚠ check_cognition 连续 10 次零发现，建议降级为跳过（adaptive gating）"
- 安全类门（sensitive/security/authz/privacy/crypto/sbom/release-sign）NEVER_GATE，永不提示降级
- strict/warn 门不自动降级（只 advisory 门可降级，与决策 19 enforce_level 一致）
```

**姿态**：`--gate-stats` 是独立子命令（非门禁，类似 `--doctor`），warn 不 fail。降级是提示不是自动执行（与"用户决策"原则一致）。复用现有 GATE_RUNS_DIR 落盘机制（`precheck.conf` 的 gate-runs.jsonl）作为基础。

#### 机制③：context-save 输入消毒（防注入）

**gstack 原型**（R5 §三.2）：context-save 的标题在 **bash 层**用允许表消毒（仅 `a-z 0-9 - .` 存活），文件名仅追加不覆盖、同秒碰撞加随机后缀——"用户输入永不进 LLM 层拼路径"。

**swarm-yuan 吸收**：state-machine.sh 新增 bash 层输入消毒辅助函数，应用于 change name 等用户输入——

```bash
# G7/A：context-save 输入消毒模式（gstack 吸收）
# 用户输入只允许安全字符集，防注入（路径穿越/命令注入）
sanitize_input() {
  printf '%s' "$1" | tr -cd 'a-zA-Z0-9._-'
}
```

应用于 `state-machine.sh init <change-name>`：change 名经 `sanitize_input` 过滤后才写入 state.yaml。

**姿态**：纯过滤（白名单字符集），不 fail。与 security-spec.md §六 bash 脚本安全一致。

---

## 3. 数据流与机制落点

### 3.1 三个机制的数据流

#### pre-emit 引用门

```
check_review 无 ocr 降级路径
  → AI 5 维度审查产出 finding 列表
  → 逐条校验：finding 行含 file:line 模式（grep -E '[a-zA-Z0-9_/.-]+\.[a-z]+:[0-9]+'）
  → 含 → 正常输出
  → 缺 → 降级 warn + 标注 pre-emit 引用门
```

#### adaptive gating

```
precheck.sh --all/--all-full 执行
  → 每门禁执行后（若 GATE_RUNS_DIR 配置）追加 gate-stats.jsonl
  → bash precheck.sh --gate-stats
  → 读 gate-stats.jsonl 统计每门禁连续零发现次数
  → advisory 门连续 N 次零发现 → warn 降级提示（安全类除外）
```

#### context-save 输入消毒

```
state-machine.sh init <change-name>
  → sanitize_input <change-name>（白名单字符集过滤）
  → 过滤后的名字写入 state.yaml
```

### 3.2 NEVER_GATE 安全门清单（与 strict 门禁对齐）

| 门 | 理由 |
|---|------|
| sensitive | 密钥泄露是硬伤，永不降级 |
| security | OWASP Top 10，永不降级 |
| authz | 授权类弱点（CWE-862/863/639/284），永不降级 |
| privacy | 个人信息（个保法），永不降级 |
| crypto | 密码算法合规（密评），永不降级 |
| sbom | 供应链 SBOM，永不降级 |
| release-sign | 发布签名（SLSA L2），永不降级 |

**理由**：gstack 的 "insurance policy specialists — they should run even when silent" 原则——安全类门即使长期零发现也必须运行（保险策略），不适用 adaptive gating 降级。

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理

| 机制 | 故障 | 行为 |
|------|------|------|
| pre-emit 引用门 | finding 格式不规则无法 grep file:line | 降级 warn（不 fail），与现有降级一致 |
| adaptive gating | gate-stats.jsonl 不存在/不可读 | 提示"无统计数据"，不 fail |
| adaptive gating | 统计逻辑误判 | 只 warn 提示，不自动降级（用户决策） |
| context-save 消毒 | 输入全是非法字符 | 返回空字符串，state-machine 提示"change name 全被过滤，请重命名" |

### 4.2 测试策略

| 验证手段 | 覆盖什么 |
|---------|---------|
| `bash -n` 语法检查 | 所有改动脚本 |
| pre-emit 引用门手动验证 | 造含/缺 file:line 的 finding，看降级行为 |
| adaptive gating 手动验证 | 造 gate-stats.jsonl 含 10 次零发现，跑 --gate-stats 看降级提示 |
| context-save 消毒手动验证 | 造含路径穿越字符的 change name，看过滤结果 |
| facts.conf 对账 | FACT_ADAPTIVE_GATING 口径 |

### 4.3 对齐标准

| 标准/理念 | A 落地 |
|----------|--------|
| 理念：分层整合，诚实降级 | 方法论引用层的关键机制有可执行落点，不再纯 advisory |
| R5 §七 未吸收机制 | pre-emit 引用门/adaptive gating/context-save 消毒从 ❌ 未吸收变 ✅ 固化 |
| gstack review #1539 | pre-emit 引用门忠实吸收（finding 须引用代码行） |
| gstack NEVER_GATE | 安全类门永不降级（保险策略） |
| 决策 19 enforce_level 三档 | adaptive gating 只作用于 advisory 门，与三档分层一致 |
| security-spec.md §六 | context-save 消毒与 bash 脚本安全一致 |

---

## 5. 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-A-1 | review-methodology.md 新增 pre-emit 引用门 § + precheck.sh check_review 增强 | 无 | 2 改 |
| WP-A-2 | precheck.sh --gate-stats 子命令 + adaptive gating + facts.conf 口径 | 无 | 2 改 |
| WP-A-3 | state-machine.sh sanitize_input + subagent-orchestration.md context-save 消毒 § | 无 | 2 改 |

---

## 6. 关键证据索引

- R5 §六 吸收度核实（全部 advisory 化）：`docs/research/R5-upstream-local.md` §六
- R5 §七.2 pre-emit 引用门（治 fail-open/误报）：`docs/research/R5-upstream-local.md` §七.2
- R5 §七.1 adaptive gating（治沉睡门禁）：`docs/research/R5-upstream-local.md` §七.1
- R5 §七.5 context-save 输入消毒：`docs/research/R5-upstream-local.md` §七.5
- gstack review #1539 pre-emit 引用门：`docs/research/R5-upstream-local.md` §三.4.4
- gstack NEVER_GATE 保险策略：`docs/research/R5-upstream-local.md` §三.4.5
- check_review 现有降级链：`swarm-yuan/assets/precheck.sh:429-460`
- GATE_RUNS_DIR 落盘机制：`swarm-yuan/assets/precheck.conf`（gate-runs.jsonl）
- 决策 19 enforce_level 三档：`docs/paradigm-decisions.md` 决策 19
- 审计确认沉睡门禁/fail-open：`docs/2026-07-20-audit-optimization-decisions.md` §刻意不修
- state-machine.sh init：`swarm-yuan/assets/state-machine.sh:45-67`
- security-spec.md §六 bash 脚本安全：`swarm-yuan/references/security-spec.md` §六

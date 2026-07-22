# D：研发全流程交付能力强化设计

> 日期：2026-07-22 ｜ 分支：`feat/d-full-lifecycle`
> 范围：研发全流程交付能力强化（D 方向）—— 用户终极目标："生成目标项目的研发技能 skill，供进行研发全流程工作的交付"
> 理念：先认识，再行动 + 左移原则（测试/变更/运维在 spec/plan 阶段嵌入）
> 口径权威源：`swarm-yuan/assets/facts.conf`

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（调研确认）

swarm-yuan 生成的目标 skill 在研发全流程的覆盖现状：

**workflow 8 节点已覆盖（`template-spec.md:198-210`）：**
1. 需求理解 → 2. 设计 spec → 3. 实施 plan → 4. 分支准备 → 5. 编码实现 → 6. 测试验证 → 7. 合入 main → 8. 构建发布

**state-machine 5 阶段（`state-machine.sh:21`）：**
open → design → build → verify → archive

**左移三件套已嵌入（`template-spec.md:328-330`）：**
- 测试左移（spec §19 + 编码先测试后实现）
- 变更左移（plan §20 + 合入前回滚预案）
- 运维监控左移（spec §21 + 发布前灰度+告警+runbook）

**最薄弱环节——operate（发布后运营）环节无节点承载。** 左移三件套把可观测性"嵌入"了 spec/plan/code/release（设计态），但**发布后运营**（发布后监控、告警响应、事故复盘、容量/性能趋势、变更后验证）没有对应的工作流节点。workflow 8 节点止于"构建发布"，state-machine 5 阶段止于"archive"——"发布后"是闭环的断点。

这与用户"研发全流程工作的交付"目标有差距：交付不是"发布即结束"，而是"发布后可持续运营"。当前目标 skill 能交付"开发到发布"，但"发布后运营"环节靠项目自身运维体系，范式未提供承载。

### 1.2 目标

补强研发全流程的最薄弱一环（operate 发布后运营），让目标 skill 能支撑"spec→plan→code→review→test→release→**operate**"的完整闭环，交付物真正覆盖研发全流程。

### 1.3 方案选型

| 档 | 内容 | 风险 | 选择 |
|---|---|---|---|
| A 只补 operate 节点 | workflow 加"节点⑨发布后运营" + state-machine 加 operate 阶段 | 低（增量节点，不破坏现有 8 节点） | ✗ 无门禁承载，仍是叙事 |
| **B operate 节点 + 门禁承载（选）** | A + 新增 `--operate` 门禁（发布后验证：健康检查/告警/runbook/灰度观察）+ spec §23 运营段 | 中（新门禁需校准，但为 warn 级） | ✓ |
| C B + 事故复盘/容量规划全生命周期 | B + 事故复盘节点 + 容量规划 + SLA 追踪 | 高（工程量大，且事故复盘偏组织流程非门禁） | ✗ 超出范式边界 |

**选 B 的理由**：B 把 operate 环节从"无节点"补为"有节点 + 有门禁承载"（可执行验证），且不碰事故复盘/容量规划等偏组织流程的内容（这些超出"门禁级自动化"边界，属组织运营范畴）。新门禁 `--operate` 为 warn 级（发布后验证是环境依赖型检查，硬 fail 风险高），与左移三件套的嵌入式设计一致。

---

## 2. 架构与组件

### 2.1 总体架构

```
研发全流程闭环（D 方向补强 operate 环节）：

需求理解 → 设计spec → 实施plan → 分支准备 → 编码 → 测试验证 → 合入 → 构建发布 → 【发布后运营】
  ①        ②        ③        ④       ⑤      ⑥        ⑦      ⑧        ⑨ (新增)

spec §19 测试左移 ─┐
spec §21 运维左移 ─┼─→ 左移三件套（设计态嵌入）──→ operate 节点（运行态验证）
plan §20 变更左移 ─┘                                    │
                                                        ▼
                                              precheck.sh --operate（新门禁）
                                              - 健康检查端点可访问
                                              - 告警阈值已配置
                                              - runbook 已更新
                                              - 灰度观察期确认
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 |
|---|------|------|---------|
| 1 | `references/template-spec.md` | 改 | 标准节点加"⑨ 发布后运营"（8 节点→9 节点）+ workflow 要素补充 |
| 2 | `assets/state-machine.sh` | 改 | PHASES 加 operate 阶段（5 阶段→6 阶段）+ guard_phase operate 准入 |
| 3 | `assets/precheck.sh` | 改 | 新增 `--operate` 门禁（发布后验证，warn 级）+ GATE_FLAGS 注册 |
| 4 | `assets/spec-template.md` | 改 | 新增 §23 运营段（发布后监控/告警响应/变更后验证） |
| 5 | `assets/facts.conf` | 改 | FACT_FLOW_NODES 10→11（或按实际口径）+ FACT_SPEC_SECTIONS 22→23 |

### 2.3 operate 环节的具体设计

#### 节点⑨：发布后运营（workflow 新增）

```
## 节点⑨：发布后运营

① 流程入口：构建发布（节点⑧）之后，无后续节点（闭环终点回到需求理解，形成迭代）
② 参与方：AI 执行 + 用户确认（发布后监控为环境依赖型，AI 辅助核查）
③ 准入条件：节点⑧ 发布完成（release-sign 通过 / 灰度策略已启用）
④ 门禁：precheck --operate（发布后验证，warn 级）
⑤ 分支处理：operate 不改代码，只验证运行态；发现问题走新需求（回到节点①）
⑥ 产出物归档：发布后验证报告（.swarm-yuan/operate-report.md）
⑦ 流程控制：灰度观察期（默认 24h 可配）内持续监控
⑧ 状态控制：state-machine operate 阶段
⑨ 调用追踪：→ [节点⑨ 发布后运营] 调用 --operate 门禁 · 发布后验证
⑩ 完成检查表：健康检查可访问 / 告警阈值已设 / runbook 已更新 / 灰度观察无异常
```

#### state-machine operate 阶段（5→6 阶段）

```
PHASES=("open" "design" "build" "verify" "archive" "operate")

guard_phase operate 准入：
  - verify_result == pass（archive 准入已有，operate 复用）
  - 灰度观察期确认（可配 OPERATE_OBSERVE_HOURS，默认 24h）
  - 发布后验证报告存在（.swarm-yuan/operate-report.md）
```

**语义**：archive（归档）与 operate（运营）的关系——archive 是"本次变更归档"，operate 是"发布后持续运营"。operate 是 archive 之后的可选延伸阶段（长期运行态），非每次变更都进入。

#### `--operate` 门禁（发布后验证，warn 级）

```
check_operate（warn 级，不新增 fail——环境依赖型检查硬 fail 风险高）：

① 健康检查端点可访问：
   - HEALTH_CHECK_URL 配置时，curl 探测（超时 5s）
   - 无 curl/URL 未配置 → skip_if_unconfigured

② 告警阈值已配置：
   - ALERT_CONFIG_FILE 配置时，检查文件存在且非空
   - 未配置 → warn

③ runbook 已更新：
   - RUNBOOK_FILE 配置时，检查最近修改时间在本次发布后
   - 未配置 → warn

④ 灰度观察期确认：
   - spec §23 运营段含灰度观察声明 → pass
   - 缺失 → warn

姿态：warn 级（advisory），环境依赖型检查硬 fail 风险高
      （健康检查/告警/runbook 都依赖部署环境，CI 环境不可达）
```

**为什么是 warn 级**：发布后验证是**环境依赖型**检查（健康检查端点/告警配置/runbook 都依赖部署环境，CI 环境通常不可达）。硬 fail 会在 CI 环境误报淹没（违反审计"刻意不修沉睡门禁"原则）。warn 级让"发布后验证缺失"可见但不阻断——与 `--cognition` 的 advisory 姿态一致（决策 12/19）。

#### spec §23 运营段（spec-template 新增）

```markdown
## 23. 发布后运营（D 方向：研发全流程闭环）

> 发布后不是结束——运营环节验证交付物在真实环境的表现。完整级别必填。

### 23.1 发布后监控
- 健康检查端点：`<URL>`
- 关键 metrics 观察清单：
- 灰度观察期：<时长>（默认 24h）

### 23.2 告警响应
- 告警阈值配置：
- 告警接收人/on-call：
- runbook 路径：

### 23.3 变更后验证
- 发布后须验证的功能点：
- 回滚触发条件：
- 回滚执行负责人：

### 23.4 声明
（发布后运营计划已就绪的确认声明）
```

---

## 3. 数据流与全流程映射

### 3.1 研发全流程 → 承载物映射表

| 环节 | workflow 节点 | state-machine 阶段 | spec 段 | 门禁 |
|------|--------------|-------------------|---------|------|
| spec | ② 设计 spec | design | §1-§18 | --requirements |
| plan | ③ 实施 plan | design | §4 tasks | （OpenSpec validate） |
| code | ⑤ 编码实现 | build | §5.5 复用 | --reuse/--stable-diff |
| review | ⑥ 测试验证 | verify | §11 测试 | --review/--security |
| test | ⑥ 测试验证 | verify | §19 测试左移 | --test/--shift-left |
| release | ⑧ 构建发布 | archive | §20/§21 | --release-sign/--sbom |
| **operate** | **⑨ 发布后运营（新增）** | **operate（新增）** | **§23（新增）** | **--operate（新增）** |

### 3.2 左移三件套与 operate 的关系

```
设计态嵌入（左移）              运行态验证（operate）
spec §19 测试左移    ──┐
spec §21 运维左移    ──┼──→ 设计时写入约束  ──→  发布后验证约束兑现
plan §20 变更左移    ──┘                          │
                                                  ▼
                                    --operate 门禁检查：
                                    健康检查/告警/runbook/灰度
```

左移把"运维监控"前置到 spec/plan 设计态；operate 在发布后运行态验证这些设计是否兑现。两者是"设计—验证"闭环，不是重复。

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理

| 故障 | 行为 | 理由 |
|------|------|------|
| 健康检查端点 CI 不可达 | skip（URL 未配置）或 warn（配置但超时） | 环境依赖，不硬 fail |
| state-machine operate 无产出物 | guard warn，不阻塞 | operate 是可选延伸阶段 |
| spec §23 缺失 | --operate warn | 简单级别可"不适用" |

### 4.2 测试策略

| 验证手段 | 覆盖什么 |
|---------|---------|
| `bash -n` 语法检查 | state-machine.sh/precheck.sh 改动 |
| `--operate` 门禁手动验证 | 造含/缺 §23 的 spec，看 warn 行为 |
| state-machine operate 手动验证 | transition archive→operate |
| facts.conf 对账 | FACT_FLOW_NODES/FACT_SPEC_SECTIONS 口径 |

### 4.3 对齐标准

| 标准/理念 | D 落地 |
|----------|--------|
| 用户目标：研发全流程交付 | operate 环节补强，spec→operate 完整闭环 |
| 左移原则（已有） | operate 是左移三件套的运行态验证闭环 |
| 决策 12/19 advisory 姿态 | --operate warn 级（环境依赖型检查不硬 fail） |
| GB/T 8566 生存周期 | 补"运行/维护"过程域（workflow 8 节点原本止于发布） |

### 4.4 边界声明

**D 方向明确不做的事**：
- ❌ 不做事故复盘/容量规划/SLA 追踪自动化（偏组织流程，超出门禁级自动化边界）
- ❌ 不做发布后监控基础设施（Prometheus/Grafana 集成等，属项目自身运维体系）
- ❌ 不硬 fail operate 门禁（环境依赖型检查硬 fail 会在 CI 误报淹没）

**理由**：operate 环节的"监控基础设施"和"事故复盘流程"属组织运营范畴，范式提供的是"发布后验证"的门禁承载（健康检查/告警/runbook/灰度观察的机器可检查项），不替代项目的运维体系。

---

## 5. 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-D-1 | spec-template §23 运营段 + template-spec 节点⑨ | 无 | 2 改 |
| WP-D-2 | state-machine.sh operate 阶段 + guard_phase | 无 | 1 改 |
| WP-D-3 | precheck.sh --operate 门禁 + facts.conf 口径 | WP-D-1 | 2 改 |

---

## 6. 关键证据索引

- workflow 8 节点：`swarm-yuan/references/template-spec.md:198-210`
- 左移三件套：`swarm-yuan/references/template-spec.md:328-330`
- state-machine 5 阶段：`swarm-yuan/assets/state-machine.sh:21`
- spec §19/§20/§21：`swarm-yuan/assets/spec-template.md`（已知存在）
- review-methodology.md（review 环节承载）：`swarm-yuan/references/review-methodology.md`
- --release-sign（release 环节门禁）：`swarm-yuan/assets/gates-strict.sh:1107-1175`
- --shift-left（左移门禁）：`swarm-yuan/assets/gates-strict.sh:536-660`
- 决策 12 advisory 姿态：`docs/paradigm-decisions.md` 决策 12
- 决策 19 enforce_level 三档：`docs/paradigm-decisions.md` 决策 19

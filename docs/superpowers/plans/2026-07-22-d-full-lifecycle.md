# D：研发全流程交付能力强化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` syntax.

**Goal:** 补强研发全流程最薄弱一环（operate 发布后运营），让目标 skill 支撑 spec→plan→code→review→test→release→operate 完整闭环。

**Architecture:** workflow 加节点⑨发布后运营；state-machine PHASES 加 operate 阶段；precheck.sh 新增 `--operate` warn 级门禁（健康检查/告警/runbook/灰度观察）；spec-template 新增 §23 运营段。

**Tech Stack:** Bash 3.2 兼容 + Markdown。

**Spec:** `docs/superpowers/specs/2026-07-22-d-full-lifecycle-design.md`

## Global Constraints

- `--operate` 门禁为 **warn 级 advisory**（环境依赖型检查硬 fail 风险高，与决策 12/19 advisory 姿态一致）
- operate 是 archive 后的可选延伸阶段（长期运行态），非每次变更都进入
- 不做事故复盘/容量规划/监控基础设施自动化（组织运营范畴，超出边界）
- bash 3.2 兼容；commit 风格 `feat(d):`

---

### Task 1: spec-template §23 运营段 + template-spec 节点⑨

**Files:**
- Modify: `swarm-yuan/assets/spec-template.md`（§22 后新增 §23）
- Modify: `swarm-yuan/references/template-spec.md`（标准节点 8→9）

- [ ] **Step 1: spec-template.md 新增 §23 运营段**

在 §22 标准合规后追加：

```markdown
## 23. 发布后运营（D 方向：研发全流程闭环）

> 发布后不是结束——运营环节验证交付物在真实环境的表现。完整级别必填；简单级别可"不适用"。

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

- [ ] **Step 2: template-spec.md 标准节点加节点⑨**

在 L208"项目可能有额外节点"前，标准节点列表第 8 条后追加：

```
9. 发布后运营 —— **★运维左移运行态验证**：发布后验证健康检查端点可访问 + 告警阈值已设 + runbook 已更新 + 灰度观察期无异常（precheck `--operate`，warn 级）
```

并更新 §2 workflow 段提及的节点数口径（如有"8 节点"表述改"9 节点"）。

- [ ] **Step 3: facts.conf 口径更新**

`FACT_SPEC_SECTIONS=22`→`23`；确认 FACT_FLOW_NODES 口径是否需同步。

- [ ] **Step 4: 验证 + Commit**

```bash
grep -c '## 23' swarm-yuan/assets/spec-template.md    # ≥1
grep -c '发布后运营' swarm-yuan/references/template-spec.md  # ≥1
git add swarm-yuan/assets/spec-template.md swarm-yuan/references/template-spec.md swarm-yuan/assets/facts.conf
git commit -m "feat(d): spec §23 运营段 + workflow 节点⑨发布后运营

- spec-template 新增 §23（发布后监控/告警响应/变更后验证/声明）
- template-spec 标准节点 8→9（节点⑨发布后运营，--operate warn 级）"
```

---

### Task 2: state-machine.sh operate 阶段

**Files:**
- Modify: `swarm-yuan/assets/state-machine.sh`

- [ ] **Step 1: PHASES 加 operate**

L21 `PHASES=("open" "design" "build" "verify" "archive")` 改为：

```bash
PHASES=("open" "design" "build" "verify" "archive" "operate")
```

- [ ] **Step 2: guard_phase 加 operate 准入**

在 guard_phase case 的 `archive)` 分支后、`*)` 前新增：

```bash
    operate)
      # D 方向：operate 发布后运营准入——verify 通过 + 灰度观察期 + 运营报告（warn 不 fail，可选延伸）
      local vr; vr=$(get_field verify_result)
      [[ "$vr" != "pass" ]] && { echo "  ⚠ operate 准入: verify_result=${vr}（建议先 verify pass）"; }
      local op_report="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/operate-report.md"
      if [[ -f "$op_report" ]]; then
        pass "operate 准入: 运营报告存在（${op_report}）"
      else
        echo "  ⚠ operate 准入: 运营报告未创建（可选延伸阶段，warn 不阻塞）"
      fi
      pass "operate 阶段（发布后运营，可选延伸）"
      ;;
```

- [ ] **Step 3: 语法检查 + 手动验证**

Run:
```bash
bash -n swarm-yuan/assets/state-machine.sh
cd /tmp && rm -rf d-test && mkdir d-test && cd d-test
export PROJECT_DIR=/tmp/d-test
mkdir -p scripts
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/state-machine.sh scripts/
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh scripts/ 2>/dev/null || true
bash scripts/state-machine.sh init test 2>&1
bash scripts/state-machine.sh guard operate 2>&1 | tail -5
```
Expected: 语法无输出；guard operate 输出 operate 准入提示

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/assets/state-machine.sh
git commit -m "feat(d): state-machine 新增 operate 发布后运营阶段

- PHASES 5→6 阶段（加 operate）
- guard_phase operate 准入（verify pass + 运营报告，warn 不 fail 可选延伸）"
```

---

### Task 3: precheck.sh --operate 门禁 + GATE_FLAGS 注册

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（新增 check_operate + GATE_FLAGS 注册）

- [ ] **Step 1: 新增 check_operate 函数**

在 precheck.sh 门禁函数区新增（warn 级 advisory）：

```bash
# --operate：发布后运营验证（D 方向，warn 级 advisory——环境依赖型检查硬 fail 风险高）
# 检查：健康检查端点可访问 / 告警阈值已配置 / runbook 已更新 / spec §23 灰度观察声明
check_operate() {
  section "发布后运营（--operate，advisory）"
  # ① spec §23 灰度观察声明
  local spec_f="${SPEC_FILE:-}"
  if [[ -n "$spec_f" && -f "$spec_f" ]]; then
    if grep -qE '## 23|发布后运营|灰度观察' "$spec_f" 2>/dev/null; then
      pass "spec 含 §23 发布后运营段"
    else
      warn "spec 缺 §23 发布后运营段（完整级别必填）"
    fi
  else
    warn "未配置 SPEC_FILE，跳过 §23 检查"
  fi
  # ② 健康检查端点（HEALTH_CHECK_URL 配置时 curl 探测，超时 5s）
  if [[ -n "${HEALTH_CHECK_URL:-}" ]]; then
    if command -v curl >/dev/null 2>&1; then
      curl -sf --max-time 5 "$HEALTH_CHECK_URL" >/dev/null 2>&1 \
        && pass "健康检查端点可访问（$HEALTH_CHECK_URL）" \
        || warn "健康检查端点不可达（$HEALTH_CHECK_URL，环境依赖）"
    else
      warn "curl 不可用，跳过健康检查探测"
    fi
  fi
  # ③ 告警阈值配置（ALERT_CONFIG_FILE 存在且非空）
  if [[ -n "${ALERT_CONFIG_FILE:-}" ]]; then
    [[ -s "$ALERT_CONFIG_FILE" ]] && pass "告警阈值配置存在" || warn "告警配置文件缺失或为空：$ALERT_CONFIG_FILE"
  fi
  # ④ runbook（RUNBOOK_FILE 存在）
  if [[ -n "${RUNBOOK_FILE:-}" ]]; then
    [[ -f "$RUNBOOK_FILE" ]] && pass "runbook 存在（$RUNBOOK_FILE）" || warn "runbook 缺失：$RUNBOOK_FILE"
  fi
  # 全未配置 → skip（与 advisory 姿态一致）
  if [[ -z "${HEALTH_CHECK_URL:-}${ALERT_CONFIG_FILE:-}${RUNBOOK_FILE:-}" && -z "$spec_f" ]]; then
    echo "  (operate 未配置，跳过——可配 HEALTH_CHECK_URL/ALERT_CONFIG_FILE/RUNBOOK_FILE 启用)"
  fi
}
```

- [ ] **Step 2: GATE_FLAGS + 分发注册**

在 GATE_FLAGS 注册表加 `"--operate"`，并在 main case 加 `operate) check_operate ;;`。归类到 advisory 档（0 fail）。

- [ ] **Step 3: facts.conf 口径**

`FACT_GATES_TOTAL=36`→`37`；`FACT_ENFORCE_ADVISORY=6`→`7`。

- [ ] **Step 4: 语法检查 + 手动验证**

Run:
```bash
bash -n swarm-yuan/assets/precheck.sh
# 造 spec 含/缺 §23 验证
cd /tmp && rm -rf d-gate && mkdir d-gate && cd d-gate
echo '## 23 发布后运营 灰度观察' > spec.md
grep -c '发布后运营' spec.md
```
Expected: 语法无输出；grep ≥1

- [ ] **Step 5: 跑自举不回归**

Run: `bash swarm-yuan/scripts/self-check.sh --check-only 2>&1 | grep -cE 'facts.conf 与代码真值一致|漂移'`
确认 facts.conf 口径与代码真值一致（门禁数 37）。

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/assets/precheck.sh swarm-yuan/assets/facts.conf
git commit -m "feat(d): precheck 新增 --operate 发布后运营门禁（warn 级 advisory）

- 检查健康检查端点/告警阈值/runbook/spec §23 灰度观察
- 环境依赖型检查 warn 级不硬 fail（与决策 12/19 advisory 姿态一致）
- FACT_GATES_TOTAL 36→37，FACT_ENFORCE_ADVISORY 6→7"
```

---

## Self-Review

**Spec coverage:** §2.2 组件 #1→Task1、#2→Task2、#3→Task3、#4→Task1、#5→Task1/3 ✓；§2.3 节点⑨/state-machine/--operate/§23→Task1/2/3 ✓；§3.1 映射表→三 Task 协同 ✓。无 gap。

**Placeholder scan:** 无 TBD，所有步骤含具体代码。

**Type consistency:** PHASES（Task2 定义）✓；check_operate（Task3 定义）✓；FACT_GATES_TOTAL/ADVISORY（Task3 更新）✓；HEALTH_CHECK_URL/ALERT_CONFIG_FILE/RUNBOOK_FILE（Task3 新增 conf 变量）✓。

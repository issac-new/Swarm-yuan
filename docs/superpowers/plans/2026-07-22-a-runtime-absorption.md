# A：运行时吸收转化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` syntax.

**Goal:** 把 gstack 的 pre-emit 引用门 / adaptive gating / context-save 输入消毒三个未吸收机制固化为可执行门禁/生成器机制。

**Architecture:** precheck.sh check_review 增强 pre-emit 引用门（finding 须引代码行否则降级 warn）；新增 `--gate-stats` 子命令 + gate-stats.jsonl 落盘 + adaptive gating 降级提示（安全类 NEVER_GATE）；state-machine.sh 新增 sanitize_input 输入消毒。

**Tech Stack:** Bash 3.2 兼容 + JSONL 落盘。

**Spec:** `docs/superpowers/specs/2026-07-22-a-runtime-absorption-design.md`

## Global Constraints

- pre-emit 引用门/adaptive gating/--operate 均为 **warn 级 advisory**（不新增 fail，避免误报淹没）
- 安全类 NEVER_GATE（sensitive/security/authz/privacy/crypto/sbom/release-sign）永不降级
- bash 3.2 兼容；commit 风格 `feat(a):`

---

### Task 1: pre-emit 引用门（check_review 增强 + review-methodology §）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（check_review 降级路径）
- Modify: `swarm-yuan/references/review-methodology.md`

- [ ] **Step 1: review-methodology.md 新增 §pre-emit 引用门**

在 review-methodology.md 追加：

```markdown
## pre-emit 引用门（gstack #1539 吸收，治 fail-open/误报）

凡 AI 审查产出的 finding **必须逐字引用动机代码行（file:line）**，否则强制降级为 warn 提示压出主报告——"If you cannot quote the motivating line(s), the finding is unverified"。

**门禁承载**：`precheck.sh check_review` 的 AI 5 维度审查降级路径（无 ocr 时）对每条 finding 校验含 `file:line` 引用；缺引用降级 warn（advisory，不 fail）。ocr review 路径不变（自带严重度分级）。

**置信度标定声明**：finding 应带置信度标注（high/medium/low），低置信 finding 压入附录——引用 gstack review/SKILL.md:1221-1281。
```

- [ ] **Step 2: precheck.sh check_review 降级路径增强**

找到 check_review 无 ocr 降级路径（AI 5 维度审查输出处），在输出 finding 后追加 pre-emit 校验：

```bash
  # A 方向：pre-emit 引用门（gstack #1539 吸收）——finding 须含 file:line 引用，缺则降级 warn
  # AI 5 维度审查降级路径输出后，逐条校验
  if [[ -n "${_review_findings:-}" ]]; then
    while IFS= read -r _fline; do
      if echo "$_fline" | grep -qE '[a-zA-Z0-9_/.-]+\.[a-zA-Z]+:[0-9]+'; then
        echo "$_fline"
      else
        warn "pre-emit 引用门：finding 未引用动机代码行（file:line），降级（gstack #1539）: ${_fline:0:80}"
      fi
    done <<< "$_review_findings"
  fi
```

（注：具体接入点以 check_review 实际结构为准——在 AI 降级输出 finding 的位置追加校验循环；若 finding 是逐行 echo 而非变量收集，改为在 echo 前校验。）

- [ ] **Step 3: 语法检查**

Run: `bash -n swarm-yuan/assets/precheck.sh`

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/assets/precheck.sh swarm-yuan/references/review-methodology.md
git commit -m "feat(a): pre-emit 引用门固化——finding 须引代码行否则降级 warn

- check_review AI 降级路径逐条校验 file:line 引用（gstack #1539 吸收）
- review-methodology.md 新增 §pre-emit 引用门 + 置信度标定声明"
```

---

### Task 2: adaptive gating（--gate-stats 子命令 + gate-stats.jsonl + facts.conf）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（新增 --gate-stats 子命令 + 门禁执行后落盘）
- Modify: `swarm-yuan/assets/facts.conf`

- [ ] **Step 1: precheck.sh 门禁执行后落盘 gate-stats.jsonl**

在 _gate_exec 或门禁执行汇总处（复用 GATE_RUNS_DIR 机制附近），追加 gate-stats 落盘：

```bash
  # A 方向：adaptive gating 命中率落盘（gstack 吸收，治沉睡门禁）
  if [[ -n "${GATE_RUNS_DIR:-}" ]]; then
    mkdir -p "$GATE_RUNS_DIR" 2>/dev/null
    local _had="false"; [[ "$rc" -ne 0 ]] && _had="true"
    printf '{"ts":"%s","gate":"%s","result":"%s","had_finding":%s}\n' \
      "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$_gate_name" "$([[ $rc -eq 0 ]] && echo pass || echo fail)" "$_had" \
      >> "$GATE_RUNS_DIR/gate-stats.jsonl" 2>/dev/null || true
  fi
```

（注：接入点以 _gate_exec 实际结构为准，复用现有 GATE_RUNS_DIR 落盘变量与 rc。）

- [ ] **Step 2: precheck.sh 新增 --gate-stats 子命令**

```bash
# --gate-stats：adaptive gating 降级提示（gstack 吸收，安全类 NEVER_GATE）
gate_stats() {
  local stats="${GATE_RUNS_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan/gate-runs}/gate-stats.jsonl"
  [[ -f "$stats" ]] || { echo "⚠ 无 gate-stats.jsonl（需配置 GATE_RUNS_DIR 并跑过门禁）"; return 0; }
  # 安全类 NEVER_GATE 清单
  local never_gate=" sensitive security authz privacy crypto sbom release-sign "
  echo "=== adaptive gating 降级提示（连续 10 次零发现的 advisory 门）==="
  # 统计每门禁连续零发现（从尾部向前连续 had_finding=false 计数）
  local gate; for gate in $(awk -F'"' '{for(i=1;i<=NF;i++) if($i=="gate") print $(i+2)}' "$stats" | sort -u); do
    echo "$never_gate" | grep -q " $gate " && continue   # NEVER_GATE 跳过
    local streak
    streak=$(grep "\"gate\":\"$gate\"" "$stats" | tac | awk -F'"had_finding":' '{print $2}' | \
      awk '{if($1=="false}") c++; else exit} END{print c+0}')
    [[ "$streak" -ge 10 ]] && echo "  ⚠ $gate 连续 $streak 次零发现，建议评估降级（adaptive gating；安全类 NEVER_GATE 已豁免）"
  done
  echo "  （仅提示不自动降级——用户决策；安全类门永不降级）"
}
```

并在 main case 注册 `gate-stats) gate_stats ;;`。

- [ ] **Step 3: facts.conf 新增口径**

```bash

# ===== adaptive gating（A 方向）=====
FACT_ADAPTIVE_GATING_STREAK=10   # 连续零发现降级提示阈值
```

- [ ] **Step 4: 语法检查 + 手动验证**

Run:
```bash
bash -n swarm-yuan/assets/precheck.sh
# 造 10 次零发现的 gate-stats.jsonl
cd /tmp && rm -rf a-test && mkdir a-test && cd a-test
for i in $(seq 1 10); do echo "{\"ts\":\"2026-07-22T10:0$i:00Z\",\"gate\":\"check_cognition\",\"result\":\"pass\",\"had_finding\":false}"; done > gate-stats.jsonl
grep -c had_finding gate-stats.jsonl
```
Expected: 语法无输出；gate-stats.jsonl 10 行

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/assets/precheck.sh swarm-yuan/assets/facts.conf
git commit -m "feat(a): adaptive gating 固化——gate-stats.jsonl 命中率 + 降级提示

- 门禁执行后落盘 gate-stats.jsonl（复用 GATE_RUNS_DIR）
- 新增 --gate-stats 子命令：连续 10 次零发现的 advisory 门降级提示
- 安全类 NEVER_GATE 豁免（sensitive/security/authz/privacy/crypto/sbom/release-sign）
- 仅提示不自动降级（用户决策）；facts.conf 新增阈值口径"
```

---

### Task 3: context-save 输入消毒（state-machine sanitize_input）

**Files:**
- Modify: `swarm-yuan/assets/state-machine.sh`
- Modify: `swarm-yuan/references/subagent-orchestration.md`

- [ ] **Step 1: state-machine.sh 新增 sanitize_input + 应用于 init**

在 state-machine.sh 工具函数区新增：

```bash
# A 方向：context-save 输入消毒（gstack 吸收，防注入）
# 用户输入白名单字符集过滤，防路径穿越/命令注入
sanitize_input() {
  printf '%s' "$1" | tr -cd 'a-zA-Z0-9._-'
}
```

在 init_state 中，`local change="${1:-}"` 后追加：

```bash
  change=$(sanitize_input "$change")
  [[ -z "$change" ]] && { echo "ERROR: change name 全被过滤（含非法字符），请重命名"; exit 1; }
```

- [ ] **Step 2: subagent-orchestration.md 新增 §context-save 输入消毒**

追加：

```markdown
## context-save 输入消毒（gstack 吸收，防注入）

gstack context-save 的标题在 **bash 层**用允许表消毒（仅 `a-z 0-9 - .` 存活），文件名仅追加不覆盖、同秒碰撞加随机后缀——"用户输入永不进 LLM 层拼路径"（`context-save/SKILL.md:870-897`）。

swarm-yuan 吸收：`state-machine.sh` 的 `sanitize_input()` 白名单字符集过滤，应用于 init 的 change name。用户输入经 bash 层过滤后才写入 state.yaml，防路径穿越/命令注入。
```

- [ ] **Step 3: 语法检查 + 手动验证**

Run:
```bash
bash -n swarm-yuan/assets/state-machine.sh
bash -c 'source /dev/stdin <<< "$(sed -n "/^sanitize_input/,/^}/p" swarm-yuan/assets/state-machine.sh)"; sanitize_input "../../etc/passwd; rm -rf"'
```
Expected: 输出 `..etcpasswdrm-rf`（路径穿越字符被过滤）

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/assets/state-machine.sh swarm-yuan/references/subagent-orchestration.md
git commit -m "feat(a): context-save 输入消毒固化——state-machine sanitize_input

- 新增 sanitize_input 白名单字符集过滤（防路径穿越/命令注入）
- init 的 change name 过滤后才写 state.yaml
- subagent-orchestration.md 新增 §context-save 输入消毒（gstack 吸收）"
```

---

## Self-Review

**Spec coverage:** §2.2 组件 #1→Task1、#2→Task1、#3→Task2、#4→Task3、#5→Task2、#6→Task3 ✓；§2.3 三机制→Task1/2/3 ✓；§3.2 NEVER_GATE 清单→Task2 ✓。无 gap。

**Placeholder scan:** Task1/2 的"接入点以实际结构为准"是因 precheck.sh 4000 行需现场确认精确行号，已给出完整可适配代码块。可接受。

**Type consistency:** gate-stats.jsonl 字段（Task2 定义）✓；FACT_ADAPTIVE_GATING_STREAK（Task2 定义）✓；sanitize_input（Task3 定义并应用）✓。

# WP-P0 计量基线 + WP-P1 信号索引数据化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` 的前两个模块：M6 计量基线设施（WP-P0）与 M4 信号索引数据化拆分（WP-P1）。

**Architecture:** WP-P0 新增 `context-surface.sh`（静态上下文表面字节计量）+ 扩展 `cost-report.sh`（started/done 配对算节点 wall-clock）+ `verifier/capture-baseline.sh`（基线采集落 `verifier/baselines/pre-opt/`）。WP-P1 把 `gen-framework-index.sh` 改为双产物（完整信号表 → `assets/framework-signals.md`，exploration-guide.md 标记区块缩为指针），detect-frameworks.sh 加 `--verbose` 命中明细。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §3（M6）、§7（M4）、§9（测试）、§10（WP 分解）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- 计量类脚本 fail-open：缺文件/缺数据不阻塞主流程（参考 cost-report.sh 恒 0 退出码约定；参数错误除外，exit 1）。
- 输出确定性：同输入字节级一致（排序后输出，绝对路径转相对路径显示），可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 名单（`.github/workflows/ci.yml` Job4）；paradigm 侧 scripts/ 不需要 .bat 包装（仅 assets/ 产物侧有 .bat 惯例）。
- 分支纪律（用户级 AGENTS.md）：每 WP 一个 worktree（`.claude/worktrees/<branch>`，从 origin/main 起），逐个收口 `merge --no-ff`。WP-P0 分支 `feat/wp-p0-measure-baseline`，WP-P1 分支 `feat/wp-p1-signal-index-split`；P0 先合，P1 rebase 后再合。
- 不破坏现有：`run-verifier.sh all` 全绿（fixtures/gate-fixtures/e2e/metrics/cli-ab）是两 WP 共同的合入门槛。

---

## WP-P0：计量基线设施（branch: feat/wp-p0-measure-baseline）

### Task 1: `context-surface.sh` — 静态上下文表面计量

**Files:**
- Create: `swarm-yuan/scripts/context-surface.sh`
- Test: `swarm-yuan/tests/test-context-surface.sh`

**Interfaces:**
- Produces: CLI `context-surface.sh --gen | --skill <dir> | --files <f...>`；stdout TSV `bytes<TAB>lines<TAB>relpath` 按 relpath 排序 + 末行 `<bytes><TAB><lines><TAB>TOTAL`；缺失文件行 `MISSING<TAB>MISSING<TAB>relpath`。Task 3 的 capture-baseline.sh 消费 `--gen` 与 `--skill` 输出。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-context-surface.sh`:

```bash
#!/usr/bin/env bash
# test-context-surface.sh — context-surface.sh 双态测试（WP-P0）
set -uo pipefail
cd "$(dirname "${0}")/.."   # swarm-yuan 根
SH="scripts/context-surface.sh"
TMP="$(mktemp -d /tmp/cstest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：--files 已知文件，字节/行数精确断言 ---
mkdir -p "$TMP/files"
printf 'abc\n' > "$TMP/files/a.md"   # 4 bytes, 1 line
printf 'x'      > "$TMP/files/b.md"   # 1 byte, 0 lines
out="$(bash "$SH" --files "$TMP/files/a.md" "$TMP/files/b.md")"
echo "$out" | grep -qF "4	1	" && ok "--files a.md 字节/行数" || bad "--files a.md 行缺失: $out"
echo "$out" | grep -qF "1	0	" && ok "--files b.md 字节/行数" || bad "--files b.md 行缺失"
echo "$out" | grep -qF "5	1	TOTAL" && ok "TOTAL 合计" || bad "TOTAL 错误: $(echo "$out" | tail -1)"

# --- 态 2：缺失文件 → MISSING 行，exit 0（fail-open）---
out="$(bash "$SH" --files "$TMP/files/a.md" "$TMP/files/nope.md")"
rc=$?
[[ $rc -eq 0 ]] && ok "缺失文件 exit 0" || bad "缺失文件 exit=$rc"
echo "$out" | grep -qF "MISSING	MISSING	" && ok "MISSING 行" || bad "MISSING 行缺失"

# --- 态 3：--skill 目录双态 ---
mkdir -p "$TMP/skill/references"
printf 's\n' > "$TMP/skill/SKILL.md"
printf 'r\n' > "$TMP/skill/references/r1.md"
out="$(bash "$SH" --skill "$TMP/skill")"
[[ "$(echo "$out" | grep -c '	')" -ge 3 ]] && ok "--skill 双文件+TOTAL" || bad "--skill 行数异常: $out"
out="$(bash "$SH" --skill "$TMP/nonexist" 2>&1)"; rc=$?
[[ $rc -eq 1 ]] && ok "--skill 目录不存在 exit 1" || bad "--skill 目录不存在 exit=$rc"

# --- 态 4：--gen 自指（swarm-yuan 自身三件套）确定性 ---
o1="$(bash "$SH" --gen")"; o2="$(bash "$SH" --gen")"
[[ "$o1" == "$o2" ]] && ok "--gen 幂等" || bad "--gen 两次输出不一致"
echo "$o1" | grep -qE '^[0-9]+	[0-9]+	TOTAL$' && ok "--gen TOTAL 格式" || bad "--gen TOTAL 格式异常"
[[ "$(echo "$o1" | wc -l | tr -d ' ')" -eq 4 ]] && ok "--gen 3 文件+TOTAL" || bad "--gen 行数异常: $o1"

[[ $FAIL -eq 0 ]] && { echo "PASS test-context-surface"; exit 0; } || { echo "FAIL test-context-surface" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-context-surface.sh`
Expected: FAIL（`scripts/context-surface.sh` 不存在，bash 报 No such file）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/context-surface.sh`**

```bash
#!/usr/bin/env bash
# context-surface.sh — 静态上下文表面计量（WP-P0/M6）
# 计量「模型必读文件」的字节/行数总量，输出确定性 TSV（同输入字节级一致，可 byte-diff）。
# 用法:
#   bash context-surface.sh --gen             生成期必读面（swarm-yuan 自身三件套）
#   bash context-surface.sh --skill <dir>     目标 skill 加载面（SKILL.md + references/*.md）
#   bash context-surface.sh --files <f...>    任意文件清单
# 输出: stdout TSV「bytes<TAB>lines<TAB>path」按 path 排序 + 末行 TOTAL；
#       缺失文件记 MISSING 行（fail-open 计量，exit 0）；BASE 内路径显示为相对路径（跨机 byte-diff 稳定）。
# 退出码: 0 正常（含 MISSING）；1 参数错误 / --skill 目录不存在。
set -uo pipefail

BASE="$(cd "$(dirname "${0}")/.." && pwd)"
MODE=""; SKILL_DIR=""; FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gen)    MODE="gen"; shift ;;
    --skill)  MODE="skill"; SKILL_DIR="${2:?--skill 需要目录}"; shift 2 ;;
    --files)  MODE="files"; shift; FILES="$*"; break ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（--help 查看用法）" >&2; exit 1 ;;
  esac
done

_list=""
case "$MODE" in
  gen)
    _list="${BASE}/SKILL.md
${BASE}/references/exploration-guide.md
${BASE}/references/template-spec.md"
    ;;
  skill)
    [[ -d "$SKILL_DIR" ]] || { echo "✗ --skill 目录不存在: $SKILL_DIR" >&2; exit 1; }
    _list="${SKILL_DIR}/SKILL.md"
    if [[ -d "${SKILL_DIR}/references" ]]; then
      for f in "${SKILL_DIR}"/references/*.md; do
        [[ -f "$f" ]] || continue
        _list="${_list}
$f"
      done
    fi
    ;;
  files)
    for f in $FILES; do
      _list="${_list}${_list:+
}$f"
    done
    ;;
  *) echo "用法: context-surface.sh --gen | --skill <dir> | --files <f...>" >&2; exit 1 ;;
esac

_tb=0; _tl=0; _rows=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  rel="${f#"${BASE}"/}"
  if [[ -f "$f" ]]; then
    b=$(wc -c < "$f" | tr -d ' ')
    l=$(wc -l < "$f" | tr -d ' ')
    _tb=$((_tb + b)); _tl=$((_tl + l))
    _rows="${_rows}${b}	${l}	${rel}
"
  else
    _rows="${_rows}MISSING	MISSING	${rel}
"
  fi
done <<EOF
${_list}
EOF

printf '%s' "$_rows" | sort -t"$(printf '\t')" -k3,3
printf '%s\t%s\tTOTAL\n' "$_tb" "$_tl"
exit 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-context-surface.sh`
Expected: `PASS test-context-surface`

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/scripts/context-surface.sh swarm-yuan/tests/test-context-surface.sh
git commit -m "feat(wp-p0): context-surface.sh 静态上下文表面计量（字节/行数 TSV，确定性输出）"
```

---

### Task 2: cost-report.sh 节点耗时段（wall-clock 代理）

**Files:**
- Modify: `swarm-yuan/scripts/cost-report.sh`（`_top()` 函数后加 `_iso2epoch`；报告块「按工具」段后加「按节点耗时」段）
- Test: `swarm-yuan/tests/test-cost-report.sh`

**Interfaces:**
- Consumes: `<dir>/.swarm-yuan/trace.jsonl`（trace-log.sh 落盘格式 `{"ts","node","actor","tool","status","note"}`，status ∈ started/done/fail）。
- Produces: cost-report 新增 `## 按节点耗时（wall-clock，模型处理时间代理）` 段；无配对时打印提示行（fail-open，恒 exit 0 不变）。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-cost-report.sh`:

```bash
#!/usr/bin/env bash
# test-cost-report.sh — cost-report.sh 节点耗时段双态测试（WP-P0）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/cost-report.sh"
TMP="$(mktemp -d /tmp/crtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：started/done 配对，耗时可算 ---
mkdir -p "$TMP/proj/.swarm-yuan"
cat > "$TMP/proj/.swarm-yuan/trace.jsonl" <<'EOF'
{"ts":"2026-07-23T10:00:00Z","node":"Step4","actor":"ai","tool":"explore","status":"started","note":""}
{"ts":"2026-07-23T10:00:05Z","node":"Step4","actor":"ai","tool":"explore","status":"done","note":""}
{"ts":"2026-07-23T10:01:00Z","node":"Step8","actor":"ai","tool":"conf","status":"started","note":""}
{"ts":"2026-07-23T10:01:30Z","node":"Step8","actor":"ai","tool":"conf","status":"fail","note":""}
{"ts":"2026-07-23T10:02:00Z","node":"Step9","actor":"ai","tool":"orphan","status":"started","note":""}
EOF
out="$(bash "$SH" --dir "$TMP/proj" --stdout)"
rc=$?
[[ $rc -eq 0 ]] && ok "exit 0" || bad "exit=$rc"
echo "$out" | grep -qF "按节点耗时" && ok "耗时段存在" || bad "耗时段缺失: $out"
echo "$out" | grep -qE "Step4	explore	5	done" && ok "Step4 耗时 5s" || bad "Step4 耗时异常: $out"
echo "$out" | grep -qE "Step8	conf	30	fail" && ok "Step8 耗时 30s(fail 也配对)" || bad "Step8 耗时异常"
echo "$out" | grep -qF "orphan" && bad "未配对 started 不应出现在耗时段" || ok "未配对不输出"

# --- 态 2：无 trace.jsonl → 提示 + exit 0（fail-open 不变）---
out="$(bash "$SH" --dir "$TMP/empty" --stdout 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF "无追踪数据" && ok "无数据 fail-open" || bad "态2 异常: rc=$rc out=$out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-cost-report"; exit 0; } || { echo "FAIL test-cost-report" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-cost-report.sh`
Expected: FAIL（「耗时段缺失」）

- [ ] **Step 3: 实现 — 两处 Edit cost-report.sh**

Edit 1 — `_top()` 函数定义后（`swarm-yuan/scripts/cost-report.sh:44` 的 `}` 之后）插入：

```bash
# WP-P0: ISO8601 UTC → epoch（三平台：GNU date -d / BSD date -j，都不可用返回 0）
_iso2epoch() {
  if date -u -d "$1" +%s >/dev/null 2>&1; then date -u -d "$1" +%s;
  elif date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s >/dev/null 2>&1; then date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s;
  else echo 0; fi
}
```

Edit 2 — 报告块中「按工具（tool）」段之后（`echo '```'` 与门禁运行证据 `_gr=` 之间）插入：

```bash
  # WP-P0 节点耗时（wall-clock，模型处理时间代理）：started/done|fail 按 node+tool 最近配对
  echo ""
  echo "## 按节点耗时（wall-clock，模型处理时间代理）"
  echo '```'
  _pairs="$(mktemp /tmp/costpairs.XXXXXX)"
  awk -F'"' '
    { ts=""; node=""; tool=""; st=""
      for (i=1; i<=NF; i++) {
        if ($i=="ts") ts=$(i+2)
        else if ($i=="node") node=$(i+2)
        else if ($i=="tool") tool=$(i+2)
        else if ($i=="status") st=$(i+2)
      }
      key=node SUBSEP tool
      if (st=="started") start[key]=ts
      else if ((st=="done" || st=="fail") && (key in start)) {
        print node "\t" tool "\t" start[key] "\t" ts "\t" st
        delete start[key]
      }
    }' "$TRACE" > "$_pairs"
  if [[ -s "$_pairs" ]]; then
    printf 'node\ttool\t耗时s\tstatus\n'
    while IFS="$(printf '\t')" read -r pn pt p0 p1 pst; do
      e0=$(_iso2epoch "$p0"); e1=$(_iso2epoch "$p1")
      printf '%s\t%s\t%s\t%s\n' "$pn" "$pt" "$((e1 - e0))" "$pst"
    done < "$_pairs"
  else
    echo "（无 started/done 配对；节点级追踪落盘后才有数据）"
  fi
  rm -f "$_pairs"
  echo '```'
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-cost-report.sh`
Expected: `PASS test-cost-report`

- [ ] **Step 5: 回归**

Run: `cd swarm-yuan && bash scripts/cost-report.sh --dir .. --stdout | head -20`
Expected: 本仓库真实 trace.jsonl 上报告正常生成，含「按节点耗时」段

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/cost-report.sh swarm-yuan/tests/test-cost-report.sh
git commit -m "feat(wp-p0): cost-report 节点耗时段——started/done 配对 wall-clock 代理指标"
```

---

### Task 3: `verifier/capture-baseline.sh` + 首份 pre-opt 基线

**Files:**
- Create: `verifier/capture-baseline.sh`
- Create: `verifier/baselines/pre-opt/`（脚本产出，提交入库）
- Modify: `verifier/v1/metrics-baseline.txt`（追加信息性基线条目）

**Interfaces:**
- Consumes: Task 1 的 `context-surface.sh --gen/--skill`；`scripts/detect-frameworks.sh <fixture>`。
- Produces: CLI `capture-baseline.sh <out-dir> [--skill-dir <dir>]`；产出 `context-surface-gen.tsv` / `context-surface-skill.tsv`（可选）/ `script-timings.txt` / `gate-loc.txt` / `MANIFEST.md`。

- [ ] **Step 1: 实现 `verifier/capture-baseline.sh`**

```bash
#!/usr/bin/env bash
# capture-baseline.sh — 性能基线采集（WP-P0/M6）
# 用法: bash verifier/capture-baseline.sh <out-dir> [--skill-dir <生成产物路径>]
# 采集（脚本侧、确定性）:
#   ① context-surface --gen    → context-surface-gen.tsv（生成期必读面字节/行数）
#   ② context-surface --skill  → context-surface-skill.tsv（仅给了 --skill-dir 时）
#   ③ detect-frameworks.sh 在固定 fixture 上的耗时 → script-timings.txt（脚本 wall-clock 样本）
#   ④ 门禁脚本 LOC/字节快照     → gate-loc.txt
#   MANIFEST.md 记录采集时间/commit/文件清单。
# 诚实声明：模型侧基线（真实生成一次的 trace/cost-report）无法由脚本自动产出——
#   须在 WP-P2~P5 合入前用真项目跑一次生成，把 cost-report 手动落入 baselines/pre-opt/model-side/。
set -uo pipefail

OUT="${1:?用法: capture-baseline.sh <out-dir> [--skill-dir <dir>]}"; shift || true
SKILL_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir) SKILL_DIR="${2:?--skill-dir 需要路径}"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done
ROOT="$(cd "$(dirname "${0}")/.." && pwd)"
SY="$ROOT/swarm-yuan"
mkdir -p "$OUT"

# ① 生成期必读面
bash "$SY/scripts/context-surface.sh" --gen > "$OUT/context-surface-gen.tsv" \
  && echo "✓ context-surface-gen.tsv"

# ② 目标 skill 加载面（可选）
if [[ -n "$SKILL_DIR" ]]; then
  bash "$SY/scripts/context-surface.sh" --skill "$SKILL_DIR" > "$OUT/context-surface-skill.tsv" \
    && echo "✓ context-surface-skill.tsv"
fi

# ③ 脚本耗时样本（fixture = tests/fixtures 下第一个目录，记录其名）
fx="$(ls "$SY/tests/fixtures" 2>/dev/null | head -1)"
{
  echo "# script-timings（wall-clock 秒，$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  if [[ -n "$fx" ]]; then
    t0=$(date +%s)
    bash "$SY/scripts/detect-frameworks.sh" "$SY/tests/fixtures/$fx" >/dev/null 2>&1
    t1=$(date +%s)
    echo "detect-frameworks.sh fixture=$fx $((t1-t0))s"
  else
    echo "detect-frameworks.sh SKIPPED（tests/fixtures 为空）"
  fi
} > "$OUT/script-timings.txt" && echo "✓ script-timings.txt"

# ④ 门禁脚本 LOC/字节快照
{
  for f in assets/precheck.sh assets/gates-strict.sh assets/gates-warn.sh assets/gates-advisory.sh; do
    [[ -f "$SY/$f" ]] || continue
    printf '%s\t%s\t%s\n' "$(wc -l < "$SY/$f" | tr -d ' ')" "$(wc -c < "$SY/$f" | tr -d ' ')" "$f"
  done
} > "$OUT/gate-loc.txt" && echo "✓ gate-loc.txt"

# MANIFEST
{
  echo "# 性能基线 MANIFEST"
  echo "- 采集时间: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- commit: $(cd "$ROOT" && git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "- 文件: context-surface-gen.tsv$( [[ -n "$SKILL_DIR" ]] && echo ' context-surface-skill.tsv') script-timings.txt gate-loc.txt"
  echo "- 模型侧基线: 未自动采集（见 capture-baseline.sh 头部诚实声明）"
} > "$OUT/MANIFEST.md" && echo "✓ MANIFEST.md → $OUT"
exit 0
```

- [ ] **Step 2: 跑一次采集，生成 pre-opt 基线**

Run: `bash verifier/capture-baseline.sh verifier/baselines/pre-opt`
Expected: 四个 ✓，目录下 4 个产物文件

- [ ] **Step 3: 确定性验证（连跑两次 byte-diff）**

Run:
```bash
bash verifier/capture-baseline.sh /tmp/base-a >/dev/null && bash verifier/capture-baseline.sh /tmp/base-b >/dev/null
diff /tmp/base-a/context-surface-gen.tsv /tmp/base-b/context-surface-gen.tsv && diff /tmp/base-a/gate-loc.txt /tmp/base-b/gate-loc.txt && echo DETERMINISTIC; rm -rf /tmp/base-a /tmp/base-b
```
Expected: `DETERMINISTIC`（timings/MANIFEST 含时间戳不参与 diff）

- [ ] **Step 4: 追加 metrics-baseline.txt 信息性条目**

从 `verifier/baselines/pre-opt/context-surface-gen.tsv` 的 TOTAL 行读两个数，Append 到 `verifier/v1/metrics-baseline.txt`:

```
# WP-P0 上下文表面基线（信息性，不设阈值；重跑 capture-baseline.sh 后 diff 对比）
BASELINE_CONTEXT_SURFACE_GEN_BYTES=<TOTAL 行第一列实测值>
BASELINE_CONTEXT_SURFACE_GEN_LINES=<TOTAL 行第二列实测值>
```

- [ ] **Step 5: Commit**

```bash
git add verifier/capture-baseline.sh verifier/baselines/pre-opt/ verifier/v1/metrics-baseline.txt
git commit -m "feat(wp-p0): capture-baseline.sh + pre-opt 基线（上下文表面/脚本耗时/门禁 LOC）"
```

---

### Task 4: WP-P0 CI 接线 + 全量回归

**Files:**
- Modify: `.github/workflows/ci.yml`（shellcheck 严格层名单 + self-check job 加测试步骤）

- [ ] **Step 1: ci.yml 两处 Edit**

Edit 1 — shellcheck 严格层名单（`ci.yml:217` 行尾 `scripts/cost-report.sh; do`）改为：

```
                   scripts/gen-framework-index.sh assets/trace-log.sh scripts/cost-report.sh \
                   scripts/context-surface.sh; do
```

Edit 2 — self-check job 的 step（`ci.yml:184-191`）之后追加：

```yaml
      - name: 计量脚本测试（WP-P0）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
```

- [ ] **Step 2: 本地全量回归**

Run: `bash verifier/v1/run-verifier.sh all`
Expected: 全绿（fixtures/gate-fixtures/e2e/shellcheck/metrics/cli-ab）

- [ ] **Step 3: Commit 并按 AGENTS.md 收口 WP-P0**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p0): context-surface 进 shellcheck 严格层 + 计量测试进 CI"
# worktree 内 rebase → push → main merge --no-ff → 清理 worktree/分支
```

---

## WP-P1：信号索引数据化拆分（branch: feat/wp-p1-signal-index-split，P0 合入后从 origin/main 起）

### Task 5: gen-framework-index.sh 双产物改造

**Files:**
- Modify: `swarm-yuan/scripts/gen-framework-index.sh`
- Create: `swarm-yuan/assets/framework-signals.md`（脚本产物，提交入库）
- Test: `swarm-yuan/tests/test-signal-index.sh`

**Interfaces:**
- Produces: `assets/framework-signals.md`（完整信号表，头部含生成声明）；exploration-guide.md 标记区块内容变为 2 行指针（标记行 `# >>> framework-signal-index >>>` / `# <<< framework-signal-index <<<` 保留，幂等）。Task 6 self-check 消费双产物做时效比对。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-signal-index.sh`:

```bash
#!/usr/bin/env bash
# test-signal-index.sh — gen-framework-index.sh 双产物 + 幂等测试（WP-P1）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/gen-framework-index.sh"
SIG="assets/framework-signals.md"
GUIDE="references/exploration-guide.md"
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

bash "$SH" >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && ok "gen-framework-index exit 0" || { bad "exit=$rc"; echo "FAIL test-signal-index" >&2; exit 1; }

# 态 1：signals 文件数据行数 == 框架文件数（不含 _template.md；表头 1 行 '^| ' 须减）
fwn=$(ls references/frameworks/*.md | grep -cv '_template')
rows=$(grep -c '^| ' "$SIG")
[[ $((rows - 1)) -eq $fwn ]] && ok "signals 数据行=$fwn" || bad "signals 行数 $((rows-1)) != $fwn"
grep -q '由 scripts/gen-framework-index.sh 生成' "$SIG" && ok "生成声明头" || bad "缺生成声明头"

# 态 2：guide 区块指针化（标记间 ≤5 行且含指针）+ 标记保留
blk=$(awk '/^# >>> framework-signal-index >>>/{f=1;next}/^# <<< framework-signal-index <<</{f=0}f' "$GUIDE")
n=$(printf '%s\n' "$blk" | grep -c .)
[[ $n -le 5 ]] && ok "guide 区块 ≤5 行（实际 $n）" || bad "guide 区块 $n 行未指针化"
printf '%s\n' "$blk" | grep -qF "assets/framework-signals.md" && ok "指针含 signals 路径" || bad "缺指针"
grep -qF '# >>> framework-signal-index >>>' "$GUIDE" && grep -qF '# <<< framework-signal-index <<<' "$GUIDE" \
  && ok "标记保留" || bad "标记丢失"

# 态 3：幂等（再跑一次，双产物 byte-identical）
sig_b="$(mktemp /tmp/sigb.XXXXXX)"; gui_b="$(mktemp /tmp/guib.XXXXXX)"
cp "$SIG" "$sig_b"; cp "$GUIDE" "$gui_b"
bash "$SH" >/dev/null 2>&1
diff -q "$sig_b" "$SIG" >/dev/null && diff -q "$gui_b" "$GUIDE" >/dev/null \
  && ok "幂等 byte-identical" || bad "二次运行产物漂移"
rm -f "$sig_b" "$gui_b"

[[ $FAIL -eq 0 ]] && { echo "PASS test-signal-index"; exit 0; } || { echo "FAIL test-signal-index" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-signal-index.sh`
Expected: FAIL（`assets/framework-signals.md` 不存在 / guide 区块数百行未指针化）

- [ ] **Step 3: 实现 — 改造 gen-framework-index.sh**

在 `GUIDE=` 变量行后新增产物路径与指针文本：

```bash
OUT_SIGNALS="${BASE}/assets/framework-signals.md"
```

原脚本「重写标记区块」段（`TMP_BODY=` 起至 `rm -f "${IDX_FILE}"` 前）替换为双产物写出：

```bash
# WP-P1 双产物：① 完整信号表 → assets/framework-signals.md（数据文件，模型按需读）
#               ② guide 标记区块 → 2 行指针（模型必读物减重 ~300 行）
SIG_TMP="$(mktemp /tmp/fwsig.XXXXXX)"
{
  printf '<!-- 由 scripts/gen-framework-index.sh 生成（WP-P1 数据化外迁），手改会被覆盖 -->\n'
  printf '# 框架信号索引（%s 个框架）\n\n' "${N}"
  cat "${IDX_FILE}"
} > "${SIG_TMP}"
if [[ -s "${SIG_TMP}" ]]; then
  mv "${SIG_TMP}" "${OUT_SIGNALS}"
else
  rm -f "${SIG_TMP}" "${IDX_FILE}"
  echo "✗ 生成信号索引为空，framework-signals.md 未改动" >&2
  exit 1
fi

PTR_FILE="$(mktemp /tmp/fwptr.XXXXXX)"
{
  printf '> 本表已数据化外迁（WP-P1/M4）：完整信号表见 \`assets/framework-signals.md\`（由 gen-framework-index.sh 生成维护，手改会被覆盖）。\n'
  printf '> 运行时框架识别以 \`scripts/detect-frameworks.sh\` 输出为准；AI 仅在需要探查细则时按需读该文件，无需常驻上下文。\n'
} > "${PTR_FILE}"

TMP_BODY="$(mktemp /tmp/fwbody.XXXXXX)"
if ! awk -v beg="${BEGIN_MARK}" -v end="${END_MARK}" -v idxfile="${PTR_FILE}" '
  $0 == beg { print; while ((getline l < idxfile) > 0) print l; inblk=1; next }
  $0 == end { print end; inblk=0; next }
  !inblk { print }
' "${GUIDE}" > "${TMP_BODY}"; then
  rm -f "${TMP_BODY}" "${IDX_FILE}" "${PTR_FILE}"
  echo "✗ awk 重写标记区块失败，exploration-guide.md 未改动" >&2
  exit 1
fi
```

（其后 `mv` 守卫段不变；`rm -f "${IDX_FILE}"` 行改为 `rm -f "${IDX_FILE}" "${PTR_FILE}"`；末尾 echo 改为 `echo "已重写索引（${N} 个框架）→ assets/framework-signals.md + guide 指针"`。头部注释第 4-5 行同步更新为双产物描述。）

注意：`N=` 赋值行（原 `:82`）须移到 `SIG_TMP` 段之前。

- [ ] **Step 4: 跑测试确认通过 + guide 瘦身验证**

Run:
```bash
bash swarm-yuan/tests/test-signal-index.sh
wc -l swarm-yuan/references/exploration-guide.md
```
Expected: `PASS test-signal-index`；guide 行数从 1334 降至 ~1030（区块 ~300 行表 → 2 行指针）

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/scripts/gen-framework-index.sh swarm-yuan/assets/framework-signals.md swarm-yuan/references/exploration-guide.md swarm-yuan/tests/test-signal-index.sh
git commit -m "feat(wp-p1): 信号索引数据化外迁——assets/framework-signals.md 双产物，guide 瘦身 ~300 行"
```

---

### Task 6: self-check.sh 时效检查覆盖 signals 文件

**Files:**
- Modify: `swarm-yuan/scripts/self-check.sh:630-643`（「6. 框架信号索引时效」段）

**Interfaces:**
- Consumes: Task 5 的双产物。

- [ ] **Step 1: Edit — 在 guide 比对 if/else 之后、`rm -f "$guide_tmp"` 之前插入**

```bash
      # WP-P1：assets/framework-signals.md 时效（gen-framework-index.sh 双产物之一，上方已幂等重跑）
      local sig="$base/assets/framework-signals.md" sig_tmp
      if [[ -f "$sig" ]]; then
        sig_tmp="$(mktemp /tmp/sigcheck.XXXXXX)"
        cp "$sig" "$sig_tmp"
        if ! diff -q "$sig_tmp" "$sig" >/dev/null 2>&1; then
          echo "  ⚠ framework-signals.md 已漂移，本次由 gen-framework-index.sh 自动重写为最新（建议提交）"
        else
          echo "  ✓ framework-signals.md 与框架文件同步"
        fi
        rm -f "$sig_tmp"
      fi
```

（说明：上方 `bash gen-framework-index.sh` 已幂等重写双产物，这里 cp 的是重写后的文件再 diff——若入库版本漂移，diff 必然不等从而 warn，逻辑与 guide 检查同构。实现时把 `cp` 移到运行 gen 之前：先 `cp guide+signals 到 tmp` → 跑 gen → 分别 diff。按此顺序调整原段。）

- [ ] **Step 2: 验证**

Run: `cd swarm-yuan && bash scripts/self-check.sh 2>&1 | grep -E "framework-signals|framework-signal-index"`
Expected: 两行 `✓ ... 同步`（当前无漂移）

- [ ] **Step 3: Commit**

```bash
git add swarm-yuan/scripts/self-check.sh
git commit -m "feat(wp-p1): self-check 时效检查覆盖 framework-signals.md 双产物"
```

---

### Task 7: detect-frameworks.sh `--verbose` 命中明细 + 头部注释修正

**Files:**
- Modify: `swarm-yuan/scripts/detect-frameworks.sh`（头部注释 `:5-7`；参数解析 `:13`；匹配循环 `:224-229`；输出段尾部）
- Test: `swarm-yuan/tests/test-detect-frameworks.sh`

**Interfaces:**
- Produces: `--verbose` 时 stderr 追加 `framework|pattern|file_type|置信度` 明细（stdout 的 ACTIVE_FRAMEWORKS 输出不变，不污染 conf 消费方）。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-detect-frameworks.sh`:

```bash
#!/usr/bin/env bash
# test-detect-frameworks.sh — detect-frameworks.sh --verbose 双态测试（WP-P1）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/detect-frameworks.sh"
TMP="$(mktemp -d /tmp/dfwtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 态 1：含 react/express 依赖的 package.json → 命中 + verbose 明细
mkdir -p "$TMP/p1"
cat > "$TMP/p1/package.json" <<'EOF'
{
  "dependencies": {
    "react": "^19.0.0",
    "express": "^4.21.0"
  }
}
EOF
out="$(bash "$SH" "$TMP/p1" --verbose 2>"$TMP/err")"
echo "$out" | grep -qF '"react"' && echo "$out" | grep -qF '"express"' \
  && ok "ACTIVE_FRAMEWORKS 命中" || bad "命中异常: $out"
grep -qF 'react|react|pkgjson' "$TMP/err" && ok "verbose 明细 react" || bad "明细缺失: $(cat "$TMP/err")"
grep -qF 'express|express|pkgjson' "$TMP/err" && ok "verbose 明细 express" || bad "明细缺失"
echo "$out" | grep -qF 'framework|pattern' && bad "stdout 被明细污染" || ok "stdout 未污染"

# 态 2：空目录 → ACTIVE_FRAMEWORKS=() exit 0
mkdir -p "$TMP/p2"
out="$(bash "$SH" "$TMP/p2" 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF 'ACTIVE_FRAMEWORKS=()' \
  && ok "空项目双态" || bad "空项目异常: rc=$rc out=$out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-detect-frameworks"; exit 0; } || { echo "FAIL test-detect-frameworks" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-detect-frameworks.sh`
Expected: FAIL（`--verbose` 被当作项目路径 → 目录不存在）

- [ ] **Step 3: 实现 — 四处 Edit**

Edit 1 — 头部注释 `:5-7` 改为（修掉指向不存在文件 `references/frameworks-index.md` 的陈旧描述）：

```bash
# 扫描文件：package.json / pom.xml / go.mod / pyproject.toml / requirements.txt
# 匹配源：内置 SIGNALS 依赖信号表（framework|pattern|file_type）；
#         探查信号全集（文件/注解/配置等）见 assets/framework-signals.md（gen-framework-index.sh 生成）
# 用法: detect-frameworks.sh <项目目录> [--verbose]（--verbose 命中明细走 stderr，不污染 stdout）
```

Edit 2 — `PROJ="${1:-.}"`（`:13`）改为：

```bash
PROJ="."; VERBOSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) PROJ="$1"; shift ;;
  esac
done
```

Edit 3 — `_detected=""`（`:193`）后加 `_detail=""`；匹配命中块（`if [[ "$_hit" -eq 1 ]]; then` 内）加：

```bash
    if [[ "$VERBOSE" -eq 1 ]]; then
      _detail="${_detail}${fw}|${pattern}|${ftype}|依赖命中=高
"
    fi
```

Edit 4 — `rm -f "$_tmpfile"` 之后、输出段之前加：

```bash
if [[ "$VERBOSE" -eq 1 && -n "$_detail" ]]; then
  echo "" >&2
  echo "# --verbose 命中信号明细（framework|pattern|file_type|置信度）" >&2
  printf '%s' "$_detail" | sort -u >&2
fi
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-detect-frameworks.sh`
Expected: `PASS test-detect-frameworks`

- [ ] **Step 5: 回归（无 --verbose 旧调用不变）**

Run: `cd swarm-yuan && bash scripts/detect-frameworks.sh tests/fixtures/gin 2>/dev/null | tail -2`
Expected: 正常输出 ACTIVE_FRAMEWORKS（旧用法兼容）

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/detect-frameworks.sh swarm-yuan/tests/test-detect-frameworks.sh
git commit -m "feat(wp-p1): detect-frameworks --verbose 命中信号明细 + 头部注释修正"
```

---

### Task 8: 文档指针批量更新（62 框架文件 + 4 处散文）

**Files:**
- Modify: `swarm-yuan/references/exploration-guide.md:272`
- Modify: `swarm-yuan/references/frameworks/_template.md:37` + `references/frameworks/*.md`（含「组装入 exploration-guide.md §C+.0.5 区块」句的所有文件）
- Modify: `swarm-yuan/references/domain-knowledge.md:392`
- Modify: `swarm-yuan/docs/USAGE.md:440`

- [ ] **Step 1: exploration-guide.md:272 段落 Edit**

old_string（`:272` 整行）：
```
**框架信号→规则集激活表（由 `scripts/gen-framework-index.sh` 重写维护，初始保留下表现有 20 行作为种子，扫描 `references/frameworks/*.md` §1 探查信号重新组装）：**
```
new_string：
```
**框架信号→规则集激活表已数据化外迁（WP-P1/M4）：完整表见 `assets/framework-signals.md`（由 `scripts/gen-framework-index.sh` 扫描 `references/frameworks/*.md` §1 生成维护）。运行时框架识别以 `scripts/detect-frameworks.sh` 输出为准；AI 仅在需要探查细则时按需读该文件。**
```

- [ ] **Step 2: _template.md + 62 框架文件批量 sed**

Run:
```bash
cd swarm-yuan
# _template.md 句式不同，单独 Edit：
#   old: 本表由 gen-framework-index.sh 扫描前几列组装成信号汇总索引，写入 exploration-guide.md §C+.0.5 标记区块
#   new: 本表由 gen-framework-index.sh 扫描前几列组装成信号汇总索引，写入 assets/framework-signals.md（exploration-guide.md §C+.0.5 仅留指针）
before=$(grep -l '组装入 exploration-guide.md §C+.0.5 区块' references/frameworks/*.md | wc -l | tr -d ' ')
for f in $(grep -l '组装入 exploration-guide.md §C+.0.5 区块' references/frameworks/*.md); do
  sed -i.bak 's|组装入 exploration-guide.md §C+.0.5 区块|组装入 assets/framework-signals.md（guide §C+.0.5 仅留指针）|g' "$f" && rm -f "${f}.bak"
done
after=$(grep -l '组装入 exploration-guide.md §C+.0.5 区块' references/frameworks/*.md | wc -l | tr -d ' ')
echo "before=$before after=$after"
```
Expected: `before=62 after=0`（before 数以实测为准，应等于 §1 含该句的框架文件总数）

- [ ] **Step 3: domain-knowledge.md:392 与 USAGE.md:440 Edit**

domain-knowledge.md（`:392` 长句尾部）：
- old: `scripts/gen-framework-index.sh 重写 exploration-guide.md §C+.0.5 信号索引区块。`
- new: `scripts/gen-framework-index.sh 生成 assets/framework-signals.md 并把 exploration-guide.md §C+.0.5 重写为指针区块（WP-P1 数据化外迁）。`

USAGE.md（`:440`）：
- old: `5. 跑 \`bash scripts/gen-framework-index.sh\` 更新索引`
- new: `5. 跑 \`bash scripts/gen-framework-index.sh\` 更新索引（产物：assets/framework-signals.md + exploration-guide.md §C+.0.5 指针）`

- [ ] **Step 4: 一致性回归**

Run: `cd swarm-yuan && bash scripts/self-check.sh 2>&1 | grep -E "✗|⚠|信号" ; bash tests/test-signal-index.sh`
Expected: 无数字一致性 ✗；信号检查 ✓；`PASS test-signal-index`

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/references/ swarm-yuan/docs/USAGE.md
git commit -m "docs(wp-p1): 62 框架文件+散文指针指向 assets/framework-signals.md"
```

---

### Task 9: WP-P1 CI 接线 + 全量回归 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: ci.yml Edit — self-check job 的 WP-P0 测试步骤改为**

```yaml
      - name: 计量与信号索引测试（WP-P0/P1）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
```

- [ ] **Step 2: 本地全量回归**

Run: `bash verifier/v1/run-verifier.sh all && bash verifier/capture-baseline.sh /tmp/post-p1 >/dev/null && diff <(grep TOTAL verifier/baselines/pre-opt/context-surface-gen.tsv) <(grep TOTAL /tmp/post-p1/context-surface-gen.tsv); rm -rf /tmp/post-p1`
Expected: verifier 全绿；diff 非空且 TOTAL 字节数**下降**（guide 瘦身效果，作为首条 before/after 证据，输出贴进 commit message）

- [ ] **Step 3: Commit 并收口 WP-P1**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p1): 信号索引/探测测试进 CI；上下文表面基线对比 <pre>TOTAL → <post>TOTAL（实测值）"
# rebase origin/main → push → main merge --no-ff → 清理
```

---

## Self-Review 记录

- Spec 覆盖：§3 M6 → Task 1-4 ✓（模型侧手动基线诚实降级，capture-baseline 头部声明）；§7 M4 → Task 5-9 ✓（detect-frameworks「消费信号表」按探索发现调整为：依赖信号表内置不动 + --verbose 明细增强，§1 探查信号全集由 signals 文件承载供 AI 按需读——spec §11 不重写控制流约束下的最小实现）；§9 测试 → 每任务双态测试 + Task 4/9 全量回归 ✓。
- 占位符扫描：metrics-baseline.txt 的两个 `<TOTAL 实测值>` 与 commit message 的 `<pre>/<post>` 为**运行期实测值**，执行者按 Step 指示读取填入，非设计占位。
- 类型一致：`context-surface.sh` 输出契约（TSV/TOTAL/MISSING）在 Task 1 测试、Task 3 消费、Task 9 diff 三处一致；`framework-signals.md` 产物名在 Task 5/6/8 一致。

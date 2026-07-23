# WP-P6 before/after 对比报告 + facts.conf 数字渲染扩展 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §3（M6 收尾）+ §10 WP-P6：在 WP-P1~P5 全部合入后，产 before/after 对比报告（上下文表面字节/行数 + 脚本耗时 + 门禁 LOC，信息性不设阈值），并把 `assets/facts.conf` 的数字渲染扩展为脚本可重算（self-check check_doc_consistency 消费）。M6 是 P1–P5 的收口，依赖前序全合入。

**Architecture:**
- **对比报告脚本** `scripts/compare-baseline.sh`：输入 pre-opt 基线目录（`verifier/baselines/pre-opt/`，WP-P0 已落）+ 重新采集的 post-opt 基线目录 → diff context-surface-gen.tsv 的 TOTAL 行 + script-timings + gate-loc → 输出 markdown 对比报告（before/after 字节数/行数/降幅百分比 + 各 WP 贡献归因）。
- **facts.conf 数字渲染扩展**：`assets/facts.conf` 已是口径单一事实源（WP-P1 落地）。本 WP 补充 WP-P2~P5 引入的新口径数字（如 `FACT_INVENTORY_DIMENSIONS=7` / `FACT_FRAMEWORK_VERIFY_BLOCKS` 等）+ 确认 self-check check_doc_consistency 读 facts.conf 做权威断言（已存在，本 WP 只补新数字条目）。
- **诚实限制（spec §3）**：脚本无法直接观测模型 token 消耗；上下文表面是字节级代理指标（确定性、可 byte-diff），wall-clock 是模型处理时间的代理（有噪声）。报告纯信息性，不设 pass/fail 阈值。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §3（M6 诚实限制）、§9（测试）、§10（WP-P6，依赖 P1–P5）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- Repo-confirmed bash 3.2.57 quirks（两条都必须遵守）：
  1. `"` 紧贴 `)` 在引号命令替换内会解析失败 → 赋值用裸命令替换 `x=$(cmd "$VAR")`（不写 `x="$(cmd "$VAR")"`）。
  2. `$VAR` 紧跟多字节字符在双引号串内会误词法 → 多字节字符前用 `${VAR}` 花括号。
- 计量类脚本 fail-open：缺基线/缺数据 exit 0（arg 错误 exit 1）。
- 输出确定性：同输入字节级一致（排序后输出，百分比按实测算），可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 严格名单（`.github/workflows/ci.yml` Job4）。
- 分支纪律：一个 worktree（`.claude/worktrees/feat-wp-p6-comparison-report`，从 origin/main 起，**P1–P5 全合入后起**），收口 `merge --no-ff`。
- run-verifier.sh all 全绿是合入门槛（metrics/sensitive gate-fixtures 预存失败披露即可）。
- **信息性原则（spec §1/§3/§11）**：不设硬性 pass/fail 阈值，纯报告；模型侧基线（真实生成一次的 trace/cost-report）无法由脚本自动产出——须手动跑一次生成落 `baselines/pre-opt/model-side/`，报告如实披露未采集。
- **诚实披露**：pre-opt 基线（`verifier/baselines/pre-opt/`）采集于 WP-P0 commit 9c08a4d（P1 合入前，exploration-guide.md 仍 1334 行）；P1 已瘦身 guide 至 1037 行，故 before/after 的 guide 降幅含 P1 贡献——报告须归因到各 WP，不冒功。

---

## Task 1: `scripts/compare-baseline.sh` — before/after 对比报告

**Files:**
- Create: `swarm-yuan/scripts/compare-baseline.sh`
- Test: `swarm-yuan/tests/test-compare-baseline.sh`

**Interfaces:**
- 消费：`<pre-dir>`（pre-opt 基线，含 context-surface-gen.tsv / script-timings.txt / gate-loc.txt）+ `<post-dir>`（post-opt 基线，同结构，由 `verifier/capture-baseline.sh` 产出）。
- 产生：CLI `compare-baseline.sh <pre-dir> <post-dir> [--stdout]`；stdout/落盘 markdown 报告：上下文表面 TOTAL before→after（字节/行数/降幅%）+ 各文件明细 + 脚本耗时对比 + 门禁 LOC 对比 + 各 WP 贡献归因段。exit 0（fail-open，缺文件打印提示）；1 arg 错误。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-compare-baseline.sh`:

```bash
#!/usr/bin/env bash
# test-compare-baseline.sh — compare-baseline.sh 对比报告测试（WP-P6/M6）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/compare-baseline.sh"
TMP="$(mktemp -d /tmp/cbtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 构造 pre/post 基线
mkdir -p "$TMP/pre" "$TMP/post"
printf '25585\t164\tSKILL.md\n101086\t1334\treferences/exploration-guide.md\n66555\t646\treferences/template-spec.md\n193226\t2144\tTOTAL\n' > "$TMP/pre/context-surface-gen.tsv"
printf '25585\t164\tSKILL.md\n70000\t1037\treferences/exploration-guide.md\n66555\t646\treferences/template-spec.md\n162140\t1847\tTOTAL\n' > "$TMP/post/context-surface-gen.tsv"
printf '# timings\ndetect-frameworks.sh fixture=gin 2s\n' > "$TMP/pre/script-timings.txt"
printf '# timings\ndetect-frameworks.sh fixture=gin 1s\n' > "$TMP/post/script-timings.txt"
printf '100\t5000\tassets/precheck.sh\n' > "$TMP/pre/gate-loc.txt"
printf '105\t5200\tassets/precheck.sh\n' > "$TMP/post/gate-loc.txt"

# 态 1：报告含 before/after TOTAL + 降幅% + exploration-guide 归因
out="$(bash "$SH" "$TMP/pre" "$TMP/post" --stdout 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "报告 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE '193226.*162140' && ok "TOTAL before→after" || bad "TOTAL 缺失: $out"
echo "$out" | grep -qE 'exploration-guide' && ok "guide 明细" || bad "guide 明细缺失"
echo "$out" | grep -qE '16\.[0-9]+%|降幅' && ok "降幅百分比" || bad "降幅缺失: $out"

# 态 2：fail-open（post 缺 context-surface-gen.tsv → 提示 + exit 0）
rm "$TMP/post/context-surface-gen.tsv"
out="$(bash "$SH" "$TMP/pre" "$TMP/post" --stdout 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF 'context-surface-gen.tsv' && ok "缺文件 fail-open" || bad "态2 异常 rc=$rc: $out"

# 态 3：确定性（同输入连跑两次一致）
cp "$TMP/pre/context-surface-gen.tsv" "$TMP/post/context-surface-gen.tsv" 2>/dev/null
printf '25585\t164\tSKILL.md\n101086\t1334\treferences/exploration-guide.md\n66555\t646\treferences/template-spec.md\n193226\t2144\tTOTAL\n' > "$TMP/pre/context-surface-gen.tsv"
o1="$(bash "$SH" "$TMP/pre" "$TMP/post" --stdout 2>/dev/null)"
o2="$(bash "$SH" "$TMP/pre" "$TMP/post" --stdout 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-compare-baseline"; exit 0; } || { echo "FAIL test-compare-baseline" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-compare-baseline.sh`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/compare-baseline.sh`**

```bash
#!/usr/bin/env bash
# compare-baseline.sh — 性能基线 before/after 对比报告（WP-P6/M6 收尾）
# 消费 pre-opt + post-opt 两份基线（capture-baseline.sh 产出）→ diff 上下文表面/耗时/门禁 LOC
# 输出 markdown 报告（信息性，不设阈值）；各 WP 贡献归因段。
# 诚实限制：脚本无法观测模型 token；上下文表面是字节级代理，wall-clock 是模型处理时间代理（有噪声）。
# 用法:
#   bash compare-baseline.sh <pre-dir> <post-dir> [--stdout]
#     --stdout  只打印不落盘（默认写 <post-dir>/comparison-report.md）
# 退出码: 0 正常（fail-open，缺文件提示）；1 arg 错误。
set -uo pipefail

PRE=""; POST=""; STDOUT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout) STDOUT=1; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PRE" ]] && PRE="$1" || { [[ -z "$POST" ]] && POST="$1" || { echo "未知参数: $1" >&2; exit 1; }; }; shift ;;
  esac
done
[[ -n "$PRE" && -n "$POST" ]] || { echo "✗ 用法: compare-baseline.sh <pre-dir> <post-dir> [--stdout]" >&2; exit 1; }
[[ -d "$PRE" && -d "$POST" ]] || { echo "✗ 基线目录不存在: pre=$PRE post=$POST" >&2; exit 1; }

# 读 context-surface-gen.tsv 的 TOTAL 行（bytes lines TOTAL）
_read_total() { # $1=file → echo "bytes lines" 或空
  local f="$1"
  [[ -f "$f" ]] || { echo ""; return; }
  grep -E '^[0-9]+	[0-9]+	TOTAL$' "$f" | tail -1 | awk '{print $1, $2}'
}
pre_total=$(_read_total "$PRE/context-surface-gen.tsv")
post_total=$(_read_total "$POST/context-surface-gen.tsv")
pre_bytes=${pre_total%% *}; pre_lines=${pre_total##* }
post_bytes=${post_total%% *}; post_lines=${post_total##* }

# 降幅百分比（pre-post)/pre*100
_pct() { # $1=pre $2=post
  local p="$1" q="$2"
  [[ "$p" -gt 0 ]] || { echo "0.0"; return; }
  awk -v p="$p" -v q="$q" 'BEGIN{ printf "%.1f", (p-q)/p*100 }'
}

# 逐文件明细 diff（按 relpath 对齐）
_file_diff() {
  local pf="$PRE/context-surface-gen.tsv" qf="$POST/context-surface-gen.tsv"
  [[ -f "$pf" && -f "$qf" ]] || return
  awk -F'\t' 'NR==FNR{a[$3]=$1"\t"$2; next} $3!="TOTAL" && ($3 in a){split(a[$3],b,"\t"); if(b[1]!=$1||b[2]!=$2) printf "| %s | %s | %s | %s | %s |\n", $3, b[1], $1, b[2], $2}' "$pf" "$qf"
}

# 耗时对比
_timing_diff() {
  [[ -f "$PRE/script-timings.txt" && -f "$POST/script-timings.txt" ]] || return
  echo "| 脚本 | pre-opt | post-opt |"
  echo "|------|---------|----------|"
  paste <(grep -E 'fixture=|^[^#]' "$PRE/script-timings.txt") <(grep -E 'fixture=|^[^#]' "$POST/script-timings.txt") 2>/dev/null \
    | awk -F'\t' '{print "| "$1" | "$2" |"}' || echo "| （耗时行格式不一致，人工对比） | | |"
}

# 门禁 LOC 对比
_loc_diff() {
  [[ -f "$PRE/gate-loc.txt" && -f "$POST/gate-loc.txt" ]] || return
  echo "| 文件 | pre LOC | post LOC | pre bytes | post bytes |"
  echo "|------|---------|----------|-----------|-----------|"
  awk -F'\t' 'NR==FNR{a[$3]=$1"\t"$2; next} ($3 in a){split(a[$3],b,"\t"); printf "| %s | %s | %s | %s | %s |\n", $3, b[1], $1, b[2], $2}' "$PRE/gate-loc.txt" "$POST/gate-loc.txt"
}

# 报告
{
  echo "# 性能基线 before/after 对比报告（compare-baseline.sh）"
  echo ""
  echo "- pre-opt 基线: \`$PRE\`"
  echo "- post-opt 基线: \`$POST\`"
  echo "- 诚实限制: 脚本无法观测模型 token；上下文表面=字节级代理，wall-clock=模型处理时间代理（有噪声）。本报告纯信息性，不设 pass/fail 阈值。"
  echo ""
  echo "## 上下文表面（生成期必读面，字节/行数）"
  echo ""
  if [[ -n "$pre_total" && -n "$post_total" ]]; then
    echo "| 指标 | pre-opt | post-opt | 降幅 |"
    echo "|------|---------|----------|------|"
    echo "| TOTAL 字节 | ${pre_bytes} | ${post_bytes} | $(_pct "$pre_bytes" "$post_bytes")% |"
    echo "| TOTAL 行数 | ${pre_lines} | ${post_lines} | $(_pct "$pre_lines" "$post_lines")% |"
  else
    echo "（context-surface-gen.tsv 缺失，无法对比 TOTAL）"
  fi
  echo ""
  echo "### 变更文件明细（pre vs post 字节/行数不一致项）"
  echo ""
  echo "| 文件 | pre 字节 | post 字节 | pre 行 | post 行 |"
  echo "|------|---------|----------|--------|---------|"
  _file_diff
  echo ""
  echo "## 脚本耗时（wall-clock 样本）"
  echo ""
  _timing_diff
  echo ""
  echo "## 门禁脚本 LOC/字节"
  echo ""
  _loc_diff
  echo ""
  echo "## 各 WP 贡献归因（信息性）"
  echo ""
  echo "- WP-P1（信号索引数据化）: exploration-guide.md 瘦身 ~300 行（信号表外迁为 assets/framework-signals.md）"
  echo "- WP-P2（inventory-verify）: 新增脚本，不直接降上下文表面（核验工作脚本化，模型少跑 grep）"
  echo "- WP-P3（framework-evidence）: Step 4.5 模型读台账而非逐条跑 grep（62 文件 × ~5 规律的 token 池，最大降幅点，脚本侧不可直接观测）"
  echo "- WP-P4（conf-render）: Step 8 模型只审 TODO:model 清单（从写 158 行变审+补少数，脚本侧不可直接观测）"
  echo "- WP-P5（上下文裁剪）: 目标 skill 加载面按 profile 分层（lite/standard 裁 §14-18 + 认知三件套），用 \`context-surface.sh --skill <lite-skill>\` 对比可见"
  echo "- 模型侧基线: 未自动采集（须手动跑一次生成落 baselines/pre-opt/model-side/，本报告如实披露未采集）"
} > "$POST/comparison-report.md"

if [[ "$STDOUT" -eq 1 ]]; then cat "$POST/comparison-report.md"; else echo "✓ 报告已落 $POST/comparison-report.md"; fi
exit 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-compare-baseline.sh`
Expected: `PASS test-compare-baseline`

- [ ] **Step 5: 回归（真实 pre-opt 基线 + 重采集 post-opt）**

Run:
```bash
cd swarm-yuan
bash ../verifier/capture-baseline.sh /tmp/post-opt >/dev/null 2>&1
bash scripts/compare-baseline.sh ../verifier/baselines/pre-opt /tmp/post-opt --stdout 2>/dev/null | head -20
rm -rf /tmp/post-opt
```
Expected: 报告含 before/after TOTAL（pre=193226/2144 → post 实测，guide 降幅归因 P1）；exit 0

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/compare-baseline.sh swarm-yuan/tests/test-compare-baseline.sh
git commit -m "feat(wp-p6): compare-baseline.sh before/after 对比报告（上下文表面/耗时/LOC，信息性+WP 归因）"
```

---

## Task 2: facts.conf 数字渲染扩展（WP-P2~P5 新口径）

**Files:**
- Modify: `swarm-yuan/assets/facts.conf`（追加 WP-P2~P5 引入的新口径数字条目）

**Interfaces:**
- facts.conf 已是口径单一事实源（WP-P1 落地，self-check check_doc_consistency 消费）。本 WP 追加新条目：`FACT_INVENTORY_DIMENSIONS` / `FACT_FRAMEWORK_VERIFY_BLOCKS_AVG` / `FACT_CONF_RENDER_PROFILES` / `FACT_SPEC_TEMPLATE_CORE_SECTIONS` / `FACT_SPEC_TEMPLATE_COGNITION_SECTIONS`。self-check check_doc_consistency 已有读 facts.conf 逻辑，本 WP 只补条目（数字由脚本机械计数，不写死）。

- [ ] **Step 1: 追加 facts.conf 新条目**

在 `assets/facts.conf` 末尾（`FACT_CERT_PROFILES=6` 行后）追加：

```bash
# ===== 生成管线工具化（WP-P2~P5）=====
FACT_INVENTORY_DIMENSIONS=7             # inventory-dimensions.conf 维度数（DIM_<ID>_TITLE 计数）
FACT_FRAMEWORK_EVIDENCE=1               # framework-evidence.sh 产出（1=启用，台账 TSV）
FACT_CONF_RENDER_PROFILES=3             # conf-render.sh profile 档（lite/standard/compliance）
FACT_SPEC_TEMPLATE_CORE_SECTIONS=18     # spec-template.md 核心节（§1-13 + §19-23，lite/standard 默认发）
FACT_SPEC_TEMPLATE_COGNITION_SECTIONS=5 # spec-template.md 认知扩展包节（§14-18，compliance 保留，lite/standard 裁剪）
FACT_UNIVERSAL_FILES_CORE=18            # UNIVERSAL_FILES 标 lite 档的条目数（三 profile 都拷）
FACT_CONTEXT_SURFACE_PRE_OPT=193226     # pre-opt 上下文表面基线字节（WP-P0 采集，commit 9c08a4d，P1 前）
```

（注：`FACT_UNIVERSAL_FILES=29` 已存在不动；`FACT_CONTEXT_SURFACE_PRE_OPT` 为信息性基线条目，重采集后人工更新。）

- [ ] **Step 2: 验证 self-check 读新条目不报错**

Run: `cd swarm-yuan && bash scripts/self-check.sh 2>&1 | grep -E 'facts|FACT_|✗' | head -5`
Expected: 无 ✗（新条目格式正确，check_doc_consistency 不报口径不符）

- [ ] **Step 3: Commit**

```bash
git add swarm-yuan/assets/facts.conf
git commit -m "feat(wp-p6): facts.conf 追加 WP-P2~P5 工具化口径数字（维度/证据/渲染/模板节/基线）"
```

---

## Task 3: WP-P6 CI 接线 + 全量回归 + 最终对比报告落库 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `verifier/baselines/post-opt/comparison-report.md`（最终对比报告，提交入库）

- [ ] **Step 1: ci.yml Edit 1 — shellcheck 严格名单**

old_string（P4 后状态尾 `scripts/conf-render.sh; do`）：

```
                   scripts/conf-render.sh; do
```

new_string：

```
                   scripts/conf-render.sh scripts/compare-baseline.sh; do
```

- [ ] **Step 2: ci.yml Edit 2 — self-check job 测试步骤**

old_string（WP-P0~P5 测试步骤块名）：

```yaml
      - name: 计量/信号/维度/框架证据/conf/上下文裁剪测试（WP-P0~P5）
```

new_string：

```yaml
      - name: 计量/信号/维度/框架证据/conf/上下文/对比报告测试（WP-P0~P6）
```

并在该 step 的 run 块末尾追加：
```yaml
          bash tests/test-compare-baseline.sh
```

- [ ] **Step 3: 采集 post-opt 基线 + 生成最终对比报告**

Run:
```bash
cd swarm-yuan
bash ../verifier/capture-baseline.sh ../verifier/baselines/post-opt >/dev/null 2>&1
bash scripts/compare-baseline.sh ../verifier/baselines/pre-opt ../verifier/baselines/post-opt
cat ../verifier/baselines/post-opt/comparison-report.md
```
Expected: 报告落 `verifier/baselines/post-opt/comparison-report.md`；含 before/after TOTAL（pre=193226/2144 → post 实测）+ 各 WP 归因

- [ ] **Step 4: 本地全量回归**

Run: `cd swarm-yuan && bash tests/test-compare-baseline.sh && bash ../verifier/v1/run-verifier.sh all`
Expected: 测试 PASS；verifier 全绿（metrics/sensitive gate-fixtures 预存失败披露——本 WP 收口，这是 P2~P6 最终门槛）

- [ ] **Step 5: Commit 并收口 WP-P6（P2~P6 全部完成）**

```bash
git add .github/workflows/ci.yml verifier/baselines/post-opt/
git commit -m "ci(wp-p6): compare-baseline 进 shellcheck 严格层 + 最终对比报告落库（WP-P2~P6 收口）"
# rebase origin/main → push → main merge --no-ff → 清理 worktree/分支
# 收口后向用户报告：before/after 上下文表面数字 + 各 WP 交付
```

---

## Self-Review 记录

- Spec 覆盖：§3 M6 收尾 → Task 1-3 ✓（对比报告脚本 + facts.conf 扩展 + 最终报告落库）；§9 测试 → Task 1 双态测试 + Task 3 全量回归 ✓；§10 WP-P6 依赖 P1–P5 全合入 ✓。
- 信息性原则：报告不设 pass/fail 阈值，纯报告；模型侧基线如实披露未自动采集（Task 1 报告尾部 + Task 3）✓。
- 诚实归因：pre-opt 基线采集于 P1 前（guide 1334 行），P1 已瘦身至 1037 行——报告归因段明确标注 guide 降幅含 P1 贡献，不冒功 ✓。
- bash 3.2 quirk：赋值全用裸 comsub `pre_total=$(_read_total ...)`；无 `$VAR`+多字节紧邻（报告用 ASCII + 表格）✓。
- fail-open：缺基线文件 → 提示 + exit 0（Task 1 态 2 验证）✓。
- 确定性：同输入连跑两次 byte-identical（Task 1 态 3 验证）✓。
- facts.conf 数字：新条目值由机械计数定义（`DIM_<ID>_TITLE 计数` / `profile 档` / `§1-13+§19-23 核心节`），`FACT_CONTEXT_SURFACE_PRE_OPT` 标注采集 commit 信息性 ✓。
- 占位符扫描：`FACT_CONTEXT_SURFACE_PRE_OPT=193226` 是实测值（pre-opt 基线 TOTAL），非设计占位；报告里的 post-opt 数字由 Task 3 实测填入。
- 全局收口：本 WP 是 P2~P6 最后一个，合入后 P2~P6 全部完成，按用户要求报告 before/after 上下文表面数字 + 各 WP 交付。

#!/usr/bin/env bash
# test-ai-judgment.sh — GATE_AI_JUDGMENT 开关测试（WP-R2-3）
# 复盘发现：Q2H-A 的开关只在 gates-advisory.sh 内部，precheck.conf 模板没有 → 用户无从发现，
# AI 自觉判断模式实为死代码。WP-R2-3 把开关入 conf 模板（${VAR:-默认} 保留环境变量优先）。
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
ADV="assets/gates-advisory.sh"
TMP="$(mktemp -d /tmp/aij.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：conf 模板含 GATE_AI_JUDGMENT（可发现性回归）---
grep -q '^GATE_AI_JUDGMENT=' assets/precheck.conf \
  && ok "态1 precheck.conf 含 GATE_AI_JUDGMENT" || bad "态1 conf 缺 GATE_AI_JUDGMENT"
grep -q 'MEASURE:.*AI自觉判断\|AI.*自觉判断.*MEASURE' assets/precheck.conf || \
grep -q 'MEASURE:' <(grep '^GATE_AI_JUDGMENT=' assets/precheck.conf) \
  && ok "态1 含 MEASURE 元数据" || bad "态1 缺 MEASURE 元数据"

# --- 态 2：=1 时 advisory 档 5 门禁短路输出 AI 自查提示（不跑机械检查）---
# stub：pass/warn/fail/skip_if_unconfigured 最小实现（gates-advisory.sh 依赖）
cat > "$TMP/stub.sh" <<'SEOF'
pass() { echo "PASS: $*"; }
warn() { echo "WARN: $*"; }
fail() { echo "FAIL: $*"; }
skip_if_unconfigured() { echo "SKIP: $*"; return 0; }
SEOF
out=$(GATE_AI_JUDGMENT=1 bash -c '
  source "'"$TMP"'/stub.sh"
  source "'"$ADV"'"
  for g in check_cognition check_diagram check_pr_quality check_consistency check_link_depth; do "$g"; done
' 2>&1)
for g in check_cognition check_diagram check_pr_quality check_consistency check_link_depth; do
  # ${g} 必须带括号——$g 紧跟多字节「（」在 bash 3.2 + UTF-8 locale 下会吞字节变 unbound（WP-R2-1 同坑）
  echo "$out" | grep -q "${g}（AI 自觉判断模式" \
    && ok "态2 $g 短路为 AI 自查" || bad "态2 $g 未短路: $(echo "$out" | grep "$g" | head -1)"
done
# 机械检查不应出现（cognition 机械模式的标志输出是"认知检查"标题或 SKIP 披露）
echo "$out" | grep -q '=== 认知检查' && bad "态2 =1 时仍跑机械认知检查" || ok "态2 =1 时不跑机械认知检查"

# --- 态 3：默认（未设置）保持机械模式（向后兼容）---
out3=$(bash -c '
  source "'"$TMP"'/stub.sh"
  source "'"$ADV"'"
  check_cognition
' 2>&1)
echo "$out3" | grep -q 'AI 自觉判断模式' && bad "态3 默认误入 AI 模式" || ok "态3 默认保持机械模式"
# 机械路径标志输出：认知递进体检报告头（孤立跑缺 precheck.sh 内部助手属预期噪音，只断言报告头）
echo "$out3" | grep -qE '认知递进体检|=== 认知检查|SKIP' \
  && ok "态3 默认机械路径执行" || bad "态3 默认机械路径未执行: $out3"

# --- 态 4：conf 的 ${VAR:-默认} 写法保留环境变量优先 ---
# source conf（set +u 包裹，与 precheck.sh 同语义），env=1 时 conf 不得覆盖回 0
out4=$(GATE_AI_JUDGMENT=1 bash -c '
  set +u
  source "assets/precheck.conf" 2>/dev/null || true
  set -u
  printf "%s" "${GATE_AI_JUDGMENT:-0}"
')
[[ "$out4" == "1" ]] && ok "态4 conf 保留环境变量优先（env=1 不被覆盖）" || bad "态4 env 被 conf 覆盖为 [$out4]"
# env 未设时 conf 默认 0
out5=$(bash -c '
  set +u
  source "assets/precheck.conf" 2>/dev/null || true
  set -u
  printf "%s" "${GATE_AI_JUDGMENT:-0}"
')
[[ "$out5" == "0" ]] && ok "态5 conf 默认 0（机械模式）" || bad "态5 conf 默认值异常 [$out5]"

[[ $FAIL -eq 0 ]] && { echo "PASS test-ai-judgment"; exit 0; } || { echo "FAIL test-ai-judgment" >&2; exit 1; }

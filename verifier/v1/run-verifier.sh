#!/usr/bin/env bash
# run-verifier.sh — Swarm-yuan 重构验收器 v1
# 用法: bash verifier/v1/run-verifier.sh <mode> [repo_root]
#   mode = fixtures | gate-fixtures | e2e | shellcheck | metrics | cli-ab | all
#   metrics = 既有测量行 + C6 阈值断言（v1/metrics-assert.sh）；cli-ab = C5 A/B 逐字节等价断言（v1/cli-ab-test.sh）
# 输出: 机器可读结果到 stdout，供 verifier/runs/ 记录
set -u
MODE="${1:-all}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -ge 2 ] && ROOT="$(cd "$2" && pwd)"
SY="$ROOT/swarm-yuan"
# shellcheck 解析顺序：$SHELLCHECK 环境变量 → PATH 中的 shellcheck → /tmp/shellcheck（历史 /mnt/agents/tools 拷贝）。
# 失败关闭（fail-closed）：若以上均无，shellcheck_scan 报告 SHELLCHECK_UNAVAILABLE 并返回非零，
# 而不是在每台缺 shellcheck 的机器上谎报 SHELLCHECK_ERRORS 0（历史缺陷：cp /mnt/agents/tools 失败被静默吞掉）。
SC=""
if [ -n "${SHELLCHECK:-}" ] && [ -x "${SHELLCHECK:-}" ]; then
  SC="$SHELLCHECK"
elif command -v shellcheck >/dev/null 2>&1; then
  SC="$(command -v shellcheck)"
elif [ -x /tmp/shellcheck ]; then
  SC="/tmp/shellcheck"
elif [ -f /mnt/agents/tools/shellcheck ]; then
  cp /mnt/agents/tools/shellcheck /tmp/shellcheck 2>/dev/null && chmod +x /tmp/shellcheck 2>/dev/null && SC="/tmp/shellcheck"
fi

fixtures() {
  local ids id rc_v rc_c outcome fails=0 total=0
  ids=$(ls "$SY/tests/fixtures" 2>/dev/null)
  for id in $ids; do
    [ -d "$SY/tests/fixtures/$id/violating" ] || continue
    [ -f "$SY/assets/framework-gates/$id.sh" ] || continue
    total=$((total+1))
    outcome=$(bash "$(dirname "$0")/run-one-fixture.sh" "$SY" "$id")
    rc_v="${outcome% *}"; rc_c="${outcome#* }"
    # violating 期望非 0，compliant 期望 0
    if [ "$rc_v" != "0" ] && [ "$rc_c" = "0" ]; then
      echo "FIXTURE $id OK (v=$rc_v c=$rc_c)"
    else
      echo "FIXTURE $id BAD (v=$rc_v c=$rc_c)"; fails=$((fails+1))
    fi
  done
  echo "FIXTURES_TOTAL $total FAILS $fails"
}

e2e() {
  bash "$SY/tests/e2e/run-e2e.sh" >/tmp/verifier-e2e.log 2>&1
  echo "E2E_RC $?"
}

# 合规门禁 fixture（C8）：遍历 6 组 gate fixture，双态 + id 级断言
gate_fixtures() {
  local g fails=0 total=0
  for g in compliance docs-pack sbom privacy sensitive summary; do
    total=$((total+1))
    if bash "$SY/tests/run-gate-fixture.sh" "$g" >/tmp/verifier-gatefx-$g.log 2>&1; then
      echo "GATE_FIXTURE $g OK"
    else
      echo "GATE_FIXTURE $g BAD（日志 /tmp/verifier-gatefx-$g.log）"; fails=$((fails+1))
    fi
  done
  echo "GATE_FIXTURES_TOTAL $total FAILS $fails"
  echo "GATE_FIXTURES_FAILS $fails"
  [ "$fails" -eq 0 ]
}

shellcheck_scan() {
  if [ -z "$SC" ]; then
    echo "SHELLCHECK_UNAVAILABLE (无 shellcheck：设 \$SHELLCHECK、装入 PATH，或提供 /tmp/shellcheck)"
    return 1
  fi
  local f total_e=0 total_w=0 c
  for f in "$SY/assets/precheck.sh" "$SY/scripts/generate-skill.sh" "$SY/scripts/self-check.sh" "$SY/assets/state-machine.sh" "$SY"/assets/framework-gates/*.sh "$ROOT/Swarm-studio/scripts/precheck.sh"; do
    [ -f "$f" ] || continue
    c=$("$SC" -s bash -S error -f gcc "$f" 2>/dev/null | wc -l)
    total_e=$((total_e+c))
  done
  echo "SHELLCHECK_ERRORS $total_e"
  for f in "$SY/assets/precheck.sh" "$SY/scripts/generate-skill.sh" "$SY/scripts/self-check.sh" "$SY"/assets/framework-gates/*.sh; do
    c=$("$SC" -s bash -S warning -f gcc "$f" 2>/dev/null | wc -l)
    total_w=$((total_w+c))
  done
  echo "SHELLCHECK_WARNINGS_CORE $total_w"
}

metrics() {
  echo "LOC_PRECHECK $(wc -l < "$SY/assets/precheck.sh")"
  echo "LOC_PRECHECK_STUDIO $(wc -l < "$ROOT/Swarm-studio/scripts/precheck.sh")"
  echo "DUP_DIFF_LINES $(diff "$SY/assets/precheck.sh" "$ROOT/Swarm-studio/scripts/precheck.sh" | grep -c '^[<>]')"
  echo "GATES_COUNT $(ls "$SY"/assets/framework-gates/*.sh | wc -l)"
  echo "GATES_TOTAL_LOC $(cat "$SY"/assets/framework-gates/*.sh | wc -l)"
  echo "DS_STORE $(find "$ROOT" -name .DS_Store -not -path "*/.git/*" | wc -l)"
}

# C5 CLI 兼容断言（v1/cli-ab-test.sh：A=HEAD vs B=工作区，GATE_FLAGS 全 flag × 双语料
# stdout+退出码逐字节等价 + --all 核心 10 序列基线断言；环境未配置时静默跳过）
cli_ab() {
  bash "$(dirname "$0")/cli-ab-test.sh" "$ROOT"
}

# C6 可维护性阈值断言（v1/metrics-assert.sh：LOC 增长/注入双副本 diff/文档一致性段；
# 阈值真值 v1/metrics-baseline.txt，缺失即未配置静默跳过，启用后 fail-closed）
metrics_assert() {
  bash "$(dirname "$0")/metrics-assert.sh" "$ROOT"
}

case "$MODE" in
  fixtures) fixtures ;;
  gate-fixtures) gate_fixtures ;;
  e2e) e2e ;;
  shellcheck) shellcheck_scan ;;
  metrics) metrics; metrics_assert ;;
  cli-ab) cli_ab ;;
  # all：既有各模式输出与投票语义不变（shellcheck 不投票、gate_fixtures 投票），
  # 新增 metrics_assert 与 cli_ab 两票（fail-closed），任一票失败则 all 非零。
  all)
    all_fail=0
    metrics; metrics_assert || all_fail=1
    shellcheck_scan
    e2e
    fixtures
    gate_fixtures || all_fail=1
    cli_ab || all_fail=1
    [ "$all_fail" -eq 0 ]
    ;;
esac

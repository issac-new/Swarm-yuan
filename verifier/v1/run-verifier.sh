#!/usr/bin/env bash
# run-verifier.sh — Swarm-yuan 重构验收器 v1
# 用法: bash verifier/v1/run-verifier.sh <mode> [repo_root]
#   mode = fixtures | e2e | shellcheck | metrics | all
# 输出: 机器可读结果到 stdout，供 verifier/runs/ 记录
set -u
MODE="${1:-all}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -ge 2 ] && ROOT="$(cd "$2" && pwd)"
SY="$ROOT/swarm-yuan"
# shellcheck 静态二进制存于 /mnt/agents/tools（noexec），每次复制到 /tmp 执行
if [ ! -x /tmp/shellcheck ]; then cp /mnt/agents/tools/shellcheck /tmp/shellcheck && chmod +x /tmp/shellcheck; fi
SC="${SHELLCHECK:-/tmp/shellcheck}"

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

shellcheck_scan() {
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

case "$MODE" in
  fixtures) fixtures ;;
  e2e) e2e ;;
  shellcheck) shellcheck_scan ;;
  metrics) metrics ;;
  all) metrics; shellcheck_scan; e2e; fixtures ;;
esac

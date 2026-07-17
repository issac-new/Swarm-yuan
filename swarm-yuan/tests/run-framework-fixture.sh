#!/usr/bin/env bash
# 用法: run-framework-fixture.sh <ruleset_id> —— violating 期望 FAIL / compliant 期望 PASS
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ID="$1"
FX="$BASE/tests/fixtures/$ID"
run_one() {  # $1=violating|compliant  $2=expect fail|pass
  local mode="$1" expect="$2" tmp
  tmp="$(mktemp -d /tmp/fwfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  cp "$FX/$mode/precheck.conf" "$tmp/scripts/precheck.conf"
  # 注入片段（直接用范式片段拼入标记区块，模拟 --inject-frameworks 结果）
  awk -v frag="$BASE/assets/framework-gates/$ID.sh" '
    /^# >>> swarm-yuan:framework-gates >>>/ { print; while ((getline l < frag) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0 }
    !skip { print }
  ' "$tmp/scripts/precheck.sh" > "$tmp/scripts/p2.sh" && mv "$tmp/scripts/p2.sh" "$tmp/scripts/precheck.sh"
  ( cd "$FX/$mode" && bash "$tmp/scripts/precheck.sh" --framework ) >/dev/null 2>&1
  local rc=$?
  rm -rf "$tmp"
  if [[ "$expect" == "fail" ]]; then [[ $rc -ne 0 ]]; else [[ $rc -eq 0 ]]; fi
}
run_one violating fail && echo "✓ violating → FAIL（符合预期）" || { echo "✗ violating 未 FAIL"; exit 1; }
run_one compliant pass && echo "✓ compliant → PASS（符合预期）" || { echo "✗ compliant 未 PASS"; exit 1; }

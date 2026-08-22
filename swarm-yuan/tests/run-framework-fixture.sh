#!/usr/bin/env bash
# 用法: run-framework-fixture.sh <ruleset_id> —— violating 期望检出（advisory 发现行 + expected-fail-ids 全命中）/ compliant 期望 PASS
# 可选断言：<fixture>/<mode>/expected-fail-ids 存在时，逐行字面串断言 precheck 输出命中。
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ID="$1"
FX="$BASE/tests/fixtures/$ID"
run_one() {  # $1=violating|compliant  $2=expect fail|pass
  local mode="$1" expect="$2" tmp out rc
  tmp="$(mktemp -d /tmp/fwfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  # WP-Q1.3：拆分后 precheck.sh 依赖 gates-strict/warn/advisory.sh 三文件（source 守卫）
  for _gf in gates-strict.sh gates-warn.sh gates-advisory.sh; do
    [[ -f "$BASE/assets/$_gf" ]] && cp "$BASE/assets/$_gf" "$tmp/scripts/$_gf"
  done
  # conf 中的 __REPO_ROOT__ 占位符替换为实际仓库根（fixture 机器无关化）
  REPO_ROOT="$(cd "$BASE/.." && pwd)"
  sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$FX/$mode/precheck.conf" > "$tmp/scripts/precheck.conf"
  # 注入片段（直接用范式片段拼入标记区块，模拟 --inject-frameworks 结果）
  awk -v frag="$BASE/assets/framework-gates/$ID.sh" '
    /^# >>> swarm-yuan:framework-gates >>>/ { print; while ((getline l < frag) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0 }
    !skip { print }
  ' "$tmp/scripts/precheck.sh" > "$tmp/scripts/p2.sh" && mv "$tmp/scripts/p2.sh" "$tmp/scripts/precheck.sh"
  out="$( cd "$FX/$mode" && bash "$tmp/scripts/precheck.sh" --framework 2>&1 )"
  rc=$?
  rm -rf "$tmp"
  # 双态断言（impl-conformance 语义修正：check_framework 自 WP-Q2H-B 降 advisory——
  # 违规不阻断退出码是设计语义；violating 的断言 = 检测命中（下方案 id 断言）+ 至少一条发现行）
  if [[ "$expect" == "fail" ]]; then
    printf '%s\n' "$out" | grep -qE '⚠ advisory: fw_|✗ fw_|✗ fail' || return 1
  else
    [[ $rc -eq 0 ]] || return 1
  fi
  # expected-fail-ids 可选断言：逐行字面串（空行与 # 注释行跳过）须在输出中命中
  if [[ -f "$FX/$mode/expected-fail-ids" ]]; then
    local fid
    while IFS= read -r fid || [[ -n "$fid" ]]; do
      [[ -z "$fid" ]] && continue
      case "$fid" in \#*) continue;; esac
      if ! printf '%s\n' "$out" | grep -qF "$fid"; then
        echo "  ✗ expected-fail-ids 未命中：$fid"
        return 1
      fi
    done < "$FX/$mode/expected-fail-ids"
  fi
  return 0
}
run_one violating fail && echo "✓ violating → 检出（符合预期）" || { echo "✗ violating 未检出（无 advisory/fail 发现行）"; exit 1; }
run_one compliant pass && echo "✓ compliant → PASS（符合预期）" || { echo "✗ compliant 未 PASS"; exit 1; }

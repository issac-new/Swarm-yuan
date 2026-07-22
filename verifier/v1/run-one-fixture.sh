#!/usr/bin/env bash
# run-one-fixture.sh <swarm-yuan_dir> <fixture_id>
# 输出: "<rc_violating> <rc_compliant> <id_failures>"
#   rc_violating  = violating 侧退出码（期望非 0）
#   rc_compliant  = compliant 侧退出码（期望 0）
#   id_failures   = violating 侧 expected-fail-ids 未命中数（期望 0；无 expected-fail-ids 时为 0）
#
# id 级双态断言（P2 #5，2026-07-21）：原仅返回退出码向量，退出码 v≠0 只代表"有 fail"，
# 不验证 fail 的具体 id 是否就是 fixture 故意植入的违规——若门禁逻辑崩成全量误报，
# v 仍非 0、golden-vector 仍全绿，但门禁已失效。升级为读 violating/expected-fail-ids，
# 逐行字面串断言 precheck 输出命中，未命中计入 id_failures。
set -u
BASE="$1"; ID="$2"; FX="$BASE/tests/fixtures/$ID"

# 捕获输出（供 id 断言）；退出码通过 PIPESTATUS 取。
run_one_capture() {  # $1=violating|compliant ；stdout=precheck 输出，$rc=退出码
  local mode="$1" tmp rc
  tmp="$(mktemp -d /tmp/vfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  # WP-Q1.3 同步：precheck.sh 依赖 gates-strict/warn/advisory.sh 三文件（source 守卫），
  # 缺失时 framework 片段调用的辅助函数（_fw_grep_count 等）127 command not found。
  local _gf
  for _gf in gates-strict.sh gates-warn.sh gates-advisory.sh; do
    cp "$BASE/assets/$_gf" "$tmp/scripts/$_gf" 2>/dev/null || true
  done
  REPO_ROOT="$(cd "$BASE/.." && pwd)"
  sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$FX/$mode/precheck.conf" > "$tmp/scripts/precheck.conf"
  awk -v frag="$BASE/assets/framework-gates/$ID.sh" '
    /^# >>> swarm-yuan:framework-gates >>>/ { print; while ((getline l < frag) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0 }
    !skip { print }
  ' "$tmp/scripts/precheck.sh" > "$tmp/scripts/p2.sh" && mv "$tmp/scripts/p2.sh" "$tmp/scripts/precheck.sh"
  ( cd "$FX/$mode" && bash "$tmp/scripts/precheck.sh" --framework ) 2>&1
  rc=$?
  rm -rf "$tmp"
  return $rc
}

# violating 侧：退出码 + id 断言
v_out=$(run_one_capture violating); v_rc=$?
id_failures=0
if [[ -f "$FX/violating/expected-fail-ids" ]]; then
  while IFS= read -r fid || [[ -n "$fid" ]]; do
    [[ -z "$fid" ]] && continue
    case "$fid" in \#*) continue;; esac
    if ! printf '%s\n' "$v_out" | grep -qF "$fid"; then
      id_failures=$((id_failures+1))
    fi
  done < "$FX/violating/expected-fail-ids"
fi

# compliant 侧：仅退出码（compliant 不应 fail，无需 id 断言）
c_out=$(run_one_capture compliant); c_rc=$?

echo "$v_rc $c_rc $id_failures"

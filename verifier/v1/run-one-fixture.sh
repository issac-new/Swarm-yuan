#!/usr/bin/env bash
# run-one-fixture.sh <swarm-yuan_dir> <fixture_id>
# 输出: "<rc_violating> <rc_compliant>"
set -u
BASE="$1"; ID="$2"; FX="$BASE/tests/fixtures/$ID"
run_one() {
  local mode="$1" tmp rc
  tmp="$(mktemp -d /tmp/vfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  REPO_ROOT="$(cd "$BASE/.." && pwd)"
  sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$FX/$mode/precheck.conf" > "$tmp/scripts/precheck.conf"
  awk -v frag="$BASE/assets/framework-gates/$ID.sh" '
    /^# >>> swarm-yuan:framework-gates >>>/ { print; while ((getline l < frag) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0 }
    !skip { print }
  ' "$tmp/scripts/precheck.sh" > "$tmp/scripts/p2.sh" && mv "$tmp/scripts/p2.sh" "$tmp/scripts/precheck.sh"
  ( cd "$FX/$mode" && bash "$tmp/scripts/precheck.sh" --framework ) >/dev/null 2>&1
  rc=$?
  rm -rf "$tmp"
  echo "$rc"
}
echo "$(run_one violating) $(run_one compliant)"

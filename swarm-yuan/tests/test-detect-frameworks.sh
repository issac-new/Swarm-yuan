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
out=$(bash "$SH" "$TMP/p1" --verbose 2>"$TMP/err")
echo "$out" | grep -qF '"react"' && echo "$out" | grep -qF '"express"' \
  && ok "ACTIVE_FRAMEWORKS 命中" || bad "命中异常: $out"
grep -qF 'react|react|pkgjson' "$TMP/err" && ok "verbose 明细 react" || bad "明细缺失"
grep -qF 'express|express|pkgjson' "$TMP/err" && ok "verbose 明细 express" || bad "明细缺失"
echo "$out" | grep -qF 'framework|pattern' && bad "stdout 被明细污染" || ok "stdout 未污染"

# 态 2：空目录 → ACTIVE_FRAMEWORKS=() exit 0
mkdir -p "$TMP/p2"
out=$(bash "$SH" "$TMP/p2" 2>/dev/null); rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF 'ACTIVE_FRAMEWORKS=()' \
  && ok "空项目双态" || bad "空项目异常: rc=$rc out=$out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-detect-frameworks"; exit 0; } || { echo "FAIL test-detect-frameworks" >&2; exit 1; }

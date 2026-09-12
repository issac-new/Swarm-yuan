#!/usr/bin/env bash
# test-detect-frameworks.sh — detect-frameworks.sh --verbose 双态测试（WP-P1）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
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

# 态 3（R25-PR3 回归锚）：.venv 内第三方包自带的 package.json 不得计入项目框架
# 实仓实证（flask 仓库）：.venv/lib/.../pyright/dist/package.json 含 webpack 依赖 →
# 探出 webpack（项目实际是纯 Python 项目）。修复：find 排除 .venv/venv/site-packages。
mkdir -p "$TMP/p3/.venv/lib/python3.13/site-packages/sometool/dist"
cat > "$TMP/p3/.venv/lib/python3.13/site-packages/sometool/dist/package.json" <<'EOF'
{ "name": "@sometool/dist", "dependencies": { "webpack": "^5.0.0" } }
EOF
out=$(bash "$SH" "$TMP/p3" 2>/dev/null)
echo "$out" | grep -qF '"webpack"' && bad "态3 venv 污染：第三方包依赖被探为项目框架" || ok "态3 venv 内 package.json 被排除"
# 同仓项目自身的 package.json 仍正常探测
mkdir -p "$TMP/p3/app"
cat > "$TMP/p3/app/package.json" <<'EOF'
{ "dependencies": { "koa": "^2.15.0" } }
EOF
out=$(bash "$SH" "$TMP/p3" 2>/dev/null)
echo "$out" | grep -qF '"koa"' && ok "态3 项目自身 package.json 仍命中" || bad "态3 自身探测被误伤: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-detect-frameworks"; exit 0; } || { echo "FAIL test-detect-frameworks" >&2; exit 1; }

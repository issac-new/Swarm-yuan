#!/usr/bin/env bash
# test-gate-rules.sh — R13 批次2：rules.d 三值求值器测试
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
SH="scripts/gate-rules.sh"
TMP="$(mktemp -d /tmp/grtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

mkdir -p "$TMP/rules.d"
cat > "$TMP/rules.d/test.rules" <<'REOF'
# test rules
git status        → allow   # 只读
git push *        → prompt  # 推进态
rm -rf *          → forbid  # 不可逆；替代：git clean -n
npm publish *     → forbid  # 发布门；替代：release 流程
REOF

# 态1 allow：只读命令
out=$(bash "$SH" "$TMP/rules.d" "git status" --quiet 2>/dev/null); rc=$?
[[ "$out" == "allow" && $rc -eq 0 ]] && ok "态1 allow 判定+exit 0" || bad "态1: $out rc=$rc"

# 态2 prompt：推进态
out=$(bash "$SH" "$TMP/rules.d" "git push origin main" --quiet 2>/dev/null); rc=$?
[[ "$out" == "prompt" && $rc -eq 3 ]] && ok "态2 prompt 判定+exit 3" || bad "态2: $out rc=$rc"

# 态3 forbid：不可逆
out=$(bash "$SH" "$TMP/rules.d" "rm -rf /tmp/x" --quiet 2>/dev/null); rc=$?
[[ "$out" == "forbid" && $rc -eq 2 ]] && ok "态3 forbid 判定+exit 2" || bad "态3: $out rc=$rc"

# 态4 裸命令命中 " *" 规则（尾参可缺省）
out=$(bash "$SH" "$TMP/rules.d" "npm publish" --quiet 2>/dev/null); rc=$?
[[ "$out" == "forbid" && $rc -eq 2 ]] && ok "态4 尾 * 可缺省命中" || bad "态4: $out rc=$rc"

# 态5 未命中 → prompt 兜底
out=$(bash "$SH" "$TMP/rules.d" "make build" --quiet 2>/dev/null); rc=$?
[[ "$out" == "prompt" && $rc -eq 3 ]] && ok "态5 未命中兜底 prompt" || bad "态5: $out rc=$rc"

# 态6 无规则文件 → prompt（fail-closed 到审批）
out=$(bash "$SH" "$TMP/empty-dir" "any cmd" --quiet 2>/dev/null); rc=$?
mkdir -p "$TMP/empty-dir"
out=$(bash "$SH" "$TMP/empty-dir" "any cmd" --quiet 2>/dev/null); rc=$?
[[ "$out" == "prompt" && $rc -eq 3 ]] && ok "态6 无规则=不静默放行" || bad "态6: $out rc=$rc"

# 态7 FORBID 消息含替代方案（stderr，给模型的 API）
err=$(bash "$SH" "$TMP/rules.d" "rm -rf x" 2>&1 1>/dev/null)
echo "$err" | grep -q 'FORBID' && echo "$err" | grep -q '替代' && ok "态7 FORBID 带替代方案" || bad "态7: $err"

# 态8 取最严：同命令 allow+forbid 双规则 → forbid
cat >> "$TMP/rules.d/test.rules" <<'REOF'
git status *      → forbid  # 冲突测试；替代：无
REOF
out=$(bash "$SH" "$TMP/rules.d" "git status" --quiet 2>/dev/null); rc=$?
[[ "$out" == "forbid" && $rc -eq 2 ]] && ok "态8 多规则取最严" || bad "态8: $out rc=$rc"

# 态9 默认规则集（仓库自带）冒烟
out=$(bash "$SH" assets/rules.d "sudo rm -rf /" --quiet 2>/dev/null); rc=$?
[[ "$out" == "forbid" ]] && ok "态9 默认规则集 forbid 冒烟" || bad "态9: $out rc=$rc"
out=$(bash "$SH" assets/rules.d "git diff --stat" --quiet 2>/dev/null)
[[ "$out" == "allow" ]] && ok "态9 默认规则集 allow 冒烟" || bad "态9b: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-gate-rules"; exit 0; } || { echo "FAIL test-gate-rules" >&2; exit 1; }

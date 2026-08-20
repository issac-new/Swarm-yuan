#!/usr/bin/env bash
# test-fail-gate-hook.sh — fail-gate-hook.sh 双模式测试（WP-Enforce1 + WP-Enforce2）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
HOOK="assets/hooks/fail-gate-hook.sh"
TMP="$(mktemp -d /tmp/fgt.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

setup_proj() {
  mkdir -p "$1/scripts" "$1/.swarm-yuan"
  cat > "$1/SKILL.md" <<EOF
---
status: active
---
EOF
  cat > "$1/scripts/precheck.conf" <<EOF
PROJECT_DIR="$1"
GATE_ENFORCE_DENY="security"
$2
EOF
  echo "security" > "$1/.swarm-yuan/.gate-fail-flag"
}

# --- 态 1：Write 拦截（flag 存在 + 白名单配） ---
setup_proj "$TMP/p1" ""
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'$TMP'/p1/src/foo.py"},"cwd":"'$TMP'/p1"}' | bash "$HOOK" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态1 Write 拦截 deny JSON" || bad "态1 未 deny: $out"

# --- 态 2：Write 落盘审计（gate-deny.jsonl） ---
[[ -f "$TMP/p1/.swarm-yuan/gate-deny.jsonl" ]] && ok "态2 deny 落盘存在" || bad "态2 deny 未落盘"
grep -q '"tool":"Write"' "$TMP/p1/.swarm-yuan/gate-deny.jsonl" && ok "态2 落盘 tool=Write" || bad "态2 落盘缺 Write"

# --- 态 3：Write 目标豁免（.swarm-yuan/conf）---
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'$TMP'/p1/.swarm-yuan/decisions.jsonl"},"cwd":"'$TMP'/p1"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态3 .swarm-yuan 目标豁免" || bad "态3 误拦 conf: $out"

# --- 态 4：Bash 推进态拦截（GATE_ENFORCE_DENY_BASH=push,commit）---
setup_proj "$TMP/p4" 'GATE_ENFORCE_DENY_BASH="push,commit"'
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"'$TMP'/p4"}' | bash "$HOOK" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态4 Bash git push 拦截" || bad "态4 未 deny: $out"
echo "$out" | grep -q 'GATE_ENFORCE_DENY_BASH' && ok "态4 deny 提示含 GATE_ENFORCE_DENY_BASH" || bad "态4 deny 缺开关提示"

# --- 态 5：Bash 只读放行（git status 不在白名单） ---
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"'$TMP'/p4"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态5 Bash git status 放行" || bad "态5 误拦只读: $out"

# --- 态 6：Bash 测试命令放行（npm test 不在白名单） ---
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"'$TMP'/p4"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态6 Bash npm test 放行" || bad "态6 误拦测试: $out"

# --- 态 7：Bash 白名单精确匹配（npm:publish） ---
setup_proj "$TMP/p7" 'GATE_ENFORCE_DENY_BASH="npm:publish"'
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm publish"},"cwd":"'$TMP'/p7"}' | bash "$HOOK" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态7 npm:publish 精确拦截" || bad "态7 未 deny: $out"
# 同 conf 下 npm install 应放行（不在白名单）
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm install"},"cwd":"'$TMP'/p7"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态7 npm install 放行（非白名单）" || bad "态7 误拦 install: $out"

# --- 态 8：draft 期自动关闭（SKILL.md status: draft）---
setup_proj "$TMP/p8" ""
sed -i.bak 's/status: active/status: draft/' "$TMP/p8/SKILL.md"
rm -f "$TMP/p8/SKILL.md.bak"
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'$TMP'/p8/src/foo.py"},"cwd":"'$TMP'/p8"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态8 draft 期放行（不拦骨架期）" || bad "态8 draft 误拦: $out"

# --- 态 9：flag 不存在时放行 ---
mkdir -p "$TMP/p9/scripts"
cat > "$TMP/p9/SKILL.md" <<EOF
---
status: active
---
EOF
cat > "$TMP/p9/scripts/precheck.conf" <<EOF
PROJECT_DIR="$TMP/p9"
GATE_ENFORCE_DENY="security"
EOF
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'$TMP'/p9/src/foo.py"},"cwd":"'$TMP'/p9"}' | bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "态9 flag 不存在放行" || bad "态9 无 flag 误拦: $out"

# --- 态 10：PostToolUse Bash precheck.sh fail 落 flag ---
mkdir -p "$TMP/p10/scripts" "$TMP/p10/.swarm-yuan"
cat > "$TMP/p10/SKILL.md" <<EOF
---
status: active
---
EOF
cat > "$TMP/p10/scripts/precheck.conf" <<EOF
PROJECT_DIR="$TMP/p10"
GATE_ENFORCE_DENY="security"
EOF
# precheck.sh 退出码非 0 → flag 写入
echo '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"bash scripts/precheck.sh --all"},"tool_response":{"exit_code":1},"cwd":"'$TMP'/p10"}' | bash "$HOOK" >/dev/null 2>&1
[[ -f "$TMP/p10/.swarm-yuan/.gate-fail-flag" ]] && ok "态10 precheck fail → flag 落盘" || bad "态10 flag 未落盘"
# precheck.sh 退出码 0 → flag 清除
echo '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"bash scripts/precheck.sh --all"},"tool_response":{"exit_code":0},"cwd":"'$TMP'/p10"}' | bash "$HOOK" >/dev/null 2>&1
[[ ! -f "$TMP/p10/.swarm-yuan/.gate-fail-flag" ]] && ok "态10 precheck pass → flag 清除" || bad "态10 flag 未清除"

[[ $FAIL -eq 0 ]] && { echo "PASS test-fail-gate-hook"; exit 0; } || { echo "FAIL test-fail-gate-hook" >&2; exit 1; }

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

# --- 态 11：WP-Enforce3 --report（向后兼容分支：仅旧 gate-deny.jsonl 无 audit） ---
# 手工造一个纯旧格式项目（p1 现在有 audit 文件会走新分支，见态17）
mkdir -p "$TMP/p11/.swarm-yuan"
printf '{"ts":"2026-08-20T01:00:00Z","tool":"Write","target":"src/a.py","gates":"security"}\n' > "$TMP/p11/.swarm-yuan/gate-deny.jsonl"
out=$(bash "$HOOK" --report --project "$TMP/p11" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态11 --report exit 0" || bad "态11 exit=$rc"
echo "$out" | grep -q '^## fail-gate deny 报告' && ok "态11 旧版报告标题命中" || bad "态11 缺旧标题: $out"
echo "$out" | grep -q '按门禁聚合' && ok "态11 聚合段命中" || bad "态11 缺聚合段: $out"
echo "$out" | grep -q 'security' && ok "态11 security 门禁命中" || bad "态11 缺 security: $out"

# --- 态 12：--report N（限制条数，旧格式项目） ---
printf '{"ts":"2026-08-20T02:00:00Z","tool":"Edit","target":"src/b.py","gates":"security"}\n' >> "$TMP/p11/.swarm-yuan/gate-deny.jsonl"
out=$(bash "$HOOK" --report 1 --project "$TMP/p11" 2>&1)
line_count=$(echo "$out" | grep -cE '^202[0-9]-' || true)
[[ "$line_count" -eq 1 ]] && ok "态12 --report 1 仅 1 条事件" || bad "态12 line_count=$line_count 应=1"

# --- 态 13：--report 无文件（fail-open） ---
out=$(bash "$HOOK" --report --project "$TMP" 2>&1); rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '无 deny 事件' && ok "态13 无文件 fail-open" || bad "态13 exit=$rc 或缺提示: $out"

# ===== WP-R12-A：gate-audit.jsonl 全量决策审计 =====

# --- 态 14：deny 决策点落 audit 行（handler/decision/reason 三字段） ---
[[ -f "$TMP/p1/.swarm-yuan/gate-audit.jsonl" ]] && ok "态14 audit 文件存在" || bad "态14 audit 未落盘"
grep -q '"handler":"fail-gate-hook:edit"' "$TMP/p1/.swarm-yuan/gate-audit.jsonl" && ok "态14 handler=edit 命中" || bad "态14 缺 handler"
grep -q '"decision":"deny"' "$TMP/p1/.swarm-yuan/gate-audit.jsonl" && grep -q '"reason":"gates-unresolved"' "$TMP/p1/.swarm-yuan/gate-audit.jsonl" \
  && ok "态14 deny/gates-unresolved 命中" || bad "态14 缺 deny 行"

# --- 态 15：豁免路径落 pass 行（态3 的 .swarm-yuan 目标） ---
grep -q '"decision":"pass"' "$TMP/p1/.swarm-yuan/gate-audit.jsonl" && grep -q '"reason":"exempt-path"' "$TMP/p1/.swarm-yuan/gate-audit.jsonl" \
  && ok "态15 豁免路径 pass/exempt-path 命中" || bad "态15 缺豁免 pass 行"

# --- 态 16：Bash 非白名单命令落 pass/bash-not-whitelisted（态5 的 git status） ---
grep -q '"reason":"bash-not-whitelisted"' "$TMP/p4/.swarm-yuan/gate-audit.jsonl" \
  && ok "态16 Bash 非白名单 pass 行命中" || bad "态16 缺 bash-not-whitelisted 行"
grep -q '"handler":"fail-gate-hook:bash"' "$TMP/p4/.swarm-yuan/gate-audit.jsonl" && ok "态16 handler=bash 命中" || bad "态16 缺 bash handler"

# --- 态 17：休眠不写审计（p9 无 flag → 无 audit 文件） ---
[[ ! -f "$TMP/p9/.swarm-yuan/gate-audit.jsonl" ]] && ok "态17 休眠态不写审计" || bad "态17 休眠态误写审计"

# --- 态 18：--report 新分支（audit 存在 → 拦截率） ---
# p1 的决策点：态1 deny + 态3 pass = 2 点 1 deny → 拦截率 50.0%
out=$(bash "$HOOK" --report --project "$TMP/p1" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态18 --report exit 0" || bad "态18 exit=$rc"
echo "$out" | grep -q '^## fail-gate 审计报告' && ok "态18 新报告标题命中" || bad "态18 缺新标题: $out"
echo "$out" | grep -q '拦截率' && ok "态18 拦截率段命中" || bad "态18 缺拦截率段: $out"
echo "$out" | grep -q '50.0%' && ok "态18 拦截率 50.0% 正确" || bad "态18 拦截率错误: $(echo "$out" | grep '%')"
echo "$out" | grep -q '按工具决策分布' && ok "态18 工具决策分布段命中" || bad "态18 缺分布段: $out"

# --- 态 19-22：rules.d 无条件面（audit-claims-reality 修复回归锚）---
# 修复前：rules.d 求值被 GATE_ENFORCE_DENY 空 + GATE_ENFORCE_DENY_BASH 空两道 early-exit 挡死，
# 默认配置下 FORBID 永不生效。修复后：forbid 无条件 deny（不依赖开关、不依赖门禁红 flag）。
# 布局：模拟生成物 scripts/ 归一（hook + gate-rules.sh 同目录，rules.d 在上一级），
# 与 UNIVERSAL_FILES 新 dest（scripts/fail-gate-hook.sh|hook）一致。
setup_rules_proj() {
  mkdir -p "$1/scripts" "$1/rules.d" "$1/.swarm-yuan"
  cat > "$1/SKILL.md" <<EOF
---
status: active
---
EOF
  cat > "$1/scripts/precheck.conf" <<EOF
PROJECT_DIR="$1"
GATE_ENFORCE_DENY=""
EOF
  cp "$HOOK" "$1/scripts/fail-gate-hook.sh"
  cp "scripts/gate-rules.sh" "$1/scripts/gate-rules.sh"
  cp assets/rules.d/*.rules "$1/rules.d/"
}

# 态 19：默认配置（白名单全空）+ 无 flag → rules.d FORBID（npm publish）仍硬拦
setup_rules_proj "$TMP/pr1"
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"npm publish --access public"},"cwd":"'$TMP'/pr1"}' | bash "$TMP/pr1/scripts/fail-gate-hook.sh" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态19 rules.d forbid 默认配置硬拦" || bad "态19 未 deny: $out"
echo "$out" | grep -q '替代' && ok "态19 deny 消息带替代方案" || bad "态19 缺替代方案: $out"
grep -q '"reason":"rules-forbid"' "$TMP/pr1/.swarm-yuan/gate-audit.jsonl" 2>/dev/null \
  && ok "态19 forbid 审计落盘" || bad "态19 审计未落盘"

# 态 20：rules.d allow（git status）→ 放行（无 deny 输出）+ 审计 rules-allow
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"'$TMP'/pr1"}' | bash "$TMP/pr1/scripts/fail-gate-hook.sh" 2>&1)
[[ -z "$out" ]] && ok "态20 rules.d allow 放行" || bad "态20 误拦只读: $out"
grep -q '"reason":"rules-allow"' "$TMP/pr1/.swarm-yuan/gate-audit.jsonl" 2>/dev/null \
  && ok "态20 allow 审计落盘" || bad "态20 审计未落盘"

# 态 21：rm -rf 命中 forbid（无条件面第二条默认规则）
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf node_modules"},"cwd":"'$TMP'/pr1"}' | bash "$TMP/pr1/scripts/fail-gate-hook.sh" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态21 rm -rf forbid 硬拦" || bad "态21 未 deny: $out"

# 态 22：prompt 命中（git push）+ 默认配置（白名单空）→ 落回白名单 → 放行不拦
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"'$TMP'/pr1"}' | bash "$TMP/pr1/scripts/fail-gate-hook.sh" 2>&1)
[[ -z "$out" ]] && ok "态22 prompt 落回白名单默认放行" || bad "态22 prompt 被误拦: $out"

# 态 23：draft 期 rules.d forbid 仍硬拦（audit-2026-08-25：forbid 无条件面不被 draft 静默）；
# 但 draft 期白名单/flag 捕获面仍休眠（态 8 语义不变）
setup_rules_proj "$TMP/pr2"
sed -i.bak 's/status: active/status: draft/' "$TMP/pr2/SKILL.md"
rm -f "$TMP/pr2/SKILL.md.bak"
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf node_modules"},"cwd":"'$TMP'/pr2"}' | bash "$TMP/pr2/scripts/fail-gate-hook.sh" 2>&1)
echo "$out" | grep -q '"permissionDecision":"deny"' && ok "态23 draft 期 forbid 仍硬拦" || bad "态23 draft 吞了 forbid: $out"
out=$(echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"'$TMP'/pr2"}' | bash "$TMP/pr2/scripts/fail-gate-hook.sh" 2>&1)
[[ -z "$out" ]] && ok "态23 draft 期 allow 仍放行" || bad "态23 draft 误拦只读: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-fail-gate-hook"; exit 0; } || { echo "FAIL test-fail-gate-hook" >&2; exit 1; }

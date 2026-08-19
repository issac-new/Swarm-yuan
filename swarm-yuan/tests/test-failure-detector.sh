#!/usr/bin/env bash
# test-failure-detector.sh — failure-detector.sh + trace-log --key-node 测试（WP-Q2-lite）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
FD="assets/hooks/failure-detector.sh"
TL="assets/trace-log.sh"
TMP="$(mktemp -d /tmp/q2test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

mkdir -p "$TMP/proj"
export PROJECT_DIR="$TMP/proj"

# --- 态 1：单次失败无干预 ---
out=$(echo '{"tool_name":"Bash","tool_result":{"exit_code":1,"content":"error: foo"},"session_id":"s1"}' | bash "$FD" 2>&1)
[[ -z "$out" ]] && ok "态1 单次失败无干预" || bad "态1 输出: $out"

# --- 态 2：连续 2 次同签名失败 → L1 完整块 ---
out=$(echo '{"tool_name":"Bash","tool_result":{"exit_code":1,"content":"error: foo"},"session_id":"s1"}' | bash "$FD" 2>&1)
echo "$out" | grep -q 'L1 — 连续失败检测' && ok "态2 第二次同签名 L1 命中" || bad "态2 缺 L1: $out"

# --- 态 3：连续 3 次同签名 → SPINNING brief（不再发完整 L2）---
out=$(echo '{"tool_name":"Bash","tool_result":{"exit_code":1,"content":"error: foo"},"session_id":"s1"}' | bash "$FD" 2>&1)
echo "$out" | grep -q 'SPINNING brief — 同一错误第 3 次' && ok "态3 第三次 SPINNING brief 命中" || bad "态3 缺 brief: $out"
echo "$out" | grep -q 'L2 —' && bad "态3 误发完整 L2（应 brief）: $out" || ok "态3 无完整 L2（去重 OK）"

# --- 态 4：连续 4 次同签名 → SPINNING brief（不再发 L3）---
out=$(echo '{"tool_name":"Bash","tool_result":{"exit_code":1,"content":"error: foo"},"session_id":"s1"}' | bash "$FD" 2>&1)
echo "$out" | grep -q 'SPINNING brief — 同一错误第 4 次' && ok "态4 第四次 SPINNING brief 命中" || bad "态4 缺 brief: $out"
echo "$out" | grep -q 'L3 —' && bad "态4 误发完整 L3（应 brief）: $out" || ok "态4 无完整 L3（去重 OK）"

# --- 态 5：换签名 → same_sig_count 重置 → L 等级按 COUNT 走 ---
out=$(echo '{"tool_name":"Bash","tool_result":{"exit_code":1,"content":"error: different thing"},"session_id":"s1"}' | bash "$FD" 2>&1)
# 第 5 次失败，COUNT=5 → L4
echo "$out" | grep -qE 'L4 — 交接报告|L[1-3]' && ok "态5 换签名 L 等级命中" || bad "态5 缺 L 块: $out"
# same_sig_count 应重置为 1
cnt=$(cat "$TMP/proj/.swarm-yuan/.same_sig_count" 2>/dev/null)
[[ "$cnt" == "1" ]] && ok "态5 换签名 same_sig_count 重置" || bad "态5 same_sig_count=$cnt 应=1"

# --- 态 6：成功后 same_sig_count 清 0 ---
echo '{"tool_name":"Bash","tool_result":{"exit_code":0,"content":"ok"},"session_id":"s1"}' | bash "$FD" >/dev/null 2>&1
cnt=$(cat "$TMP/proj/.swarm-yuan/.same_sig_count" 2>/dev/null || echo "0")
[[ "$cnt" == "0" ]] && ok "态6 成功后 same_sig_count 清 0" || bad "态6 未清 0: $cnt"

# --- 态 7：tone 软化——L3 不再有"3.25/毕业"话术（4 次都不同签名，避免 SPINNING brief 拦截）---
rm -rf "$TMP/proj/.swarm-yuan"
# 4 次连续失败，每次不同签名（避免 SPINNING 拦截）
for i in 1 2 3 4; do
  out=$(echo "{\"tool_name\":\"Bash\",\"tool_result\":{\"exit_code\":1,\"content\":\"error: thing $i happened\"},\"session_id\":\"s1\"}" | bash "$FD" 2>&1)
done
echo "$out" | grep -qE '3\.25|毕业' && bad "态7 tone 仍有 3.25/毕业话术: $out" || ok "态7 tone 软化（无 3.25/毕业）"
echo "$out" | grep -q 'L3 — 换路线审问' && ok "态7 L3 重命名为换路线审问" || bad "态7 缺新 L3 名: $out"

# --- 态 8：trace-log --key-node 落盘 ---
mkdir -p "$TMP/proj8"
out=$(PROJECT_DIR="$TMP/proj8" bash "$TL" --key-node "①探查仓库" --actor "swarm-yuan/ai" --status started --note "三路并行" 2>&1)
echo "$out" | grep -q '→ \[关键节点\] ①探查仓库' && ok "态8 --key-node stdout 提示" || bad "态8 缺提示: $out"
[[ -f "$TMP/proj8/.swarm-yuan/key-nodes.jsonl" ]] && ok "态8 key-nodes.jsonl 落盘" || bad "态8 未落盘"
grep -q '"key_node":"①探查仓库"' "$TMP/proj8/.swarm-yuan/key-nodes.jsonl" && ok "态8 jsonl 含 key_node 字段" || bad "态8 jsonl 缺字段"

# --- 态 9：--key-node 缺节点名 → 降级 exit 0 ---
out=$(PROJECT_DIR="$TMP/proj8" bash "$TL" --key-node "" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态9 缺节点名 exit 0（降级）" || bad "态9 exit=$rc"

# --- 态 10：--key-node-summary 不实现（最小切片）；只验证 --key-node 不再破坏 --node 普通调用 ---
out=$(PROJECT_DIR="$TMP/proj8" bash "$TL" --node "test" --actor "ai" --tool "ls" --status done 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态10 --node 普通调用兼容" || bad "态10 --node exit=$rc"
echo "$out" | grep -q '→ \[test\] 调用 ai · ls' && ok "态10 --node stdout 提示" || bad "态10 缺提示: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-failure-detector"; exit 0; } || { echo "FAIL test-failure-detector" >&2; exit 1; }

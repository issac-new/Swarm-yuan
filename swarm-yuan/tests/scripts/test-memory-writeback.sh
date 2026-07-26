#!/usr/bin/env bash
# test-memory-writeback.sh — S9 守卫测试：验证 memory-writeback.sh 不污染环境
# 测试 1：.zcode/memories/ 不存在时不创建（守卫）
# 测试 2：.zcode/memories/ 存在时写入（正常）
# 测试 3：幂等（重复运行追加不覆盖）
# 用法：bash tests/scripts/test-memory-writeback.sh
set -uo pipefail
MW="$(cd "$(dirname "$0")/../.." && pwd)/assets/memory-writeback.sh"
[[ -f "$MW" ]] || { echo "✗ memory-writeback.sh 不存在"; exit 1; }
TMP="$(mktemp -d /tmp/mw-test.XXXXXX)"
PASS=0; FAIL=0
pass(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
fail(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "=== S9 守卫测试：memory-writeback.sh 环境污染防护 ==="

# 测试 1：.zcode/memories/ 不存在时不创建
PROJECT_DIR="$TMP" bash "$MW" >/dev/null 2>&1
if [[ ! -d "$TMP/.zcode" ]]; then pass ".zcode 不存在时不创建（守卫生效）"; else fail ".zcode 被错误创建（守卫失效）"; fi

# 测试 2：.zcode/memories/ 存在时写入
mkdir -p "$TMP/.zcode/memories"
PROJECT_DIR="$TMP" bash "$MW" >/dev/null 2>&1
if [[ -f "$TMP/.zcode/memories/project-knowledge.md" ]]; then pass ".zcode/memories/ 存在时正确写入"; else fail ".zcode/memories/ 未写入"; fi

# 测试 3：幂等（重复运行追加，行数增长）
LINES_BEFORE=$(wc -l < "$TMP/.zcode/memories/project-knowledge.md" | tr -d ' ')
PROJECT_DIR="$TMP" bash "$MW" >/dev/null 2>&1
LINES_AFTER=$(wc -l < "$TMP/.zcode/memories/project-knowledge.md" | tr -d ' ')
if [[ "$LINES_AFTER" -gt "$LINES_BEFORE" ]]; then pass "幂等追加（${LINES_BEFORE}→${LINES_AFTER} 行）"; else fail "幂等失效（${LINES_BEFORE}→${LINES_AFTER}）"; fi

# 测试 4：.swarm-yuan/ 始终写（本地兜底）
if [[ -f "$TMP/.swarm-yuan/project-knowledge.md" ]]; then pass ".swarm-yuan/ 本地兜底始终写"; else fail ".swarm-yuan/ 未写"; fi

# 测试 5：永不 fail 阻塞（exit 0 即使部分 sink 失败）
PROJECT_DIR="/nonexistent-path-xyz" bash "$MW" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then pass "无效 PROJECT_DIR 仍 exit 0（best-effort 不阻塞）"; else fail "无效 PROJECT_DIR 阻塞了"; fi

rm -rf "$TMP"
echo "=== 汇总：PASS=$PASS FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] && echo "✓ S9 守卫测试通过" || { echo "✗ S9 守卫测试失败"; exit 1; }

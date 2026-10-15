#!/usr/bin/env bash
# run-sweep.sh — 本地全量回归统一入口（R70 流程修复：此前各轮"全量 sweep"是临时 for 循环，
# 只跑 tests/test-*.sh，不含 verifier（shellcheck/产物 e2e/夹具双态）——R66-R69 连续四轮
# CI 红的流程根因。本脚本把"收口前必跑"的完整面固化为单一命令，任一环节失败即非零退出。
#
# 用法: bash swarm-yuan/tests/run-sweep.sh
# 覆盖面（与 CI 同构）:
#   ① tests/test-*.sh 全部锁测试
#   ② tests/run-e2e.sh（注入链路 e2e）
#   ③ tests/run-gen-e2e.sh（生成产物 e2e——mark-active 闭环）
#   ④ tests/run-fieldchange-e2e.sh（字段变更传播 e2e）
#   ⑤ verifier/v1/run-verifier.sh all（79+1 夹具双态 + gate fixtures + CLI_AB + golden + shellcheck + 自举）
#   ⑥ self-check.sh --check-only（口径一致性）
set -u
BASE="$(cd "$(dirname "${0}")/.." && pwd)"          # swarm-yuan/
REPO="$(cd "${BASE}/.." && pwd)"                     # 仓库根（verifier/ 在此）
cd "${REPO}" || exit 1

pass=0; fail=0
ok()  { echo "  ✓ [$1] 通过"; pass=$((pass+1)); }
bad() { echo "  ✗ [$1] 失败（日志: $2）"; fail=$((fail+1)); }

run_step() { # $1=名称 $2=日志路径 $3..=命令
  local name="$1" log="$2"; shift 2
  if "$@" > "${log}" 2>&1; then
    ok "${name}"
  else
    bad "${name}" "${log}"
  fi
}

echo "=== swarm-yuan 本地全量回归（run-sweep.sh）==="

# ① 锁测试全量
for t in "${BASE}"/tests/test-*.sh; do
  [[ -f "$t" ]] || continue
  run_step "$(basename "$t")" "/tmp/sweep-$(basename "$t" .sh).log" bash "$t"
done

# ②③④ 三条 e2e
run_step "e2e（注入链路）" /tmp/sweep-e2e.log bash "${BASE}/tests/e2e/run-e2e.sh"
run_step "gen-e2e（生成产物/mark-active 闭环）" /tmp/sweep-gen-e2e.log bash "${BASE}/tests/e2e/run-gen-e2e.sh"
run_step "fieldchange-e2e" /tmp/sweep-fieldchange.log bash "${BASE}/tests/e2e/run-fieldchange-e2e.sh"

# ⑤ verifier all（夹具双态 + gate fixtures + CLI_AB + golden + shellcheck + 自举闭环）
run_step "verifier-all" /tmp/sweep-verifier.log bash "${REPO}/verifier/v1/run-verifier.sh" all

# ⑥ self-check
run_step "self-check" /tmp/sweep-self-check.log bash "${BASE}/scripts/self-check.sh" --check-only

echo "=== 汇总：${pass} 通过 / ${fail} 失败 ==="
[[ ${fail} -eq 0 ]]

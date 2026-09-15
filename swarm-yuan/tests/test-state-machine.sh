#!/usr/bin/env bash
# test-state-machine.sh — state-machine.sh transition 阶段名合法性测试
# R28-DF5 回归锚（2026-09-16 执勤实证）：未知阶段名（implement）原先落到 tgt_idx=-1
# 走「不能回退」分支，且在「阶段转换」横幅之后才报——横幅+回退话术双重误导。
# 修复：阶段名合法性前置校验，未知名直接报「未知阶段」并列出合法阶段，不打横幅。
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
ROOT="$(pwd)"
SH="${ROOT}/assets/state-machine.sh"
TMP="$(mktemp -d /tmp/smt.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

mkdir -p "$TMP/proj" && cd "$TMP/proj" || exit 1
out="$(bash "$SH" init demo-change 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && ok "init 成功" || bad "init exit=$rc: $out"

# 态 0（R28-DF8 回归锚）：conf 接线不得消费骨架 conf 的 <项目根绝对路径> 占位符——
# 防护失效时 STATE_DIR 会落进 cwd 下字面量垃圾目录，真实 state.yaml 反而缺失。
[[ -f .swarm-yuan/state.yaml ]] && ok "态0 state.yaml 落在 cwd/.swarm-yuan（占位符未当真值）" \
  || bad "态0 state.yaml 缺失（占位符被当真值消费）: $(ls -d '<'* 2>/dev/null || echo 无 .swarm-yuan/)"
[[ -d "<项目根绝对路径>" ]] && bad "态0 产生字面量垃圾目录 <项目根绝对路径>" \
  || ok "态0 无字面量垃圾目录"

# 态 1：未知阶段名 → 「未知阶段」+ exit 1，且不出现「阶段转换」横幅
out="$(bash "$SH" transition implement 2>&1)"; rc=$?
[[ $rc -eq 1 ]] && ok "态1 未知阶段 exit 1" || bad "态1 exit=$rc: $out"
grep -q '未知阶段: implement' <<<"$out" && ok "态1 报未知阶段并列出合法值" || bad "态1 报错话术异常: $out"
grep -q '阶段转换' <<<"$out" && bad "态1 未知名不应打阶段转换横幅" || ok "态1 不打阶段转换横幅"
grep -q '不能回退' <<<"$out" && bad "态1 未知名不应走回退话术" || ok "态1 不走回退话术"

# 态 2：状态文件 phase 字段被写坏 → 「phase 字段异常」+ exit 1
if grep -q '^phase: open' .swarm-yuan/state.yaml; then
  sed -i.bak 's/^phase: open/phase: bogus/' .swarm-yuan/state.yaml && rm -f .swarm-yuan/state.yaml.bak
fi
out="$(bash "$SH" transition build 2>&1)"; rc=$?
[[ $rc -eq 1 ]] && ok "态2 phase 异常 exit 1" || bad "态2 exit=$rc: $out"
grep -q 'phase 字段异常: bogus' <<<"$out" && ok "态2 报 phase 字段异常" || bad "态2 报错话术异常: $out"

# 态 3：正常路径——proposal 存在时 open→design 通过（合法性校验不误伤合法转换）
sed -i.bak 's/^phase: bogus/phase: open/' .swarm-yuan/state.yaml && rm -f .swarm-yuan/state.yaml.bak
printf '# proposal\n演示用开放阶段产出。\n' > .swarm-yuan/proposal.md
out="$(bash "$SH" transition design 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && ok "态3 合法转换 open→design 通过" || bad "态3 exit=$rc: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-state-machine"; exit 0; } || { echo "FAIL test-state-machine" >&2; exit 1; }

#!/usr/bin/env bash
# run-verifier.sh — Swarm-yuan 重构验收器 v1
# 用法: bash verifier/v1/run-verifier.sh <mode> [repo_root]
#   mode = fixtures | gate-fixtures | e2e | gen-e2e | shellcheck | metrics | cli-ab | all
#   metrics = 既有测量行 + C6 阈值断言（v1/metrics-assert.sh）；cli-ab = C5 A/B 逐字节等价断言（v1/cli-ab-test.sh）
# 输出: 机器可读结果到 stdout，供 verifier/runs/ 记录
set -u
MODE="${1:-all}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -ge 2 ] && ROOT="$(cd "$2" && pwd)"
SY="$ROOT/swarm-yuan"
# 查找 shellcheck 的顺序：$SHELLCHECK 环境变量 → PATH 中的 shellcheck → /tmp/shellcheck（历史 /mnt/agents/tools 拷贝）。
# 失败关闭（fail-closed）：若以上均无，shellcheck_scan 报告 SHELLCHECK_UNAVAILABLE 并返回非零，
# 而不是在每台缺 shellcheck 的机器上谎报 SHELLCHECK_ERRORS 0（历史缺陷：cp /mnt/agents/tools 失败被静默吞掉）。
SC=""
if [ -n "${SHELLCHECK:-}" ] && [ -x "${SHELLCHECK:-}" ]; then
  SC="$SHELLCHECK"
elif command -v shellcheck >/dev/null 2>&1; then
  SC="$(command -v shellcheck)"
elif [ -x /tmp/shellcheck ]; then
  SC="/tmp/shellcheck"
elif [ -f /mnt/agents/tools/shellcheck ]; then
  cp /mnt/agents/tools/shellcheck /tmp/shellcheck 2>/dev/null && chmod +x /tmp/shellcheck 2>/dev/null && SC="/tmp/shellcheck"
fi

fixtures() {
  local ids id rc_v rc_c id_fail outcome fails=0 total=0
  ids=$(ls "$SY/tests/fixtures" 2>/dev/null)
  for id in $ids; do
    [ -d "$SY/tests/fixtures/$id/violating" ] || continue
    [ -f "$SY/assets/framework-gates/$id.sh" ] || continue
    total=$((total+1))
    outcome=$(bash "$(dirname "$0")/run-one-fixture.sh" "$SY" "$id")
    # outcome = "<rc_v> <rc_c> <id_failures>"（三段，空格分隔）
    rc_v=$(echo "$outcome" | awk '{print $1}')
    rc_c=$(echo "$outcome" | awk '{print $2}')
    id_fail=$(echo "$outcome" | awk '{print $3}')
    # id 级双态断言（P2 #5）：violating 期望非 0，compliant 期望 0，且 expected-fail-ids 全命中（id_fail=0）
    if [ "$rc_v" != "0" ] && [ "$rc_c" = "0" ] && [ "$id_fail" = "0" ]; then
      echo "FIXTURE $id OK (v=$rc_v c=$rc_c ids=0)"
    else
      echo "FIXTURE $id BAD (v=$rc_v c=$rc_c ids=$id_fail)"; fails=$((fails+1))
    fi
  done
  echo "FIXTURES_TOTAL $total FAILS $fails"
  [ "$fails" -eq 0 ]
}

e2e() {
  local rc
  bash "$SY/tests/e2e/run-e2e.sh" >/tmp/verifier-e2e.log 2>&1
  rc=$?
  echo "E2E_RC $rc"
  return "$rc"
}

# WP-B：生成产物 e2e 回归——断言 generate-skill.sh create 产物质量（骨架/JSON/workflow/conf 嗅探）。
# 与 e2e()（测 --inject-frameworks 注入链路）互补：e2e 测生成器行为，gen_e2e 测生成产物。
gen_e2e() {
  local rc
  bash "$SY/tests/e2e/run-gen-e2e.sh" >/tmp/verifier-gen-e2e.log 2>&1
  rc=$?
  echo "GEN_E2E_RC $rc"
  return "$rc"
}

# 合规门禁 fixture（C8）：遍历全部 gate fixture 组（WP3.3：从硬编码 6 组改为全量遍历），双态 + id 级断言
gate_fixtures() {
  local g fails=0 total=0
  for g in $(ls "$SY/tests/gate-fixtures" 2>/dev/null); do
    [ -d "$SY/tests/gate-fixtures/$g" ] || continue
    total=$((total+1))
    if bash "$SY/tests/run-gate-fixture.sh" "$g" >/tmp/verifier-gatefx-$g.log 2>&1; then
      echo "GATE_FIXTURE $g OK"
    else
      echo "GATE_FIXTURE $g BAD（日志 /tmp/verifier-gatefx-$g.log）"; fails=$((fails+1))
    fi
  done
  echo "GATE_FIXTURES_TOTAL $total FAILS $fails"
  echo "GATE_FIXTURES_FAILS $fails"
  [ "$fails" -eq 0 ]
}

# golden-vector 内容比对（C1 行为等价 fail-closed）：
# 跑 fixtures 生成当前向量，与 golden-vector.txt 逐行 diff。漂移=门禁行为变了（可能是 bug 或故意调整）。
# 故意调整时用 rebuild-golden 重建基线；漂移则 fail + 提示重建。
golden_check() {
  local golden="$(dirname "$0")/golden-vector.txt"
  local tmp; tmp="$(mktemp /tmp/golden-check.XXXXXX)"
  fixtures > "$tmp"
  if diff -u "$golden" "$tmp" >/dev/null 2>&1; then
    echo "GOLDEN_VECTOR OK（$(wc -l < "$golden" | tr -d ' ') 行向量与 golden 逐行一致）"
    rm -f "$tmp"
    return 0
  fi
  echo "GOLDEN_VECTOR DRIFT（门禁行为已变，diff 如下）"
  diff -u "$golden" "$tmp" | head -40
  echo "  若属故意门禁调整：bash verifier/v1/run-verifier.sh rebuild-golden 重建基线并审 git diff"
  rm -f "$tmp"
  return 1
}

# rebuild-golden：故意调整门禁后重建 golden-vector.txt 基线。
# fail-closed：存在 BAD fixture 时拒绝把坏向量写成 golden（防"坏门禁被固化进基线"）。
rebuild_golden() {
  local golden="$(dirname "$0")/golden-vector.txt"
  local tmp; tmp="$(mktemp /tmp/golden-rebuild.XXXXXX)"
  fixtures > "$tmp"
  # fail-closed：存在 BAD fixture 时拒绝重建
  if ! tail -1 "$tmp" | grep -q "FAILS 0"; then
    echo "REBUILD_GOLDEN REFUSED（存在 BAD fixture，先修门禁再重建）"
    tail -1 "$tmp"
    rm -f "$tmp"
    return 1
  fi
  # 先展示将应用的变更（供审阅），再覆盖
  echo "REBUILD_GOLDEN DIFF（将应用以下变更到 golden-vector.txt）"
  diff -u "$golden" "$tmp" || true
  cp "$tmp" "$golden"
  echo "REBUILD_GOLDEN OK（已覆盖 golden-vector.txt，请 git diff 审阅后随代码同 commit）"
  rm -f "$tmp"
}

shellcheck_scan() {
  if [ -z "$SC" ]; then
    echo "SHELLCHECK_UNAVAILABLE (无 shellcheck：设 \$SHELLCHECK、装入 PATH，或提供 /tmp/shellcheck)"
    return 1
  fi
  local f total_e=0 total_w=0 c
  for f in "$SY/assets/precheck.sh" "$SY/scripts/generate-skill.sh" "$SY/scripts/self-check.sh" "$SY/assets/state-machine.sh" "$SY"/assets/framework-gates/*.sh "$ROOT/Swarm-studio/scripts/precheck.sh"; do
    [ -f "$f" ] || continue
    c=$("$SC" -s bash -S error -f gcc "$f" 2>/dev/null | wc -l)
    total_e=$((total_e+c))
  done
  echo "SHELLCHECK_ERRORS $total_e"
  for f in "$SY/assets/precheck.sh" "$SY/scripts/generate-skill.sh" "$SY/scripts/self-check.sh" "$SY"/assets/framework-gates/*.sh; do
    c=$("$SC" -s bash -S warning -f gcc "$f" 2>/dev/null | wc -l)
    total_w=$((total_w+c))
  done
  echo "SHELLCHECK_WARNINGS_CORE $total_w"
}

metrics() {
  echo "LOC_PRECHECK $(wc -l < "$SY/assets/precheck.sh")"
  # Swarm-studio 是兄弟仓库（不在本仓库内）；存在时报告双副本漂移度量，不存在时显式标记
  # ABSENT 而非让 wc -l/diff 对缺失文件报错被静默吞掉（历史缺陷：cp 失败被静默吞掉的同类）。
  # 该度量属信息性，metrics-assert.sh 不对其断言（C3 双副本一致性已由 ② 注入双副本 diff 覆盖）。
  local studio="$ROOT/Swarm-studio/scripts/precheck.sh"
  if [ -f "$studio" ]; then
    echo "LOC_PRECHECK_STUDIO $(wc -l < "$studio")"
    echo "DUP_DIFF_LINES $(diff "$SY/assets/precheck.sh" "$studio" | grep -c '^[<>]')"
  else
    echo "LOC_PRECHECK_STUDIO ABSENT（Swarm-studio 兄弟仓库不在本机）"
    echo "DUP_DIFF_LINES ABSENT（同上）"
  fi
  echo "GATES_COUNT $(ls "$SY"/assets/framework-gates/*.sh | wc -l)"
  echo "GATES_TOTAL_LOC $(cat "$SY"/assets/framework-gates/*.sh | wc -l)"
  echo "DS_STORE $(find "$ROOT" -name .DS_Store -not -path "*/.git/*" | wc -l)"
}

# C5 CLI 兼容断言（v1/cli-ab-test.sh：A=HEAD vs B=工作区，GATE_FLAGS 全 flag × 双语料
# stdout+退出码逐字节等价 + --all 核心 10 序列基线断言；环境未配置时静默跳过）
cli_ab() {
  bash "$(dirname "$0")/cli-ab-test.sh" "$ROOT"
}

# C6 可维护性阈值断言（v1/metrics-assert.sh：LOC 增长/注入双副本 diff/文档一致性段；
# 阈值真值 v1/metrics-baseline.txt，缺失即未配置静默跳过，启用后 fail-closed）
metrics_assert() {
  bash "$(dirname "$0")/metrics-assert.sh" "$ROOT"
}

# WP-Z13: 自举闭环断言（G4）——生成器对自身仓库跑 --all，RC=0 才算通过。
# self-check.sh 已有 check_bootstrap_gate 对账 ci/self-precheck.conf + CI 三档 step，
# 本函数在 verifier 层实跑一次 --all，补齐"自举从 slogan 变证据"的最后一环。
# 跳过条件：ci/self-precheck.conf 不存在（安装态 ~/.claude/skills 无 ci/ 目录）。
bootstrap_self_gate() {
  local conf="$SY/ci/self-precheck.conf"
  [ -f "$conf" ] || { echo "BOOTSTRAP_SELF_GATE ABSENT（ci/self-precheck.conf 不存在，安装态跳过）"; return 0; }
  echo "=== C9 自举闭环（生成器对自身跑 precheck --all）==="
  local tmpdir; tmpdir="$(mktemp -d)"
  # 拷贝四件套（precheck.sh + gates-*.sh，与 CI generator-self-gate Job 同款）
  cp "$SY/assets/precheck.sh" "$SY/assets/gates-strict.sh" "$SY/assets/gates-warn.sh" "$SY/assets/gates-advisory.sh" "$tmpdir/" 2>/dev/null || true
  # 占位符替换：__REPO_ROOT__ → 仓库根
  sed "s|__REPO_ROOT__|$ROOT|g" "$conf" > "$tmpdir/precheck.conf"
  # detached HEAD 兜底：建临时 feat 分支让分支门禁真实执行
  ( cd "$ROOT" && git checkout -b feat/verifier-bootstrap-self-gate 2>/dev/null ) || true
  local out rc
  out=$( cd "$ROOT" && bash "$tmpdir/precheck.sh" --all 2>&1 ) || true
  rc=$?
  # 清理临时分支（不破坏原 HEAD）
  ( cd "$ROOT" && git checkout - 2>/dev/null && git branch -D feat/verifier-bootstrap-self-gate 2>/dev/null ) || true
  rm -rf "$tmpdir"
  if [ "$rc" -eq 0 ]; then
    echo "BOOTSTRAP_SELF_GATE OK (precheck --all RC=0)"
    echo "$out" | tail -3 | sed 's/^/    /'
    return 0
  else
    echo "BOOTSTRAP_SELF_GATE FAIL (precheck --all RC=$rc)"
    echo "$out" | tail -10 | sed 's/^/    /'
    return 1
  fi
}

case "$MODE" in
  fixtures) fixtures ;;
  gate-fixtures) gate_fixtures ;;
  e2e) e2e ;;
  gen-e2e) gen_e2e ;;
  shellcheck) shellcheck_scan ;;
  metrics) metrics; metrics_assert ;;
  cli-ab) cli_ab ;;
  bootstrap) bootstrap_self_gate ;;
  golden) golden_check ;;
  rebuild-golden) rebuild_golden ;;
  # all：既有各模式输出与投票语义不变（shellcheck 不投票、gate_fixtures 投票），
  # 新增 metrics_assert、cli_ab、bootstrap_self_gate 三票（fail-closed），任一票失败则 all 非零。
  # WP-B：gen_e2e 加入 all 投票（fail-closed，守生成产物质量回归）。
  # fix(verifier-honesty)：fixtures/e2e 从"只输出不投票"改为进 all 投票（fail-closed，
  # 本地 run-verifier.sh all 与 CI 同级）；gen_e2e 死票修复（函数末尾 echo 恒返回 0，
  # 已改为 return 真实 rc）；golden_check 替代裸 fixtures（fail-closed 比对 golden-vector 内容）。
  all)
    all_fail=0
    metrics; metrics_assert || all_fail=1
    shellcheck_scan
    e2e || all_fail=1
    gen_e2e || all_fail=1
    golden_check || all_fail=1
    gate_fixtures || all_fail=1
    cli_ab || all_fail=1
    bootstrap_self_gate || all_fail=1
    [ "$all_fail" -eq 0 ]
    ;;
esac

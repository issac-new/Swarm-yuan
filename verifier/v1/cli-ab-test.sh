#!/usr/bin/env bash
# cli-ab-test.sh — C5 CLI 兼容断言化（A/B 沙箱逐字节等价，验收标准 v1 C5）
#
# A 版 = git HEAD 版 precheck.sh；B 版 = 工作区版 precheck.sh。
# 对 GATE_FLAGS 全部 flag（运行时从 B 版注册表解析，当前 31 个）×
# compliant/violating 两语料 × A/B 双版本逐用例断言：
#   断言① 退出码 ∈ {0,1}（崩溃/段错误/用法错误等异常退出即失败）
#   断言② A/B stdout 逐字节一致 且 退出码一致（历史 C5「131 次调用逐字节一致」的脚本化）
# 附加固定用例：无参数（默认 --all）、--all-full、未知 flag（--bogus-flag → usage）。
#   断言③ --all 核心 10 门禁执行序列（stdout 中 '^=== ' 段头按序提取）
#         与基线文件 v1/core10-sequence.txt 逐字节一致（防 ALL_GATES_CORE 调序/段头改名）。
#
# 语料（tests/gate-fixtures 现有 fixture 项目样本，conf 由本脚本运行时生成）：
#   compliant = gate-fixtures/summary/compliant（最小 conf：BRANCH_REGEX 放宽 + IMPACT_SPEC_FILE 供给）
#   violating = gate-fixtures/sensitive/violating（同最小 conf + SCAN_DIRS=("src")，--sensitive 实际触发 fail）
#
# 环境约定：
#   - 无 git、HEAD 无 precheck.sh 对象、语料目录缺失 → 按「未配置」静默跳过（CLI_AB_SKIP，RC=0）；
#     基线序列文件缺失 → 仅断言③跳过。启用（对象齐备）后 fail-closed。
#   - A/B 口径为「HEAD↔工作区」，须在工作区静止期判定：并行改动 precheck.sh 或语料会合理报 DIFF。
#
# 用法: bash verifier/v1/cli-ab-test.sh [repo_root]
# 输出: CLI_AB_* 机器可读行；退出码 0=全部断言通过/未配置跳过，1=断言失败
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -ge 1 ] && ROOT="$(cd "$1" && pwd)"
SY="$ROOT/swarm-yuan"
V1="$(cd "$(dirname "$0")" && pwd)"

PRECHECK_B="$SY/assets/precheck.sh"
[ -f "$PRECHECK_B" ] || { echo "CLI_AB_SKIP: 工作区 precheck.sh 不存在"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "CLI_AB_SKIP: 无 git，A 版（HEAD）基线不可用，未配置静默跳过"; exit 0; }

COMP_CORPUS="$SY/tests/gate-fixtures/summary/compliant"
VIOL_CORPUS="$SY/tests/gate-fixtures/sensitive/violating"
[ -d "$COMP_CORPUS" ] || { echo "CLI_AB_SKIP: compliant 语料缺失（${COMP_CORPUS}），未配置静默跳过"; exit 0; }
[ -d "$VIOL_CORPUS" ] || { echo "CLI_AB_SKIP: violating 语料缺失（${VIOL_CORPUS}），未配置静默跳过"; exit 0; }

WORK="$(mktemp -d /tmp/cli-ab.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# A 版（HEAD）：对象缺失 → 未配置静默跳过
if ! git -C "$ROOT" show "HEAD:swarm-yuan/assets/precheck.sh" > "$WORK/precheck-A.sh" 2>/dev/null; then
  echo "CLI_AB_SKIP: HEAD 无 swarm-yuan/assets/precheck.sh 对象，未配置静默跳过"
  exit 0
fi

# flag 清单：运行时自 B 版 GATE_FLAGS 注册表解析（门禁扩缩容随注册表自动跟随）
FLAGS=$(sed -n 's/^GATE_FLAGS=(\([^)]*\)).*/\1/p' "$PRECHECK_B")
[ -n "$FLAGS" ] || { echo "CLI_AB FAIL: 无法从 B 版解析 GATE_FLAGS 注册表"; exit 1; }

# 语料 conf（运行时生成；__REPO_ROOT__ 语义=语料目录，机器无关）
write_conf() { # $1=输出路径 $2=语料目录 $3=profile(comp|viol)
  {
    printf 'PROJECT_DIR="%s"\n' "$2"
    printf "BRANCH_REGEX='.*'\n"
    printf 'PROTECTED_BRANCHES=()\n'
    if [ "$3" = "comp" ]; then
      printf 'IMPACT_SPEC_FILE="%s/docs/impact-spec.md"\n' "$2"
    else
      printf 'SCAN_DIRS=("src")\n'
    fi
  } > "$1"
}

# 预建 4 个沙箱（profile × 版本），跨用例复用（precheck 不写 scripts/）
for prof in comp viol; do
  case "$prof" in
    comp) corpus="$COMP_CORPUS" ;;
    viol) corpus="$VIOL_CORPUS" ;;
  esac
  for ver in a b; do
    sd="$WORK/sd-$prof-$ver/scripts"
    mkdir -p "$sd"
    if [ "$ver" = "a" ]; then
      cp "$WORK/precheck-A.sh" "$sd/precheck.sh"
      # WP-Q1.3 拆分后 precheck.sh 依赖同目录 gates-strict/warn/advisory.sh（source 守卫），
      # 缺文件则全部门禁 command not found（rc=127）。A 版配套 gates 取自 HEAD 对象，
      # 与 precheck-A 同一代口径；对象缺失则跳过（source 守卫容忍，对齐 fixtures/e2e 拷贝范式）。
      for _gf in gates-strict.sh gates-warn.sh gates-advisory.sh; do
        git -C "$ROOT" show "HEAD:swarm-yuan/assets/$_gf" > "$sd/$_gf" 2>/dev/null || rm -f "$sd/$_gf"
      done
    else
      cp "$PRECHECK_B" "$sd/precheck.sh"
      # B 版配套 gates 取自工作区（与 PRECHECK_B 同一代口径）
      for _gf in gates-strict.sh gates-warn.sh gates-advisory.sh; do
        [ -f "$SY/assets/$_gf" ] && cp "$SY/assets/$_gf" "$sd/$_gf"
      done
    fi
    write_conf "$sd/precheck.conf" "$corpus" "$prof"
  done
done

CALLS=0
DIFFS=0
RC_INVALID=0

run_one() { # $1=沙箱脚本 $2=语料目录 $3=arg(可空) $4=stdout 落盘；echo 退出码
  local sh="$1" corpus="$2" arg="$3" outf="$4" rc
  if [ -n "$arg" ]; then
    ( cd "$corpus" && bash "$sh" "$arg" ) > "$outf" 2>/dev/null
  else
    ( cd "$corpus" && bash "$sh" ) > "$outf" 2>/dev/null
  fi
  rc=$?
  echo "$rc"
}

run_pair() { # $1=用例标签 $2=profile $3=arg(可空)
  local label="$1" prof="$2" arg="${3:-}" corpus rc_a rc_b
  case "$prof" in
    comp) corpus="$COMP_CORPUS" ;;
    viol) corpus="$VIOL_CORPUS" ;;
  esac
  rc_a=$(run_one "$WORK/sd-$prof-a/scripts/precheck.sh" "$corpus" "$arg" "$WORK/a.out")
  rc_b=$(run_one "$WORK/sd-$prof-b/scripts/precheck.sh" "$corpus" "$arg" "$WORK/b.out")
  CALLS=$((CALLS+2))
  case "$rc_a" in 0|1) : ;; *) echo "CLI_AB $label A_RC_INVALID($rc_a)"; RC_INVALID=$((RC_INVALID+1)) ;; esac
  case "$rc_b" in 0|1) : ;; *) echo "CLI_AB $label B_RC_INVALID($rc_b)"; RC_INVALID=$((RC_INVALID+1)) ;; esac
  if cmp -s "$WORK/a.out" "$WORK/b.out" && [ "$rc_a" = "$rc_b" ]; then
    echo "CLI_AB $label OK (rc=$rc_a, $(wc -c < "$WORK/a.out" | tr -d ' ')B 逐字节一致)"
  else
    echo "CLI_AB $label DIFF (rc_a=$rc_a rc_b=$rc_b)"
    diff "$WORK/a.out" "$WORK/b.out" | head -20
    DIFFS=$((DIFFS+1))
  fi
}

# ① 全 flag × 双语料 A/B 逐字节等价
for flag in $FLAGS; do
  run_pair "$flag@compliant" comp "$flag"
  run_pair "$flag@violating" viol "$flag"
done

# ② 固定用例：无参数（默认 --all）/ --all-full / 未知 flag
for prof in comp viol; do
  run_pair "(no-args=--all)@$prof" "$prof" ""
  run_pair "--all-full@$prof" "$prof" "--all-full"
done
run_pair "--bogus-flag@compliant" comp "--bogus-flag"

# ③ --all 核心 10 序列基线断言（B 版，compliant 语料）
SEQ_FILE="$V1/core10-sequence.txt"
if [ -f "$SEQ_FILE" ]; then
  rc_seq=$(run_one "$WORK/sd-comp-b/scripts/precheck.sh" "$COMP_CORPUS" "--all" "$WORK/all.out")
  CALLS=$((CALLS+1))
  grep '^=== ' "$WORK/all.out" > "$WORK/seq.out"
  if [ "$rc_seq" = "0" ] && cmp -s "$SEQ_FILE" "$WORK/seq.out"; then
    echo "CLI_AB_CORE10_SEQUENCE OK（核心 10 段头序列与 v1/core10-sequence.txt 逐字节一致）"
  else
    echo "CLI_AB_CORE10_SEQUENCE DIFF (rc=$rc_seq)"
    diff "$SEQ_FILE" "$WORK/seq.out" | head -20
    DIFFS=$((DIFFS+1))
  fi
else
  echo "CLI_AB_CORE10_SEQUENCE SKIP（基线文件 $SEQ_FILE 缺失，未配置静默跳过）"
fi

echo "CLI_AB_CALLS $CALLS"
echo "CLI_AB_DIFFS $DIFFS RC_INVALID $RC_INVALID"
echo "CLI_AB_FAILS $((DIFFS+RC_INVALID))"
[ "$DIFFS" -eq 0 ] && [ "$RC_INVALID" -eq 0 ]

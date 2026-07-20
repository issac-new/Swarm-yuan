#!/usr/bin/env bash
# 用法: run-gate-fixture.sh <gate> —— 合规/通用门禁 fixture 运行器
#   遍历 tests/gate-fixtures/<gate>/ 下 violating*/ 目录（期望退出非 0）与
#   compliant*/ 目录（期望退出 0）。每个 fixture 为自包含项目结构：
#     scripts/precheck.conf  conf（__REPO_ROOT__ 占位符，运行时替换为 fixture 根）
#     其余文件              项目样本（源码/文档/lockfile 等）
#   运行时拷贝当前 assets/precheck.sh 到临时目录执行（precheck.sh 与同目录 conf 联动）。
# 可选断言文件（置于 fixture 根，逐行字面串；空行与 # 注释行跳过）：
#   expected-ids    fail id 清单，输出须全部命中
#   forbidden-ids   输出不得命中
#   expect-output   输出须包含
# 可选钩子：scripts/setup.sh（precheck 执行前，cwd=fixture）与 scripts/teardown.sh
# （执行后无条件调用）——用于运行时生成被 .gitignore 排除的样本（如 node_modules mock）。
# gate → flag 映射：compliance/docs-pack/sbom/privacy/sensitive 同名单门禁；summary=--all-full。
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
GATE="${1:-}"
case "$GATE" in
  compliance) FLAG="--compliance";;
  docs-pack)  FLAG="--docs-pack";;
  sbom)       FLAG="--sbom";;
  privacy)    FLAG="--privacy";;
  sensitive)  FLAG="--sensitive";;
  summary)    FLAG="--all-full";;
  *) echo "用法: run-gate-fixture.sh <compliance|docs-pack|sbom|privacy|sensitive|summary>" >&2; exit 2;;
esac
FX="$BASE/tests/gate-fixtures/$GATE"
[[ -d "$FX" ]] || { echo "✗ fixture 目录不存在：$FX" >&2; exit 2; }

PASS_N=0
FAIL_N=0

# 逐行字面串断言：$1=断言文件 $2=must（须命中）|miss（不得命中）$3=输出文本
assert_lines() {
  local file="$1" mode="$2" out="$3" ln
  [[ -f "$file" ]] || return 0
  while IFS= read -r ln || [[ -n "$ln" ]]; do
    [[ -z "$ln" ]] && continue
    case "$ln" in \#*) continue;; esac
    if [[ "$mode" == "must" ]]; then
      if ! printf '%s\n' "$out" | grep -qF "$ln"; then
        echo "  ✗ 断言未命中（$(basename "$file")）：$ln"
        return 1
      fi
    else
      if printf '%s\n' "$out" | grep -qF "$ln"; then
        echo "  ✗ 禁中断言被命中（$(basename "$file")）：$ln"
        return 1
      fi
    fi
  done < "$file"
  return 0
}

# $1=fixture 目录  $2=expect fail|pass
run_one() {
  local fx="$1" expect="$2" name tmp out rc
  name="$(basename "$fx")"
  tmp="$(mktemp -d /tmp/gfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  # conf 中 __REPO_ROOT__ 占位符替换为 fixture 根（机器无关化）
  sed "s|__REPO_ROOT__|$fx|g" "$fx/scripts/precheck.conf" > "$tmp/scripts/precheck.conf"
  # setup 钩子：运行时生成被 .gitignore 排除的样本（如 node_modules mock）
  [[ -f "$fx/scripts/setup.sh" ]] && ( cd "$fx" && bash scripts/setup.sh )
  out="$( bash "$tmp/scripts/precheck.sh" "$FLAG" 2>&1 )"
  rc=$?
  rm -rf "$tmp"
  # teardown 钩子（无条件）+ SBOM 门禁产物目录清理（fixture 内 .sbom-out，conf 约定）
  [[ -f "$fx/scripts/teardown.sh" ]] && ( cd "$fx" && bash scripts/teardown.sh )
  rm -rf "$fx/.sbom-out"
  local ok=0
  if [[ "$expect" == "fail" ]]; then
    [[ $rc -ne 0 ]] || { echo "  ✗ $name：期望退出非 0，实际 $rc"; ok=1; }
  else
    [[ $rc -eq 0 ]] || { echo "  ✗ $name：期望退出 0，实际 $rc"; ok=1; }
  fi
  assert_lines "$fx/expected-ids" must "$out" || ok=1
  assert_lines "$fx/forbidden-ids" miss "$out" || ok=1
  assert_lines "$fx/expect-output" must "$out" || ok=1
  if [[ $ok -eq 0 ]]; then
    echo "  ✓ $name → 退出 $rc（符合预期：$expect）"
    return 0
  fi
  return 1
}

for fx in "$FX"/violating*/ "$FX"/compliant*/; do
  [[ -d "$fx" ]] || continue
  fx="${fx%/}"
  case "$(basename "$fx")" in
    violating*)  run_one "$fx" fail || FAIL_N=$((FAIL_N+1));;
    compliant*)  run_one "$fx" pass || FAIL_N=$((FAIL_N+1));;
  esac
done
TOTAL=0
for fx in "$FX"/violating*/ "$FX"/compliant*/; do
  [[ -d "$fx" ]] && TOTAL=$((TOTAL+1))
done
PASS_N=$((TOTAL-FAIL_N))
echo "gate-fixture [$GATE]：共 $TOTAL，PASS $PASS_N，FAIL $FAIL_N"
[[ $FAIL_N -eq 0 ]]

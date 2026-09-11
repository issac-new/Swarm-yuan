#!/usr/bin/env bash
# test-check-test-zero-runs.sh — R25-PF3 回归锚：check_test 零用例检出须覆盖多 runner 输出形态
#
# 真实执勤实证（2026-09-12 Java 栈 task-core）：mvn test 对无 JUnit 用例项目输出
# "Tests run: 0, Failures: 0"且 exit 0——原正则只认 jest/pytest 风格，零用例假绿穿透
# 门禁打出"✓ 测试通过"。修复补齐三种主流 runner 形态：Maven/Gradle surefire、Node TAP、pytest。
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
TMP="$(mktemp -d /tmp/zt.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# stub 门禁输出三函数（check_test 依赖调用方提供）+ 测试命令执行器
run_check_test() { # $1 = fake runner 输出 fixture 文件路径
  pass() { echo "PASS:$1" > "$TMP/out.txt"; }
  warn() { echo "WARN:$1" > "$TMP/out.txt"; }
  fail() { echo "FAIL:$1" > "$TMP/out.txt"; }
  TEST_CMD="cat $1"
  source assets/gates-warn.sh
  check_test > /dev/null 2>&1
  cat "$TMP/out.txt" 2>/dev/null || echo "NO-OUTPUT"
}

# 造 runner 输出 fixture（多行安全）
fixture() { printf '%b' "$2" > "$TMP/fx-$1.txt"; }

# 态 1：Maven/Gradle surefire 形态（执勤实证的穿透形态）
fixture maven 'Tests run: 0, Failures: 0, Errors: 0, Skipped: 0\n'
out=$(run_check_test "$TMP/fx-maven.txt")
grep -q "WARN:.*0 用例" <<<"$out" && ok "态1 surefire Tests run: 0 → warn" || bad "态1 假绿穿透: $out"

# 态 2：Node TAP 形态（node --test 零用例尾部）
fixture tap '# tests 0\n# pass 0\n# fail 0\n'
out=$(run_check_test "$TMP/fx-tap.txt")
grep -q "WARN:.*0 用例" <<<"$out" && ok "态2 Node TAP '# tests 0' → warn" || bad "态2 假绿穿透: $out"

# 态 3：pytest 零用例形态
fixture pytest 'no tests ran in 0.01s\n'
out=$(run_check_test "$TMP/fx-pytest.txt")
grep -q "WARN:.*0 用例" <<<"$out" && ok "态3 pytest 'no tests ran' → warn" || bad "态3 假绿穿透: $out"

# 态 4：jest 风格（原有正则已覆盖，防回归）
fixture jest 'Tests: 0 passed, 0 total\n'
out=$(run_check_test "$TMP/fx-jest.txt")
grep -q "WARN:.*0 用例" <<<"$out" && ok "态4 jest 'Tests: 0 passed' → warn（原有覆盖防回归）" || bad "态4 漏检: $out"

# 态 5：Python unittest 零用例形态
fixture unittest '-------------\nRan 0 tests in 0.000s\n\nOK\n'
out=$(run_check_test "$TMP/fx-unittest.txt")
grep -q "WARN:.*0 用例" <<<"$out" && ok "态5 unittest 'Ran 0 tests' → warn" || bad "态5 漏检: $out"

# 态 6：真用例通过不误报（5 个用例 → PASS 不是 WARN）
fixture real 'Tests run: 5, Failures: 0, Errors: 0, Skipped: 0\n'
out=$(run_check_test "$TMP/fx-real.txt")
grep -q "PASS:测试通过" <<<"$out" && ok "态6 真用例 5 → pass 不误报" || bad "态6 误报: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-check-test-zero-runs"; exit 0; } || { echo "FAIL test-check-test-zero-runs" >&2; exit 1; }

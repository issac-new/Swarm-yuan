#!/usr/bin/env bash
# test-project-fingerprint.sh — project-fingerprint.sh + generate-skill.sh --refresh 测试（WP-Q3-1）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
SH="scripts/project-fingerprint.sh"
GEN="scripts/generate-skill.sh"
TMP="$(mktemp -d /tmp/q3test.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：算+落盘 ---
mkdir -p "$TMP/proj/src" "$TMP/proj/docs"
printf 'def a(): pass\n' > "$TMP/proj/src/a.py"
printf 'const x = 1\n' > "$TMP/proj/src/b.ts"
printf '# docs\n' > "$TMP/proj/docs/README.md"

out=$(bash "$SH" "$TMP/proj" --write 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态1 落盘 exit 0" || bad "态1 exit=$rc: $out"
[[ -f "$TMP/proj/.swarm-yuan/project-fingerprint" ]] && ok "态1 指纹文件存在" || bad "态1 指纹未写入"

# --- 态 2：--diff 无变化 → quiet 静默 ---
out=$(bash "$SH" "$TMP/proj" --diff --quiet 2>&1); rc=$?
[[ $rc -eq 0 && -z "$out" ]] && ok "态2 无变化 quiet 静默" || bad "态2 exit=$rc out=[$out]"

# --- 态 3：加文件 → 有变化输出 ---
printf 'fn x() {}\n' > "$TMP/proj/src/e.rs"
out=$(bash "$SH" "$TMP/proj" --diff 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态3 有变化 exit 0" || bad "态3 exit=$rc"
echo "$out" | grep -q '⚠ 项目源码已变化' && ok "态3 变化警示行命中" || bad "态3 缺警示行: $out"
echo "$out" | grep -q '+ .rs 新增' && ok "态3 .rs 新增命中" || bad "态3 缺新增行: $out"
echo "$out" | grep -qE '文件数:.*3 → 4' && ok "态3 文件数 4→5 命中" || bad "态3 文件数不符: $out"

# --- 态 4：± 数量变化（加既有扩展名）---
rm "$TMP/proj/src/e.rs"
printf 'const y = 2\n' > "$TMP/proj/src/b2.ts"
# 重置基线
bash "$SH" "$TMP/proj" --write >/dev/null
printf 'const z = 3\n' > "$TMP/proj/src/b3.ts"
out=$(bash "$SH" "$TMP/proj" --diff 2>&1)
echo "$out" | grep -qE '± .ts：2 → 3' && ok "态4 ±.ts 2→3 命中" || bad "态4 缺±行: $out"

# --- 态 5：generate-skill.sh --refresh 无变化 → exit 0 ---
# 先 reset：清掉 b3.ts 让 proj 回到当前指纹基线
rm -f "$TMP/proj/src/b3.ts"
bash "$SH" "$TMP/proj" --write >/dev/null
mkdir -p "$TMP/skill5/references" "$TMP/skill5/scripts"
cat > "$TMP/skill5/SKILL.md" <<EOF2
---
name: t
description: t
status: draft
---
EOF2
cat > "$TMP/skill5/scripts/precheck.conf" <<EOF2
PROJECT_DIR="$TMP/proj"
EOF2
out=$(bash "$GEN" --refresh "$TMP/skill5" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态5 --refresh 无变化 exit 0" || bad "态5 exit=$rc: $out"
echo "$out" | grep -q '✓ 无变化' && ok "态5 无变化行命中" || bad "态5 缺无变化行: $out"

# --- 态 6：generate-skill.sh --refresh 有变化 → 提示 --upgrade ---
printf 'fn z() {}\n' > "$TMP/proj/src/f.rs"
out=$(bash "$GEN" --refresh "$TMP/skill5" 2>&1); rc=$?
[[ $rc -eq 0 ]] && ok "态6 --refresh 有变化 exit 0" || bad "态6 exit=$rc"
echo "$out" | grep -q '→ 检测到变化（建议跑 --upgrade）' && ok "态6 升级提示命中" || bad "态6 缺升级提示: $out"

# --- 态 7：--refresh --commit-fp 落新基线 → 再 --refresh 无变化 ---
out=$(bash "$GEN" --refresh "$TMP/skill5" --commit-fp 2>&1); rc=$?
echo "$out" | grep -q -- '--commit-fp' && ok "态7 commit-fp 行命中" || bad "态7 缺 commit-fp 行"
out2=$(bash "$GEN" --refresh "$TMP/skill5" 2>&1); rc=$?
echo "$out2" | grep -q '✓ 无变化' && ok "态7 commit 后无变化命中" || bad "态7 二次 refresh 仍有变化: $out2"

# --- 态 8：skill conf 缺 PROJECT_DIR → exit 1 ---
mkdir -p "$TMP/skill8/scripts"
cat > "$TMP/skill8/SKILL.md" <<EOF2
---
status: draft
---
EOF2
echo "" > "$TMP/skill8/scripts/precheck.conf"
out=$(bash "$GEN" --refresh "$TMP/skill8" 2>&1); rc=$?
[[ $rc -eq 1 ]] && ok "态8 缺 PROJECT_DIR exit 1" || bad "态8 exit=$rc"

# --- 态 9：元数据文件不纳入指纹（.swarm-yuan/.claude 排除） ---
mkdir -p "$TMP/proj/.swarm-yuan" "$TMP/proj/.claude"
printf 'junk\n' > "$TMP/proj/.swarm-yuan/decisions.jsonl"
printf 'junk\n' > "$TMP/proj/.claude/notes.md"
# 先重置基线（含 rs）
bash "$SH" "$TMP/proj" --write >/dev/null
out=$(bash "$SH" "$TMP/proj" --diff --quiet 2>&1); rc=$?
[[ -z "$out" ]] && ok "态9 元数据忽略 → 无变化静默" || bad "态9 元数据被算入: $out"

# --- 态 10：目录被排除（node_modules/.git） ---
mkdir -p "$TMP/proj/node_modules/xyz" "$TMP/proj/.git/objects"
printf 'junk\n' > "$TMP/proj/node_modules/xyz/pkg.js"
printf 'junk\n' > "$TMP/proj/.git/objects/ab"
bash "$SH" "$TMP/proj" --write >/dev/null
out=$(bash "$SH" "$TMP/proj" --diff --quiet 2>&1); rc=$?
[[ -z "$out" ]] && ok "态10 node_modules/.git 忽略" || bad "态10 未忽略: $out"

[[ $FAIL -eq 0 ]] && { echo "PASS test-project-fingerprint"; exit 0; } || { echo "FAIL test-project-fingerprint" >&2; exit 1; }

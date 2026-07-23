#!/usr/bin/env bash
# test-inventory-verify.sh — inventory-verify.sh 双态测试（WP-P2/M1）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/inventory-verify.sh"
TMP="$(mktemp -d /tmp/ivtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：后端项目，controller 维度枚举计数 == 清单计数 → PASS ---
mkdir -p "$TMP/proj/src" "$TMP/skill/references"
cat > "$TMP/proj/src/a.ts" <<'EOF'
router.get('/x', h1)
router.post('/y', h2)
EOF
cat > "$TMP/proj/src/b.ts" <<'EOF'
router.get('/z', h3)
EOF
# reference-manual.md §6 接口表：表头 1 行 + 3 数据行 = 3 个端点清单
cat > "$TMP/skill/references/reference-manual.md" <<'EOF'
# reference-manual
## §6 全量接口端点表
| 端点 | 方法 | 说明 |
|------|------|------|
| /x | GET | a |
| /y | POST | b |
| /z | GET | c |
EOF
out="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "后端态 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE '后端 controller	3	3	1\.00	PASS' && ok "controller 3/3 PASS" || bad "controller 核验异常: $out"

# --- 态 2：枚举计数 > 清单计数（漏列）→ FAIL + 比率 <0.95 ---
cat > "$TMP/proj/src/c.ts" <<'EOF'
router.get('/w', h4)
router.post('/v', h5)
EOF
out="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
echo "$out" | grep -qE '后端 controller	5	3	0\.60	FAIL' && ok "漏列 5/3 FAIL" || bad "漏列核验异常: $out"

# --- 态 3：维度错配 lint（声明 backend 却有 UI 组件文件）→ DIM_MISMATCH ---
mkdir -p "$TMP/proj2/src" "$TMP/skill2/references"
printf '<template><div/></template>\n' > "$TMP/proj2/src/x.vue"
printf 'router.get("/a", h)\n' > "$TMP/proj2/src/c.ts"
cat > "$TMP/skill2/references/reference-manual.md" <<'EOF'
# reference-manual
## §6 全量接口端点表
| 端点 | 方法 |
| /a | GET |
EOF
out="$(bash "$SH" "$TMP/proj2" --skill-dir "$TMP/skill2" --form backend 2>/dev/null)"
echo "$out" | grep -qF 'DIM_MISMATCH' && ok "backend+UI 文件 → DIM_MISMATCH" || bad "错配未检出: $out"

# --- 态 4：fail-open（无 reference-manual.md → exit 0 + 提示）---
mkdir -p "$TMP/proj3/src" "$TMP/skill3"
printf 'router.get("/a", h)\n' > "$TMP/proj3/src/c.ts"
out="$(bash "$SH" "$TMP/proj3" --skill-dir "$TMP/skill3" --form backend 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF 'reference-manual.md' && ok "无清单 fail-open" || bad "态4 异常 rc=$rc: $out"

# --- 态 5：确定性（同输入连跑两次 byte-identical 的 TSV 明细段）---
o1="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
o2="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次输出不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-inventory-verify"; exit 0; } || { echo "FAIL test-inventory-verify" >&2; exit 1; }

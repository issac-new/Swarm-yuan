#!/usr/bin/env bash
# test-inventory-verify.sh — inventory-verify.sh 双态测试（WP-P2/M1）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
ROOT="$(pwd)"
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

# --- 态 6：WP-Q1A --path-check：§4 表格登记路径在仓库中不存在 → HALLUCINATION ---
mkdir -p "$TMP/proj6/src" "$TMP/skill6/references" "$TMP/skill6/scripts"
printf 'router.get("/a", h)\n' > "$TMP/proj6/src/c.ts"
printf 'class OrderService:\n    pass\n' > "$TMP/proj6/src/order_svc.py"
cat > "$TMP/skill6/references/reference-manual.md" <<'EOF'
## §4 组件清单

| 业务名 | 路径 | 端点 | 说明 |
|--------|------|------|------|
| 订单服务 | `src/order_svc.py` | /api/orders | 真实存在 |
| 幽灵模块 | `src/ghost_module.py` | /api/ghost | 不存在（应被检出） |
EOF
echo "PROJECT_FORM=backend" > "$TMP/skill6/scripts/precheck.conf"
out="$(bash "$SH" "$TMP/proj6" --skill-dir "$TMP/skill6" --form backend --tsv --path-check 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "态6 exit 0（path-check 是 fail-open 输出，不阻断 exit）" || bad "态6 exit=$rc"
echo "$out" | grep -qF 'HALLUCINATION	清单登记路径不存在: src/ghost_module.py' && ok "态6 HALLUCINATION 行命中" || bad "态6 未检出 ghost_module.py"
# 真实存在路径不应出 HALLUCINATION
echo "$out" | grep -qF 'HALLUCINATION' && echo "$out" | grep -vF 'ghost_module.py' | grep -qF 'HALLUCINATION' && bad "态6 误伤真实路径" || ok "态6 仅幽灵路径被命中"

# --- 态 7：WP-Q1A --stability-audit：标注「禁止改」但近 90 天有 churn → STABILITY_WARN ---
mkdir -p "$TMP/proj7/src" "$TMP/skill7/references" "$TMP/skill7/scripts"
cd "$TMP/proj7" && git init -q 2>/dev/null && git add -A && git -c user.email=t@t -c user.name=t commit -qm "init" >/dev/null 2>&1 || true
printf 'def a(): pass\n' > "$TMP/proj7/src/payment.py"
cd "$TMP/proj7" && git add -A && git -c user.email=t@t -c user.name=t commit -qm "touch payment.py" 2>/dev/null
cd "$TMP/proj7" 2>/dev/null && printf 'def b(): pass\n' >> src/payment.py && git add -A && git -c user.email=t@t -c user.name=t commit -qm "touch payment.py again" 2>/dev/null
cd "$ROOT" || exit 1
cat > "$TMP/skill7/references/reference-manual.md" <<'EOF'
## §4 组件清单

| 业务名 | 路径 | 说明 |
|--------|------|------|
| 支付服务 | `src/payment.py` | 支付（禁止改） |
EOF
echo "PROJECT_FORM=backend" > "$TMP/skill7/scripts/precheck.conf"
out="$(bash "$SH" "$TMP/proj7" --skill-dir "$TMP/skill7" --form backend --tsv --stability-audit 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "态7 exit 0（stability-audit 是 advisory，永不 fail）" || bad "态7 exit=$rc"
echo "$out" | grep -qE 'STABILITY_WARN.*src/payment.py.*禁止改但近 90 天变更' && ok "态7 STABILITY_WARN 命中（禁止改 vs churn）" || bad "态7 未检出 STABILITY_WARN"

# --- 态 8：WP-Q1A --stability-audit：标注「稳定」但 fan-in=0 → STABILITY_WARN ---
mkdir -p "$TMP/proj8/src" "$TMP/skill8/references" "$TMP/skill8/scripts"
printf 'def x(): pass\n' > "$TMP/proj8/src/standalone.py"
cd "$TMP/proj8" && git init -q 2>/dev/null && git add -A && git -c user.email=t@t -c user.name=t commit -qm "init" >/dev/null 2>&1
cd "$ROOT" || exit 1
cat > "$TMP/skill8/references/reference-manual.md" <<'EOF'
## §4 组件清单

| 业务名 | 路径 | 说明 |
|--------|------|------|
| 单例组件 | `src/standalone.py` | 独立模块【稳定】 |
EOF
echo "PROJECT_FORM=backend" > "$TMP/skill8/scripts/precheck.conf"
out="$(bash "$SH" "$TMP/proj8" --skill-dir "$TMP/skill8" --form backend --tsv --stability-audit 2>/dev/null)"; rc=$?
echo "$out" | grep -qE 'STABILITY_WARN.*src/standalone.py.*fan-in=0' && ok "态8 STABILITY_WARN 命中（稳定 vs fan-in=0）" || bad "态8 未检出 STABILITY_WARN: $out"

# --- 态 9：WP-Q1A §10/§11 等非 §4/§6/§9 段不应被抽到（避免错纳）---
mkdir -p "$TMP/proj9/src" "$TMP/skill9/references" "$TMP/skill9/scripts"
printf 'def y(): pass\n' > "$TMP/proj9/src/in_ten.py"
cd "$TMP/proj9" && git init -q 2>/dev/null && git add -A && git -c user.email=t@t -c user.name=t commit -qm "init" >/dev/null 2>&1
cd "$ROOT" || exit 1
cat > "$TMP/skill9/references/reference-manual.md" <<'EOF'
## §4 组件清单

| 业务名 | 路径 | 说明 |
|--------|------|------|
| A | `src/in_ten.py` | 应被抽 |

## §10 多余节

| 业务名 | 路径 | 说明 |
|--------|------|------|
| Z | `src/in_ten.py` | §10 应忽略 |
EOF
echo "PROJECT_FORM=backend" > "$TMP/skill9/scripts/precheck.conf"
out="$(bash "$SH" "$TMP/proj9" --skill-dir "$TMP/skill9" --form backend --tsv --path-check --stability-audit 2>/dev/null)"
# §10 行不应产生 STABILITY_WARN（因为根本不应被抽出）
echo "$out" | grep -qE 'STABILITY_WARN.*src/in_ten.py.*fan-in' && bad "态9 §10 被错误纳入" || ok "态9 §10 排除正确"
# §4 行存在 + 真实路径 → 无 HALLUCINATION
echo "$out" | grep -qF 'HALLUCINATION' && bad "态9 真实路径误报 HALLUCINATION" || ok "态9 真实路径通过"

[[ $FAIL -eq 0 ]] && { echo "PASS test-inventory-verify"; exit 0; } || { echo "FAIL test-inventory-verify" >&2; exit 1; }

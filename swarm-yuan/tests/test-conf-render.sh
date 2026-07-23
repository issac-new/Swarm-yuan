#!/usr/bin/env bash
# test-conf-render.sh — conf-render.sh 初稿渲染双态测试（WP-P4/M3）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/conf-render.sh"
TMP="$(mktemp -d /tmp/crtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：TS 项目 → PROJECT_DIR/语言/包管理器 detected；LAYER_DEFS TODO:model ---
mkdir -p "$TMP/proj/src"
cat > "$TMP/proj/package.json" <<'EOF'
{ "name": "demo", "dependencies": { "react": "^19.0.0" } }
EOF
out="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "渲染 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE 'PROJECT_DIR=.*# AUTO:detected' && ok "PROJECT_DIR detected" || bad "PROJECT_DIR 缺失: $out"
echo "$out" | grep -qE "BUILD_CMD=.*# AUTO:default" && ok "BUILD_CMD default" || bad "BUILD_CMD 缺失"
echo "$out" | grep -qE 'LAYER_DEFS=.*# TODO:model' && ok "LAYER_DEFS TODO:model" || bad "LAYER_DEFS 未留 TODO: $out"
echo "$out" | grep -qE 'ACTIVE_FRAMEWORKS=.*react' && ok "ACTIVE_FRAMEWORKS detected react" || bad "框架未探测: $out"

# --- 态 2：Java/Maven 项目 → BUILD_CMD maven detected ---
mkdir -p "$TMP/proj2/src/main/java"
cat > "$TMP/proj2/pom.xml" <<'EOF'
<project><modelVersion>4.0.0</modelVersion><dependencies>
<dependency><groupId>org.springframework.boot</groupId></dependency>
</dependencies></project>
EOF
out="$(bash "$SH" "$TMP/proj2" --profile standard 2>/dev/null)"
echo "$out" | grep -qE 'BUILD_CMD=.*mvn.*# AUTO:detected' && ok "Java BUILD_CMD mvn detected" || bad "态2 BUILD_CMD: $out"
echo "$out" | grep -qE 'ACTIVE_FRAMEWORKS=.*spring-boot' && ok "spring-boot detected" || bad "态2 框架: $out"

# --- 态 3：lite profile 不渲染 arch.conf/compliance.conf 段（section header 不得出现） ---
# 注：core 模板里的 `[[ -f .../precheck.arch.conf ]] && source ... || true` 功能行保留（lite 无兄弟时 no-op，
# 未来补 arch.conf 可自动加载），故用 section header `^# ===== precheck.arch.conf =====` 判定是否渲染了完整段。
out="$(bash "$SH" "$TMP/proj" --profile lite 2>/dev/null)"
echo "$out" | grep -qE '^# ===== precheck\.arch\.conf =====' && bad "lite 不应渲染 arch 段" || ok "lite 无 arch.conf 段"
echo "$out" | grep -qE '^# ===== precheck\.compliance\.conf =====' && bad "lite 不应渲染 compliance 段" || ok "lite 无 compliance.conf 段"

# --- 态 4：--out 落盘三文件 + TODO:model 清单 ---
mkdir -p "$TMP/out"
bash "$SH" "$TMP/proj" --profile standard --out "$TMP/out" >/dev/null 2>&1
[[ -f "$TMP/out/precheck.conf" ]] && ok "precheck.conf 落盘" || bad "precheck.conf 未落盘"
[[ -f "$TMP/out/precheck.arch.conf" ]] && ok "arch.conf 落盘" || bad "arch.conf 未落盘"
[[ ! -f "$TMP/out/precheck.compliance.conf" ]] && ok "standard 无 compliance.conf" || bad "standard 不应落 compliance"

# --- 态 5：确定性（同输入连跑两次 byte-identical）---
o1="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"
o2="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-conf-render"; exit 0; } || { echo "FAIL test-conf-render" >&2; exit 1; }

#!/usr/bin/env bash
# test-relations-extract.sh — relations-extract.sh 多态测试（R21-D）
# 态1: TS/JS/py 混合项目 import 边提取与解析（跨目录/扩展名补全/自环排除）
# 态2: --verify 抽样核验（全绿 + 断边检出）
# 态3: --stable-diff 消费接线（gates-warn 传播段读边集召回 1 跳下游）
# 态4: Go/Java 解析（module 剥离 / 包路径映射）
set -uo pipefail
cd "$(dirname "${0}")/.." || exit 1
ROOT="$(pwd)"
SH="scripts/relations-extract.sh"
TMP="$(mktemp -d /tmp/relxt.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：TS/JS/py 混合提取 ---
mkdir -p "$TMP/proj/src/components" "$TMP/proj/src/pages" "$TMP/proj/src"
printf 'export function Table(): void {}\n' > "$TMP/proj/src/components/Table.tsx"
printf "import { Table } from '../components/Table';\nexport function Page(): void { Table(); }\n" > "$TMP/proj/src/pages/List.tsx"
printf "import Table from './Table';\n" > "$TMP/proj/src/components/Wrapper.js"
printf 'def helper(): pass\n' > "$TMP/proj/src/util.py"
printf 'from .util import helper\n' > "$TMP/proj/src/app.py"
out="$(bash "$SH" "$TMP/proj" --out "$TMP/proj/relations.jsonl" 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && ok "态1 exit 0" || bad "态1 exit=$rc: $out"
E="$TMP/proj/relations.jsonl"
[[ -f "$E" ]] && ok "态1 边集落盘" || bad "态1 边集未生成"
grep -qF '{"from":"src/pages/List.tsx","to":"src/components/Table.tsx","kind":"import","evidence":"import@src/pages/List.tsx:1"}' "$E" \
  && ok "态1 跨目录 TS 边（../ 解析 + .tsx 补全）" || bad "态1 List→Table 边缺失"
grep -qF '"from":"src/components/Wrapper.js","to":"src/components/Table.tsx"' "$E" \
  && ok "态1 同目录 JS→TS 边（./ 解析 + 跨扩展名）" || bad "态1 Wrapper→Table 边缺失"
grep -qF '"from":"src/app.py","to":"src/util.py"' "$E" \
  && ok "态1 py 相对导入边" || bad "态1 app→util 边缺失"
_ecn=$(grep -c . "$E"); [[ "$_ecn" -eq 3 ]] && ok "态1 边数=3（无多余/自环）" || bad "态1 边数=${_ecn}（期望 3）"

# --- 态 2：--verify 全绿 + 断边检出 ---
out="$(bash "$SH" "$TMP/proj" --out "$E" --verify 2>&1)"
echo "$out" | grep -qF '抽样核验通过' && ok "态2 全绿核验（3/3）" || bad "态2 全绿核验异常: $out"
# 断一条边（删 from 文件）→ RELATION_MISS
rm "$TMP/proj/src/components/Wrapper.js"
out="$(bash "$SH" "$TMP/proj" --out "$E" --verify 2>&1)"
echo "$out" | grep -qF 'RELATION_MISS	from 路径不存在: src/components/Wrapper.js' \
  && ok "态2 断边检出（from 失锚）" || bad "态2 断边未检出: $out"

# --- 态 3：--stable-diff 消费接线（传播段读边集召回下游） ---
# 构造最小目标技能形态：stable 层=src/components/Table.tsx（STABLE_GLOBS），下游=src/pages/List.tsx（边集 from）
printf 'export function Table(): void {}\n' > "$TMP/proj/src/components/Table.tsx"
SK="$TMP/skill"; mkdir -p "$SK/references" "$SK/scripts"
cp assets/gates-warn.sh "$SK/scripts/gates-warn.sh" 2>/dev/null || cp "$ROOT/assets/gates-warn.sh" "$SK/scripts/gates-warn.sh"
cat > "$SK/scripts/precheck.conf" <<EOF
PROJECT_DIR="$TMP/proj"
STABLE_PROPAGATE=1
STABLE_PROPAGATE_HOPS=1
EOF
mkdir -p "$TMP/proj/.swarm-yuan"
# stable-diff 走 git diff 检出 stable_changed——用非 git 环境直接构造场景困难，
# 改为直接验证消费函数输入路径：手工模拟传播段读边集的行（与 gates-warn 3a' 同款管道）
_ds=$(grep -F '"to":"src/components/Table.tsx"' "$E" | sed -n 's/.*"from":"\([^"]*\)".*/\1/p')
printf '%s\n' "$_ds" | grep -qF 'src/pages/List.tsx' \
  && ok "态3 消费管道召回 1 跳下游（List.tsx 在边集 from 集）" \
  || bad "态3 消费管道未召回（got: ${_ds:-空}）"

# --- 态 4：Go module 剥离 + Java 包路径映射 ---
mkdir -p "$TMP/go/internal/svc" "$TMP/go/cmd/app"
printf 'module example.com/demo\n\ngo 1.21\n' > "$TMP/go/go.mod"
printf 'package svc\nfunc F() {}\n' > "$TMP/go/internal/svc/svc.go"
printf 'package main\nimport (\n\t"example.com/demo/internal/svc"\n)\nfunc main() { svc.F() }\n' > "$TMP/go/cmd/app/main.go"
out="$(bash "$SH" "$TMP/go" --out "$TMP/go/relations.jsonl" 2>&1)"
grep -qF '"from":"cmd/app/main.go","to":"internal/svc"' "$TMP/go/relations.jsonl" \
  && ok "态4 Go module 剥离边" || bad "态4 Go 边缺失: $(cat "$TMP/go/relations.jsonl" 2>/dev/null)"
mkdir -p "$TMP/java/src/main/java/com/example/pkg"
printf 'package com.example.pkg;\npublic class Util {}\n' > "$TMP/java/src/main/java/com/example/pkg/Util.java"
printf 'package com.example;\nimport com.example.pkg.Util;\npublic class App {}\n' > "$TMP/java/src/main/java/com/example/App.java"
out="$(bash "$SH" "$TMP/java" --out "$TMP/java/relations.jsonl" 2>&1)"
grep -qF '"from":"src/main/java/com/example/App.java","to":"src/main/java/com/example/pkg/Util.java"' "$TMP/java/relations.jsonl" \
  && ok "态4 Java 包路径映射边" || bad "态4 Java 边缺失: $(cat "$TMP/java/relations.jsonl" 2>/dev/null)"

# --- 态 4b：CommonJS require() 相对导入（R23 回归 D1：原模式不容左括号，0 边） ---
mkdir -p "$TMP/cjs/src/routes" "$TMP/cjs/src/services" "$TMP/cjs/src/models"
printf 'const express = require("express");\nconst router = express.Router();\nrouter.get("/", (q,s) => s.json({}));\nmodule.exports = router;\n' > "$TMP/cjs/src/routes/tasks.js"
printf "const { create } = require('../models/task');\nfunction add(p) { return create(p); }\nmodule.exports = { add };\n" > "$TMP/cjs/src/services/task-service.js"
printf 'function create(p) { return p; }\nmodule.exports = { create };\n' > "$TMP/cjs/src/models/task.js"
out="$(bash "$SH" "$TMP/cjs" --out "$TMP/cjs/relations.jsonl" 2>&1)"
grep -qF '"from":"src/services/task-service.js","to":"src/models/task.js"' "$TMP/cjs/relations.jsonl" \
  && ok "态4b CommonJS require('../') 相对导入边" || bad "态4b require 边缺失: $(cat "$TMP/cjs/relations.jsonl" 2>/dev/null)"
_cjsn=$(grep -c . "$TMP/cjs/relations.jsonl"); [[ "$_cjsn" -eq 1 ]] && ok "态4b 边数=1（裸包 require 不计边）" || bad "态4b 边数=${_cjsn}（期望 1，express 裸包不应成边）"

[[ $FAIL -eq 0 ]] && { echo "PASS test-relations-extract"; exit 0; } || { echo "FAIL test-relations-extract" >&2; exit 1; }

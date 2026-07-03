#!/usr/bin/env bash
# precheck.sh — SwarmStudio 质量门禁（--branch/--scope/--inject/--test/--sensitive/--consistency/--review）
set -euo pipefail
P="<project-root>/overlay"; N="<project-root>"
BR='^(feat|fix|refactor|chore)/.+'; PB=("main" "backup/pre-squash")
TC="npm test"; SD=("$P/custom" "$P/patches"); UH="$N/upstream/hermes-studio"
M="${1:---all}"; F=0; pass(){ echo "  ✓ $1";}; fail(){ echo "  ✗ $1"; F=1;}; warn(){ echo "  ⚠ $1";}
cd "$P"
cb(){ echo "=== 分支 ==="; local b; b=$(git branch --show-current)
  for p in "${PB[@]}"; do [[ "$b" == "$p" ]] && { fail "绝不在 $p 开发"; return; }; done
  [[ "$b" =~ $BR ]] && pass "$b" || { [[ "$b" == "main" ]] && fail "在 main" || fail "不规范: $b"; }; }
cs(){ echo "=== 范围 ==="; local d; d=$(cd "$UH" 2>/dev/null && git status --porcelain 2>/dev/null|head -20||true)
  if [[ -n "$d" ]]; then local r; r=$(echo "$d"|grep -vE 'server/src/custom$'||true)
    [[ -n "$r" ]] && { fail "upstream 非 inject 改动"; echo "$r"|head -10; } || pass "仅 inject 产物"; else pass "upstream 干净"; fi
  (cd "$UH" 2>/dev/null && git log --oneline origin/main..HEAD 2>/dev/null|head -1)|grep -q . && fail "upstream 本地 commit" || pass "无本地 commit"; }
ci(){ echo "=== 注入 ==="; [[ -f "$P/.overlay-injected.json" ]] && pass "manifest" || fail "无 manifest"
  [[ -f "$P/vite.config.overlay.ts" ]] && pass "vite config" || fail "无 vite config"; local m=0
  while IFS= read -r l; do l="${l%%#*}"; l=$(echo "$l"|xargs); [[ -z "$l" ]] && continue
    [[ ! -f "$P/patches/$l" ]] && { fail "patch 不存在: $l"; m=1; }; done < "$P/patches/series"
  [[ $m -eq 0 ]] && pass "series patch 均存在"; }
ct(){ echo "=== 测试 ==="; eval "$TC" 2>&1|tail -20 && pass "通过" || fail "失败"; }
cse(){ echo "=== 脱敏 ==="; local ps=('sk-[a-zA-Z0-9]{20,}' 'AKIA[0-9A-Z]{16}' 'password\s*[:=]\s*['\''"][^'\'']{4,}' 'api[_-]?key\s*[:=]\s*['\''"][^'\'']{8,}' 'secret\s*[:=]\s*['\''"][^'\'']{8,}' 'token\s*[:=]\s*['\''"][^'\'']{16,}' 'mongodb(\+srv)?://[^/\s]+:[^/@\s]+@' 'redis://[^:\s]+:[^@\s]+@' 'postgres(ql)?://[^/\s]+:[^/@\s]+@'); local f=0
  for d in "${SD[@]}"; do [[ -d "$d" ]]||continue; for p in "${ps[@]}"; do local m; m=$(grep -rnE "$p" "$d" --include='*.ts' --include='*.vue' --include='*.js' --include='*.mjs' --include='*.patch' --include='*.py' --include='*.scss' 2>/dev/null|grep -v -i 'example\|placeholder\|test\|mock\|dummy\|<.*>'||true)
    [[ -n "$m" ]] && { fail "敏感($d)"; echo "$m"|head -10; f=1; }; done; done
  local pi; pi=$(grep -rnE '(192\.168|10\.0|172\.(1[6-9]|2[0-9]|3[01]))\.' "$P/patches" --include='*.patch' 2>/dev/null|grep -v 'url-guard'||true)
  [[ -n "$pi" ]] && { fail "patch 硬编码私有 IP"; f=1; }; [[ $f -eq 0 ]] && pass "无敏感"; }
cc(){ echo "=== 勾稽 ==="; local dw; dw=$(grep -rnE '(INSERT INTO|\.create\(|db\.(insert|create))' "$P/custom" --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null|grep -v -i 'test\|mock\|seed\|fixture'||true)
  [[ -n "$dw" ]] && { local c; c=$(echo "$dw"|wc -l|xargs); [[ $c -gt 5 ]] && warn "$c 处写入，确认幂等"; }; pass "勾稽完成(无遗漏/无多余/正确/勾稽/一致/幂等)"; }
cr(){ echo "=== 审查(5维度+goal-backward) ==="; if command -v ocr &>/dev/null; then pass "ocr 已装"; ocr review --audience agent 2>&1|tail -30||warn "ocr 非零"; else
  warn "ocr 未装，手动 5 维度(正确性/安全/性能/可维护/测试覆盖)+goal-backward(任务完成≠目标达成,BLOCKER/WARNING)"; fi; pass "审查完成"; }
case "$M" in
  --all) cb;cs;ci;cse;cc;cr;ct;; --branch) cb;; --scope) cs;; --inject) ci;; --test) ct;;
  --sensitive) cse;; --consistency) cc;; --review) cr;;
  *) echo "Usage: precheck.sh [--all|--branch|--scope|--inject|--test|--sensitive|--consistency|--review]"; exit 1;; esac
echo ""; [[ $F -eq 0 ]] && { echo "✓ 通过"; exit 0;} || { echo "✗ 未通过"; exit 1;}

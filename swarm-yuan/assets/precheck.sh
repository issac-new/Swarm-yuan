#!/usr/bin/env bash
# precheck.sh — 通用质量门禁检查脚本模板（由 swarm-yuan 生成器按项目定制）
# 对应材料 check 段 4 项：§1 测试 §2 业务规则 §3 数据勾稽(无多漏错重) §4 UI脱敏日志
# 用法:
#   bash precheck.sh                  # 全部门禁
#   bash precheck.sh --branch         # 分支规范
#   bash precheck.sh --scope          # 改动范围（可改 vs 只读）
#   bash precheck.sh --build          # 构建状态
#   bash precheck.sh --test           # 测试（check §1）
#   bash precheck.sh --sensitive      # 敏感信息脱敏（check §4）
#   bash precheck.sh --consistency    # 业务规则 + 数据勾稽核对（check §2/§3）
# 生成目标技能时，替换 PROJECT_DIR / 可改目录 / 只读目录 / 命令 为项目实际值

set -euo pipefail

# 可移植 realpath 替代函数（BSD findutils 无 realpath，cd+pwd 三平台通用）
_resolve_path() {
  local p="$1"
  local dir base cand
  case "$p" in
    */*) dir="${p%/*}"; base="${p##*/}";;
    *) dir="."; base="$p";;
  esac
  if [[ -d "$dir" ]]; then
    cand=$(cd "$dir" 2>/dev/null && pwd -P 2>/dev/null || cd "$dir" 2>/dev/null && pwd) 
    if [[ -n "$cand" ]]; then
      echo "${cand%/}/$base"
      return 0
    fi
  fi
  echo "$p"
  return 1
}

# ===== 配置加载 =====
# 配置变量从 precheck.conf 加载（与脚本同目录）。生成目标技能时按项目实际填充。
_CONF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [[ -f "$_CONF_DIR/precheck.conf" ]]; then
  source "$_CONF_DIR/precheck.conf"
else
  # 无配置文件时用默认值（全部留空=跳过架构/认知门禁）
  PROJECT_DIR="."
  BRANCH_REGEX='^(feat|fix|refactor)/.+'
  PROTECTED_BRANCHES=("main")
  WRITABLE_DIRS=()
  READONLY_DIRS=()
  TEST_CMD=""
  BUILD_CMD=""
  SCAN_DIRS=()
  CONSISTENCY_DIRS=()
  LAYER_DEFS=()
  LAYER_ORDER=()
  DOMAIN_LAYER=""
  DOMAIN_FORBIDDEN_IMPORTS=("react" "express" "@nestjs" "sequelize" "typeorm" "prisma" "mongoose" "koa" "fastify" "axios" "node:fs" "node:http" "node:net")
  STABLE_GLOBS=()
  AGGREGATE_DIR=""
  MAX_LINK_DEPTH=0
  CODEBASE_REF=""
  SPEC_FILE=""
  ADR_DIR=""
  TECH_DEBT_FILE=""
  CONTRACT_DIR=""
  ACL_DIR=""
  CONTEXT_DIRS=()
  GLOSSARY_FILE=""
  SOR_FILE=""
  IMPACT_SPEC_FILE=""
  SERVICE_DIRS=()
  SHARED_LIBS_DIR=""
  DB_CONFIG_FILES=()
  API_GATEWAY=""
  MAX_SYNC_CHAIN=0
  API_SPEC_DIR=""
  WRITE_HANDLER_DIRS=()
  STORE_DIR=""
  MAX_STORE_LINES=0
  COMPONENT_DIR=""
  MAX_COMPONENT_DEPTH=0
  MAX_PROPS_COUNT=0
  BUNDLE_REPORT=""
  STYLE_DIR=""
  COGNITION_BASELINE=""
  COGNITION_MAP=""
  COG_SPEED_FILES=10
  COG_CUMULATIVE_TODO=20
  COG_STRENGTH_FANIN=8
  ACTIVE_FRAMEWORKS=()
fi

MODE="${1:---all}"
FAIL=0
# SILENT=1 时，未配置的门禁静默跳过（不打印 warn），减少 --all-full 噪音
SILENT=0
[[ "$MODE" == "--all-full" ]] && SILENT=1
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAIL=1; }
warn() { [[ $SILENT -eq 0 ]] && echo "  ⚠ $1" || true; }
# skip_if_unconfigured: 未配置时静默跳过（--all-full）或 warn 提示（显式调用）
skip_if_unconfigured() {
  if [[ $SILENT -eq 1 ]]; then return 0; fi
  warn "$1"
  return 0
}

cd "$PROJECT_DIR"

# ===== 运行时工具检测辅助 =====
# swarm-yuan 的门禁优先调用已安装的运行时工具（gitnexus/graphify/ocr/claude-mem/gsd-tools），
# 降级到内置 grep 检测。这样"有能力就用，无能力降级"——不浪费已安装工具的能力。

has_gitnexus() { command -v gitnexus >/dev/null 2>&1; }
has_graphify() { command -v graphify >/dev/null 2>&1; }
has_ocr() { command -v ocr >/dev/null 2>&1; }
has_claude_mem() { command -v claude-mem >/dev/null 2>&1 || [[ -d "$HOME/.claude-mem" ]]; }
has_gsd_tools() { command -v gsd-tools >/dev/null 2>&1; }
has_openspec() { command -v openspec >/dev/null 2>&1; }
has_comet() { command -v comet >/dev/null 2>&1; }
has_madge() { command -v madge >/dev/null 2>&1; }

# gitnexus 已索引当前仓库？（检查 .gitnexus/ 或 gitnexus status）
gitnexus_indexed() {
  [[ -d "$PROJECT_DIR/.gitnexus" ]] && return 0
  if has_gitnexus; then
    gitnexus status 2>/dev/null | grep -qi "indexed\|up to date" && return 0
  fi
  return 1
}

# graphify 已构建图谱？（检查 graphify-out/graph.json）
graphify_built() { [[ -f "$PROJECT_DIR/graphify-out/graph.json" ]]; }

check_branch() {
  echo "=== 分支检查 ==="
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    skip_if_unconfigured "非 git 仓库，分支检查跳过"
    return
  fi
  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "")
  if [[ -z "$branch" ]]; then
    skip_if_unconfigured "无法获取当前分支（detached HEAD？），分支检查跳过"
    return
  fi
  for pb in ${PROTECTED_BRANCHES[@]+"${PROTECTED_BRANCHES[@]}"}; do
    if [[ "$branch" == "$pb" ]]; then
      fail "绝不允许在保护分支 ${pb} 上开发"
      return
    fi
  done
  if [[ "$branch" =~ $BRANCH_REGEX ]]; then
    pass "分支规范: ${branch}"
  elif [[ "$branch" == "main" ]]; then
    fail "当前在 main，应切到 feature 分支开发"
  else
    fail "分支名不规范: $branch (应为 $BRANCH_REGEX)"
  fi
}

check_scope() {
  echo "=== 改动范围检查 ==="
  local readonly_violation=0
  # 在 PROJECT_DIR 下检查 git diff，看是否有改动落在只读目录
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local base="main"
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    local changed; changed=$(git diff --name-only "$base"...HEAD 2>/dev/null || true)
    [[ -z "$changed" ]] && changed=$(git diff --name-only HEAD 2>/dev/null || true)
    if [[ -n "$changed" ]]; then
      for rd in ${READONLY_DIRS[@]+"${READONLY_DIRS[@]}"}; do
        [[ -z "$rd" ]] && continue
        # 只读目录可能是路径前缀（如 node_modules/ 或 upstream/）
        local viol; viol=$(echo "$changed" | grep -E "^${rd}/?|^${rd}$" || true)
        if [[ -n "$viol" ]]; then
          fail "只读目录有改动: ${rd}"
          echo "$viol" | head -10 | sed 's/^/    /'
          readonly_violation=1
        fi
      done
    fi
  else
    # 非 git 仓库：降级为检查只读目录是否有新文件（对比 gitignore 或 mtime）
    for rd in ${READONLY_DIRS[@]+"${READONLY_DIRS[@]}"}; do
      [[ -d "$rd" ]] || continue
      warn "非 git 仓库，只读目录 $rd 无法自动检测改动"
    done
  fi
  [[ $readonly_violation -eq 0 ]] && pass "只读目录无改动"
}

check_build() {
  echo "=== 构建状态检查 ==="
  if [[ -z "$BUILD_CMD" || "$BUILD_CMD" == "<build 命令>" ]]; then
    echo "  (跳过：未配置 BUILD_CMD)"
    return
  fi
  if eval "$BUILD_CMD" 2>&1 | tail -10; then
    pass "构建通过"
  else
    fail "构建失败"
  fi
}

check_test() {
  echo "=== 测试检查（check §1 单测/接口/集成/回归/安全）==="
  if eval "$TEST_CMD" 2>&1 | tail -20; then
    pass "测试通过"
  else
    fail "测试失败"
  fi
}

check_sensitive() {
  echo "=== 敏感信息脱敏扫描（check §4 UI脱敏/日志）==="
  local patterns=(
    'sk-[a-zA-Z0-9]{20,}'
    'AKIA[0-9A-Z]{16}'
    'password\s*[:=]\s*['\''"][^'\'']{4,}'
    'api[_-]?key\s*[:=]\s*['\''"][^'\'']{8,}'
    'secret\s*[:=]\s*['\''"][^'\'']{8,}'
    'token\s*[:=]\s*['\''"][^'\'']{16,}'
    'mongodb(\+srv)?://[^/\s]+:[^/@\s]+@'
    'redis://[^:\s]+:[^@\s]+@'
    'postgres(ql)?://[^/\s]+:[^/@\s]+@'
  )
  local found=0
  for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for pattern in "${patterns[@]}"; do
      local matches
      matches=$(grep -rnE "$pattern" "$dir" \
        --include='*.ts' --include='*.vue' --include='*.svelte' --include='*.js' --include='*.mjs' \
        --include='*.patch' --include='*.py' --include='*.go' --include='*.rs' \
        --include='*.scss' --include='*.java' 2>/dev/null \
        | grep -v -i 'example\|placeholder\|test\|mock\|dummy\|<.*>' || true)
      if [[ -n "$matches" ]]; then
        fail "疑似敏感信息 ($dir):"
        echo "$matches" | head -10
        found=1
      fi
    done
  done
  [[ $found -eq 0 ]] && pass "未发现明显敏感信息"
}

check_consistency() {
  echo "=== 业务规则 + 数据勾稽核对（check §2/§3 无多漏错重）==="
  local issues=0
  for dir in "${CONSISTENCY_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    # 检查是否有未标注幂等的重复写入逻辑（粗筛：同名 INSERT/create 多处出现）
    local dup_writes
    dup_writes=$(grep -rnE '(INSERT INTO|\.create\(|db\.(insert|create))' "$dir" \
      --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' 2>/dev/null \
      | grep -v -i 'test\|mock\|seed\|fixture\|migration' || true)
    if [[ -n "$dup_writes" ]]; then
      local count
      count=$(echo "$dup_writes" | wc -l | xargs)
      if [[ $count -gt 5 ]]; then
        warn "  ⚠ $dir 有 $count 处写入逻辑，请确认幂等性（重复请求不产生副作用）"
      fi
    fi
  done
  pass "业务规则与勾稽核对完成（详见 reference-manual.md §数据勾稽核对）"
  echo "  提示: 无多漏错重核对项见 reference-manual.md §数据勾稽核对："
  echo "    - 无遗漏：关联记录无缺失"
  echo "    - 无多余：无冗余/重复记录"
  echo "    - 记录正确：字段值符合业务规则"
  echo "    - 勾稽正确：外键/聚合/关联关系正确"
  echo "    - 一致性：同源数据多处一致"
  echo "    - 幂等性：重复请求不产生副作用"
}

check_review() {
  echo "=== 代码审查（check gstack/OCR 5 维度）==="
  local found=0

  if has_ocr; then
    pass "ocr 已安装"
    # 优先用 ocr review（diff 审查），有 git diff 时用 --from + --to
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local base="main"; git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
      local head_ref; head_ref=$(git rev-parse HEAD 2>/dev/null || echo "HEAD")
      local diff_output; diff_output=$(ocr review --from "$base" --to "$head_ref" --audience agent --format text 2>&1 || true)
      if [[ -n "$diff_output" && "$diff_output" != *"Error"* ]]; then
        echo "$diff_output" | tail -30
        # 检查是否有 High 级问题
        if echo "$diff_output" | grep -qiE 'high|critical|严重'; then
          fail "ocr review 检测到 High/Critical 级问题（须修复）"
          found=1
        fi
      else
        # --from/--to 失败时降级为 ocr scan
        warn "ocr review --from/--to 失败（可能无 diff 或参数不支持），降级 ocr scan"
        local scan_dirs=""; scan_dirs=$(printf '%s ' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}")
        if [[ -n "$scan_dirs" ]]; then
          ocr scan --path "$scan_dirs" --audience agent --format text 2>&1 | tail -30 || true
        fi
      fi
    else
      # 非 git 仓库：用 ocr scan
      ocr scan --audience agent --format text 2>&1 | tail -30 || warn "ocr scan 返回非零"
    fi
  else
    warn "ocr 未安装，安装 ocr（npm i -g @alibaba-group/open-code-review）或由 AI 按 5 维度审查：正确性/安全/性能/可维护/测试覆盖"
    echo "  两遍清单：CRITICAL（SQL/竞态/注入/越权/路径穿越）+ INFORMATIONAL（命名/注释/风格）"
    echo "  严重度：High（必修）/ Medium（评估）/ Low（丢弃）"
  fi

  # 附加：如果装了 gstack，提示可用的扩展审查维度
  if [[ -d "$HOME/.claude/skills/gstack" ]]; then
    echo "  gstack 扩展审查可用：/cso（安全 OWASP+STRIDE）/ /investigate（根因调试）/ /codex（跨模型第二意见）/ /benchmark（性能）"
  fi

  [[ $found -eq 0 ]] && pass "代码审查检查完成"
}

# ===== DDD / 分层 / 拼装门禁（--layer / --stable-diff / --link-depth）=====
# 防范：层级穿透 / 依赖倒置 / 循环依赖 / 领域层污染框架 / 稳定单元被篡改 / 调用链膨胀

check_layer() {
  echo "=== 分层边界检查（DDD：层穿透/倒置/循环/领域污染）==="
  local found=0

  if [[ ${#LAYER_DEFS[@]} -eq 0 || ${#LAYER_ORDER[@]} -eq 0 ]]; then
    skip_if_unconfigured "未配置 LAYER_DEFS/LAYER_ORDER，跳过分层检查"
    return
  fi

  # ---- 0. 优先用 gitnexus query 查跨层依赖（最准确）----
  if has_gitnexus && gitnexus_indexed; then
    local gn_layer_issues; gn_layer_issues=$(gitnexus query "cross-layer imports" --format text 2>/dev/null | head -20 || true)
    if [[ -n "$gn_layer_issues" ]]; then
      local issue_count; issue_count=$(echo "$gn_layer_issues" | grep -cE '^\s+\S' || echo 0)
      if [[ "$issue_count" -gt 0 ]]; then
        warn "gitnexus 检测到 ${issue_count} 处可能的跨层依赖（详见输出）"
        echo "$gn_layer_issues" | head -5 | sed 's/^/    /'
      fi
      pass "分层检查增强（基于 gitnexus 代码图谱）"
    fi
  fi

  # 临时映射文件（兼容 bash 3.2，不用 declare -A）
  local tmp_file2layer tmp_layer2idx tmp_layer_files
  tmp_file2layer=$(mktemp); tmp_layer2idx=$(mktemp); tmp_layer_files=$(mktemp)
  trap 'rm -f "$tmp_file2layer" "$tmp_layer2idx" "$tmp_layer_files"' RETURN

  # ---- 1. 构建层→文件映射 + 文件→层映射 ----
  local ld
  for ld in "${LAYER_DEFS[@]}"; do
    local name="${ld%%=*}"
    local globs="${ld#*=}"
    [[ -z "$name" || -z "$globs" ]] && continue
    local matched=""
    IFS=',' read -ra garr <<< "$globs"
    for g in "${garr[@]}"; do
      g="${g// /}"
      [[ -z "$g" ]] && continue
      local m=""
      # 优先 find（覆盖未 git add 的新文件），再并 git ls-files（覆盖 git 历史但已删除的工作区文件）
      local base="${g%%/\**}"
      if [[ -d "$base" ]]; then
        m=$(find "$base" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.java' \) 2>/dev/null || true)
      fi
      if [[ -z "$m" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        m=$(git ls-files "$g" 2>/dev/null || true)
      fi
      [[ -n "$m" ]] && matched="${matched}${matched:+$'\n'}$m"
    done
    # 记录 layer -> files
    printf '%s\t' "$name" >> "$tmp_layer_files"
    printf '%s\n' "$matched" >> "$tmp_layer_files"
    # 记录 file -> layer
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      printf '%s\t%s\n' "$f" "$name" >> "$tmp_file2layer"
    done <<< "$matched"
  done

  if [[ ! -s "$tmp_file2layer" ]]; then
    warn "LAYER_DEFS 配置但未匹配到任何源文件，检查 glob 是否正确"
    return
  fi

  # ---- 2. 层索引（LAYER_ORDER[0] 最上层，只能依赖下方层）----
  local i=0 lo
  for lo in "${LAYER_ORDER[@]}"; do
    printf '%s\t%s\n' "$lo" "$i" >> "$tmp_layer2idx"
    i=$((i+1))
  done

  # 辅助：查文件所属层（接受绝对或相对路径，统一去掉 PROJECT_DIR 前缀）
  # 注意 macOS 下 /tmp 是 /private/tmp 的 symlink，PROJECT_DIR 与 realpath 结果可能前缀不一致
  local _pd; _pd=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P || echo "$PROJECT_DIR")
  _norm() { local p="$1"; p="${p#$_pd/}"; p="${p#$PROJECT_DIR/}"; p="${p#./}"; printf '%s' "$p"; }
  _layer_of() { local p; p=$(_norm "$1"); awk -F'\t' -v f="$p" '$1==f{print $2; exit}' "$tmp_file2layer"; }
  _idx_of()   { awk -F'\t' -v l="$1" '$1==l{print $2; exit}' "$tmp_layer2idx"; }

  # ---- 3. 层依赖方向断言：仅允许上层依赖下层 ----
  local f
  while IFS= read -r line; do
    f="${line%%$'\t'*}"
    local src_layer; src_layer="${line#*$'\t'}"
    [[ -z "$f" || -z "$src_layer" ]] && continue
    local src_idx; src_idx=$(_idx_of "$src_layer")
    src_idx=${src_idx:-0}
    local imports
    imports=$(grep -hoE "(import|from)\s+['\"][^'\"]+['\"]|import\s+[a-zA-Z0-9_./]+" "$f" 2>/dev/null \
      | grep -oE "['\"][^'\"]+['\"]" | sed "s/['\"]//g" | sort -u || true)
    [[ -z "$imports" ]] && continue
    while IFS= read -r imp; do
      [[ -z "$imp" ]] && continue
      case "$imp" in
        ./*|../*)
          local dir; dir=$(dirname "$f")
          local target=""
          # realpath 对无扩展名的模块路径会失败，先按各扩展名尝试解析
          for ext in ".ts" ".js" ".py" ".go" ".tsx" ".jsx" "/index.ts" "/index.js"; do
            local cand
            cand=$(cd "$dir" 2>/dev/null && _resolve_path "${imp}${ext}" 2>/dev/null || echo "")
            if [[ -n "$cand" && -f "$cand" ]]; then target="$cand"; break; fi
          done
          [[ -z "$target" ]] && continue
          local tgt_layer; tgt_layer=$(_layer_of "$target")
          [[ -z "$tgt_layer" ]] && continue
          local tgt_idx; tgt_idx=$(_idx_of "$tgt_layer")
          tgt_idx=${tgt_idx:-0}
          if [[ "$tgt_layer" != "$src_layer" && "$tgt_idx" -le "$src_idx" ]]; then
            fail "层依赖违规：$f ($src_layer) → $target ($tgt_layer)。仅允许上层依赖下层（${LAYER_ORDER[*]}）"
            found=1
          fi
          ;;
      esac
    done <<< "$imports"
  done < "$tmp_file2layer"

  # ---- 4. 领域层污染检测：领域层不得 import 框架/ORM/Web/IO ----
  if [[ -n "$DOMAIN_LAYER" && ${#DOMAIN_FORBIDDEN_IMPORTS[@]} -gt 0 ]]; then
    local dom_files
    dom_files=$(awk -F'\t' -v l="$DOMAIN_LAYER" '$1==l{print $2}' "$tmp_layer_files")
    if [[ -n "$dom_files" ]]; then
      while IFS= read -r df; do
        [[ -z "$df" ]] && continue
        local ffi
        for ffi in "${DOMAIN_FORBIDDEN_IMPORTS[@]}"; do
          if grep -qE "from ['\"]${ffi}|import ['\"]${ffi}|require\(['\"]${ffi}" "$df" 2>/dev/null; then
            fail "领域层污染：$df import 了框架/ORM/IO 模块 '$ffi'（领域层应保持纯业务，不依赖框架）"
            found=1
          fi
        done
      done <<< "$dom_files"
    fi
  fi

  # ---- 5. 循环依赖检测（madge 若装）----
  if command -v madge >/dev/null 2>&1; then
    local circ
    circ=$(madge --circular --extensions ts,js "$PROJECT_DIR" 2>/dev/null || true)
    if echo "$circ" | grep -qi "circular"; then
      fail "检测到循环依赖（madge）："; echo "$circ" | sed 's/^/    /'
      found=1
    fi
  else
    warn "未安装 madge（npm i -g madge），循环依赖检测跳过"
  fi

  # ---- 6. 聚合间直接对象引用检测（聚合应只引用其他聚合的 ID，非对象）----
  if [[ -n "$AGGREGATE_DIR" && -d "$AGGREGATE_DIR" ]]; then
    local aggs; aggs=$(find "$AGGREGATE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
    if [[ -n "$aggs" ]]; then
      local ad af
      while IFS= read -r ad; do
        [[ -z "$ad" ]] && continue
        local aname; aname=$(basename "$ad")
        while IFS= read -r af; do
          [[ -z "$af" ]] && continue
          local imps
          imps=$(grep -hoE "from ['\"][^'\"]+['\"]|import ['\"][^'\"]+['\"]" "$af" 2>/dev/null \
            | grep -oE "['\"][^'\"]+['\"]" | sed "s/['\"]//g" || true)
          while IFS= read -r imp; do
            [[ -z "$imp" ]] && continue
            case "$imp" in
              ./*|../*)
                local dir; dir=$(dirname "$af")
                local target=""
                for ext in ".ts" ".js" ".py" ".tsx" ".jsx"; do
                  local cand
                  cand=$(cd "$dir" 2>/dev/null && _resolve_path "${imp}${ext}" 2>/dev/null || echo "")
                  if [[ -n "$cand" && -f "$cand" ]]; then target="$cand"; break; fi
                done
                [[ -z "$target" ]] && continue
                local other
                while IFS= read -r other; do
                  [[ -z "$other" || "$other" == "$aname" ]] && continue
                  local other_dir; other_dir=$(cd "$AGGREGATE_DIR/$other" 2>/dev/null && pwd -P || echo "$AGGREGATE_DIR/$other")
                  if [[ -n "$target" && "$target" == "$other_dir"* ]]; then
                    fail "聚合跨边界对象引用：$af ($aname 聚合) 直接 import 了 $other 聚合的内部。聚合间应只引用 ID，不引用对象"
                    found=1
                  fi
                done < <(find "$AGGREGATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
                ;;
            esac
          done <<< "$imps"
        done < <(find "$ad" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' \) 2>/dev/null)
      done <<< "$aggs"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "分层边界检查通过（无穿透/倒置/领域污染/聚合跨引用）"
  fi
}

check_stable_diff() {
  echo "=== 稳定单元篡改检查（DDD：稳定层/聚合根/Repository 不得被随意改）==="
  local found=0

  if [[ ${#STABLE_GLOBS[@]} -eq 0 ]]; then
    warn "未配置 STABLE_GLOBS，跳过稳定单元篡改检查"
    return
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "非 git 仓库，稳定单元篡改检查跳过"
    return
  fi

  # ---- 1. 收集本次变更（vs main）触及的稳定层文件 ----
  local base="main"
  git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
  local changed; changed=$(git diff --name-only "$base"...HEAD 2>/dev/null || true)
  if [[ -z "$changed" ]]; then
    changed=$(git diff --name-only HEAD 2>/dev/null || true)
  fi
  [[ -z "$changed" ]] && { pass "无变更，稳定单元篡改检查通过"; return; }

  # 匹配 stable globs
  declare -a stable_changed=()
  local c sg
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    for sg in "${STABLE_GLOBS[@]}"; do
      # 用 bash 的 extglob/globstar 近似匹配（** → 递归）
      shopt -s globstar extglob nullglob 2>/dev/null || true
      # 简单前缀匹配：把 glob 的 ** 之前部分作为前缀
      local prefix="${sg%%/\**}"
      if [[ "$c" == "$prefix"* ]]; then
        stable_changed+=("$c")
        break
      fi
    done
  done <<< "$changed"

  if [[ ${#stable_changed[@]} -eq 0 ]]; then
    pass "本次未改动稳定层文件"
    return
  fi

  # ---- 2. 对每个被改的稳定文件，检查是否有 spec 声明 MODIFIED ----
  # 找 spec 文档（含 §5.5 复用约束的 spec）
  local spec_file=""
  for cand in "specs/spec-template.md" "spec-template.md" "docs/spec-template.md"; do
    if [[ -f "$cand" ]]; then spec_file="$cand"; break; fi
  done
  if [[ -z "$spec_file" ]]; then
    for dir in "${WRITABLE_DIRS[@]}" "${SCAN_DIRS[@]}"; do
      if [[ -d "$dir" ]]; then
        local hit; hit=$(grep -rliE '复用约束|拼装合规声明|MODIFIED' "$dir" --include='*.md' 2>/dev/null | head -1 || true)
        if [[ -n "$hit" ]]; then spec_file="$hit"; break; fi
      fi
    done
  fi

  # 从 spec 提取声明为 MODIFIED 的文件路径
  local declared_modified=""
  if [[ -n "$spec_file" ]]; then
    declared_modified=$(awk '
      /MODIFIED|修改文件|侵入点/ {in_sec=1}
      /^## [0-9]/ && in_sec {in_sec=0}
      in_sec && /`[^`]+`/ {
        line=$0; while (match(line, /`[^`]+`/)) {
          print substr(line, RSTART+1, RLENGTH-2); line=substr(line, RSTART+RLENGTH)
        }
      }
    ' "$spec_file" 2>/dev/null | grep -E '/|\.' | sort -u || true)
  fi

  local sc si
  for ((si=0; si<${#stable_changed[@]}; si++)); do
    sc="${stable_changed[$si]}"
    # 检查该稳定文件是否在 spec 的 MODIFIED 清单中
    if echo "$declared_modified" | grep -qF -- "$sc"; then
      : # 已声明修改，允许
    else
      fail "稳定单元被篡改但未在 spec MODIFIED 段声明：${sc}（稳定层改动必须先立 spec，标注 MODIFIED + 理由 + 迁移）"
      found=1
    fi
  done

  if [[ $found -eq 0 ]]; then
    pass "稳定单元篡改检查通过（${#stable_changed[@]} 个稳定文件改动均已在 spec 声明）"
  fi
}

check_link_depth() {
  echo "=== 调用链深度检查（DDD：链路膨胀/跨聚合事务/Repository 查询泄漏）==="
  local found=0

  if [[ "$MAX_LINK_DEPTH" -le 0 ]]; then
    skip_if_unconfigured "MAX_LINK_DEPTH=0，跳过调用链深度检查"
    return
  fi

  # ---- 1. 优先用 gitnexus trace（最准确，基于代码图谱）----
  if has_gitnexus && gitnexus_indexed; then
    local depth_output; depth_output=$(gitnexus trace --format text 2>/dev/null | head -50 || true)
    if [[ -n "$depth_output" ]]; then
      local max_depth; max_depth=$(echo "$depth_output" | grep -oE '[0-9]+' | sort -n | tail -1 || echo 0)
      if [[ "$max_depth" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度 ${max_depth}（gitnexus trace）超过阈值 ${MAX_LINK_DEPTH}，建议拆分中转层"
      fi
      pass "调用链深度检查完成（基于 gitnexus trace，最大深度 ${max_depth}）"
      return
    fi
  fi

  # ---- 2. 降级 graphify path ----
  if has_graphify && graphify_built; then
    local report; report=$(graphify explain 2>/dev/null | head -50 || true)
    if echo "$report" | grep -qiE "depth|max.*path|longest"; then
      local depths; depths=$(echo "$report" | grep -oE '[0-9]+' | sort -n | tail -1 || true)
      if [[ -n "$depths" && "$depths" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度 ${depths} 超过阈值 ${MAX_LINK_DEPTH}（graphify 报告，建议拆分中间适配层）"
      fi
    fi
    pass "调用链深度检查完成（基于 graphify 图谱）"
    return
  fi

  # ---- 3. 降级 madge ----
  if has_madge; then
    local tree; tree=$(madge --tree --extensions ts,js "$PROJECT_DIR" 2>/dev/null || true)
    local max_indent=0
    while IFS= read -r line; do
      local spaces; spaces=$(echo "$line" | grep -oE '^[ ]*' | wc -c | xargs)
      [[ "$spaces" -gt "$max_indent" ]] && max_indent=$spaces
    done <<< "$tree"
    local depth=$(( max_indent / 2 ))
    if [[ "$depth" -gt "$MAX_LINK_DEPTH" ]]; then
      warn "调用链最大深度约 ${depth}（madge 估算）超过阈值 ${MAX_LINK_DEPTH}，建议拆分中转层"
    fi
    pass "调用链深度检查完成（基于 madge，最大深度约 ${depth}）"
    return
  fi

  # ---- 2. 降级：统计"纯转发函数"（只调用下一个函数、无其他逻辑）作为链路膨胀信号 ----
  local forwarders=0
  local dir
  for dir in "${WRITABLE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    # 粗筛：函数体只有一行 return xxx()，疑似纯转发
    local hits
    hits=$(grep -rnE '^\s*(export\s+)?(async\s+)?function\s+\w+.*\{$' "$dir" \
      --include='*.ts' --include='*.js' 2>/dev/null | wc -l | xargs || true)
    # 进一步：找函数体只有 return 调用的（粗略，需多行匹配）
    local pure_fwd
    pure_fwd=$(grep -rzoP 'function\s+\w+\([^)]*\)\s*\{\s*return\s+\w+\([^)]*\)\s*;?\s*\}' "$dir" \
      --include='*.ts' --include='*.js' 2>/dev/null | grep -c 'function' || true)
    forwarders=$((forwarders + ${pure_fwd:-0}))
  done
  if [[ $forwarders -gt 5 ]]; then
    warn "检测到 $forwarders 个疑似纯转发函数（只 return 调用下一个函数）——可能是链路膨胀的适配层堆叠，建议合并"
  fi
  warn "未安装 graphify/madge，调用链深度检查降级为纯转发函数统计。安装 madge（npm i -g madge）或 graphify（uv tool install graphifyy）以获得准确调用链深度"
  pass "调用链深度检查完成（降级模式）"
}

check_reuse() {
  echo "=== 复用合规检查（拼装式开发：禁止重复造轮子）==="
  local found=0

  # ---- 1. 硬门禁：spec-template.md §5.5 复用约束段必须已填写 ----
  # 找到最近一份 spec-template（项目内 specs/ 或当前目录）
  local spec_file=""
  for cand in "specs/spec-template.md" "spec-template.md" "docs/spec-template.md"; do
    if [[ -f "$cand" ]]; then spec_file="$cand"; break; fi
  done
  # 兜底：在可改目录下找任意 *spec*.md 含 §5.5 标记
  if [[ -z "$spec_file" ]]; then
    for dir in "${WRITABLE_DIRS[@]}" "${SCAN_DIRS[@]}"; do
      if [[ -d "$dir" ]]; then
        local hit
        hit=$(grep -rliE '复用约束|拼装合规声明' "$dir" --include='*.md' 2>/dev/null | head -1 || true)
        if [[ -n "$hit" ]]; then spec_file="$hit"; break; fi
      fi
    done
  fi

  if [[ -z "$spec_file" ]]; then
    fail "未找到含 §5.5 复用约束段的 spec 文档——拼装式开发要求每个变更先声明复用（见 spec-template.md §5.5）"
    found=1
  else
    # 校验 §5.5 拼装合规声明 4 个 checkbox 已勾选
    local decl; decl=$(awk '/复用约束|拼装合规声明/,/^## [0-9]/' "$spec_file" 2>/dev/null)
    if [[ -z "$decl" ]]; then
      fail "$spec_file 缺少 §5.5 复用约束段"
      found=1
    else
      local unchecked; unchecked=$(echo "$decl" | grep -cE '^\s*-\s*\[\s\]' || true)
      local checked;   checked=$(echo "$decl" | grep -cE '^\s*-\s*\[x\]' || true)
      if [[ $unchecked -gt 0 || $checked -lt 4 ]]; then
        fail "$spec_file §5.5 拼装合规声明未全部勾选（$checked/4 已勾，$unchecked 未勾）"
        found=1
      fi
    fi
  fi

  # ---- 2. 硬门禁：新增胶水代码单元名 vs reference-manual.md §4/5/6 稳定单元名重名检测 ----
  local ref_file=""
  local hit=""
  for cand in "references/reference-manual.md" "reference-manual.md"; do
    if [[ -f "$cand" ]]; then ref_file="$cand"; break; fi
  done
  if [[ -z "$ref_file" ]]; then
    # 兜底：glob 匹配 .claude/skills/<*>/references/reference-manual.md
    for f in .claude/skills/*/references/reference-manual.md; do
      if [[ -f "$f" ]]; then ref_file="$f"; break; fi
    done
  fi

  if [[ -n "$spec_file" && -n "$ref_file" ]]; then
    # 从 spec §5.5 "新增胶水代码" 表提取首列单元名（跳过表头/分隔行/空行）
    local new_names; new_names=$(awk '
      /^### .*新增胶水代码/ {in_tbl=1; next}
      /^### / && in_tbl {in_tbl=0}
      in_tbl && /^\|/ && !/^\|[-: ]+\|/ && !/文件|单元名/ {
        cell=$2; gsub(/[ `]/,"",cell); if(cell!="") print cell
      }
    ' "$spec_file" 2>/dev/null | sort -u)
    # 从 reference-manual.md §4/§5/§6 表格首列提取稳定单元名
    local stable_names; stable_names=$(awk '
      /^#+ .*[§4-6].*(组件|依赖链路|接口)/ {in_sec=1}
      /^#+ / && !/[§4-6].*(组件|依赖链路|接口)/ {if(in_sec) in_sec=0}
      in_sec && /^\|/ && !/^\|[-: ]+\|/ {
        cell=$2; gsub(/[ `]/,"",cell); if(cell!="" && cell !~ /^</) print cell
      }
    ' "$ref_file" 2>/dev/null | sort -u)

    if [[ -n "$new_names" && -n "$stable_names" ]]; then
      local dups; dups=$(comm -12 <(echo "$new_names") <(echo "$stable_names"))
      if [[ -n "$dups" ]]; then
        fail "疑似重复造轮子：以下新增单元名与 reference-manual.md §4/5/6 既有稳定单元重名（应直接复用）："
        echo "$dups" | sed 's/^/    - /'
        found=1
      fi
    fi
  fi

  # ---- 3. 启发式 warn：本次 diff 新增导出单元数量异常（非全量统计）----
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local base="main"; git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    local diff_add; diff_add=$(git diff "$base"...HEAD --diff-filter=A --name-only 2>/dev/null || true)
    [[ -z "$diff_add" ]] && diff_add=$(git diff HEAD --diff-filter=A --name-only 2>/dev/null || true)
    if [[ -n "$diff_add" ]]; then
      local new_count=0
      while IFS= read -r nf; do
        [[ -z "$nf" ]] && continue
        case "$nf" in
          *.ts|*.js|*.vue|*.py)
            local exports; exports=$(grep -cE '^\s*(export\s+)?(function|const|class|def)\s+[A-Za-z_]' "$nf" 2>/dev/null || echo 0)
            new_count=$((new_count + exports))
            ;;
        esac
      done <<< "$diff_add"
      if [[ $new_count -gt 30 ]]; then
        warn "本次变更新增 $new_count 个导出单元——请核对 reference-manual.md §4/5/6 可复用稳定单元清单，确认无重复造轮子"
      fi
    fi
  fi

  echo "  提示: 拼装式开发原则——新功能应优先复用既有稳定单元（见 reference-manual.md §4/5/6）"
  echo "    - 禁止重复造轮子：新增前先查可复用稳定单元清单"
  echo "    - 禁止侵入式重构：不改既有稳定单元签名/行为"
  echo "    - 禁止破坏性改造：不改 upstream 骨架/第三方依赖"
  echo "    - 每个新增文件应标注复用了哪些既有单元（见 spec-template.md §5.5 复用约束段）"
  if [[ $found -eq 0 ]]; then
    pass "复用合规检查通过"
  fi
}

# 依赖版本提取（输出 name<TAB>version，跨平台 awk，兼容 5 类依赖文件）
_extract_deps() {
  local f="$1"
  case "$f" in
    *package.json)
      grep -E '"[^"]+"[[:space:]]*:[[:space:]]*"[~^]?[0-9]' "$f" 2>/dev/null \
        | awk -F'"' '{ if($2!="" && $4!="") print $2"\t"$4 }' || true
      ;;
    *pyproject.toml)
      awk '/^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=[[:space:]]*"[~^><=!0-9]/ {
        n=$1; gsub(/[=[:space:]]/,"",n);
        v=$0; sub(/.*"/,"",v); sub(/".*/,"",v);
        if(n!="" && v!="") print n"\t"v
      }' "$f" 2>/dev/null || true
      ;;
    *requirements.txt)
      awk '{
        n=$0; sub(/[=<>~!].*/,"",n); gsub(/[[:space:]]/,"",n);
        v=$0; sub(/^[^=<>~!]*[=<>~!]+/,"",v); sub(/[,[[:space:];].*/,"",v);
        if(n!="" && v!="" && v ~ /^[0-9]/) print n"\t"v
      }' "$f" 2>/dev/null || true
      ;;
    *go.mod)
      awk '/^\t[[:alnum:]\/._-]+[[:space:]]+v[0-9]/ { print $1"\t"$2 }' "$f" 2>/dev/null || true
      ;;
    *Cargo.toml)
      awk '/^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=[[:space:]]*"[0-9]/ {
        n=$1; gsub(/[=[:space:]]/,"",n);
        v=$0; sub(/.*"/,"",v); sub(/".*/,"",v);
        if(n!="" && v!="") print n"\t"v
      }' "$f" 2>/dev/null || true
      ;;
    *pom.xml)
      # Maven: <dependency><groupId>G</groupId><artifactId>A</artifactId><version>V</version>
      awk '/<dependency>/{gd="";ad="";vd=""}
           /<groupId>/{gd=$0}
           /<artifactId>/{ad=$0}
           /<version>/{vd=$0}
           /<\/dependency>/{
             g=gd; sub(/.*<groupId>/,"",g); sub(/<\/groupId>.*/,"",g)
             a=ad; sub(/.*<artifactId>/,"",a); sub(/<\/artifactId>.*/,"",a)
             v=vd; sub(/.*<version>/,"",v); sub(/<\/version>.*/,"",v)
             if(g!="" && a!="" && v!="") print g":"a"\t"v
           }' "$f" 2>/dev/null || true
      ;;
    *build.gradle|*build.gradle.kts)
      # Gradle: implementation 'group:artifact:version' 或 implementation group: 'g', name: 'a', version: 'v'
      grep -oE "implementation\s+['\"]([^'\"]+):([^'\"]+):([^'\"]+)['\"]" "$f" 2>/dev/null \
        | sed -E "s/.*['\"]([^'\"]+)['\"].*/\\1/" | awk -F: '{print $1":"$2"\t"$3}' || true
      # Gradle Kotlin DSL: implementation("group:artifact:version")
      grep -oE 'implementation\("([^"]+):([^"]+):([^"]+)"\)' "$f" 2>/dev/null \
        | sed -E 's/.*\("([^"]+)"\).*/\1/' | awk -F: '{print $1":"$2"\t"$3}' || true
      ;;
  esac
}

# 去除版本前缀符号 ^ ~ > < = 及尾部约束，便于跨版本比较
_norm_ver() { echo "$1" | sed -E 's/^[~^><=]+//; s/[[:space:],;].*$//'; }

check_deps() {
  echo "=== 依赖版本锁定检查（铁律：未经确认不得升级/更换核心依赖）==="
  local found=0

  # 定位基线 codebase.md
  local baseline_file=""
  if [[ -n "${CODEBASE_REF:-}" && -f "$CODEBASE_REF" ]]; then
    baseline_file="$CODEBASE_REF"
  else
    local cand
    cand=$(find "$PROJECT_DIR/.claude/skills" -name codebase.md -path '*/references/*' 2>/dev/null | head -n 1 || true)
    [[ -n "$cand" ]] && baseline_file="$cand"
  fi
  if [[ -z "$baseline_file" ]]; then
    warn "未找到 codebase.md 版本基线（设置 CODEBASE_REF 或确保 .claude/skills/<skill>/references/codebase.md 存在）"
    return 0
  fi

  # 版本约束声明文件（spec）——记录经用户确认允许变更的依赖及理由
  local spec_file=""
  if [[ -n "${SPEC_FILE:-}" && -f "$SPEC_FILE" ]]; then
    spec_file="$SPEC_FILE"
  else
    local cand2
    cand2=$(find "$PROJECT_DIR/.claude/skills" -type f -name '*.md' 2>/dev/null | grep -iE 'spec' | head -n 1 || true)
    [[ -n "$cand2" ]] && spec_file="$cand2"
  fi

  # 从 codebase.md 技术栈版本表提取 name<TAB>version 基线对（跨平台 awk，按 | 分列）
  # 表格行形如: | react | 18.2.0 | 核心 |  → $2=依赖名 $3=版本
  # 注意：v 中的空格必须 trim，否则 _norm_ver 的 sed 会误切
  local baseline_pairs
  baseline_pairs=$(awk -F'|' '
    /^\|.*\|.*[0-9]+\.[0-9]+.*\|/ {
      n=$2; v=$3;
      sub(/^[[:space:]]+/,"",n); sub(/[[:space:]]+$/,"",n);
      sub(/^[[:space:]]+/,"",v); sub(/[[:space:]]+$/,"",v);
      sub(/^[~^><=]+/,"",v);
      if(n!="" && v!="" && n !~ /^[-=+]/ && v ~ /^[0-9]+/) print n"\t"v
    }
  ' "$baseline_file" 2>/dev/null | sort -u || true)

  # 收集项目依赖清单文件（排除 node_modules / upstream / .git）
  local dep_files
  dep_files=$(find "$PROJECT_DIR" -maxdepth 3 \
    \( -name package.json -o -name pyproject.toml -o -name go.mod -o -name requirements.txt -o -name Cargo.toml -o -name pom.xml -o -name build.gradle -o -name build.gradle.kts \) \
    2>/dev/null | grep -vE 'node_modules|/upstream/|/\.git/' || true)

  local df name ver base_ver ver_clean base_clean declared
  for df in $dep_files; do
    [[ -f "$df" ]] || continue
    local cur; cur=$(_extract_deps "$df" | sort -u)
    [[ -z "$cur" ]] && continue
    # 用 while + 管道避免 set -e 在子进程中触发；process substitution 兼容 bash 4+
    while IFS= read -r dep_line; do
      [[ -z "$dep_line" ]] && continue
      name="${dep_line%%$'\t'*}"
      ver="${dep_line#*$'\t'}"
      [[ -z "$name" || -z "$ver" || "$name" == "$ver" ]] && continue
      ver_clean=$(_norm_ver "$ver")
      base_ver=$(printf '%s\n' "$baseline_pairs" | awk -F'\t' -v n="$name" '$1==n {print $2; exit}')
      [[ -z "$base_ver" ]] && continue   # 基线无记录 → 跳过（新依赖由 --reuse 关注）
      base_clean=$(_norm_ver "$base_ver")
      if [[ "$ver_clean" != "$base_clean" ]]; then
        declared=""
        if [[ -n "$spec_file" && -f "$spec_file" ]]; then
          declared=$(grep -E -- "${name}.*${ver_clean}" "$spec_file" 2>/dev/null | head -n 1 || true)
        fi
        if [[ -z "$declared" ]]; then
          fail "依赖版本被变更但未在 spec 版本约束声明段声明: ${name} 基线=${base_clean} 当前=${ver_clean} (${df})"
          found=1
        fi
      fi
    done <<< "$cur"
  done

  echo "  提示: 版本锁定铁律——功能性开发中不得随意升级/更换核心依赖版本"
  echo "    - 例外仅限：用户主动要求 / 严重安全或性能隐患 / 功能缺失"
  echo "    - 任何版本变更须在 spec 版本约束声明段显式声明理由 + 经用户确认"
  if [[ $found -eq 0 ]]; then
    pass "依赖版本锁定检查通过（未检测到未经声明的版本变更）"
  fi
}

# 安全扫描辅助：在指定目录中按 ERE 模式扫描，返回 文件:行号:内容
_sec_scan() {
  local pattern="$1"; shift
  local d
  for d in "$@"; do
    [[ -z "$d" || ! -d "$d" ]] && continue
    # 基础文件类型
    local includes="--include=*.ts --include=*.js --include=*.jsx --include=*.tsx --include=*.vue --include=*.svelte --include=*.py --include=*.java --include=*.go --include=*.json --include=*.env"
    # 当配置了 MyBatis mapper 目录时，追加 .xml 扫描（SQL 注入实际在 XML mapper 中）
    if [[ ${#MYBATIS_MAPPER_DIRS[@]} -gt 0 ]]; then
      includes="$includes --include=*.xml"
    fi
    grep -rnE "$pattern" "$d" $includes 2>/dev/null \
      | grep -viE 'test|mock|node_modules|\.patch|__fixtures__|__mocks__|\.spec\.|\.d\.ts' || true
  done
}

check_security() {
  echo "=== 安全规范检查（OWASP Top 10 / 代码安全 / 网络安全）==="
  local found=0
  # 合并 WRITABLE_DIRS + SCAN_DIRS 并去重（避免同一目录扫两遍产生重复告警）
  local targets=() seen=""
  for d in "${WRITABLE_DIRS[@]}" "${SCAN_DIRS[@]}"; do
    [[ -z "$d" || ! -d "$d" ]] && continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"; targets+=("$d")
  done
  [[ ${#targets[@]} -eq 0 ]] && { warn "无可扫描目录（WRITABLE_DIRS/SCAN_DIRS 为空）"; return 0; }

  local line

  # §1 SQL 注入：SQL 关键字 + 字符串拼接/插值
  # ★MyBatis 框架感知：#{} 是参数化安全写法（跳过），${} 是危险字符串拼接（仅 ORDER BY/表名白名单可用）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # 排除 MyBatis 安全的 #{} 参数化写法
    if echo "$line" | grep -qE '#\{'; then
      # 含 #{} 的行如果是纯 #{}（无 ${}），视为安全
      if ! echo "$line" | grep -qE '\$\{'; then
        continue
      fi
    fi
    # 检查白名单（SQL_INJECTION_WHITELIST）
    local in_whitelist=0
    if [[ ${#SQL_INJECTION_WHITELIST[@]} -gt 0 ]]; then
      local wl
      for wl in "${SQL_INJECTION_WHITELIST[@]}"; do
        echo "$line" | grep -qF "$wl" && in_whitelist=1 && break
      done
    fi
    if [[ $in_whitelist -eq 1 ]]; then
      warn "MyBatis \${} 白名单命中（须人工确认安全）：$line"
    else
      fail "疑似 SQL 注入（字符串拼接 SQL）：$line"; found=1
    fi
  done < <(_sec_scan 'SELECT|INSERT|UPDATE|DELETE|DROP' "${targets[@]}" | grep -E '\+|\$\{' || true)

  # §2 命令注入：child_process exec/spawn + 动态拼接（排除 RegExp.exec）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "疑似命令注入（exec/system 拼接动态内容）：$line"; found=1
  done < <(_sec_scan 'exec\(|execSync\(|spawn\(|system\(|popen\(|child_process' "${targets[@]}" \
    | grep -E '\+|\$\{|%s|format\(' \
    | grep -viE '\.exec\(|RegExp|regex|pattern\.exec|match\.' || true)

  # §3 不安全动态代码执行：eval / new Function
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "不安全动态代码执行（eval / new Function）：$line"; found=1
  done < <(_sec_scan 'eval\(|new Function\(' "${targets[@]}" || true)

  # §4 XSS：v-html / dangerouslySetInnerHTML / innerHTML + 拼接
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "疑似 XSS（v-html / dangerouslySetInnerHTML / innerHTML 拼接）：$line"; found=1
  done < <(_sec_scan 'v-html|dangerouslySetInnerHTML|innerHTML' "${targets[@]}" | grep -E '\+|\$\{' || true)

  # §5 路径穿越（warn）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    warn "疑似路径穿越（../ 或 path.join 含动态片段）：$line"
  done < <(_sec_scan '\.\./|path\.join\(|path\.resolve\(' "${targets[@]}" | grep -E '\+|\$\{|req\.|input|param' || true)

  # §6 硬编码密钥：变量名含 key/secret/token/password + 赋值 16+ 位字符串字面量（排除注释/变量名/枚举）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "疑似硬编码密钥：$line"; found=1
  done < <(_sec_scan 'api[_-]?key|secret|token|password|passwd|pwd|private[_-]?key' "${targets[@]}" \
    | grep -E '[:=][[:space:]]*["\x27][A-Za-z0-9+/=_-]{16,}["\x27]' \
    | grep -viE 'process\.env|getenv|os\.environ|config\.|env\.|example|placeholder|//|/\*|\*|const [A-Z_]|enum |type |interface |class ' || true)

  # §7 弱哈希用于密码（warn）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    warn "疑似弱哈希（md5/sha1 用于密码场景）：$line"
  done < <(_sec_scan 'md5|sha1|createHash' "${targets[@]}" | grep -iE 'password|pwd|passwd|auth|token|secret' || true)

  # §8 TLS 验证关闭
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "不安全传输配置（TLS 验证关闭）：$line"; found=1
  done < <(_sec_scan 'rejectUnauthorized|verify\s*:\s*false|insecure|allowInsecure|ssl.*verify' "${targets[@]}" \
    | grep -iE 'false|true' | grep -viE 'rejectUnauthorized\s*:\s*true' || true)

  # §9 CORS 全开（warn）—— 只匹配实际 CORS 配置中的 *，不匹配注释
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    warn "疑似 CORS 全开（Allow-Origin: *）：$line"
  done < <(_sec_scan 'Access-Control-Allow-Origin|cors\(' "${targets[@]}" | grep -E '\*' | grep -viE '//|/\*|\*' || true)

  # §10 调试模式开启（warn）
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    warn "疑似生产调试模式开启（debug:true）：$line"
  done < <(_sec_scan 'debug\s*:\s*true|DEBUG\s*=\s*true|DEBUG\s*=\s*True' "${targets[@]}" \
    | grep -viE 'dev\.env|development|test' || true)

  echo "  提示: 安全规范——防范 OWASP Top 10（注入/XSS/CSRF/访问控制/认证/敏感数据）"
  echo "    - 硬性违规(fail)：SQL/命令注入、eval、XSS 拼接、硬编码密钥、TLS 关闭"
  echo "    - 人工复核(warn)：路径穿越、弱哈希、CORS *、调试模式"
  echo "    - 完整规范见 references/security-spec.md（应用安全/代码安全/网络安全/AI安全）"
  if [[ $found -eq 0 ]]; then
    pass "安全规范检查通过（未检测到硬性违规；warn 项请人工复核）"
  fi
}

# ===== TOGAF 架构契约门禁（--adr / --contract / --consistency-cross / --impact）=====
# 防范：架构决策无文档 / 接口无版本 / BDAT 命名不一致 / 数据所有权模糊 / 变更无影响分析 / 遗留无 ACL

check_adr() {
  echo "=== 架构决策记录检查（TOGAF：决策可追溯 + 技术债登记）==="
  local found=0

  # ---- 1. ADR 目录必须存在 ----
  if [[ -z "$ADR_DIR" ]]; then
    warn "未配置 ADR_DIR，跳过架构决策检查（生成目标技能时设为 docs/adr 或 adr）"
    return
  fi
  if [[ ! -d "$ADR_DIR" ]]; then
    fail "ADR 目录不存在：${ADR_DIR}（TOGAF 要求架构决策可追溯，须建立 ADR 目录）"
    found=1
    # 后续检查依赖目录存在，直接返回
    if [[ $found -eq 0 ]]; then pass "架构决策记录检查通过"; fi
    return
  fi

  # ---- 2. ADR 文件计数（至少应有 1 个 ADR）----
  local adr_count
  adr_count=$(find "$ADR_DIR" -type f \( -name '*.md' -o -name '*.adoc' \) 2>/dev/null | wc -l | xargs || true)
  if [[ "$adr_count" -eq 0 ]]; then
    warn "${ADR_DIR} 目录无 ADR 文件（在 ADR_DIR 新建 0001-技术栈选择.md + 0002-关键架构决策.md（格式：# ADR-NNNN: 标题 / 状态 / 上下文 / 决策 / 理由））"
  fi

  # ---- 3. 本次引入的新依赖/新框架必须有对应 ADR ----
  # 检测 git diff 中新增的 import 语句（package.json/requirements.txt/go.mod/pyproject.toml）
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local base="main"
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    local diff_imports
    diff_imports=$(git diff "$base"...HEAD -- '*.ts' '*.js' '*.py' '*.go' 2>/dev/null \
      | grep -E '^\+.*(import|from)\s' \
      | grep -oE "['\"][^'\"./][^'\"]*['\"]" | sed "s/['\"]//g" | sort -u || true)
    # 过滤出"非相对路径"的第三方包（形如 lodash、@scope/pkg）
    local third_party=""
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      # 相对路径（./ ../）跳过；node: 内置跳过
      case "$pkg" in
        ./*|../*|node:*) continue ;;
        @*/*|*) ;;
      esac
      third_party="${third_party}${third_party:+$'\n'}$pkg"
    done <<< "$diff_imports"

    if [[ -n "$third_party" ]]; then
      # 在所有 ADR 文件中搜索这些包名
      local adr_all; adr_all=$(cat "$ADR_DIR"/*.md "$ADR_DIR"/*.adoc 2>/dev/null || true)
      local unexplained=""
      while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! echo "$adr_all" | grep -qF -- "$pkg"; then
          unexplained="${unexplained}${unexplained:+$'\n'}$pkg"
        fi
      done <<< "$third_party"
      if [[ -n "$unexplained" ]]; then
        warn "本次新增以下第三方依赖未在 ADR 中说明选型理由（TOGAF 要求技术选型有决策记录）："
        echo "$unexplained" | sed 's/^/    - /'
        echo "  建议：在 ${ADR_DIR}/ 新增 ADR，记录为何选这些包（替代方案/权衡/影响）"
      fi
    fi
  fi

  # ---- 4. 技术债登记检查 ----
  if [[ -n "$TECH_DEBT_FILE" ]]; then
    if [[ ! -f "$TECH_DEBT_FILE" ]]; then
      warn "技术债登记文件不存在：${TECH_DEBT_FILE}（绕过架构决策的临时代码应在技术债登记，便于追踪）"
    else
      local td_count; td_count=$(grep -cE '^\s*[-*]\s' "$TECH_DEBT_FILE" 2>/dev/null || true)
      # 检测代码中是否有 TODO/FIXME/HACK 但未在技术债登记
      local code_todos
      code_todos=$(grep -rnE 'TODO|FIXME|HACK|XXX' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
        --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
        | grep -v -i 'node_modules\|\.patch' | wc -l | xargs || true)
      if [[ "$code_todos" -gt 0 ]]; then
        warn "代码中有 ${code_todos} 处 TODO/FIXME/HACK——在 TECH_DEBT_FILE 追加条目：格式 '- [ ] 文件:行号 TODO内容 计划修复时间'（当前技术债条目 ${td_count} 个）"
      fi
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "架构决策记录检查通过（${adr_count} 个 ADR）"
  fi
}

check_contract() {
  echo "=== 接口契约检查（TOGAF：契约版本化 + 防腐层 ACL）==="
  local found=0

  # ---- 1. 契约文件版本化检查 ----
  if [[ -z "$CONTRACT_DIR" ]]; then
    warn "未配置 CONTRACT_DIR，跳过接口契约检查（生成目标技能时设为 docs/contracts）"
  elif [[ ! -d "$CONTRACT_DIR" ]]; then
    warn "契约目录不存在：${CONTRACT_DIR}（新建 CONTRACT_DIR/ 并为每个 API 创建 YAML/JSON 文件，必含 version: "x.y.z" 字段）"
  else
    local contracts; contracts=$(find "$CONTRACT_DIR" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.md' \) 2>/dev/null || true)
    if [[ -z "$contracts" ]]; then
      warn "${CONTRACT_DIR} 目录无契约文件"
    else
      local cf
      while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        # 检查是否含 version 字段（yaml/json/md 都查 version 关键字）
        if ! grep -qE 'version\s*[:=]|## v?[0-9]' "$cf" 2>/dev/null; then
          fail "接口契约缺 version 字段：${cf}（TOGAF 要求系统间接口契约可追溯版本，便于变更影响分析）"
          found=1
        fi
      done <<< "$contracts"
    fi
  fi

  # ---- 2. 防腐层（ACL）检查：跨上下文 import 必须经 ACL 目录中转 ----
  if [[ -n "$ACL_DIR" && ${#CONTEXT_DIRS[@]} -gt 0 ]]; then
    if [[ ! -d "$ACL_DIR" ]]; then
      warn "ACL 目录不存在：${ACL_DIR}（新建 ACL_DIR/ 目录，跨上下文 import 须经此目录中转（在 ACL_DIR 为每个外部上下文建 adapter 文件））"
    else
      local _pd; _pd=$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P || echo "$PROJECT_DIR")
      # 预解析每个上下文目录为绝对路径
      local ctx_abs=()
      local ci
      for ((ci=0; ci<${#CONTEXT_DIRS[@]}; ci++)); do
        local a; a=$(cd "${CONTEXT_DIRS[$ci]}" 2>/dev/null && pwd -P || echo "")
        ctx_abs+=("$a")
      done
      # 对每个上下文目录的文件，检测其 import 是否解析到其他上下文目录
      local i j
      for ((i=0; i<${#CONTEXT_DIRS[@]}; i++)); do
        local ctx_a="${CONTEXT_DIRS[$i]}"
        local ctx_a_abs="${ctx_abs[$i]}"
        [[ -d "$ctx_a" ]] || continue
        local af
        while IFS= read -r af; do
          [[ -z "$af" ]] && continue
          local imps
          imps=$(grep -hoE "from ['\"][^'\"]+['\"]|import ['\"][^'\"]+['\"]" "$af" 2>/dev/null \
            | grep -oE "['\"][^'\"]+['\"]" | sed "s/['\"]//g" || true)
          while IFS= read -r imp; do
            [[ -z "$imp" ]] && continue
            case "$imp" in
              ./*|../*)
                local dir; dir=$(dirname "$af")
                local target=""
                for ext in ".ts" ".js" ".py" ".tsx" ".jsx"; do
                  local cand
                  cand=$(cd "$dir" 2>/dev/null && _resolve_path "${imp}${ext}" 2>/dev/null || echo "")
                  if [[ -n "$cand" && -f "$cand" ]]; then target="$cand"; break; fi
                done
                [[ -z "$target" ]] && continue
                # 检查 target 是否落在其他上下文目录内
                for ((j=0; j<${#CONTEXT_DIRS[@]}; j++)); do
                  [[ $i -eq $j ]] && continue
                  local ctx_b_abs="${ctx_abs[$j]}"
                  [[ -z "$ctx_b_abs" ]] && continue
                  if [[ "$target" == "$ctx_b_abs"* ]]; then
                    fail "上下文间直接引用（绕过 ACL）：${af} (${ctx_a}) 直接 import 了 ${CONTEXT_DIRS[$j]}。跨上下文应经 ${ACL_DIR} 防腐层中转"
                    found=1
                    break
                  fi
                done
                ;;
            esac
          done <<< "$imps"
        done < <(find "$ctx_a" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' \) 2>/dev/null)
      done
      pass "ACL 防腐层目录存在：${ACL_DIR}"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "接口契约检查通过"
  fi
}

check_consistency_cross() {
  echo "=== BDAT 跨域一致性检查（TOGAF：业务-应用-数据命名一致 + 数据所有权 SoR）==="
  local found=0

  # ---- 1. 业务域术语表 vs 代码标识符命名一致性 ----
  if [[ -z "$GLOSSARY_FILE" ]]; then
    warn "未配置 GLOSSARY_FILE，跳过 BDAT 命名一致性检查（新建 GLOSSARY_FILE，格式：| 业务名 | 代码标识符 |（每行一个概念，供 --consistency-cross 校验））"
  elif [[ ! -f "$GLOSSARY_FILE" ]]; then
    warn "术语表文件不存在：${GLOSSARY_FILE}（TOGAF 要求业务域有统一术语表，避免同名异义/异名同义）"
  else
    # 解析术语表：每行 "业务名 <TAB> 代码标识符" 或 "| 业务名 | 代码标识符 |"
    # 跳过表头行（恰好是"业务名"）与分隔行（---）
    local entries; entries=$(awk '
      /^\|/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) {
          gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]);
          if(a[1]!=""&&a[2]!="" && a[1]!="业务名" && a[1]!="业务" && a[1]!="名字" && a[1]!="标识符" && a[2] !~ /^[-:]+$/)
            print a[1]"\t"a[2]
        }
      }
      /\t/ { n=split($0,a,"\t"); if(a[1]!=""&&a[2]!=""&&a[1]!="业务名") print a[1]"\t"a[2] }
    ' "$GLOSSARY_FILE" 2>/dev/null || true)
    if [[ -n "$entries" ]]; then
      local biz code
      while IFS=$'\t' read -r biz code; do
        [[ -z "$biz" || -z "$code" ]] && continue
        # 检查代码中是否存在该标识符（粗筛：grep 类名/函数名/表名）
        # 注意 BSD grep：--include 必须紧跟 -r 选项，pattern 用 -e 防止 - 开头
        local hits
        hits=$(grep -rnwF --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.sql' -e "$code" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" 2>/dev/null | wc -l | xargs || true)
        if [[ "$hits" -eq 0 ]]; then
          warn "术语表中的代码标识符 '${code}'（业务名：${biz}）在代码中未找到——可能命名已漂移或术语表过时"
        fi
      done <<< "$entries"
    fi
  fi

  # ---- 2. 数据所有权（System of Record）检查 ----
  if [[ -z "$SOR_FILE" ]]; then
    warn "未配置 SOR_FILE，跳过数据所有权检查（新建 SOR_FILE，格式：| 实体 | 权威源 | 允许读 | 允许写 |（每个数据实体一行））"
  elif [[ ! -f "$SOR_FILE" ]]; then
    warn "数据所有权文件不存在：${SOR_FILE}（TOGAF 要求明确每个数据实体的 System of Record，避免双写不一致）"
  else
    # 解析 SoR 表：| 实体 | 权威源 | 允许读 | 允许写 |
    local sor_entries; sor_entries=$(awk '
      /^\|/ && !/^\|[-: ]+\|/ && !/实体|实体名/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) { gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]); if(a[1]!="") print a[1]"\t"a[2] }
      }
    ' "$SOR_FILE" 2>/dev/null || true)
    if [[ -n "$sor_entries" ]]; then
      local ent sor
      while IFS=$'\t' read -r ent sor; do
        [[ -z "$ent" ]] && continue
        # 检查该实体是否有写操作出现在非 SoR 系统目录（粗筛：grep INSERT/UPDATE/写操作）
        : # 仅校验 SoR 表存在且实体有登记，详细双写检测需人工
      done <<< "$sor_entries"
      pass "数据所有权表存在（${SOR_FILE}），含 $(echo "$sor_entries" | wc -l | xargs) 个实体登记"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "BDAT 跨域一致性检查通过"
  fi
}

check_impact() {
  echo "=== 变更影响分析检查（TOGAF：变更须含影响范围段 + 消费方清单）==="
  local found=0

  # ---- 1. 找 spec 文件（影响范围段应在此）----
  local spec_file="${IMPACT_SPEC_FILE:-$SPEC_FILE}"
  if [[ -z "$spec_file" ]]; then
    for cand in "specs/spec-template.md" "spec-template.md" "docs/spec-template.md"; do
      if [[ -f "$cand" ]]; then spec_file="$cand"; break; fi
    done
  fi
  if [[ -z "$spec_file" ]]; then
    for dir in "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" "${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}"; do
      if [[ -d "$dir" ]]; then
        local hit; hit=$(grep -rliE '影响范围|impact|消费方|stakeholder' "$dir" --include='*.md' 2>/dev/null | head -1 || true)
        if [[ -n "$hit" ]]; then spec_file="$hit"; break; fi
      fi
    done
  fi

  # ---- 2. spec 必须含"影响范围"段 ----
  if [[ -z "$spec_file" ]]; then
    fail "未找到 spec 文档——TOGAF 要求每次架构变更先做影响分析（spec 须含'影响范围'段，列出受影响消费方）"
    found=1
  else
    if ! grep -qE '影响范围|impact|消费方|stakeholder' "$spec_file" 2>/dev/null; then
      fail "${spec_file} 缺少'影响范围'段（TOGAF 要求架构变更声明影响范围：哪些系统/模块/消费方受影响、迁移路径）"
      found=1
    fi
  fi

  # ---- 3. 变更影响分析：优先用 gitnexus impact/detect_changes，降级 grep ----
  if has_gitnexus && gitnexus_indexed; then
    # gitnexus detect_changes: git diff → 受影响进程（最准确）
    local gn_impact; gn_impact=$(gitnexus detect_changes 2>/dev/null | head -30 || true)
    if [[ -n "$gn_impact" ]]; then
      local affected_count; affected_count=$(echo "$gn_impact" | grep -cE '^\s+\S' || echo 0)
      if [[ "$affected_count" -gt 5 ]]; then
        warn "gitnexus 检测到 ${affected_count} 个受影响进程——变更影响范围较大，确认 spec 已列出受影响方"
      fi
      echo "  gitnexus detect_changes 输出（前 10 行）："
      echo "$gn_impact" | head -10 | sed 's/^/    /'
    fi
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # 降级：git diff + grep 反查消费方
    local base="main"
    git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    local changed; changed=$(git diff --name-only "$base"...HEAD 2>/dev/null || true)
    if [[ -z "$changed" ]]; then
      changed=$(git diff --name-only HEAD 2>/dev/null || true)
    fi
    if [[ -n "$changed" ]]; then
      local cf
      while IFS= read -r cf; do
        [[ -z "$cf" ]] && continue
        local in_writable=0 wd
        for wd in "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}"; do
          case "$cf" in
            "$wd"*) in_writable=1; break ;;
          esac
        done
        [[ $in_writable -eq 0 ]] && continue
        local mod; mod=$(basename "$cf")
        mod="${mod%.*}"
        [[ -z "$mod" ]] && continue
        local consumers
        consumers=$(grep -rlwF -- "$mod" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
          --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null \
          | grep -v "^${cf}$" || true)
        if [[ -n "$consumers" ]]; then
          local ccount; ccount=$(echo "$consumers" | wc -l | xargs || true)
          if [[ $ccount -gt 3 ]]; then
            warn "${cf} 有 ${ccount} 个消费方引用——变更影响范围较大，确认 spec 已列出这些消费方并评估回归"
          fi
        fi
      done <<< "$changed"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "变更影响分析检查通过"
  fi
}

# ===== 微服务架构门禁（--service / --api）=====
# 防范：共享数据库 / 同步调用链过长 / 共享模型库 / 无网关 / 无trace透传 / 契约无版本 / 无幂等 / 跨服务事务

check_service() {
  echo "=== 微服务架构检查（共享DB/同步链/共享模型/网关/trace透传）==="
  local found=0

  if [[ ${#SERVICE_DIRS[@]} -eq 0 ]]; then
    warn "未配置 SERVICE_DIRS，跳过微服务架构检查（生成目标技能时列出各服务目录）"
    return
  fi

  # ---- 1. 共享数据库检测：多服务 DB 配置指向同一数据库 ----
  if [[ ${#DB_CONFIG_FILES[@]} -gt 0 ]]; then
    declare -a db_uris=()
    local cf
    for cf in "${DB_CONFIG_FILES[@]}"; do
      [[ -f "$cf" ]] || continue
      # 提取数据库连接 URI/host（粗筛：含 host/port/database 的配置行）
      local uri
      uri=$(grep -hoE '(host|HOST|url|URL|dsn|DSN|database_url|DATABASE_URL)\s*[:=]\s*["'"'"']?[^"'"'"'\s,;]+' "$cf" 2>/dev/null \
        | sed 's/.*[:=]\s*["'"'"']\?//' | sort -u || true)
      if [[ -n "$uri" ]]; then
        db_uris+=("${cf}::${uri}")
      fi
    done
    # 检测是否有两个服务指向同一 host+database
    local i j
    for ((i=0; i<${#db_uris[@]}; i++)); do
      for ((j=i+1; j<${#db_uris[@]}; j++)); do
        local uri_i="${db_uris[$i]##*::}"
        local uri_j="${db_uris[$j]##*::}"
        local file_i="${db_uris[$i]%%::*}"
        local file_j="${db_uris[$j]%%::*}"
        if [[ -n "$uri_i" && "$uri_i" == "$uri_j" ]]; then
          fail "共享数据库反模式：${file_i} 与 ${file_j} 指向同一数据库（${uri_i}）。微服务应每服务独立数据库，避免 schema 变更互相影响"
          found=1
        fi
      done
    done
    if [[ $found -eq 0 ]]; then
      pass "无共享数据库（${#db_uris[@]} 个 DB 配置均指向不同实例）"
    fi
  fi

  # ---- 2. 共享模型/库检测：多服务依赖同一共享包 ----
  if [[ -n "$SHARED_LIBS_DIR" && -d "$SHARED_LIBS_DIR" ]]; then
    local shared_pkg; shared_pkg=$(basename "$SHARED_LIBS_DIR")
    local svc_count=0
    local svc
    for svc in "${SERVICE_DIRS[@]}"; do
      [[ -d "$svc" ]] || continue
      # 检测服务是否 import 了共享包
      if grep -rqwF -- "$shared_pkg" "$svc" --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null; then
        svc_count=$((svc_count+1))
      fi
    done
    if [[ $svc_count -gt 1 ]]; then
      warn "共享库 ${SHARED_LIBS_DIR} 被 ${svc_count} 个服务依赖——共享领域模型会导致服务无法独立演进（改一处全服务重发）。将共享库拆分：utils/types 可共享，领域模型复制到各服务（防分布式单体）"
    fi
  fi

  # ---- 3. API 网关存在性 ----
  if [[ -z "$API_GATEWAY" ]]; then
    warn "未配置 API_GATEWAY——新建 API_GATEWAY 目录/文件，实现认证+限流+跨域+路由聚合（或在 API_GATEWAY 指向已有网关）"
  elif [[ ! -e "$API_GATEWAY" ]]; then
    warn "API 网关不存在：${API_GATEWAY}（客户端直连后端服务会导致认证/跨域/限流各服务重复实现）"
  else
    pass "API 网关存在：${API_GATEWAY}"
  fi

  # ---- 4. 同步调用链深度（HTTP/RPC 调用）----
  if [[ "$MAX_SYNC_CHAIN" -gt 0 ]]; then
    local svc2
    for svc2 in "${SERVICE_DIRS[@]}"; do
      [[ -d "$svc2" ]] || continue
      # 粗筛：统计服务内 HTTP 调用语句（fetch/axios/httpClient/grpc）
      local call_count
      call_count=$(grep -rnE '(fetch|axios|httpClient|grpc|http\.request|requests\.)\(' "$svc2" \
        --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null \
        | grep -v -i 'test\|mock\|node_modules' | wc -l | xargs || true)
      if [[ "$call_count" -gt "$MAX_SYNC_CHAIN" ]]; then
        warn "${svc2} 有 ${call_count} 处对外同步调用——同步链过长易雪崩（建议熔断/降级/异步化，阈值 ${MAX_SYNC_CHAIN}）"
      fi
    done
  fi

  # ---- 5. 分布式追踪（traceId 透传）检测 ----
  local trace_found=0
  local svc3
  for svc3 in "${SERVICE_DIRS[@]}"; do
    [[ -d "$svc3" ]] || continue
    if grep -rqwE 'traceId|trace_id|x-trace|traceparent|spanId|span_id|opentelemetry|@opentelemetry' "$svc3" \
      --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null; then
      trace_found=1
      break
    fi
  done
  if [[ $trace_found -eq 0 ]]; then
    warn "未检测到 traceId/spanId 透传——跨服务调用无分布式追踪，故障难定位（建议接入 OpenTelemetry 或透传 x-trace-id）"
  else
    pass "检测到分布式追踪（traceId 透传）"
  fi

  if [[ $found -eq 0 ]]; then
    pass "微服务架构检查通过"
  fi
}

check_api() {
  echo "=== API 契约与幂等检查（版本化/幂等/跨服务事务）==="
  local found=0

  # ---- 1. API 定义文件版本化 ----
  if [[ -z "$API_SPEC_DIR" ]]; then
    warn "未配置 API_SPEC_DIR，跳过 API 契约检查（建议建立 OpenAPI/proto/GraphQL schema 目录）"
  elif [[ ! -d "$API_SPEC_DIR" ]]; then
    warn "API 定义目录不存在：${API_SPEC_DIR}"
  else
    local specs; specs=$(find "$API_SPEC_DIR" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.proto' -o -name '*.graphql' \) 2>/dev/null || true)
    if [[ -n "$specs" ]]; then
      local sf
      while IFS= read -r sf; do
        [[ -z "$sf" ]] && continue
        if ! grep -qE 'version\s*[:=]|^version|## v?[0-9]|edition\s*=' "$sf" 2>/dev/null; then
          fail "API 定义缺 version：${sf}（微服务契约无版本化会导致消费方静默挂）"
          found=1
        fi
      done <<< "$specs"
    fi
  fi

  # ---- 2. 写操作幂等性检测 ----
  if [[ ${#WRITE_HANDLER_DIRS[@]} -gt 0 ]]; then
    local hd
    for hd in "${WRITE_HANDLER_DIRS[@]}"; do
      [[ -d "$hd" ]] || continue
      # 检测 POST/PUT/DELETE handler 是否含幂等键（idempotency-key/request-id 去重）
      local handlers
      handlers=$(grep -rlnE '(POST|PUT|DELETE|@Post|@Put|@Delete|app\.(post|put|delete))' "$hd" \
        --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null || true)
      if [[ -n "$handlers" ]]; then
        local hf
        while IFS= read -r hf; do
          [[ -z "$hf" ]] && continue
          if ! grep -qwiE 'idempotency|request.?id|dedup|去重|幂等' "$hf" 2>/dev/null; then
            warn "${hf} 含写操作但无幂等设计（建议 idempotency-key 去重，防止重试导致重复扣款/重复创建）"
          fi
        done <<< "$handlers"
      fi
    done
  fi

  # ---- 3. 跨服务分布式事务检测（反模式：微服务不该用 2PC）----
  local svc
  for svc in "${SERVICE_DIRS[@]+"${SERVICE_DIRS[@]}"}"; do
    [[ -d "$svc" ]] || continue
    # 检测跨服务 BEGIN TRANSACTION / @Transactional 跨服务调用
    local xa
    xa=$(grep -rnE 'XAResource|XA_OPEN|2pc|two.?phase|distributed.?transaction|seata|@GlobalTransactional' "$svc" \
      --include='*.ts' --include='*.js' --include='*.py' --include='*.java' 2>/dev/null \
      | grep -v -i 'test\|mock\|node_modules' || true)
    if [[ -n "$xa" ]]; then
      warn "${svc} 检测到分布式事务/2PC——微服务应避免跨服务事务，改用 Saga/Outbox 模式"
      echo "$xa" | head -3 | sed 's/^/    /'
    fi
  done

  # ---- 4. Outbox 模式提示（写库+发消息一致性）----
  local has_outbox=0
  for svc in "${SERVICE_DIRS[@]+"${SERVICE_DIRS[@]}"}"; do
    [[ -d "$svc" ]] || continue
    if grep -rqwiE 'outbox|out_box|event.?relay|transactional.?outbox' "$svc" \
      --include='*.ts' --include='*.js' --include='*.py' --include='*.java' 2>/dev/null; then
      has_outbox=1
      break
    fi
  done
  if [[ $has_outbox -eq 0 && ${#SERVICE_DIRS[@]} -gt 0 ]]; then
    warn "未检测到 Outbox 模式——服务写库后发消息可能不一致（库已改消息未发）。建议 outbox 表保证原子性"
  fi

  if [[ $found -eq 0 ]]; then
    pass "API 契约与幂等检查通过"
  fi
}

# ===== 前端架构门禁（--state / --frontend）=====
# 防范：巨型store / prop drilling / 派生状态useState / 组件层级深 / 容器展示混合 / props过多 / 重复依赖 / 循环依赖 / 全局CSS污染

check_state() {
  echo "=== 状态管理检查（巨型store/prop drilling/派生状态）==="
  local found=0

  # ---- 1. 巨型 store 检测：store 文件行数 ----
  if [[ -n "$STORE_DIR" && -d "$STORE_DIR" ]]; then
    if [[ "$MAX_STORE_LINES" -gt 0 ]]; then
      local sf
      while IFS= read -r sf; do
        [[ -z "$sf" ]] && continue
        local lines; lines=$(wc -l < "$sf" 2>/dev/null | xargs || echo 0)
        if [[ "$lines" -gt "$MAX_STORE_LINES" ]]; then
          warn "${sf} 有 ${lines} 行（>阈值 ${MAX_STORE_LINES}）——巨型 store 会导致改一个字段全组件重渲染，建议按领域拆分"
        fi
      done < <(find "$STORE_DIR" -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null)
    fi
  else
    warn "未配置 STORE_DIR，跳过 store 检查"
  fi

  # ---- 2. Prop Drilling 深度检测：组件 props 透传链 ----
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    # 粗筛：检测组件接收 props 后原样透传给子组件（...props / {...this.props}）
    local drilling
    drilling=$(grep -rnE '\.\.\.props|\{\.\.\.props\}|\{\.\.\.this\.props\}|rest\.props|remaining.*props' "$COMPONENT_DIR" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.vue' --include='*.svelte' 2>/dev/null \
      | grep -v -i 'test\|mock\|node_modules' || true)
    if [[ -n "$drilling" ]]; then
      local dcount; dcount=$(echo "$drilling" | wc -l | xargs || true)
      if [[ "$dcount" -gt 5 ]]; then
        warn "检测到 ${dcount} 处 props 透传（...props）——深度 prop drilling 会使中间组件被迫接收无关 props，建议 Context/compose"
      fi
    fi
  fi

  # ---- 3. 派生状态用 useState 检测（应改 useMemo/直接计算）----
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    local derived
    derived=$(grep -rnE 'useState\([^)]*(\.map|\.filter|\.reduce|\.sort|\.find|\.length|\.concat)' "$COMPONENT_DIR" \
      --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' 2>/dev/null \
      | grep -v -i 'test\|mock\|node_modules' || true)
    if [[ -n "$derived" ]]; then
      local dcount; dcount=$(echo "$derived" | wc -l | xargs || true)
      warn "检测到 ${dcount} 处 useState 内做派生计算（.map/.filter/.reduce 等）——派生状态应直接计算或 useMemo，存 state 会导致不同步"
      echo "$derived" | head -3 | sed 's/^/    /'
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "状态管理检查通过"
  fi
}

check_frontend() {
  echo "=== 前端组件架构检查（层级深/容器展示分离/props多/重复依赖/循环依赖/CSS污染）==="
  local found=0

  if [[ -z "$COMPONENT_DIR" || ! -d "$COMPONENT_DIR" ]]; then
    warn "未配置 COMPONENT_DIR 或目录不存在，跳过前端组件检查"
    return
  fi

  # ---- 1. 组件嵌套深度（>MAX_COMPONENT_DEPTH warn）----
  if [[ "$MAX_COMPONENT_DEPTH" -gt 0 ]]; then
    # 粗筛：找 JSX 中组件标签嵌套深度（按缩进估算）
    local cf
    while IFS= read -r cf; do
      [[ -z "$cf" ]] && continue
      local max_indent=0
      # 用 python 扫描字符算 JSX 组件标签的峰值嵌套深度（兼容同行嵌套）
      local depth
      depth=$(python3 -c "
import re,sys
try: t=open('$cf',encoding='utf-8').read()
except: t=''
depth=0; maxd=0
for m in re.finditer(r'<(/?)([A-Z][A-Za-z0-9]*)', t):
  if m.group(1)=='/': depth=max(0,depth-1)
  else: depth+=1; maxd=max(maxd,depth)
print(maxd)
" 2>/dev/null || echo 0)
      if [[ "$depth" -gt "$MAX_COMPONENT_DEPTH" ]]; then
        warn "${cf} 组件嵌套深度 ${depth}（>阈值 ${MAX_COMPONENT_DEPTH}）——层级过深导致渲染栈深、调试难、性能损耗，建议扁平化"
      fi
    done < <(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) 2>/dev/null)
  fi

  # ---- 2. 容器组件与展示组件未分离检测 ----
  # 粗筛：组件文件同时含 API 调用（fetch/axios/useQuery）和大量 JSX 渲染
  local cf2
  while IFS= read -r cf2; do
    [[ -z "$cf2" ]] && continue
    local has_io has_render
    has_io=$(grep -cE '(fetch|axios|useQuery|useMutation|useSWR|\.get\(|\.post\()' "$cf2" 2>/dev/null || true)
    has_io=${has_io:-0}; has_io=$(echo "$has_io" | xargs)
    [[ "$has_io" =~ ^[0-9]+$ ]] || has_io=0
    # 统计 JSX 标签出现次数（非行数），用 grep -o 计数
    has_render=$(grep -oE '<(div|span|ul|li|section|article|main|header|footer|table|button|input|form|p|h[1-6])' "$cf2" 2>/dev/null | wc -l | xargs || true)
    has_render=${has_render:-0}; has_render=$(echo "$has_render" | xargs)
    [[ "$has_render" =~ ^[0-9]+$ ]] || has_render=0
    if [[ "$has_io" -gt 0 && "$has_render" -gt 10 ]]; then
      warn "${cf2} 同时含数据获取（${has_io}）和大量渲染（${has_render}）——容器组件与展示组件未分离，建议拆分（容器管数据，展示管 UI），提升复用性与可测性"
      break  # 只提示一次，避免刷屏
    fi
  done < <(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) 2>/dev/null)

  # ---- 3. 组件 props 过多检测（>MAX_PROPS_COUNT warn）----
  if [[ "$MAX_PROPS_COUNT" -gt 0 ]]; then
    local cf3
    while IFS= read -r cf3; do
      [[ -z "$cf3" ]] && continue
      # 提取 props 解构 / interface Props 的字段数（粗筛，支持同行多字段）
      local props_count
      props_count=$(awk '
        /interface [A-Z][A-Za-z]*Props|type [A-Z][A-Za-z]*Props/ {in_props=1; next}
        in_props && /^\}/ {in_props=0; if(count>0) print count; count=0; next}
        in_props {
          # 统计该行中 "字段:" 模式的出现次数（同行多字段用 ; 或 , 分隔）
          n = gsub(/[a-zA-Z_][a-zA-Z0-9_]*[?:]?[[:space:]]*:/, "&")
          count += n
        }
      ' "$cf3" 2>/dev/null | sort -n | tail -1 || echo 0)
      if [[ "$props_count" -gt "$MAX_PROPS_COUNT" ]]; then
        warn "${cf3} props 数量 ${props_count}（>阈值 ${MAX_PROPS_COUNT}）——props 过多说明组件职责过重，建议拆分"
      fi
    done < <(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.ts' \) 2>/dev/null)
  fi

  # ---- 4. 循环依赖检测（madge 优先，降级 grep）----
  if command -v madge >/dev/null 2>&1; then
    local circ
    circ=$(madge --circular --extensions ts,tsx,js,jsx "$COMPONENT_DIR" 2>/dev/null || true)
    if echo "$circ" | grep -qi 'circular'; then
      fail "检测到组件循环依赖（madge）——A↔B 互相 import 会导致运行时 undefined："
      echo "$circ" | sed 's/^/    /'
      found=1
    fi
  else
    # 降级：检测同目录文件互引（粗筛）
    warn "未安装 madge，循环依赖检测跳过（npm i -g madge）"
  fi

  # ---- 5. 全局 CSS 污染检测 ----
  if [[ -n "$STYLE_DIR" && -d "$STYLE_DIR" ]]; then
    # 检测纯 CSS 文件（无 .module. 后缀）含全局类定义
    local global_css
    global_css=$(find "$STYLE_DIR" -type f -name '*.css' ! -name '*.module.css' 2>/dev/null || true)
    if [[ -n "$global_css" ]]; then
      local gcount; gcount=$(echo "$global_css" | wc -l | xargs || true)
      if [[ "$gcount" -gt 0 ]]; then
        warn "检测到 ${gcount} 个非 scoped CSS 文件（无 .module.css 后缀）——全局类名易冲突，建议 CSS Modules / styled-components / Tailwind scoped"
      fi
    fi
  fi

  # ---- 6. bundle 重复依赖（若有报告）----
  if [[ -n "$BUNDLE_REPORT" && -f "$BUNDLE_REPORT" ]]; then
    # 粗筛：bundle 报告中是否含同一包多版本（搜 "x.x.x" 重复包名）
    local dups
    dups=$(grep -oE '"[^"]+"' "$BUNDLE_REPORT" 2>/dev/null | sort | uniq -c | sort -rn | awk '$1>1' | head -5 || true)
    if [[ -n "$dups" ]]; then
      warn "bundle 报告中检测到重复依赖（可能多版本打包）："
      echo "$dups" | sed 's/^/    /'
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "前端组件架构检查通过"
  fi
}

# ===== 认知递进门禁（--cognition）=====
# 理念：先有概念定义→结构→空间→三者映射→认知规律→处理关系
#       关系在时空中变化：速度/聚散/趋势/强度/能耗/累积量
# 本门禁不判违规（不 fail），而是呈现"认知体检报告"——六阶认知链完整性 + 六维动力学状态
# 让开发者看见关系的递进与演化方向，而非仅数量计数

check_cognition() {
  echo "=== 认知递进体检（六阶认知链 + 六维动力学）==="
  echo "  理念：先有概念→结构→空间→映射→规律→处理；关系在时空变化中呈现速度/聚散/趋势/强度/能耗/累积量"
  echo ""

  # ---- ①概念定义：项目核心概念是否被定义 ----
  echo "  ①概念定义（是什么）"
  local concept_score=0
  if [[ -n "$GLOSSARY_FILE" && -f "$GLOSSARY_FILE" ]]; then
    local term_count; term_count=$(awk '/^\|/ && !/^\|[-: ]+\|/ && !/业务名|代码/ {c++} END{print c+0}' "$GLOSSARY_FILE" 2>/dev/null || echo 0)
    echo "    业务术语表：${GLOSSARY_FILE}（${term_count} 个概念定义）"
    [[ "$term_count" -gt 0 ]] && concept_score=$((concept_score+1))
  else
    echo "    ⚠ 无业务术语表（GLOSSARY_FILE 未配置）——概念未显式定义，依赖口头约定"
  fi
  # 稳定单元清单（reference-manual §4/5/6）
  local rm_file=""
  for cand in "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md"; do
    for f in $cand; do [[ -f "$f" ]] && rm_file="$f" && break 2; done
  done
  if [[ -n "$rm_file" ]]; then
    local unit_count; unit_count=$(awk '/^#+ .*[§4-6].*(组件|依赖链路|接口)/{in_sec=1} /^#+ /&&!/[§4-6]/{in_sec=0} in_sec&&/^\|/&&!/^\|[-: ]+\|/{c++} END{print c+0}' "$rm_file" 2>/dev/null || echo 0)
    echo "    稳定单元清单：${rm_file}（${unit_count} 个单元登记）"
    [[ "$unit_count" -gt 0 ]] && concept_score=$((concept_score+1))
  else
    echo "    ⚠ 无 reference-manual.md——稳定单元未盘点"
  fi
  echo "    ①概念定义认知度：${concept_score}/2"

  # ---- ②结构：概念怎么组织成结构 ----
  echo ""
  echo "  ②结构（怎么组织）"
  local struct_score=0
  if [[ ${#LAYER_DEFS[@]} -gt 0 ]]; then
    echo "    分层定义：${#LAYER_DEFS[@]} 层（${LAYER_ORDER[*]+"${LAYER_ORDER[*]}"})"
    struct_score=$((struct_score+1))
  else
    echo "    ⚠ 无分层定义（LAYER_DEFS）——结构未显式声明"
  fi
  if [[ -n "$AGGREGATE_DIR" && -d "$AGGREGATE_DIR" ]]; then
    local agg_count; agg_count=$(find "$AGGREGATE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | xargs || echo 0)
    echo "    聚合边界：${AGGREGATE_DIR}（${agg_count} 个聚合根）"
    [[ "$agg_count" -gt 0 ]] && struct_score=$((struct_score+1))
  fi
  if [[ ${#CONTEXT_DIRS[@]} -gt 0 ]]; then
    echo "    限界上下文：${#CONTEXT_DIRS[@]} 个"
    struct_score=$((struct_score+1))
  fi
  echo "    ②结构认知度：${struct_score}/3"

  # ---- ③空间：结构占据什么空间 ----
  echo ""
  echo "  ③空间（在哪里）"
  local space_score=0
  if [[ ${#SERVICE_DIRS[@]} -gt 0 ]]; then
    echo "    服务空间：${#SERVICE_DIRS[@]} 个服务目录"
    space_score=$((space_score+1))
  fi
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    local comp_count; comp_count=$(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) 2>/dev/null | wc -l | xargs || echo 0)
    echo "    组件空间：${COMPONENT_DIR}（${comp_count} 个组件）"
    space_score=$((space_score+1))
  fi
  if [[ -n "$STORE_DIR" && -d "$STORE_DIR" ]]; then
    echo "    状态空间：${STORE_DIR}"
    space_score=$((space_score+1))
  fi
  echo "    ③空间认知度：${space_score}/3"

  # ---- ④三者映射：概念↔结构↔空间是否一致 ----
  echo ""
  echo "  ④三者映射（概念↔结构↔空间是否一致）"
  local map_score=0
  # 术语表标识符 vs 代码存在性（概念↔空间映射）
  if [[ -n "$GLOSSARY_FILE" && -f "$GLOSSARY_FILE" && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    local drift_count=0
    local entries; entries=$(awk '
      /^\|/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) { gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]);
          if(a[1]!=""&&a[2]!=""&&a[1]!="业务名"&&a[2] !~ /^[-:]+$/) print a[2]
        }
      }
    ' "$GLOSSARY_FILE" 2>/dev/null || true)
    if [[ -n "$entries" ]]; then
      local code
      while IFS= read -r code; do
        [[ -z "$code" ]] && continue
        local hits; hits=$(grep -rnwF --include='*.ts' --include='*.js' --include='*.py' --include='*.go' -e "$code" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" 2>/dev/null | wc -l | xargs || true)
        [[ "$hits" -eq 0 ]] && drift_count=$((drift_count+1))
      done <<< "$entries"
      if [[ $drift_count -eq 0 ]]; then
        echo "    术语↔代码映射：一致（无漂移）"
        map_score=$((map_score+1))
      else
        echo "    ⚠ 术语↔代码映射：${drift_count} 个术语在代码中未找到（概念↔空间漂移）"
      fi
    fi
  fi
  # 分层↔目录映射（结构↔空间）
  if [[ ${#LAYER_DEFS[@]} -gt 0 ]]; then
    echo "    分层↔目录映射：${#LAYER_DEFS[@]} 层均绑定目录 glob"
    map_score=$((map_score+1))
  fi
  # 数据所有权↔服务映射（概念↔空间）
  if [[ -n "$SOR_FILE" && -f "$SOR_FILE" ]]; then
    echo "    数据所有权↔服务映射：${SOR_FILE} 存在"
    map_score=$((map_score+1))
  fi
  echo "    ④映射认知度：${map_score}/3"

  # ---- ⑤认知规律：从映射中发现的规律是否被编码 ----
  echo ""
  echo "  ⑤认知规律（规律是否被编码成门禁）"
  local rule_count=0
  [[ ${#LAYER_DEFS[@]} -gt 0 ]] && { echo "    规律：依赖单向（上层→下层）→ --layer"; rule_count=$((rule_count+1)); }
  [[ -n "$AGGREGATE_DIR" ]] && { echo "    规律：聚合间只引用 ID → --layer"; rule_count=$((rule_count+1)); }
  [[ ${#STABLE_GLOBS[@]} -gt 0 ]] && { echo "    规律：稳定单元不可擅改 → --stable-diff"; rule_count=$((rule_count+1)); }
  [[ -n "$ACL_DIR" ]] && { echo "    规律：跨上下文须经 ACL → --contract"; rule_count=$((rule_count+1)); }
  [[ ${#DB_CONFIG_FILES[@]} -gt 0 ]] && { echo "    规律：每服务独立 DB → --service"; rule_count=$((rule_count+1)); }
  [[ -n "$API_SPEC_DIR" ]] && { echo "    规律：契约须版本化 → --api"; rule_count=$((rule_count+1)); }
  [[ -n "$ADR_DIR" ]] && { echo "    规律：决策须可追溯 → --adr"; rule_count=$((rule_count+1)); }
  echo "    ⑤规律编码数：${rule_count}（每个规律对应一个门禁）"

  # ---- ⑥处理关系：关系被破坏时如何处理 ----
  echo ""
  echo "  ⑥处理关系（违规时的处置机制）"
  local handle_score=0
  [[ -n "$SPEC_FILE" || -f "spec-template.md" ]] && { echo "    spec 声明变更（MODIFIED 段）"; handle_score=$((handle_score+1)); }
  [[ -n "$ADR_DIR" && -d "$ADR_DIR" ]] && { echo "    ADR 记录决策"; handle_score=$((handle_score+1)); }
  [[ -n "$TECH_DEBT_FILE" && -f "$TECH_DEBT_FILE" ]] && { echo "    技术债登记"; handle_score=$((handle_score+1)); }
  echo "    处置机制：${handle_score}/3（spec/ADR/技术债）"

  # ---- 六维动力学观测 ----
  echo ""
  echo "  ── 六维关系动力学观测（关系的时空变化）──"

  # 速度：单次变更文件数
  local speed_val=0
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local base="main"; git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    speed_val=$(git diff --name-only "$base"...HEAD 2>/dev/null | wc -l | xargs || true)
    [[ "$speed_val" -eq 0 ]] && speed_val=$(git diff --name-only HEAD 2>/dev/null | wc -l | xargs || true)
  fi
  echo "    速度：本次变更 ${speed_val} 个文件", $([[ "$COG_SPEED_FILES" -gt 0 && "$speed_val" -gt "$COG_SPEED_FILES" ]] && echo "⚠ 过快（>${COG_SPEED_FILES}，耦合扩散风险）" || echo "正常")

  # 聚散：服务/组件数
  local gather_val=0
  [[ ${#SERVICE_DIRS[@]} -gt 0 ]] && gather_val=${#SERVICE_DIRS[@]}
  [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]] && gather_val=$((gather_val + $(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.vue' -o -name '*.svelte' -o -name '*.jsx' \) 2>/dev/null | wc -l | xargs || echo 0)))
  echo "    聚散：${gather_val} 个服务/组件单元", $([[ "$gather_val" -gt 50 ]] && echo "趋向分散" || echo "聚合适中")

  # 趋势：依赖深度变化（与基线对比）
  local trend_val="未知"
  if [[ -n "$COGNITION_BASELINE" && -f "$COGNITION_BASELINE" ]]; then
    local base_depth; base_depth=$(grep -iE '依赖深度|depth' "$COGNITION_BASELINE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "")
    if [[ -n "$base_depth" ]]; then trend_val="基线深度 ${base_depth}"; fi
  fi
  echo "    趋势：依赖深度 ${trend_val}（对比基线判断上升/下降）"

  # 强度：高 fan-in 文件（被多处引用）
  if [[ "$COG_STRENGTH_FANIN" -gt 0 && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    local strong_files=0
    local wd
    for wd in "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}"; do
      [[ -d "$wd" ]] || continue
      # 找被 >COG_STRENGTH_FANIN 个文件 import 的模块（粗筛：找高频 import 目标）
      local hot
      hot=$(grep -rhoE "from ['\"][^'\"]+['\"]" "$wd" --include='*.ts' --include='*.js' 2>/dev/null \
        | sed "s/.*['\"]//;s/['\"]$//" | sort | uniq -c | sort -rn \
        | awk -v th="$COG_STRENGTH_FANIN" '$1>th{c++} END{print c+0}' || true)
      strong_files=$((strong_files + ${hot:-0}))
    done
    echo "    强度：${strong_files} 个高 fan-in 模块（被 >${COG_STRENGTH_FANIN} 处引用）", $([[ "$strong_files" -gt 3 ]] && echo "⚠ 强依赖集中" || echo "强度分散")
  fi

  # 能耗：巨型文件数（store/组件）
  local energy_val=0
  [[ -n "$STORE_DIR" && "$MAX_STORE_LINES" -gt 0 ]] && energy_val=$(find "$STORE_DIR" -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null | while read -r f; do wc -l < "$f"; done | awk -v th="$MAX_STORE_LINES" '$1>th{c++} END{print c+0}' || true)
  echo "    能耗：${energy_val:-0} 个巨型 store 文件（>${MAX_STORE_LINES} 行，认知负荷高）"

  # 累积量：TODO/FIXME 累积
  local cumul_val=0
  if [[ "$COG_CUMULATIVE_TODO" -gt 0 && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    cumul_val=$(grep -rnE 'TODO|FIXME|HACK|XXX' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
      --include='*.ts' --include='*.js' --include='*.py' 2>/dev/null \
      | grep -v -i 'node_modules\|\.patch' | wc -l | xargs || true)
    echo "    累积量：${cumul_val} 处 TODO/FIXME", $([[ "$cumul_val" -gt "$COG_CUMULATIVE_TODO" ]] && echo "⚠ 技术债累积过载（>${COG_CUMULATIVE_TODO}）" || echo "正常")
  fi

  # ---- 认知总结 ----
  echo ""
  local total_score=$((concept_score + struct_score + space_score + map_score + handle_score))
  echo "  ── 认知递进总结（第一层）──"
  echo "    ①概念(${concept_score}/2) → ②结构(${struct_score}/3) → ③空间(${space_score}/3) → ④映射(${map_score}/3) → ⑤规律(${rule_count}条) → ⑥处理(${handle_score}/3)"
  echo "    认知总分：${total_score}/11 + ${rule_count} 条规律编码"
  if [[ $total_score -ge 8 && $rule_count -ge 4 ]]; then
    pass "第一层认知递进完整（${total_score}/11 + ${rule_count} 条规律）——关系脉络清晰，可处理关系而非仅计数"
  elif [[ $total_score -ge 5 ]]; then
    warn "第一层认知递进部分建立（${total_score}/11）——存在认知断层，建议补全缺失阶（见上表 ⚠ 项）"
  else
    warn "第一层认知递进不足（${total_score}/11）——概念/结构/空间未显式定义，门禁沦为计数，建议先建立 ①概念定义"
  fi

  # ---- 五层认知基底完整性检查（第二/三/四/五层）----
  echo ""
  echo "  ── 五层认知基底完整性（第一层 + 第二/三/四/五层）──"
  local layer2_score=0 layer3_score=0 layer4_score=0

  # 第二层：思维语言框架——spec 含三导向段（§1.1现状/§1.2目标/§14交付衰减/§15蓝图）
  local spec_for_cog="${SPEC_FILE:-}"
  [[ -z "$spec_for_cog" ]] && for cand in "spec-template.md" "specs/spec-template.md" "docs/spec-template.md"; do
    [[ -f "$cand" ]] && spec_for_cog="$cand" && break
  done
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # 强化：要求 §14/§15 章节标题存在（非仅关键词），且段落有实质内容
    grep -qE '^## 14\..*交付衰减' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    grep -qE '^## 15\..*蓝图' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    # §1.1 现状须含"痛点/根因/溯因"之一（实质内容，非仅标题）
    awk '/^## 1\.1|^### 1\.1/{in_sec=1} /^## [0-9]/{if(in_sec)in_sec=0} in_sec && /痛点|根因|溯因|为什么/{found=1} END{exit !found}' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    echo "    第二层(思维语言)：spec §14交付衰减/§15蓝图/§1.1现状溯因 ${layer2_score}/3"
  else
    echo "    第二层(思维语言)：⚠ 未找到 spec，三导向段无法检查"
  fi

  # 第三层：认知辩证——reference-manual 含逻辑谬误图谱 + spec 含思维模型对照
  if [[ -n "$rm_file" ]]; then
    # 须含 2+ 个剃刀/谬误信号（非仅一个关键词）
    local l3_hits=0
    grep -qiE '逻辑剃刀|谬误图谱' "$rm_file" 2>/dev/null && l3_hits=$((l3_hits+1))
    grep -qiE '对抗审查|灵魂拷问|降维反驳' "$rm_file" 2>/dev/null && l3_hits=$((l3_hits+1))
    [[ $l3_hits -ge 2 ]] && layer3_score=$((layer3_score+1))
  fi
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # spec §16.2 思维模型对照须有实际表格行（非仅标题）
    awk '/思维模型对照/{in_sec=1} in_sec && /^\|[^|]+\|[^|]+\|/{row++} in_sec && /^### /{if(in_sec&&row>0){found=1}} END{exit !found}' "$spec_for_cog" 2>/dev/null && layer3_score=$((layer3_score+1))
  fi
  echo "    第三层(认知辩证)：reference-manual 逻辑剃刀+谬误图谱(2+信号) + spec §16.2 思维模型对照(有行) ${layer3_score}/2"

  # 第四层：认知偏差防范——spec §16 认知偏差自检段须有实质内容
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # §16 章节标题存在 + 五维偏差表有行
    grep -qE '^## 16\..*认知偏差自检' "$spec_for_cog" 2>/dev/null && layer4_score=$((layer4_score+1))
    # 偏差扫描表须含"感知/记忆/社会/决策/元认知"至少 3 维
    local bias_dims=0
    grep -qiE '感知.*确认偏误|确认偏误.*感知' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    grep -qiE '决策.*沉没成本|沉没成本.*决策' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    grep -qiE '元认知.*达克|达克.*元认知' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    [[ $bias_dims -ge 2 ]] && layer4_score=$((layer4_score+1))
  fi
  echo "    第四层(偏差防范)：spec §16 章节存在 + 五维偏差表(≥2维有内容) ${layer4_score}/2"

  # ---- 第五层：辩证认知——reference-manual 含辩证映射表 ----
  local layer5_score=0
  if [[ -n "$rm_file" ]]; then
    # 检查含"辩证映射表"或 7 对辩证关系中的 ≥3 对
    local dialectic_hits=0
    grep -qiE '辩证映射表|辩证关系|辩证认知' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '内容与形式|内容.*形式.*辩证' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '原因与结果|因果.*辩证' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '必然与偶然|必然.*偶然' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '现实与可能|现实.*可能' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '实践与认识|实践.*认识' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '真理与谬误|真理.*谬误' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '绝对.*相对.*真理|相对.*绝对.*真理' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    [[ $dialectic_hits -ge 3 ]] && layer5_score=1
  fi
  echo "    第五层(辩证认知)：reference-manual 辩证映射表+7对辩证关系(≥3对) ${layer5_score}/1"

  # 五层总评
  local five_layer_total=$((total_score + layer2_score + layer3_score + layer4_score + layer5_score))
  local five_layer_max=19  # 11 + 3 + 2 + 2 + 1
  echo "    五层认知基底总分：${five_layer_total}/${five_layer_max}"
  if [[ $five_layer_total -ge 15 ]]; then
    pass "五层认知基底完整（${five_layer_total}/${five_layer_max}）——本质(①-④)+实践认识(思维语言)+现象分析(逻辑剃刀)+真理边界(偏差防范)+辩证统一(7对范畴)"
  elif [[ $five_layer_total -ge 10 ]]; then
    warn "五层认知基底部分建立（${five_layer_total}/${five_layer_max}）——补全缺失层（见上表）"
  else
    warn "五层认知基底不足（${five_layer_total}/${five_layer_max}）——认知有系统性漏洞，建议先补第一层+第四层+第五层"
  fi
}

check_domain() {
  echo "=== 领域知识检查（动态识别→深入分析→客观规律违规检测）==="
  local found=0

  # ---- 1. spec §18 领域知识段存在性 + 动态分析质量 ----
  local spec_file="${SPEC_FILE:-}"
  [[ -z "$spec_file" ]] && for cand in "spec-template.md" "specs/spec-template.md" "docs/spec-template.md"; do
    [[ -f "$cand" ]] && spec_file="$cand" && break
  done
  if [[ -n "$spec_file" && -f "$spec_file" ]]; then
    if grep -qE '^## 18\..*领域知识' "$spec_file" 2>/dev/null; then
      pass "spec §18 领域知识段存在"
      # 检查 §18.2 深入分析表是否有"依据"（非空壳填写）
      local analysis_rows; analysis_rows=$(awk '/^### 18\.2/,/^### 18\.3/' "$spec_file" 2>/dev/null | grep -cE '^\|.*\|.*\|.*\|.*\|.*\|.*\|' || true)
      local has_evidence; has_evidence=$(awk '/^### 18\.2/,/^### 18\.3/' "$spec_file" 2>/dev/null | grep -cE '因为|依据|证据|@/|src/|代码' || true)
      if [[ "$analysis_rows" -gt 2 ]]; then
        if [[ "$has_evidence" -ge 1 ]]; then
          pass "§18.2 领域深入分析表已填写且含代码依据（${analysis_rows} 行分析，${has_evidence} 处证据）"
        else
          warn "§18.2 领域分析表已填写但无代码依据——每条规律须标注依据（代码证据/文档证据/行业常识），非套用通用清单"
        fi
      else
        warn "§18.2 领域深入分析表未填写——须逐领域分析核心实体→因果→约束→遵循→风险"
      fi
      # 检查 §18.3 声明 checkbox
      if grep -qE '^\s*- \[[x]\].*动态识别' "$spec_file" 2>/dev/null; then
        pass "§18.3 领域声明已勾选"
      else
        warn "§18.3 领域声明未全部勾选——须确认动态识别+深入分析+标注依据+不违反客观规律"
      fi
    else
      warn "spec 缺少 §18 领域知识约束段——须动态识别领域→深入分析→推导客观规律"
    fi
  else
    skip_if_unconfigured "未找到 spec，领域知识段无法检查"
  fi

  # ---- 2. reference-manual 含"领域知识"段且规律有依据 ----
  local rm_file=""
  for cand in "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md"; do
    for f in $cand; do [[ -f "$f" ]] && rm_file="$f" && break 2; done
  done
  if [[ -n "$rm_file" ]]; then
    if grep -qiE '领域知识|领域规则|客观规律|业务规则|行业知识' "$rm_file" 2>/dev/null; then
      # 检查规律是否有代码依据（非通用清单复制）
      local has_evidence; has_evidence=$(grep -cE '因为|依据|证据|@/|src/|代码' "$rm_file" 2>/dev/null || true)
      if [[ "$has_evidence" -ge 1 ]]; then
        pass "reference-manual 含领域知识段且规律有代码依据"
      else
        warn "reference-manual 领域知识段无代码依据——规律须从项目代码分析推导，非套用通用清单"
      fi
      pass "reference-manual 含领域知识段"
    else
      warn "reference-manual 缺少'领域知识'段——须补充项目所属技术+业务领域的专业知识规则"
    fi
  fi

  # ---- 3. 客观规律违规检测（硬门禁：检测代码中违反通用常识的模式）----
  # 3a. 安全常识：密码明文存储
  local pwd_violation
  pwd_violation=$(grep -rnE "password\s*[=:]\s*['\"][^'\"]+['\"]" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
    --include='*.ts' --include='*.js' --include='*.py' --include='*.java' 2>/dev/null \
    | grep -v -i 'test\|mock\|node_modules\|placeholder\|example\|xxx\|yyy' || true)
  if [[ -n "$pwd_violation" ]]; then
    fail "违反安全客观规律：检测到密码明文存储（密码必须哈希，不可明文）"
    echo "$pwd_violation" | head -3 | sed 's/^/    /'
    found=1
  fi
  # 3b. 数据库常识：SQL 拼接（非参数化）
  local sql_violation
  sql_violation=$(grep -rnE "SELECT.*\+.*FROM|INSERT.*\+.*VALUES|WHERE.*\+.*=" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
    --include='*.ts' --include='*.js' --include='*.py' --include='*.java' 2>/dev/null \
    | grep -v -i 'test\|mock\|node_modules' || true)
  if [[ -n "$sql_violation" ]]; then
    fail "违反数据库客观规律：检测到 SQL 字符串拼接（必须参数化查询，防注入）"
    echo "$sql_violation" | head -3 | sed 's/^/    /'
    found=1
  fi
  # 3c. 前端常识：v-html / dangerouslySetInnerHTML 直接拼接动态内容（排除 sanitize/renderMarkdown/DOMPurify 等消毒场景）
  local xss_violation
  xss_violation=$(grep -rnE 'v-html|dangerouslySetInnerHTML|innerHTML\s*=' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
    --include='*.vue' --include='*.svelte' --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' 2>/dev/null \
    | grep -v -i 'test\|mock\|node_modules' \
    | grep -viE 'sanitize|renderMarkdown|DOMPurify|escape|encode|sanitizeHtml|marked\(|markdownit' || true)
  if [[ -n "$xss_violation" ]]; then
    warn "潜在前端客观规律违反：v-html/innerHTML 使用但未检测到消毒函数（sanitize/renderMarkdown/DOMPurify）。如已消毒请人工确认"
    echo "$xss_violation" | head -3 | sed 's/^/    /'
  fi
  # 3d. 并发常识：共享可变状态无锁
  local race_violation
  race_violation=$(grep -rnE 'global\s+\w+\s*=|window\.\w+\s*=' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
    --include='*.ts' --include='*.js' 2>/dev/null \
    | grep -v -i 'test\|mock\|node_modules\|config\|const\|readonly' || true)
  if [[ -n "$race_violation" ]]; then
    warn "潜在并发违规：检测到全局可变状态（共享可变状态须同步，否则竞态）"
  fi

  if [[ $found -eq 0 ]]; then
    pass "领域知识检查通过（无客观规律违规）"
  fi
}

check_knowledge() {
  echo "=== 项目知识复用检查（AGENTS.md/CLAUDE.md/记忆 → 生成 skill 是否复用）==="
  local found=0

  # ---- 0. 优先用 claude-mem search 查项目记忆 ----
  if has_claude_mem; then
    local mem_results; mem_results=$(claude-mem search "project rules conventions" 2>/dev/null | head -10 || true)
    if [[ -n "$mem_results" ]]; then
      pass "claude-mem 记忆库有历史记录（项目知识已积累）"
    else
      warn "claude-mem 已安装但无项目记忆——首次生成 skill，探查后写入项目特征摘要"
    fi
  fi

  # ---- 1. 检查项目是否有知识文件 ----
  local has_agents=0 has_claude=0 has_memories=0
  [[ -f "$PROJECT_DIR/AGENTS.md" ]] && has_agents=1
  [[ -f "$PROJECT_DIR/CLAUDE.md" ]] && has_claude=1
  # 检查 .zcode/memories 或 .claude 目录
  [[ -d "$PROJECT_DIR/.zcode/memories" || -d "$HOME/.zcode/cli/memories" ]] && has_memories=1
  [[ -d "$PROJECT_DIR/.claude" || -d "$HOME/.claude-mem" ]] && has_memories=1

  if [[ $has_agents -eq 0 && $has_claude -eq 0 && $has_memories -eq 0 ]]; then
    skip_if_unconfigured "项目无 AGENTS.md/CLAUDE.md/记忆文件，知识复用检查跳过"
    return
  fi

  # ---- 2. 检查生成的 SKILL.md 是否引用了知识来源 ----
  local skill_file=""
  for cand in "$PROJECT_DIR/.claude/skills/*/SKILL.md" ".claude/skills/*/SKILL.md" "SKILL.md"; do
    for f in $cand; do [[ -f "$f" ]] && skill_file="$f" && break 2; done
  done
  if [[ -z "$skill_file" ]]; then
    skip_if_unconfigured "未找到生成的 SKILL.md，知识复用检查跳过"
    return
  fi

  local refs=0
  [[ $has_agents -eq 1 ]] && grep -qiE 'AGENTS\.md|见 AGENTS' "$skill_file" 2>/dev/null && refs=$((refs+1))
  [[ $has_claude -eq 1 ]] && grep -qiE 'CLAUDE\.md|见 CLAUDE' "$skill_file" 2>/dev/null && refs=$((refs+1))
  [[ $has_memories -eq 1 ]] && grep -qiE 'memories|记忆|claude-mem|\.zcode' "$skill_file" 2>/dev/null && refs=$((refs+1))

  local total=$((has_agents + has_claude + has_memories))
  if [[ $refs -ge $total ]]; then
    pass "项目知识复用完整（${refs}/${total} 个知识来源被引用）"
  elif [[ $refs -gt 0 ]]; then
    warn "项目知识部分复用（${refs}/${total} 个来源被引用）——建议在 SKILL.md 铁律段引用全部知识来源"
  else
    fail "项目有知识文件（AGENTS.md/CLAUDE.md/记忆）但生成的 SKILL.md 未引用——须读取项目知识并写入铁律段"
    found=1
  fi

  # ---- 3. 检查特征卡是否从知识文件提取了规则 ----
  # 检查 SKILL.md 的铁律段是否含"见 AGENTS.md"等引用（非写死规则值）
  if [[ $has_agents -eq 1 ]]; then
    # 读 AGENTS.md 的关键规则（可改范围/只读区/分支策略）
    local agents_rules; agents_rules=$(grep -iE '可改|只读|禁止|分支|feature|feat|fix' "$PROJECT_DIR/AGENTS.md" 2>/dev/null | head -5 || true)
    if [[ -n "$agents_rules" ]]; then
      # 检查 SKILL.md 是否引用了这些规则（而非写死值）
      if ! grep -qiE 'AGENTS\.md' "$skill_file" 2>/dev/null; then
        warn "AGENTS.md 含项目规则但 SKILL.md 未引用来源——须标注'见 AGENTS.md'而非写死规则值"
      fi
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "项目知识复用检查通过"
  fi
}

check_mermaid() {
  echo "=== Mermaid 可视化检查（架构图/流程图/调用链是否用 Mermaid）==="
  local found=0

  # 检查 reference-manual.md 是否含 mermaid 图
  local rm_file=""
  for cand in "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md"; do
    for f in $cand; do [[ -f "$f" ]] && rm_file="$f" && break 2; done
  done
  local has_mermaid=0
  if [[ -n "$rm_file" ]]; then
    grep -qiE '```mermaid|<mermaid' "$rm_file" 2>/dev/null && has_mermaid=1
  fi

  # 检查 spec-template.md 是否含 mermaid 引导
  local spec_file=""
  for cand in "spec-template.md" "specs/spec-template.md" "docs/spec-template.md"; do
    [[ -f "$cand" ]] && spec_file="$cand" && break
  done
  local spec_mermaid=0
  if [[ -n "$spec_file" ]]; then
    grep -qiE 'mermaid|架构图.*可视化|流程图.*Mermaid' "$spec_file" 2>/dev/null && spec_mermaid=1
  fi

  if [[ $has_mermaid -eq 1 ]]; then
    pass "reference-manual.md 含 Mermaid 可视化"
  else
    warn "reference-manual.md 未检测到 Mermaid 图——涉及架构/流程/调用链时须用 Mermaid 可视化（mermaid 代码块）"
  fi
  if [[ $spec_mermaid -eq 1 ]]; then
    pass "spec-template 含 Mermaid 引导"
  fi

  if [[ $found -eq 0 ]]; then
    pass "Mermaid 可视化检查通过"
  fi
}

# ===== 左移门禁（--shift-left：测试左移+变更左移+运维监控左移）=====
check_shift_left() {
  echo "=== 左移检查（Shift-Left：测试设计+变更影响+可观测性，防缺陷/变更/故障流入后段）==="
  local found=0

  # ---- 定位 spec 文件 ----
  local spec_file="${SPEC_FILE:-}"
  [[ -z "$spec_file" ]] && for cand in "spec-template.md" "specs/spec-template.md" "docs/spec-template.md"; do
    [[ -f "$cand" ]] && spec_file="$cand" && break
  done
  local test_design_file="${TEST_DESIGN_FILE:-$spec_file}"
  local obs_file="${OBSERVABILITY_FILE:-$spec_file}"

  # ---- 定位 plan 文件 ----
  local plan_file="${CHANGE_IMPACT_FILE:-}"
  [[ -z "$plan_file" ]] && for cand in "plan-template.md" "plans/plan-template.md" "docs/plan-template.md"; do
    [[ -f "$cand" ]] && plan_file="$cand" && break
  done

  echo "  ── 测试左移（spec §19 + test 先于 impl）──"

  # 1a. spec §19 测试设计段存在（硬门禁）
  if [[ -n "$test_design_file" && -f "$test_design_file" ]]; then
    if grep -qE '^## .*19.*测试左移|^## §19' "$test_design_file" 2>/dev/null; then
      pass "spec §19 测试左移段存在"
      # 检查 §19.2 用例骨架表是否有实质内容
      local case_rows; case_rows=$(awk '/^### 19\.2/,/^### 19\.3/' "$test_design_file" 2>/dev/null | grep -cE '^\|.*\|.*\|.*\|.*\|' || true)
      if [[ "$case_rows" -ge 3 ]]; then
        pass "§19.2 用例骨架有 $case_rows 行（含边界/异常用例）"
      else
        warn "§19.2 用例骨架行数不足（$case_rows），须覆盖正常/边界/异常路径"
      fi
    else
      fail "spec 缺 §19 测试左移段——测试设计须在 spec 阶段写，不可编码后才补"
      found=1
    fi
  else
    warn "未找到 spec 文件，跳过 §19 测试左移段检查（配置 SPEC_FILE 或 TEST_DESIGN_FILE）"
  fi

  # 1b. git diff 中 test 文件先于或同时于 impl 文件提交（warn）
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local base="main"; git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
    local test_commits impl_commits
    test_commits=$(git log --name-only --pretty=format: "$base..HEAD" 2>/dev/null | grep -E '\.test\.|\.spec\.|__tests__' | sort -u | wc -l | xargs || echo 0)
    impl_commits=$(git log --name-only --pretty=format: "$base..HEAD" 2>/dev/null | grep -vE '\.test\.|\.spec\.|__tests__|\.md$|\.json$|\.lock$' | grep -E '\.(ts|js|py|go|java|rs)$' | sort -u | wc -l | xargs || echo 0)
    if [[ "$impl_commits" -gt 0 && "$test_commits" -eq 0 ]]; then
      warn "本次变更有 $impl_commits 个 impl 文件但无 test 文件提交——须先写/更新测试再实现（TDD/BDD）"
      found=1
    elif [[ "$impl_commits" -gt 0 && "$test_commits" -gt 0 ]]; then
      pass "本次变更有 test 文件提交（$test_commits test + $impl_commits impl）"
    fi
  fi

  echo "  ── 变更左移（plan §20 变更影响 + 回滚预案 + 迁移兼容）──"

  # 2a. plan §20 变更影响段存在（硬门禁）
  if [[ -n "$plan_file" && -f "$plan_file" ]]; then
    if grep -qE '^## .*20.*变更左移|^## §20' "$plan_file" 2>/dev/null; then
      pass "plan §20 变更左移段存在"
    else
      fail "plan 缺 §20 变更左移段——变更影响范围须在 plan 阶段写"
      found=1
    fi
  else
    warn "未找到 plan 文件，跳过 §20 变更左移段检查（配置 CHANGE_IMPACT_FILE）"
  fi

  # 2b. spec 含回滚预案声明（硬门禁）
  if [[ -n "$spec_file" && -f "$spec_file" ]]; then
    local has_rollback
    has_rollback=$(grep -ciE "$ROLLBACK_KEYWORDS" "$spec_file" 2>/dev/null || true)
    has_rollback=${has_rollback:-0}
    has_rollback=$(echo "$has_rollback" | xargs)
    [[ "$has_rollback" =~ ^[0-9]+$ ]] || has_rollback=0
    if [[ "$has_rollback" -ge 1 ]]; then
      pass "spec 含回滚预案声明（$has_rollback 处提及）"
    else
      fail "spec 无回滚预案声明——须含回滚方式+验证+窗口"
      found=1
    fi
  fi

  # 2c. 数据库迁移无破坏性 DDL（warn）
  if [[ ${#MIGRATION_DIRS[@]} -gt 0 ]]; then
    local breaking=0
    local md
    for md in "${MIGRATION_DIRS[@]}"; do
      [[ -d "$md" ]] || continue
      local hits; hits=$(grep -rnEi "$BREAKING_DDL_PATTERNS" "$md" 2>/dev/null | grep -v -i 'down\|rollback\|revert' || true)
      if [[ -n "$hits" ]]; then
        warn "迁移目录 $md 含破坏性 DDL（DROP/TRUNCATE），须确认向前兼容或双写期："
        echo "$hits" | head -5
        breaking=1
      fi
    done
    [[ $breaking -eq 0 ]] && pass "迁移目录无破坏性 DDL（或均在 down/rollback 段）"
  fi

  echo "  ── 运维监控左移（spec §21 可观测性 + 代码埋点 + 健康检查）──"

  # 3a. spec §21 可观测性段存在（warn）
  if [[ -n "$obs_file" && -f "$obs_file" ]]; then
    if grep -qE '^## .*21.*可观测性|^## §21' "$obs_file" 2>/dev/null; then
      pass "spec §21 可观测性约束段存在"
    else
      warn "spec 缺 §21 可观测性约束段——日志/metrics/trace/告警须在 spec 阶段写"
      found=1
    fi
  else
    warn "未找到 spec 文件，跳过 §21 可观测性段检查"
  fi

  # 3b. 代码中 metrics/日志/trace 埋点存在（warn）
  local scan_targets=()
  for d in "${WRITABLE_DIRS[@]}"; do [[ -d "$d" ]] && scan_targets+=("$d"); done
  [[ ${#scan_targets[@]} -eq 0 ]] && scan_targets=(".")

  local metric_hits=0 log_hits=0 trace_hits=0
  for d in "${scan_targets[@]}"; do
    local mh lh th
    mh=$(grep -rlE "$METRIC_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs)
    lh=$(grep -rlE "$LOG_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs)
    th=$(grep -rlE "$TRACE_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs)
    metric_hits=$((metric_hits + ${mh:-0}))
    log_hits=$((log_hits + ${lh:-0}))
    trace_hits=$((trace_hits + ${th:-0}))
  done
  if [[ $metric_hits -gt 0 ]]; then
    pass "代码中检测到 metrics 埋点（$metric_hits 个文件）"
  else
    warn "代码中未检测到 metrics 埋点——可观测性约束要求 spec §21 的埋点清单在代码中实现"
  fi
  if [[ $log_hits -gt 0 ]]; then
    pass "代码中检测到日志埋点（$log_hits 个文件）"
  else
    warn "代码中未检测到日志埋点"
  fi
  if [[ $trace_hits -gt 0 ]]; then
    pass "代码中检测到 trace 埋点（$trace_hits 个文件）"
  else
    warn "代码中未检测到 trace 埋点（微服务/分布式项目建议加 traceId 透传）"
  fi

  # 3c. 健康检查端点可访问（warn）
  if [[ ${#HEALTH_CHECK_URLS[@]} -gt 0 ]]; then
    local hc
    for hc in "${HEALTH_CHECK_URLS[@]}"; do
      local code
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$HEALTH_CHECK_TIMEOUT" "$hc" 2>/dev/null || echo "000")
      if [[ "$code" == "200" ]]; then
        pass "健康检查端点可访问：$hc (200)"
      else
        warn "健康检查端点不可访问：$hc (HTTP $code)——服务须启动后才能验证"
      fi
    done
  fi

  if [[ $found -eq 0 ]]; then
    pass "左移检查通过（测试设计+变更影响+可观测性均已在 spec/plan 阶段嵌入）"
  else
    echo "  ⚠ 左移有 fail 项——测试/变更/运维约束须在 spec/plan 阶段写，不可后置"
  fi
}

# ===== 框架适配门禁（--framework）：由 --inject-frameworks 注入片段，动态分发 =====
check_framework() {
  echo "▶ 框架适配门禁 (--framework)"
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    # 漏配检测：探查信号明显但未配置 → warn
    local hit
    hit=$(find "${PROJECT_DIR:-.}" -name '*Mapper.xml' -not -path '*/node_modules/*' 2>/dev/null | head -1)
    [[ -n "$hit" ]] && warn "发现 $hit 但 ACTIVE_FRAMEWORKS 未配置——疑似漏配 mybatis"
    skip_if_unconfigured "ACTIVE_FRAMEWORKS 未配置"; return
  fi
  local fw fn
  for fw in "${ACTIVE_FRAMEWORKS[@]}"; do
    fn="_fw_$(echo "$fw" | tr '-' '_')_check"
    if declare -f "$fn" >/dev/null 2>&1; then
      "$fn"
    else
      fail "框架 '$fw' 已激活但无门禁实现（$fn 缺失）——须运行 generate-skill.sh --inject-frameworks"
    fi
  done
}

# >>> swarm-yuan:framework-gates >>> （由 generate-skill.sh --inject-frameworks 维护，勿手改）
# <<< swarm-yuan:framework-gates <<<

# 将 *_FILE_GLOBS（含 ** 递归通配）解析为实际文件列表（兼容 bash 3.2 无 globstar）。
# 每个 glob 形如 "overlay/custom/client/**/*.vue" → find overlay/custom/client -name '*.vue'
# 输出：以空格分隔的文件路径串（供 unquoted 展开给 grep 作 path 参数）。
_fw_resolve_globs() {
  local g dir name
  for g in "$@"; do
    # 拆分为 ** 之前的目录前缀 与 末段文件名
    dir="${g%%/\*\*/*}"
    name="${g##*/}"
    # 若拆分后 dir == g 说明无 **，整体当作单个路径/文件
    if [[ "$dir" == "$g" ]]; then
      [[ -e "$g" ]] && printf '%s\n' "$g"
    else
      [[ -d "$dir" ]] || continue
      find "$dir" -type f -name "$name" 2>/dev/null
    fi
  done
}

# grep 计数包装：规避 set -e + pipefail 在无匹配（grep exit 1）时整体退出。
_fw_grep_count() {
  # $1=pattern, $@=files...
  local pat="$1"; shift
  { grep -rlE "$pat" "$@" 2>/dev/null || true; } | wc -l | xargs
}

case "$MODE" in
  --all)
    # 核心门禁（适用所有项目）：分支/范围/构建/敏感/一致性/审查/复用/依赖/安全/测试
    check_branch
    check_scope
    check_build
    check_sensitive
    check_consistency
    check_review
    check_reuse
    check_deps
    check_security
    check_test
    ;;
  --all-full)
    # 全部门禁（含架构/认知门禁，未配置的静默跳过）
    check_branch
    check_scope
    check_build
    check_sensitive
    check_consistency
    check_review
    check_reuse
    check_deps
    check_security
    check_layer
    check_stable_diff
    check_link_depth
    check_adr
    check_contract
    check_consistency_cross
    check_impact
    check_service
    check_api
    check_state
    check_frontend
    check_cognition
    check_domain
    check_knowledge
    check_mermaid
    check_shift_left
    check_framework
    check_test
    ;;
  --branch) check_branch ;;
  --scope) check_scope ;;
  --build) check_build ;;
  --test) check_test ;;
  --sensitive) check_sensitive ;;
  --consistency) check_consistency ;;
  --review) check_review ;;
  --reuse) check_reuse ;;
  --deps) check_deps ;;
  --security) check_security ;;
  --layer) check_layer ;;
  --stable-diff) check_stable_diff ;;
  --link-depth) check_link_depth ;;
  --adr) check_adr ;;
  --contract) check_contract ;;
  --consistency-cross) check_consistency_cross ;;
  --impact) check_impact ;;
  --service) check_service ;;
  --api) check_api ;;
  --state) check_state ;;
  --frontend) check_frontend ;;
  --cognition) check_cognition ;;
  --domain) check_domain ;;
  --knowledge) check_knowledge ;;
  --mermaid) check_mermaid ;;
  --shift-left) check_shift_left ;;
  --framework) check_framework ;;
  *)
    echo "Usage: bash precheck.sh [--all|--all-full|--branch|--scope|--build|--test|--sensitive|--consistency|--review|--reuse|--deps|--security|--layer|--stable-diff|--link-depth|--adr|--contract|--consistency-cross|--impact|--service|--api|--state|--frontend|--cognition|--domain|--knowledge|--mermaid|--shift-left|--framework]"
    exit 1
    ;;
esac

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "✓ 门禁检查通过"
  exit 0
else
  echo "✗ 门禁检查未通过，请修复上述问题"
  exit 1
fi

#!/usr/bin/env bash
# warn (21) 门禁（由 scripts/split-gates.sh 从 precheck.sh 抽取，决策 19）
# 被 precheck.sh source（开发态）或 install.sh 内联（打包态）。
# 不要单独执行——依赖 precheck.sh 主文件的 fail()/warn()/pass() 与全局变量。

check_scope() {
  echo "=== 改动范围检查 ==="
  local readonly_violation=0
  # 在 PROJECT_DIR 下检查 git diff，看是否有改动落在只读目录
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local changed; changed=$(_git_changed_files)
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
  if [[ -z "$TEST_CMD" || "$TEST_CMD" == "<test 命令>" ]]; then
    echo "  (跳过：未配置 TEST_CMD)"
    return
  fi
  if eval "$TEST_CMD" 2>&1 | tail -20; then
    pass "测试通过"
  else
    fail "测试失败"
  fi
}

_check_sensitive_gitleaks() {
  # 空 SCAN_DIRS 交回内置路径（与基线同一 warn 披露文案，避免双份漂移）
  [[ ${#SCAN_DIRS[@]} -eq 0 ]] && return 2
  local found=0 dir report hits files f rc
  for dir in ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
    [[ -d "$dir" ]] || continue
    report=$(mktemp)
    # --no-git 按文件系统扫描（与内置路径同口径）；--exit-code 0 统一由报告计数判定，不靠工具退出码
    rc=0
    gitleaks detect --no-git -s "$dir" --report-format json --report-path "$report" --exit-code 0 >/dev/null 2>&1 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      rm -f "$report"
      return 1
    fi
    # 报告为 JSON 数组：finding 元素含 RuleID（v8+）/rule（旧版）字段，元素数即命中数
    hits=$(grep -oE '"(RuleID|rule)"' "$report" 2>/dev/null | wc -l | xargs || true)
    hits=$(_norm_int "$hits")
    if [[ "$hits" -gt 0 ]]; then
      # 逐文件聚合去重（v8+ 字段 File；旧版小写 file 兜底）
      files=$(grep -oE '"File": ?"[^"]+"' "$report" 2>/dev/null | sed 's/"File": *"//; s/"$//' | sort -u || true)
      [[ -z "$files" ]] && files=$(grep -oE '"file": ?"[^"]+"' "$report" 2>/dev/null | sed 's/"file": *"//; s/"$//' | sort -u || true)
      while IFS= read -r f; do
        [[ -n "$f" ]] && fail "gate_sensitive_gitleaks:${f}: gitleaks 检出疑似硬编码密钥（GB/T 34944-2017 6.2.6.3）"
      done <<< "$files"
      found=1
    fi
    rm -f "$report"
  done
  if [[ $found -eq 0 ]]; then
    pass "未发现明显敏感信息（gitleaks）"
  fi
  return 0
}

check_sensitive() {
  echo "=== 敏感信息脱敏扫描（check §4 UI脱敏/日志）==="
  # 工具链降级（P1-3）：SENSITIVE_TOOL=auto/builtin/gitleaks；auto=有 gitleaks 用 gitleaks，否则内置
  # 内置路径（下方原逻辑）行为一字不变；gitleaks 执行失败降级内置（不静默 fail-open）
  local _sensitive_tool="${SENSITIVE_TOOL:-auto}"
  if [[ "$_sensitive_tool" == "auto" ]]; then
    if command -v gitleaks >/dev/null 2>&1; then _sensitive_tool="gitleaks"; else _sensitive_tool="builtin"; fi
  elif [[ "$_sensitive_tool" == "gitleaks" ]] && ! command -v gitleaks >/dev/null 2>&1; then
    warn "SENSITIVE_TOOL=gitleaks 但 gitleaks 未安装，降级内置正则扫描"
    _sensitive_tool="builtin"
  fi
  if [[ "$_sensitive_tool" == "gitleaks" ]]; then
    local _gitleaks_rc=0
    if _check_sensitive_gitleaks; then
      return
    else
      _gitleaks_rc=$?
    fi
    if [[ "$_gitleaks_rc" -eq 1 ]]; then
      warn "gitleaks 执行失败，降级内置正则扫描"
    fi
    # rc=2：SCAN_DIRS 空，落入内置路径的同文案披露
  fi
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
  # 空 SCAN_DIRS 为 fail-open 风险（原恒 pass「未发现」），改 warn 如实披露；判定语义不变
  if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
    warn "SCAN_DIRS 未配置，敏感信息扫描未执行（fail-open 风险）"
  fi
  for dir in ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
    [[ -d "$dir" ]] || continue
    for pattern in "${patterns[@]}"; do
      local matches
      matches=$(grep -rnE "$pattern" "$dir" \
        --include='*.ts' --include='*.vue' --include='*.svelte' --include='*.js' --include='*.mjs' \
        --include='*.patch' --include='*.py' --include='*.go' --include='*.rs' \
        --include='*.scss' --include='*.java' 2>/dev/null \
        | grep -viE 'example|placeholder|test|mock|dummy|<.*>' || true)
      if [[ -n "$matches" ]]; then
        fail "疑似敏感信息 ($dir):"
        echo "$matches" | head -10
        found=1
      fi
    done
  done
  [[ $found -eq 0 ]] && pass "未发现明显敏感信息"
}

check_review() {
  echo "=== 代码审查（check gstack/OCR 5 维度）==="
  local found=0

  if has_ocr; then
    pass "ocr 已安装"
    # 优先用 ocr review（diff 审查），有 git diff 时用 --from + --to
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local base; base=$(_git_base)
      local head_ref; head_ref=$(git rev-parse HEAD 2>/dev/null || echo "HEAD")
      trace_tool "ocr" "review --from $base --to $head_ref"
      local diff_output; diff_output=$(ocr review --from "$base" --to "$head_ref" --audience agent --format text 2>&1 || true)
      if [[ -n "$diff_output" && "$diff_output" != *"Error"* ]]; then
        echo "$diff_output" | tail -30
        # 检查是否有 High 级问题
        if echo "$diff_output" | grep -qiE 'high|critical|严重'; then
          fail "ocr review 检测到 High/Critical 级问题（须修复）"
          found=1
        fi
        # A 方向：pre-emit 引用门（gstack #1539 吸收，治 fail-open/误报）——
        # finding 须逐字引用动机代码行（file:line），缺引用的 finding 降级 warn 压出主报告。
        # "If you cannot quote the motivating line(s), the finding is unverified."
        local _noref_cnt
        _noref_cnt=$(echo "$diff_output" | grep -iE 'issue|finding|问题|风险|漏洞' \
          | grep -vE '[a-zA-Z0-9_/.-]+\.[a-zA-Z]+:[0-9]+' | grep -c . || true)
        if [[ "${_noref_cnt:-0}" -gt 0 ]]; then
          warn "pre-emit 引用门：${_noref_cnt} 条 finding 未引用动机代码行（file:line），按 gstack #1539 降级（未验证 finding 不进主报告）"
        fi
        # A 方向：FP 硬排除清单（gstack cso 22 条硬排除吸收，治误报）——
        # 已知误报类模式命中时降级提示（可配 FP_EXCLUSIONS，| 分隔的 ERE 模式）。
        # 内置默认排除：文档文件误报（md/txt 不是可执行代码）、注释行、test/mock 样本。
        local _fp_patterns="${FP_EXCLUSIONS:-README|\.md:|\.txt:|// |# |\* }"
        local _fp_cnt
        _fp_cnt=$(echo "$diff_output" | grep -iE 'issue|finding|问题|风险|漏洞' \
          | grep -E "$_fp_patterns" | grep -c . || true)
        if [[ "${_fp_cnt:-0}" -gt 0 ]]; then
          warn "FP 硬排除：${_fp_cnt} 条 finding 命中已知误报类（文档/注释/样本），降级提示（可配 FP_EXCLUSIONS 扩展）"
        fi
      else
        # --from/--to 失败时降级为 ocr scan
        warn "ocr review --from/--to 失败（可能无 diff 或参数不支持），降级 ocr scan"
        local scan_dirs=""; scan_dirs=$(printf '%s ' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}")
        if [[ -n "$scan_dirs" ]]; then
          trace_tool "ocr" "scan --path $scan_dirs"
          ocr scan --path "$scan_dirs" --audience agent --format text 2>&1 | tail -30 || true
        fi
      fi
    else
      # 非 git 仓库：用 ocr scan
      trace_tool "ocr" "scan"
      ocr scan --audience agent --format text 2>&1 | tail -30 || warn "ocr scan 返回非零"
    fi
  else
    warn "ocr 未安装，安装 ocr（npm i -g @alibaba-group/open-code-review）或由 AI 按 5 维度审查：正确性/安全/性能/可维护/测试覆盖"
    echo "  两遍清单：CRITICAL（SQL/竞态/注入/越权/路径穿越）+ INFORMATIONAL（命名/注释/风格）"
    echo "  严重度：High（必修）/ Medium（评估）/ Low（丢弃）"
    # A 方向：pre-emit 引用门指引（gstack #1539）——AI 审查每条 finding 须引用动机代码行（file:line），
    # 缺引用的 finding 视为未验证，压出主报告。置信度标定：high/medium/low，低置信压附录。
    echo "  pre-emit 引用门（gstack #1539）：每条 finding 须引用动机代码行（file:line），缺引用=未验证压出主报告"
    # A 方向：置信度标定 + FP 硬排除指引（gstack cso 吸收）——
    # finding 带置信度（high/medium/low，低置信压附录）；已知误报类（文档/注释/样本）先排除。
    echo "  置信度标定（gstack cso）：finding 带 high/medium/low 置信度，低置信压附录；FP 硬排除：文档/注释/test/mock 样本误报先过滤（可配 FP_EXCLUSIONS）"
  fi

  # 附加：如果装了 gstack，提示可用的扩展审查维度
  if [[ -d "$HOME/.claude/skills/gstack" ]]; then
    echo "  gstack 扩展审查可用：/cso（安全 OWASP+STRIDE）/ /investigate（根因调试）/ /codex（跨模型第二意见）/ /benchmark（性能）"
  fi

  # 附加：gsd-tools CLI 接线（WP1.3）：若装了 gsd-tools 且项目用了 gsd-core（有 .planning/ 或 .gsd/），
  # 跑 `gsd-tools validate health` 检查项目一致性健康度。status!=healthy → warn（项目配置问题，非代码缺陷，不 fail）。
  # 未装/项目未用 gsd-core 时降级（本函数上方 ocr/手动清单已覆盖代码审查）。
  if has_gsd_tools; then
    local gsd_root="${GSD_PROJECT_DIR:-$PROJECT_DIR}"
    if [[ -n "$gsd_root" && ( -d "$gsd_root/.planning" || -d "$gsd_root/.gsd" ) ]]; then
      trace_tool "gsd-tools" "validate health --cwd $gsd_root"
      local gsd_health; gsd_health=$(gsd-tools validate health --cwd "$gsd_root" 2>/dev/null || true)
      if [[ -n "$gsd_health" ]]; then
        local gsd_status; gsd_status=$(echo "$gsd_health" | grep -oE '"status"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"status"[[:space:]]*:[[:space:]]*"//;s/"$//')
        if [[ "$gsd_status" == "healthy" ]]; then
          pass "gsd-tools validate health: 项目一致性健康度通过"
        else
          warn "gsd-tools validate health: status=${gsd_status:-unknown}（项目 gsd-core 配置不一致，建议修复）"
          echo "$gsd_health" | grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' | head -5 | sed 's/^/    /'
        fi
      fi
    fi
  fi

  [[ $found -eq 0 ]] && pass "代码审查检查完成"
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
  local changed; changed=$(_git_changed_files)
  [[ -z "$changed" ]] && { pass "无变更，稳定单元篡改检查通过"; return; }

  # 匹配 stable globs
  declare -a stable_changed=()
  local c sg
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    for sg in "${STABLE_GLOBS[@]}"; do
      # 用 bash 的 extglob/globstar 近似匹配（** → 递归）
      shopt -s globstar extglob nullglob 2>/dev/null || true
      # 简单前缀匹配：把 glob 的 ** 之前部分作为前缀（% 最短匹配——与 check_layer §516 同款修复；
      # %% 会把 'overlay/custom/client/*/components/**' 误截成 'overlay/custom/client'，导致整目录被误判为稳定层改动）
      local prefix="${sg%/\**}"
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
  local spec_file
  spec_file=$(_first_existing_file "specs/spec-template.md" "spec-template.md" "docs/spec-template.md")
  if [[ -z "$spec_file" ]]; then
    for dir in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"} ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
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
    local base; base=$(_git_base)
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
      code_todos=$(_scan_src 'TODO|FIXME|HACK|XXX' 'ts,js,py,go' 'node_modules\|\.patch' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" | wc -l | xargs || true)
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
    warn "契约目录不存在：${CONTRACT_DIR}（新建 CONTRACT_DIR/ 并为每个 API 创建 YAML/JSON 文件，必含 version: x.y.z 字段）"
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
        [[ -d "$ctx_a" ]] || continue
        local af target
        while IFS= read -r af; do
          [[ -z "$af" ]] && continue
          while IFS= read -r target; do
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
          done < <(_resolve_rel_imports "$af")
        done < <(find "$ctx_a" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' \) 2>/dev/null)
      done
      pass "ACL 防腐层目录存在：${ACL_DIR}"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "接口契约检查通过"
  fi
}

check_impact() {
  echo "=== 变更影响分析检查（TOGAF：变更须含影响范围段 + 消费方清单）==="
  local found=0

  # ---- 1. 找 spec 文件（影响范围段应在此）----
  local spec_file="${IMPACT_SPEC_FILE:-$SPEC_FILE}"
  if [[ -z "$spec_file" ]]; then
    spec_file=$(_first_existing_file "specs/spec-template.md" "spec-template.md" "docs/spec-template.md")
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
    trace_tool "gitnexus" "detect_changes"
    local gn_impact; gn_impact=$(gitnexus detect_changes 2>/dev/null | head -30 || true)
    if [[ -n "$gn_impact" ]]; then
      local affected_count; affected_count=$(echo "$gn_impact" | grep -cE '^\s+\S' || true)
      if [[ "$affected_count" -gt 5 ]]; then
        warn "gitnexus 检测到 ${affected_count} 个受影响进程——变更影响范围较大，确认 spec 已列出受影响方"
      fi
      echo "  gitnexus detect_changes 输出（前 10 行）："
      echo "$gn_impact" | head -10 | sed 's/^/    /'
    fi
  elif has_graphify && graphify_built; then
    # WP-X: graphify God Nodes 变更影响检测（R6 P1：God Nodes 是变更风险放大器）
    trace_tool "graphify" "explain god-nodes"
    local gf_report; gf_report=$(graphify explain 2>/dev/null | head -50 || true)
    if echo "$gf_report" | grep -qiE 'god.node|hub|surprising'; then
      local god_count; god_count=$(echo "$gf_report" | grep -icE 'god.node|hub' || true)
      if [[ "$god_count" -gt 0 ]]; then
        warn "graphify 检出 ${god_count} 个 God Node（高扇入枢纽节点）——变更此类节点影响范围放大，确认 spec 已评估"
        echo "$gf_report" | grep -iE 'god.node|hub|surprising' | head -5 | sed 's/^/    /'
      fi
    fi
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # 降级：git diff + grep 反查消费方
    local changed; changed=$(_git_changed_files)
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
      call_count=$(_scan_src '(fetch|axios|httpClient|grpc|http\.request|requests\.)\(' 'ts,js,py' 'test\|mock\|node_modules' "$svc2" | wc -l | xargs || true)
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
    xa=$(_scan_src 'XAResource|XA_OPEN|2pc|two.?phase|distributed.?transaction|seata|@GlobalTransactional' 'ts,js,py,java' 'test\|mock\|node_modules' "$svc")
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
    has_io=$(_norm_int "${has_io:-0}")
    # 统计 JSX 标签出现次数（非行数），用 grep -o 计数
    has_render=$(grep -oE '<(div|span|ul|li|section|article|main|header|footer|table|button|input|form|p|h[1-6])' "$cf2" 2>/dev/null | wc -l | xargs || true)
    has_render=$(_norm_int "${has_render:-0}")
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
    local circ _circ_err
    _circ_err=$(mktemp "${TMPDIR:-/tmp}/swarm-yuan-madge.XXXXXX")
    circ=$(madge --circular --extensions ts,tsx,js,jsx "$COMPONENT_DIR" 2>"$_circ_err" || true)
    if echo "$circ" | grep -qi 'circular'; then
      fail "检测到组件循环依赖（madge）——A↔B 互相 import 会导致运行时 undefined："
      echo "$circ" | sed 's/^/    /'
      found=1
    elif [[ -z "$circ" && -s "$_circ_err" ]]; then
      warn "madge 循环依赖检测执行失败（stderr: $(head -1 "$_circ_err" 2>/dev/null)）——本项未判定"
    fi
    rm -f "$_circ_err"
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

check_domain() {
  echo "=== 领域知识检查（动态识别→深入分析→客观规律违规检测）==="
  local found=0

  # ---- 1. spec §18 领域知识段存在性 + 动态分析质量 ----
  local spec_file="${SPEC_FILE:-}"
  [[ -z "$spec_file" ]] && spec_file=$(_first_existing_file "spec-template.md" "specs/spec-template.md" "docs/spec-template.md")
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
  local rm_file
  rm_file=$(_first_existing_file "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md")
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
  pwd_violation=$(_scan_src "password\s*[=:]\s*['\"][^'\"]+['\"]" 'ts,js,py,java' 'test\|mock\|node_modules\|placeholder\|example\|xxx\|yyy' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}")
  if [[ -n "$pwd_violation" ]]; then
    fail "违反安全客观规律：检测到密码明文存储（密码必须哈希，不可明文）"
    echo "$pwd_violation" | head -3 | sed 's/^/    /'
    found=1
  fi
  # 3b. 数据库常识：SQL 拼接（非参数化）
  local sql_violation
  sql_violation=$(_scan_src "SELECT.*\+.*FROM|INSERT.*\+.*VALUES|WHERE.*\+.*=" 'ts,js,py,java' 'test\|mock\|node_modules' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}")
  if [[ -n "$sql_violation" ]]; then
    fail "违反数据库客观规律：检测到 SQL 字符串拼接（必须参数化查询，防注入）"
    echo "$sql_violation" | head -3 | sed 's/^/    /'
    found=1
  fi
  # 3c. 前端常识：v-html / dangerouslySetInnerHTML 直接拼接动态内容（排除 sanitize/renderMarkdown/DOMPurify 等消毒场景）
  local xss_violation
  xss_violation=$(_scan_src 'v-html|dangerouslySetInnerHTML|innerHTML\s*=' 'vue,svelte,tsx,jsx,ts,js' 'test\|mock\|node_modules' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" \
    | grep -viE 'sanitize|renderMarkdown|DOMPurify|escape|encode|sanitizeHtml|marked\(|markdownit' || true)
  if [[ -n "$xss_violation" ]]; then
    warn "潜在前端客观规律违反：v-html/innerHTML 使用但未检测到消毒函数（sanitize/renderMarkdown/DOMPurify）。如已消毒请人工确认"
    echo "$xss_violation" | head -3 | sed 's/^/    /'
  fi
  # 3d. 并发常识：共享可变状态无锁
  local race_violation
  race_violation=$(_scan_src 'global\s+\w+\s*=|window\.\w+\s*=' 'ts,js' 'test\|mock\|node_modules\|config\|const\|readonly' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}")
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
    trace_tool "claude-mem" "search project rules conventions"
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
  local skill_file
  skill_file=$(_first_existing_file "$PROJECT_DIR/.claude/skills/*/SKILL.md" ".claude/skills/*/SKILL.md" "SKILL.md")
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

check_docs_pack() {
  echo "=== 交付文档包完备性检查（GB/T 8567/9386、RUSP）==="
  [[ -z "${DOCS_PACK_PROFILE:-}" ]] && { skip_if_unconfigured "DOCS_PACK_PROFILE 未配置"; return; }
  local docs_dir="${DOCS_PACK_DIR:-docs}"
  local required=()
  case "$DOCS_PACK_PROFILE" in
    rusp)
      # RUSP（GB/T 25000.51）内置清单
      required=("产品说明" "用户手册" "测试计划" "测试说明" "测试报告")
      ;;
    gbt9386)
      # GB/T 9386 测试文档内置清单（4 计划/说明 + 4 报告/日志）
      required=("测试计划" "测试设计说明" "测试用例说明" "测试规程说明" "测试项传递报告" "测试日志" "测试事件报告" "测试总结报告")
      ;;
    gbt8567|custom)
      # gbt8567 与 custom 均取 DOCS_PACK_REQUIRED 自定义清单
      required=(${DOCS_PACK_REQUIRED[@]+"${DOCS_PACK_REQUIRED[@]}"})
      ;;
    *)
      warn "未知 DOCS_PACK_PROFILE：${DOCS_PACK_PROFILE}（按 custom 处理，取 DOCS_PACK_REQUIRED）"
      required=(${DOCS_PACK_REQUIRED[@]+"${DOCS_PACK_REQUIRED[@]}"})
      ;;
  esac
  [[ ${#required[@]} -eq 0 ]] && { skip_if_unconfigured "文档包必备清单为空（profile=${DOCS_PACK_PROFILE}）"; return; }
  local found=0 req hit tbd
  for req in "${required[@]}"; do
    hit=""
    [[ -d "$docs_dir" ]] && hit=$(find "$docs_dir" -type f -name "*${req}*" 2>/dev/null | head -1)
    if [[ -z "$hit" ]]; then
      fail "gate_docs_pack_missing:${req}: 文档包缺少必备文档（${docs_dir} 下未找到 *${req}*）"
      found=1
      continue
    fi
    # TBD 扫描（ALLOW_TBD=1 时降级 warn）
    tbd=$(grep -nE 'TBD|待补充|待完善' "$hit" 2>/dev/null || true)
    if [[ -n "$tbd" ]]; then
      if [[ "${DOCS_PACK_ALLOW_TBD:-0}" == "1" ]]; then
        warn "gate_docs_pack_tbd:${hit}: 文档含 TBD（ALLOW_TBD=1 降级 warn）"
      else
        fail "gate_docs_pack_tbd:${hit}: 文档含 TBD/待补充占位"
        echo "$tbd" | head -5
        found=1
      fi
    fi
  done
  [[ $found -eq 0 ]] && pass "文档包完备性检查通过（profile=${DOCS_PACK_PROFILE}）"
}

check_crypto() {
  echo "=== 密码算法合规检查（GB/T 39786-2021 密评，国密白名单 SM2/SM3/SM4）==="
  local profile="${CRYPTO_PROFILE:-}"
  if [[ -z "$profile" ]]; then
    skip_if_unconfigured "CRYPTO_PROFILE 未配置（密评场景设为 gm）"
    return
  fi
  if [[ "$profile" != "gm" ]]; then
    warn "未知 CRYPTO_PROFILE：${profile}（当前仅内置 gm=GB/T 39786-2021 密评弱算法扫描），未执行"
    return
  fi
  local found=0 d f hits files
  if [[ ${#CRYPTO_SCAN_DIRS[@]} -eq 0 ]]; then
    # 与 check_sensitive 同姿态：profile 已启用但扫描目录未配置 → warn 如实披露 fail-open 风险
    warn "CRYPTO_SCAN_DIRS 未配置，密码算法扫描未执行（fail-open 风险）"
  fi
  local inc=(--include='*.java' --include='*.kt' --include='*.ts' --include='*.js' --include='*.py' --include='*.go')
  for d in ${CRYPTO_SCAN_DIRS[@]+"${CRYPTO_SCAN_DIRS[@]}"}; do
    if [[ ! -d "$d" ]]; then
      warn "CRYPTO_SCAN_DIRS 目录不存在：${d}（跳过该目录）"
      continue
    fi
    # 弱算法 ERE（\b 词界防 SHA1PRNG/DESede 误命中）；滤 example/mock 噪声与注释行
    hits=$(grep -rnE '\bMD5\b|\bSHA1\b|\bDES\b|RSA[-_]?1024|\bECDSA\b' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'example|mock|node_modules' \
      | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true)
    if [[ -n "$hits" ]]; then
      files=$(printf '%s\n' "$hits" | cut -d: -f1 | sort -u)
      while IFS= read -r f; do
        [[ -n "$f" ]] && fail "gate_crypto_weak_algorithm:${f}: 检出弱密码算法（MD5/SHA1/DES/RSA-1024/ECDSA；GB/T 39786 密评应用 SM2/SM3/SM4 白名单）"
      done <<< "$files"
      printf '%s\n' "$hits" | head -10 | sed 's/^/    /'
      found=1
    fi
  done
  # B 方向：国密正向使用核查（warn 级——加密场景判断难自动化，不 fail 避免误报淹没；
  # 依据 references/crypto-spec.md §3 国密选型；机构密评测评仍属线下）
  local _enc_use _gm_use _rng_hit
  for d in ${CRYPTO_SCAN_DIRS[@]+"${CRYPTO_SCAN_DIRS[@]}"}; do
    [[ -d "$d" ]] || continue
    # 国密正向核查：检测到加密操作但全目录无 SM2/SM3/SM4 引用 → warn
    _enc_use=$(grep -rlE '\bencrypt\b|\bdecrypt\b|加密|解密' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'example|mock|node_modules' | head -1 || true)
    _gm_use=$(grep -rlE '\bSM2\b|\bSM3\b|\bSM4\b' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'example|mock|node_modules' | head -1 || true)
    if [[ -n "$_enc_use" && -z "$_gm_use" ]]; then
      warn "gate_crypto_gm_positive: 检测到加密操作但未使用国密算法（GB/T 39786 密评场景须 SM2/SM3/SM4）：${_enc_use}"
    fi
    # 随机数质量：安全上下文（password/token/secret/key/加密 同行）使用弱随机数 → warn
    _rng_hit=$(grep -rnE 'Math\.random|\brand[[:space:]]*\(' "$d" --include='*.js' --include='*.ts' --include='*.py' 2>/dev/null \
      | grep -viE 'example|mock|node_modules' | grep -iE 'password|token|secret|key|加密' | head -1 || true)
    [[ -n "$_rng_hit" ]] && warn "gate_crypto_weak_rng: 安全上下文使用弱随机数（Math.random/rand），安全场景须 CSPRNG：${_rng_hit}"
  done
  if [[ $found -eq 0 ]]; then
    pass "密码算法合规检查通过（未检出弱算法；国密白名单 SM2/SM3/SM4）"
  fi
}

# 内置词法降级载体（check_sast_deep 两降级分支共用：TOOL=builtin 强制 / 工具执行失败降级）。
# 仅高危 sink 直查，与 check_security 互补不重复。$1=fail 消息（含降级缘由）；返回 0=有命中 1=无命中。
# 独立为 helper（非 check_* 命名）：gen-enforce-level.sh 只统计 check_* 函数体的 fail() 调用数，
# 共用 helper 使 check_sast_deep 保持 1 个 fail 点、落 warn 档（决策 19 分类规则：warn 1-2 fail）。
_sast_deep_lexical_scan() {
  local hits
  hits=$(grep -rnE '\beval\s*\(|\bexec\s*\(|Runtime\.getRuntime\(\)\.exec|child_process\.exec' "${SECURITY_SCAN_DIRS[@]}" \
    --include='*.java' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
    | grep -viE 'example|mock|node_modules' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true)
  [[ -z "$hits" ]] && return 1
  fail "$1"
  printf '%s\n' "$hits" | head -10 | sed 's/^/    /'
  return 0
}

check_sast_deep() {
  echo "=== 深度 SAST 检查（AST/数据流层；GB/T 34943/34944/34946-2017 源代码漏洞测试规范）==="
  if [[ ${#SECURITY_SCAN_DIRS[@]} -eq 0 ]]; then
    skip_if_unconfigured "SECURITY_SCAN_DIRS 未配置，深度 SAST 跳过"
    return
  fi
  local tool="${SAST_DEEP_TOOL:-auto}" sev="${SAST_DEEP_SEVERITY:-error}" found=0
  # SAST 豁免登记（5 字段：对象|规则|理由|审批人|日期；空理由视为无效豁免 → fail）
  local _sast_exempt=""
  if [[ ${#SAST_DEEP_EXEMPTIONS[@]} -gt 0 ]]; then
    local _sex _sex_id _sex_reason
    for _sex in "${SAST_DEEP_EXEMPTIONS[@]}"; do
      _sex_reason=$(printf '%s\n' "$_sex" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')
      if [[ -z "$_sex_reason" ]]; then
        fail "gate_sast_deep_exemption_invalid: SAST 豁免须为 5 字段（对象|规则|理由|审批人|日期）：${_sex}"
        return
      fi
      _sex_id=$(printf '%s\n' "$_sex" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
      _sast_exempt="${_sast_exempt}${_sex_id} "
    done
  fi
  _sast_exempted() { printf '%s\n' "$_sast_exempt" | grep -qF "$1"; }
  local bin=""
  # 载体解析：builtin=强制内置；可执行路径=直接调用（fixture mock 亦走此分支）；空/auto=降级链探测
  if [[ "$tool" == "builtin" ]]; then
    bin="builtin"
  elif [[ "$tool" != "auto" && -n "$tool" ]]; then
    if [[ -x "$tool" ]]; then bin="$tool"; else warn "SAST_DEEP_TOOL=${tool} 不可执行，降级自动探测"; fi
  fi
  if [[ -z "$bin" ]]; then
    if command -v semgrep >/dev/null 2>&1; then bin="semgrep"
    elif command -v opengrep >/dev/null 2>&1; then bin="opengrep"
    else bin="builtin"; fi
  fi
  if [[ "$bin" == "builtin" ]]; then
    # 自带降级载体（词法模式族，明示降级；AST/数据流层未执行）
    echo "  ⓘ 降级为内置词法模式族（semgrep/opengrep 不可用；AST/数据流层未执行）"
    trace_tool "sast-deep" "builtin-lexical"
    if _sast_deep_lexical_scan "gate_sast_deep_builtin: 内置模式族检出高危代码执行 sink（eval/exec/Runtime.exec/child_process.exec；GB/T 34943/34944/34946 漏洞类别，降级词法检出）："; then
      found=1
    fi
  else
    echo "  ⓘ SAST 载体：${bin}（AST/规则层）"
    trace_tool "sast-deep" "$bin"
    local json _rc=0
    json=$("$bin" scan --config p/default --json --quiet "${SECURITY_SCAN_DIRS[@]}" 2>/dev/null) || _rc=$?
    if [[ $_rc -ne 0 || -z "$json" ]]; then
      # 网络/规则包不可达（离线环境 p/default 拉取失败）→ 降级内置，明示
      warn "${bin} 执行失败或无输出（rc=${_rc}；离线环境规则包不可达）——降级内置词法模式族"
      if _sast_deep_lexical_scan "gate_sast_deep_builtin: 内置模式族检出高危代码执行 sink（${bin} 执行失败后降级检出；GB/T 34943/34944/34946 漏洞类别）："; then
        found=1
      fi
    else
      local _e _w
      _e=$(printf '%s\n' "$json" | grep -cE '"severity"[^,]*ERROR' || true)
      _w=$(printf '%s\n' "$json" | grep -cE '"severity"[^,]*WARNING' || true)
      echo "  ⓘ ${bin} 结果：ERROR=${_e} WARNING=${_w}"
      if [[ "$sev" == "warning" && $((_e+_w)) -gt 0 ]] || [[ "$sev" == "error" && "$_e" -gt 0 ]]; then
        if _sast_exempted gate_sast_deep_findings; then
          warn "gate_sast_deep_findings: ${bin} 检出达标严重级别发现（已豁免留痕）"
        else
          fail "gate_sast_deep_findings: ${bin} 检出达标严重级别（${sev}）以上发现 ERROR=${_e} WARNING=${_w}（GB/T 34943/34944/34946 漏洞类别）——详见 ${bin} JSON 输出"
          found=1
        fi
      fi
    fi
  fi
  [[ $found -eq 0 ]] && pass "深度 SAST 检查通过（载体：${bin}）"
}

# check_oss_eval（--oss-eval，WP-S1）：开源代码安全评价，GB/T 43848-2024 四维
# （来源/安全质量/知识产权/管理）。复用 --sbom 产物（SBOM_OUTPUT_DIR/SBOM_LICENSE_BLOCKLIST/
# SBOM_LICENSE_EXEMPTIONS），不重复扫描。2 个 fail 点 → warn 档。
# 措辞纪律：本标准将成分清单与许可证合规纳入评价体系，不宣称"强制提交 SBOM"。
check_oss_eval() {
  echo "=== 开源代码安全评价（GB/T 43848-2024：来源/安全质量/知识产权/管理四维）==="
  [[ "${OSS_EVAL_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "OSS_EVAL_REQUIRED 未启用，开源代码安全评价跳过"; return; }
  local found=0
  # ① 成分清单存在（复用 --sbom 产物；sbom 未跑时本门禁独立核验目录）
  local dir="${SBOM_OUTPUT_DIR:-.sbom}"
  local _sbom_files
  _sbom_files=$(find "$dir" -type f \( -name '*.json' -o -name '*.spdx' -o -name '*.xml' -o -name '*.txt' \) 2>/dev/null | head -20 || true)
  if [[ -z "$_sbom_files" ]]; then
    fail "gate_oss_eval_sbom_missing: 开源成分清单产物不存在（${dir}；GB/T 43848-2024 将成分清单纳入评价体系——先运行 --sbom 生成）"
    found=1
  fi
  # ② 许可证遵从（块名单扫描成分清单）
  if [[ -n "$_sbom_files" && ${#SBOM_LICENSE_BLOCKLIST[@]} -gt 0 ]]; then
    local lic _hits=""
    for lic in ${SBOM_LICENSE_BLOCKLIST[@]+"${SBOM_LICENSE_BLOCKLIST[@]}"}; do
      local h
      h=$(printf '%s\n' "$_sbom_files" | xargs grep -lF "$lic" 2>/dev/null || true)
      [[ -n "$h" ]] && _hits="${_hits}${lic}→$(printf '%s\n' "$h" | head -3 | tr '\n' ' ') "
    done
    if [[ -n "$_hits" ]]; then
      fail "gate_oss_eval_license_blocked: 成分清单命中许可证块名单：${_hits}（GB/T 43848-2024 知识产权维度：开源许可证遵从度评价）"
      found=1
    fi
  fi
  # ③ 上游来源登记（管理维度，warn-only）
  if [[ ! -f docs/upstream-baseline.md && ! -f UPSTREAM.md && ! -f docs/UPSTREAM.md ]]; then
    warn "未见上游来源登记文档（docs/upstream-baseline.md 或 UPSTREAM.md）——GB/T 43848-2024 来源维度建议登记开源成分来源"
  fi
  # ④ 豁免到期检查（warn-only：SBOM_LICENSE_EXEMPTIONS 五字段第 5 字段日期 < 今天）
  if [[ ${#SBOM_LICENSE_EXEMPTIONS[@]} -gt 0 ]]; then
    local today ex _d
    today=$(date -u +%Y-%m-%d)
    for ex in ${SBOM_LICENSE_EXEMPTIONS[@]+"${SBOM_LICENSE_EXEMPTIONS[@]}"}; do
      _d=$(printf '%s\n' "$ex" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}')
      if [[ -n "$_d" && "$_d" < "$today" ]]; then
        warn "开源许可证豁免已过期：${ex}（到期日 ${_d} < ${today}）——须复审或移除"
      fi
    done
  fi
  [[ $found -eq 0 ]] && pass "开源代码安全评价通过（成分清单在案，许可证未命中块名单）"
}

check_metrics() {
  echo "=== 度量门禁化检查（GB/T 25000.30 质量度量 / DevOps 度量趋势恶化告警）==="
  local runs_dir="${GATE_RUNS_DIR:-}"
  if [[ -z "$runs_dir" ]]; then
    skip_if_unconfigured "GATE_RUNS_DIR 未配置，度量检查跳过（无 gate-runs.jsonl 数据源）"
    return
  fi
  local jsonl="${runs_dir}/gate-runs.jsonl"
  if [[ ! -f "$jsonl" ]]; then
    skip_if_unconfigured "gate-runs.jsonl 不存在（${jsonl}）——度量检查跳过（首次运行无历史数据）"
    return
  fi
  local window="${METRICS_TREND_WINDOW:-3}"
  local found=0
  # 提取 strict 门禁列表（从 gate-enforce-level.conf）
  local _conf_dir _gel
  _conf_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _gel="${_conf_dir}/gate-enforce-level.conf"
  local _strict_gates=""
  if [[ -f "$_gel" ]]; then
    _strict_gates=$(grep -E '=strict$' "$_gel" 2>/dev/null | cut -d= -f1 || true)
  fi
  [[ -z "$_strict_gates" ]] && { warn "gate-enforce-level.conf 无 strict 门禁或文件缺失——度量趋势检查降级为全门禁"; _strict_gates=$(grep -oE '"gate":"[^"]*"' "$jsonl" 2>/dev/null | sed 's/"gate":"//;s/"//' | sort -u || true); }
  local _g _statuses _half _total _first_half _second_half _fh_pass _sh_pass _prev_rate _rate _declining=""
  for _g in $_strict_gates; do
    [[ -z "$_g" ]] && continue
    # 取该门禁最近 N 次状态
    _statuses=$(grep -F "\"gate\":\"$_g\"" "$jsonl" 2>/dev/null | grep -oE '"status":"[^"]*"' | sed 's/"status":"//;s/"//' | tail -"$window" || true)
    [[ -z "$_statuses" ]] && continue
    _total=$(printf '%s\n' "$_statuses" | grep -c . || true)
    [[ "$_total" -lt 2 ]] && continue
    _half=$((_total / 2))
    [[ "$_half" -eq 0 ]] && _half=1
    _first_half=$(printf '%s\n' "$_statuses" | head -"$_half" || true)
    _second_half=$(printf '%s\n' "$_statuses" | tail -"$((_total - _half))" || true)
    _fh_pass=$(printf '%s\n' "$_first_half" | grep -c 'pass' || true)
    _sh_pass=$(printf '%s\n' "$_second_half" | grep -c 'pass' || true)
    _prev_rate=$((_fh_pass * 100 / _half))
    _rate=$((_sh_pass * 100 / (_total - _half)))
    if [[ "$_rate" -lt "$_prev_rate" ]]; then
      _declining="${_declining}${_g}(${_prev_rate}%→${_rate}%) "
    fi
  done
  if [[ -n "$_declining" ]]; then
    fail "gate_metrics_trend_declining: strict 门禁通过率趋势恶化：${_declining}（窗口 ${window} 次；GB/T 25000.30 度量反馈——质量退化信号，须排查根因）"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "度量趋势检查通过（strict 门禁通过率无恶化，窗口 ${window} 次）"
}

check_framework() {
  echo "▶ 框架适配门禁 (--framework)"
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    # 漏配检测：探查信号明显但未配置 → warn
    local hit
    hit=$(find "${PROJECT_DIR:-.}" -name '*Mapper.xml' -not -path '*/node_modules/*' 2>/dev/null | head -1)
    [[ -n "$hit" ]] && warn "发现 $hit 但 ACTIVE_FRAMEWORKS 未配置——疑似漏配 mybatis"
    skip_if_unconfigured "ACTIVE_FRAMEWORKS 未配置"; return
  fi
  local fw fn _run_list=()
  # --framework <id>：仅跑指定框架（单框架隔离）；未指定 id 则全量串联（兼容原行为）
  if [[ -n "${FRAMEWORK_ID:-}" ]]; then
    local _found=0 _cand
    for _cand in ${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}; do
      [[ "$_cand" == "$FRAMEWORK_ID" ]] && _found=1 && break
    done
    if [[ $_found -eq 0 ]]; then
      fail "框架 '$FRAMEWORK_ID' 不在 ACTIVE_FRAMEWORKS（${ACTIVE_FRAMEWORKS[*]}）——无法单跑"
      return
    fi
    _run_list=("$FRAMEWORK_ID")
    echo "  （单框架模式：仅 ${FRAMEWORK_ID}）"
  else
    _run_list=(${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"})
  fi
  for fw in ${_run_list[@]+"${_run_list[@]}"}; do
    fn="_fw_$(echo "$fw" | tr '-' '_')_check"
    if declare -f "$fn" >/dev/null 2>&1; then
      # || true 兜底：单个框架函数内若有命令返回非 0（如 grep 无匹配），
      # set -e 会触发整个 check_framework 退出，导致后续框架无法执行。
      # 框架函数内部的 pass/fail/warn 已自行记录检查结果，此处只须防止退出。
      "$fn" || true
    else
      fail "框架 '$fw' 已激活但无门禁实现（$fn 缺失）——须运行 generate-skill.sh --inject-frameworks"
    fi
  done
}


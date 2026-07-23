#!/usr/bin/env bash
# strict (17) 门禁（由 scripts/split-gates.sh 从 precheck.sh 抽取，决策 19）
# 被 precheck.sh source（开发态）或 install.sh 内联（打包态）。
# 不要单独执行——依赖 precheck.sh 主文件的 fail()/warn()/pass() 与全局变量。

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

check_layer() {
  echo "=== 分层边界检查（DDD：层穿透/倒置/循环/领域污染）==="
  local found=0

  if [[ ${#LAYER_DEFS[@]} -eq 0 || ${#LAYER_ORDER[@]} -eq 0 ]]; then
    skip_if_unconfigured "未配置 LAYER_DEFS/LAYER_ORDER，跳过分层检查"
    return
  fi

  # ---- 0. 优先用 gitnexus query 查跨层依赖（最准确）----
  if has_gitnexus && gitnexus_indexed; then
    trace_tool "gitnexus" "query cross-layer imports"
    local gn_layer_issues; gn_layer_issues=$(gitnexus query "cross-layer imports" --format text 2>/dev/null | head -20 || true)
    if [[ -n "$gn_layer_issues" ]]; then
      local issue_count; issue_count=$(echo "$gn_layer_issues" | grep -cE '^\s+\S' || true)
      if [[ "$issue_count" -gt 0 ]]; then
        warn "gitnexus 检测到 ${issue_count} 处可能的跨层依赖（详见输出）"
        echo "$gn_layer_issues" | head -5 | sed 's/^/    /'
      fi
      pass "分层检查增强（基于 gitnexus 代码图谱）"
    else
      # WP-D3：空结果也提示（修静默——原代码 gitnexus 无跨层问题时连 pass 都不打印）
      pass "gitnexus 查询跨层依赖:无问题"
    fi
  fi

  # 临时映射文件（兼容 bash 3.2，不用 declare -A）
  local tmp_file2layer tmp_layer2idx tmp_layer_files
  tmp_file2layer=$(mktemp); tmp_layer2idx=$(mktemp); tmp_layer_files=$(mktemp)
  # RETURN trap 会随外层函数（如 _gate_exec）返回二次触发——双引号定义期烘焙路径使其自包含，
  # 避免 set -u 下单引号延迟求值引用已销毁的局部变量；二次触发对已删文件 rm -f 为无害 no-op。
  trap "rm -f '$tmp_file2layer' '$tmp_layer2idx' '$tmp_layer_files'" RETURN

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
      # base 解析：去掉末尾的 /**（用 % 最短匹配，不能用 %% 最长匹配——%% 会跨越中间的 * 把
      # 'overlay/custom/client/*/components/**' 误截成 'overlay/custom/client'，导致 find 扫整个 client 目录，
      # 把 __tests__/adapters/composables 全归入 component 层，check_layer §3 大量误判）。
      local base="${g%/\*\*}"
      # base 可能含 * 通配（如 overlay/custom/client/*/components），[[ -d ]] 不展开 glob 会 false。
      # 用 compgen -d 展开 glob 为实际目录列表，逐个 find（兼容 bash 3.2）。
      if [[ -d "$base" ]]; then
        m=$(find "$base" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.java' \) 2>/dev/null || true)
      else
        # base 含 glob 字符，展开后逐个 find
        local expanded
        expanded=$(compgen -d "$base" 2>/dev/null || true)
        if [[ -n "$expanded" ]]; then
          local d
          while IFS= read -r d; do
            [[ -z "$d" ]] && continue
            local dm; dm=$(find "$d" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' -o -name '*.java' \) 2>/dev/null || true)
            [[ -n "$dm" ]] && m="${m}${m:+$'\n'}$dm"
          done <<< "$expanded"
        fi
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
  _norm() { local p="$1"; p="${p#"$_pd"/}"; p="${p#"$PROJECT_DIR"/}"; p="${p#./}"; printf '%s' "$p"; }
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
  if has_madge; then
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
          local target
          while IFS= read -r target; do
            [[ -z "$target" ]] && continue
            local other
            while IFS= read -r other; do
              [[ -z "$other" || "$other" == "$aname" ]] && continue
              local other_dir; other_dir=$(cd "$AGGREGATE_DIR/$other" 2>/dev/null && pwd -P || echo "$AGGREGATE_DIR/$other")
              if [[ "$target" == "$other_dir"* ]]; then
                fail "聚合跨边界对象引用：$af ($aname 聚合) 直接 import 了 $other 聚合的内部。聚合间应只引用 ID，不引用对象"
                found=1
              fi
            done < <(find "$AGGREGATE_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
          done < <(_resolve_rel_imports "$af")
        done < <(find "$ad" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' \) 2>/dev/null)
      done <<< "$aggs"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "分层边界检查通过（无穿透/倒置/领域污染/聚合跨引用）"
  fi
}

check_reuse() {
  echo "=== 复用合规检查（拼装式开发：禁止重复造轮子）==="
  local found=0

  # ---- 1. 硬门禁：spec-template.md §5.5 复用约束段必须已填写 ----
  # 找到最近一份 spec（项目内 specs/ 或当前目录）。
  # 注意：排除 *-template.md 模板文件——模板的 §5.5 checkbox 本就该是 [ ] 待用户复制后勾选，
  # 把模板当具体 spec 检会误判 fail（范式自举检查发现的缺陷）。
  local spec_file
  spec_file=$(_first_existing_file "specs/spec.md" "specs/spec-template.md" "spec-template.md" "docs/spec-template.md")
  # 兜底：在可改目录下找任意 *spec*.md 含 §5.5 标记，但排除 *-template.md / *template*.md。
  # 要求文件同时含"拼装合规声明"和 checkbox 结构（- [ ] 或 - [x]），避免误命中 USAGE/README 等引用文档。
  if [[ -z "$spec_file" ]] || [[ "$(basename "$spec_file")" == *template* ]]; then
    spec_file=""
    for dir in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"} ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
      if [[ -d "$dir" ]]; then
        local hit
        hit=$(grep -rliE '拼装合规声明' "$dir" --include='*.md' 2>/dev/null \
              | grep -vE 'template' \
              | while read -r f; do
                  grep -qE '^\s*-\s*\[[ x]\]' "$f" 2>/dev/null && echo "$f"
                done | head -1 || true)
        if [[ -n "$hit" ]]; then spec_file="$hit"; break; fi
      fi
    done
  fi

  if [[ -z "$spec_file" ]]; then
    # 无 spec 文档（项目本身无具体变更 spec，如范式仓库自身/纯工具仓库）：跳过而非 fail。
    # --all-full 静默跳过；显式 --reuse 时 warn 提示（拼装式开发项目应配 spec）。
    skip_if_unconfigured "未找到含 §5.5 复用约束段的 spec 文档（拼装式开发项目应在 specs/ 下配 spec；纯工具/范式仓库可跳过）"
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
  # 兜底候选含 glob：.claude/skills/<*>/references/reference-manual.md
  local ref_file
  ref_file=$(_first_existing_file "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md")

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
    local base; base=$(_git_base)
    local diff_add; diff_add=$(git diff "$base"...HEAD --diff-filter=A --name-only 2>/dev/null || true)
    [[ -z "$diff_add" ]] && diff_add=$(git diff HEAD --diff-filter=A --name-only 2>/dev/null || true)
    if [[ -n "$diff_add" ]]; then
      local new_count=0
      while IFS= read -r nf; do
        [[ -z "$nf" ]] && continue
        case "$nf" in
          *.ts|*.js|*.vue|*.py)
            local exports; exports=$(grep -cE '^\s*(export\s+)?(function|const|class|def)\s+[A-Za-z_]' "$nf" 2>/dev/null | head -1); exports=${exports:-0}
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
      | grep -viE 'test|mock|node_modules|\.patch|__fixtures__|__mocks__|\.spec\.|\.d\.ts|/dist/|/\.tmp/|/out/|/build/|/\.next/|/coverage/' || true
  done
}

_check_security_semgrep() {
  # 与内置路径同一目标集：WRITABLE_DIRS + SCAN_DIRS 去重（语义同下方原逻辑）
  local targets=() seen="" d
  for d in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"} ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
    [[ -z "$d" || ! -d "$d" ]] && continue
    case " $seen " in *" $d "*) continue ;; esac
    seen="$seen $d"; targets+=("$d")
  done
  [[ ${#targets[@]} -eq 0 ]] && return 2
  local out rc=0 err_hits
  out=$(mktemp)
  # --error：有命中（任意级）时退出码 1；0=无命中；≥2=执行错误（降级内置）
  semgrep --config auto --json --quiet --error -o "$out" "${targets[@]}" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -ge 2 ]]; then
    rm -f "$out"
    return 1
  fi
  # ERROR 级命中 → fail（WARNING/INFO 不判，与内置「硬 fail / 软 warn」分层语义一致）
  err_hits=$(grep -cE '"severity":[[:space:]]*"ERROR"' "$out" 2>/dev/null || true)
  err_hits=$(_norm_int "$err_hits")
  if [[ "$err_hits" -gt 0 ]]; then
    fail "gate_security_semgrep_error: semgrep ERROR 级命中 ${err_hits} 处（--config auto）"
    # 粗解析多行 JSON：同一 result 内 check_id/path 先于 extra.severity 出现，按序配对取前 10 条
    awk '
      /"check_id":/ { cid=$0; sub(/^.*"check_id":[[:space:]]*"/,"",cid); sub(/".*$/,"",cid) }
      /"path":/     { p=$0;   sub(/^.*"path":[[:space:]]*"/,"",p);   sub(/".*$/,"",p) }
      /"severity":[[:space:]]*"ERROR"/ { if (p != "") { print cid" @ "p; p="" } }
    ' "$out" 2>/dev/null | head -10 | sed 's/^/    /'
  else
    pass "semgrep 扫描通过（ERROR 级 0 命中）"
  fi
  rm -f "$out"
  return 0
}

check_security() {
  echo "=== 安全规范检查（OWASP Top 10 / 代码安全 / 网络安全）==="
  # 工具链降级（P1-3）：SECURITY_TOOL=auto/builtin/semgrep；auto=有 semgrep 用 semgrep，否则内置
  # 内置路径（下方原逻辑）行为一字不变；semgrep 执行失败降级内置（不静默 fail-open）
  local _security_tool="${SECURITY_TOOL:-auto}"
  if [[ "$_security_tool" == "auto" ]]; then
    if command -v semgrep >/dev/null 2>&1; then _security_tool="semgrep"; else _security_tool="builtin"; fi
  elif [[ "$_security_tool" == "semgrep" ]] && ! command -v semgrep >/dev/null 2>&1; then
    warn "SECURITY_TOOL=semgrep 但 semgrep 未安装，降级内置规则扫描"
    _security_tool="builtin"
  fi
  if [[ "$_security_tool" == "semgrep" ]]; then
    local _semgrep_rc=0
    if _check_security_semgrep; then
      return
    else
      _semgrep_rc=$?
    fi
    if [[ "$_semgrep_rc" -eq 1 ]]; then
      warn "semgrep 执行失败（rc≥2），降级内置规则扫描"
    fi
    # rc=2：无可扫目录，落入内置路径的同文案披露
  fi
  local found=0
  # 合并 WRITABLE_DIRS + SCAN_DIRS 并去重（避免同一目录扫两遍产生重复告警）
  local targets=() seen=""
  for d in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"} ${SCAN_DIRS[@]+"${SCAN_DIRS[@]}"}; do
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
    # ★TS/JS 生态安全形态豁免（机械可判，better-sqlite3/fetch 标准写法）：
    #   列名常量插值 ${COLS}（值仍经 ? 参数化）/ URL 模板经 encodeURIComponent / IN 占位符 ${placeholders}
    if echo "$line" | grep -qE '\$\{[A-Z_][A-Z_0-9]*\}|\$\{placeholders\}|encodeURIComponent'; then
      continue
    fi
    if [[ $in_whitelist -eq 1 ]]; then
      warn "MyBatis \${} 白名单命中（须人工确认安全）：$line"
    # ★语义豁免（变量经 sanitize 函数，ERE 不可判）：降级 warn 人工复核，不 fail
    elif echo "$line" | grep -qE '\$\{(safe|sanitized|escaped)[A-Za-z]*\}'; then
      warn "SQL 插值变量疑似已经 sanitize（须人工确认校验覆盖）：$line"
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

check_shift_left() {
  echo "=== 左移检查（Shift-Left：测试设计+变更影响+可观测性，防缺陷/变更/故障流入后段）==="
  local found=0

  # ---- 定位 spec 文件 ----
  local spec_file="${SPEC_FILE:-}"
  [[ -z "$spec_file" ]] && spec_file=$(_first_existing_file "spec-template.md" "specs/spec-template.md" "docs/spec-template.md")
  local test_design_file="${TEST_DESIGN_FILE:-$spec_file}"
  local obs_file="${OBSERVABILITY_FILE:-$spec_file}"

  # ---- 定位 plan 文件 ----
  local plan_file="${CHANGE_IMPACT_FILE:-}"
  [[ -z "$plan_file" ]] && plan_file=$(_first_existing_file "plan-template.md" "plans/plan-template.md" "docs/plan-template.md")

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
        warn "§19.2 用例骨架行数不足（${case_rows}），须覆盖正常/边界/异常路径"
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
    local base; base=$(_git_base)
    local test_commits impl_commits
    test_commits=$(git log --name-only --pretty=format: "$base..HEAD" 2>/dev/null | grep -E '\.test\.|\.spec\.|__tests__' | sort -u | wc -l | tr -d ' ' || true)
    impl_commits=$(git log --name-only --pretty=format: "$base..HEAD" 2>/dev/null | grep -vE '\.test\.|\.spec\.|__tests__|\.md$|\.json$|\.lock$' | grep -E '\.(ts|js|py|go|java|rs)$' | sort -u | wc -l | tr -d ' ' || true)
    # 防御：若值非纯数字（git log 异常输出多行），强制归 0
    test_commits=$(_norm_int "${test_commits:-0}")
    impl_commits=$(_norm_int "${impl_commits:-0}")
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
    has_rollback=$(_norm_int "${has_rollback:-0}")
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
      local hits; hits=$(grep -rnEi "$BREAKING_DDL_PATTERNS" "$md" 2>/dev/null | grep -viE 'down|rollback|revert' || true)
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
  for d in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}; do [[ -d "$d" ]] && scan_targets+=("$d"); done
  [[ ${#scan_targets[@]} -eq 0 ]] && scan_targets=(".")

  local metric_hits=0 log_hits=0 trace_hits=0
  for d in "${scan_targets[@]}"; do
    local mh lh th
    mh=$(grep -rlE "$METRIC_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs || true)
    lh=$(grep -rlE "$LOG_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs || true)
    th=$(grep -rlE "$TRACE_CODE_PATTERNS" "$d" 2>/dev/null --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' | wc -l | xargs || true)
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

check_compliance() {
  echo "=== 标准合规矩阵校验（25000.51/8566/8567+9386/安全/国际/门禁姿态）==="
  # 矩阵路径：优先 COMPLIANCE_MATRIX_FILE，缺省探测 SKILL_DIR/references/standards-compliance.md
  local matrix="${COMPLIANCE_MATRIX_FILE:-}"
  if [[ -z "$matrix" ]]; then
    # SKILL_DIR 用 _CONF_DIR（配置加载时已解析为绝对路径，规避 cd 后 $0 相对路径失效）
    local skill_dir cand
    skill_dir=$(cd "${_CONF_DIR}/.." 2>/dev/null && pwd || echo "$PROJECT_DIR")
    cand="${skill_dir}/references/standards-compliance.md"
    [[ -f "$cand" ]] && matrix="$cand"
  fi
  if [[ -z "$matrix" || ! -f "$matrix" ]]; then
    if [[ -n "${COMPLIANCE_MATRIX_FILE:-}" ]]; then
      # 显式配置但文件不存在 → fail-closed
      fail "gate_compliance_matrix_missing: 配置的矩阵文件不存在：${COMPLIANCE_MATRIX_FILE}"
    else
      skip_if_unconfigured "标准合规矩阵未配置（references/standards-compliance.md 缺失）"
    fi
    return
  fi
  local found=0
  # 6 锚点默认集（与 references/standards-compliance.md 锚点契约一致，可用 COMPLIANCE_REQUIRED_SECTIONS 覆盖）
  local anchors=(
    '## A. GB/T 25000.51 八特性 × 门禁映射'
    '## B. GB/T 8566 过程 × 生成流程映射'
    '## C. GB/T 8567+9386 文档包 × 交付物映射'
    '## D. 安全标准 × 门禁映射（等保/三法/38674/34943/39786）'
    '## E. 国际工程标准映射（ISO 5055/SSDF/ASVS/SBOM-SLSA）'
    '## F. 门禁姿态与豁免登记'
  )
  if [[ ${#COMPLIANCE_REQUIRED_SECTIONS[@]} -gt 0 ]]; then
    anchors=("${COMPLIANCE_REQUIRED_SECTIONS[@]}")
  fi
  local a
  for a in "${anchors[@]}"; do
    if ! grep -qF "$a" "$matrix" 2>/dev/null; then
      fail "gate_compliance_anchor_incomplete:${a}: 矩阵缺少锚点章节"
      found=1
    fi
  done
  # 全文占位符扫描（骨架填充残留）
  local ph
  ph=$(grep -nE '待填充|（待填充）|<占位符>|填充指引' "$matrix" 2>/dev/null || true)
  if [[ -n "$ph" ]]; then
    fail "gate_compliance_placeholder: 矩阵存在未填充占位符："
    echo "$ph" | head -10
    found=1
  fi
  # SPEC_FILE 存在时查「## 22. 标准合规」段
  if [[ -n "${SPEC_FILE:-}" && -f "$SPEC_FILE" ]]; then
    if ! grep -qE '^## 22\. 标准合规' "$SPEC_FILE" 2>/dev/null; then
      fail "gate_compliance_spec_section_missing: spec 缺少「## 22. 标准合规」段"
      found=1
    fi
  fi
  # ---- WP-S1 标准映射表核验（STANDARDS_MAP_FILE 配置或默认探测；文件不存在则跳过）----
  local _smap="${STANDARDS_MAP_FILE:-}"
  if [[ -z "$_smap" ]]; then
    # 默认探测 SKILL_DIR/assets/standards-map.conf（SKILL_DIR 用 _CONF_DIR 推导，同矩阵探测口径）
    local _smap_dir _smap_cand
    _smap_dir=$(cd "${_CONF_DIR}/.." 2>/dev/null && pwd || echo "")
    _smap_cand="${_smap_dir}/assets/standards-map.conf"
    [[ -n "$_smap_dir" && -f "$_smap_cand" ]] && _smap="$_smap_cand"
  fi
  if [[ -n "$_smap" && -f "$_smap" ]]; then
    local _ln_no=0 _bad_fmt="" _bad_conf="" _row _nf _cf
    while IFS= read -r _row || [[ -n "$_row" ]]; do
      _ln_no=$((_ln_no+1))
      case "$_row" in ''|\#*) continue;; esac
      _nf=$(printf '%s\n' "$_row" | awk -F'|' '{print NF}')
      if [[ "$_nf" -ne 5 ]]; then
        _bad_fmt="${_bad_fmt}${_ln_no}行(${_nf}字段) "
        continue
      fi
      _cf=$(printf '%s\n' "$_row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}')
      case "$_cf" in high|medium|unverified) ;; *) _bad_conf="${_bad_conf}${_ln_no}行(${_cf}) ";; esac
    done < "$_smap"
    if [[ -n "$_bad_fmt" ]]; then
      fail "gate_compliance_standards_map_format: 标准映射表字段数≠5：${_bad_fmt}（须为 rule|cwe|gb_iso|asvs5|confidence 五字段）"
    fi
    if [[ -n "$_bad_conf" ]]; then
      fail "gate_compliance_standards_map_confidence: 标准映射表 confidence 非法值：${_bad_conf}（仅 high|medium|unverified）"
    fi
    [[ -z "$_bad_fmt" && -z "$_bad_conf" ]] && pass "标准映射表核验通过（${_smap}）"
  fi
  [[ $found -eq 0 ]] && pass "标准合规矩阵校验通过（锚点齐备，无占位符）"
}

check_sbom() {
  echo "=== SBOM 物料清单与许可证扫描 ==="
  [[ "${SBOM_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "SBOM_REQUIRED 未启用"; return; }
  local out_dir="${SBOM_OUTPUT_DIR:-.sbom}"
  local ts sbom_file lic_file
  ts=$(date '+%Y%m%d-%H%M%S')
  sbom_file="${out_dir}/sbom-${ts}.txt"
  lic_file="${out_dir}/licenses-${ts}.txt"
  mkdir -p "$out_dir" 2>/dev/null || true
  local generated=0 tool="${SBOM_TOOL:-}"
  # 工具降级链：$SBOM_TOOL → syft → cdxgen → 内置 lockfile 解析
  # SBOM_TOOL=none：显式屏蔽外部工具，强制走内置 lockfile 解析（无工具链环境依赖的确定性路径，
  # 修 fixture 环境依赖遗留——机器装有 syft/cdxgen 时 fixture 结果不应漂移）
  if [[ "$tool" == "none" ]]; then
    tool=""
  elif [[ -z "$tool" ]]; then
    if command -v syft >/dev/null 2>&1; then tool="syft"
    elif command -v cdxgen >/dev/null 2>&1; then tool="cdxgen"
    fi
  fi
  if [[ -n "$tool" ]] && command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      syft) syft "dir:${PROJECT_DIR:-.}" -o text > "$sbom_file" 2>/dev/null || true ;;
      cdxgen) cdxgen -o "$sbom_file" 2>/dev/null || true ;;
      *) "$tool" > "$sbom_file" 2>/dev/null || true ;;
    esac
    [[ -s "$sbom_file" ]] && generated=1
  fi
  if [[ $generated -eq 0 ]]; then
    # 内置 lockfile 解析（无外部工具时降级）：提取依赖名+版本
    local locks="" lf
    for lf in package-lock.json yarn.lock pnpm-lock.yaml go.sum requirements.txt pom.xml; do
      [[ -f "$lf" ]] && locks="${locks} ${lf}"
    done
    if [[ -z "$locks" ]]; then
      # 无工具且无 lockfile → fail-closed
      fail "gate_sbom_toolchain_unavailable: 无 SBOM 工具（syft/cdxgen）且未找到 lockfile，无法生成 SBOM"
      return
    fi
    : > "$sbom_file"
    for lf in $locks; do
      echo "# ${lf}" >> "$sbom_file"
      case "$lf" in
        package-lock.json)
          grep -oE '"node_modules/[^"]+"' "$lf" 2>/dev/null | sed 's/"node_modules\///; s/"$//' | sort -u >> "$sbom_file" || true ;;
        yarn.lock|pnpm-lock.yaml)
          grep -E '^[^#[:space:]][^:]*:' "$lf" 2>/dev/null | sed 's/["'\'']//g; s/:$//' | sort -u >> "$sbom_file" || true ;;
        go.sum)
          awk '{print $1" "$2}' "$lf" 2>/dev/null | sort -u >> "$sbom_file" || true ;;
        requirements.txt)
          grep -vE '^[[:space:]]*(#|$)' "$lf" 2>/dev/null >> "$sbom_file" || true ;;
        pom.xml)
          grep -oE '<artifactId>[^<]+</artifactId>' "$lf" 2>/dev/null | sed 's/<[^>]*>//g' | sort -u >> "$sbom_file" || true ;;
      esac
    done
    generated=1
  fi
  # license 提取：node_modules 下 package.json 的 license 字段
  : > "$lic_file"
  if [[ -d node_modules ]]; then
    find node_modules -maxdepth 2 -name package.json 2>/dev/null | while read -r pj; do
      local nm lic
      nm=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' "$pj" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//')
      lic=$(grep -oE '"license"[[:space:]]*:[[:space:]]*"[^"]+"' "$pj" 2>/dev/null | head -1 | sed 's/.*: *"//; s/"$//')
      [[ -n "$lic" ]] && echo "${nm:-unknown} ${lic}" >> "$lic_file"
    done
  fi
  # 许可证块名单扫描（license 清单 + SBOM 产物）
  local found=0 b hits _lic_line
  if [[ ${#SBOM_LICENSE_BLOCKLIST[@]} -gt 0 ]]; then
    for b in "${SBOM_LICENSE_BLOCKLIST[@]}"; do
      hits=$(grep -iE "$b" "$lic_file" 2>/dev/null || true)
      if [[ -n "$hits" ]]; then
        while IFS= read -r _lic_line; do
          [[ -n "$_lic_line" ]] && fail "gate_sbom_license_blocked:${_lic_line%% *}: 命中许可证块名单「${b}」（${_lic_line}）"
        done <<< "$hits"
        found=1
      fi
    done
  fi
  # 豁免登记：5 字段（对象|规则|理由|审批人|日期）校验 + 回显
  if [[ ${#SBOM_LICENSE_EXEMPTIONS[@]} -gt 0 ]]; then
    local ex nf
    for ex in "${SBOM_LICENSE_EXEMPTIONS[@]}"; do
      nf=$(awk -F'|' '{print NF}' <<< "$ex")
      if [[ "$nf" -ne 5 ]]; then
        fail "gate_sbom_exemption_invalid: 豁免须为 5 字段（对象|规则|理由|审批人|日期）：${ex}"
        found=1
      else
        echo "  ⓘ 豁免登记：${ex}"
      fi
    done
  fi
  # B 方向：CVE 漏洞阈值门禁（SCA 补全）——SBOM 生成后 grype --fail-on 扫描，超阈值 fail。
  # 姿态：skip_if_unconfigured（CVE_THRESHOLD 未配置静默跳过）→ 配置后 fail-closed。
  # 工具降级链 grype → osv-scanner（仅提示，无阈值判定能力）→ warn 跳过（fail-open 风险如实披露）。
  if [[ -n "${CVE_THRESHOLD:-}" && -s "$sbom_file" ]]; then
    if command -v grype >/dev/null 2>&1; then
      trace_tool "grype" "sbom cve scan"
      if ! grype "sbom:${sbom_file}" --fail-on "$CVE_THRESHOLD" >/dev/null 2>&1; then
        fail "gate_sbom_cve_threshold: SBOM 检出 ≥${CVE_THRESHOLD} 级 CVE（grype --fail-on ${CVE_THRESHOLD}；豁免须 5 字段留痕 CVE_EXEMPTIONS）"
        found=1
      fi
    elif command -v osv-scanner >/dev/null 2>&1; then
      trace_tool "osv-scanner" "sbom cve scan"
      osv-scanner --sbom="$sbom_file" >/dev/null 2>&1 || true
      warn "grype 不可用，降级 osv-scanner（无阈值判定能力，结果须人工复核阈值）"
    else
      warn "CVE_THRESHOLD=${CVE_THRESHOLD} 已配置但 grype/osv-scanner 均不可用，跳过漏洞扫描（fail-open 风险如实披露）"
    fi
  fi
  # CVE 豁免登记：5 字段（对象|规则|理由|审批人|日期）校验 + 回显（与许可证豁免同机制）
  # bash 3.2 + set -u：CVE_EXEMPTIONS 可能未声明（conf 默认注释），先判声明再取长度
  if [[ -n "${CVE_EXEMPTIONS+x}" && ${#CVE_EXEMPTIONS[@]} -gt 0 ]]; then
    local cex cnf
    for cex in "${CVE_EXEMPTIONS[@]}"; do
      cnf=$(awk -F'|' '{print NF}' <<< "$cex")
      if [[ "$cnf" -ne 5 ]]; then
        fail "gate_sbom_cve_exemption_invalid: CVE 豁免须为 5 字段（对象|规则|理由|审批人|日期）：${cex}"
        found=1
      else
        echo "  ⓘ CVE 豁免登记：${cex}"
      fi
    done
  fi
  [[ $found -eq 0 ]] && pass "SBOM 已生成：${sbom_file}（许可证块名单未命中，证据归档）"
}

check_privacy() {
  echo "=== 个人信息（PII）扫描（个保法 / GB/T 35273）==="
  [[ ${#PRIVACY_SCAN_DIRS[@]} -eq 0 ]] && { skip_if_unconfigured "PRIVACY_SCAN_DIRS 未配置"; return; }
  # 配置目录全不存在 → fail-closed
  local existing=() d
  for d in "${PRIVACY_SCAN_DIRS[@]}"; do
    [[ -d "$d" ]] && existing+=("$d")
  done
  if [[ ${#existing[@]} -eq 0 ]]; then
    fail "gate_privacy_dirs_missing: PRIVACY_SCAN_DIRS 配置的目录全部不存在：${PRIVACY_SCAN_DIRS[*]}"
    return
  fi
  # 内置 ERE：18 位身份证 / 手机号 / 16-19 位银行卡
  local patterns=(
    '[1-9][0-9]{5}(19|20)[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{3}[0-9Xx]'
    '1[3-9][0-9]{9}'
    '[0-9]{16,19}'
  )
  if [[ ${#PRIVACY_EXTRA_PATTERNS[@]} -gt 0 ]]; then
    patterns+=("${PRIVACY_EXTRA_PATTERNS[@]}")
  fi
  local found=0 pat kw hits pii_files=""
  for d in "${existing[@]}"; do
    for pat in "${patterns[@]}"; do
      # 滤 example/mock/dummy/placeholder/样例 噪声行；-I 跳过二进制
      hits=$(grep -rnIE "$pat" "$d" 2>/dev/null | grep -viE 'example|mock|dummy|placeholder|样例' || true)
      [[ -n "$hits" ]] && pii_files="${pii_files}$(echo "$hits" | cut -d: -f1)
"
    done
    # 敏感关键词（固定串、忽略大小写）
    if [[ ${#PRIVACY_SENSITIVE_KEYWORDS[@]} -gt 0 ]]; then
      for kw in "${PRIVACY_SENSITIVE_KEYWORDS[@]}"; do
        hits=$(grep -rniF "$kw" "$d" 2>/dev/null | grep -viE 'example|mock|dummy|placeholder|样例' || true)
        [[ -n "$hits" ]] && pii_files="${pii_files}$(echo "$hits" | cut -d: -f1)
"
      done
    fi
  done
  # 按文件聚合去重后逐文件 fail
  if [[ -n "$pii_files" ]]; then
    local f
    while IFS= read -r f; do
      [[ -n "$f" ]] && fail "gate_privacy_pii_found:${f}: 疑似个人信息命中（身份证/手机号/银行卡/敏感关键词）"
    done <<< "$(printf '%s' "$pii_files" | sort -u)"
    found=1
  fi
  # 豁免登记：5 字段（对象|规则|理由|审批人|日期）校验 + 回显
  if [[ ${#PRIVACY_EXEMPTIONS[@]} -gt 0 ]]; then
    local ex nf
    for ex in "${PRIVACY_EXEMPTIONS[@]}"; do
      nf=$(awk -F'|' '{print NF}' <<< "$ex")
      if [[ "$nf" -ne 5 ]]; then
        fail "gate_privacy_exemption_invalid: 豁免须为 5 字段（对象|规则|理由|审批人|日期）：${ex}"
        found=1
      else
        echo "  ⓘ 豁免登记：${ex}"
      fi
    done
  fi
  [[ $found -eq 0 ]] && pass "未发现个人信息泄露风险"
}

check_authz() {
  echo "=== 授权类弱点检查（CWE-862/863/639/284：服务端授权覆盖）==="
  [[ ${#AUTHZ_SCAN_DIRS[@]} -eq 0 ]] && { skip_if_unconfigured "AUTHZ_SCAN_DIRS 未配置"; return; }
  local found=0 d f hits files pat
  local inc=(--include='*.java' --include='*.kt' --include='*.ts' --include='*.js')
  for d in "${AUTHZ_SCAN_DIRS[@]}"; do
    if [[ ! -d "$d" ]]; then
      warn "AUTHZ_SCAN_DIRS 目录不存在：${d}（跳过该目录）"
      continue
    fi
    # —— 1. 敏感操作缺鉴权注解（粗放：文件含请求映射方法但全文无鉴权注解/安全配置声明）→ fail
    files=$(grep -rlE '@(Get|Post|Put|Delete|Patch|Request)Mapping' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'test|mock|node_modules' || true)
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if ! grep -qE '@PreAuthorize|@Secured|@RolesAllowed|SecurityFilter|@EnableWebSecurity|@RequiresPermissions|@PreAuth' "$f" 2>/dev/null; then
        fail "gate_authz_missing_check:${f}: 控制器含请求映射但无鉴权注解/安全配置（CWE-862 缺失授权）"
        found=1
      fi
    done <<< "$files"
    # —— 2. IDOR 风险：findById(request.…) / findById(…getParameter(…)) 用户可控主键直取 → fail
    hits=$(grep -rnE 'findById\(\s*request\.|findById\([^)]*getParameter\(' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'test|mock|node_modules' || true)
    if [[ -n "$hits" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && fail "gate_authz_idor:${f}: 用户可控主键直取对象（IDOR 风险，CWE-639）"
      done <<< "$(printf '%s\n' "$hits" | cut -d: -f1 | sort -u)"
      found=1
    fi
    # —— 3. CORS 全放行且带凭据（allowedOrigins("*") 与 allowCredentials(true) 同文件并存）→ fail
    files=$(grep -rlE 'allowedOrigins\(\s*"\*"\s*\)|allowedOriginPatterns\(\s*"\*"\s*\)' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'test|mock|node_modules' || true)
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if grep -qE 'allowCredentials\(\s*true\s*\)' "$f" 2>/dev/null; then
        fail "gate_authz_permissive:${f}: CORS allowedOrigins(\"*\") 且 allowCredentials(true)（CWE-284 不当访问控制）"
        found=1
      fi
    done <<< "$files"
    # —— 4. permitAll() 全放行 → warn-only（可能为有意公开端点，须人工复核，不计 fail）
    hits=$(grep -rnE 'permitAll\(\)' "$d" "${inc[@]}" 2>/dev/null \
      | grep -viE 'test|mock|node_modules' || true)
    if [[ -n "$hits" ]]; then
      warn "permitAll() 全放行 $(printf '%s\n' "$hits" | wc -l | xargs) 处（warn-only，确认均为有意公开端点）："
      printf '%s\n' "$hits" | head -5 | sed 's/^/    /'
    fi
    # —— 5. 自定义授权风险模式（AUTHZ_EXTRA_PATTERNS）→ warn-only
    if [[ ${#AUTHZ_EXTRA_PATTERNS[@]} -gt 0 ]]; then
      for pat in "${AUTHZ_EXTRA_PATTERNS[@]}"; do
        [[ -z "$pat" ]] && continue
        hits=$(grep -rnE "$pat" "$d" "${inc[@]}" 2>/dev/null | grep -viE 'test|mock|node_modules' || true)
        if [[ -n "$hits" ]]; then
          warn "授权自定义模式命中（warn-only，须人工复核）：${pat}"
          printf '%s\n' "$hits" | head -5 | sed 's/^/    /'
        fi
      done
    fi
  done
  echo "  提示: 授权铁律——服务端每个 API 默认拒绝、显式授权（OWASP ASVS V8 / CWE Top25:2025 授权类四弱点）"
  if [[ $found -eq 0 ]]; then
    pass "授权类弱点检查通过（fail 项未命中；warn 项请人工复核）"
  fi
}

check_requirements() {
  echo "=== 需求质量检查（ISO/IEC/IEEE 29148：无 TBD / 唯一 ID / EARS）==="
  local found=0 hits l
  # —— 0. OpenSpec CLI 接线（WP1.1）：若装了 openspec 且配置了 OPENSPEC_SPEC_DIR，
  #     跑 `openspec validate --all --strict` 校验 delta spec 合法性；未装/未配置则降级（下方文档检查已覆盖）。
  #     语义：openspec validate 退出码不稳定（部分版本 failed 时仍 rc=0），故靠输出判断——
  #     输出含 "failed" 且 "passed" 项为 0 → spec 非法 → fail。独立于 SPEC_FILE，openspec 有自己的 spec 目录。
  local ospec_dir="${OPENSPEC_SPEC_DIR:-}"
  # 相对路径解析为 PROJECT_DIR 下（与 precheck 其他路径解析一致；run-gate-fixture 不 cd 到 fixture，
  # cwd 可能是 swarm-yuan/，相对路径 openspec 会解析到错误位置）
  if [[ -n "$ospec_dir" && "${ospec_dir:0:1}" != "/" && -n "${PROJECT_DIR:-}" ]]; then
    ospec_dir="$PROJECT_DIR/$ospec_dir"
  fi
  if has_openspec && [[ -n "$ospec_dir" && -d "$ospec_dir" ]]; then
    trace_tool "openspec" "validate --all --strict $ospec_dir"
    local ospec_out; ospec_out=$(openspec validate --all --strict --no-interactive "$ospec_dir" 2>&1 || true)
    if echo "$ospec_out" | grep -qE '[1-9][0-9]* failed' && ! echo "$ospec_out" | grep -qE '[1-9][0-9]* passed'; then
      fail "gate_requirements_openspec_invalid: openspec validate 失败（delta spec 非法，详见输出）"
      echo "$ospec_out" | tail -10 | sed 's/^/    /'
      found=1
    else
      pass "openspec validate 通过（delta spec 合法）"
    fi
  fi
  local spec="${SPEC_FILE:-}"
  if [[ -z "$spec" || ! -f "$spec" ]]; then
    if [[ $found -eq 0 ]]; then
      skip_if_unconfigured "SPEC_FILE 未配置或不存在，需求 lint 跳过（openspec 守卫已在上方执行）"
      return
    fi
    # openspec 已 fail，仍返回非 0
    return 1
  fi
  # —— 1. TBD 零容忍（REQUIREMENTS_STRICT=1）：spec 含 TBD/待定/待明确 → fail（id 带行号）
  if [[ "${REQUIREMENTS_STRICT:-0}" == "1" ]]; then
    hits=$(grep -nE 'TBD|待定|待明确' "$spec" 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
      while IFS= read -r l; do
        [[ -n "$l" ]] && fail "gate_requirements_tbd:${l%%:*}: spec 含 TBD/待定/待明确（29148 要求需求集完备、不允许待定项）"
      done <<< "$hits"
      found=1
    fi
  fi
  # —— 2. 唯一标识（REQUIREMENTS_ID_REQUIRED=1）：需求条目（含 应当/应该/必须/shall/must 的列表项）缺 REQ- 编号 → fail
  if [[ "${REQUIREMENTS_ID_REQUIRED:-0}" == "1" ]]; then
    hits=$(grep -nE '^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+' "$spec" 2>/dev/null \
      | grep -E '应当|应该|必须|shall|must|SHALL|MUST' \
      | grep -vE 'REQ-[0-9A-Za-z-]+' || true)
    if [[ -n "$hits" ]]; then
      local noid_count
      noid_count=$(printf '%s\n' "$hits" | wc -l | xargs)
      fail "gate_requirements_no_id: ${noid_count} 条需求条目缺 REQ- 唯一编号（29148 要求每条需求可唯一标识）"
      printf '%s\n' "$hits" | head -10 | sed 's/^/    /'
      found=1
    fi
  fi
  # —— 3. EARS 句式覆盖率 → warn-only（粗估：需求句中含 当…时/如果/若/when/while/if 触发词的比例 <50% 提示）
  local total=0 ears=0
  total=$(_norm_int "$(grep -cE '应当|应该|必须|shall|must|SHALL|MUST' "$spec" 2>/dev/null || true)")
  ears=$(_norm_int "$(grep -cE '当.*时|如果|若|在.*时|when|while|if |When |While |If ' "$spec" 2>/dev/null || true)")
  if [[ "$total" -gt 0 ]]; then
    local pct=$((ears*100/total))
    if [[ "$pct" -lt 50 ]]; then
      warn "EARS 句式覆盖率约 ${pct}%（${ears}/${total}，<50%）——建议按 EARS（Ubiquitous/Event/State/Optional/Complex）改写需求句"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "需求质量检查通过（执法项未命中；EARS 覆盖率为 warn-only 提示）"
  fi
}

check_rtm() {
  echo "=== 需求追溯矩阵（RTM）检查（ISO/IEC/IEEE 29148：需求↔测试/矩阵追溯）==="
  [[ "${RTM_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "RTM_REQUIRED 未启用，RTM 检查跳过"; return; }
  local found=0
  local matrix="${RTM_MATRIX_FILE:-docs/rtm.md}"
  local matrix_ok=1
  if [[ ! -f "$matrix" ]]; then
    matrix_ok=0
    if [[ "${RTM_MATRIX_REQUIRED:-0}" == "1" ]]; then
      # fail-closed 锚点：声明矩阵强制而文件缺失即 fail 并返回（不再级联检查 REQ，防误报放大）
      fail "gate_rtm_matrix_missing: 追溯矩阵文件不存在：${matrix}（RTM_MATRIX_REQUIRED=1，fail-closed；可用 RTM_MATRIX_FILE 指定路径）"
      return
    fi
    warn "追溯矩阵文件不存在：${matrix}——降级为仅测试目录追溯（RTM_MATRIX_REQUIRED=1 可升级为 fail）"
  fi
  local spec="${SPEC_FILE:-}"
  if [[ -z "$spec" || ! -f "$spec" ]]; then
    warn "SPEC_FILE 未配置或不存在，无法提取 REQ- 编号——RTM 降级为仅矩阵存在性检查"
    pass "需求追溯矩阵检查通过（无需求源，0/0）"
    return
  fi
  # 从 spec 提取 REQ-[0-9]+ 编号集合（去重排序，与 --requirements 的 REQ- 机制同源）
  local reqs
  reqs=$(grep -oE 'REQ-[0-9]+' "$spec" 2>/dev/null | sort -u || true)
  if [[ -z "$reqs" ]]; then
    pass "需求追溯矩阵检查通过（spec 无 REQ- 编号条目，0/0）"
    return
  fi
  # 测试目录文件清单（TEST_DIR_PATTERNS 经 _fw_resolve_globs 解析，兼容 bash 3.2 无 globstar）
  local test_files=""
  if [[ ${#TEST_DIR_PATTERNS[@]} -gt 0 ]]; then
    test_files=$(_fw_resolve_globs ${TEST_DIR_PATTERNS[@]+"${TEST_DIR_PATTERNS[@]}"} || true)
  fi
  local total=0 traced=0 req hit _thits
  while IFS= read -r req; do
    [[ -z "$req" ]] && continue
    total=$((total+1))
    hit=0
    # 编号边界防护：REQ-001 不得误命中 REQ-0010（ERE 后置 [^0-9] 或行尾）
    if [[ $matrix_ok -eq 1 ]] && grep -qE "${req}([^0-9]|\$)" "$matrix" 2>/dev/null; then
      hit=1
    fi
    if [[ $hit -eq 0 && -n "$test_files" ]]; then
      _thits=$(printf '%s\n' "$test_files" | xargs grep -lE "${req}([^0-9]|\$)" 2>/dev/null || true)
      [[ -n "$_thits" ]] && hit=1
    fi
    if [[ $hit -eq 1 ]]; then
      traced=$((traced+1))
    else
      fail "gate_rtm_untraced:${req}: 需求未追溯——测试目录与追溯矩阵（${matrix}）均无 ${req} 引用（29148 RTM）"
      found=1
    fi
  done <<< "$reqs"
  local pct=$((traced*100/total))
  echo "  ⓘ 追溯率：${pct}%（${traced}/${total}，矩阵：${matrix}）"
  [[ $found -eq 0 ]] && pass "需求追溯矩阵检查通过（全部 ${total} 个 REQ 已追溯，追溯率 ${pct}%）"
}

check_dengbao() {
  echo "=== 等级保护 2.0 控制点映射检查（GB/T 22239-2019 安全计算环境/安全建设管理）==="
  local level="${DENGBAO_LEVEL:-}"
  if [[ -z "$level" ]]; then
    skip_if_unconfigured "DENGBAO_LEVEL 未配置（等保测评场景设 2 或 3）"
    return
  fi
  if [[ "$level" != "2" && "$level" != "3" ]]; then
    warn "未知 DENGBAO_LEVEL：${level}（仅支持 2/3），未执行"
    return
  fi
  local found=0
  # 豁免登记（四字段：规则id|理由|审批人|日期；空理由视为无效豁免不降级）
  local _exempt=""
  if [[ -n "${DENGBAO_EXEMPT_FILE:-}" && -f "${DENGBAO_EXEMPT_FILE}" ]]; then
    _exempt=$(awk -F'|' '!/^[[:space:]]*(#|$)/ { r=$2; gsub(/^[ \t]+|[ \t]+$/,"",r); if (r != "") { id=$1; gsub(/^[ \t]+|[ \t]+$/,"",id); print id } }' "$DENGBAO_EXEMPT_FILE" 2>/dev/null || true)
  fi
  _db_exempted() { printf '%s\n' "$_exempt" | grep -qF "$1"; }
  # 扫描目录就绪性（与 --crypto 同姿态：启用但留空 → warn 披露）
  if [[ ${#DENGBAO_SCAN_DIRS[@]} -eq 0 ]]; then
    warn "DENGBAO_SCAN_DIRS 未配置，MFA/审计代码证据扫描未执行（fail-open 风险）"
  fi
  local _scan_hits
  _scan_hits() { # $1=ERE；stdout=命中行（跨目录聚合，滤注释行与 example/mock）
    local d
    for d in ${DENGBAO_SCAN_DIRS[@]+"${DENGBAO_SCAN_DIRS[@]}"}; do
      [[ -d "$d" ]] || continue
      grep -rnE "$1" "$d" --include='*.java' --include='*.kt' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
        | grep -viE 'example|mock|node_modules' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true
    done
  }
  # ① 双因子鉴别（三级起强制：两种及以上组合且至少一种密码技术；GB/T 22239-2019 三级安全计算环境）
  if [[ "$level" == "3" ]]; then
    local _mfa
    _mfa=$(_scan_hits 'TOTP|GoogleAuthenticator|twoFactor|two_factor|2FA|\bMFA\b|\bOTP\b|短信验证码|动态口令')
    if [[ -z "$_mfa" ]]; then
      if _db_exempted gate_dengbao_mfa; then
        warn "gate_dengbao_mfa: 未检出双因子鉴别证据（已豁免留痕：${DENGBAO_EXEMPT_FILE}）"
      else
        fail "gate_dengbao_mfa: 等保三级要求双因子身份鉴别（口令+密码技术/生物技术等两种及以上组合）——DENGBAO_SCAN_DIRS 内未检出 TOTP/OTP/MFA/短信验证码等证据（GB/T 22239-2019）"
        found=1
      fi
    fi
  fi
  # ② 安全审计存在性（二级 warn / 三级 fail）
  local _audit
  _audit=$(_scan_hits 'audit|Audit|审计')
  if [[ -z "$_audit" ]]; then
    if [[ "$level" == "3" ]]; then
      if _db_exempted gate_dengbao_audit_missing; then
        warn "gate_dengbao_audit_missing: 未检出安全审计日志调用（已豁免留痕）"
      else
        fail "gate_dengbao_audit_missing: 未检出安全审计日志调用（audit/审计）——等保三级安全审计控制点要求记录并保护审计记录（GB/T 22239-2019）"
        found=1
      fi
    else
      warn "未检出安全审计日志调用（audit/审计）——等保二级建议补审计记录（GB/T 22239-2019）"
    fi
  fi
  # ③ 审计字段四要素声明（spec §23.2：日期时间/用户/事件类型/事件是否成功）
  local _spec="${SPEC_FILE:-}"
  if [[ -z "$_spec" || ! -f "$_spec" ]]; then
    if _db_exempted gate_dengbao_audit_fields; then
      warn "gate_dengbao_audit_fields: SPEC_FILE 未配置（已豁免留痕）"
    else
      fail "gate_dengbao_audit_fields: SPEC_FILE 未配置或不存在——无法核验审计字段四要素声明（spec §23.2 须声明：日期时间/用户/事件类型/事件是否成功）"
      found=1
    fi
  else
    local _fmiss=""
    grep -qF '日期时间' "$_spec" 2>/dev/null || _fmiss="${_fmiss}日期时间 "
    grep -qF '用户' "$_spec" 2>/dev/null || _fmiss="${_fmiss}用户 "
    grep -qF '事件类型' "$_spec" 2>/dev/null || _fmiss="${_fmiss}事件类型 "
    grep -qE '事件是否成功|成功与否' "$_spec" 2>/dev/null || _fmiss="${_fmiss}事件是否成功 "
    if [[ -n "$_fmiss" ]]; then
      if _db_exempted gate_dengbao_audit_fields; then
        warn "gate_dengbao_audit_fields: spec 审计字段声明缺：${_fmiss}（已豁免留痕）"
      else
        fail "gate_dengbao_audit_fields: spec §23.2 审计字段声明缺要素：${_fmiss}（GB/T 22239-2019：审计记录应包括事件的日期和时间、用户、事件类型、事件是否成功及其他审计相关信息）"
        found=1
      fi
    fi
    # ④ 等保级别一致性（spec 声明级别 vs DENGBAO_LEVEL）
    local _spec_lv
    _spec_lv=$(grep -oE '等保[^0-9]*[23]级' "$_spec" 2>/dev/null | grep -oE '[23]' | head -1 || true)
    if [[ -z "$_spec_lv" ]]; then
      warn "spec §23.2 未声明等保级别（建议补充「等保级别：X 级」）"
    elif [[ "$_spec_lv" != "$level" ]]; then
      if _db_exempted gate_dengbao_level_mismatch; then
        warn "gate_dengbao_level_mismatch: spec 声明 ${_spec_lv} 级 vs DENGBAO_LEVEL=${level}（已豁免留痕）"
      else
        fail "gate_dengbao_level_mismatch: spec 声明等保 ${_spec_lv} 级与 DENGBAO_LEVEL=${level} 不一致——立法（spec）与执法（conf）必须同源"
        found=1
      fi
    fi
  fi
  # ⑤ 个人信息保护勾稽（二级起要求；--privacy 须在配）
  if [[ ${#PRIVACY_SCAN_DIRS[@]} -eq 0 ]]; then
    if _db_exempted gate_dengbao_privacy_unconfigured; then
      warn "gate_dengbao_privacy_unconfigured: PRIVACY_SCAN_DIRS 未配置（已豁免留痕）"
    else
      fail "gate_dengbao_privacy_unconfigured: PRIVACY_SCAN_DIRS 未配置——等保二级起要求个人信息保护，须启用 --privacy 扫描（GB/T 22239-2019 个人信息保护控制点）"
      found=1
    fi
  fi
  # ⑥ 剩余信息保护（warn-only：敏感数据清除证据）
  local _resid
  _resid=$(_scan_hits 'Arrays\.fill|shred|secureErase|SecureRandom|清除敏感|内存清零')
  [[ -z "$_resid" ]] && warn "未检出剩余信息保护证据（敏感数据存储空间清除/释放，如 Arrays.fill/shred）——建议人工核对（GB/T 22239-2019 剩余信息保护）"
  [[ $found -eq 0 ]] && pass "等保 ${level} 级控制点映射检查通过（GB/T 22239-2019）"
}

check_pia() {
  echo "=== 隐私影响评估（PIA）检查（个人信息保护法第55-56条 / GB/T 35273-2020）==="
  [[ "${PIA_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "PIA_REQUIRED 未启用，PIA 检查跳过"; return; }
  local dir="${PIA_DOCS_DIR:-docs/privacy}"
  local found=0
  if [[ ! -d "$dir" ]]; then
    fail "gate_pia_doc_missing: PIA 文档目录不存在：${dir}（PIA_REQUIRED=1，fail-closed；个保法第55条：处理敏感个人信息等情形须事前进行个人信息保护影响评估）"
    return
  fi
  # ① PIA 评估文档存在性
  local _pia_doc
  _pia_doc=$(find "$dir" -maxdepth 2 -type f \( -iname '*pia*' -o -name '*隐私影响评估*' -o -name '*影响评估*' \) 2>/dev/null | head -1)
  if [[ -z "$_pia_doc" ]]; then
    fail "gate_pia_doc_missing: PIA 评估文档不存在（${dir} 下未见 *pia*/ *隐私影响评估* 文件；个保法第55-56条）"
    found=1
  fi
  # ② 个人信息处理活动清单存在性
  local _inv
  _inv=$(find "$dir" -maxdepth 2 -type f \( -name '*清单*' -o -iname '*inventory*' -o -iname '*register*' -o -iname '*activities*' \) 2>/dev/null | head -1)
  if [[ -z "$_inv" ]]; then
    fail "gate_pia_inventory_missing: 个人信息处理活动清单不存在（${dir} 下未见 *清单*/*inventory*/*register* 文件；GB/T 35273-2020 处理活动记录）"
    found=1
  fi
  # ③ PIA 文档零 TBD（评估报告不得含待定项）
  local _tbd
  _tbd=$(grep -rnE 'TBD|待定|待明确|待补充' "$dir" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_pia_tbd: PIA 文档含待定项（TBD/待定/待明确/待补充）——评估结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  # ④ 清单覆盖勾稽（warn-only：PRIVACY_SCAN_DIRS 各目录应在清单中有引用）
  if [[ -n "$_inv" && ${#PRIVACY_SCAN_DIRS[@]} -gt 0 ]]; then
    local d _base
    for d in ${PRIVACY_SCAN_DIRS[@]+"${PRIVACY_SCAN_DIRS[@]}"}; do
      _base=$(basename "$d")
      grep -qF "$_base" "$_inv" 2>/dev/null || warn "处理活动清单（${_inv}）未引用 PRIVACY_SCAN_DIRS 目录：${d}——请核对登记完整性"
    done
  fi
  [[ $found -eq 0 ]] && pass "PIA 检查通过（评估文档+处理活动清单齐备，零待定项）"
}

check_test_evidence() {
  echo "=== 测试证据链检查（GB/T 15532-2008 测试规范 / GB/T 9386-2008 测试文档）==="
  [[ "${TEST_EVIDENCE_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "TEST_EVIDENCE_REQUIRED 未启用，测试证据链检查跳过"; return; }
  local dir="${TEST_EVIDENCE_DIR:-docs/test}"
  if [[ ! -d "$dir" ]]; then
    fail "gate_test_evidence_missing: 测试证据文档目录不存在：${dir}（GB/T 15532-2008 须含测试计划/测试说明/测试报告）"
    return
  fi
  local found=0
  # ① 三类测试文档存在性（测试计划/测试说明/测试报告）
  local _plan _spec_doc _report
  _plan=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试计划*' -o -iname '*test*plan*' -o -iname '*plan*' \) 2>/dev/null | head -1)
  _spec_doc=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试说明*' -o -iname '*测试用例*' -o -iname '*test*case*' -o -iname '*test*spec*' \) 2>/dev/null | head -1)
  _report=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试报告*' -o -iname '*test*report*' \) 2>/dev/null | head -1)
  if [[ -z "$_plan" || -z "$_spec_doc" || -z "$_report" ]]; then
    local _miss=""
    [[ -z "$_plan" ]] && _miss="${_miss}测试计划 "
    [[ -z "$_spec_doc" ]] && _miss="${_miss}测试说明/用例 "
    [[ -z "$_report" ]] && _miss="${_miss}测试报告 "
    fail "gate_test_evidence_missing: 测试证据文档缺：${_miss}（GB/T 15532-2008 须含测试计划+测试说明+测试报告三类）"
    found=1
  fi
  # ② 测试报告含准出条件结论段
  if [[ -n "$_report" ]]; then
    if ! grep -qE '准出|验收结论|测试结论|pass.*criteria|exit.*criteria' "$_report" 2>/dev/null; then
      fail "gate_test_evidence_exit_missing: 测试报告缺准出条件结论段（${_report}）——GB/T 15532-2008 要求测试报告含验收准则与结论"
      found=1
    fi
  fi
  # ③ REQ- 编号勾稽（warn-only：测试文档中 REQ- 引用与 spec 抽样核对）
  local _spec="${SPEC_FILE:-}"
  if [[ -n "$_spec" && -f "$_spec" ]]; then
    local _reqs _req _hit
    _reqs=$(grep -oE 'REQ-[0-9]+' "$_spec" 2>/dev/null | sort -u || true)
    if [[ -n "$_reqs" ]]; then
      while IFS= read -r _req; do
        [[ -z "$_req" ]] && continue
        _hit=$(find "$dir" -type f -exec grep -lE "${_req}([^0-9]|\$)" {} \; 2>/dev/null | head -1 || true)
        [[ -z "$_hit" ]] && warn "测试文档未引用 ${_req}（测试证据链断链，建议补追溯）"
      done <<< "$_reqs"
    fi
  fi
  # ④ 零 TBD
  local _tbd
  _tbd=$(grep -rnE 'TBD|待定|待明确|待补充' "$dir" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_test_evidence_tbd: 测试证据文档含待定项——测试结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "测试证据链检查通过（计划+说明+报告齐备，含准出结论，零待定项）"
}

check_review_record() {
  echo "=== 评审记录与 AI 过程信息项检查（GB/T 8566-2022 评审过程 / ISO/IEC 42001 成文信息+可追溯）==="
  [[ "${REVIEW_RECORD_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "REVIEW_RECORD_REQUIRED 未启用，评审记录检查跳过"; return; }
  local dir="${REVIEW_RECORD_DIR:-docs/reviews}"
  if [[ ! -d "$dir" ]]; then
    fail "gate_review_record_missing: 评审记录目录不存在：${dir}（GB/T 8566-2022 评审过程要求留存评审记录）"
    return
  fi
  local found=0
  # ① 评审记录存在且含评审人/日期/结论三要素
  local _recs _rec
  _recs=$(find "$dir" -maxdepth 2 -type f \( -iname '*review*' -o -iname '*评审*' \) 2>/dev/null || true)
  if [[ -z "$_recs" ]]; then
    fail "gate_review_record_missing: 评审记录目录无评审文件（${dir} 下未见 *review*/*评审* 文件）"
    found=1
  else
    while IFS= read -r _rec; do
      [[ -z "$_rec" ]] && continue
      local _miss=""
      grep -qE '评审人|reviewer|审核人' "$_rec" 2>/dev/null || _miss="${_miss}评审人 "
      grep -qE '日期|date|时间' "$_rec" 2>/dev/null || _miss="${_miss}日期 "
      grep -qE '结论|conclusion|result|通过|不通过' "$_rec" 2>/dev/null || _miss="${_miss}结论 "
      if [[ -n "$_miss" ]]; then
        fail "gate_review_record_incomplete: 评审记录缺要素：${_miss}（${_rec}；GB/T 8566-2022 评审记录须含评审人/日期/结论）"
        found=1
      fi
      # 零 TBD
      if grep -qE 'TBD|待定|待明确|待补充' "$_rec" 2>/dev/null; then
        fail "gate_review_record_tbd: 评审记录含待定项（${_rec}）——评审结论必须完整"
        found=1
      fi
    done <<< "$_recs"
  fi
  # ② AI 过程信息项（AI_DISCLOSURE_REQUIRED=1 时）
  if [[ "${AI_DISCLOSURE_REQUIRED:-0}" == "1" ]]; then
    local _spec="${SPEC_FILE:-}"
    if [[ -n "$_spec" && -f "$_spec" ]]; then
      if ! grep -qE 'AI.*(生成|辅助|generated)|人工智能.*生成|AI-assisted' "$_spec" 2>/dev/null; then
        fail "gate_review_record_ai_undisclosed: spec 未声明 AI 辅助生成（AI_DISCLOSURE_REQUIRED=1）——ISO/IEC 42001 成文信息要求 AI 生成产物声明+人工复核记录"
        found=1
      fi
    fi
    # 人工复核记录存在性（warn-only）
    local _hr
    _hr=$(find "$dir" -type f -exec grep -lE '人工复核|human.*(review|verify)|人工审查' {} \; 2>/dev/null | head -1 || true)
    [[ -z "$_hr" ]] && warn "未见人工复核记录（AI_DISCLOSURE_REQUIRED=1 建议留存人工复核签字）"
  fi
  [[ $found -eq 0 ]] && pass "评审记录检查通过（评审人/日期/结论齐备，零待定项）"
}

check_release_sign() {
  echo "=== 发布签名与 provenance 检查（SLSA Build L2 / SSDF PS.2 发布完整性）==="
  [[ "${RELEASE_SIGN_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "RELEASE_SIGN_REQUIRED 未启用，发布签名检查跳过"; return; }
  local found=0
  # 工具降级：RELEASE_SIGN_TOOL（空=auto：有 cosign 用 cosign；"none"=强制存在性检查，无工具链环境依赖）
  local tool="${RELEASE_SIGN_TOOL:-}"
  if [[ "$tool" == "none" ]]; then
    tool=""
  elif [[ -z "$tool" ]] && command -v cosign >/dev/null 2>&1; then
    tool="cosign"
  fi
  if [[ -n "$tool" ]] && ! command -v "$tool" >/dev/null 2>&1; then
    warn "RELEASE_SIGN_TOOL=${tool} 不可用，降级为签名文件存在性检查"
    tool=""
  fi
  if [[ -z "$tool" ]]; then
    echo "  ⓘ 降级为签名文件存在性检查（cosign 不可用或未启用，SLSA 验签未执行）"
  fi
  # 产物枚举（glob 空格分隔；nullglob 展开防未命中模式退化为字面量；shopt 状态保存/恢复）
  local globs="${RELEASE_ARTIFACTS_GLOB:-dist/*.tar.gz dist/*.zip dist/*.jar}"
  local _ng_save
  _ng_save=$(shopt -p nullglob || true)
  shopt -s nullglob
  local artifacts=() a
  for a in $globs; do [[ -e "$a" ]] && artifacts+=("$a"); done
  eval "$_ng_save"
  if [[ ${#artifacts[@]} -eq 0 ]]; then
    warn "未匹配到发布产物（${globs}）——签名检查无对象"
  fi
  local sig ext vrc
  for a in ${artifacts[@]+"${artifacts[@]}"}; do
    sig=""
    for ext in .sig .asc .att .bundle; do
      if [[ -f "${a}${ext}" ]]; then sig="${a}${ext}"; break; fi
    done
    if [[ -z "$sig" ]]; then
      fail "gate_release_sign_missing:${a}: 发布产物缺伴随签名/证明（.sig/.asc/.att/.bundle 其一；SLSA Build L2 / SSDF PS.2）"
      found=1
      continue
    fi
    if [[ -n "$tool" ]]; then
      vrc=0
      if [[ -f "${a}.bundle" ]]; then
        "$tool" verify-blob --bundle "${a}.bundle" "$a" >/dev/null 2>&1 || vrc=$?
      elif [[ "$sig" == "${a}.sig" ]]; then
        "$tool" verify-blob --signature "$sig" "$a" >/dev/null 2>&1 || vrc=$?
      fi
      if [[ "$vrc" -ne 0 ]]; then
        fail "gate_release_sign_verify_failed:${a}: cosign verify-blob 验签失败（${sig}）"
        found=1
      fi
    fi
  done
  # SLSA provenance（RELEASE_PROVENANCE_REQUIRED=1，fail-closed）
  if [[ "${RELEASE_PROVENANCE_REQUIRED:-0}" == "1" ]]; then
    local prov="${RELEASE_PROVENANCE_FILE:-dist/provenance.json}"
    if [[ ! -f "$prov" ]]; then
      fail "gate_release_provenance_missing: SLSA provenance 文件不存在：${prov}（RELEASE_PROVENANCE_REQUIRED=1，fail-closed；可用 RELEASE_PROVENANCE_FILE 指定路径）"
      found=1
    elif ! grep -q '"predicateType"' "$prov" 2>/dev/null; then
      warn "provenance 文件未见 \"predicateType\" 字段（${prov}）——请确认为 in-toto/SLSA 格式"
    fi
  fi
  if [[ -n "$tool" ]]; then
    [[ $found -eq 0 ]] && pass "发布签名检查通过（${#artifacts[@]} 个产物签名齐备，cosign 验签通过）"
  else
    [[ $found -eq 0 ]] && pass "发布签名检查通过（${#artifacts[@]} 个产物签名齐备，存在性检查）"
  fi
}

# check_quality_model（--quality-model，WP-S2）：质量特性剪裁核验
# GB/T 25000.10-2016 八特性（功能适合性/性能效率/兼容性/易用性/可靠性/安全性/维护性/可移植性）
# 逐项适用/剪裁声明；ISO/IEC 25010:2023 新增 Safety（无害性/人身安全），国标暂无，主动对齐。
# 5 个 fail 点 → strict 档。启用后 fail-closed。
check_quality_model() {
  echo "=== 质量特性剪裁核验（GB/T 25000.10-2016 八特性 + ISO/IEC 25010:2023 Safety 主动对齐）==="
  [[ "${QUALITY_MODEL_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "QUALITY_MODEL_REQUIRED 未启用，质量特性剪裁核验跳过"; return; }
  local spec="${SPEC_FILE:-}"
  if [[ -z "$spec" || ! -f "$spec" ]]; then
    fail "gate_quality_model_missing: SPEC_FILE 未配置或不存在——无法核验质量特性剪裁表（spec §22 须含八特性逐项适用/剪裁声明）"
    return
  fi
  local found=0
  # ① 质量特性剪裁表存在性（spec 中须含质量特性剪裁表标题或至少一个八特性字段）
  local _qm_section
  _qm_section=$(grep -nE '质量特性剪裁表|^#+.*质量特性|质量模型|quality.*model|功能适合性|性能效率' "$spec" 2>/dev/null | head -1 || true)
  if [[ -z "$_qm_section" ]]; then
    fail "gate_quality_model_missing: spec 未声明质量特性剪裁表——须含 GB/T 25000.10-2016 八特性（功能适合性/性能效率/兼容性/易用性/可靠性/安全性/维护性/可移植性）逐项适用/剪裁声明"
    found=1
  fi
  # ② 八特性逐项覆盖（缺项 fail，列明缺失特性以利修复）
  local _ch _miss=""
  for _ch in 功能适合性 性能效率 兼容性 易用性 可靠性 安全性 维护性 可移植性; do
    grep -qF "$_ch" "$spec" 2>/dev/null || _miss="${_miss}${_ch} "
  done
  if [[ -n "$_miss" ]]; then
    fail "gate_quality_model_incomplete: 质量特性剪裁表缺特性：${_miss}（GB/T 25000.10-2016 八特性须逐项声明适用/剪裁+理由）"
    found=1
  fi
  # ③ Safety 维度声明（ISO/IEC 25010:2023 新增；国标 25000.10-2016 暂无，主动对齐）
  if ! grep -qE 'Safety|无害性|人身安全' "$spec" 2>/dev/null; then
    fail "gate_quality_model_safety: spec 未声明 Safety（无害性）维度——ISO/IEC 25010:2023 新增该特性，国标 GB/T 25000.10-2016 暂无，须主动对齐声明（适用/不适用+理由）"
    found=1
  fi
  # ④ 零 TBD（质量特性剪裁表不得含待定项）
  local _tbd
  _tbd=$(grep -nE 'TBD|待定|待明确|待补充' "$spec" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_quality_model_tbd: spec 含待定项（TBD/待定/待明确/待补充）——质量特性剪裁结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "质量特性剪裁核验通过（八特性+Safety 齐备，零待定项）"
}


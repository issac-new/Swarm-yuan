#!/usr/bin/env bash
# generate-skill.sh — swarm-yuan 目标技能脚手架生成器 / 升级器
# 用法:
#   bash generate-skill.sh <skill-name> <project-dir> [target-dir]       # 创建新技能骨架
#   bash generate-skill.sh --upgrade <skill-name> <project-dir> [target-dir]  # 升级已存在技能
#   bash generate-skill.sh --verify-completeness <skill-dir>   # 零占位符机器执法（骨架填充完成度校验）
#   bash generate-skill.sh --render-tools <skill-dir> [project-root] [tool]   # 派生各 AI 工具原生规则文件（幂等）
# 可选环境变量:
#   SKILLS_PATH_REWRITE — sed 表达式，复制通用文件后逐文件应用（create/upgrade 均生效；
#     缺省为空 = 不重写，行为不变）。用于目标运行时的 skills 目录不是 .claude/skills 的实例。
#     例: SKILLS_PATH_REWRITE='s|\.claude/skills|.agents/skills|g' \
#           bash generate-skill.sh --upgrade <skill-name> <project-dir> <target-dir>
# 作用:
#   创建模式: 自动检测运行环境，在对应 skill 默认目录下创建六段式骨架
#   升级模式: 用 swarm-yuan 最新模板覆盖通用文件，保留项目特定文件

set -euo pipefail

# ============================================================
# --inject-frameworks 子命令（独立于 create/upgrade，单独拦截）
# 用法: bash generate-skill.sh --inject-frameworks <skill-dir>
# 读取目标 skill 的 precheck.conf 中 ACTIVE_FRAMEWORKS，把对应门禁片段
# 幂等注入其 precheck.sh 的标记区块；核对/补齐 conf 变量；记录区块哈希。
# ============================================================
# ============================================================
# 已合并框架迁移映射（缺口 B 合并产物）
# key=旧独立 ruleset_id，value=母框架 ruleset_id
# 维护约定：后续若有新合并，在此追加映射 + 注释说明
# ============================================================
MERGED_FRAMEWORK_MAP=(
  "pinia:vue"        # B1: pinia 合并入 vue
  "socketio:koa"     # B3: socketio 合并入 koa
  "vitest:jest-vitest" # B2: vitest 合并入 jest-vitest
)

# ============================================================
# 通用文件清单（唯一数据源，create 复制 / upgrade 备份+覆盖 共用）
# 格式：目标相对路径|源类别（源文件统一按 basename 取自源目录）
#   assets = $ASSETS_DIR  ref = $SRC_REF  gen = $SRC_SCRIPTS（scripts/ 自身）
# 注：scripts/precheck.conf 仅 create 覆盖；upgrade 保留用户配置（merge_precheck_conf 增量补）
# ============================================================
# 通用文件清单：<目标路径>|<源类别>[|<最低 profile 档>]
# 档序 lite(1)<standard(2)<compliance(3)：骨架只拷「最低档 ≤ 当前档」的文件；
# 无第三段 = standard（向后兼容既有清单语义）。
UNIVERSAL_FILES=(
  "assets/spec-template.md|assets|lite"
  "assets/plan-template.md|assets|lite"
  "assets/branch-setup.sh|assets"
  "assets/env-setup.sh|assets"
  "assets/data-sample-template.md|assets"
  "assets/state-machine.sh|assets|lite"
  "assets/trace-log.sh|assets|lite"
  "assets/task-type-gates.conf|assets|lite"
  "assets/profile-thresholds.conf|assets|lite"
  "scripts/precheck.sh|assets|lite"
  "scripts/gates-strict.sh|assets|lite"
  "scripts/gates-warn.sh|assets|lite"
  "scripts/gates-advisory.sh|assets|lite"
  "scripts/gate-enforce-level.conf|assets|lite"
  "scripts/precheck.conf|assets|lite"
  "scripts/precheck.arch.conf|assets"
  "scripts/precheck.compliance.conf|assets|compliance"
  "scripts/snippets.md|assets"
  "scripts/mcp-tools.md|assets"
  "scripts/state-machine.sh|assets|lite"
  "scripts/trace-log.sh|assets|lite"
  "scripts/self-check.sh|gen|lite"
  "scripts/detect-frameworks.sh|gen|lite"
  "scripts/cost-report.sh|gen|lite"
  "scripts/detect-profile-drift.sh|gen|lite"
  "scripts/detect-spec-scale.sh|gen|lite"
  "scripts/task-scale.sh|gen|lite"
  "references/subagent-orchestration.md|ref"
  "references/review-methodology.md|ref"
  "references/code-graph-tools.md|ref"
  "references/gsd-patterns.md|ref"
  "references/memory-persistence.md|ref"
  "references/security-spec.md|ref|lite"
  "references/cognition-framework.md|ref|standard"
  "references/logic-razor.md|ref|standard"
  "references/cognitive-bias.md|ref|standard"
  "references/domain-knowledge.md|ref"
  "references/claude-code-capabilities.md|ref"
  "references/standards-compliance.md|ref|compliance"
)

# 项目特定文件（upgrade 保留不覆盖、不备份）
PROJECT_SPECIFIC_FILES=("SKILL.md" "references/workflow.md" "references/codebase.md" "references/dev-guide.md" "references/release.md" "references/reference-manual.md")

# 迁移 ACTIVE_FRAMEWORKS 里的旧 id 到母框架（原地修改全局 ACTIVE_FRAMEWORKS 数组）
# 迁移后 warn 提示用户更新 conf 的 ACTIVE_FRAMEWORKS 行
# 置全局 MIGRATION_HAPPENED=1 表示发生了迁移（供调用方判断是否写回 conf）
MIGRATION_HAPPENED=0
migrate_merged_frameworks() {
  MIGRATION_HAPPENED=0
  local fw new migrated=0 newlist=()
  for fw in "${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}"; do
    new="$fw"
    for m in "${MERGED_FRAMEWORK_MAP[@]+"${MERGED_FRAMEWORK_MAP[@]}"}"; do
      if [[ "$fw" == "${m%%:*}" ]]; then
        new="${m##*:}"
        echo "⚠ 框架 '$fw' 已合并入母框架 '$new'（conf 的 ACTIVE_FRAMEWORKS 将自动更新）"
        migrated=$((migrated+1))
        break
      fi
    done
    # 去重（母框架可能已在列表里）
    local dup=0
    for ex in "${newlist[@]+"${newlist[@]}"}"; do [[ "$ex" == "$new" ]] && { dup=1; break; }; done
    [[ "$dup" -eq 0 ]] && newlist+=("$new")
  done
  ACTIVE_FRAMEWORKS=("${newlist[@]+"${newlist[@]}"}")
  if [[ "$migrated" -gt 0 ]]; then
    MIGRATION_HAPPENED=1
    echo "  已迁移 $migrated 个旧框架 id 到母框架"
  fi
}

# upgrade 模式增量合并 precheck.conf：保留用户配置，只对【激活框架】缺失的 requires_conf 变量补占位
# 不触碰用户已填的任何行；只追加用户 ACTIVE_FRAMEWORKS 里框架声明但 conf 没有的变量
merge_precheck_conf() {
  local skill_dir="$1"
  local paradigm_dir; paradigm_dir="$(cd "$(dirname "$0")/.." && pwd)"
  local conf="$skill_dir/scripts/precheck.conf"
  [[ -f "$conf" ]] || { echo "⚠ precheck.conf 不存在，跳过合并"; return 0; }
  # WP-I：框架变量属 arch 组——补占位落 precheck.arch.conf（旧版 skill 无此文件则回落主 conf）
  local merge_target="$skill_dir/scripts/precheck.arch.conf"
  [[ -f "$merge_target" ]] || merge_target="$conf"
  # 读取用户 ACTIVE_FRAMEWORKS（含旧 id，迁移后补对应母框架变量）。
  # 子 shell 内 set +u source（conf 可能含字面 ${}），把数组逐行打印出来供当前 shell 读；
  # 子 shell 的变量带不出来，故只取打印输出。
  local _af
  _af=$( (
    set +u
    # shellcheck disable=SC1090
    . "$conf" 2>/dev/null
    printf '%s\n' "${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}"
  ) )
  # 迁移旧 id 到母框架，确定要补占位的框架清单
  local fws=() seen="" fw m new
  while IFS= read -r fw; do
    [[ -z "$fw" ]] && continue
    new="$fw"
    for m in "${MERGED_FRAMEWORK_MAP[@]+"${MERGED_FRAMEWORK_MAP[@]}"}"; do
      [[ "$fw" == "${m%%:*}" ]] && { new="${m##*:}"; break; }
    done
    case " $seen " in *" $new "*) continue;; esac
    seen="$seen $new"; fws+=("$new")
  done <<< "$_af"
  [[ ${#fws[@]} -eq 0 ]] && { echo "  （ACTIVE_FRAMEWORKS 为空，跳过变量补占位）"; return 0; }
  local frag var missing=()
  for fw in "${fws[@]}"; do
    frag="$paradigm_dir/assets/framework-gates/$fw.sh"
    [[ -f "$frag" ]] || continue
    local req
    req=$(sed -n 's/^# ruleset:.*requires_conf: *//p' "$frag" | tr -s ' ')
    for var in $req; do
      # WP-I：变量可能定义在主 conf 或 arch conf（物理三分），两处都查
      grep -q "^${var}=" "$conf" 2>/dev/null && continue
      [[ -f "$merge_target" ]] && grep -q "^${var}=" "$merge_target" 2>/dev/null && continue
      missing+=("$var")
    done
  done
  # 去重
  local uniq_missing=() useen=""
  for var in "${missing[@]+"${missing[@]}"}"; do
    case " $useen " in *" $var "*) continue;; esac
    useen="$useen $var"; uniq_missing+=("$var")
  done
  if [[ ${#uniq_missing[@]} -gt 0 ]]; then
    echo "" >> "$merge_target"
    echo "# ===== 由 upgrade 增量补充（激活框架需要的变量，用户未声明）=====" >> "$merge_target"
    for var in "${uniq_missing[@]}"; do
      printf '%s=()  # TODO(upgrade): 由用户按项目实际填充\n' "$var" >> "$merge_target"
      echo "⚠ conf 缺失变量 ${var}，已注入占位（须填充）"
    done
  fi
}

# WP-D3：trace_tool 辅助函数（全链路追踪——设计理念 2，generate-skill 侧）
# 定义在 inject_frameworks 之前，确保 --inject-frameworks 独立拦截分支也能调用。
# trace-log.sh 路径：脚本所在目录的 ../assets/trace-log.sh
_TRACE_LOG_SH="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/assets/trace-log.sh"
trace_tool() {  # $1=操作(create/inject/verify/upgrade) $2=说明
  [[ -f "$_TRACE_LOG_SH" ]] || return 0
  bash "$_TRACE_LOG_SH" --node "生成" --actor "generate-skill" --tool "$1" --status started --note "$2" >&2 2>/dev/null || true
}

inject_frameworks() {
  local skill_dir="$1"
  trace_tool "inject-frameworks" "$skill_dir"
  local paradigm_dir; paradigm_dir="$(cd "$(dirname "$0")/.." && pwd)"
  local sh="$skill_dir/scripts/precheck.sh"
  local conf="$skill_dir/scripts/precheck.conf"
  local ver="$skill_dir/.swarm-yuan-version"
  [[ -f "$sh" ]]  || { echo "✗ 未找到 $sh"; return 1; }
  [[ -f "$conf" ]] || { echo "✗ 未找到 $conf"; return 1; }
  # WP-I：框架变量属 arch 组——缺失判定与补占位落 precheck.arch.conf（旧版 skill 无此文件则回落主 conf）
  local arch_conf="$skill_dir/scripts/precheck.arch.conf"
  [[ -f "$arch_conf" ]] || arch_conf="$conf"

  # 冲突检测：若 .swarm-yuan-version 已记 framework_gates_sha，且现有区块哈希不符 → 裁决
  if [[ -f "$ver" ]]; then
    local old_sha; old_sha=$(grep '^framework_gates_sha=' "$ver" 2>/dev/null | cut -d= -f2- || true)
    if [[ -n "$old_sha" ]]; then
      local cur_sha; cur_sha=$(sed -n '/^# >>> swarm-yuan:framework-gates >>>/,/^# <<< swarm-yuan:framework-gates <<</p' "$sh" 2>/dev/null | cksum | awk '{print $1}')
      # 空区块（只有标记行）的 cksum 作为"未注入"基准；与 old_sha 不符即手改嫌疑
      if [[ "$cur_sha" != "$old_sha" && -n "$cur_sha" ]]; then
        echo "⚠ precheck.sh 框架门禁区块被手改（记录 sha=${old_sha}，当前 sha=${cur_sha}）"
        echo "  须用户裁决：覆盖（继续注入会丢失手改）或保留（中止）。中止。"
        return 2
      fi
    fi
  fi

  # 读取 ACTIVE_FRAMEWORKS（conf 可能含字面 ${} 如 SQL_INJECTION_WHITELIST，set -u 下会 unbound；
  # 在函数内临时关闭 set -u 做 source，读完立即恢复）
  ACTIVE_FRAMEWORKS=()
  set +u
  # shellcheck disable=SC1090
  # WP-R Bug#2: . "$conf" 末条语句可能返回非零（[[ -f ]] && source 兄弟 conf 不存在时返回 1），
  # set -e 下会使 inject_frameworks 退出。|| true 兜底（对齐 L827 既有范式）。
  . "$conf" || true
  set -u
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    echo "⚠ ACTIVE_FRAMEWORKS 未配置，跳过门禁注入"
    return 0
  fi

  # 迁移已合并的旧框架 id 到母框架（缺口 B 合并产物：pinia→vue / socketio→koa / vitest→jest-vitest）
  migrate_merged_frameworks

  # 若发生迁移，把迁移后的 ACTIVE_FRAMEWORKS 写回 conf（运行时 check_framework 遍历 conf 的 ACTIVE_FRAMEWORKS，
  # 不写回会导致旧 id 仍触发"无门禁实现"fail）。用 sed 替换 ACTIVE_FRAMEWORKS= 行，三平台兼容（mktemp+mv）。
  if [[ "$MIGRATION_HAPPENED" == "1" ]]; then
    local new_af_line="ACTIVE_FRAMEWORKS=("
    local first=1 fw
    for fw in "${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}"; do
      [[ "$first" -eq 1 ]] && first=0 || new_af_line="$new_af_line "
      new_af_line="${new_af_line}\"$fw\""
    done
    new_af_line="${new_af_line})"
    local conf_tmp; conf_tmp="$(mktemp /tmp/fwconf.XXXXXX)"
    # 替换首个 ACTIVE_FRAMEWORKS= 开头的行（用户可能在该行有注释，迁移后注释丢弃——可接受，因迁移是范式主动行为）
    awk -v line="$new_af_line" '/^ACTIVE_FRAMEWORKS=/{print line; next} {print}' "$conf" > "$conf_tmp"
    cat "$conf_tmp" > "$conf"
    rm -f "$conf_tmp"
    echo "  ✓ conf 的 ACTIVE_FRAMEWORKS 已更新为迁移后列表：${new_af_line#ACTIVE_FRAMEWORKS=}"
  fi

  # 1) 构建新区块 + 校验 requires_conf
  local block; block="$(mktemp /tmp/fwblock.XXXXXX)"
  local uncovered=() missing_conf=()
  echo '# >>> swarm-yuan:framework-gates >>> （由 generate-skill.sh --inject-frameworks 维护，勿手改）' > "$block"
  local fw frag req var
  for fw in "${ACTIVE_FRAMEWORKS[@]}"; do
    frag="$paradigm_dir/assets/framework-gates/$fw.sh"
    if [[ -f "$frag" ]]; then
      cat "$frag" >> "$block"
      # 解析 requires_conf（兼容行内多空格/无声明）
      req=$(sed -n 's/^# ruleset:.*requires_conf: *//p' "$frag" | tr -s ' ')
      for var in $req; do
        # WP-I：变量可能定义在主 conf 或 arch conf（物理三分），两处都查
        grep -q "^${var}=" "$conf" 2>/dev/null && continue
        [[ "$arch_conf" != "$conf" ]] && grep -q "^${var}=" "$arch_conf" 2>/dev/null && continue
        missing_conf+=("$var")
      done
    else
      uncovered+=("$fw")
    fi
  done
  echo '# <<< swarm-yuan:framework-gates <<<' >> "$block"

  # 2) 幂等替换标记区块（awk 三平台兼容）
  local tmp; tmp="$(mktemp /tmp/fwprecheck.XXXXXX)"
  if grep -q '^# >>> swarm-yuan:framework-gates >>>' "$sh"; then
    # 失败关闭（fail-closed）：开标记存在但闭标记缺失时，awk 的 skip 会一直为 1 直到 EOF，
    # 把区块之后的全部内容（公共库 _fw_resolve_globs/_fw_report、main case 分发，约 150 行）静默删除，
    # 且 --inject-frameworks 路径不备份（仅 --upgrade 备份）→ 不可恢复。故必须先校验闭标记存在。
    if ! grep -q '^# <<< swarm-yuan:framework-gates <<<' "$sh"; then
      rm -f "$tmp" "$block"
      echo "✗ $sh 含开标记 '# >>> swarm-yuan:framework-gates >>>' 但缺闭标记 '# <<< ... <<<'。" >&2
      echo "  为避免静默删除区块之后的公共库/main 分发，已中止注入（未改动 ${sh}）。" >&2
      echo "  请补全闭标记 '# <<< swarm-yuan:framework-gates <<<' 后重跑。" >&2
      return 1
    fi
    awk -v blockfile="$block" '
      /^# >>> swarm-yuan:framework-gates >>>/ { while ((getline l < blockfile) > 0) print l; skip=1; next }
      /^# <<< swarm-yuan:framework-gates <<</ { skip=0; next }
      !skip { print }
    ' "$sh" > "$tmp"
  elif grep -q '^case "\$MODE" in' "$sh"; then
    # 无标记区块：追加到文件末尾会落在 main case/exit 之后，注入的函数永不被定义。
    # 改为插入 main case（case "$MODE" in）之前，保证函数先定义后被调用。
    awk -v blockfile="$block" '
      /^case "\$MODE" in/ && !inserted {
        print ""
        while ((getline l < blockfile) > 0) print l
        print ""
        inserted=1
      }
      { print }
    ' "$sh" > "$tmp"
    echo "⚠ $sh 中无标记区块，已插入 main case 之前（建议人工在 check_framework 之后补标记区块）"
  else
    rm -f "$tmp" "$block"
    echo "✗ $sh 既无标记区块也无 main case（case \"\$MODE\" in），无法安全注入" >&2
    echo "  须人工在 check_framework 函数之后加入标记区块：" >&2
    echo "    # >>> swarm-yuan:framework-gates >>>" >&2
    echo "    # <<< swarm-yuan:framework-gates <<<" >&2
    return 1
  fi
  cat "$tmp" > "$sh"
  rm -f "$tmp" "$block"

  # 3) 缺失 conf 变量：注入占位 + warn（不静默）——WP-I：落 arch conf（框架变量组）
  for var in ${missing_conf[@]+"${missing_conf[@]}"}; do
    printf '%s=()  # TODO(framework-gates): 由生成流程 Step 7.5 填充\n' "${var}" >> "$arch_conf"
    echo "⚠ conf 缺失变量 ${var}，已注入占位（须填充）"
  done

  # 4) 未覆盖框架：warn 列出（不静默跳过）
  for fw in ${uncovered[@]+"${uncovered[@]}"}; do
    echo "⚠ 框架 '${fw}' 无对应门禁片段（references/frameworks/${fw}.md 缺失）——列入未覆盖清单"
  done

  # 5) 记录区块哈希（更新而非追加；首次注入则新建 ver）
  local sha
  sha=$(sed -n '/^# >>> swarm-yuan:framework-gates >>>/,/^# <<< swarm-yuan:framework-gates <<</p' "$sh" | cksum | awk '{print $1}')
  touch "$ver"
  # 移除旧字段，再追加新值（幂等更新；分组确保 .tmp 始终被清理）
  grep -Ev '^framework_gates_(injected_at|sha)=' "$ver" > "${ver}.tmp" 2>/dev/null || true
  { mv "${ver}.tmp" "$ver" 2>/dev/null || cp "${ver}.tmp" "$ver"; }
  rm -f "${ver}.tmp"
  {
    echo "framework_gates_injected_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
    echo "framework_gates_sha=${sha}"
  } >> "$ver"
  echo "✓ 门禁片段注入完成（${#ACTIVE_FRAMEWORKS[@]} 个框架，区块 sha=${sha}）"
}

if [[ "${1:-}" == "--inject-frameworks" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --inject-frameworks <skill-dir>"; exit 1; }
  inject_frameworks "$2"
  exit $?
fi

# ============================================================
# --verify-completeness 子命令（独立于 create/upgrade，单独拦截）
# 用法: bash generate-skill.sh --verify-completeness <skill-dir>
# 零占位符机器执法：扫描目标 skill 的 SKILL.md / references/*.md /
# scripts/precheck.conf / hooks/hooks.json（存在才查），命中占位符模式
# 或未勾 checkbox（- [ ]）则打印 file:line 清单并 exit 1；零命中 exit 0。
# 调用追踪机器执法（设计理念 2）：references/workflow.md 每个节点段
# （## 节点… 标题起）须含「调用追踪」要素，缺则列 file:line 并 exit 1。
# ============================================================
verify_completeness() {
  local skill_dir="$1" strict="${2:-}"
  trace_tool "verify-completeness" "$skill_dir"
  [[ -d "$skill_dir" ]] || { echo "✗ 目录不存在: $skill_dir" >&2; return 1; }
  # WP-H 状态门：draft 骨架允许占位符残留（报告模式 exit 0）；--strict（--mark-active 路径）保持 exit 1
  local _vc_status=""
  if [[ -f "$skill_dir/SKILL.md" ]]; then
    _vc_status=$(grep -m1 '^status: ' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^status: *//' | tr -d '[:space:]')
  fi
  # 收集检查目标（存在才查；空数组在 bash 3.2 + set -u 下须用 ${arr[@]+...} 防空崩）
  local targets=() f
  [[ -f "$skill_dir/SKILL.md" ]] && targets+=("$skill_dir/SKILL.md")
  for f in "$skill_dir"/references/*.md; do
    [[ -f "$f" ]] && targets+=("$f")
  done
  [[ -f "$skill_dir/scripts/precheck.conf" ]] && targets+=("$skill_dir/scripts/precheck.conf")
  # WP-R P3-3: precheck.arch.conf 也含 --inject-frameworks 注入的 TODO 占位符,须纳入扫描
  [[ -f "$skill_dir/scripts/precheck.arch.conf" ]] && targets+=("$skill_dir/scripts/precheck.arch.conf")
  [[ -f "$skill_dir/hooks/hooks.json" ]] && targets+=("$skill_dir/hooks/hooks.json")
  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "⚠ 未找到可检查文件（SKILL.md / references/*.md / precheck.conf / hooks.json 均不存在）"
    echo "✓ 零占位符确认"
    return 0
  fi
  # grep -F 固定串多模式（-e 叠加），三平台兼容；输出 file:line:内容 清单
  # 占位符四模式（骨架未填充痕迹）：待填充/（待填充）/<占位符>/填充指引
  # WP-Q4 P0/P1 分级机器化：
  #   - P1 占位符（含「（P1 待补）」标记）：draft 期允许，--strict（--mark-active）前须清零
  #   - P0 占位符（不含 P1 标记的常规占位符）：draft 期也仅 warn（draft 允许残留），--strict 时 exit 1
  #   区分方式：占位符所在行含「P1 待补」或「P1待补」→ 归 P1；否则归 P0
  local hits p1_hits="" p0_hits="" p0_ln p1_ln
  p0_hits=$(grep -Fn -e '待填充' -e '（待填充）' -e '<占位符>' -e '填充指引' \
    ${targets[@]+"${targets[@]}"} 2>/dev/null | grep -vE 'P1[[:space:]]*待补' || true)
  p1_hits=$(grep -Fn -e '待填充' -e '（待填充）' -e '<占位符>' -e '填充指引' \
    ${targets[@]+"${targets[@]}"} 2>/dev/null | grep -E 'P1[[:space:]]*待补' || true)
  hits="$p0_hits"
  # 未勾 checkbox（- [ ]）：仅骨架"填充指引"清单算占位；
  # 目标 skill 的"完成检查表/流程完成检查表"段是给使用者运行中勾选的，剔除该段防误伤。
  # 实现：对每个目标文件用 awk 标记"检查表段"区间，仅输出段外的 - [ ] 行。
  local cb_hits="" tf
  for tf in ${targets[@]+"${targets[@]}"}; do
    [[ -f "$tf" ]] || continue
    local out
    out=$(awk '
      /^#+ .*(检查表|检查清单|自检|审查清单|裁决条款|清单（)/ { intable=1; next }
      /^#+ / { intable=0 }
      /- \[ \]/ && !intable { print FILENAME":"FNR":"$0 }
    ' "$tf" 2>/dev/null || true)
    [[ -n "$out" ]] && cb_hits="${cb_hits}${cb_hits:+
}${out}"
  done
  hits=$(printf '%s\n%s\n' "$hits" "$cb_hits" | grep -v '^$' || true)
  # P1 占位符追加到 hits（--strict 模式下也算，draft 模式下仅 warn 不计入 hits）
  if [[ "$strict" == "--strict" && -n "$p1_hits" ]]; then
    hits=$(printf '%s\n%s\n' "$hits" "$p1_hits" | grep -v '^$' || true)
  fi
  local p1_cnt=0
  [[ -n "$p1_hits" ]] && p1_cnt=$(printf '%s\n' "$p1_hits" | grep -c . | tr -d ' \n' || echo 0)
  # 调用追踪要素机器执法（理念 2：全链路追踪落实到 workflow 模板）：
  # workflow.md 每个「## 节点…」段须含「调用追踪」字样（第 ⑨ 要素）。
  # 骨架阶段（待填充）已被上方占位符检查拦截；此处针对已填充内容。
  # 无节点段（项目裁剪后无 workflow 节点）不查，放行。
  local wf="$skill_dir/references/workflow.md" trace_miss=""
  if [[ -f "$wf" ]]; then
    # 节点段标题判定：标题行含「节点」且含冒号（如「## 节点①：需求理解」）。
    # 不用正则字符类匹配①-⑩/CJK数字——BSD awk 20200816 把多字节字符类按字节解析
    # 导致 [一] 匹配任意 ASCII 字符（已实测）。index() 固定子串匹配对 UTF-8 安全。
    trace_miss=$(awk '
      /^#{1,6} / && index($0, "节点") > 0 && (index($0, "：") > 0 || index($0, ":") > 0) {
        if (node != "" && !has) print FILENAME":"line": 节点段缺「调用追踪」要素（template-spec §2 第⑨要素）: " node
        node=$0; line=FNR; has=0; next
      }
      /调用追踪/ { has=1 }
      END { if (node != "" && !has) print FILENAME":"line": 节点段缺「调用追踪」要素（template-spec §2 第⑨要素）: " node }
    ' "$wf" 2>/dev/null || true)
  fi
  hits=$(printf '%s\n%s\n' "$hits" "$trace_miss" | grep -v '^$' || true)
  # G1：decisions.jsonl 校验（decisions_miss 并入 hits 统一裁决）
  # 检查 ① 每行 JSON 合法性 ② UserChallenge 行五要素非空（文件不存在不告警——draft 期允许空）
  local dec_file="$skill_dir/.swarm-yuan/decisions.jsonl" decisions_miss=""
  if [[ -f "$dec_file" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      local py_out
      py_out=$(python3 -c '
import sys, json
for i, line in enumerate(sys.stdin, 1):
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
    except Exception as e:
        print(f"%d: 非法JSON (%s)" % (i, e))
        continue
    if obj.get("type") == "UserChallenge":
        for k in ("alternatives", "missing_context", "cost_if_wrong"):
            if not obj.get(k):
                print("%d: UserChallenge 缺 %s" % (i, k))
' < "$dec_file" 2>/dev/null || true)
      [[ -n "$py_out" ]] && decisions_miss=$(printf '%s\n' "$py_out" | sed "s|^|$dec_file:|")
    else
      # 降级：grep 字段存在性（bash 3.2 兼容，不阻塞）
      local ln=0 dline
      while IFS= read -r dline; do
        ln=$((ln + 1))
        echo "$dline" | grep -q '"type"' || { decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: 非法JSON（缺 type 字段）"; continue; }
        echo "$dline" | grep -q '"type":"UserChallenge"' || continue
        echo "$dline" | grep -q '"alternatives"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 alternatives"
        echo "$dline" | grep -q '"missing_context"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 missing_context"
        echo "$dline" | grep -q '"cost_if_wrong"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 cost_if_wrong"
      done < "$dec_file"
    fi
  fi
  hits=$(printf '%s\n%s\n' "$hits" "$decisions_miss" | grep -v '^$' || true)
  if [[ -n "$hits" ]]; then
    echo "✗ 占位符/未勾项/缺失要素未清零（$(printf '%s\n' "$hits" | wc -l | tr -d ' ') 处）:"
    printf '%s\n' "$hits"
    if [[ "$_vc_status" == "draft" && "$strict" != "--strict" ]]; then
      echo "ℹ draft 状态：允许残留（填充中段，断点续传安全）；--mark-active 前须清零"
      [[ "$p1_cnt" -gt 0 ]] && echo "  （含 ${p1_cnt} 处 P1 占位符：WP-Q4 分级，draft 期允许，--mark-active 前 exit 1）"
      return 0
    fi
    return 1
  fi
  # P1 占位符在非 --strict 模式下单独 warn（不 exit 1）
  if [[ "$p1_cnt" -gt 0 && "$strict" != "--strict" ]]; then
    echo "⚠ 发现 ${p1_cnt} 处 P1 占位符（WP-Q4 分级，draft 期允许，--mark-active 前须清零）:"
    printf '%s\n' "$p1_hits"
  fi
  echo "✓ 零占位符确认"
  return 0
}

if [[ "${1:-}" == "--verify-completeness" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --verify-completeness <skill-dir>"; exit 1; }
  verify_completeness "$2"
  exit $?
fi

# ============================================================
# --mark-active 子命令（WP-H 状态门：draft → active）
# 用法: bash generate-skill.sh --mark-active <skill-dir>
# 严格零占位符核验（--strict）通过才把 SKILL.md frontmatter 的 status: draft 翻为 active；
# active 后目标 skill 的 precheck.sh --all-full/--compliance-suite 才解除禁用（precheck 侧状态门）。
# ============================================================
if [[ "${1:-}" == "--mark-active" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --mark-active <skill-dir>"; exit 1; }
  _ma_dir="$2"
  [[ -f "$_ma_dir/SKILL.md" ]] || { echo "✗ SKILL.md 不存在: $_ma_dir" >&2; exit 1; }
  if ! grep -q '^status: draft' "$_ma_dir/SKILL.md"; then
    echo "ℹ 非 draft 状态（已是 active 或无 status 字段），无需标记"
    exit 0
  fi
  if verify_completeness "$_ma_dir" --strict; then
    sed -i.bak 's/^status: draft/status: active/' "$_ma_dir/SKILL.md" && rm -f "$_ma_dir/SKILL.md.bak"
    echo "✓ 已标记 status: active（--all-full/--compliance-suite 已解锁）"
    exit 0
  else
    echo "✗ 占位符未清零，保持 draft（--all-full/--compliance-suite 仍禁用）" >&2
    exit 1
  fi
fi

# ============================================================
# --render-tools 子命令（独立于 create/upgrade，单独拦截）
# 用法: bash generate-skill.sh --render-tools <skill-dir> [project-root] [tool]
# G7 三档对齐：runnable（全部 7 工具目录复制即可运行）/ cli（6 工具派生原生规则）/
#   deep（Claude Code 已深度集成，no-op）。档位元数据：assets/tool-adapters/common.sh TA_TIER_*。
# 从目标 skill 的 SKILL.md + scripts/precheck.conf 派生各 AI 工具原生规则文件：
#   Cursor .cursor/rules/<skill>.mdc（description/globs/alwaysApply 三字段）
#   Windsurf .windsurf/rules/<skill>.md（trigger: model_decision）
#   Gemini/Codex/OpenCode/Kimi 的 GEMINI.md/AGENTS.md 段（标记区块包裹，幂等重渲染）
#   Claude Code 维持现状（hooks/commands 已深度集成，不渲染）
# project-root 缺省自动推导（用户级工具 home → 各工具全局规则位；否则取项目根）；
# tool 缺省渲染全部 7 工具，指定则只渲染其一。适配器：assets/tool-adapters/<tool>.sh
# （install.sh 共用 source）。重渲染同一项目为 no-op（内容一致跳过）。
# ============================================================
if [[ "${1:-}" == "--render-tools" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --render-tools <skill-dir> [project-root] [tool]"; exit 1; }
  TA_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/tool-adapters"
  export TA_DIR
  # shellcheck disable=SC1090
  . "$TA_DIR/common.sh"
  ta_render_tools "$2" "${3:-}" "${4:-}"
  exit $?
fi

# ---- 检测运行环境 ----
# 默认目标：项目内 .claude/skills/（"为目标项目生成 skill"名副其实）。
# 历史行为（2026-07-21 前）：项目内无 .claude/skills 时 fallback 到 $HOME/.claude/skills 全局目录，
# 导致 generate-skill.sh <name> <project> 把骨架生成到用户全局 skills 目录、项目目录内却什么都没有，
# 与 README/SKILL.md 宣称的"为某项目生成开发技能"不符。改为默认在项目内创建 .claude/skills/。
# 全局安装走 install.sh；用户仍可用第 3 参数 target-dir 显式指定任意目录。
detect_skill_dir() {
  local project="$1"
  # 1) 项目内已有 skills 目录（任意受支持运行时）→ 优先复用
  local rt
  for rt in .claude/skills .codex/skills .cursor/skills .codeium/windsurf/skills .config/opencode/skills .gemini/skills .kimi/skills; do
    if [[ -d "$project/$rt" ]]; then echo "$project/$rt"; return; fi
  done
  # 2) 项目内无 skills 目录 → 默认在项目内创建 .claude/skills/
  echo "$project/.claude/skills"
}

detect_runtime_name() {
  local project="$1"
  # 仅按项目内已有的 skills 目录判定运行时；不再因 $HOME 下有全局 skills 目录就误报。
  if [[ -d "$project/.claude/skills" ]]; then echo "Claude Code"
  elif [[ -d "$project/.codex/skills" ]]; then echo "Codex"
  elif [[ -d "$project/.cursor/skills" ]]; then echo "Cursor"
  elif [[ -d "$project/.codeium/windsurf/skills" ]]; then echo "Windsurf"
  elif [[ -d "$project/.config/opencode/skills" ]]; then echo "OpenCode"
  elif [[ -d "$project/.gemini/skills" ]]; then echo "Gemini CLI"
  elif [[ -d "$project/.kimi/skills" ]]; then echo "Kimi"
  else echo "通用（将在项目内创建 .claude/skills/）"
  fi
}

# ---- 解析模式 ----
MODE="create"
if [[ "${1:-}" == "--upgrade" ]]; then MODE="upgrade"; shift; fi

# ---- 解析 --profile（WP-E 三档骨架：lite/standard/compliance；WP-N1：auto 项目级自适应，默认）----
# 档序：lite(1) 只拷认知档最小集；standard(2) 当前默认全集（不含合规档文件）；
#       compliance(3) = standard + 合规档文件（references/standards-compliance.md 等）。
# auto：按项目信号自动判定（合规信号 > 规模信号；质量优先偏置——不确定一律升档不降级）。
PROFILE="auto"
PROFILE_EXPLICIT=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile 需要 auto|lite|standard|compliance}"; PROFILE_EXPLICIT=1; shift 2 ;;
    *) break ;;
  esac
done
case "$PROFILE" in
  auto|lite|standard|compliance) ;;
  *) echo "ERROR: --profile 仅支持 auto|lite|standard|compliance（收到: ${PROFILE}）" >&2; exit 1 ;;
esac
_profile_rank() { case "$1" in lite) echo 1;; compliance) echo 3;; *) echo 2;; esac; }

# WP-N1 项目级自适应判定：合规信号（等保/密评/个保法/金融/医疗关键词）→ compliance；
# 规模信号（文件数 <80）→ lite；其余 standard。
# WP-Q2 偏置方向修正（决策 18 修订）：
#   原"只升不降"让 lite 档几乎不被自动选中（auto 输出压缩到 standard/compliance 二选一）。
#   改为"信号明确才升档，模糊走默认 standard"：
#     - 合规关键词命中 → compliance（明确升档，不变）
#     - 文件数 <80 且无合规且非 monorepo 且依赖数 <20 → lite（明确降档）
#     - 探测失败/信号模糊（find 报错、依赖数不可读、边界不确定）→ standard（默认，不升不降）
#   质量优先的正确做法是"该 fail 的严格 fail"（strict 门禁真 fail），不是"档位一律往重选"。
# WP-P9 技术栈复杂度信号：形态信号（≥3 种形态）→ 升 standard；框架信号（≥20 个）→ 升 standard；
#   微服务信号（services/ 目录存在）→ 升 standard。优先级：合规 > 技术栈复杂度 > 规模。
auto_detect_profile() {
  local proj="$1" n sig forms fws msig result reason
  # 合规信号（最强，命中即 compliance）：docs/ 与根 README 的关键词扫描（限量提速）
  sig=$(grep -rliE '等保|密评|GB/T[[:space:]]*39786|GB/T[[:space:]]*22239|个人信息保护|个保法|金融行业|医疗行业' \
        "$proj/docs" "$proj"/README* 2>/dev/null | head -1 || true)
  if [[ -n "$sig" ]]; then
    echo "compliance"; return
  fi
  # 规模信号：文件数（head 截断加速，≥80 即 standard；统计失败按 standard——默认不降）
  n=$(find "$proj" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \
      2>/dev/null | head -81 | wc -l | tr -d ' ')
  n="${n:-81}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=81
  if [[ "$n" -lt 80 ]]; then result="lite"; else result="standard"; fi
  reason="规模信号：文件数 ${n}"

  # WP-P9 技术栈复杂度信号（明确升档，不模糊）
  # 形态信号：同时含 ≥3 种形态（前端 .vue/.jsx/.tsx + 后端 .py/.java/.go/.rb + 异步 .consumer./.handler. + 微服务 services/ + 桌面 .electron. 等）
  forms=0
  # 前端形态
  # WP-R Bug#1: find -print -quit 替代 find|head -1（避免 set -euo pipefail 下 SIGPIPE 崩溃）
  find "$proj" -type f \( -name "*.vue" -o -name "*.jsx" -o -name "*.tsx" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
  # 后端形态（非前端的 .py/.java/.go/.rb/.php/.kt/.scala）
  find "$proj" -type f \( -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.php" -o -name "*.kt" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
  # 异步/MQ 形态（含 consumer/handler/listener/subscriber 文件名）
  find "$proj" -type f \( -name "*consumer*" -o -name "*listener*" -o -name "*subscriber*" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
  # 微服务形态（services/ 或 apps/ 多服务目录）
  # WP-R Bug#1: find -maxdepth 1 -mindepth 1 -type d 列目录后 wc -l，find 目录数有限不会触发 SIGPIPE；
  # 但原 head -2 截断在 pipefail 下有风险。改用 find ... -print -quit 两次判定 ≥2：先确认 services/ 有子目录，
  # 再用 wc -l 计数（无 head 截断）。services/apps 可能其一不存在，find 对不存在路径 stderr 已 2>/dev/null。
  if [[ -d "$proj/services" || -d "$proj/apps" ]]; then
    local _svc_n
    _svc_n=$(find "$proj/services" "$proj/apps" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$_svc_n" =~ ^[0-9]+$ && "$_svc_n" -ge 2 ]] && forms=$((forms+1))
  fi
  # 桌面/移动形态（electron/tauri/android/ios 目录）
  { [[ -d "$proj/electron" || -d "$proj/src-tauri" || -d "$proj/android" || -d "$proj/ios" ]]; } && forms=$((forms+1))
  # 框架信号：依赖文件中的框架数（package.json dependencies + pom.xml + go.mod 等，粗计）
  fws=0
  [[ -f "$proj/package.json" ]] && fws=$(grep -cE '"[a-z@/][^"]+":\s*"' "$proj/package.json" 2>/dev/null | head -1 || echo 0)
  [[ -f "$proj/pom.xml" ]] && fws=$((fws + $(grep -cE "<artifactId>" "$proj/pom.xml" 2>/dev/null || echo 0)))
  [[ -f "$proj/go.mod" ]] && fws=$((fws + $(grep -cE "^\s*[a-z]" "$proj/go.mod" 2>/dev/null || echo 0)))
  [[ "$fws" =~ ^[0-9]+$ ]] || fws=0
  # 微服务信号：services/ 目录存在且含 ≥2 子目录
  msig=0
  if [[ -d "$proj/services" ]]; then
    local svc_cnt; svc_cnt=$(find "$proj/services" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$svc_cnt" =~ ^[0-9]+$ && "$svc_cnt" -ge 2 ]] && msig=1
  fi
  # WP-Q2：技术栈复杂度升档（明确信号才升，不模糊）
  # 形态/框架/微服务任一明确 → 升 standard（覆盖 lite 判定）
  if [[ $forms -ge 3 ]]; then
    result="standard"; reason="${reason}；形态信号：${forms} 种形态（≥3 → 升 standard）"
  fi
  if [[ $fws -ge 20 ]]; then
    result="standard"; reason="${reason}；框架信号：${fws} 依赖（≥20 → 升 standard）"
  fi
  if [[ $msig -eq 1 ]]; then
    result="standard"; reason="${reason}；微服务信号：services/ 含多服务（→ 升 standard）"
  fi
  # WP-Q2：monorepo 信号（明确升档，不降 lite）
  if [[ -f "$proj/lerna.json" || -f "$proj/pnpm-workspace.yaml" || -f "$proj/turbo.json" ]]; then
    result="standard"; reason="${reason}；monorepo 信号（lerna/pnpm-workspace/turbo → 升 standard）"
  fi
  echo "$result"
}

SKILL_NAME="${1:?Usage: generate-skill.sh [--upgrade] [--profile lite|standard|compliance] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh [--upgrade] [--profile lite|standard|compliance] <skill-name> <project-dir> [target-dir]}"
if [[ -z "${3:-}" ]]; then
  TARGET_DIR=$(detect_skill_dir "$PROJECT_DIR")
  RUNTIME_NAME=$(detect_runtime_name "$PROJECT_DIR")
  echo "检测到运行环境: ${RUNTIME_NAME}"
  echo "目标 skill 目录: ${TARGET_DIR}"
else
  TARGET_DIR="$3"
fi

[[ ! -d "$PROJECT_DIR" ]] && { echo "ERROR: 项目目录不存在: $PROJECT_DIR"; exit 1; }
mkdir -p "$TARGET_DIR"

# WP-N1：auto 档解析为具体档（在 PROJECT_DIR 校验后、骨架创建前；输出判定依据供用户评估）
if [[ "$PROFILE" == "auto" ]]; then
  _auto_reason=""
  # 注：先捕获再判空——pipefail 下 grep|head 的 SIGPIPE(141) 会让 if 管道直接误判（全库已知坑）
  _sig=$(grep -rliE '等保|密评|GB/T[[:space:]]*39786|GB/T[[:space:]]*22239|个人信息保护|个保法|金融行业|医疗行业' \
      "$PROJECT_DIR/docs" "$PROJECT_DIR"/README* 2>/dev/null | head -1 || true)
  if [[ -n "$_sig" ]]; then
    _auto_reason="命中合规信号（等保/密评/个保法/金融/医疗关键词：${_sig}）"
  else
    # WP-R Bug#1: find|head -81|wc -l 在 $(...) 内 set -e 不传播，但 pipefail 下 find SIGPIPE(141)
    # 会使赋值非零（虽 head -81 有意截断计数）。改用 find -printf '' 计数或 awk 统计避免截断管道。
    # 这里只需"是否 ≥80 文件"判定，用 find ... | wc -l 全量计数（不截断）更准且无 SIGPIPE。
    _fc=$(find "$PROJECT_DIR" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' 2>/dev/null | wc -l | tr -d ' ')
    _auto_reason="规模信号：文件数 ${_fc:-?}（<80 → lite，否则 standard）"
  fi
  # WP-P9：技术栈复杂度信号（只升不降，质量优先）
  # WP-R Bug#1: 原 find|head -1|grep -q . 在 set -euo pipefail 下，find 输出被 head 截断收 SIGPIPE(141)，
  # pipefail 使管道非零 → && 链非零 → set -e 触发脚本退出（5/5 真实项目崩溃 exit 141）。
  # 改用 find -print -quit：find 原生首匹配即停，无管道无 SIGPIPE。
  _forms=0
  find "$PROJECT_DIR" -type f \( -name "*.vue" -o -name "*.jsx" -o -name "*.tsx" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  find "$PROJECT_DIR" -type f \( -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.php" -o -name "*.kt" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  find "$PROJECT_DIR" -type f \( -name "*consumer*" -o -name "*listener*" -o -name "*subscriber*" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  { [[ -d "$PROJECT_DIR/electron" || -d "$PROJECT_DIR/src-tauri" || -d "$PROJECT_DIR/android" || -d "$PROJECT_DIR/ios" ]]; } && _forms=$((_forms+1))
  _msig=""
  if [[ -d "$PROJECT_DIR/services" ]]; then
    _svc_cnt=$(find "$PROJECT_DIR/services" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$_svc_cnt" =~ ^[0-9]+$ && "$_svc_cnt" -ge 2 ]] && { _forms=$((_forms+1)); _msig="services/ 含 ${_svc_cnt} 服务"; }
  fi
  [[ $_forms -ge 3 ]] && _auto_reason="${_auto_reason}；技术栈复杂度：${_forms} 种形态${_msig:+（${_msig}）}（≥3 → 升 standard）"
  PROFILE=$(auto_detect_profile "$PROJECT_DIR")
  echo "profile auto 判定: ${PROFILE}（${_auto_reason}；WP-Q2 偏置修正——信号明确才升档，模糊走默认 standard。显式 --profile 可覆盖）"
fi

# WP-Q3：auto 档时探测框架，写入 precheck.arch.conf 的 ACTIVE_FRAMEWORKS（standard+ 档）
# 替代 AI 手工探查 §C+.0.5。lite 档不拷 precheck.arch.conf，跳过。
_wq3_script="$(cd "$(dirname "$0")" && pwd)/detect-frameworks.sh"
if [[ "$PROFILE" != "lite" && -f "$_wq3_script" ]]; then
  _dfw_out=$(bash "$_wq3_script" "$PROJECT_DIR" 2>/dev/null || true)
  if [[ -n "$_dfw_out" ]]; then
    # WP-R Bug#1: printf|grep|head -1 上游 printf 输出有限(几行)无 SIGPIPE 风险,但 pipefail 下防御性 || true
    _dfw_fws=$(printf '%s\n' "$_dfw_out" | grep '^ACTIVE_FRAMEWORKS=' | head -1 || true)
    if [[ -n "$_dfw_fws" && "$_dfw_fws" != 'ACTIVE_FRAMEWORKS=()' ]]; then
      echo "框架探测: $_dfw_fws"
    fi
  fi
fi

SKILL_DIR="$TARGET_DIR/$SKILL_NAME"
ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets"
SRC_REF="$(cd "$(dirname "$0")/.." && pwd)/references"
SRC_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
SWARM_YUAN_STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"

# 按 UNIVERSAL_FILES 清单复制通用文件（create 全量；upgrade 跳过 precheck.conf 保留用户配置）
# 可选环境变量 SKILLS_PATH_REWRITE：sed 表达式，复制后逐文件就地应用（缺省空=不重写）。
# 用途：目标运行时的 skills 目录不是 .claude/skills 时做路径重写，
#       如 SKILLS_PATH_REWRITE='s|\.claude/skills|.agents/skills|g'（非标准 skills 目录实例）。
copy_universal_templates() {
  local dir="$1"
  local mode="${2:-create}"   # create=覆盖 precheck.conf（新建骨架）；upgrade=不覆盖（保留用户配置，由 merge_precheck_conf 增量补）；resume=断点续传（已有文件一律不覆盖）
  local entry dest kind minprof src
  for entry in "${UNIVERSAL_FILES[@]}"; do
    dest="${entry%%|*}"; kind="${entry#*|}"; minprof="${kind#*|}"; kind="${kind%%|*}"
    [[ "$minprof" == "$kind" ]] && minprof="standard"   # 无第三段 = standard
    # profile 过滤：文件最低档 > 当前档则跳过（WP-E）
    [[ $(_profile_rank "$minprof") -gt $(_profile_rank "$PROFILE") ]] && continue
    # resume：断点续传只补缺失文件，已有一律不覆盖（WP-H）
    [[ "$mode" == "resume" && -f "$dir/$dest" ]] && continue
    # precheck.conf 三件套：create 模式覆盖模板；upgrade 模式保留用户配置（由 merge_precheck_conf 增量补缺失变量）
    [[ "$mode" == "upgrade" && ( "$dest" == "scripts/precheck.conf" || "$dest" == "scripts/precheck.arch.conf" || "$dest" == "scripts/precheck.compliance.conf" ) ]] && continue
    case "$kind" in
      assets) src="$ASSETS_DIR/${dest##*/}" ;;
      ref)    src="$SRC_REF/${dest##*/}" ;;
      gen)    src="$SRC_SCRIPTS/${dest##*/}" ;;
      *) echo "ERROR: UNIVERSAL_FILES 未知源类别: $entry" >&2; return 1 ;;
    esac
    cp "$src" "$dir/$dest"
    # 路径重写（三平台兼容：sed -i.bak + rm，与 tests/e2e/run-e2e.sh 同款写法）
    if [[ -n "${SKILLS_PATH_REWRITE:-}" ]]; then
      sed -i.bak -e "$SKILLS_PATH_REWRITE" "$dir/$dest" || { echo "ERROR: SKILLS_PATH_REWRITE 应用失败: $dir/$dest" >&2; return 1; }
      rm -f "$dir/$dest.bak"
    fi
  done
  chmod +x "$dir/assets/"*.sh "$dir/scripts/"*.sh
  # Windows .bat 包装器（让 Windows 用户也能直接运行，三平台兼容；缺失则跳过）
  # 设 SKIP_BAT=1 可跳过 .bat 复制（macOS/Linux 用户无需 .bat，让 skill 目录更干净）
  if [[ "${SKIP_BAT:-0}" != "1" ]]; then
    # scripts/ 下的 .bat（install/generate-skill/self-check/precheck/state-machine/trace-log）
    local b
    for b in install generate-skill self-check precheck state-machine trace-log; do
      src="$SRC_SCRIPTS/$b.bat"
      [[ "$b" == "install" ]] && src="$SRC_SCRIPTS/../install.bat"
      [[ "$b" == "trace-log" ]] && src="$ASSETS_DIR/trace-log.bat"
      if [[ -f "$src" ]]; then cp "$src" "$dir/scripts/$b.bat" 2>/dev/null || true; fi
    done
    # assets/ 下的 .bat（branch-setup/env-setup）
    for b in branch-setup env-setup; do
      if [[ -f "$ASSETS_DIR/$b.bat" ]]; then cp "$ASSETS_DIR/$b.bat" "$dir/assets/$b.bat" 2>/dev/null || true; fi
    done
  fi
}

# ============================================================
# 升级模式
# ============================================================
if [[ "$MODE" == "upgrade" ]]; then
  [[ ! -d "$SKILL_DIR" ]] && { echo "ERROR: 目标技能不存在: $SKILL_DIR"; exit 1; }
  # WP-E：upgrade 继承既有 profile（frontmatter `profile: <档>`）；显式 --profile 优先
  if [[ "$PROFILE_EXPLICIT" -eq 0 && -f "$SKILL_DIR/SKILL.md" ]]; then
    _existing_profile=$(grep -m1 '^profile: ' "$SKILL_DIR/SKILL.md" 2>/dev/null | sed 's/^profile: *//' | tr -d '[:space:]')
    case "${_existing_profile:-}" in
      lite|standard|compliance) PROFILE="$_existing_profile" ;;
    esac
  fi
  echo "=== 升级: $SKILL_DIR ==="
  echo "  profile: $PROFILE"
  trace_tool "upgrade" "$SKILL_DIR"
  echo "  时间戳: $SWARM_YUAN_STAMP"
  backup_dir="$SKILL_DIR/.upgrade-backup-${SWARM_YUAN_STAMP}"
  mkdir -p "$backup_dir/assets" "$backup_dir/scripts" "$backup_dir/references"
  echo "=== 1. 备份 ==="
  for entry in "${UNIVERSAL_FILES[@]}"; do
    f="${entry%%|*}"
    [[ -f "$SKILL_DIR/$f" ]] && { mkdir -p "$backup_dir/$(dirname "$f")"; cp "$SKILL_DIR/$f" "$backup_dir/$f"; }
  done
  echo "  ✓ 已备份"
  echo "=== 2. 覆盖通用模板（precheck.conf 保留用户配置，不覆盖）==="
  [[ -n "${SKILLS_PATH_REWRITE:-}" ]] && echo "  （应用 SKILLS_PATH_REWRITE: ${SKILLS_PATH_REWRITE}）"
  copy_universal_templates "$SKILL_DIR" upgrade
  echo "  ✓ 已更新（precheck.conf 保留，precheck.sh 已覆盖）"
  echo "=== 2.5 增量合并 precheck.conf（补缺失的 requires_conf 变量占位）==="
  merge_precheck_conf "$SKILL_DIR"
  echo "=== 3. 保留项目特定文件 ==="
  for f in "${PROJECT_SPECIFIC_FILES[@]}"; do [[ -f "$SKILL_DIR/$f" ]] && echo "  ✓ $f"; done
  # WP-A3：settings.local.json / .mcp.json 不存在则生成（存在则保留用户定制，不覆盖）
  for cfg in settings.local.json .mcp.json; do
    if [[ ! -f "$SKILL_DIR/$cfg" ]]; then
      echo "  → 补生成 ${cfg}（旧版生成器未产出）"
      case "$cfg" in
        settings.local.json)
          cat > "$SKILL_DIR/$cfg" <<'SEOF'
{
  "permissions": {
    "allow": [
      "Bash(bash scripts/precheck.sh:*)",
      "Bash(bash scripts/state-machine.sh:*)",
      "Bash(bash scripts/self-check.sh:*)",
      "Bash(bash scripts/trace-log.sh:*)",
      "Bash(bash scripts/generate-skill.sh:*)"
    ],
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(rm -rf ~:*)",
      "Bash(sudo:*)",
      "Bash(curl:* | sh)",
      "Bash(curl:* | bash)"
    ]
  }
}
SEOF
          ;;
        .mcp.json)
          cat > "$SKILL_DIR/$cfg" <<'MEOF'
{
  "_comment": "MCP server 接入模板（由 swarm-yuan 生成）。默认无激活 server——AI 按项目已装运行时激活对应 server。常用：gitnexus（代码图谱，PolyForm 非商用）/ claude-mem（跨会话记忆）/ graphify（MIT 代码图谱，默认推荐）。",
  "mcpServers": {
  }
}
MEOF
          ;;
      esac
      echo "  ✓ $cfg 已生成"
    else
      echo "  ✓ ${cfg}（保留用户定制）"
    fi
  done
  echo "=== 4. 版本戳 ==="
  cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
upgraded_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=upgrade
EOF
  echo "  ✓ .swarm-yuan-version（已重置 framework_gates_sha，由重注入写入新值）"
  echo "=== 升级完成 ==="
  echo "  备份: $backup_dir"
  echo "  下一步: AI 自动检查 + 运行门禁验证"
  # --upgrade 自动重注入门禁片段（precheck.sh 已被覆盖，区块为空，须重注入）
  # upgrade 场景下 .swarm-yuan-version 的 framework_gates_sha 已在第 4 步重置（cat 覆盖），
  # inject_frameworks 的 sha 冲突检测走"无 old_sha"分支，直接注入不中止。
  if [[ -f "$SKILL_DIR/scripts/precheck.conf" ]] && grep -q '^ACTIVE_FRAMEWORKS=' "$SKILL_DIR/scripts/precheck.conf" 2>/dev/null; then
    # conf 可能含字面 ${}（如 SQL_INJECTION_WHITELIST），set -u 下 source 会 unbound 崩溃、
    # 导致计数为 0、门禁重注入被静默跳过。照搬 inject_frameworks 的 set +u / source / set -u 模式。
    local_af_count=$(
      set +u
      # shellcheck disable=SC1090
      . "$SKILL_DIR/scripts/precheck.conf" 2>/dev/null || true
      # set +u 仍生效，ACTIVE_FRAMEWORKS 未定义时计数为 0 而不报错
      echo "${#ACTIVE_FRAMEWORKS[@]}"
    )
    if [[ "${local_af_count:-0}" -eq 0 ]]; then
      echo "  （ACTIVE_FRAMEWORKS 未配置或为空，跳过门禁注入）"
    else
      inject_frameworks "$SKILL_DIR" || echo "  ⚠ 门禁注入返回非 0（$?），请人工检查"
    fi
  fi
  echo "提示：precheck.conf 保留原值，新增标准合规 16 变量由 _default_conf 兜底（未配置静默跳过），如需启用请按特征卡补配"
  exit 0
fi

# ============================================================
# 创建模式（WP-H：draft 状态门 + 断点续传）
# ============================================================
# 已存在目录：draft 骨架 → 续传（幂等补齐缺失文件，不覆盖已有内容）；active/无 status → 报错走 --upgrade
RESUME=0
if [[ -d "$SKILL_DIR" ]]; then
  if grep -q '^status: draft' "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    echo "→ 检测到 draft 状态骨架，断点续传（幂等补齐缺失文件，不覆盖已有内容）"
    RESUME=1
  else
    echo "ERROR: 已存在: ${SKILL_DIR}（用 --upgrade 升级；draft 骨架自动续传）"; exit 1
  fi
fi
# 续传幂等写入：RESUME=1 且目标已存在时跳过（吃掉 stdin 不落盘）
_write_if_absent() {  # $1=目标路径；stdin=内容
  if [[ "$RESUME" -eq 1 && -f "$1" ]]; then echo "  续传跳过（已存在）: $1"; cat >/dev/null; else cat > "$1"; fi
}

echo "=== 创建: $SKILL_DIR ==="
echo "  profile: ${PROFILE}（lite=认知档最小集 / standard=标准档 / compliance=强监管档）"
trace_tool "create" "$SKILL_DIR"
# WP-E：lite 档只建三目录（无 hooks/commands/settings/.mcp.json）
if [[ "$PROFILE" == "lite" ]]; then
  mkdir -p "$SKILL_DIR"/{references,assets,scripts}
else
  mkdir -p "$SKILL_DIR"/{references,assets,scripts,hooks,commands}
fi
if [[ "$RESUME" -eq 1 ]]; then
  copy_universal_templates "$SKILL_DIR" resume
else
  copy_universal_templates "$SKILL_DIR"
fi
# WP-P4: create 模式 precheck.conf 三件套由 conf-render.sh 渲染初稿（嗅探+溯源注释），覆盖模板拷贝
# 仅新建（RESUME=0）时渲染；续传保留既有 conf 不覆盖。upgrade 模式在上文独立分支（merge_precheck_conf 保留用户配置）。
if [[ "$RESUME" -eq 0 ]]; then
  if bash "$SRC_SCRIPTS/conf-render.sh" "$PROJECT_DIR" --profile "$PROFILE" --out "$SKILL_DIR/scripts" >/dev/null 2>&1; then
    echo "  ✓ precheck.conf 初稿由 conf-render.sh 渲染（# AUTO:detected/default + # TODO:model 清单）"
  else
    echo "  ⚠ conf-render.sh 不可用，保留模板占位符（须手填）"
  fi
fi

fill_guide() {
  case "$1" in
    workflow.md) echo "八节点全流程，每节点 10 要素（含★调用追踪），4-Phase SOP，节点①含读取项目知识子步骤" ;;
    codebase.md) echo "目录结构+技术栈版本表+端口+配置" ;;
    dev-guide.md) echo "改造分类+拼装式开发原则+安全编码规范" ;;
    release.md) echo "编译规则+构建命令+产物位置" ;;
    reference-manual.md) echo "安全+组件+接口+数据+认知映射+谬误图谱+领域知识" ;;
    *) echo "见 template-spec.md" ;;
  esac
}
# WP-E：lite 档只生成 reference-manual.md 占位（特征卡+参考手册承载认知；其余段随升档补）
_placeholder_refs="workflow.md codebase.md dev-guide.md release.md reference-manual.md"
[[ "$PROFILE" == "lite" ]] && _placeholder_refs="reference-manual.md"
for f in $_placeholder_refs; do
  _write_if_absent "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f
> 填充指引：$(fill_guide "$f")
EOF
done

# WP-E：lite 档跳过 hooks/settings/.mcp.json/commands（无 hooks 生命周期与 slash 命令负担）
if [[ "$PROFILE" != "lite" ]]; then
_write_if_absent "$SKILL_DIR/hooks/hooks.json" <<'HEOF'
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|clear|compact", "command": "echo \"→ [hook:SessionStart] 调用 state-machine.sh status（阶段状态追踪）\"; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" status 2>/dev/null || true"}],
    "PreToolUse": [{"matcher": "Write|Edit", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --scope >/dev/null 2>&1 && echo \"→ [hook:PreToolUse] 调用 precheck --scope：✓ pass\" || echo \"→ [hook:PreToolUse] 调用 precheck --scope：✗ FAIL——运行 bash scripts/precheck.sh --scope 查看详情\""}]
  }
}
HEOF

# settings.local.json（WP-A1：真生成，落实 SKILL.md Step 9 宣称）
# 最小权限模板：允许本 skill 自带脚本执行；deny 危险命令。项目特定权限由 AI 填充。
_write_if_absent "$SKILL_DIR/settings.local.json" <<'SEOF'
{
  "permissions": {
    "allow": [
      "Bash(bash scripts/precheck.sh:*)",
      "Bash(bash scripts/state-machine.sh:*)",
      "Bash(bash scripts/self-check.sh:*)",
      "Bash(bash scripts/trace-log.sh:*)",
      "Bash(bash scripts/generate-skill.sh:*)"
    ],
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(rm -rf ~:*)",
      "Bash(sudo:*)",
      "Bash(curl:* | sh)",
      "Bash(curl:* | bash)"
    ]
  }
}
SEOF

# .mcp.json（WP-A2：真生成，落实 SKILL.md Step 9 宣称）
# 注释模板：列出可选 MCP server 接入示例，默认全 commented out，由 AI 按项目已装运行时激活。
# JSON 不支持注释，用 "_comment" 字段承载说明；激活时删除对应 server 前的注释行（改为有效 JSON）。
_write_if_absent "$SKILL_DIR/.mcp.json" <<'MEOF'
{
  "_comment": "MCP server 接入模板（由 swarm-yuan 生成）。默认无激活 server——AI 按项目已装运行时激活对应 server。激活示例：把 mcpServers 对象内对应 server 的注释去掉（改为有效 JSON 键值）。常用 server：gitnexus（代码图谱，PolyForm 非商用）/ claude-mem（跨会话记忆）/ graphify（MIT 代码图谱，默认推荐）。",
  "mcpServers": {
  }
}
MEOF


_write_if_absent "$SKILL_DIR/commands/spec.md" <<'CEOF'
---
description: 开始新需求——AI 自动创建 spec + 判断任务类型 + 判断规模 + 预填复用约束
argument-hint: <需求描述>
---
AI 自动：
1.创建 spec 文件
2.判断任务类型（WP-P4，从分支名/用户意图）：feature/fix/refactor/chore/docs/test/exp——映射见 assets/task-type-gates.conf
3.判断规模（优先 task-scale.sh 事前判定；spec 写完后用 detect-spec-scale.sh 复核）：
  - bash scripts/task-scale.sh → simple/standard/full（基于 git diff，不需要 spec）
  - 规则：simple（≤5 文件且不触碰敏感目录）；standard（6-10 文件单一模块）；full（>10 或触碰 public/api/schema/migration/auth/model 等敏感目录 或 跨多服务）
  - 规模不确定按更大规模处理（升档不降级）；公共接口/数据模型/权限改动无"简单"档
4.预填 §5.5 复用约束（从特征卡第 11 项检索可复用稳定单元）
5.运行 --reuse 验证
6.执行门禁集（任务类型 × 规模档取并集，质量优先取更重档）：
  - 任务类型基础集（task-type-gates.conf）：feature→--all-full；fix→--all --reuse；refactor→--all-full --reuse --stable-diff；chore→--all；docs→--docs-pack；test→--all --shift-left；exp→--all
  - 规模档叠加：simple→--all；standard→--all-full；full→--all-full --shift-left
  - 两者取并集（更重档）；compliance 档项目追加 --compliance-suite；compliance 档无"简单任务"豁免
$ARGUMENTS
CEOF
_write_if_absent "$SKILL_DIR/commands/precheck.md" <<'CEOF'
---
description: 运行门禁检查
argument-hint: --all | --all-full | <gate>
---
bash scripts/precheck.sh $ARGUMENTS
CEOF
_write_if_absent "$SKILL_DIR/commands/explore.md" <<'CEOF'
---
description: 探查项目结构
---
用 gitnexus/graphify/claude-mem 探查项目，更新特征卡。
CEOF
fi  # PROFILE != lite

# WP-H：SKILL.md 含续传追加段，整段按存在性守卫（draft 骨架的 SKILL.md 已存在时整体跳过）
if [[ "$RESUME" -eq 0 || ! -f "$SKILL_DIR/SKILL.md" ]]; then
cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $SKILL_NAME
description: （填充指引：触发条件 + 项目关键词）
profile: $PROFILE
status: draft
---
# $SKILL_NAME — （填充指引：项目名 + 需求交付全流程技能）
> 由 swarm-yuan 生成器创建（${SWARM_YUAN_STAMP}，profile=${PROFILE}），需 AI agent 探查后填充。
> 填充规范见 swarm-yuan/references/template-spec.md
## 填充指引
- [ ] meta: 核心理念+改造分类+流程总览+命令速查+门禁
EOF
# WP-E：checklist 按档裁剪（lite 无 workflow/commands/hooks 条目）
if [[ "$PROFILE" != "lite" ]]; then
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] workflow: 八节点+每节点 10 要素（含★调用追踪）+4-Phase SOP+每节点读取项目知识
- [ ] reference: codebase/dev-guide/release/reference-manual + 方法论+认知 reference
EOF
else
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] reference: reference-manual（特征卡 P0 六项 + 全量构件库清单）
EOF
fi
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] assets: spec-template(§5.5-§18) + plan + branch + env + data + state-machine
- [ ] check: precheck.sh 门禁（标准 27 随 --all-full；合规 13 随 --compliance-suite 按需）
- [ ] scripts: precheck + state-machine + trace-log + cost-report
EOF
else
  echo "  续传跳过（已存在）: $SKILL_DIR/SKILL.md"
fi

_write_if_absent "$SKILL_DIR/.swarm-yuan-version" <<EOF
created_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=create
EOF

echo "✓ 骨架已创建: $SKILL_DIR"
echo ""
find "$SKILL_DIR" -type f | sort
echo ""
echo "下一步: AI 自动探查 $PROJECT_DIR 并填充全部文件 + 配置 precheck.conf + 运行门禁验证。"
echo "  用户无需手动编辑任何配置文件。"
echo "  骨架状态: draft（--all-full/--compliance-suite 禁用）——填充完成后:"
echo "    bash generate-skill.sh --mark-active $SKILL_DIR"
echo "  中断后可重跑本命令断点续传（幂等补齐，不覆盖已有内容）。"
echo "  升级已有技能: bash generate-skill.sh --upgrade $SKILL_NAME $PROJECT_DIR"

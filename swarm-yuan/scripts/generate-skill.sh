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
  "assets/review-record-template.md|assets|lite"  # field-feedback：审查留痕载体（check_review 提示落 docs/reviews/YYYY-MM-DD.md 时按此模板）
  "assets/branch-setup.sh|assets"
  "assets/env-setup.sh|assets"
  "assets/data-sample-template.md|assets"
  # S14 修复：删 assets/state-machine.sh + assets/trace-log.sh 重复条目——
  # 所有引用指向 scripts/（SKILL.md:64/74/86），assets/ 副本无人加载。
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
  "scripts/memory-writeback.sh|assets|lite"
  # audit-claims-reality 修复：hooks 统一装到 scripts/（kind=hook，源 assets/hooks/）。
  # 此前 dest=assets/hooks/，但 hooks.json/settings 白名单/codex 适配器/文档全部引用 scripts/*.sh，
  # 且 hook 命令带 || true 兜底——生成物 hooks 整体静默失效（fail-gate 真拦截从不触发）。
  # 归一后全部既有引用点成立；fail-gate-hook 的 rules.d 相对解析（scripts/gate-rules.sh + rules.d/）也随之接通。
  "scripts/failure-detector.sh|hook|lite"
  "scripts/integrity-guard.sh|hook|lite"
  "scripts/fail-gate-hook.sh|hook|lite"
  "scripts/install.sh|assets|lite"  # 回归#27：安装器转发垫片（install.bat 同伴；source_repo 定位；安装器本体不入生成物）
  "scripts/generate-skill.sh|assets|lite"  # 回归#25：生成器转发垫片（source_repo 定位；白名单与 .bat 同伴复活的根修）
  "scripts/codex-gate-wrapper.sh|hook|standard"  # R13 批次4：Codex deny 协议适配（exit 2+stderr）
  "scripts/setup-loop.sh|hook|standard"
  "scripts/loop-hook.sh|hook|standard"
  "scripts/project-fingerprint.sh|gen|lite"
  # WP-R3-5：inventory-update.sh 给目标 skill 的 AI 用（编码中发现语义变化 → 局部更新清单单条目），
  # 与 inventory-verify.sh 的"生成器侧核验"角色区分——本脚本必须拷到目标 skill 的 scripts/ 下。
  "scripts/inventory-update.sh|gen|lite"
  # R13 批次2：规则即数据——三值求值器 + 默认规则集随生成物分发（conf 收缩的载体：门禁阈值/白名单类参数迁入规则数据）
  "scripts/gate-rules.sh|gen|lite"
  "scripts/gate-plan.sh|gen|lite"      # R15 HarnessEval P4：选择即证据（启用/跳过理由，负空间可审计）
  "scripts/audit-closure.sh|gen|lite"  # R15 HarnessEval P7：审计即完成条件（closure 完备性重走）
  "scripts/ontology-verify.sh|gen|lite" # R16-B：本体论健康检查（六锚一站式）
  "references/ontology/objects.md|onto|lite"  # R16-A：本体层类型目录（对象/关系/动作三姊妹，从 assets/ontology/ 拷入）
  "references/ontology/links.md|onto|lite"
  "references/ontology/actions.md|onto|lite"
  "rules.d/bash-advance.rules|rules|lite"
  "rules.d/readonly-safe.rules|rules|lite"
  "scripts/self-check.sh|gen|lite"
  "scripts/detect-frameworks.sh|gen|lite"
  "scripts/cost-report.sh|gen|lite"
  "scripts/detect-profile-drift.sh|gen|lite"
  "scripts/detect-spec-scale.sh|gen|lite"
  "scripts/task-scale.sh|gen|lite"
  "references/subagent-orchestration.md|ref"
  "references/governance-agents.md|ref|compliance"
  "references/task-methodology-router.md|ref"
  "references/canary-monitoring.md|ref"
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

# F1（dsh/cordis 吸收·协效应定向失效）：框架移出 ACTIVE_FRAMEWORKS 后的 conf 死变量注释。
# 补齐 merge_precheck_conf 只有"缺失补占位"没有"多余回收"的半边——对齐 cordis 的
# 服务表收缩（论文 Def 23：set 之逆即 unset）：依赖集合变化 → conf 定向失效。
# 死变量判定（机械、保守，三者同时满足）：
#   ① v 不在已注入区块 requires_conf 并集（活跃框架都不需要）
#   ② v 出现在某个【未注入】框架源文件的 requires_conf 中（证明它是框架专属变量）
#   ③ v 不被 skill 四脚本正文直接引用（排通用白名单如 SQL_INJECTION_WHITELIST/
#     EVAL_WHITELIST——它们在 gates 正文有引用，永不被判定死）
# 处置：不删除——原位注释（# deprecated VAR=原值），用户可整体恢复。
sync_framework_vars() {
  local skill_dir="$1"
  local sh="$skill_dir/scripts/precheck.sh"
  local conf="$skill_dir/scripts/precheck.conf"
  local arch_conf="$skill_dir/scripts/precheck.arch.conf"
  [[ -f "$sh" && -f "$conf" ]] || return 0
  [[ -f "$arch_conf" ]] || arch_conf="$conf"
  local paradigm_dir; paradigm_dir="$(cd "$(dirname "$0")/.." && pwd)"
  # 1. 活跃集：注入区块内 ruleset 行的 requires_conf 并集 + 已注入框架 id 集
  local active="" ln fw_id injected_ids=""
  while IFS= read -r ln; do
    fw_id="${ln#\# ruleset: }"; fw_id="${fw_id%%  *}"
    injected_ids="$injected_ids $fw_id "
    active="$active ${ln##*requires_conf: }"
  done < <(sed -n '/^# >>> swarm-yuan:framework-gates >>>/,/^# <<< swarm-yuan:framework-gates <<</p' "$sh" 2>/dev/null | grep '^# ruleset:')
  # 2. 未注入框架源文件的 requires_conf 并集（死变量声明证据）
  local dead_decl="" frag
  for frag in "$paradigm_dir"/assets/framework-gates/*.sh; do
    [[ -f "$frag" ]] || continue
    fw_id="$(basename "$frag" .sh)"
    case "$injected_ids" in *" $fw_id "*) continue;; esac
    dead_decl="$dead_decl $(sed -n 's/^# ruleset:.*requires_conf: *//p' "$frag" | tr -s ' ')"
  done
  [[ -z "$dead_decl" ]] && return 0
  # 3. 逐 conf 变量判定死变量（①②③）
  local v dead_vars="" referenced script
  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    case " $active " in *" $v "*) continue;; esac
    case " $dead_decl " in *" $v "*) ;; *) continue;; esac
    referenced=0
    for script in "$sh" "$skill_dir/scripts/gates-strict.sh" "$skill_dir/scripts/gates-warn.sh" "$skill_dir/scripts/gates-advisory.sh"; do
      [[ -f "$script" ]] || continue
      # 词边界匹配（保守）：${VAR} / ${#VAR[@]} / ${VAR[@]} / 裸 $VAR / 注释提及全算被引用。
      # 回归测试教训：精确匹配 "${VAR}" 会漏 ${VAR[@]}/$ {#VAR[@]} 形式，误把
      # SQL_INJECTION_WHITELIST 等通用白名单判死（注释提及也是"被需要"证据，宁保勿杀）。
      if grep -qE "(^|[^A-Za-z0-9_])${v}([^A-Za-z0-9_]|$)" "$script" 2>/dev/null; then
        referenced=1; break
      fi
    done
    [[ "$referenced" -eq 1 ]] && continue
    dead_vars="$dead_vars $v"
  done < <(grep -hoE '^[A-Z_][A-Z0-9_]+=' "$conf" "$arch_conf" 2>/dev/null | tr -d '=' | sort -u)
  [[ -z "${dead_vars// /}" ]] && return 0
  # 4. 原位注释（awk 幂等编辑，mktemp+cat 仓库既有范式）
  local target cf_tmp
  for target in "$arch_conf" "$conf"; do
    [[ -f "$target" ]] || continue
    cf_tmp="$(mktemp)"
    awk -v vars="$dead_vars" '
      BEGIN { n = split(vars, arr, " "); for (i = 1; i <= n; i++) if (arr[i] != "") dead[arr[i]] = 1 }
      { name = $0; sub(/=.*/, "", name); if (dead[name] == 1 && /^[A-Z_][A-Z0-9_]*=/) print "# deprecated（框架已移出 ACTIVE_FRAMEWORKS，可恢复）" $0; else print }
    ' "$target" > "$cf_tmp"
    cat "$cf_tmp" > "$target" && rm -f "$cf_tmp"
  done
  echo "⚠ sync_framework_vars：注释死变量（${dead_vars} ）——只被未注入框架需要；恢复请解开对应行的 # deprecated 注释"
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

  # F4（dsh 吸收·注入前快照，配对逆的根基）：任何落盘修改之前备份 $sh + conf 三件套到
  # .swarm-yuan/effects/<UTC时间戳>/，保留最近 1 份（更旧的清理）——--rollback-frameworks
  # 据此整体撤销本次注入效果（对齐 cordis "注册即效果、卸载可 unwind"；此前此路径无备份
  # 注释自认不可恢复）。
  local _fx_ts _fx_dir _fx_old
  _fx_ts="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)"
  _fx_dir="$skill_dir/.swarm-yuan/effects/$_fx_ts"
  mkdir -p "$_fx_dir"
  cp "$sh" "$_fx_dir/precheck.sh"
  cp "$conf" "$_fx_dir/precheck.conf"
  [[ -f "$skill_dir/scripts/precheck.arch.conf" ]] && cp "$skill_dir/scripts/precheck.arch.conf" "$_fx_dir/"
  [[ -f "$skill_dir/scripts/precheck.compliance.conf" ]] && cp "$skill_dir/scripts/precheck.compliance.conf" "$_fx_dir/"
  for _fx_old in "$skill_dir"/.swarm-yuan/effects/*/; do
    [[ -d "$_fx_old" ]] || continue
    [[ "$_fx_old" == "$_fx_dir/" ]] && continue
    rm -rf "$_fx_old"
  done

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
  # 回归发现#9（2026-08-27 四栈回归）：注入只负责"缺失补占位"，但骨架期框架变量行零存在
  # （懒生成移除空占位）→ AI/用户想预填无处落笔（sed 锚定不存在行=无操作，注入又懒补 ()）。
  # 此处补"已填非空值保留"——若变量行存在但值非空（非 ()），视为已配置，从 missing_conf 移除；
  # 仅当行不存在或值为空 () 时才懒补占位。这样 inject 幂等可重跑，不覆盖 AI 填充结果。
  if [[ ${#missing_conf[@]} -gt 0 ]]; then
    local _kept=() _mv _mline
    for _mv in "${missing_conf[@]}"; do
      # 查两 conf 里该变量的当前值；非空（非 () 非 ""）则保留
      _mline=$( { grep -h "^${_mv}=" "$arch_conf" 2>/dev/null; [[ "$arch_conf" != "$conf" ]] && grep -h "^${_mv}=" "$conf" 2>/dev/null; } | head -1 || true)
      if [[ -n "$_mline" && "$_mline" != *"()"* && "$_mline" != *'=""'* && "$_mline" != *"=() "* ]]; then
        continue  # 已填非空值——保留，不补占位
      fi
      _kept+=("$_mv")
    done
    missing_conf=("${_kept[@]+"${_kept[@]}"}")
  fi
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
  elif grep -q '^case "\$MODE" in' "$sh"; then  # shellcheck disable=SC2016
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

  # 4.5) framework-knowledge.md 骨架（DESIGN §4.1 声称的机械产出；audit-2026-08-25 落地——
  # 此前该文件完全依赖 AI 从零手写）。已存在不覆盖（AI 可能已实例化）；按 ACTIVE_FRAMEWORKS
  # 逐框架生成节，规律行数=该框架规则文件声明的"深度门槛"（机械节点只出骨架，实例化是 AI 审的活）。
  local fk="$skill_dir/references/framework-knowledge.md"
  if [[ ! -f "$fk" && ${#ACTIVE_FRAMEWORKS[@]} -gt 0 ]]; then
    mkdir -p "$(dirname "$fk")" 2>/dev/null || true
    {
      echo "# 框架知识库（--inject-frameworks 生成骨架；AI 按 references/frameworks/<fw>.md §3 实例化）"
      echo ""
      echo "> 每框架一节：规律数 ≥ 该框架「深度门槛」，每条必须含「证据：」字段（本项目源码证据，非通用常识）。"
      local fw _th _i
      for fw in ${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}; do
        _th=$(grep -m1 '^深度门槛:' "$paradigm_dir/references/frameworks/${fw}.md" 2>/dev/null | sed 's/^深度门槛:[[:space:]]*//; s/[^0-9].*$//')
        _th="${_th:-5}"
        echo ""
        echo "## ${fw}（规律 ≥ ${_th} 条，每条含「证据：」）"
        for ((_i=1; _i<=_th; _i++)); do
          echo "- 规律 ${_i}：待填充（证据：待填充）"
        done
      done
    } > "$fk"       && echo "✓ framework-knowledge.md 骨架已生成（${#ACTIVE_FRAMEWORKS[@]} 框架；待 AI 实例化）"       || echo "⚠ framework-knowledge.md 骨架写入失败（references/ 不可写；不阻塞注入）" >&2
  fi

  # 5) 记录区块哈希 + 效果 ledger（更新而非追加；首次注入则新建 ver）
  #    F4（dsh 吸收·效果记账）：framework_gates_effects 显式记录本次注入动了什么
  #    （conf_add=追加的占位变量清单）——--rollback-frameworks 据此+快照整体撤销。
  local sha _fx_ledger=""
  sha=$(sed -n '/^# >>> swarm-yuan:framework-gates >>>/,/^# <<< swarm-yuan:framework-gates <<</p' "$sh" | cksum | awk '{print $1}')
  if [[ ${#missing_conf[@]} -gt 0 ]]; then
    local _fx_u="" _fx_v
    for _fx_v in ${missing_conf[@]+"${missing_conf[@]}"}; do
      case " $_fx_u " in *" $_fx_v "*) continue;; esac
      _fx_u="$_fx_u $_fx_v"
    done
    _fx_ledger="conf_add:${_fx_u# }"
  fi
  touch "$ver"
  # 移除旧字段，再追加新值（幂等更新；分组确保 .tmp 始终被清理）
  grep -Ev '^framework_gates_(injected_at|sha|effects)=' "$ver" > "${ver}.tmp" 2>/dev/null || true
  { mv "${ver}.tmp" "$ver" 2>/dev/null || cp "${ver}.tmp" "$ver"; }
  rm -f "${ver}.tmp"
  {
    echo "framework_gates_injected_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
    echo "framework_gates_sha=${sha}"
    [[ -n "$_fx_ledger" ]] && echo "framework_gates_effects=${_fx_ledger}"
  } >> "$ver"
  # F1（dsh 吸收）：注入重建后同步 conf——回收移出 ACTIVE_FRAMEWORKS 的死变量
  sync_framework_vars "$skill_dir"
  echo "✓ 门禁片段注入完成（${#ACTIVE_FRAMEWORKS[@]} 个框架，区块 sha=${sha}）"
}

# F4（dsh 吸收·可逆效应补全）：整体撤销最近一次 --inject-frameworks 的效果。
# 依据：.swarm-yuan/effects/<ts>/ 快照（注入前原态）恢复 precheck.sh + conf 三件套，
# 并清 .swarm-yuan-version 的 framework_gates_* 记账。对齐 cordis "卸载即 unwind"
# （论文 Def 23：set 之逆 unset）——此前注入路径无备份、不可恢复。
rollback_frameworks() {
  local skill_dir="$1"
  local fx_root="$skill_dir/.swarm-yuan/effects"
  local ver="$skill_dir/.swarm-yuan-version"
  # 取最新一份快照（目录名=UTC 时间戳，字典序即时间序）
  local latest="" d
  for d in "$fx_root"/*/; do
    [[ -d "$d" ]] || continue
    latest="$d"
  done
  if [[ -z "$latest" || ! -f "$latest/precheck.sh" ]]; then
    echo "✗ 未找到注入前快照（$fx_root/*/precheck.sh）——无法回滚" >&2
    echo "  快照由 --inject-frameworks 自动创建（保留最近 1 份）" >&2
    return 1
  fi
  echo "=== 回滚注入效果（快照: ${latest} ）==="
  local f name
  for f in precheck.sh precheck.conf precheck.arch.conf precheck.compliance.conf; do
    [[ -f "$latest/$f" ]] || continue
    cp "$latest/$f" "$skill_dir/scripts/$f"
    echo "  ✓ 已恢复 scripts/$f"
  done
  # 清记账（framework_gates_* 全部字段）
  if [[ -f "$ver" ]]; then
    grep -Ev '^framework_gates_' "$ver" > "${ver}.tmp" 2>/dev/null || true
    { mv "${ver}.tmp" "$ver" 2>/dev/null || cp "${ver}.tmp" "$ver"; }
    rm -f "${ver}.tmp"
    echo "  ✓ 已清除 .swarm-yuan-version 的 framework_gates_* 记账"
  fi
  rm -rf "$latest"
  echo "=== 回滚完成（快照已消费；重注入请跑 --inject-frameworks）==="
}

if [[ "${1:-}" == "--rollback-frameworks" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --rollback-frameworks <skill-dir>"; exit 1; }
  rollback_frameworks "$2"
  exit $?
fi

if [[ "${1:-}" == "--inject-frameworks" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --inject-frameworks <skill-dir> [--remove <fw>]"; exit 1; }
  # F4（dsh 吸收·定向移除）：--remove <fw> 先从 conf 的 ACTIVE_FRAMEWORKS 移除该框架，
  # 再走常规注入（区块重建 + F1 sync 自动回收其死变量）——此前移除框架无路径，只能手改。
  if [[ "${3:-}" == "--remove" && -n "${4:-}" ]]; then
    sd="$2"; rfw="$4"; acf="$sd/scripts/precheck.arch.conf"
    [[ -f "$acf" ]] || acf="$sd/scripts/precheck.conf"
    if grep -q '^ACTIVE_FRAMEWORKS=' "$acf" 2>/dev/null; then
      # 词级重建（兼容带引号/裸词两种风格，输出统一带引号）：剥引号后逐词比较，
      # 命中 fw 的词跳过；空列表/单元素/多元素均正确重组。
      awk -v fw="$rfw" '
        /^ACTIVE_FRAMEWORKS=/ {
          head=$0; sub(/\(.*/, "", head)
          body=$0; sub(/^[^(]*\(/, "", body); sub(/\)[[:space:]]*$/, "", body)
          n=split(body, w, /[[:space:]]+/); out=""
          for (i=1; i<=n; i++) {
            if (w[i] == "") continue
            t=w[i]; gsub(/"/, "", t)
            if (t == fw) continue
            out = out " \"" t "\""
          }
          print head "(" out ")"; next
        }
        { print }
      ' "$acf" > "$acf.tmp"
      cat "$acf.tmp" > "$acf" && rm -f "$acf.tmp"
      echo "✓ 已从 ACTIVE_FRAMEWORKS 移除 '$rfw'（若原本不在列表则为空操作）"
    else
      echo "⚠ 未找到 ACTIVE_FRAMEWORKS= 行（${acf}），跳过移除"
    fi
  fi
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
  # WP-Z2: commands/*.md 骨架模板内嵌数字可能漂移（G6），纳入零占位符扫描
  for f in "$skill_dir"/commands/*.md; do
    [[ -f "$f" ]] && targets+=("$f")
  done
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
      # 九轮复盘：排除 ``` 代码块——gsd-patterns.md/cognitive-bias.md 等 UNIVERSAL_FILES
      # 模板里的 ```markdown 示例（破窗台账格式演示）含 - [ ]，是正确的方法论示例，
      # 非待清零占位符。原未排除代码块，导致 --mark-active 永远拒绝（E2E Step ⑧ 死锁）。
      # /^```/ 行首匹配 fence 边界，toggle 翻转；完整配对 fence 正确，
      # 未闭合 fence 把块内全判为 incode（保守不误报，可接受）。
      /^```/ { incode=!incode; next }
      # 真 checkbox 判定：行首（可有缩进）的 "- [ ]"。
      # 反引号引用（`- [ ]`）是方法论说明文字（如 gsd-patterns.md L181/185/187 讲解语法），
      # 非行首 checkbox，不匹配；与上方代码块排除同批修复 E2E Step ⑧ 死锁。
      /^[[:space:]]*- \[ \]/ && !intable && !incode { print FILENAME":"FNR":"$0 }
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
      /^## / && index($0, "节点") > 0 && (index($0, "：") > 0 || index($0, ":") > 0) {
        if (node != "" && !has) print FILENAME":"line": 节点段缺追踪要素（R13 4 要素模型：⑥ 产出物与追踪段须含 trace-log.sh 调用）: " node
        node=$0; line=FNR; has=0; next
      }
      /调用追踪|trace-log\.sh/ { has=1 }
      END { if (node != "" && !has) print FILENAME":"line": 节点段缺追踪要素（R13 4 要素模型：⑥ 产出物与追踪段须含 trace-log.sh 调用）: " node }
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
  # C2: --strict 模式下强制 decisions.jsonl 至少 1 条记录（spec-template §2 决策记录契约：
  # --mark-active 前须≥1 决策；UserChallenge 类决策须带 missing_context/cost_if_wrong）
  # draft 期（非 strict）允许空；strict 时文件缺失或零记录均记为 hit
  if [[ "$strict" == "--strict" ]]; then
    local _dec_cnt=0
    if [[ -f "$dec_file" ]]; then
      _dec_cnt=$(grep -c '.' "$dec_file" 2>/dev/null | xargs)
    fi
    if [[ "$_dec_cnt" -eq 0 ]]; then
      decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file: 缺少决策记录（--mark-active 须≥1 条，spec-template §2 契约；UserChallenge 须带 missing_context/cost_if_wrong）"
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
# --mark-active 子命令（WP-H 状态门：draft → active；WP-Q1A 串联 inventory-verify --path-check）
# 用法: bash generate-skill.sh --mark-active <skill-dir>
# 三道关：
#   ① verify_completeness --strict（占位符零残留，P0/P1 分级）
#   ② inventory-verify.sh --path-check（§4/§6/§9 表格登记的路径必须在仓库真实存在）
#   ③ inventory-verify.sh 基线 FAIL 维度阻断（HALLUCINATION 列表非空阻断）
# 三关全过才把 SKILL.md frontmatter 的 status: draft 翻为 active；
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
  # ① 零占位符核验
  if ! verify_completeness "$_ma_dir" --strict; then
    echo "✗ ①占位符未清零，保持 draft（--all-full/--compliance-suite 仍禁用）" >&2
    exit 1
  fi
  # ②③ inventory-verify 路径校验（HALLUCINATION 阻断；FAIL 维度作为告警不阻断——fail-open）
  # WP-R3-3：补串 --stability-audit（WP-Q1A 时漏串，仅文档化）——稳定性标注与三机械信号
  # （近 90 天 git churn / fan-in / 同名测试）冲突时 STABILITY_WARN（advisory，不阻断）。
  _ma_iv="$(cd "$(dirname "$0")" && pwd)/inventory-verify.sh"
  if [[ -x "$_ma_iv" || -f "$_ma_iv" ]]; then
    _ma_proj=$( (set +u; . "$_ma_dir/scripts/precheck.conf" 2>/dev/null; printf '%s' "${PROJECT_DIR:-}") )
    _ma_proj=$(cd "$_ma_proj" 2>/dev/null && pwd)
    if [[ -n "$_ma_proj" && -d "$_ma_proj" && -f "$_ma_dir/references/reference-manual.md" ]]; then
      _iv_out=$(bash "$_ma_iv" "$_ma_proj" --skill-dir "$_ma_dir" --tsv --path-check --stability-audit 2>&1) || true
      _iv_hallus=$(printf '%s\n' "$_iv_out" | grep -c '^HALLUCINATION' || true)
      if [[ "${_iv_hallus:-0}" -gt 0 ]]; then
        echo "✗ ②③ inventory-verify 检测到 ${_iv_hallus} 个 HALLUCINATION 路径（清单登记 vs 仓库实存不符）" >&2
        printf '%s\n' "$_iv_out" | grep '^HALLUCINATION' >&2
        echo "  → 回 Step 4 补齐组件/重写登记行；保持 draft（--all-full/--compliance-suite 仍禁用）" >&2
        exit 1
      fi
      # FAIL 维度作为告警（不阻断——fail-open；与 -path-check 的硬阻断区分）
      _iv_fail=$(printf '%s\n' "$_iv_out" | grep -cE '\bFAIL\b' || true)
      if [[ "${_iv_fail:-0}" -gt 0 ]]; then
        echo "⚠ inventory-verify FAIL 维度 ${_iv_fail} 个（advisory：清单覆盖度 < 0.95；不阻断 mark-active，但建议补漏）" >&2
        printf '%s\n' "$_iv_out" | grep -E '\bFAIL\b' >&2 || true
      fi
      # WP-R3-3：STABILITY_WARN 也作为告警（不阻断——advisory 级；标注与机械信号冲突须人工复核）
      _iv_stab=$(printf '%s\n' "$_iv_out" | grep -c '^STABILITY_WARN' || true)
      if [[ "${_iv_stab:-0}" -gt 0 ]]; then
        echo "⚠ inventory-verify STABILITY_WARN ${_iv_stab} 条（advisory：稳定性标注与 git churn/fan-in/测试存在性信号冲突；不阻断 mark-active，但建议复核标注）" >&2
        printf '%s\n' "$_iv_out" | grep '^STABILITY_WARN' >&2 || true
      fi
    else
      echo "⚠ inventory-verify 跳过（PROJECT_DIR 或 reference-manual.md 缺失：mark-active 不强求）" >&2
    fi
  else
    echo "⚠ inventory-verify.sh 不存在（$BASE/scripts/），跳过 ②③" >&2
  fi
  # R15（HarnessEval P7）：audit-closure --strict 闭环完备性检查（advisory 降级——
  # 无 decisions.jsonl 或全部 closed 时过；有 open goal 时 warn 不阻断，fail-open 教义：
  # 审计未完成是提示信号不是阻断条件，有下层门禁兜底）
  _ma_ac="$(cd "$(dirname "$0")" && pwd)/audit-closure.sh"
  if [[ -x "$_ma_ac" || -f "$_ma_ac" ]]; then
    _ac_proj=$( (set +u; . "$_ma_dir/scripts/precheck.conf" 2>/dev/null; printf '%s' "${PROJECT_DIR:-}") )
    if [[ -n "$_ac_proj" && -d "$_ac_proj" ]]; then
      if ! bash "$_ma_ac" "$_ac_proj" --strict >/dev/null 2>&1; then
        echo "⚠ audit-closure：存在 open goal（change↔validation 未闭合）——advisory 提示，不阻断 mark-active" >&2
        bash "$_ma_ac" "$_ac_proj" 2>&1 | grep '⚠' >&2 || true
      fi
    fi
  fi
  sed -i.bak 's/^status: draft/status: active/' "$_ma_dir/SKILL.md" && rm -f "$_ma_dir/SKILL.md.bak"
  echo "✓ 已标记 status: active（--all-full/--compliance-suite 已解锁）"
  exit 0
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

# ============================================================
# --refresh 子命令（WP-Q3-1 自成长机制最小切片：dry-run 报告 + 不实际修改）
# 用法: bash generate-skill.sh --refresh <skill-dir>
# 走 project-fingerprint.sh --diff 拿变化报告，加上：
#   ① 当前 skill 状态（draft/active）+ 上一次 refresh 时间
#   ② 建议行动（无变化 → 无需刷新；有变化 → --upgrade 详情）
#   ③ 把当前指纹落盘到 project（新基线）——可选 --commit-fp
# 红线：仅报告，不改任何文件；不写 reference-manual.md（那是 --upgrade 的活）。
# ============================================================
if [[ "${1:-}" == "--refresh" ]]; then
  [[ $# -ge 2 ]] || { echo "Usage: bash generate-skill.sh --refresh <skill-dir> [--commit-fp]"; exit 1; }
  _rf_dir="$2"; shift 2
  [[ -d "$_rf_dir" ]] || { echo "✗ skill 目录不存在: $_rf_dir" >&2; exit 1; }
  [[ -f "$_rf_dir/SKILL.md" ]] || { echo "✗ SKILL.md 不存在: $_rf_dir" >&2; exit 1; }
  # 项目根：从 precheck.conf 拿
  _rf_conf="$_rf_dir/scripts/precheck.conf"
  [[ -f "$_rf_conf" ]] || { echo "✗ scripts/precheck.conf 不存在，无法定位项目根" >&2; exit 1; }
  _rf_proj=$( (set +u; . "$_rf_conf" 2>/dev/null; printf '%s' "${PROJECT_DIR:-}") )
  [[ -n "$_rf_proj" && -d "$_rf_proj" ]] || { echo "✗ precheck.conf 中 PROJECT_DIR 无效: ${PROJECT_DIR:-（空）}" >&2; exit 1; }
  _rf_proj=$(cd "$_rf_proj" && pwd)
  # fingerprint 脚本路径
  _rf_fp="$(cd "$(dirname "$0")" && pwd)/project-fingerprint.sh"
  [[ -x "$_rf_fp" || -f "$_rf_fp" ]] || { echo "✗ project-fingerprint.sh 缺失: $_rf_fp" >&2; exit 1; }
  # 跑 diff
  _rf_out=$(bash "$_rf_fp" "$_rf_proj" --diff 2>&1) || true
  # 输出报告
  echo "## --refresh dry-run（skill=$(basename "$_rf_dir")，project=${_rf_proj}）"
  _rf_status=$(grep -m1 '^status:' "$_rf_dir/SKILL.md" 2>/dev/null | sed 's/^status: *//')
  echo "  当前 skill 状态: ${_rf_status:-无 status 字段}"
  if printf '%s\n' "$_rf_out" | LC_ALL=C grep -q '⚠ 项目源码已变化'; then
    # WP-R2-2：建议从"只 --upgrade"升级为完整更新链——--upgrade 只刷工具链，
    # reference-manual.md 组件库清单需 AI 重探查更新 + inventory-verify 核验。
    echo "  → 检测到变化，更新链（详见目标技能 SKILL.md「自成长」段）："
    echo "      ① --upgrade 刷工具链（保留 reference-manual.md 内容文件）"
    echo "      ② AI 按「变化目录（scope）」局部重探查变化目录 → 更新 reference-manual.md 清单（未变 scope 条目不重写）"
    echo "      ③ inventory-verify.sh 计数核验（≥0.95 + 路径存在性）→ ④ --commit-fp 落新基线"
    printf '%s\n' "$_rf_out" | LC_ALL=C grep -v '^⚠' | LC_ALL=C grep -v '^  →' | LC_ALL=C grep -v '^$' | LC_ALL=C sed 's/^/    /'
    # --commit-fp：把当前指纹落盘为新基线
    if [[ "${1:-}" == "--commit-fp" ]]; then
      bash "$_rf_fp" "$_rf_proj" --write >/dev/null
      echo "  ✓ --commit-fp：已把当前指纹落盘为新基线（$_rf_proj/.swarm-yuan/project-fingerprint）"
    fi
    exit 0
  elif printf '%s\n' "$_rf_out" | LC_ALL=C grep -q '无既有指纹'; then
    # WP-R2-1：无基线 ≠ 无变化——此前落入 else 报"✓ 无变化"，首次感知场景假阴性。
    echo "  → 无指纹基线（尚未做过首次感知），无法判断变化——建议落基线："
    echo "      bash scripts/generate-skill.sh --refresh <skill-dir> --commit-fp"
    if [[ "${1:-}" == "--commit-fp" ]]; then
      bash "$_rf_fp" "$_rf_proj" --write >/dev/null
      echo "  ✓ --commit-fp：已把当前指纹落盘为基线（$_rf_proj/.swarm-yuan/project-fingerprint）"
    fi
    exit 0
  else
    echo "  ✓ 无变化（文件骨架指纹未变）"
    printf '%s\n' "$_rf_out" | LC_ALL=C grep -E '^\s*✓' | head -1 || true
    exit 0
  fi
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
#   auto：按项目信号自动判定（合规信号 > 规模信号；决策 30 现行口径：信号明确才升档，模糊走默认 standard）。
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
  # WP-CogAudit：source profile-thresholds.conf（消除死配置--conf 声称被用但从未 source）
  # 变量用 ${VAR:-default} 兜底，conf 缺失或变量未设仍走默认值（保兼容）
  local _pthr="${BASE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/assets/profile-thresholds.conf"
  if [[ -f "$_pthr" ]]; then
    set +u; # shellcheck disable=SC1090
    source "$_pthr"; set -u
  fi
  local _lite_max=${PROFILE_LITE_MAX_FILES:-80}
  local _forms_thr=${PROFILE_FORMS_THRESHOLD:-3}
  local _fws_thr=${PROFILE_FRAMEWORKS_THRESHOLD:-20}
  # 合规信号（最强，命中即 compliance）：docs/ 与根 README 的关键词扫描（限量提速）
  sig=$(grep -rliE '等保|密评|GB/T[[:space:]]*39786|GB/T[[:space:]]*22239|个人信息保护|个保法|金融行业|医疗行业' \
        "$proj/docs" "$proj"/README* 2>/dev/null | head -1 || true)
  if [[ -n "$sig" ]]; then
    echo "compliance"; return
  fi
  # 规模信号：文件数（head 截断加速，≥阈值即 standard；统计失败按 standard--默认不降）
  # _lite_max+1 截断：文件数 < _lite_max 才 lite，截断到 _lite_max+1 足够判定
  n=$(find "$proj" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \
      2>/dev/null | head -$((_lite_max + 1)) | wc -l | tr -d ' ')
  n="${n:-$((_lite_max + 1))}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=$((_lite_max + 1))
  if [[ "$n" -lt $_lite_max ]]; then result="lite"; else result="standard"; fi
  reason="规模信号：文件数 ${n}"

  # WP-P9 技术栈复杂度信号（明确升档，不模糊）
  # 形态信号：同时含 ≥3 种形态（前端 .vue/.jsx/.tsx + 后端 .py/.java/.go/.rb + 异步 .consumer./.handler. + 微服务 services/ + 桌面 .electron. 等）
  forms=0
  # 前端形态
  # WP-R Bug#1: find -print -quit 替代 find|head -1（避免 set -euo pipefail 下 SIGPIPE 崩溃）
  find "$proj" -type f \( -name "*.vue" -o -name "*.jsx" -o -name "*.tsx" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
  # 后端形态（.py/.java/.go/.rb/.php/.kt + .rs/.cs/.swift；WP-CogAudit 补 .rs/.cs/.swift 漏检；.scala 暂无 framework-gates 门禁，不纳入形态判定）
  find "$proj" -type f \( -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.php" -o -name "*.kt" -o -name "*.rs" -o -name "*.cs" -o -name "*.swift" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
  # 异步/MQ 形态（含 consumer/handler/listener/subscriber 文件名；WP-CogAudit 补 handler 漏检）
  find "$proj" -type f \( -name "*consumer*" -o -name "*listener*" -o -name "*subscriber*" -o -name "*handler*" \) -print -quit 2>/dev/null | grep -q . && forms=$((forms+1))
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
  [[ -f "$proj/package.json" ]] && fws=$(grep -cE '"[a-z@/][^"]+":[[:space:]]*"' "$proj/package.json" 2>/dev/null | head -1 || echo 0)
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
  if [[ $forms -ge $_forms_thr ]]; then
    result="standard"; reason="${reason}；形态信号：${forms} 种形态（≥${_forms_thr} -> 升 standard）"
  fi
  if [[ $fws -ge $_fws_thr ]]; then
    result="standard"; reason="${reason}；框架信号：${fws} 依赖（≥${_fws_thr} -> 升 standard）"
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

# Windows 路径转换（.bat 包装器 %* 原样透传，C:\proj 在 Git Bash 反斜杠被吞、WSL 下非法路径）。
# 匹配 ^[A-Za-z]:[\\/] 的参数，Git Bash/MSYS2 用 cygpath -u，WSL 用 wslpath -u 转 POSIX。
# 不匹配的参数原样保留（POSIX 路径不受影响，零行为变化）；两工具都不可用时 warn 提示。
_win_path_to_posix() {
  local p="$1"
  [[ "$p" =~ ^[A-Za-z]:[\\/] ]] || { printf '%s' "$p"; return 0; }
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p"
  elif command -v wslpath >/dev/null 2>&1; then
    wslpath -u "$p"
  else
    echo "  ⚠ 检测到 Windows 路径 $p 但无 cygpath/wslpath 可转换，请改用 POSIX 路径（如 /c/proj 或 /mnt/c/proj）" >&2
    printf '%s' "$p"
  fi
}

SKILL_NAME="${1:?Usage: generate-skill.sh [--upgrade] [--profile lite|standard|compliance] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh [--upgrade] [--profile lite|standard|compliance] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="$(_win_path_to_posix "$PROJECT_DIR")"
if [[ -z "${3:-}" ]]; then
  TARGET_DIR=$(detect_skill_dir "$PROJECT_DIR")
  RUNTIME_NAME=$(detect_runtime_name "$PROJECT_DIR")
  echo "检测到运行环境: ${RUNTIME_NAME}"
  echo "目标 skill 目录: ${TARGET_DIR}"
else
  TARGET_DIR="$3"
  TARGET_DIR="$(_win_path_to_posix "$TARGET_DIR")"
fi
# 回归发现#21（2026-08-27 第九轮边缘形态回归）：第 4+ 位置参数被静默丢弃——后置
# `--profile compliance`（标志位须前置，后置沦为多余位置参数）与不存在的 `--auto`
# 均被吞掉：用户以为拿到 compliance 实际生成 lite（静默错档）。多余参数显式报错。
if [[ $# -ge 4 ]]; then
  _extra_args="$4"
  [[ $# -gt 4 ]] && _extra_args="$4 ...（共 ${#} 个参数）"
  echo "ERROR: 多余参数「${_extra_args}」——用法仅接受 3 个位置参数（skill-name project-dir [target-dir]）；标志位（--profile/--upgrade 等）须置于位置参数之前；无 --auto 标志（自动检测默认开启）" >&2
  exit 1
fi

[[ ! -d "$PROJECT_DIR" ]] && { echo "ERROR: 项目目录不存在: $PROJECT_DIR"; exit 1; }
mkdir -p "$TARGET_DIR"

# WP-N1：auto 档解析为具体档（在 PROJECT_DIR 校验后、骨架创建前；输出判定依据供用户评估）
if [[ "$PROFILE" == "auto" ]]; then
  # WP-CogAudit：source profile-thresholds.conf 让 reason 文案的阈值与 auto_detect_profile 一致（消除死配置）
  if [[ -z "${PROFILE_LITE_MAX_FILES:-}" ]]; then
    _pthr2="${BASE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/assets/profile-thresholds.conf"
    [[ -f "$_pthr2" ]] && { set +u; # shellcheck disable=SC1090
      source "$_pthr2"; set -u; }
  fi
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
    _auto_reason="规模信号：文件数 ${_fc:-?}（<${PROFILE_LITE_MAX_FILES:-80} → lite，否则 standard）"
  fi
  # WP-P9：技术栈复杂度信号（只升不降，质量优先）
  # WP-R Bug#1: 原 find|head -1|grep -q . 在 set -euo pipefail 下，find 输出被 head 截断收 SIGPIPE(141)，
  # pipefail 使管道非零 → && 链非零 → set -e 触发脚本退出（5/5 真实项目崩溃 exit 141）。
  # 改用 find -print -quit：find 原生首匹配即停，无管道无 SIGPIPE。
  _forms=0
  find "$PROJECT_DIR" -type f \( -name "*.vue" -o -name "*.jsx" -o -name "*.tsx" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  find "$PROJECT_DIR" -type f \( -name "*.py" -o -name "*.java" -o -name "*.go" -o -name "*.rb" -o -name "*.php" -o -name "*.kt" -o -name "*.rs" -o -name "*.cs" -o -name "*.swift" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  find "$PROJECT_DIR" -type f \( -name "*consumer*" -o -name "*listener*" -o -name "*subscriber*" -o -name "*handler*" \) -print -quit 2>/dev/null | grep -q . && _forms=$((_forms+1))
  { [[ -d "$PROJECT_DIR/electron" || -d "$PROJECT_DIR/src-tauri" || -d "$PROJECT_DIR/android" || -d "$PROJECT_DIR/ios" ]]; } && _forms=$((_forms+1))
  _msig=""
  if [[ -d "$PROJECT_DIR/services" ]]; then
    _svc_cnt=$(find "$PROJECT_DIR/services" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [[ "$_svc_cnt" =~ ^[0-9]+$ && "$_svc_cnt" -ge 2 ]] && { _forms=$((_forms+1)); _msig="services/ 含 ${_svc_cnt} 服务"; }
  fi
  [[ $_forms -ge ${PROFILE_FORMS_THRESHOLD:-3} ]] && _auto_reason="${_auto_reason}；技术栈复杂度：${_forms} 种形态${_msig:+（${_msig}）}（≥${PROFILE_FORMS_THRESHOLD:-3} → 升 standard）"
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
# 版本溯源（八轮复盘 install.sh source_version 对齐）：生成器自身 git describe，
# 与 install.sh L123-124 同哲学；非 git 场景（zip 下载）降级 "unknown"，不阻塞生成。
# 不带 --dirty（跨平台：Windows Git Bash 默认 autocrlf=true 致干净 checkout 误报
# -dirty，污染版本字符串；版本演进比对只看 tag，不依赖 dirty 标记）。
SWARM_YUAN_SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_YUAN_SRC_VERSION="$(git -C "$SWARM_YUAN_SRC_DIR" describe --tags --always 2>/dev/null || echo "unknown")"

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
      # WP-B: assets 类源文件统一平铺在 $ASSETS_DIR/（assets/precheck.sh 等）。
      # dest 形态：scripts/precheck.sh → 源 = assets/precheck.sh（取 basename，文件平铺在 assets/）。
      # （hooks 不再走本分支——audit-claims-reality 起 dest 归一 scripts/，由 hook 分支映射 assets/hooks/ 源。）
      # 历史 bug：assets) src=$ASSETS_DIR/${dest#assets/} —— dest=scripts/precheck.sh 时
      # ${dest#assets/} 不剥前缀（不以 assets/ 开头），得 $ASSETS_DIR/scripts/precheck.sh（不存在），
      # cp 失败致 scripts/ 目录整批漏拷（precheck.sh/gates-*.sh/state-machine.sh 等）。
      # 验证器从未跑 generate-skill create（run-e2e.sh 手拼骨架绕过此路径），故长期未暴露。
      assets)
        if [[ "$dest" == assets/* ]]; then
          src="$ASSETS_DIR/${dest#assets/}"
        else
          src="$ASSETS_DIR/${dest##*/}"
        fi
        ;;
      ref)    src="$SRC_REF/${dest##*/}" ;;
      rules)  src="$ASSETS_DIR/$dest" ;;   # R13 批次2：rules.d 规则数据（dest=rules.d/xxx.rules → assets/rules.d/xxx.rules）
      onto)   src="$ASSETS_DIR/ontology/$(basename "$dest")" ;;  # R16-A：本体层（dest=references/ontology/x.md → assets/ontology/x.md）
      hook)   src="$ASSETS_DIR/hooks/${dest##*/}" ;;  # audit-claims-reality：hooks 源在 assets/hooks/，dest 归一 scripts/
      gen)    src="$SRC_SCRIPTS/${dest##*/}" ;;
      *) echo "ERROR: UNIVERSAL_FILES 未知源类别: $entry" >&2; return 1 ;;
    esac
    # WP-B: dest 可能含子目录（rules.d/bash-advance.rules、references/ontology/objects.md），
    # mkdir -p 父目录再 cp，否则 cp 报"No such file or directory"
    # （顶层 mkdir 只建了 references/assets/scripts/hooks/commands，子目录不在内）。
    mkdir -p "$dir/$(dirname "$dest")"
    cp "$src" "$dir/$dest"
    # WP-P5: spec-template §14-§18 认知扩展包按 profile 门控
    # lite/standard 裁掉 §14-§18（节不存在 → check_cognition SKIP 披露）；compliance 保留全部。
    # 裁剪范围：从门控注释 <!-- profile-gate: standard+ ... --> 起，到 ## 19. 止（不含 §19）。
    # 对 create/upgrade/resume 任意模式均生效（凡拷贝 spec-template 即按 profile 分层）。
    if [[ "$dest" == "assets/spec-template.md" && "$PROFILE" != "compliance" ]]; then
      awk '
        /^<!-- profile-gate: standard\+/{ skip=1; next }
        /^## 14\. /{ skip=1 }
        /^## 19\. /{ skip=0 }
        !skip { print }
      ' "$dir/$dest" > "$dir/$dest.tmp" && mv "$dir/$dest.tmp" "$dir/$dest"
    fi
    # 路径重写（三平台兼容：sed -i.bak + rm，与 tests/e2e/run-e2e.sh 同款写法）
    if [[ -n "${SKILLS_PATH_REWRITE:-}" ]]; then
      sed -i.bak -e "$SKILLS_PATH_REWRITE" "$dir/$dest" || { echo "ERROR: SKILLS_PATH_REWRITE 应用失败: $dir/$dest" >&2; return 1; }
      rm -f "$dir/$dest.bak"
    fi
  done
  # audit-claims-reality：清理旧版生成物残留的 assets/hooks/*.sh（dest 已归一 scripts/）。
  # 仅当 scripts/ 新位存在同名文件才删旧位（幂等；upgrade/create 后旧位即残留死文件，
  # 留着会让 AI 误读"hooks 在 assets/hooks/"的旧布局）。
  local _hb
  for _hb in failure-detector integrity-guard fail-gate-hook codex-gate-wrapper setup-loop loop-hook; do
    if [[ -f "$dir/scripts/${_hb}.sh" && -f "$dir/assets/hooks/${_hb}.sh" ]]; then
      rm -f "$dir/assets/hooks/${_hb}.sh"
    fi
  done
  # assets/hooks/ 清空后移除空目录（rmdir 仅删空目录，非空静默跳过）
  rmdir "$dir/assets/hooks" 2>/dev/null || true
  # chmod +x 所有 .sh（四轮复盘 P0 修复）：原写法 `chmod +x "$dir/assets/"*.sh "$dir/scripts/"*.sh`
  # 在 lite 档下必然失败——lite 档 UNIVERSAL_FILES 只拷 assets/ 下的 .md/.conf（无任何 .sh），
  # glob 无匹配时 chmod 报 "No such file or directory"，set -euo pipefail 直接中断生成，
  # 导致 lite 档（auto 对 <80 文件小项目的默认判定）产物残缺不可用。
  # 用 find -exec 替代 glob：目录不存在或无 .sh 时静默跳过，不中断。
  local _cd
  for _cd in assets scripts; do
    [[ -d "$dir/$_cd" ]] || continue
    find "$dir/$_cd" -maxdepth 1 -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  done
  # Windows .bat 包装器（让 Windows 用户也能直接运行，三平台兼容；缺失则跳过）
  # 设 SKIP_BAT=1 可跳过 .bat 复制（macOS/Linux 用户无需 .bat，让 skill 目录更干净）
  if [[ "${SKIP_BAT:-0}" != "1" ]]; then
    # scripts/ 下的 .bat（install/generate-skill/self-check/precheck/state-machine/trace-log/cost-report/detect-frameworks）
    # S15 修复：补 cost-report + detect-frameworks（原缺，违反 SKILL.md:38 三平台兼容铁律）
    local b
    for b in install generate-skill self-check precheck state-machine trace-log cost-report detect-frameworks memory-writeback; do
      src="$SRC_SCRIPTS/$b.bat"
      [[ "$b" == "install" ]] && src="$SRC_SCRIPTS/../install.bat"
      [[ "$b" == "trace-log" || "$b" == "memory-writeback" ]] && src="$ASSETS_DIR/$b.bat"
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
  # F3：用户覆盖层骨架——upgrade 不覆盖用户 patch（_write_if_absent），仅旧版 skill 无此文件时补建
  if [[ ! -f "$SKILL_DIR/scripts/precheck.patch.conf" ]]; then
    cat > "$SKILL_DIR/scripts/precheck.patch.conf" <<'PEOF'
# precheck.patch.conf —— 用户覆盖层（F3 分层 patch）
# 用法：在此覆盖任意生成变量（后 source 即胜出），例：
#   SENSITIVE_TOOL=builtin          # 覆盖 core 层的 auto
#   ACTIVE_FRAMEWORKS=("vue" "koa") # 覆盖 arch 层框架清单
# 请只写覆盖行，不要复制整份生成 conf——升级时本文件原样保留。
PEOF
    echo "  ✓ 已补建 precheck.patch.conf（用户覆盖层骨架）"
  fi
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
      "Bash(bash scripts/generate-skill.sh:*)",
      "Bash(bash scripts/failure-detector.sh:*)",
      "Bash(bash scripts/integrity-guard.sh:*)"
    ],
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(rm -rf ~:*)",
      "Bash(sudo:*)",
      "Bash(curl:* | sh)",
      "Bash(curl:* | bash)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/id_rsa)",
      "Read(**/id_ed25519)",
      "Read(**/*.pem)"
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
generator_version=$SWARM_YUAN_SRC_VERSION
source_repo=$SWARM_YUAN_SRC_DIR
source_version=$SWARM_YUAN_SRC_VERSION
mode=upgrade
EOF
  echo "  ✓ .swarm-yuan-version（已重置 framework_gates_sha，由重注入写入新值）"
  echo "=== 升级完成 ==="
  echo "  备份: $backup_dir"
  echo "  下一步: AI 自动检查 + 运行门禁验证"
  # --upgrade 自动重注入门禁片段（precheck.sh 已被覆盖，区块为空，须重注入）
  # upgrade 场景下 .swarm-yuan-version 的 framework_gates_sha 已在第 4 步重置（cat 覆盖），
  # inject_frameworks 的 sha 冲突检测走"无 old_sha"分支，直接注入不中止。
  # WP-I 物理三分：ACTIVE_FRAMEWORKS 定义在 precheck.arch.conf（standard/compliance 产物），
  # 主 conf 仅 lite 可能直书。触发判定须两处任一命中——此前只查主 conf，导致
  # standard/compliance 档 upgrade 从不触发门禁重注入（区块/ sha/ 快照全空，回归测试发现）。
  if [[ -f "$SKILL_DIR/scripts/precheck.conf" ]] && { grep -q '^ACTIVE_FRAMEWORKS=' "$SKILL_DIR/scripts/precheck.conf" 2>/dev/null || grep -q '^ACTIVE_FRAMEWORKS=' "$SKILL_DIR/scripts/precheck.arch.conf" 2>/dev/null; }; then
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
    workflow.md) echo "九节点全流程，每节点 4 要素（入口/参与方/门禁/产出物与调用追踪），4-Phase SOP" ;;
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
  if [[ "$f" == "workflow.md" ]]; then
    # S10/S4 实装：workflow.md 不再 2 行占位，emit 9 节点骨架（R13 批次1b 后 4 要素/节点），
    # 节点②探查的 ⑨ 调用追踪预填 trace-log 模板（具体化 SKILL.md:86 的 AI 自由动作）。
    # 节点名对齐 template-spec.md:198-207 标准 9 节点（⑥测试验证 + ⑦独立审查独立拆分，审查留痕 review-record 落盘）。
    _write_if_absent "$SKILL_DIR/references/$f" <<'WFEOF'
# workflow.md — 九节点全流程（4 要素/节点：入口/参与方/门禁/产出物与调用追踪）

> 填充指引：九节点全流程，每节点 4 要素（入口/参与方/门禁/产出物与调用追踪），4-Phase SOP。
> 节点名对齐 references/template-spec.md §2 标准 9 节点（⑥测试验证 + ⑦独立审查独立拆分，审查留痕 review-record 落盘）；按项目实际裁剪。

## 流程总览

（流程图，标注：①→②→③ 串行节点；并行节点用 └──┘ 标注）

> **编号体系消歧**：本 workflow 的 ①-⑨ 是**开发工作流节点**；SKILL.md（生成器侧）流程图的 ⓪-⑨ 是**生成流程步骤**——两套编号独立，同名符号不同义。
> **state-machine 六阶段 ↔ 九节点对照**（粗粒度状态桶 ↔ 细粒度执行流，`scripts/state-machine.sh` 按阶段守产出物）：
> open=①需求理解+②探查 ｜ design=③设计 spec+④实施 plan ｜ build=⑤编码实现 ｜ verify=⑥测试验证+⑦独立审查 ｜ archive=⑧合入 main ｜ operate=⑨构建发布

---

## 节点①：需求理解

**① 流程入口（顺序/并行）：** （本节点在流程中的位置：前序节点、后续节点、可并行项）

**② 参与方：** （谁参与，谁是决策方，谁执行）

**③ 前序依赖检查（准入）：**
- （进入本节点前必须满足的条件）
- 信息不足时的处理（提问澄清，不臆测）

**④ 质量门禁：**
- （离开本节点前必须满足的条件，可被 precheck.sh 验证）



**⑥ 产出物与调用追踪：**
- 持久化：（落盘到哪个路径）
- 临时上下文：（仅对话/草稿的产物）





**调用追踪：**
- 公告：进入本节点时 AI 输出一行结构化提示，格式 `→ [节点① 需求理解] 调用 <技能/子代理/工具> · <目的>`
- 落盘：节点级默认——进入/完成本节点时执行 `bash scripts/trace-log.sh --node "需求理解" --actor "<技能/子代理>" --tool "<工具/命令>"`，追加到 `.swarm-yuan/trace.jsonl`

---

## 节点②：探查（设计 spec 前的仓库探查）

**① 流程入口（顺序/并行）：** 前序=节点①；可三路并行（结构/规范/代码组织子代理）

**② 参与方：** controller + 三路子代理（结构/规范/代码组织）

**③ 前序依赖检查（准入）：**
- 节点①需求理解已完成
- 项目路径可访问

**④ 质量门禁：**
- 探查覆盖度（组件库清单全量穷举，非代表性样本）



**⑥ 产出物与调用追踪：**
- 持久化：特征卡写入 SKILL.md；组件库清单写入 codebase.md
- 临时上下文：探查中间产物





**调用追踪：**
- 公告：每路子代理启动/完成时输出 `→ [节点② 探查] 调用 结构子代理 · gitnexus context（started/done）`
- 落盘：每路子代理启动前执行 `bash scripts/trace-log.sh --node "探查" --actor "结构子代理" --tool "gitnexus context" --status started`，完成后 `--status done`（规范/代码组织子代理同理）

---

## 节点③：设计 spec

**① 流程入口（顺序/并行）：** 前序=节点②

**② 参与方：** AI + 用户（spec 评审）

**③ 前序依赖检查（准入）：** 节点②探查完成（特征卡+组件库清单就绪；架构设计/演进类变更还须四层架构枚举——探查侧 §C+.0.6，生成器侧 exploration-guide）

**④ 质量门禁：** ★测试左移（spec §19 测试设计）+ ★运维左移（spec §21 可观测性约束）+ SPEC_REQUIRED 前置门（fail-gate-hook 拦无 spec 写码）+ 架构类变更须填 spec §24 架构映射（TOGAF BDAT 四层+纵向链验证，非架构变更可豁免）



**⑥ 产出物与调用追踪：** 持久化：references/spec.md





**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "设计 spec" --actor "<技能>" --tool "<工具>"`

---

## 节点④：实施 plan

**① 流程入口（顺序/并行）：** 前序=节点③

**③ 前序依赖检查（准入）：** spec 通过评审

**④ 质量门禁：** ★变更左移（plan §20 变更影响范围：消费方反查/回滚预案/灰度策略/迁移兼容窗口）

**⑥ 产出物与调用追踪：** 持久化：references/plan.md（OpenSpec tasks checkbox 格式）

**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "实施 plan" --actor "<技能>" --tool "<工具>"`

---

## 节点⑤：编码实现

**① 流程入口（顺序/并行）：** 前序=节点④；复杂变更（>3 文件/跨模块）用 Dynamic Workflows 并行扇出

**④ 质量门禁：** ★测试左移（每个 task 先写/更新测试再实现，TDD/BDD；precheck `--shift-left` 校验 test 与 impl 同分支提交）

**⑥ 产出物与调用追踪：** 代码提交 + 测试提交

**⑨ 调用追踪：** 子代理派发时 `bash scripts/trace-log.sh --node "编码实现" --actor "implementer" --tool "<task>" --status started`

---

## 节点⑥：测试验证

**① 流程入口（顺序/并行）：** 前序=节点⑤

**④ 质量门禁：** gstack/OCR 5 审查维度 + AUTO-FIX/ASK；★运维左移（验证 metrics/日志/trace 已埋点）；独立跑单元/集成测试 + `check_test` 门禁（0 用例检测 / 断言密度 / Mutation Check 测试有效性）

**⑥ 产出物与调用追踪：** 测试报告 + 测试有效性证据（mutation score）

**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "测试验证" --actor "tester" --tool "pytest/mutation"`

---

## 节点⑦：独立审查

**① 流程入口（顺序/并行）：** 前序=节点⑥

**④ 质量门禁：** 独立 code review（第三方 reviewer 视角，非 Step 7 自检）+ `check_review` 门禁（核验 `references/review-record.md` 留痕非空：5 维审查点 + findings 表）

**⑥ 产出物与调用追踪：** `references/review-record.md` 审查证据产物（从 review-record-template.md 填充）

**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "独立审查" --actor "reviewer" --tool "review-record"`

---

## 节点⑧：合入 main

**① 流程入口（顺序/并行）：** 前序=节点⑦

**④ 质量门禁：** ★变更左移（回滚预案存在 + 数据库变更兼容：向前兼容/双写期）

**⑥ 产出物与调用追踪：** merge commit

**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "合入 main" --actor "<技能>" --tool "git merge"`

---

## 节点⑨：构建发布

**① 流程入口（顺序/并行）：** 前序=节点⑧（合入 main 后方可发布）

**④ 质量门禁：** ★运维左移（灰度/金丝雀策略 + 监控告警阈值 + 运维 runbook）

**⑥ 产出物与调用追踪：** 发布产物 + release notes——发布规则/构建命令/产物位置填入并消费 \`references/release.md\`（六段式正式成员，本节点消费方）

**⑨ 调用追踪：** `bash scripts/trace-log.sh --node "构建发布" --actor "<技能>" --tool "<构建命令>"`

---

## 终检：流程完成检查表（⑨）

（全流程完成前的 checkbox 清单，汇总所有节点的门禁）
- [ ] 节点①需求理解：特征卡 17 项齐备
- [ ] 节点②探查：组件库清单全量 + 调用链
- [ ] 节点③设计 spec：§19 测试设计 + §21 可观测性
- [ ] 节点④实施 plan：§20 变更影响范围
- [ ] 节点⑤编码实现：测试与实现同分支提交
- [ ] 节点⑥测试验证：5 维度审查通过 + check_test 门禁
- [ ] 节点⑦独立审查：review-record.md 留痕 + check_review 门禁
- [ ] 节点⑧合入 main：回滚预案 + 迁移兼容
- [ ] 节点⑨构建发布：灰度 + 告警 + runbook
WFEOF
  else
    if [[ "$f" == "reference-manual.md" ]]; then
      # R13 批次1b：reference-manual.md 两维表骨架（五维表减负——"维度/来源"列纯记账退役）。
      # 原因：inventory-verify --path-check / --stability-audit 期望 §4/§6/§9 表格行内含反引号路径
      # + 稳定性标注（稳定/禁止改），骨架表头让 AI 有结构起点而非从 0 造（R13 批次1b 已减负为两维）。
      # 骨架仅给表头 + 一行示例（P1 待补标记——mark-active 前必须替换为真实条目）。
      _write_if_absent "$SKILL_DIR/references/$f" <<'RMEOF'
# reference-manual.md — 项目参考手册（组件库清单 / 接口约束 / 数据勾稽）

> 填充指引：按 exploration-guide §C+ 探查后填充。§4/§6/§9 表格行两列：`| 路径 | 说明与约束 |`；
> 路径用反引号包裹（--path-check 校验存在性）；稳定性标注词写进说明列（如"导出 add（禁止改）"）——
> --stability-audit 按行内字面词识别（与列位置无关）。说明列 = AI 读代码后的理解，不是填表。
>
> **语义/动能两区纪律**（本体层口径，见 `references/ontology/links.md` 使用纪律）：本文件的说明列是**表征区**（描述性——仓库是什么样的：组件/接口/依赖）；**规范性内容**（应当怎样——约束/禁令的执行体）只落 rules.d/*.rules 与门禁，本文件至多**引用**规范词（如稳定性标注词），不承载规范的执行逻辑。是/应当不混写。

## §4 组件库清单

| 路径 | 说明与约束 |
|------|--------------|
| `src/components/Example.tsx` | （P1 待补）导出 `Example` 函数；入参 `props: Props`（稳定） |

## §6 接口清单

| 路径 | 说明与约束 |
|------|--------------|
| `src/api/example.ts` | （P1 待补）`GET /api/example`；返回 `ExampleVO`（稳定） |

## §9 数据勾稽

| 路径 | 说明与约束 |
|------|--------------|
| `src/service/order.ts` | （P1 待补）订单金额 = Σ 明细金额；库存 = 在库 + 在途（禁止改——勾稽恒等式） |

---

（其余 §1/§2/§3/§5/§7/§8/§10/§11 节按 references/template-spec.md 维度注册表补齐—— lite 档精简到 §4/§6/§9 三节，standard/compliance 档补全）
RMEOF
    else
      _write_if_absent "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f
> 填充指引：$(fill_guide "$f")
EOF
    fi
  fi
done

# WP-E：lite 档跳过 hooks/settings/.mcp.json/commands（无 hooks 生命周期与 slash 命令负担）
if [[ "$PROFILE" != "lite" ]]; then
_write_if_absent "$SKILL_DIR/hooks/hooks.json" <<'HEOF'
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|clear|compact", "command": "echo \"→ [hook:SessionStart] 调用 state-machine.sh status（阶段状态追踪）\"; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" status 2>/dev/null || true; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" restore-journal 2>/dev/null || true; _fp=\"${CLAUDE_PLUGIN_ROOT:-.}/scripts/project-fingerprint.sh\"; if [[ -f \"$_fp\" ]]; then _proj=$( (set +u; . \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.conf\" 2>/dev/null; printf '%s' \"${PROJECT_DIR:-}\") ); if [[ -n \"$_proj\" && -d \"$_proj\" ]]; then _fp_out=$(bash \"$_fp\" \"$_proj\" --diff --quiet 2>/dev/null || true); if printf '%s\\n' \"$_fp_out\" | LC_ALL=C grep -q '⚠'; then echo \"⚠ [hook:SessionStart] 项目源码指纹已变化——按 SKILL.md「自成长」段走更新链（感知: bash scripts/project-fingerprint.sh <项目根> --diff）\"; fi; fi; fi; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --state-phase 2>/dev/null || true"}],
    "PreCompact": [{"matcher": "*", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" dump-journal 2>/dev/null || true", "timeout": 5}],
    "PreToolUse": [{"matcher": "Write|Edit", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --scope >/dev/null 2>&1 && echo \"→ [hook:PreToolUse] 调用 precheck --scope：✓ pass\" || echo \"→ [hook:PreToolUse] 调用 precheck --scope：✗ FAIL——运行 bash scripts/precheck.sh --scope 查看详情\""}, {"matcher": "Write|Edit|MultiEdit|Bash|WebSearch|WebFetch", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/integrity-guard.sh\" 2>/dev/null || true", "timeout": 5}, {"matcher": "Write|Edit|MultiEdit|Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/fail-gate-hook.sh\" 2>/dev/null || true", "timeout": 5}],
    "PostToolUse": [{"matcher": "Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/failure-detector.sh\" 2>/dev/null || true", "timeout": 5}, {"matcher": "Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/fail-gate-hook.sh\" 2>/dev/null || true", "timeout": 5}, {"matcher": "Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --operate 2>/dev/null || true", "timeout": 5}, {"matcher": "Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --pr-quality 2>/dev/null || true", "timeout": 10}, {"matcher": "Bash", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --skill-supply-chain 2>/dev/null || true", "timeout": 10}],
    "Stop": [{"matcher": "*", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/loop-hook.sh\" 2>/dev/null || true; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --decision-audit 2>/dev/null || true; bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --learnings 2>/dev/null || true; _mw=\"${CLAUDE_PLUGIN_ROOT:-.}/scripts/memory-writeback.sh\"; [[ -f \"$_mw\" ]] && bash \"$_mw\" 2>/dev/null || true", "timeout": 310}]
  }
}
HEOF

# settings.local.json（WP-A1：真生成，落实 SKILL.md Step 9 宣称）
# 最小权限模板：允许本 skill 自带脚本执行；deny 危险命令 + 敏感文件读（沙箱通配符 deny——
# Claude Code v2.1.236 起 ** glob 防重命名绕过：Read(**/.env) 在 allowed read 区域内优先生效）。
# 项目特定权限由 AI 填充。
_write_if_absent "$SKILL_DIR/settings.local.json" <<'SEOF'
{
  "permissions": {
    "allow": [
      "Bash(bash scripts/precheck.sh:*)",
      "Bash(bash scripts/state-machine.sh:*)",
      "Bash(bash scripts/self-check.sh:*)",
      "Bash(bash scripts/trace-log.sh:*)",
      "Bash(bash scripts/generate-skill.sh:*)",
      "Bash(bash scripts/failure-detector.sh:*)",
      "Bash(bash scripts/integrity-guard.sh:*)"
    ],
    "deny": [
      "Bash(rm -rf /:*)",
      "Bash(rm -rf ~:*)",
      "Bash(sudo:*)",
      "Bash(curl:* | sh)",
      "Bash(curl:* | bash)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/id_rsa)",
      "Read(**/id_ed25519)",
      "Read(**/*.pem)"
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

探查方法论与降级链：`references/exploration-guide.md`（§C+.0 形态判定 → §C+.0.5 框架激活 → §C+.0.6 四层架构枚举 → §C+.1 全量穷举）。
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

## 项目认知摘要（生成器检测回填——特征卡 #1 项目类型 / #4 技术栈的承接点，AI 填充时在此基础上深化）

| 特征项 | 生成器检测值（AUTO:detected） |
|--------|------------------------------|
| 项目根 | ${PROJECT_DIR} |
| 构建命令 | $(grep -m1 '^BUILD_CMD=' "$SKILL_DIR/scripts/precheck.conf" 2>/dev/null | sed "s/^BUILD_CMD=//;s/'//g;s| *#.*||" || echo "（AI 探查填充）") |
| 测试命令 | $(grep -m1 '^TEST_CMD=' "$SKILL_DIR/scripts/precheck.conf" 2>/dev/null | sed "s/^TEST_CMD=//;s/'//g;s| *#.*||" || echo "（AI 探查填充）") |
| 检测框架 | $(bash "$SRC_SCRIPTS/detect-frameworks.sh" "$PROJECT_DIR" 2>/dev/null | grep -E '^ACTIVE_FRAMEWORKS=' | sed 's/^ACTIVE_FRAMEWORKS=//;s/[()"]//g' || echo "（无已知框架）") |

> 项目类型（单体/monorepo/overlay-fork/微服务）与改造分类（A 纯新增/B 骨架修改）由 AI 探查判定后填充——
> 生成器只做机械嗅探（构建/测试命令/框架清单），形态判定（§C+.0）与改造分类是语义判断属 AI 职责。

## 填充指引
- [ ] meta: 核心理念+改造分类+流程总览+命令速查+门禁+反借口表（借口/反驳两列表，从门禁步骤逐条反推，见 template-spec §1.5）+假设清单（需求/架构/范围三维度+"现在纠正我"，见 template-spec §1.5）
EOF
# WP-E：checklist 按档裁剪（lite 无 workflow/commands/hooks 条目）
if [[ "$PROFILE" != "lite" ]]; then
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] workflow: 九节点+每节点 4 要素（入口/参与方/门禁/产出物与调用追踪）+4-Phase SOP
- [ ] reference: codebase/dev-guide/release/reference-manual + 方法论+认知 reference
EOF
else
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] reference: reference-manual（特征卡 P0 六项 + 全量构件库清单）
EOF
fi
cat >> "$SKILL_DIR/SKILL.md" <<EOF
- [ ] assets: spec-template(§5.5-§18) + plan + branch + env + data + state-machine
- [ ] check: precheck.sh 门禁四族（计数真值见 assets/facts.conf；core 随 --all，arch 随 --all-full，compliance 随 --compliance-suite）
- [ ] scripts: precheck + state-machine + trace-log + cost-report
- [ ] 决策记录：spec §2 决策记录段写本技能生成/选型决策到 \`.swarm-yuan/decisions.jsonl\`（≥1 条；UserChallenge 类须带 missing_context/cost_if_wrong）——\`--mark-active\` 核验项
EOF
# WP-R2-2：自成长指引段（固定操作指引，非填充项——目标技能的 AI 按此链保持技能与项目同步）
# WP-R3-1：profile 分档——lite 档 WP-E 不装 hooks/hooks.json，SessionStart 自动感知链不存在；
# 须明示"lite 档须 AI 在会话开始时手动跑 --diff"，别让文档撒谎说"hook 已自动感知"。
if [[ "$PROFILE" == "lite" ]]; then
cat >> "$SKILL_DIR/SKILL.md" <<'EOF'

## 自成长（项目变了，本技能跟着变）

本技能的组件库清单/编排约束是生成时刻的快照。项目代码演进后按此链更新：

1. **感知**（会话开始时手动跑，秒级——lite 档按 WP-E 裁剪未装 SessionStart hook，AI 须在每个开发会话开始时主动跑一次）：`bash scripts/project-fingerprint.sh <项目根> --diff`；提示无基线时先 `--write` 落基线。若升级到 standard/compliance 档会自动装 SessionStart hook 实现自动感知。
2. **判断**：输出「⚠ 项目源码已变化」→ 走更新链；「无变化」→ 继续正常开发。
3. **更新链**（检测到变化后）：
   - 工具链刷新：用生成器（路径见本目录 `.swarm-yuan-version` 的 `source_repo`）跑 `generate-skill.sh --refresh <本技能目录>` 看 dry-run 报告 → `--upgrade` 更新门禁/模板（reference-manual.md 等项目内容文件保留不动）
   - 内容刷新（局部重探查，dsh R12 吸收）：`--diff` 报告的「变化目录（scope）」就是重探查范围——**只针对变化 scope** 按 swarm-yuan `references/exploration-guide.md` §C+ 重探查（新增/消失/改名组件），更新 `references/reference-manual.md` 对应清单条目；未变 scope 的条目原样保留（SHA 未变即不重写）
   - 核验：生成器侧 `inventory-verify.sh` 计数核验（清单 ≥ 枚举 ×0.95 + 路径存在性防幻觉）
4. **落新基线**：更新完成后 `bash scripts/project-fingerprint.sh <项目根> --write`。

红线：① 指纹只感知结构变化（文件数/扩展名/骨架 cksum/目录 cksum）；语义变化（约束失效/接口语义变更）靠 AI 在编码流程中发现即更新清单，不等 refresh。② **清单更新先完整生成再原子替换，探查中途失败绝不覆盖上一份好清单**（last-good 保留：探查输出条目数骤降 >50% 视为失败，保留旧清单并告警）。
EOF
else
cat >> "$SKILL_DIR/SKILL.md" <<'EOF'

## 自成长（项目变了，本技能跟着变）

本技能的组件库清单/编排约束是生成时刻的快照。项目代码演进后按此链更新：

1. **感知**（会话开始时可跑，秒级）：`bash scripts/project-fingerprint.sh <项目根> --diff`；提示无基线时先 `--write` 落基线。Claude Code 的 SessionStart hook 已自动感知；其他运行时由 AI 在会话开始时主动跑本命令。
2. **判断**：输出「⚠ 项目源码已变化」→ 走更新链；「无变化」→ 继续正常开发。
3. **更新链**（检测到变化后）：
   - 工具链刷新：用生成器（路径见本目录 `.swarm-yuan-version` 的 `source_repo`）跑 `generate-skill.sh --refresh <本技能目录>` 看 dry-run 报告 → `--upgrade` 更新门禁/模板（reference-manual.md 等项目内容文件保留不动）
   - 内容刷新（局部重探查，dsh R12 吸收）：`--diff` 报告的「变化目录（scope）」就是重探查范围——**只针对变化 scope** 按 swarm-yuan `references/exploration-guide.md` §C+ 重探查（新增/消失/改名组件），更新 `references/reference-manual.md` 对应清单条目；未变 scope 的条目原样保留（SHA 未变即不重写）
   - 核验：生成器侧 `inventory-verify.sh` 计数核验（清单 ≥ 枚举 ×0.95 + 路径存在性防幻觉）
4. **落新基线**：更新完成后 `bash scripts/project-fingerprint.sh <项目根> --write`。

红线：① 指纹只感知结构变化（文件数/扩展名/骨架 cksum/目录 cksum）；语义变化（约束失效/接口语义变更）靠 AI 在编码流程中发现即更新清单，不等 refresh。② **清单更新先完整生成再原子替换，探查中途失败绝不覆盖上一份好清单**（last-good 保留：探查输出条目数骤降 >50% 视为失败，保留旧清单并告警）。
EOF
fi
# WP-P5: SKILL.md「按需读取」索引表自动生成（依据实际拷入的 UNIVERSAL_FILES 分级清单）
# 仅 create 分支执行（resume 分支走 else 跳过，不重复追加）；表按 UNIVERSAL_FILES 数组顺序输出。
_idx_file="$SKILL_DIR/.universal-files-index.md"
{
  echo "## 按需读取引用索引（自动生成，勿手改——由 generate-skill.sh 依据 profile 档生成）"
  echo ""
  echo "| 文件 | 用途 | profile 档 |"
  echo "|------|------|-----------|"
  for entry in "${UNIVERSAL_FILES[@]}"; do
    _path=${entry%%|*}; _rest=${entry#*|}; _cat=${_rest%%|*}; _tier=${_rest#*|}
    [[ "$_tier" == "$_rest" ]] && _tier="standard"
    # 按 profile 档过滤（档序 lite<standard<compliance，已由拷贝逻辑保证存在性，这里只列已拷入的）
    [[ -f "$SKILL_DIR/$_path" ]] || continue
    printf '| %s | %s | %s |\n' "$_path" "$_cat" "$_tier"
  done
} > "$_idx_file"
[[ -f "$SKILL_DIR/SKILL.md" ]] && cat "$_idx_file" >> "$SKILL_DIR/SKILL.md" && rm -f "$_idx_file"
else
  echo "  续传跳过（已存在）: $SKILL_DIR/SKILL.md"
fi

_write_if_absent "$SKILL_DIR/.swarm-yuan-version" <<EOF
created_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
generator_version=$SWARM_YUAN_SRC_VERSION
source_repo=$SWARM_YUAN_SRC_DIR
source_version=$SWARM_YUAN_SRC_VERSION
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

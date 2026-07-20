#!/usr/bin/env bash
# generate-skill.sh — swarm-yuan 目标技能脚手架生成器 / 升级器
# 用法:
#   bash generate-skill.sh <skill-name> <project-dir> [target-dir]       # 创建新技能骨架
#   bash generate-skill.sh --upgrade <skill-name> <project-dir> [target-dir]  # 升级已存在技能
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
UNIVERSAL_FILES=(
  "assets/spec-template.md|assets"
  "assets/plan-template.md|assets"
  "assets/branch-setup.sh|assets"
  "assets/env-setup.sh|assets"
  "assets/data-sample-template.md|assets"
  "assets/state-machine.sh|assets"
  "scripts/precheck.sh|assets"
  "scripts/precheck.conf|assets"
  "scripts/snippets.md|assets"
  "scripts/mcp-tools.md|assets"
  "scripts/state-machine.sh|assets"
  "scripts/self-check.sh|gen"
  "references/subagent-orchestration.md|ref"
  "references/review-methodology.md|ref"
  "references/code-graph-tools.md|ref"
  "references/gsd-patterns.md|ref"
  "references/memory-persistence.md|ref"
  "references/security-spec.md|ref"
  "references/cognition-framework.md|ref"
  "references/logic-razor.md|ref"
  "references/cognitive-bias.md|ref"
  "references/domain-knowledge.md|ref"
  "references/claude-code-capabilities.md|ref"
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
      grep -q "^${var}=" "$conf" 2>/dev/null || missing+=("$var")
    done
  done
  # 去重
  local uniq_missing=() useen=""
  for var in "${missing[@]+"${missing[@]}"}"; do
    case " $useen " in *" $var "*) continue;; esac
    useen="$useen $var"; uniq_missing+=("$var")
  done
  if [[ ${#uniq_missing[@]} -gt 0 ]]; then
    echo "" >> "$conf"
    echo "# ===== 由 upgrade 增量补充（激活框架需要的变量，用户未声明）=====" >> "$conf"
    for var in "${uniq_missing[@]}"; do
      printf '%s=()  # TODO(upgrade): 由用户按项目实际填充\n' "$var" >> "$conf"
      echo "⚠ conf 缺失变量 ${var}，已注入占位（须填充）"
    done
  fi
}

inject_frameworks() {
  local skill_dir="$1"
  local paradigm_dir; paradigm_dir="$(cd "$(dirname "$0")/.." && pwd)"
  local sh="$skill_dir/scripts/precheck.sh"
  local conf="$skill_dir/scripts/precheck.conf"
  local ver="$skill_dir/.swarm-yuan-version"
  [[ -f "$sh" ]]  || { echo "✗ 未找到 $sh"; return 1; }
  [[ -f "$conf" ]] || { echo "✗ 未找到 $conf"; return 1; }

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
  . "$conf"
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
        grep -q "^${var}=" "$conf" 2>/dev/null || missing_conf+=("$var")
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
      echo "  为避免静默删除区块之后的公共库/main 分发，已中止注入（未改动 $sh）。" >&2
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

  # 3) 缺失 conf 变量：注入占位 + warn（不静默）
  for var in ${missing_conf[@]+"${missing_conf[@]}"}; do
    printf '%s=()  # TODO(framework-gates): 由生成流程 Step 7.5 填充\n' "${var}" >> "$conf"
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

# ---- 检测运行环境 ----
detect_skill_dir() {
  local project="$1"
  if [[ -d "$project/.claude/skills" ]]; then echo "$project/.claude/skills"; return; fi
  if [[ -d "$HOME/.claude/skills" ]]; then echo "$HOME/.claude/skills"; return; fi
  if [[ -d "$HOME/.codex/skills" ]]; then echo "$HOME/.codex/skills"; return; fi
  if [[ -d "$HOME/.cursor/skills" ]]; then echo "$HOME/.cursor/skills"; return; fi
  if [[ -d "$HOME/.codeium/windsurf/skills" ]]; then echo "$HOME/.codeium/windsurf/skills"; return; fi
  if [[ -d "$HOME/.config/opencode/skills" ]]; then echo "$HOME/.config/opencode/skills"; return; fi
  if [[ -d "$HOME/.gemini/skills" ]]; then echo "$HOME/.gemini/skills"; return; fi
  if [[ -d "$HOME/.kimi/skills" ]]; then echo "$HOME/.kimi/skills"; return; fi
  echo "$project/.claude/skills"
}

detect_runtime_name() {
  local project="$1"
  if [[ -d "$project/.claude/skills" || -d "$HOME/.claude/skills" ]]; then echo "Claude Code"
  elif [[ -d "$HOME/.codex/skills" ]]; then echo "Codex"
  elif [[ -d "$HOME/.cursor/skills" ]]; then echo "Cursor"
  elif [[ -d "$HOME/.codeium/windsurf/skills" ]]; then echo "Windsurf"
  elif [[ -d "$HOME/.config/opencode/skills" ]]; then echo "OpenCode"
  elif [[ -d "$HOME/.gemini/skills" ]]; then echo "Gemini CLI"
  elif [[ -d "$HOME/.kimi/skills" ]]; then echo "Kimi"
  else echo "通用"
  fi
}

# ---- 解析模式 ----
MODE="create"
if [[ "${1:-}" == "--upgrade" ]]; then MODE="upgrade"; shift; fi

SKILL_NAME="${1:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
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
  local mode="${2:-create}"   # create=覆盖 precheck.conf（新建骨架）；upgrade=不覆盖（保留用户配置，由 merge_precheck_conf 增量补）
  local entry dest kind src
  for entry in "${UNIVERSAL_FILES[@]}"; do
    dest="${entry%%|*}"; kind="${entry##*|}"
    # precheck.conf：create 模式覆盖模板；upgrade 模式保留用户配置（由 merge_precheck_conf 增量补缺失变量）
    [[ "$mode" == "upgrade" && "$dest" == "scripts/precheck.conf" ]] && continue
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
    # scripts/ 下的 .bat（install/generate-skill/self-check/precheck/state-machine）
    local b
    for b in install generate-skill self-check precheck state-machine; do
      src="$SRC_SCRIPTS/$b.bat"
      [[ "$b" == "install" ]] && src="$SRC_SCRIPTS/../install.bat"
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
  echo "=== 升级: $SKILL_DIR ==="
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
  exit 0
fi

# ============================================================
# 创建模式
# ============================================================
[[ -d "$SKILL_DIR" ]] && { echo "ERROR: 已存在: $SKILL_DIR（用 --upgrade 升级）"; exit 1; }

echo "=== 创建: $SKILL_DIR ==="
mkdir -p "$SKILL_DIR"/{references,assets,scripts,hooks,commands}
copy_universal_templates "$SKILL_DIR"

fill_guide() {
  case "$1" in
    workflow.md) echo "八节点全流程，每节点 9 要素，4-Phase SOP，节点①含读取项目知识子步骤" ;;
    codebase.md) echo "目录结构+技术栈版本表+端口+配置" ;;
    dev-guide.md) echo "改造分类+拼装式开发原则+安全编码规范" ;;
    release.md) echo "编译规则+构建命令+产物位置" ;;
    reference-manual.md) echo "安全+组件+接口+数据+认知映射+谬误图谱+领域知识" ;;
    *) echo "见 template-spec.md" ;;
  esac
}
for f in workflow.md codebase.md dev-guide.md release.md reference-manual.md; do
  cat > "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f
> 填充指引：$(fill_guide "$f")
EOF
done

cat > "$SKILL_DIR/hooks/hooks.json" <<'HEOF'
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|clear|compact", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" status 2>/dev/null || true"}],
    "PreToolUse": [{"matcher": "Write|Edit", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --scope --quiet 2>/dev/null || true"}]
  }
}
HEOF

cat > "$SKILL_DIR/commands/spec.md" <<'CEOF'
---
description: 开始新需求——AI 自动创建 spec + 判断规模 + 预填复用约束
argument-hint: <需求描述>
---
AI 自动：1.创建 spec 文件 2.判断规模 3.预填 §5.5 4.运行 --reuse 验证
$ARGUMENTS
CEOF
cat > "$SKILL_DIR/commands/precheck.md" <<'CEOF'
---
description: 运行门禁检查
argument-hint: --all | --all-full | <gate>
---
bash scripts/precheck.sh $ARGUMENTS
CEOF
cat > "$SKILL_DIR/commands/explore.md" <<'CEOF'
---
description: 探查项目结构
---
用 gitnexus/graphify/claude-mem 探查项目，更新特征卡。
CEOF

cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $SKILL_NAME
description: （填充指引：触发条件 + 项目关键词）
---
# $SKILL_NAME — （填充指引：项目名 + 需求交付全流程技能）
> 由 swarm-yuan 生成器创建（${SWARM_YUAN_STAMP}），需 AI agent 探查后填充。
> 填充规范见 swarm-yuan/references/template-spec.md
## 填充指引
- [ ] meta: 核心理念+改造分类+流程总览+命令速查+门禁
- [ ] workflow: 八节点+4-Phase SOP+每节点读取项目知识
- [ ] reference: codebase/dev-guide/release/reference-manual + 方法论+认知 reference
- [ ] assets: spec-template(§5.5-§18) + plan + branch + env + data + state-machine
- [ ] check: precheck.sh 25 门禁
- [ ] scripts: precheck + state-machine + snippets + mcp-tools
EOF

cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
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
echo "  升级已有技能: bash generate-skill.sh --upgrade $SKILL_NAME $PROJECT_DIR"

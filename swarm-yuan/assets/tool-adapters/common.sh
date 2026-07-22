#!/usr/bin/env bash
# common.sh — 多平台规则渲染公共库（generate-skill.sh --render-tools 与 install.sh 共用 source）
# 职责：从目标 skill 的 SKILL.md + scripts/precheck.conf 派生各 AI 工具原生规则文件。
# 适配器契约：assets/tool-adapters/<tool>.sh 定义 render_tool_<tool> <skill_dir> <proj> <level>，
#   level ∈ user（工具全局规则位）| project（项目根规则文件）；TA_* 全局变量由调度器预填。
# 幂等约定：生成内容不含时间戳等易变字段，ta_write_if_changed 内容一致即 no-op。
# 调用方须先设置 TA_DIR（本适配器目录绝对路径）再 source 本文件。
#
# 格式依据（均访问于 2026-07-20）：
#   Cursor .mdc frontmatter（description/globs/alwaysApply 三字段 → 四种激活方式）：
#     https://qaskills.sh/blog/cursor-skill-md-frontmatter-schema-guide
#   Windsurf .windsurf/rules/*.md（trigger 四值；2026-06 起新版偏好 .devin/rules/，
#     .windsurf/rules/ 保留回退；全局规则 6,000 字符硬上限）：
#     https://skillwright.app/blog/windsurf-rules-guide
#     https://thepromptshelf.dev/blog/windsurf-vs-cursor-vs-agents-md-2026/
#   各工具全局/项目指令文件对照（Codex ~/.codex/AGENTS.md、OpenCode
#     ~/.config/opencode/AGENTS.md、Gemini ~/.gemini/GEMINI.md、Kimi 仅项目 AGENTS.md）：
#     https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624

# ---- G7：AI 工具兼容三档机器可读元数据 ----
# runnable（可运行，目录复制即被该工具加载约定消费）
# cli（集成，runnable + --render-tools 派生该工具原生规则文件）
# deep（深度集成，cli + slash command 注册 + hooks/commands/MCP）
# 声明式元数据；未声明工具 ta_tier_of 默认按 runnable（最低档）处理，不阻塞。
# 口径权威源：assets/facts.conf（FACT_COMPAT_TIERS=3/DEEP=1/CLI=6），self-check 对账。
TA_TIER_claude=deep
TA_TIER_cursor=cli
TA_TIER_windsurf=cli
TA_TIER_codex=cli
TA_TIER_opencode=cli
TA_TIER_gemini=cli
TA_TIER_kimi=cli

# 按工具查 tier（bash 3.2 兼容：间接展开 eval，不用 declare -A 关联数组）
ta_tier_of() {  # $1=tool → stdout tier（runnable/cli/deep）
  local tool="$1"
  eval "echo \"\${TA_TIER_${tool}:-runnable}\""
}

# ---- 用户级工具 home 判定（与 install.sh detect_runtimes 的 7 目录一一对应）----
ta_is_user_level() {  # $1=tool_home
  case "$1" in
    "$HOME/.claude"|"$HOME/.cursor"|"$HOME/.codex"|"$HOME/.gemini"|"$HOME/.kimi"|"$HOME/.config/opencode"|"$HOME/.codeium/windsurf") return 0 ;;
    *) return 1 ;;
  esac
}

# ---- 从 SKILL.md frontmatter 提取单行字段（name/description）；无命中输出空 ----
ta_parse_skill_field() {  # $1=skill_dir $2=字段名 → stdout 字段值
  local f="$1/SKILL.md" key="$2"
  [[ -f "$f" ]] || return 0
  # 无 frontmatter（首行非 ---）直接返回空
  [[ "$(head -n 1 "$f" 2>/dev/null)" == "---" ]] || return 0
  awk -v key="$key" '
    NR == 1 { next }                       # 跳过首个 ---
    /^---[[:space:]]*$/ { exit }           # frontmatter 结束
    index($0, key ":") == 1 {              # 行首命中 key:
      val = substr($0, length(key) + 1)
      sub(/^:[[:space:]]*/, "", val)       # 去掉冒号与前导空格
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      sub(/^"/, "", val); sub(/"$/, "", val)
      print val
      exit
    }
  ' "$f"
}

# ---- 读取 precheck.conf 的 ACTIVE_FRAMEWORKS（conf 缺失/未配置静默输出空）----
# conf 可能含字面 ${}（如 SQL_INJECTION_WHITELIST），照搬 inject_frameworks 的 set +u 子 shell 模式
ta_active_frameworks() {  # $1=skill_dir → 空格分隔框架清单（可空）
  local conf="$1/scripts/precheck.conf"
  [[ -f "$conf" ]] || return 0
  (
    set +u
    # shellcheck disable=SC1090
    . "$conf" 2>/dev/null
    printf '%s ' ${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}
  )
}

# ---- YAML 双引号字符串转义（换行折叠为空格，转义反斜杠与双引号）----
ta_yaml_dq() {
  printf '%s' "$1" | tr '\n' ' ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# ---- 幂等写：内容一致即 no-op，否则原子替换（mktemp + mv）----
ta_write_if_changed() {  # <tmpfile> <dest> <label>
  local tmp="$1" dest="$2" label="$3"
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
    echo "  · ${label}: 内容一致，跳过（no-op）"
    return 0
  fi
  local existed=0
  if [[ -f "$dest" ]]; then existed=1; fi
  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest"
  if [[ "$existed" -eq 1 ]]; then
    echo "  ✓ ${label}: 已更新 $dest"
  else
    echo "  ✓ ${label}: 已生成 $dest"
  fi
  return 0
}

# ---- 标记区块幂等 upsert（AGENTS.md / GEMINI.md / Windsurf global_rules.md 用）----
# 区块已存在则原位替换；不存在则文件末尾追加。缺闭标记 fail-closed 中止（同 --inject-frameworks 教训）
ta_upsert_marker_block() {  # <dest> <tool> <skill_name> <body_file>
  local dest="$1" tool="$2" name="$3" body="$4"
  local open="<!-- >>> swarm-yuan:${tool}:${name} >>> （由 generate-skill.sh --render-tools 维护，勿手改） -->"
  local close="<!-- <<< swarm-yuan:${tool}:${name} <<< -->"
  local new merged
  new="$(mktemp "${TMPDIR:-/tmp}/rtblock.XXXXXX")"
  merged="$(mktemp "${TMPDIR:-/tmp}/rtmerge.XXXXXX")"
  { printf '%s\n' "$open"; cat "$body"; printf '%s\n' "$close"; } > "$new"
  if [[ -f "$dest" ]] && grep -qF "$open" "$dest"; then
    if ! grep -qF "$close" "$dest"; then
      echo "  ✗ $dest 含开标记但缺闭标记，中止（未改动）" >&2
      rm -f "$new" "$merged"
      return 1
    fi
    # awk 变量名避开内建函数（close 是 awk 内建，BSD awk 下作变量名直接语法错误）；
    # awk 失败必须中止且不覆盖 dest（先写 merged 临时文件，成功才进入幂等替换）
    if ! awk -v omark="$open" -v cmark="$close" -v blockfile="$new" '
      $0 == omark { while ((getline l < blockfile) > 0) print l; skip = 1; next }
      $0 == cmark { skip = 0; next }
      !skip { print }
    ' "$dest" > "$merged"; then
      echo "  ✗ 标记区块替换失败（awk 错误），中止（未改动 ${dest}）" >&2
      rm -f "$new" "$merged"
      return 1
    fi
  else
    if [[ -f "$dest" ]]; then cat "$dest" > "$merged"; else : > "$merged"; fi
    if [[ -s "$merged" ]]; then printf '\n' >> "$merged"; fi
    cat "$new" >> "$merged"
  fi
  rm -f "$new"
  ta_write_if_changed "$merged" "$dest" "${tool} $(basename "$dest")"
}

# ---- 规则正文（各工具共享；不含时间戳，保证重渲染字节一致）----
ta_build_body() {  # $1=skill_dir（绝对路径）→ stdout 规则正文（markdown）
  cat <<EOF
## ${TA_SKILL_NAME}（swarm-yuan 生成技能）

- 用途：${TA_SKILL_DESC}
- 技能本体：$1/SKILL.md（八节点工作流 + references/ 项目知识库）
- 质量门禁：bash "$1/scripts/precheck.sh" --all（门禁配置：$1/scripts/precheck.conf）
- 激活框架门禁：${TA_FRAMEWORKS:-未配置}
- 流程状态机：bash "$1/scripts/state-machine.sh" status

> 本规则由 swarm-yuan generate-skill.sh --render-tools 从 SKILL.md + precheck.conf 派生；改动请重跑渲染，勿手改。
EOF
}

# ---- 调度器：渲染全部（或指定）工具的原生规则文件 ----
ta_render_tools() {  # <skill_dir> [project_root] [tool]
  local skill_dir="$1" proj_arg="${2:-}" filter="${3:-}"
  [[ -d "${TA_DIR:-}" ]] || { echo "✗ TA_DIR 未设置或目录不存在: ${TA_DIR:-<空>}" >&2; return 1; }
  [[ -d "$skill_dir" ]] || { echo "✗ skill 目录不存在: $skill_dir" >&2; return 1; }
  [[ -f "$skill_dir/SKILL.md" ]] || { echo "✗ 未找到 SKILL.md: $skill_dir/SKILL.md" >&2; return 1; }
  # 绝对化 skill_dir（规则正文写绝对路径，保证稳定可点）
  local base; base="$(basename "$skill_dir")"
  skill_dir="$(cd "$(dirname "$skill_dir")" && pwd)/$base"
  # 推导目标根与级别：显式 project_root 优先；否则按 7 个已知工具 home 判 user/project
  local tool_home; tool_home="$(dirname "$(dirname "$skill_dir")")"
  local level proj
  if [[ -n "$proj_arg" ]]; then
    level="project"; proj="$proj_arg"
  elif ta_is_user_level "$tool_home"; then
    level="user"; proj="$HOME"
  else
    level="project"; proj="$(dirname "$tool_home")"
  fi
  TA_SKILL_NAME="$(ta_parse_skill_field "$skill_dir" name)"
  [[ -z "$TA_SKILL_NAME" ]] && TA_SKILL_NAME="$base"
  TA_SKILL_DESC="$(ta_parse_skill_field "$skill_dir" description)"
  [[ -z "$TA_SKILL_DESC" ]] && TA_SKILL_DESC="swarm-yuan 生成技能 ${TA_SKILL_NAME}（特征卡 + 门禁 + 状态机的项目研发范式）"
  TA_FRAMEWORKS="$(ta_active_frameworks "$skill_dir" | sed -e 's/ $//' -e 's/ /, /g')"
  TA_BODY="$(mktemp "${TMPDIR:-/tmp}/rtbody.XXXXXX")"
  ta_build_body "$skill_dir" > "$TA_BODY"
  echo "=== 渲染多平台原生规则: ${TA_SKILL_NAME}（${level} 级，目标根 ${proj}）==="
  local tools="cursor windsurf gemini codex opencode kimi claude"
  [[ -n "$filter" ]] && tools="$filter"
  local t rc=0
  for t in $tools; do
    if [[ ! -f "$TA_DIR/$t.sh" ]]; then
      echo "  ⚠ 适配器缺失: $TA_DIR/$t.sh（跳过 ${t}）"
      continue
    fi
    # shellcheck disable=SC1090
    . "$TA_DIR/$t.sh"
    if command -v "render_tool_$t" >/dev/null 2>&1; then
      if ! "render_tool_$t" "$skill_dir" "$proj" "$level"; then
        echo "  ⚠ $t 渲染失败（继续其余工具）"
        rc=1
      fi
    else
      echo "  ⚠ 适配器 $t 未定义 render_tool_${t}（跳过）"
    fi
  done
  rm -f "$TA_BODY"
  echo "=== 渲染完成 ==="
  return $rc
}

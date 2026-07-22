#!/usr/bin/env bash
# windsurf.sh — Windsurf 适配器：项目级 .windsurf/rules/<skill>.md；用户级全局 memories/global_rules.md
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 格式依据（访问 2026-07-20）：https://thepromptshelf.dev/blog/windsurf-vs-cursor-vs-agents-md-2026/
#   trigger 四值 always_on|model_decision|glob|manual；model_decision 凭 description 由模型决定加载，
#   与 Cursor 的 Agent Requested 对齐。2026-06 起新版偏好 .devin/rules/，.windsurf/rules/ 保留回退
#   （https://skillwright.app/blog/windsurf-rules-guide）；全局规则 6,000 字符硬上限。
render_tool_windsurf() {  # <skill_dir> <proj> <level>
  local proj="$2" level="$3"
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/rtwindsurf.XXXXXX")"
  {
    printf -- '---\n'
    printf 'trigger: model_decision\n'
    printf 'description: "%s"\n' "$(ta_yaml_dq "$TA_SKILL_DESC")"
    printf -- '---\n\n'
    cat "$TA_BODY"
  } > "$tmp"
  if [[ "$level" == "user" ]]; then
    # 用户级全局规则为单文件（6,000 字符硬上限，超限静默失效），标记区块幂等 upsert
    local dest="$HOME/.codeium/windsurf/memories/global_rules.md"
    if ta_upsert_marker_block "$dest" "windsurf" "$TA_SKILL_NAME" "$tmp"; then
      local size; size="$(wc -c < "$dest" | tr -d ' ')"
      if [[ "$size" -gt 6000 ]]; then
        echo "  ⚠ $dest 已 ${size} 字符，超 Windsurf 全局规则 6,000 字符上限，请精简"
      fi
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp"
    return 1
  fi
  ta_write_if_changed "$tmp" "$proj/.windsurf/rules/${TA_SKILL_NAME}.md" "Windsurf .windsurf/rules/${TA_SKILL_NAME}.md"
}

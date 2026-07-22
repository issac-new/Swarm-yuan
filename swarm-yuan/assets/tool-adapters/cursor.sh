#!/usr/bin/env bash
# cursor.sh — Cursor 适配器：<proj>/.cursor/rules/<skill>.mdc
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 格式依据（访问 2026-07-20）：https://qaskills.sh/blog/cursor-skill-md-frontmatter-schema-guide
#   frontmatter 三字段 description/globs/alwaysApply；description 有值 + globs 空 + alwaysApply:false
#   = Agent Requested（按描述相关性激活），与 skill 的语义触发一致。
#   user 级（proj=$HOME）即 ~/.cursor/rules/，Cursor 用户规则位，同样生效。
render_tool_cursor() {  # <skill_dir> <proj> <level>
  local dest="$2/.cursor/rules/${TA_SKILL_NAME}.mdc"
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/rtcursor.XXXXXX")"
  {
    printf -- '---\n'
    printf 'description: "%s"\n' "$(ta_yaml_dq "$TA_SKILL_DESC")"
    printf 'globs: ""\n'
    printf 'alwaysApply: false\n'
    printf -- '---\n\n'
    cat "$TA_BODY"
  } > "$tmp"
  ta_write_if_changed "$tmp" "$dest" "Cursor .cursor/rules/${TA_SKILL_NAME}.mdc"
}

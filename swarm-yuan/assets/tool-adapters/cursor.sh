#!/usr/bin/env bash
# cursor.sh — Cursor 适配器：<proj>/.cursor/rules/<skill>.mdc
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 格式依据（访问 2026-07-20）：https://qaskills.sh/blog/cursor-skill-md-frontmatter-schema-guide
#   frontmatter 三字段 description/globs/alwaysApply；description 有值 + globs 空 + alwaysApply:false
#   = Agent Requested（按描述相关性激活），与 skill 的语义触发一致。
#   user 级（proj=$HOME）即 ~/.cursor/rules/，Cursor 用户规则位，同样生效。
# hooks 格式依据（访问 2026-10-09）：https://cursor.com/docs/agent/hooks —— hooks.json 顶层
#   {"version": 1, "hooks": {...}}，事件条目扁平（command/matcher/type/timeout 于条目层——
#   与 Claude 嵌套形不同，勿混用）；阻断=exit 2（"Exit code 2 - Block the action"）。
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
  render_tool_cursor_hooks "$1" "$2"
}

# spec-first 写时拦截（L1）：合并进 <proj>/.cursor/hooks.json（用户级即 ~/.cursor/hooks.json）。
# 幂等合并保用户既有配置（ta_merge_json_hook）；preset 补 version:1（Cursor schema 必填）。
render_tool_cursor_hooks() {  # <skill_dir> <proj>
  local entry; entry="$(mktemp "${TMPDIR:-/tmp}/rtcurh.XXXXXX")"
  python3 - "$1" > "$entry" <<'PYEOF'
import json, sys
skill = sys.argv[1]
print(json.dumps({
    "command": "bash \"%s/scripts/spec-first-bridge.sh\" --host cursor" % skill,
    "matcher": "Shell|Write|Edit",
    "type": "command",
    "timeout": 5
}, ensure_ascii=False))
PYEOF
  ta_merge_json_hook "$2/.cursor/hooks.json" "hooks" "preToolUse" "$entry" "spec-first-bridge" '{"version": 1}'
  rm -f "$entry"
}

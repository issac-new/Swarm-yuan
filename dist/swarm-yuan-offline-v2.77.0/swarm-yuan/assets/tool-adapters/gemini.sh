#!/usr/bin/env bash
# gemini.sh — Gemini CLI 适配器：项目级 <proj>/GEMINI.md；用户级 ~/.gemini/GEMINI.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   GEMINI.md 为 Gemini CLI 原生项目上下文文件（ analogous to CLAUDE.md），纯 markdown 无 frontmatter。
# hooks 格式依据（访问 2026-10-09）：https://geminicli.com/docs/hooks/reference/ ——
#   settings.json 的 hooks 段，事件（BeforeTool）条目嵌套形 {"matcher","sequential","hooks":[{...}]}；
#   hook 元素 {"type":"command","command":...,"timeout":毫秒}；阻断=decision deny（reason 必填）
#   或 exit 2；matcher 为工具名正则。项目层 <proj>/.gemini/settings.json > 用户层 ~/.gemini/settings.json。
render_tool_gemini() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.gemini/GEMINI.md"; else dest="$2/GEMINI.md"; fi
  ta_upsert_marker_block "$dest" "gemini" "$TA_SKILL_NAME" "$TA_BODY"
  render_tool_gemini_hooks "$1" "$2"
}

# spec-first 写时拦截（L1）：合并进 settings.json hooks.BeforeTool（幂等保用户配置）。
render_tool_gemini_hooks() {  # <skill_dir> <proj>
  local entry; entry="$(mktemp "${TMPDIR:-/tmp}/rtgemh.XXXXXX")"
  python3 - "$1" > "$entry" <<'PYEOF'
import json, sys
skill = sys.argv[1]
print(json.dumps({
    "matcher": "write_file|replace|run_shell_command",
    "sequential": True,
    "hooks": [{"type": "command",
               "command": "bash \"%s/scripts/spec-first-bridge.sh\" --host gemini" % skill,
               "timeout": 30000}]
}, ensure_ascii=False))
PYEOF
  ta_merge_json_hook "$2/.gemini/settings.json" "hooks" "BeforeTool" "$entry" "spec-first-bridge"
  rm -f "$entry"
}

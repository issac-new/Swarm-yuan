#!/usr/bin/env bash
# gemini.sh — Gemini CLI 适配器：项目级 <proj>/GEMINI.md；用户级 ~/.gemini/GEMINI.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   GEMINI.md 为 Gemini CLI 原生项目上下文文件（ analogous to CLAUDE.md），纯 markdown 无 frontmatter。
render_tool_gemini() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.gemini/GEMINI.md"; else dest="$2/GEMINI.md"; fi
  ta_upsert_marker_block "$dest" "gemini" "$TA_SKILL_NAME" "$TA_BODY"
}

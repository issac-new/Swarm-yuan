#!/usr/bin/env bash
# codex.sh — Codex 适配器：项目级 <proj>/AGENTS.md；用户级 ~/.codex/AGENTS.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   AGENTS.md 是 Codex 原生标准（项目内 root→cwd 级联拼接），纯 markdown 无 frontmatter。
render_tool_codex() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.codex/AGENTS.md"; else dest="$2/AGENTS.md"; fi
  ta_upsert_marker_block "$dest" "codex" "$TA_SKILL_NAME" "$TA_BODY"
}

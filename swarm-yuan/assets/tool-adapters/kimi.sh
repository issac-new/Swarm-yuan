#!/usr/bin/env bash
# kimi.sh — Kimi 适配器：仅项目级 <proj>/AGENTS.md（标记区块包裹）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   Kimi 仅读项目树内 AGENTS.md / .kimi/AGENTS.md（root→cwd），无全局指令文件位，故 user 级跳过。
render_tool_kimi() {  # <skill_dir> <proj> <level>
  if [[ "$3" == "user" ]]; then
    echo "  · Kimi: 无全局指令文件（仅读项目 AGENTS.md / .kimi/AGENTS.md），用户级跳过"
    return 0
  fi
  ta_upsert_marker_block "$2/AGENTS.md" "kimi" "$TA_SKILL_NAME" "$TA_BODY"
}

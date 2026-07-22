#!/usr/bin/env bash
# opencode.sh — OpenCode 适配器：项目级 <proj>/AGENTS.md；用户级 ~/.config/opencode/AGENTS.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   OpenCode 主读 AGENTS.md（另有 opencode.json 的 instructions[] 可挂额外路径，本适配器不改动 json 配置）。
render_tool_opencode() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.config/opencode/AGENTS.md"; else dest="$2/AGENTS.md"; fi
  ta_upsert_marker_block "$dest" "opencode" "$TA_SKILL_NAME" "$TA_BODY"
}

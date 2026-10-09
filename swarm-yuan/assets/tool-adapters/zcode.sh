#!/usr/bin/env bash
# zcode.sh — ZCode 适配器：项目级 <proj>/AGENTS.md；用户级 ~/.zcode/AGENTS.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据：ZCode 以 AGENTS.md 为用户默认指令与项目指令载体（用户级 ~/.zcode/AGENTS.md、
# 项目级仓库根 AGENTS.md），纯 markdown 无 frontmatter——与 Codex 的 AGENTS.md 标准同形态。
render_tool_zcode() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.zcode/AGENTS.md"; else dest="$2/AGENTS.md"; fi
  ta_upsert_marker_block "$dest" "zcode" "$TA_SKILL_NAME" "$TA_BODY"
}

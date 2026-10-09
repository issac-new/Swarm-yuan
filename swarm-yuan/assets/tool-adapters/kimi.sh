#!/usr/bin/env bash
# kimi.sh — Kimi 适配器：项目级 <proj>/AGENTS.md（标记区块）+ kimi-code hooks（R103）
# TA_TIER=cli（目录复制 + --render-tools 规则派生 + hooks 整合）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   Kimi 仅读项目树内 AGENTS.md / .kimi/AGENTS.md（root→cwd），无全局指令文件位，故规则 user 级跳过。
# R103 产品更替（docs/research/R102-legacy-items.md §二）：旧 kimi-cli 已于 2026-09-23 归档，
#   接任 kimi-code（~/.kimi-code/，watch 列表载明加载 AGENTS.md 与 skills）有可阻断 PreToolUse。
#   hooks 格式依据（访问 2026-10-09）：https://moonshotai.github.io/kimi-code/en/configuration/config-files
#   ——hook 规则全部写在 ~/.kimi-code/config.toml 的 [[hooks]] 表数组（event/matcher/command/timeout），
#   阻断=exit 2（stderr 为原因，kimi-code hooks 页）。旧 ~/.kimi 路径保留为 legacy 回退。
render_tool_kimi() {  # <skill_dir> <proj> <level>
  if [[ "$3" == "user" ]]; then
    echo "  · Kimi: 无全局指令文件（仅读项目 AGENTS.md / .kimi/AGENTS.md），规则渲染跳过"
  else
    ta_upsert_marker_block "$2/AGENTS.md" "kimi" "$TA_SKILL_NAME" "$TA_BODY"
  fi
  render_tool_kimi_hooks "$1"
}

# spec-first 写时拦截（L1）：kimi-code 用户级 config.toml [[hooks]] 标记块（TOML 注释风格标记）。
render_tool_kimi_hooks() {  # <skill_dir>
  local cfg="$HOME/.kimi-code/config.toml"
  if [[ ! -d "$HOME/.kimi-code" ]]; then
    echo "  ⚠ Kimi hooks 未注册：~/.kimi-code 不存在（kimi-code 未安装/旧 kimi-cli 无 hook 机制）"
    return 0
  fi
  local body; body="$(mktemp "${TMPDIR:-/tmp}/rtkimh.XXXXXX")"
  cat > "$body" <<HJEOF
[[hooks]]
event = "PreToolUse"
matcher = "Write|Edit|Bash"
command = "bash \"$1/scripts/spec-first-bridge.sh\" --host kimi"
timeout = 5
HJEOF
  ta_upsert_marker_block "$cfg" "kimi" "$TA_SKILL_NAME" "$body" toml
  rm -f "$body"
}

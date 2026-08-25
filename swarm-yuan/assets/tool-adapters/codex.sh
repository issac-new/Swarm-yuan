#!/usr/bin/env bash
# codex.sh — Codex 适配器：项目级 <proj>/AGENTS.md；用户级 ~/.codex/AGENTS.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   AGENTS.md 是 Codex 原生标准（项目内 root→cwd 级联拼接），纯 markdown 无 frontmatter。
render_tool_codex() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.codex/AGENTS.md"; else dest="$2/AGENTS.md"; fi
  ta_upsert_marker_block "$dest" "codex" "$TA_SKILL_NAME" "$TA_BODY"
  [[ "$3" != "user" ]] && render_tool_codex_hooks "$2"
}

# R13 批次4（宿主下沉）：Codex v0.148 hooks 注册——生成目标技能的预检门禁接 Codex 官方强制点。
# PreToolUse Bash → fail-gate-hook（exit 2=deny，stderr 原因透传给模型）；PostToolUse → failure-detector。
# 配置位置：项目级 <proj>/.codex/hooks.json（hooks/src/engine/discovery.rs 的 config layer 探测点）。
# 铁律（audit-2026-08-25）：PreToolUse 命令禁止 `|| true` / `2>/dev/null`——|| true 把 exit 2 吞成 0、
# stderr 重定向丢弃透传原因，deny 协议将整体静默失效；PostToolUse 为 advisory 可 fail-open（|| true）但须保留 stderr。
render_tool_codex_hooks() {  # <proj>
  local hdir="$1/.codex" hfile="$1/.codex/hooks.json"
  mkdir -p "$hdir"
  if [[ ! -f "$hfile" ]]; then
    cat > "$hfile" <<'HJEOF'
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "command": "bash scripts/codex-gate-wrapper.sh", "timeout": 5}
    ],
    "PostToolUse": [
      {"matcher": "Bash", "command": "bash scripts/failure-detector.sh || true", "timeout": 5}
    ]
  }
}
HJEOF
  fi
}

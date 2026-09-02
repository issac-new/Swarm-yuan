#!/usr/bin/env bash
# codex.sh — Codex 适配器：项目级 <proj>/AGENTS.md；用户级 ~/.codex/AGENTS.md（标记区块包裹）
# TA_TIER=cli（目录复制 + --render-tools 规则派生）
# 依据（访问 2026-07-20）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
#   AGENTS.md 是 Codex 原生标准（项目内 root→cwd 级联拼接），纯 markdown 无 frontmatter。
render_tool_codex() {  # <skill_dir> <proj> <level>
  local dest
  if [[ "$3" == "user" ]]; then dest="$HOME/.codex/AGENTS.md"; else dest="$2/AGENTS.md"; fi
  ta_upsert_marker_block "$dest" "codex" "$TA_SKILL_NAME" "$TA_BODY"
  [[ "$3" != "user" ]] && render_tool_codex_hooks "$1" "$2"
}

# Codex v0.148 hooks 注册——生成目标技能的预检门禁接 Codex 官方强制点。
# PreToolUse Bash → fail-gate-hook（exit 2=deny，stderr 原因透传给模型）；PostToolUse → failure-detector。
# 配置位置：项目级 <proj>/.codex/hooks.json（hooks/src/engine/discovery.rs 的 config layer 探测点）。
# 铁律（audit-2026-08-25）：PreToolUse 命令禁止 `|| true` / `2>/dev/null`——|| true 把 exit 2 吞成 0、
# stderr 重定向丢弃透传原因，deny 协议将整体静默失效；PostToolUse 为 advisory 可 fail-open（|| true）但须保留 stderr。
# 回归发现#23（2026-08-27 R11 双宿主整合）：原扁平 {"matcher","command","timeout"} 不符 Codex 真实
# schema（config/src/hook_config.rs MatcherGroup）——matcher 组的执行体是 hooks 数组、元素为
# tag 判别 {"type":"command","command":...}。扁平 command 字段被 serde 静默丢弃、hooks 空数组
# → 注册了 matcher 却零 handler，Codex 门禁 hook 完全惰性。改为嵌套 schema（对 research/codex
# 源码逐字段核验：matcher/hooks[].type=command/command/timeout）。
# 回归发现#24（同轮）：命令原用相对路径 scripts/...，但 wrapper 部署在 skill 目录、项目根无
# scripts/——注册未部署，运行必 No such file。改绝对路径（与 AGENTS.md 体内 bash "<skill>/...
# 绝对引用同款）；另：旧版扁平 hooks.json 已存在时升级重写（检测缺 "type": "command" 即旧形态）。
render_tool_codex_hooks() {  # <skill_dir> <proj>
  local skill_dir="$1" hdir="$2/.codex" hfile="$2/.codex/hooks.json"
  mkdir -p "$hdir"
  local _rewrite=1
  if [[ -f "$hfile" ]] && grep -q '"type": *"command"' "$hfile" 2>/dev/null; then
    _rewrite=0  # 已是嵌套 schema，幂等跳过
  fi
  if [[ "$_rewrite" -eq 1 ]]; then
    cat > "$hfile" <<HJEOF
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${skill_dir}/scripts/codex-gate-wrapper.sh", "timeout": 5}]}
    ],
    "PostToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${skill_dir}/scripts/failure-detector.sh || true", "timeout": 5}]}
    ]
  }
}
HJEOF
  fi
}

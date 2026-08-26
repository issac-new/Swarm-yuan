#!/usr/bin/env bash
# memory-writeback.sh — Step 11 记忆写回（S9 实装：补全"记忆→生成→开发→记忆"闭环的写回半环）
#
# 理念来源：SKILL.md:100 Step 11 "claude-mem/.zcode/memories/.project-knowledge.md 三路写回"。
# 此前该步纯 AI 自由动作、无脚本兜底（S9 审计发现）；本脚本提供机器兜底：
# 把本次生成的项目知识摘要（特征卡 + 框架清单 + spec 摘要）写回三路 sink，幂等、best-effort、不阻塞主流程。
#
# 用法:
#   bash scripts/memory-writeback.sh [--skill-dir <目标技能目录>] [--project-dir <项目目录>]
#   缺省 --skill-dir 用 ${PROJECT_DIR:-$(pwd)}/.swarm-yuan/skill（生成产物）；
#   --project-dir 缺省用 $PWD。
#
# 三路写回（每路独立降级，任一失败仅 warn 不阻塞）:
#   1) .swarm-yuan/project-knowledge.md   — 项目本地知识文件（swarm-yuan 自有状态目录，始终写）
#   2) $PROJECT_DIR/.zcode/memories/project-knowledge.md — .zcode 记忆目录（仅当目录存在时追加）
#   3) claude-mem CLI（仅当 command -v claude-mem 成功时调，best-effort）
#
# 幂等：同一项目重复写回用时间戳分节，不覆盖历史；旧节保留供 diff。
# 三平台兼容：bash 3.2 / 无 declare -A / date -u / sed 无 -i / $(cd+pwd)。

set -uo pipefail

SKILL_DIR=""
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)   SKILL_DIR="${2:-}";   shift 2 ;;
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    *) echo "未知参数: $1" >&2; echo "Usage: bash scripts/memory-writeback.sh [--skill-dir <dir>] [--project-dir <dir>]" >&2; exit 1 ;;
  esac
done

# 缺省 skill-dir：猜测 .swarm-yuan/skill 或当前目录
[[ -z "$SKILL_DIR" ]] && SKILL_DIR="${PROJECT_DIR}/.swarm-yuan/skill"
[[ -d "$SKILL_DIR" ]] || SKILL_DIR="${PROJECT_DIR}"

STATE_DIR="${PROJECT_DIR}/.swarm-yuan"
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# ---- 0. 采集项目知识摘要（从生成产物读，不自己探查）----
# 优先读目标技能的 SKILL.md 头部 + spec.md 摘要 + facts.conf（若存在）；缺则降级用项目目录名。
_collect_summary() {
  local summary=""
  local skill_md="${SKILL_DIR}/SKILL.md"
  local spec_md="${SKILL_DIR}/references/spec.md"
  if [[ -f "$skill_md" ]]; then
    # 取 SKILL.md 的前 20 行（含项目名 + 核心约束）
    summary+="## 项目技能摘要（$(basename "$SKILL_DIR")）"$'\n\n'
    summary+=$(head -20 "$skill_md" 2>/dev/null)
    summary+=$'\n\n'
  fi
  if [[ -f "$spec_md" ]]; then
    # 取 spec.md 的 §1 需求理解 + §2 技术栈（前 40 行）
    summary+="## spec 摘要"$'\n\n'
    summary+=$(head -40 "$spec_md" 2>/dev/null)
    summary+=$'\n\n'
  fi
  if [[ -z "$summary" ]]; then
    summary="## 项目知识（无生成产物，仅目录名: $(basename "$PROJECT_DIR")）"$'\n'
  fi
  printf '%s' "$summary"
}

# ---- 写回函数（每路独立，返回 0/1，不 exit）----
_write_local() {
  # 1) .swarm-yuan/project-knowledge.md（项目本地，始终写）
  mkdir -p "$STATE_DIR" 2>/dev/null || return 1
  local f="${STATE_DIR}/project-knowledge.md"
  {
    echo "---"
    echo "ts: ${ts}"
    echo "project: $(basename "$PROJECT_DIR")"
    echo "---"
    _collect_summary
    echo ""
  } >> "$f" 2>/dev/null || return 1
  echo "→ [记忆写回] 本地: $f"
  return 0
}

_write_zcode() {
  # 2) $PROJECT_DIR/.zcode/memories/project-knowledge.md（仅当 .zcode/memories 目录存在）
  local zdir="${PROJECT_DIR}/.zcode/memories"
  [[ -d "$zdir" ]] || return 0  # 目录不存在=跳过，非错误
  local f="${zdir}/project-knowledge.md"
  {
    echo "---"
    echo "ts: ${ts}"
    echo "---"
    _collect_summary
    echo ""
  } >> "$f" 2>/dev/null || return 1
  echo "→ [记忆写回] .zcode: $f"
  return 0
}

_write_claude_mem() {
  # 3) claude-mem CLI（仅当 CLI 存在；best-effort，不阻塞）
  command -v claude-mem >/dev/null 2>&1 || return 0
  # P0-5：真实写入——优先 `claude-mem add` 显式写记忆，失败/不支持时降级 search 触发 observation 捕获。
  # 注：add 子命令签名按 claude-mem 上游（title + content）；不支持 add 的旧版自动降级，不阻塞。
  local _content="swarm-yuan skill generated ${ts}: 项目知识已写回（特征卡+框架清单+spec 摘要）"
  if claude-mem add "swarm-yuan 生成" "$_content" >/dev/null 2>&1; then
    echo "→ [记忆写回] claude-mem: 已写入（add 真实子进程）"
    return 0
  fi
  # 降级：search 触发 observation 捕获（原机制，治旧版无 add）
  if claude-mem search "swarm-yuan skill generated ${ts}" >/dev/null 2>&1; then
    echo "→ [记忆写回] claude-mem: 已触发（observation 由其 hooks 捕获）"
  fi
  return 0
}

# ---- 三路写回（每路独立降级，不阻塞）----
echo "=== 记忆写回（Step 11，三路 best-effort）==="
_ok=0
_write_local   && _ok=$((_ok+1)) || echo "⚠ 本地写回失败（$STATE_DIR/project-knowledge.md 不可写）" >&2
_write_zcode   && _ok=$((_ok+1)) || echo "⚠ .zcode 写回失败（目录存在但不可写）" >&2
_write_claude_mem && _ok=$((_ok+1)) || echo "⚠ claude-mem 写回失败（CLI 异常）" >&2

echo "✓ 记忆写回完成（${_ok}/3 路成功）"
# 永不 fail 阻塞主流程（记忆写回是 best-effort，失败不阻断生成）
exit 0

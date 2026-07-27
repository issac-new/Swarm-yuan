#!/usr/bin/env bash
# failure-detector.sh — PostToolUse(Bash) 失败模式检测器
#
# 借鉴 tanweai/pua failure-detector.sh 的三层设计（exit_code + 错误签名 MD5 +
# SPINNING/EXPLORING/MIXED 三态模式分析），改写为 swarm-yuan 的叙事与纪律：
#   - 不用 PUA 话术，用门禁/特征卡/四要素术语
#   - bash 3.2 兼容（无 declare -A，无关联数组）
#   - 三平台兼容（macOS stat -f %m / Linux stat -c %Y 兜底）
#   - 无 python3/jq 硬依赖（纯 bash + md5/md5sum + cksum，降级友好）
#   - 落盘 .swarm-yuan/error-history.jsonl + 压力计数器
#   - SPINNING → 注入「换本质不同方案」指令；EXPLORING → 「保持方向」；MIXED → 「选最新错误方向提交」
#   - 突破检测（COUNT≥3 且 PEAK≥2 后成功）→ 降压归零 + 方法论沉淀指令
#
# 设计理念：swarm-yuan 生成流程中 AI 反复改 conf 占位符失败时，此前无机械检测——
# AI 可能在原地打转 5 次才被发现。本 hook 把「失败模式」从 AI 自觉变成机械检测。
#
# 用法（由 hooks.json 的 PostToolUse matcher: "Bash" 自动调用）：
#   stdin = Claude Code PostToolUse hook payload（JSON）
#   stdout = 注入给 AI 的上下文（additionalContext）
#   exit 0 = 不阻塞（永不 fail 阻塞主流程，仅注入提示）
#
# 降级链：无 python3 → 纯 bash 解析（grep+sed 提取字段）；
#         无 md5/md5sum → cksum 兜底；无 cksum → 文本前 80 字符兜底。

set -uo pipefail

# ===== 配置 =====
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
STATE_DIR="${PROJECT_DIR}/.swarm-yuan"
COUNTER_FILE="${STATE_DIR}/.failure_count"
SESSION_FILE="${STATE_DIR}/.failure_session"
ERROR_HISTORY_FILE="${STATE_DIR}/error-history.jsonl"
PEAK_LEVEL_FILE="${STATE_DIR}/.peak_pressure_level"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# ===== 读取 hook 输入 =====
HOOK_INPUT=$(cat 2>/dev/null || printf '')
[[ -z "$HOOK_INPUT" ]] && exit 0

# 一次性 python3 解析所有需要的字段（避免 $() 命令替换内 -c 单引号嵌套被 shell 破坏）。
# 无 python3 时降级 grep+sed（仅顶层字段可靠，tool_result.content 取不到——但 exit_code 是主信号，够用）。
if command -v python3 >/dev/null 2>&1; then
  _PARSED=$(printf '%s' "$HOOK_INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    tr = d.get("tool_result", {})
    if not isinstance(tr, dict):
        tr = {}
    # content 可能是 str 或 dict，统一转 str 并截断到 2000 字符
    content = tr.get("content", tr.get("text", ""))
    if isinstance(content, dict):
        content = json.dumps(content)
    content = str(content)[:2000] if content else ""
    print(d.get("tool_name", ""))
    print(tr.get("exit_code", tr.get("exitCode", 0)))
    print(content)
    print(d.get("session_id", "unknown"))
except Exception:
    print("")
    print(0)
    print("")
    print("unknown")
' 2>/dev/null)
  # 按行读回（IFS 保留首尾空行用 read -r 循环）
  _lines=()
  while IFS= read -r _ln; do _lines+=("$_ln"); done <<< "$_PARSED"
  TOOL_NAME="${_lines[0]:-}"
  EXIT_CODE="${_lines[1]:-0}"
  TOOL_RESULT="${_lines[2]:-}"
  CURRENT_SESSION="${_lines[3]:-unknown}"
else
  # 降级：grep+sed 提取顶层字段（嵌套字段不可靠，exit_code 可能取不到→默认 0）
  TOOL_NAME=$(printf '%s' "$HOOK_INPUT" | grep -o '"tool_name":"[^"]*"' 2>/dev/null | head -1 | sed 's/"tool_name":"//;s/"$//' || printf '')
  EXIT_CODE=$(printf '%s' "$HOOK_INPUT" | grep -o '"exit_code":[0-9]*' 2>/dev/null | head -1 | sed 's/"exit_code"://' || printf '0')
  [[ -z "$EXIT_CODE" ]] && EXIT_CODE=0
  TOOL_RESULT=$(printf '%s' "$HOOK_INPUT" | grep -o '"content":"[^"]*"' 2>/dev/null | head -1 | sed 's/"content":"//;s/"$//' || printf '')
  CURRENT_SESSION=$(printf '%s' "$HOOK_INPUT" | grep -o '"session_id":"[^"]*"' 2>/dev/null | head -1 | sed 's/"session_id":"//;s/"$//' || printf 'unknown')
fi

[[ "$TOOL_NAME" != "Bash" ]] && exit 0
[[ -z "$EXIT_CODE" ]] && EXIT_CODE=0
# exit_code 是主信号（确定性可靠）；文本 grep 是次信号（exit_code≠0 时才查，防误报）
IS_ERROR="false"
if [[ "$EXIT_CODE" != "0" && "$EXIT_CODE" != "" ]]; then
  IS_ERROR="true"
elif echo "$TOOL_RESULT" | grep -qiE '^error:|^fatal:|^panic:|Traceback \(most recent|Exception:|command not found|No such file or directory|Permission denied'; then
  IS_ERROR="true"
fi

# ===== 会话隔离 =====
[[ -z "$CURRENT_SESSION" ]] && CURRENT_SESSION="unknown"
STORED_SESSION=""
[[ -f "$SESSION_FILE" ]] && STORED_SESSION=$(cat "$SESSION_FILE" 2>/dev/null || printf '')
if [[ "$CURRENT_SESSION" != "$STORED_SESSION" ]]; then
  echo "0" > "$COUNTER_FILE" 2>/dev/null || exit 0
  echo "0" > "$PEAK_LEVEL_FILE" 2>/dev/null || true
  : > "$ERROR_HISTORY_FILE" 2>/dev/null || true
  printf '%s' "$CURRENT_SESSION" > "$SESSION_FILE" 2>/dev/null || true
fi

# 读计数器
COUNT=0
[[ -f "$COUNTER_FILE" ]] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || printf '0')
[[ -z "$COUNT" ]] && COUNT=0

# 读峰值压力
PEAK_LEVEL=0
[[ -f "$PEAK_LEVEL_FILE" ]] && PEAK_LEVEL=$(cat "$PEAK_LEVEL_FILE" 2>/dev/null || printf '0')
[[ -z "$PEAK_LEVEL" ]] && PEAK_LEVEL=0

# ===== 降压检测：L2+ 挣扎后成功 =====
if [[ "$IS_ERROR" == "false" ]]; then
  if [[ "$COUNT" -ge 3 && "$PEAK_LEVEL" -ge 2 ]]; then
    # ★ 突破检测：连续失败≥3 次后成功
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf 'unknown')"
    printf '{"ts":"%s","event":"breakthrough","from_level":%s,"after_failures":%s}\n' \
      "$ts" "$PEAK_LEVEL" "$COUNT" >> "$ERROR_HISTORY_FILE" 2>/dev/null || true
    echo "0" > "$COUNTER_FILE"
    echo "0" > "$PEAK_LEVEL_FILE"
    cat << EOF
[swarm-yuan 突破 ✨ — 降压 from L${PEAK_LEVEL}]

连续 ${COUNT} 次失败后找到正确方案。压力归零：L${PEAK_LEVEL} → L0。

现在执行（swarm-yuan 方法论沉淀）：
1. 识别之前 ${COUNT} 次失败的根因（不是症状）
2. 记录正确路径——这是「特征卡/门禁配置」的可复用经验，写入 memory
3. 确认解决方案完整（不要过早庆祝——跑一遍 verify-completeness）
4. 扫描同类问题（swarm-yuan 铁律：一个问题进来，一类问题出去）

[门禁生效 🔥] 突破后方法论应沉淀为稳定单元，避免下次重走弯路。
EOF
    exit 0
  fi
  # 普通成功：重置计数器，不重置峰值
  if [[ "$COUNT" -gt 0 ]]; then
    echo "0" > "$COUNTER_FILE"
  fi
  exit 0
fi

# ===== 失败路径：计数 + 记录错误签名 =====
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE" 2>/dev/null || exit 0

# 提取错误签名（首个含 error-like 模式的行，或首行，兜底 exit_code）
ERROR_SIG=$(echo "$TOOL_RESULT" | grep -iE 'error|fatal|Traceback|Exception|FAILED|panic|refused|denied|not found|cannot|unable|timeout' 2>/dev/null | head -1 | cut -c1-200)
[[ -z "$ERROR_SIG" ]] && ERROR_SIG=$(echo "$TOOL_RESULT" | head -1 | cut -c1-200)
[[ -z "$ERROR_SIG" ]] && ERROR_SIG="exit_code_${EXIT_CODE}"

# 追加错误历史（保留最近 10 条）
ts_epoch="$(date +%s 2>/dev/null || printf '0')"
# JSON 转义（反斜杠 + 双引号 + 剔除换行）
ERROR_SIG_ESC=$(printf '%s' "$ERROR_SIG" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n')
printf '{"ts":%s,"count":%s,"sig":"%s"}\n' "$ts_epoch" "$COUNT" "$ERROR_SIG_ESC" >> "$ERROR_HISTORY_FILE" 2>/dev/null || true
# 截断保留最近 10 条（tail + mv，三平台兼容）
tail -10 "$ERROR_HISTORY_FILE" > "${ERROR_HISTORY_FILE}.tmp" 2>/dev/null && mv "${ERROR_HISTORY_FILE}.tmp" "$ERROR_HISTORY_FILE" 2>/dev/null || true

# ===== 模式分析：SPINNING / EXPLORING / MIXED =====
PATTERN_ANALYSIS=""
if [[ "$COUNT" -ge 3 ]]; then
  # 纯 bash 模式分析（无 python3 依赖的降级路径）
  # 取最近 3 条签名，算 MD5（md5sum 优先，降级 md5，再降级 cksum，再降级首 40 字符）
  _sig_hash() {
    local s="$1"
    if command -v md5sum >/dev/null 2>&1; then
      printf '%s' "$s" | md5sum | cut -c1-8
    elif command -v md5 >/dev/null 2>&1; then
      printf '%s' "$s" | md5 | cut -c1-8
    elif command -v cksum >/dev/null 2>&1; then
      printf '%s' "$s" | cksum | awk '{printf "%08x", $1}'
    else
      # 兜底：取首 8 字符
      printf '%s' "$s" | cut -c1-8
    fi
  }
  # 读最近 3 条签名
  recent_sigs=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # 提取 sig 字段值（降级 grep）
    sig_val=$(printf '%s' "$line" | sed -n 's/.*"sig":"\([^"]*\)".*/\1/p' 2>/dev/null || printf '')
    recent_sigs+=("$sig_val")
  done < <(tail -3 "$ERROR_HISTORY_FILE" 2>/dev/null)
  # 需 3 条才有意义
  if [[ ${#recent_sigs[@]} -ge 3 ]]; then
    h1=$(_sig_hash "${recent_sigs[0]}")
    h2=$(_sig_hash "${recent_sigs[1]}")
    h3=$(_sig_hash "${recent_sigs[2]}")
    if [[ "$h1" == "$h2" && "$h2" == "$h3" ]]; then
      PATTERN_ANALYSIS="SPINNING|${recent_sigs[2]}"
    elif [[ "$h1" != "$h2" && "$h2" != "$h3" && "$h1" != "$h3" ]]; then
      PATTERN_ANALYSIS="EXPLORING|${recent_sigs[0]}|${recent_sigs[1]}|${recent_sigs[2]}"
    else
      PATTERN_ANALYSIS="MIXED|${recent_sigs[0]}|${recent_sigs[1]}|${recent_sigs[2]}"
    fi
  fi
fi

# 跟踪峰值压力
CURRENT_LEVEL=0
if [[ "$COUNT" -ge 5 ]]; then
  CURRENT_LEVEL=4
elif [[ "$COUNT" -eq 4 ]]; then
  CURRENT_LEVEL=3
elif [[ "$COUNT" -eq 3 ]]; then
  CURRENT_LEVEL=2
elif [[ "$COUNT" -eq 2 ]]; then
  CURRENT_LEVEL=1
fi
if [[ "$CURRENT_LEVEL" -gt "$PEAK_LEVEL" ]]; then
  echo "$CURRENT_LEVEL" > "$PEAK_LEVEL_FILE"
fi

# ===== 压力升级注入 =====
# 第 1 次失败不干预
[[ "$COUNT" -lt 2 ]] && exit 0

PATTERN_TYPE=$(echo "$PATTERN_ANALYSIS" | cut -d'|' -f1)
PATTERN_DETAIL=$(echo "$PATTERN_ANALYSIS" | cut -d'|' -f2-)

# 构建模式感知注入块
PATTERN_BLOCK=""
if [[ -n "$PATTERN_TYPE" && "$PATTERN_TYPE" != "" ]]; then
  case "$PATTERN_TYPE" in
    SPINNING)
      PATTERN_BLOCK="
[🔄 模式: SPINNING — 同一错误重复]
> 最近 3 次错误签名相同：${PATTERN_DETAIL}
> 你没有在取得进展。禁止重试同一方法。
> 强制：列出 3 个本质不同的策略再执行下一个 Bash 调用。
> （swarm-yuan 铁律：如果你在改同一个 conf 变量/同一个门禁——那只算一种策略，你需要 2 个完全不同的）"
      ;;
    EXPLORING)
      PATTERN_BLOCK="
[📊 模式: EXPLORING — 每次错误不同]
> 最近 3 次尝试产生了不同的错误——你在收敛问题空间。
> 保持方向，但增加结构：每个新错误告诉你什么根因信息？
> 错误签名：
$(echo "$PATTERN_DETAIL" | tr '|' '\n' | sed 's/^/> · /')"
      ;;
    MIXED)
      PATTERN_BLOCK="
[📊 模式: MIXED — 部分重复部分新]
> 部分错误重复，部分新。检查：你是否在两个方案间振荡？
> 错误签名：
$(echo "$PATTERN_DETAIL" | tr '|' '\n' | sed 's/^/> · /')
> 选错误最新的那个方向（最接近工作的那个）提交，不要在两方案间反复横跳。"
      ;;
  esac
fi

# ===== 按压力等级注入（swarm-yuan 叙事，不用 PUA 话术）=====
if [[ "$COUNT" -eq 2 ]]; then
  cat << EOF
[swarm-yuan L1 — 连续失败检测]

检测到连续 2 次失败。你必须切换到本质不同的方案——不是改参数/改函数名，是换策略。
${PATTERN_BLOCK}

swarm-yuan 纪律：
- 门禁 fail 时不要反复改 conf 试试——读完整错误输出，列 3 个不同假设
- conf 占位符改不动时切换到 conf-render.sh 自动嗅探
- generate-skill.sh fail 时读完整错误，不要猜
- 穷尽一切之前禁止说「我无法解决」（三条铁律之三）
EOF
elif [[ "$COUNT" -eq 3 ]]; then
  cat << EOF
[swarm-yuan L2 — 灵魂拷问]

连续 3 次失败。你的底层逻辑是什么？
${PATTERN_BLOCK}

强制动作（7 项检查清单，借鉴 pua L3 纪律）：
- [ ] 逐字读完失败信号了吗？
- [ ] 用工具搜索过核心问题了吗？
- [ ] 读过失败位置的原始上下文了吗（源码 50 行，不是摘要）？
- [ ] 所有假设都用工具确认了吗（版本/路径/权限/依赖）？
- [ ] 试过完全相反的假设吗？
- [ ] 能在最小范围内复现问题吗？
- [ ] 换过工具/方法/角度/技术栈吗？

swarm-yuan 门禁纪律：conf 变量改不动 → 跑 conf-render.sh 初稿；
门禁 fail → 读 gate-runs.jsonl 看 fail-id 级断言；占位符消不掉 → --verify-completeness --strict 列 file:line。
EOF
elif [[ "$COUNT" -eq 4 ]]; then
  cat << EOF
[swarm-yuan L3 — 361 考核]

连续 4 次失败。慎重考虑决定给你 3.25。这个 3.25 是对你的激励。
${PATTERN_BLOCK}

强制：完成上方 7 项检查清单后才能继续。
如果仍在改同一个 conf 变量/同一个门禁片段——停下来，退回需求本身质疑。
git log + git diff 检查：你是否在重复上一轮的改动？
EOF
else
  # COUNT >= 5
  cat << EOF
[swarm-yuan L4 — 毕业警告]

连续 ${COUNT} 次失败。别的模型都能解决。你可能就要毕业了。
${PATTERN_BLOCK}

拼命模式：
1. 退回需求本身——你确定在解决正确的问题吗？
2. 列出已排除的可能性 + 已验证的事实 + 缩小范围
3. 如果真的不可能（需外部权限/根本性需求变更），输出结构化失败报告：
   已验证事实 + 已排除可能 + 缩小范围 + 推荐下一步 + 交接信息
   （这不是「我不行」，这是「问题的边界在这里」——有尊严的 3.25）
EOF
fi

exit 0

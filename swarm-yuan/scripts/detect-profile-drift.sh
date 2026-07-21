#!/usr/bin/env bash
# detect-profile-drift.sh — 运行时探测 profile 漂移（WP-P6）
#
# 作用：重跑 auto_detect_profile 逻辑对比当前 SKILL.md frontmatter 的 profile 字段，
# 漂移则输出建议（只升不降，质量优先偏置）。
#
# 偏置规则（决策 18/22）：
#   - 合规信号新增（docs/README 出现等保/密评/个保法/金融/医疗关键词）→ 强制提示升 compliance
#   - 规模信号升档（文件数从 <80 涨到 ≥80）→ 提示升 standard
#   - 规模信号降档（文件数从 ≥80 降到 <80）→ 不提示降 lite（只升不降）
#   - 探测失败/边界不确定 → 不提示（保守不误报）
#
# 用法：
#   bash detect-profile-drift.sh <skill_dir>
#   退出码：0=无漂移或仅 warn（不阻塞）；1=参数错误
#
# 触发点：precheck.sh --all/--all-full 启动时（轻量调用，stderr 输出，不阻塞主流程）
#         self-check.sh check_profile_drift 子检查

set -uo pipefail

SKILL_DIR="${1:?Usage: detect-profile-drift.sh <skill_dir>}"
[[ -d "$SKILL_DIR" ]] || { echo "✗ skill_dir 不存在: $SKILL_DIR" >&2; exit 1; }

SKILL_MD="$SKILL_DIR/SKILL.md"
[[ -f "$SKILL_MD" ]] || { echo "ℹ 无 SKILL.md，跳过 profile 漂移检测" >&2; exit 0; }

# 读取当前 profile（frontmatter `profile:` 字段）
CURRENT_PROFILE=$(grep -E "^profile:" "$SKILL_MD" 2>/dev/null | head -1 | sed -E "s/^profile:[[:space:]]*//;s/[[:space:]]*$//")
[[ -z "$CURRENT_PROFILE" ]] && CURRENT_PROFILE="standard"  # 缺省视为 standard

# profile 档序（rank：lite=1 < standard=2 < compliance=3；auto 视为 standard 对比基准）
_profile_rank() { case "$1" in lite) echo 1;; compliance) echo 3;; *) echo 2;; esac; }

# 重跑 auto_detect_profile 逻辑（从 generate-skill.sh 移植）
# 需要项目目录——从 SKILL_DIR 推导：skill 通常在 <project>/.claude/skills/<name>/
PROJECT_DIR=$(cd "$SKILL_DIR/../../.." 2>/dev/null && pwd)
[[ -d "$PROJECT_DIR" ]] || { echo "ℹ 无法推导项目根目录，跳过 profile 漂移检测" >&2; exit 0; }

# 合规信号（最强，命中即 compliance）
COMPLIANCE_KW="等保|密评|GB/T[[:space:]]*39786|GB/T[[:space:]]*22239|个人信息保护|个保法|金融行业|医疗行业"
sig=$(grep -rliE "$COMPLIANCE_KW" "$PROJECT_DIR/docs" "$PROJECT_DIR"/README* 2>/dev/null | head -1 || true)
if [[ -n "$sig" ]]; then
  DETECTED_PROFILE="compliance"
  DRIFT_REASON="命中合规信号（${sig#"$PROJECT_DIR"/}）"
else
  # 规模信号：文件数（head 截断加速，≥80 即 standard；统计失败按 standard——升档偏置）
  n=$(find "$PROJECT_DIR" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \
      2>/dev/null | head -81 | wc -l | tr -d ' ')
  n="${n:-81}"
  [[ "$n" =~ ^[0-9]+$ ]] || n=81
  if [[ "$n" -lt 80 ]]; then
    DETECTED_PROFILE="lite"
    DRIFT_REASON="规模信号：文件数 ${n}（<80 → lite）"
  else
    DETECTED_PROFILE="standard"
    DRIFT_REASON="规模信号：文件数 ${n}（≥80 → standard）"
  fi
fi

# 漂移判定（只升不降）
_current_rank=$(_profile_rank "$CURRENT_PROFILE")
_detected_rank=$(_profile_rank "$DETECTED_PROFILE")

if [[ "$DETECTED_PROFILE" == "$CURRENT_PROFILE" ]]; then
  exit 0  # 无漂移
fi

if [[ $_detected_rank -gt $_current_rank ]]; then
  # 升档漂移：提示
  echo "⚠ profile 漂移：当前 ${CURRENT_PROFILE} → 探测 ${DETECTED_PROFILE}（${DRIFT_REASON}）" >&2
  echo "  建议升级：bash generate-skill.sh --upgrade --profile ${DETECTED_PROFILE} <name> <project>" >&2
  echo "  （质量优先偏置：只升不降；探测为降档时不提示）" >&2
  exit 0  # warn 不阻塞
fi

# 降档不提示（只升不降），静默退出
exit 0

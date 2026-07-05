#!/usr/bin/env bash
# generate-skill.sh — swarm-yuan 目标技能脚手架生成器 / 升级器
# 用法:
#   bash generate-skill.sh <skill-name> <project-dir> [target-dir]       # 创建新技能骨架
#   bash generate-skill.sh --upgrade <skill-name> <project-dir> [target-dir]  # 升级已存在技能
# 作用:
#   创建模式: 自动检测运行环境，在对应 skill 默认目录下创建六段式骨架
#   升级模式: 用 swarm-yuan 最新模板覆盖通用文件，保留项目特定文件

set -euo pipefail

# ---- 检测运行环境 ----
detect_skill_dir() {
  local project="$1"
  if [[ -d "$project/.claude/skills" ]]; then echo "$project/.claude/skills"; return; fi
  if [[ -d "$HOME/.claude/skills" ]]; then echo "$HOME/.claude/skills"; return; fi
  if [[ -d "$HOME/.codex/skills" ]]; then echo "$HOME/.codex/skills"; return; fi
  if [[ -d "$HOME/.cursor/skills" ]]; then echo "$HOME/.cursor/skills"; return; fi
  if [[ -d "$HOME/.codeium/windsurf/skills" ]]; then echo "$HOME/.codeium/windsurf/skills"; return; fi
  if [[ -d "$HOME/.config/opencode/skills" ]]; then echo "$HOME/.config/opencode/skills"; return; fi
  if [[ -d "$HOME/.gemini/skills" ]]; then echo "$HOME/.gemini/skills"; return; fi
  if [[ -d "$HOME/.kimi/skills" ]]; then echo "$HOME/.kimi/skills"; return; fi
  echo "$project/.claude/skills"
}

detect_runtime_name() {
  local project="$1"
  if [[ -d "$project/.claude/skills" || -d "$HOME/.claude/skills" ]]; then echo "Claude Code"
  elif [[ -d "$HOME/.codex/skills" ]]; then echo "Codex"
  elif [[ -d "$HOME/.cursor/skills" ]]; then echo "Cursor"
  elif [[ -d "$HOME/.codeium/windsurf/skills" ]]; then echo "Windsurf"
  elif [[ -d "$HOME/.config/opencode/skills" ]]; then echo "OpenCode"
  elif [[ -d "$HOME/.gemini/skills" ]]; then echo "Gemini CLI"
  elif [[ -d "$HOME/.kimi/skills" ]]; then echo "Kimi"
  else echo "通用"
  fi
}

# ---- 解析模式 ----
MODE="create"
if [[ "${1:-}" == "--upgrade" ]]; then MODE="upgrade"; shift; fi

SKILL_NAME="${1:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
if [[ -z "${3:-}" ]]; then
  TARGET_DIR=$(detect_skill_dir "$PROJECT_DIR")
  RUNTIME_NAME=$(detect_runtime_name "$PROJECT_DIR")
  echo "检测到运行环境: ${RUNTIME_NAME}"
  echo "目标 skill 目录: ${TARGET_DIR}"
else
  TARGET_DIR="$3"
fi

[[ ! -d "$PROJECT_DIR" ]] && { echo "ERROR: 项目目录不存在: $PROJECT_DIR"; exit 1; }
mkdir -p "$TARGET_DIR"

SKILL_DIR="$TARGET_DIR/$SKILL_NAME"
ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets"
SRC_REF="$(cd "$(dirname "$0")/.." && pwd)/references"
SRC_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
SWARM_YUAN_STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"

copy_universal_templates() {
  local dir="$1"
  cp "$ASSETS_DIR/spec-template.md" "$dir/assets/spec-template.md"
  cp "$ASSETS_DIR/plan-template.md" "$dir/assets/plan-template.md"
  cp "$ASSETS_DIR/branch-setup.sh" "$dir/assets/branch-setup.sh"
  cp "$ASSETS_DIR/env-setup.sh" "$dir/assets/env-setup.sh"
  cp "$ASSETS_DIR/data-sample-template.md" "$dir/assets/data-sample-template.md"
  cp "$ASSETS_DIR/state-machine.sh" "$dir/assets/state-machine.sh"
  chmod +x "$dir/assets/branch-setup.sh" "$dir/assets/env-setup.sh" "$dir/assets/state-machine.sh"
  cp "$ASSETS_DIR/precheck.sh" "$dir/scripts/precheck.sh"
  cp "$ASSETS_DIR/snippets.md" "$dir/scripts/snippets.md"
  cp "$ASSETS_DIR/mcp-tools.md" "$dir/scripts/mcp-tools.md"
  cp "$ASSETS_DIR/state-machine.sh" "$dir/scripts/state-machine.sh"
  cp "$SRC_SCRIPTS/self-check.sh" "$dir/scripts/self-check.sh"
  chmod +x "$dir/scripts/precheck.sh" "$dir/scripts/state-machine.sh" "$dir/scripts/self-check.sh"
  cp "$SRC_REF/subagent-orchestration.md" "$dir/references/subagent-orchestration.md"
  cp "$SRC_REF/review-methodology.md" "$dir/references/review-methodology.md"
  cp "$SRC_REF/code-graph-tools.md" "$dir/references/code-graph-tools.md"
  cp "$SRC_REF/gsd-patterns.md" "$dir/references/gsd-patterns.md"
  cp "$SRC_REF/memory-persistence.md" "$dir/references/memory-persistence.md"
  cp "$SRC_REF/security-spec.md" "$dir/references/security-spec.md"
  cp "$SRC_REF/cognition-framework.md" "$dir/references/cognition-framework.md"
  cp "$SRC_REF/logic-razor.md" "$dir/references/logic-razor.md"
  cp "$SRC_REF/cognitive-bias.md" "$dir/references/cognitive-bias.md"
  cp "$SRC_REF/domain-knowledge.md" "$dir/references/domain-knowledge.md"
  cp "$SRC_REF/claude-code-capabilities.md" "$dir/references/claude-code-capabilities.md"
}

PROJECT_SPECIFIC_FILES=("SKILL.md" "references/workflow.md" "references/codebase.md" "references/dev-guide.md" "references/release.md" "references/reference-manual.md")

# ============================================================
# 升级模式
# ============================================================
if [[ "$MODE" == "upgrade" ]]; then
  [[ ! -d "$SKILL_DIR" ]] && { echo "ERROR: 目标技能不存在: $SKILL_DIR"; exit 1; }
  echo "=== 升级: $SKILL_DIR ==="
  echo "  时间戳: $SWARM_YUAN_STAMP"
  backup_dir="$SKILL_DIR/.upgrade-backup-${SWARM_YUAN_STAMP}"
  mkdir -p "$backup_dir/assets" "$backup_dir/scripts" "$backup_dir/references"
  echo "=== 1. 备份 ==="
  for f in assets/spec-template.md assets/plan-template.md assets/branch-setup.sh assets/env-setup.sh assets/data-sample-template.md assets/state-machine.sh scripts/precheck.sh scripts/snippets.md scripts/mcp-tools.md scripts/state-machine.sh scripts/self-check.sh references/subagent-orchestration.md references/review-methodology.md references/code-graph-tools.md references/gsd-patterns.md references/memory-persistence.md references/security-spec.md references/cognition-framework.md references/logic-razor.md references/cognitive-bias.md references/domain-knowledge.md references/claude-code-capabilities.md; do
    [[ -f "$SKILL_DIR/$f" ]] && { mkdir -p "$backup_dir/$(dirname "$f")"; cp "$SKILL_DIR/$f" "$backup_dir/$f"; }
  done
  echo "  ✓ 已备份"
  echo "=== 2. 覆盖通用模板 ==="
  copy_universal_templates "$SKILL_DIR"
  echo "  ✓ 已更新"
  echo "=== 3. 保留项目特定文件 ==="
  for f in "${PROJECT_SPECIFIC_FILES[@]}"; do [[ -f "$SKILL_DIR/$f" ]] && echo "  ✓ $f"; done
  echo "=== 4. 版本戳 ==="
  cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
upgraded_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=upgrade
EOF
  echo "  ✓ .swarm-yuan-version"
  echo "=== 升级完成 ==="
  echo "  备份: $backup_dir"
  echo "  下一步: AI 自动检查 + 重新探查填充 precheck.conf + 运行门禁验证"
  exit 0
fi

# ============================================================
# 创建模式
# ============================================================
[[ -d "$SKILL_DIR" ]] && { echo "ERROR: 已存在: $SKILL_DIR（用 --upgrade 升级）"; exit 1; }

echo "=== 创建: $SKILL_DIR ==="
mkdir -p "$SKILL_DIR"/{references,assets,scripts,hooks,commands}
copy_universal_templates "$SKILL_DIR"

fill_guide() {
  case "$1" in
    workflow.md) echo "八节点全流程，每节点 9 要素，4-Phase SOP，节点①含读取项目知识子步骤" ;;
    codebase.md) echo "目录结构+技术栈版本表+端口+配置" ;;
    dev-guide.md) echo "改造分类+拼装式开发原则+安全编码规范" ;;
    release.md) echo "编译规则+构建命令+产物位置" ;;
    reference-manual.md) echo "安全+组件+接口+数据+认知映射+谬误图谱+领域知识" ;;
    *) echo "见 template-spec.md" ;;
  esac
}
for f in workflow.md codebase.md dev-guide.md release.md reference-manual.md; do
  cat > "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f
> 填充指引：$(fill_guide "$f")
EOF
done

cat > "$SKILL_DIR/hooks/hooks.json" <<'HEOF'
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|clear|compact", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" status 2>/dev/null || true"}],
    "PreToolUse": [{"matcher": "Write|Edit", "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --scope --quiet 2>/dev/null || true"}]
  }
}
HEOF

cat > "$SKILL_DIR/commands/spec.md" <<'CEOF'
---
description: 开始新需求——AI 自动创建 spec + 判断规模 + 预填复用约束
argument-hint: <需求描述>
---
AI 自动：1.创建 spec 文件 2.判断规模 3.预填 §5.5 4.运行 --reuse 验证
$ARGUMENTS
CEOF
cat > "$SKILL_DIR/commands/precheck.md" <<'CEOF'
---
description: 运行门禁检查
argument-hint: --all | --all-full | <gate>
---
bash scripts/precheck.sh $ARGUMENTS
CEOF
cat > "$SKILL_DIR/commands/explore.md" <<'CEOF'
---
description: 探查项目结构
---
用 gitnexus/graphify/claude-mem 探查项目，更新特征卡。
CEOF

cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $SKILL_NAME
description: （填充指引：触发条件 + 项目关键词）
---
# $SKILL_NAME — （填充指引：项目名 + 需求交付全流程技能）
> 由 swarm-yuan 生成器创建（${SWARM_YUAN_STAMP}），需 AI agent 探查后填充。
> 填充规范见 swarm-yuan/references/template-spec.md
## 填充指引
- [ ] meta: 核心理念+改造分类+流程总览+命令速查+门禁
- [ ] workflow: 八节点+4-Phase SOP+每节点读取项目知识
- [ ] reference: codebase/dev-guide/release/reference-manual + 方法论+认知 reference
- [ ] assets: spec-template(§5.5-§18) + plan + branch + env + data + state-machine
- [ ] check: precheck.sh 25 门禁
- [ ] scripts: precheck + state-machine + snippets + mcp-tools
EOF

cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
created_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=create
EOF

echo "✓ 骨架已创建: $SKILL_DIR"
echo ""
find "$SKILL_DIR" -type f | sort
echo ""
echo "下一步: AI 自动探查 $PROJECT_DIR 并填充全部文件 + 配置 precheck.conf + 运行门禁验证。"
echo "  用户无需手动编辑任何配置文件。"
echo "  升级已有技能: bash generate-skill.sh --upgrade $SKILL_NAME $PROJECT_DIR"

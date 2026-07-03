#!/usr/bin/env bash
# generate-skill.sh — swarm-yuan 目标技能脚手架生成器
# 用法: bash generate-skill.sh <skill-name> <project-dir> [target-dir]
# 作用: 在 target-dir 下创建目标技能的六段式目录骨架（含全部材料要素文件），从 assets/ 拷贝模板
# 注意: 本脚本只创建骨架与通用模板，具体内容需由 AI agent 探查项目后填充

set -euo pipefail

SKILL_NAME="${1:?Usage: generate-skill.sh <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh <skill-name> <project-dir> [target-dir]}"
TARGET_DIR="${3:-$PROJECT_DIR/.agents/skills}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: 项目目录不存在: $PROJECT_DIR"
  exit 1
fi

SKILL_DIR="$TARGET_DIR/$SKILL_NAME"
ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets"

if [[ -d "$SKILL_DIR" ]]; then
  echo "ERROR: 目标技能已存在: $SKILL_DIR"
  exit 1
fi

echo "=== 创建目标技能骨架: $SKILL_DIR ==="
mkdir -p "$SKILL_DIR"/{references,assets,scripts}

# --- assets 段（7 项）---
cp "$ASSETS_DIR/spec-template.md"        "$SKILL_DIR/assets/spec-template.md"
cp "$ASSETS_DIR/plan-template.md"        "$SKILL_DIR/assets/plan-template.md"
cp "$ASSETS_DIR/branch-setup.sh"         "$SKILL_DIR/assets/branch-setup.sh"
cp "$ASSETS_DIR/env-setup.sh"            "$SKILL_DIR/assets/env-setup.sh"
cp "$ASSETS_DIR/data-sample-template.md" "$SKILL_DIR/assets/data-sample-template.md"
cp "$ASSETS_DIR/state-machine.sh"        "$SKILL_DIR/assets/state-machine.sh"
chmod +x "$SKILL_DIR/assets/branch-setup.sh" "$SKILL_DIR/assets/env-setup.sh" "$SKILL_DIR/assets/state-machine.sh"

# --- scripts 段（6 项，含 self-check）---
cp "$ASSETS_DIR/precheck.sh"             "$SKILL_DIR/scripts/precheck.sh"
cp "$ASSETS_DIR/snippets.md"             "$SKILL_DIR/scripts/snippets.md"
cp "$ASSETS_DIR/mcp-tools.md"            "$SKILL_DIR/scripts/mcp-tools.md"
cp "$ASSETS_DIR/state-machine.sh"        "$SKILL_DIR/scripts/state-machine.sh"
# self-check.sh（9 项目运行时自检 + 自动安装）
SRC_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
cp "$SRC_SCRIPTS/self-check.sh"          "$SKILL_DIR/scripts/self-check.sh"
chmod +x "$SKILL_DIR/scripts/precheck.sh" "$SKILL_DIR/scripts/state-machine.sh" "$SKILL_DIR/scripts/self-check.sh"

# --- reference 段（8 项 → 7 文件）+ workflow 段（9 要素）+ 方法论整合 ---
# 创建待填充的 reference 占位文件（agent 探查后填充）
for f in workflow.md codebase.md dev-guide.md release.md reference-manual.md; do
  cat > "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f

> 本文件由 swarm-yuan 生成器创建，需 AI agent 探查项目后填充。
> 填充规范见 swarm-yuan/references/template-spec.md
EOF
done

# 拷贝方法论 reference（已成型，无需填充，agent 按需引用）
SRC_REF="$(cd "$(dirname "$0")/.." && pwd)/references"
cp "$SRC_REF/subagent-orchestration.md" "$SKILL_DIR/references/subagent-orchestration.md"
cp "$SRC_REF/review-methodology.md"     "$SKILL_DIR/references/review-methodology.md"
cp "$SRC_REF/code-graph-tools.md"       "$SKILL_DIR/references/code-graph-tools.md"
cp "$SRC_REF/gsd-patterns.md"           "$SKILL_DIR/references/gsd-patterns.md"
cp "$SRC_REF/memory-persistence.md"     "$SKILL_DIR/references/memory-persistence.md"
# scripts 段：code-graph-tools.md（引用 GitNexus/graphify）
cp "$SRC_REF/code-graph-tools.md"       "$SKILL_DIR/scripts/code-graph-tools.md"

# --- meta 段 ---
cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $SKILL_NAME
description: （待填充）触发条件与技能概述。需包含项目特有关键词以提高触发率。
---

# $SKILL_NAME — （待填充）项目需求交付全流程技能

> 本技能由 swarm-yuan 生成器创建，需 AI agent 探查项目后填充。
> 填充规范见 swarm-yuan/references/template-spec.md

## 待填充段落（六段式 + 材料要素 + 方法论整合核对）
- [ ] **meta**: 核心理念、改造分类、全流程总览（含入口顺序）、命令速查、门禁、检查表
- [ ] **workflow** (9 要素/节点): references/workflow.md
  - 节点②③用 OpenSpec proposal→spec(delta)→design→tasks 模式
  - 节点⑤用 superpowers subagent 编排（见 references/subagent-orchestration.md）
  - 状态控制引用 scripts/state-machine.sh（comet 风格脚本背书）
- [ ] **reference** (8 项 + 3 方法论): codebase.md / dev-guide.md / release.md / reference-manual.md
  + subagent-orchestration.md / review-methodology.md / code-graph-tools.md（已就绪，按需引用）
- [ ] **assets** (7 项): spec-template.md(OpenSpec proposal) / plan-template.md(tasks checkbox) /
  branch-setup.sh / env-setup.sh / data-sample-template.md / state-machine.sh
- [ ] **check** (4 项 + 审查): scripts/precheck.sh（--test/--sensitive/--consistency/--review）
  + reference-manual.md 检查段（含 5 审查维度，见 review-methodology.md）
- [ ] **scripts** (5 项): precheck.sh / state-machine.sh / snippets.md / code-graph-tools.md / mcp-tools.md
  - code-graph-tools.md 引用 GitNexus/graphify（只引用命令，不复制源码）
  - mcp-tools.md §2 MCP 工具(DB/ELK/Redis/MQ，按项目实际)
EOF

echo ""
echo "✓ 骨架已创建: $SKILL_DIR"
echo ""
echo "=== 目录结构（六段式，覆盖材料全部要素）==="
find "$SKILL_DIR" -type f | sort
echo ""
echo "下一步: AI agent 探查 $PROJECT_DIR 后，填充各占位文件。"
echo "  探查指南: swarm-yuan/references/exploration-guide.md"
echo "  填充规范: swarm-yuan/references/template-spec.md"
echo "  核对清单: template-spec.md 末尾"生成后核对清单""

#!/usr/bin/env bash
# generate-skill.sh — swarm-yuan 目标技能脚手架生成器 / 升级器
# 用法:
#   bash generate-skill.sh <skill-name> <project-dir> [target-dir]       # 创建新技能骨架
#   bash generate-skill.sh --upgrade <skill-name> <project-dir> [target-dir]  # 升级已存在技能的模板文件
# 作用:
#   创建模式: 在 target-dir 下创建目标技能的六段式目录骨架（含全部材料要素文件），从 assets/ 拷贝模板
#   升级模式: 用 swarm-yuan 最新模板覆盖已存在技能的"通用模板文件"（precheck/spec-template/方法论 reference），
#            保留"项目特定填充文件"（SKILL.md/codebase.md/dev-guide.md/release.md/reference-manual.md/workflow.md）
# 注意: 本脚本只创建骨架与通用模板，具体内容需由 AI agent 探查项目后填充

set -euo pipefail

# ---- 解析模式 ----
MODE="create"
if [[ "${1:-}" == "--upgrade" ]]; then
  MODE="upgrade"
  shift
fi

SKILL_NAME="${1:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
PROJECT_DIR="${2:?Usage: generate-skill.sh [--upgrade] <skill-name> <project-dir> [target-dir]}"
TARGET_DIR="${3:-$PROJECT_DIR/.agents/skills}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: 项目目录不存在: $PROJECT_DIR"
  exit 1
fi

SKILL_DIR="$TARGET_DIR/$SKILL_NAME"
ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets"
SRC_REF="$(cd "$(dirname "$0")/.." && pwd)/references"
SRC_SCRIPTS="$(cd "$(dirname "$0")" && pwd)"

# swarm-yuan 版本戳（用于追踪生成/升级时 swarm-yuan 的状态）
SWARM_YUAN_VERSION="$(cd "$(dirname "$0")/.." && pwd)/SKILL.md"
SWARM_YUAN_STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"

# ---- 通用文件拷贝函数（create 和 upgrade 共用）----
# 通用模板文件 = 可被 swarm-yuan 升级覆盖的文件（不含项目特定内容）
copy_universal_templates() {
  local dir="$1"
  # --- assets 段（7 项）---
  cp "$ASSETS_DIR/spec-template.md"        "$dir/assets/spec-template.md"
  cp "$ASSETS_DIR/plan-template.md"        "$dir/assets/plan-template.md"
  cp "$ASSETS_DIR/branch-setup.sh"         "$dir/assets/branch-setup.sh"
  cp "$ASSETS_DIR/env-setup.sh"            "$dir/assets/env-setup.sh"
  cp "$ASSETS_DIR/data-sample-template.md" "$dir/assets/data-sample-template.md"
  cp "$ASSETS_DIR/state-machine.sh"        "$dir/assets/state-machine.sh"
  chmod +x "$dir/assets/branch-setup.sh" "$dir/assets/env-setup.sh" "$dir/assets/state-machine.sh"

  # --- scripts 段（precheck + precheck.conf + state-machine + self-check + snippets/mcp/code-graph）---
  cp "$ASSETS_DIR/precheck.sh"             "$dir/scripts/precheck.sh"
  cp "$ASSETS_DIR/precheck.conf"            "$dir/scripts/precheck.conf"
  cp "$ASSETS_DIR/snippets.md"             "$dir/scripts/snippets.md"
  cp "$ASSETS_DIR/mcp-tools.md"            "$dir/scripts/mcp-tools.md"
  cp "$ASSETS_DIR/state-machine.sh"        "$dir/scripts/state-machine.sh"
  cp "$SRC_SCRIPTS/self-check.sh"          "$dir/scripts/self-check.sh"
  chmod +x "$dir/scripts/precheck.sh" "$dir/scripts/state-machine.sh" "$dir/scripts/self-check.sh"

  # --- reference 段：方法论 reference（已成型，无需填充，agent 按需引用）---
  cp "$SRC_REF/subagent-orchestration.md" "$dir/references/subagent-orchestration.md"
  cp "$SRC_REF/review-methodology.md"     "$dir/references/review-methodology.md"
  cp "$SRC_REF/code-graph-tools.md"       "$dir/references/code-graph-tools.md"
  cp "$SRC_REF/gsd-patterns.md"           "$dir/references/gsd-patterns.md"
  cp "$SRC_REF/memory-persistence.md"     "$dir/references/memory-persistence.md"
  cp "$SRC_REF/security-spec.md"          "$dir/references/security-spec.md"
  # 四层认知基底 reference（第三层逻辑剃刀 + 第四层认知偏差 + 四层总览）
  cp "$SRC_REF/cognition-framework.md"    "$dir/references/cognition-framework.md"
  cp "$SRC_REF/logic-razor.md"            "$dir/references/logic-razor.md"
  cp "$SRC_REF/cognitive-bias.md"         "$dir/references/cognitive-bias.md"
  cp "$SRC_REF/domain-knowledge.md"       "$dir/references/domain-knowledge.md"
  cp "$SRC_REF/claude-code-capabilities.md" "$dir/references/claude-code-capabilities.md"
}

# ---- 项目特定文件列表（upgrade 时保留，不覆盖）----
PROJECT_SPECIFIC_FILES=(
  "SKILL.md"
  "references/workflow.md"
  "references/codebase.md"
  "references/dev-guide.md"
  "references/release.md"
  "references/reference-manual.md"
)

# ============================================================
# 升级模式
# ============================================================
if [[ "$MODE" == "upgrade" ]]; then
  if [[ ! -d "$SKILL_DIR" ]]; then
    echo "ERROR: 目标技能不存在: ${SKILL_DIR}（无法升级）"
    exit 1
  fi

  echo "=== 升级目标技能: $SKILL_DIR ==="
  echo "  swarm-yuan 升级时间戳: $SWARM_YUAN_STAMP"
  echo ""

  # 备份被覆盖的通用模板（以防项目曾自定义过）
  backup_dir="$SKILL_DIR/.upgrade-backup-${SWARM_YUAN_STAMP}"
  mkdir -p "$backup_dir/assets" "$backup_dir/scripts" "$backup_dir/references"

  echo "=== 1. 备份现有通用模板 → $backup_dir ==="
  for f in assets/spec-template.md assets/plan-template.md assets/branch-setup.sh assets/env-setup.sh assets/data-sample-template.md assets/state-machine.sh \
           scripts/precheck.sh scripts/snippets.md scripts/mcp-tools.md scripts/state-machine.sh scripts/self-check.sh scripts/code-graph-tools.md \
           references/subagent-orchestration.md references/review-methodology.md references/code-graph-tools.md references/gsd-patterns.md references/memory-persistence.md references/security-spec.md \
           references/cognition-framework.md references/logic-razor.md references/cognitive-bias.md; do
    if [[ -f "$SKILL_DIR/$f" ]]; then
      mkdir -p "$backup_dir/$(dirname "$f")"
      cp "$SKILL_DIR/$f" "$backup_dir/$f"
    fi
  done
  echo "  ✓ 已备份"

  echo ""
  echo "=== 2. 覆盖通用模板（用 swarm-yuan 最新版）==="
  copy_universal_templates "$SKILL_DIR"
  echo "  ✓ 已更新 precheck.sh / spec-template.md / 3 个认知 reference / 6 个方法论 reference"

  echo ""
  echo "=== 3. 保留项目特定文件（未覆盖）==="
  for f in "${PROJECT_SPECIFIC_FILES[@]}"; do
    if [[ -f "$SKILL_DIR/$f" ]]; then
      echo "  ✓ 保留: $f"
    fi
  done

  echo ""
  echo "=== 4. 写入版本戳 ==="
  cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
upgraded_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=upgrade
EOF
  echo "  ✓ $SKILL_DIR/.swarm-yuan-version"

  echo ""
  echo "=== 升级完成 ==="
  echo "  通用模板已更新到 swarm-yuan 最新版"
  echo "  项目特定文件保留（如 SKILL.md 含旧版框架描述，需手动同步四层认知基底）"
  echo "  备份: $backup_dir"
  echo ""
  echo "  ⚠ 升级后须手动检查:"
  echo "    1. SKILL.md 是否引用了新增的门禁/认知框架段（可能需补四层认知基底段）"
  echo "    2. reference-manual.md 是否含认知映射表/逻辑谬误图谱/六维动力学基线段"
  echo "    3. precheck.sh 配置变量是否按项目实际填充（升级后配置变量重置为占位符）"
  echo "    4. spec-template.md 的 §14/§15/§16 段是否需在 SKILL.md 中引用"
  exit 0
fi

# ============================================================
# 创建模式（原有逻辑）
# ============================================================
if [[ -d "$SKILL_DIR" ]]; then
  echo "ERROR: 目标技能已存在: $SKILL_DIR"
  echo "  如需升级已有技能，用: bash generate-skill.sh --upgrade $SKILL_NAME $PROJECT_DIR"
  exit 1
fi

echo "=== 创建目标技能骨架: $SKILL_DIR ==="
mkdir -p "$SKILL_DIR"/{references,assets,scripts,hooks,commands}

copy_universal_templates "$SKILL_DIR"

# --- reference 段（待填充占位文件，含具体填充指引）---
fill_guide() {
  case "$1" in
    workflow.md) echo "八节点全流程（①需求→②spec→③plan→④分支→⑤编码→⑥测试→⑦合入→⑧发布），每节点 9 要素。映射 4-Phase SOP（概念澄清→破局重构→七步推演→行动落地，每 Phase 暂停等确认）。节点①含'读取项目最新知识（AGENTS.md/CLAUDE.md/记忆）'子步骤。详见 template-spec.md §2" ;;
    codebase.md) echo "§1 目录结构+技术栈版本表+端口+配置+构建机制。从特征卡第 1/4/5/10 项填充" ;;
    dev-guide.md) echo "§7 组件库代码填充+改造分类+拼装式开发原则+安全编码规范+三平台兼容规范。从特征卡第 2/3/11 项填充" ;;
    release.md) echo "§3 编译规则表+构建命令+产物位置+失败排查。从特征卡第 5 项填充真实命令" ;;
    reference-manual.md) echo "§2 安全检查清单 + §4 组件库 + §5 依赖链路 + §6 接口 + §7 UI + §8 数据字典 + check §1-4 + 逻辑谬误图谱 + 认知映射表 + 辩证映射表。从特征卡第 7/9/11/12 项填充" ;;
    *) echo "见 template-spec.md" ;;
  esac
}
for f in workflow.md codebase.md dev-guide.md release.md reference-manual.md; do
  cat > "$SKILL_DIR/references/$f" <<EOF
# （待填充）$f

> 本文件由 swarm-yuan 生成器创建，需 AI agent 探查项目后填充。
> 填充规范见 swarm-yuan/references/template-spec.md
> 填充指引：$(fill_guide "$f")
EOF
done

# --- hooks 段：SessionStart + PreToolUse(Write) ---
cat > "$SKILL_DIR/hooks/hooks.json" <<'HEOF'
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|clear|compact",
      "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/state-machine.sh\" status 2>/dev/null || true"
    }],
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "command": "bash \"${CLAUDE_PLUGIN_ROOT:-.}/scripts/precheck.sh\" --scope --quiet 2>/dev/null || true"
    }]
  }
}
HEOF

# --- commands 段：slash 命令入口 ---
cat > "$SKILL_DIR/commands/spec.md" <<'CEOF'
---
description: 开始新需求——AI 自动创建 spec 文件 + 判断规模 + 引导填写 + 预填复用约束
argument-hint: <需求描述>
---
AI 自动执行：
1. 从 assets/spec-template.md 复制到 specs/YYYY-MM-DD-<feature>.md
2. 根据需求描述判断变更规模（简单/标准/完整），只引导用户填需要的段
3. 从 reference-manual §4/5/6 检索可复用稳定单元，预填 §5.5 复用约束
4. 填完后运行 precheck.sh --reuse 验证 §5.5 合规

需求描述：$ARGUMENTS
CEOF
cat > "$SKILL_DIR/commands/precheck.md" <<'CEOF'
---
description: 运行门禁检查
argument-hint: --all | --all-full | <gate>
---
运行 `bash scripts/precheck.sh $ARGUMENTS`
CEOF
cat > "$SKILL_DIR/commands/explore.md" <<'CEOF'
---
description: 探查项目结构
---
用 gitnexus/graphify/claude-mem 探查项目，更新特征卡。
CEOF

# --- meta 段 ---
cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $SKILL_NAME
description: （填充指引：写一句触发条件 + 项目特有关键词。例"SwarmStudio 二次开发全流程技能。触发关键词: hermes-overlay, cockpit, patch inject, vitest, 拼装式开发"）
---

# $SKILL_NAME — （填充指引：项目名 + 需求交付全流程技能）项目需求交付全流程技能

> 本技能由 swarm-yuan 生成器创建（${SWARM_YUAN_STAMP}），需 AI agent 探查项目后填充。
> 填充规范见 swarm-yuan/references/template-spec.md

## 填充指引（六段式 + 材料要素 + 方法论整合 + 五层认知基底核对）
- [ ] **★四层认知基底**: SKILL.md 含四层框架段（认知递进/思维语言/认知辩证/认知偏差防范）；spec-template 含 §14 交付衰减/§15 蓝图/§16 认知偏差自检；reference-manual 含逻辑谬误图谱 + 认知映射表 + 六维动力学基线；workflow 含 4-Phase 多轮交互 SOP；check 含逻辑剃刀对抗审查
- [ ] **meta**: 核心理念（四层认知基底 + 拼装式开发三条禁止性约束）、改造分类、全流程总览（含入口顺序）、命令速查、门禁、检查表
- [ ] **workflow** (9 要素/节点 + 4-Phase SOP): references/workflow.md
  - 节点②③用 OpenSpec proposal→spec(delta)→design→tasks 模式
  - 节点⑤用 superpowers subagent 编排（见 references/subagent-orchestration.md）
  - 4-Phase SOP（概念澄清→破局重构→七步推演→行动落地），每 Phase 暂停等确认
  - 状态控制引用 scripts/state-machine.sh（comet 风格脚本背书）
- [ ] **reference** (8 项 + 方法论 + 认知): codebase.md / dev-guide.md / release.md / reference-manual.md
  + subagent-orchestration.md / review-methodology.md / code-graph-tools.md / security-spec.md
  + cognition-framework.md / logic-razor.md / cognitive-bias.md（四层认知 reference，已就绪按需引用）
- [ ] **assets** (7 项): spec-template.md(OpenSpec proposal 含 §5.5复用约束/§5.6版本约束/§5.7安全约束/§14交付衰减/§15蓝图/§16认知偏差自检) / plan-template.md(tasks checkbox) /
  branch-setup.sh / env-setup.sh / data-sample-template.md / state-machine.sh
- [ ] **check** (22 门禁 + 审查 + 逻辑剃刀 + 铁律): scripts/precheck.sh
  --branch/--scope/--build/--test/--sensitive/--consistency/--review/--reuse/--deps/--security
  --layer/--stable-diff/--link-depth/--adr/--contract/--consistency-cross/--impact
  --service/--api/--state/--frontend/--cognition
  + reference-manual.md 检查段（含 5 审查维度 + 逻辑剃刀 6 步 + 谬误图谱）
- [ ] **scripts** (5 项): precheck.sh / state-machine.sh / snippets.md / code-graph-tools.md / mcp-tools.md
  - precheck.sh 22 个门禁子命令，配置变量按项目实际填充（DDD/TOGAF/微服务/前端/认知）
  - code-graph-tools.md 引用 GitNexus/graphify（只引用命令，不复制源码）
  - mcp-tools.md §2 MCP 工具(DB/ELK/Redis/MQ，按项目实际)
EOF

# --- 版本戳 ---
cat > "$SKILL_DIR/.swarm-yuan-version" <<EOF
created_at=$SWARM_YUAN_STAMP
generator=swarm-yuan
mode=create
EOF

echo ""
echo "✓ 骨架已创建: $SKILL_DIR"
echo ""
echo "✓ 骨架已创建: $SKILL_DIR"
echo ""
echo "=== 目录结构（六段式，覆盖材料全部要素）==="
find "$SKILL_DIR" -type f | sort
echo ""
echo "下一步: AI 自动探查 $PROJECT_DIR 并填充全部文件 + 配置 precheck.conf + 运行门禁验证。"
echo "  用户无需手动编辑任何配置文件。"
echo "  AI 探查指南: swarm-yuan/references/exploration-guide.md"
echo "  AI 填充规范: swarm-yuan/references/template-spec.md"
echo "  AI 核对清单: template-spec.md 末尾"生成后核对清单""
echo ""
echo "  升级已有技能: bash generate-skill.sh --upgrade $SKILL_NAME $PROJECT_DIR"

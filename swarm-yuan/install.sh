#!/usr/bin/env bash
# install.sh — swarm-yuan 安装脚本（自动检测运行环境，安装到对应 skill 默认目录）
# 用法:
#   bash install.sh                    # 自动检测环境 + 安装
#   bash install.sh --claude           # 强制安装到 ~/.claude/skills/
#   bash install.sh --cursor           # 强制安装到 ~/.cursor/skills/
#   bash install.sh --codex            # 强制安装到 ~/.codex/skills/
#   bash install.sh --opencode         # 强制安装到 ~/.config/opencode/skills/
#   bash install.sh --windsurf         # 强制安装到 ~/.codeium/windsurf/skills/
#   bash install.sh --gemini           # 强制安装到 ~/.gemini/skills/
#   bash install.sh --kimi             # 强制安装到 ~/.kimi/skills/
#   bash install.sh --all              # 安装到所有已检测到的环境
#   bash install.sh --list             # 仅列出检测到的环境，不安装

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
# 查找 SKILL.md 所在目录作为源目录
# 场景1: 从 zip 解压，install.sh 和 SKILL.md 同目录
# 场景2: 从 git clone，install.sh 在 swarm-yuan/ 子目录或仓库根目录
# 场景3: 已安装在 ~/.claude/skills/swarm-yuan/ 下
SRC_DIR=""
for cand in "$SCRIPT_PATH" "$SCRIPT_PATH/swarm-yuan" "$SCRIPT_PATH/.." "$SCRIPT_PATH/../.."; do
  if [[ -f "$cand/SKILL.md" ]]; then SRC_DIR="$(cd "$cand" && pwd)"; break; fi
done
if [[ ! -f "$SRC_DIR/SKILL.md" ]]; then
  echo "ERROR: 未找到 SKILL.md，请确保在 swarm-yuan 目录下运行此脚本"
  exit 1
fi

# ===== 运行环境定义 =====
# 格式: "工具名|检测目录|slash command 目录"
RUNTIMES=(
  "Claude Code|$HOME/.claude/skills|$HOME/.claude/commands"
  "Codex|$HOME/.codex/skills|$HOME/.codex/skills"
  "Cursor|$HOME/.cursor/skills|"
  "Windsurf|$HOME/.codeium/windsurf/skills|"
  "OpenCode|$HOME/.config/opencode/skills|"
  "Gemini CLI|$HOME/.gemini/skills|"
  "Kimi|$HOME/.kimi/skills|"
)

# ===== 检测已安装的运行时 =====
detect_runtimes() {
  local found=()
  for rt in "${RUNTIMES[@]}"; do
    local name="${rt%%|*}"
    local dir="${rt#*|}"; dir="${dir%%|*}"
    if [[ -d "$dir" ]]; then
      found+=("$rt")
    fi
  done
  echo "${found[@]}"
}

# ===== 安装到指定目录 =====
install_to() {
  local name="$1" skill_dir="$2" cmd_dir="$3"
  local dest="$skill_dir/swarm-yuan"

  echo "=== 安装到 $name ==="
  echo "  目标: $dest"

  # 检查是否已存在
  if [[ -d "$dest" ]]; then
    echo "  ⚠ 已存在，备份旧版本..."
    mv "$dest" "${dest}.bak.$(date +%s)"
  fi

  # 复制（排除 docs/ .upgrade-backup* .git .DS_Store）
  mkdir -p "$skill_dir"
  cp -r "$SRC_DIR" "$dest"
  # 清理不需要的文件
  rm -rf "$dest/docs" "$dest/.upgrade-backup-"* "$dest/.git" "$dest/.DS_Store" 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true

  # 设置脚本可执行
  chmod +x "$dest/scripts/"*.sh "$dest/assets/"*.sh 2>/dev/null || true

  echo "  ✓ 已安装: $dest"

  # 安装 slash command（如果有 commands 目录定义）
  if [[ -n "$cmd_dir" && -f "$dest/.claude/commands/swarm-yuan.md" ]]; then
    mkdir -p "$cmd_dir"
    cp "$dest/.claude/commands/swarm-yuan.md" "$cmd_dir/swarm-yuan.md"
    echo "  ✓ slash command 已注册: $cmd_dir/swarm-yuan.md"
  fi

  # 运行自检
  if [[ -f "$dest/scripts/self-check.sh" ]]; then
    echo ""
    echo "  运行自检..."
    bash "$dest/scripts/self-check.sh" --check-only 2>&1 | head -15 || true
  fi
}

# ===== 主逻辑 =====
MODE="${1:-auto}"

case "$MODE" in
  --list)
    echo "=== 检测到的运行环境 ==="
    found=$(detect_runtimes)
    if [[ -z "$found" ]]; then
      echo "  未检测到任何已安装的 AI 工具"
    else
      for rt in $found; do
        local name="${rt%%|*}"
        local dir="${rt#*|}"; dir="${dir%%|*}"
        echo "  ✅ $name ($dir)"
      done
    fi
    exit 0
    ;;
  --claude)
    install_to "Claude Code" "$HOME/.claude/skills" "$HOME/.claude/commands"
    ;;
  --cursor)
    install_to "Cursor" "$HOME/.cursor/skills" ""
    ;;
  --codex)
    install_to "Codex" "$HOME/.codex/skills" "$HOME/.codex/skills"
    ;;
  --opencode)
    install_to "OpenCode" "$HOME/.config/opencode/skills" ""
    ;;
  --windsurf)
    install_to "Windsurf" "$HOME/.codeium/windsurf/skills" ""
    ;;
  --gemini)
    install_to "Gemini CLI" "$HOME/.gemini/skills" ""
    ;;
  --kimi)
    install_to "Kimi" "$HOME/.kimi/skills" ""
    ;;
  --all)
    found=$(detect_runtimes)
    if [[ -z "$found" ]]; then
      echo "ERROR: 未检测到任何已安装的 AI 工具"
      echo "  用 --claude/--cursor/--codex 等强制指定"
      exit 1
    fi
    for rt in $found; do
      name="${rt%%|*}"
      dir="${rt#*|}"; dir="${dir%%|*}"
      cmd="${rt##*|}"
      install_to "$name" "$dir" "$cmd"
      echo ""
    done
    ;;
  auto|"")
    echo "=== 自动检测运行环境 ==="
    found=$(detect_runtimes)
    if [[ -z "$found" ]]; then
      echo "  未检测到已安装的 AI 工具，默认安装到 ~/.claude/skills/"
      install_to "通用" "$HOME/.claude/skills" "$HOME/.claude/commands"
    elif [[ $(echo "$found" | wc -w) -eq 1 ]]; then
      # 只检测到一个
      rt="$found"
      name="${rt%%|*}"
      dir="${rt#*|}"; dir="${dir%%|*}"
      cmd="${rt##*|}"
      install_to "$name" "$dir" "$cmd"
    else
      # 检测到多个，让用户选择
      echo "  检测到多个运行环境："
      i=1
      for rt in $found; do
        name="${rt%%|*}"
        dir="${rt#*|}"; dir="${dir%%|*}"
        echo "    $i) $name ($dir)"
        i=$((i+1))
      done
      echo "    $i) 全部安装"
      echo ""
      read -rp "选择安装目标 [1-$i]: " choice
      if [[ "$choice" == "$i" ]]; then
        for rt in $found; do
          name="${rt%%|*}"
          dir="${rt#*|}"; dir="${dir%%|*}"
          cmd="${rt##*|}"
          install_to "$name" "$dir" "$cmd"
          echo ""
        done
      else
        i=1
        for rt in $found; do
          if [[ "$i" == "$choice" ]]; then
            name="${rt%%|*}"
            dir="${rt#*|}"; dir="${dir%%|*}"
            cmd="${rt##*|}"
            install_to "$name" "$dir" "$cmd"
            break
          fi
          i=$((i+1))
        done
      fi
    fi
    ;;
  *)
    echo "Usage: bash install.sh [--claude|--cursor|--codex|--opencode|--windsurf|--gemini|--kimi|--all|--list]"
    exit 1
    ;;
esac

echo ""
echo "=== 安装完成 ==="
echo "  使用方法：对 AI 说 '为 /path/to/project 生成 skill'"
echo "  或用 slash command：/swarm-yuan /path/to/project"
echo "  详细说明：docs/USAGE.md"

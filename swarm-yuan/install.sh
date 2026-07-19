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
SRC_DIR=""
for cand in "$SCRIPT_PATH" "$SCRIPT_PATH/swarm-yuan" "$SCRIPT_PATH/.." "$SCRIPT_PATH/../.."; do
  if [[ -f "$cand/SKILL.md" ]]; then SRC_DIR="$(cd "$cand" && pwd)"; break; fi
done
if [[ -z "$SRC_DIR" ]]; then
  echo "ERROR: 未找到 SKILL.md，请确保在 swarm-yuan 目录下运行此脚本"
  exit 1
fi

# ===== 运行时检测 =====
# 返回: 名称<TAB>skill目录<TAB>slash命令目录（每行一个）
detect_runtimes() {
  # Claude Code
  if [[ -d "$HOME/.claude/skills" ]]; then printf 'Claude Code\t%s\t%s\n' "$HOME/.claude/skills" "$HOME/.claude/commands"; fi
  # Codex
  if [[ -d "$HOME/.codex/skills" ]]; then printf 'Codex\t%s\t\n' "$HOME/.codex/skills"; fi
  # Cursor
  if [[ -d "$HOME/.cursor/skills" ]]; then printf 'Cursor\t%s\t\n' "$HOME/.cursor/skills"; fi
  # Windsurf
  if [[ -d "$HOME/.codeium/windsurf/skills" ]]; then printf 'Windsurf\t%s\t\n' "$HOME/.codeium/windsurf/skills"; fi
  # OpenCode
  if [[ -d "$HOME/.config/opencode/skills" ]]; then printf 'OpenCode\t%s\t\n' "$HOME/.config/opencode/skills"; fi
  # Gemini CLI
  if [[ -d "$HOME/.gemini/skills" ]]; then printf 'Gemini CLI\t%s\t\n' "$HOME/.gemini/skills"; fi
  # Kimi
  if [[ -d "$HOME/.kimi/skills" ]]; then printf 'Kimi\t%s\t\n' "$HOME/.kimi/skills"; fi
}

# 源目录与目标相同（已安装在此）时：跳过复制，仅确保 slash command 已注册
skip_self_install() {
  local cmd_dir="$1"
  echo "  ⚠ 源目录与目标目录相同，跳过复制（已安装在此位置）"
  if [[ -n "$cmd_dir" && -f "$SRC_DIR/.claude/commands/swarm-yuan.md" ]]; then
    mkdir -p "$cmd_dir"
    cp "$SRC_DIR/.claude/commands/swarm-yuan.md" "$cmd_dir/swarm-yuan.md"
    echo "  ✓ slash command 已注册: ${cmd_dir}/swarm-yuan.md"
  fi
}

# ===== 安装到指定目录 =====
install_to() {
  local name="$1" skill_dir="$2" cmd_dir="$3"
  local dest="$skill_dir/swarm-yuan"

  echo "=== 安装到 ${name} ==="
  echo "  目标: ${dest}"

  # 不能自我复制（SRC_DIR == dest 时跳过复制，只注册 slash command）
  if [[ "$SRC_DIR" == "$dest" ]]; then
    skip_self_install "$cmd_dir"
    return 0
  fi

  # 备份旧版本
  if [[ -d "$dest" ]]; then
    echo "  ⚠ 已存在，备份旧版本..."
    mv "$dest" "${dest}.bak.$(date +%s)"
  fi

  # 复制（排除 offline-cache/：33MB 离线安装缓存，不应进入每个运行时 skill 目录；
  # 逐项 cp -R 覆盖隐藏文件，三平台兼容，无需 tar --exclude）
  mkdir -p "$skill_dir" "$dest"
  local item base
  for item in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
    [[ -e "$item" ]] || continue
    base="$(basename "$item")"
    [[ "$base" == "offline-cache" ]] && continue
    cp -R "$item" "$dest/"
  done
  rm -rf "$dest/docs" "$dest/.upgrade-backup-"* "$dest/.git" "$dest/.DS_Store" 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true
  chmod +x "$dest/scripts/"*.sh "$dest/assets/"*.sh 2>/dev/null || true

  echo "  ✓ 已安装: ${dest}"

  # 注册 slash command
  if [[ -n "$cmd_dir" && -f "$dest/.claude/commands/swarm-yuan.md" ]]; then
    mkdir -p "$cmd_dir"
    cp "$dest/.claude/commands/swarm-yuan.md" "$cmd_dir/swarm-yuan.md"
    echo "  ✓ slash command 已注册: ${cmd_dir}/swarm-yuan.md"
  fi
}

# ===== 主逻辑 =====
MODE="${1:-auto}"

case "$MODE" in
  --list)
    echo "=== 检测到的运行环境 ==="
    found="$(detect_runtimes)"
    if [[ -z "$found" ]]; then
      echo "  未检测到任何已安装的 AI 工具"
    else
      echo "$found" | while IFS=$'\t' read -r name dir _; do
        echo "  ✅ ${name} (${dir})"
      done
    fi
    ;;
  --claude)
    install_to "Claude Code" "$HOME/.claude/skills" "$HOME/.claude/commands"
    ;;
  --cursor)
    install_to "Cursor" "$HOME/.cursor/skills" ""
    ;;
  --codex)
    install_to "Codex" "$HOME/.codex/skills" ""
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
    found="$(detect_runtimes)"
    if [[ -z "$found" ]]; then
      echo "ERROR: 未检测到任何已安装的 AI 工具"
      exit 1
    fi
    echo "$found" | while IFS=$'\t' read -r name dir cmd; do
      install_to "$name" "$dir" "$cmd"
      echo ""
    done
    ;;
  auto|"")
    echo "=== 自动检测运行环境 ==="
    found="$(detect_runtimes)"
    if [[ -z "$found" ]]; then
      echo "  未检测到已安装的 AI 工具，默认安装到 ~/.claude/skills/"
      install_to "通用" "$HOME/.claude/skills" "$HOME/.claude/commands"
    else
      count=$(echo "$found" | wc -l | xargs)
      if [[ "$count" -eq 1 ]]; then
        echo "$found" | while IFS=$'\t' read -r name dir cmd; do
          install_to "$name" "$dir" "$cmd"
        done
      else
        echo "  检测到多个运行环境："
        i=1
        echo "$found" | while IFS=$'\t' read -r name dir _; do
          echo "    ${i}) ${name} (${dir})"
          i=$((i+1))
        done
        echo "    a) 全部安装"
        echo ""
        read -rp "选择安装目标 [1-${count}/a]: " choice
        if [[ "$choice" == "a" ]]; then
          echo "$found" | while IFS=$'\t' read -r name dir cmd; do
            install_to "$name" "$dir" "$cmd"
            echo ""
          done
        else
          i=1
          echo "$found" | while IFS=$'\t' read -r name dir cmd; do
            if [[ "$i" == "$choice" ]]; then
              install_to "$name" "$dir" "$cmd"
              break
            fi
            i=$((i+1))
          done
        fi
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

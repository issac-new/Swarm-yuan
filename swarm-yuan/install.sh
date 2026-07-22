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
#   bash install.sh --version          # 显示版本号 + bash 版本
# 安装后动作：对每个安装目标自动调用 scripts/generate-skill.sh --render-tools 补生成
#   该工具原生规则文件（.cursor/rules/*.mdc、AGENTS.md/GEMINI.md 段等；失败仅警告，不影响安装）

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

# ===== 多平台规则渲染（P3）：安装后补生成该工具原生规则文件 =====
# 失败仅 warn 不 fail——不破坏现有目录复制主流程。Claude Code 已深度集成，适配器内 no-op。
render_native_rules() {
  local name="$1" dest="$2" key
  case "$name" in
    "Claude Code"|"通用") key="claude" ;;
    "Cursor")      key="cursor" ;;
    "Codex")       key="codex" ;;
    "OpenCode")    key="opencode" ;;
    "Windsurf")    key="windsurf" ;;
    "Gemini CLI")  key="gemini" ;;
    "Kimi")        key="kimi" ;;
    *)             key="" ;;
  esac
  [[ -n "$key" ]] || return 0
  local gen="$SRC_DIR/scripts/generate-skill.sh"
  [[ -f "$gen" ]] || { echo "  ⚠ 未找到 ${gen}，跳过原生规则渲染"; return 0; }
  if ! bash "$gen" --render-tools "$dest" "" "$key"; then
    echo "  ⚠ ${name} 原生规则渲染返回非 0（仅警告，不影响安装主流程）"
  fi
  return 0
}

# 源目录与目标相同（已安装在此）时：跳过复制，仅确保 slash command 已注册
skip_self_install() {
  local name="$1" cmd_dir="$2"
  echo "  ⚠ 源目录与目标目录相同，跳过复制（已安装在此位置）"
  if [[ -n "$cmd_dir" && -f "$SRC_DIR/.claude/commands/swarm-yuan.md" ]]; then
    mkdir -p "$cmd_dir"
    cp "$SRC_DIR/.claude/commands/swarm-yuan.md" "$cmd_dir/swarm-yuan.md"
    echo "  ✓ slash command 已注册: ${cmd_dir}/swarm-yuan.md"
  fi
  render_native_rules "$name" "$SRC_DIR"
}

# ===== 安装到指定目录 =====
install_to() {
  local name="$1" skill_dir="$2" cmd_dir="$3"
  local dest="$skill_dir/swarm-yuan"

  echo "=== 安装到 ${name} ==="
  echo "  目标: ${dest}"

  # 不能自我复制（SRC_DIR == dest 时跳过复制，只注册 slash command）
  if [[ "$SRC_DIR" == "$dest" ]]; then
    skip_self_install "$name" "$cmd_dir"
    return 0
  fi

  # 备份旧版本
  if [[ -d "$dest" ]]; then
    echo "  ⚠ 已存在，备份旧版本..."
    mv "$dest" "${dest}.bak.$(date +%s)"
  fi

  # 复制（逐项 cp -R 覆盖隐藏文件，三平台兼容，无需 tar --exclude）
  mkdir -p "$skill_dir" "$dest"
  local item
  for item in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
    [[ -e "$item" ]] || continue
    cp -R "$item" "$dest/"
  done
  rm -rf "$dest/docs" "$dest/.upgrade-backup-"* "$dest/.git" "$dest/.DS_Store" 2>/dev/null || true
  find "$dest" -name '.DS_Store' -delete 2>/dev/null || true
  chmod +x "$dest/scripts/"*.sh "$dest/assets/"*.sh "$dest/assets/tool-adapters/"*.sh 2>/dev/null || true

  echo "  ✓ 已安装: ${dest}"

  # 注册 slash command
  if [[ -n "$cmd_dir" && -f "$dest/.claude/commands/swarm-yuan.md" ]]; then
    mkdir -p "$cmd_dir"
    cp "$dest/.claude/commands/swarm-yuan.md" "$cmd_dir/swarm-yuan.md"
    echo "  ✓ slash command 已注册: ${cmd_dir}/swarm-yuan.md"
  fi

  # 多平台规则渲染（P3）：补生成该工具原生规则文件；渲染失败仅 warn，不影响安装
  render_native_rules "$name" "$dest"
}

# ===== 主逻辑 =====
MODE="${1:-auto}"

case "$MODE" in
  --version)
    # 范式版本（与 .swarm-yuan-version 的 upgraded_at 对齐，由 git describe 自动派生）
    ver="unknown"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      ver=$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")
    fi
    echo "swarm-yuan installer $ver"
    echo "bash ${BASH_VERSION:-unknown}"
    # 最低 bash 版本校验（bash 3.2 即可，macOS 默认满足）
    if [[ "${BASH_VERSINFO[0]:-0}" -lt 3 ]]; then
      echo "⚠ bash 版本过低（${BASH_VERSION}），需 bash 3.2+（macOS 默认 BSD bash 3.2 兼容）"
    fi
    exit 0
    ;;
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
    echo "Usage: bash install.sh [--claude|--cursor|--codex|--opencode|--windsurf|--gemini|--kimi|--all|--list|--version]"
    exit 1
    ;;
esac

echo ""
echo "=== 安装完成 ==="
echo "  使用方法：对 AI 说 '为 /path/to/project 生成 skill'"
echo "  或用 slash command：/swarm-yuan /path/to/project"

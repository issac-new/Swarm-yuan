#!/usr/bin/env bash
# spec-first-lib.sh — spec-first 判定单一事实源（R101 四层拦截模型的判定内核）
#
# 消费方（判据同源，四层各取所需）：
#   L1 写时   hooks/fail-gate-hook.sh（Write/Edit PreToolUse deny）
#   L2 提交时 hooks/spec-first-pre-commit.sh（git pre-commit exit 1）
#   L3 门禁时 gates-warn.sh check_spec_first（precheck --all 序列 fail）
#   L4 准入   state-machine.sh guard build（SPEC_REQUIRED=1 硬拦）
# 此前判据三处复制（fail-gate-hook 内联 ×2 + state-machine 审批环）——R36-D10/R75-D3
# 两轮都在同一判据上修过缺陷，复制面即回归面；本库收敛后再接新层。
#
# 契约：纯函数、无副作用、不读环境变量（解析优先级由调用方决定后传参）；
#       恒 rc=0（输出空=未命中/未配置），调用方按输出判定——hook 上下文非零退出会干扰宿主协议。
# bash 3.2 兼容：无关联数组、无 ${var,,}、local 声明与赋值拆行（同行引用前变量 unbound 坑）。

# conf 末行赋值解析（剥行内注释/空白/引号；解析 ${VAR:-def} 自引用默认）。
# 解析链与 fail-gate-hook 原内联版及 state-machine _sm_conf_val 逐字节对齐；
# 注意：<占位符> 剥离是 state-machine 侧语义（骨架 conf 占位符不得当真实值消费），
# 由 _sm_conf_val 包装层追加——本函数不含，保证 fail-gate-hook 行为零变化。
spf_conf_val() {  # $1=conf 文件路径 $2=变量名 → stdout 值（文件缺失/未配置=空）
  local _f="$1" _k="$2"
  local _v=""
  if [[ -f "$_f" ]]; then
    _v=$(grep "^${_k}=" "$_f" 2>/dev/null | tail -1 | cut -d'#' -f1 | tr -d '[:space:]' | sed "s/^${_k}=//;s/^\"//;s/\"\$//" || true)
    case "$_v" in
      "\${${_k}:-"*'}') _v="${_v#\$\{${_k}:-}"; _v="${_v%\}}" ;;
    esac
  fi
  printf '%s' "$_v"
  return 0
}

# WRITABLE_DIRS 解析（fail-gate-hook 原内联链逐字节对齐：括号剥离须容忍行尾注释——
# 行尾锚定的 s/)$// 在 conf 模板惯例「WRITABLE_DIRS=()  # TODO:model」下剥不掉括号，
# 历史缺陷见 fail-gate-hook 注记，勿回退为行尾锚定写法）。
spf_writable_dirs() {  # $1=conf 文件路径 → stdout 空格分隔目录表（未配置=空）
  local _v=""
  if [[ -f "$1" ]]; then
    _v=$(grep '^WRITABLE_DIRS=' "$1" 2>/dev/null | tail -1 | cut -d'#' -f1 | sed -e 's/^WRITABLE_DIRS=(//' -e 's/[[:space:]]*)[[:space:]]*$//' -e 's/"//g' || true)
  fi
  printf '%s' "$_v"
  return 0
}

# 已批准 spec 检测（判据：含「## 决策记录」段且非占位——与 workflow.md ③ 节点产物定义一致）。
spf_find_approved_spec() {  # $1=项目根 $2=spec glob（相对根，如 docs/specs/*.md）→ stdout 命中路径（空=无）
  local _root="$1" _glob="$2"
  local _sf
  for _sf in "${_root}"/${_glob}; do
    [[ -f "$_sf" ]] || continue
    if grep -q '^## .*决策记录' "$_sf" 2>/dev/null && ! grep -qE '待填充|<占位符>' "$_sf" 2>/dev/null; then
      printf '%s' "$_sf"
      return 0
    fi
  done
  return 0
}

# 路径是否落入可写区（fail-gate-hook 原匹配语义：相对段命中 */<dir>/* 或项目根前缀 <root>/<dir>/）。
# $2=项目根（可空——空时前缀模式退化为 /<dir>/，与原 "${PROJECT_DIR:-}/${_d}/" 展开等价）。
# R106-D14 修复①（传参两态兼容）：L3 门禁传 "${WRITABLE_DIRS[*]}"（空格拼接单串），L1/L2 传裸数组
# （多个参数）——原实现只按独立参数迭代，拼接串被当成一个超长"目录名"整体匹配，多目录
# 可写区永远不命中（go-forge 回归实证：internal 改动 L3 判"未触及"）。单参内再按空白拆分，两态通吃。
# R106-D14 修复②（文件型条目）：WRITABLE_DIRS 可含文件条目（如 main.go）——原模式强制尾斜杠
# （*/<dir>/），文件路径永不能命中（死条目）。补 "${_proj}/${_part}" 精确匹配分支。
spf_path_in_dirs() {  # $1=规范化路径 $2=项目根(可空) $3..=目录/文件表（多参数或空格拼接单串均可） → rc 0=命中 1=未命中
  local _p="$1" _proj="$2"
  shift 2
  local _d _part
  for _d in "$@"; do
    # shellcheck disable=SC2086  # 有意按空白拆分（拼接串形态）；路径含空格的条目不在本表语义内
    for _part in $_d; do
      [[ -z "${_part}" ]] && continue
      case "$_p" in
        *"/${_part}/"*|"${_proj}/${_part}/"*|"${_proj}/${_part}") return 0 ;;
      esac
    done
  done
  return 1
}

# draft 骨架判定（骨架期无 spec 是常态，四层拦截全部放行——与 fail-gate-hook draft 分支同口径）。
spf_is_draft() {  # $1=SKILL.md 路径（可空） → rc 0=draft 1=非 draft/缺文件
  [[ -n "${1:-}" && -f "$1" ]] && grep -q '^status: draft' "$1" 2>/dev/null
}

#!/usr/bin/env bash
# conf-render.sh — precheck.conf 三件套初稿渲染（WP-P4/M3）
# 把 Step 8 模型手译 176 变量的机械工作脚本化：嗅探项目 → 渲染 conf 初稿
#   每变量带溯源注释: # AUTO:detected（探测所得）/ # AUTO:default（默认值未动）/ # TODO:model（语义型，须人工）
# 模型新动作: 只处理 # TODO:model 清单 + 审 diff（从「写 158 行」变「审 + 补少数」）
# 用法:
#   bash conf-render.sh <PROJECT_DIR> [--feature-card <f>] [--profile <lite|standard|compliance>] [--industry <name>] [--out <dir>]
#     --feature-card  特征卡 md（解析结构化字段补实值，可选）
#     --profile       lite(只 core) / standard(core+arch) / compliance(三件套)，默认 standard
#     --industry      行业 profile（finance|gov|medical|telecom|automotive|energy|industrial）
#                     真实加载 assets/industry-profiles/<name>.conf 并渲染为 precheck.industry.conf
#                     追加到 precheck.conf 尾部 source 链（R13 批次1a/D3：替代"手工 cat >>"伪激活）
#     --out           落盘目录（不给则 stdout 合并三件套）
# 输出: conf 初稿（每变量行带 # AUTO:* 溯源）；末尾 # TODO:model 清单汇总。
# 退出码: 0 正常（fail-open，嗅探失败用默认）；1 arg 错误。
# 红线: LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量显式留 # TODO:model，脚本不替模型做架构判断。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; CARD=""; PROFILE="standard"; INDUSTRY=""; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-card) CARD="${2:?--feature-card 需要路径}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile 需要 lite|standard|compliance}"; shift 2 ;;
    --industry) INDUSTRY="${2:?--industry 需要 finance|gov|medical|telecom|automotive|energy|industrial}"; shift 2 ;;
    --out) OUT="${2:?--out 需要目录}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ=$(cd "$PROJ" && pwd)
[[ -n "$OUT" ]] && { mkdir -p "$OUT"; }

# ===== 嗅探层 =====
_lang="unknown"; _pm="unknown"; _build=""; _test=""; _build_confirmed=0; _test_confirmed=0; _frameworks=""
if [[ -f "$PROJ/package.json" ]]; then
  _lang="typescript"
  if [[ -f "$PROJ/yarn.lock" ]]; then _pm="yarn"; _build="yarn build"; _test="yarn test"; _build_confirmed=1; _test_confirmed=1
  elif [[ -f "$PROJ/pnpm-lock.yaml" ]]; then _pm="pnpm"; _build="pnpm build"; _test="pnpm test"; _build_confirmed=1; _test_confirmed=1
  else _pm="npm"; _build="npm run build"; _test="npm test"; fi
  # 仅当 package.json 确证含 build/test 脚本时才标 detected（裸 package.json 无脚本 → 默认值 # AUTO:default）
  if grep -qE '"build"[[:space:]]*:' "$PROJ/package.json" 2>/dev/null; then _build_confirmed=1; fi
  if grep -qE '"test"[[:space:]]*:' "$PROJ/package.json" 2>/dev/null; then _test_confirmed=1; fi
elif [[ -f "$PROJ/pom.xml" ]]; then
  _lang="java"; _pm="maven"; _build="mvn package"; _test="mvn test"; _build_confirmed=1; _test_confirmed=1
elif [[ -f "$PROJ/build.gradle" ]] || [[ -f "$PROJ/build.gradle.kts" ]]; then
  _lang="java"; _pm="gradle"; _build="gradle build"; _test="gradle test"; _build_confirmed=1; _test_confirmed=1
elif [[ -f "$PROJ/go.mod" ]]; then
  _lang="go"; _pm="go"; _build="go build ./..."; _test="go test ./..."; _build_confirmed=1; _test_confirmed=1
elif [[ -f "$PROJ/pyproject.toml" ]] || [[ -f "$PROJ/requirements.txt" ]]; then
  _lang="python"; _pm="pip"
  if [[ -f "$PROJ/uv.lock" ]]; then _pm="uv"; _build="uv run build"; _test="uv run pytest"; _build_confirmed=1; _test_confirmed=1
  elif [[ -f "$PROJ/poetry.lock" ]]; then _pm="poetry"; _build="poetry build"; _test="poetry run pytest"; _build_confirmed=1; _test_confirmed=1
  else _build="python -m build"; _test="pytest"; fi
fi
# monorepo 判定
_monorepo=0
[[ -d "$PROJ/packages" && $(ls -1 "$PROJ/packages" 2>/dev/null | wc -l | tr -d ' ') -gt 1 ]] && _monorepo=1
[[ -d "$PROJ/services" && $(ls -1 "$PROJ/services" 2>/dev/null | wc -l | tr -d ' ') -gt 1 ]] && _monorepo=1
# ACTIVE_FRAMEWORKS（调 detect-frameworks.sh；其行式解析器对紧凑单行 package.json 会漏探，fail-open 兜底补 pkgjson）
# 回归发现#2（2026-08-27 RuoYi 双项目回归）：原解析 sed 's/.*"\([^"]*\)".*/\1/p' 贪婪匹配
# 只捕获 ACTIVE_FRAMEWORKS=("vue" "element" "vite") 行的最后一个 "vite" → 骨架 conf 只落
# 1 个框架（SKILL.md 认知摘要另一套正确解析写 3 个 → 设计/实现/生成物三体不一致）。
# 修复：整行剥壳（去 ACTIVE_FRAMEWORKS= 前缀 + 剥 ()"），框架 id 全量保留。
if [[ -x "$BASE/scripts/detect-frameworks.sh" ]]; then
  _frameworks=$("$BASE/scripts/detect-frameworks.sh" "$PROJ" 2>/dev/null | sed -n 's/^ACTIVE_FRAMEWORKS=//p' | tr -d '()"' | sed 's/^ *//; s/ *$//')
fi
# 兜底：detect-frameworks.sh 行式 grep 要求 `"key":` 在行首空白后，紧凑 JSON（键内联）会漏；
# 此处仅当主探测为空且存在 package.json 时，用键无关位置的稳健提取补 pkgjson 类框架（ID 与 detect-frameworks.sh 对齐）。
if [[ -z "$_frameworks" && -f "$PROJ/package.json" ]]; then
  _pkgkeys=$(grep -oE '"[^"]+"[[:space:]]*:' "$PROJ/package.json" 2>/dev/null | sed -E 's/"([^"]+)"[[:space:]]*:.*/\1/' || true)
  _fb=""
  while IFS= read -r _k; do
    [[ -z "$_k" ]] && continue
    case "$_k" in
      react)         _fb="${_fb}${_fb:+ }react" ;;
      react-native)  _fb="${_fb}${_fb:+ }react-native" ;;
      vue|pinia)     _fb="${_fb}${_fb:+ }vue" ;;
      @angular/core) _fb="${_fb}${_fb:+ }angular" ;;
      antd|@ant-design) _fb="${_fb}${_fb:+ }antd" ;;
      element-plus)  _fb="${_fb}${_fb:+ }element" ;;
      naive-ui)      _fb="${_fb}${_fb:+ }naiveui" ;;
      next)          _fb="${_fb}${_fb:+ }nextjs" ;;
      nuxt)          _fb="${_fb}${_fb:+ }nuxt" ;;
      vite)          _fb="${_fb}${_fb:+ }vite" ;;
      webpack)       _fb="${_fb}${_fb:+ }webpack" ;;
      tailwindcss)   _fb="${_fb}${_fb:+ }tailwind" ;;
      koa)           _fb="${_fb}${_fb:+ }koa" ;;
      express)       _fb="${_fb}${_fb:+ }express" ;;
      fastify)       _fb="${_fb}${_fb:+ }fastify" ;;
      @nestjs/*)     _fb="${_fb}${_fb:+ }nestjs" ;;
      @prisma/client|prisma) _fb="${_fb}${_fb:+ }prisma" ;;
      typeorm)       _fb="${_fb}${_fb:+ }typeorm" ;;
      jest|vitest)   _fb="${_fb}${_fb:+ }jest-vitest" ;;
      redis|ioredis) _fb="${_fb}${_fb:+ }redis" ;;
      kafkajs)       _fb="${_fb}${_fb:+ }kafka" ;;
      amqplib)       _fb="${_fb}${_fb:+ }rabbitmq" ;;
      @opentelemetry/api) _fb="${_fb}${_fb:+ }opentelemetry" ;;
    esac
  done <<EOF
$_pkgkeys
EOF
  _frameworks="$_fb"
fi
# 特征卡字段（若给）
if [[ -n "$CARD" && -f "$CARD" ]]; then
  : # 特征卡解析预留：未来从 md 表格提取 WRITABLE_DIRS 等；当前 YAGNI，靠嗅探 + TODO:model
fi

# ===== 渲染层：以模板为基底，逐变量判定溯源 =====
# 溯源判定 helper：变量值非空且确证 → detected，否则 default
_src_build() { [[ "$_build_confirmed" -eq 1 ]] && echo detected || echo default; }
_src_test()  { [[ "$_test_confirmed" -eq 1 ]] && echo detected || echo default; }

# 模板变量映射 → 渲染值 + 溯源（detected/default/TODO:model）
_render_var() { # $1=变量名 $2=模板行
  local vn="$1" line="$2"
  case "$vn" in
    PROJECT_DIR)      printf 'PROJECT_DIR=%s  # AUTO:detected' "$PROJ" ;;
    BUILD_CMD)        printf "BUILD_CMD='%s'  # AUTO:%s" "$_build" "$(_src_build)" ;;
    TEST_CMD)         printf "TEST_CMD='%s'  # AUTO:%s" "$_test" "$(_src_test)" ;;
    ACTIVE_FRAMEWORKS)
      local fw_arr=""
      local f
      for f in $_frameworks; do fw_arr="${fw_arr}${fw_arr:+ }\"$f\""; done
      if [[ -n "$fw_arr" ]]; then
        printf "ACTIVE_FRAMEWORKS=(%s)  # AUTO:detected" "$fw_arr"
      else
        printf "ACTIVE_FRAMEWORKS=()  # AUTO:default"
      fi ;;
    LAYER_DEFS|SERVICE_DIRS|STORE_DIR|WRITABLE_DIRS|READONLY_DIRS|SCAN_DIRS|CONSISTENCY_DIRS|COMPONENT_DIR)
      printf "%s=()  # TODO:model" "$vn" ;;
    *) printf "%s" "$line" ;;  # 其余保留模板原行
  esac
}

# 渲染单份 conf：读模板，对 ^[A-Z_]+= 行替换，其余行原样
_render_conf() { # $1=模板相对路径
  local tpl="$BASE/$1"
  [[ -f "$tpl" ]] || return 0
  local line vn
  while IFS= read -r line; do
    if [[ "$line" =~ ^[A-Z_]+= ]]; then
      vn=$(printf '%s' "$line" | sed -E 's/^([A-Z_]+)=.*/\1/')
      _render_var "$vn" "$line"
    else
      printf '%s' "$line"
    fi
    printf '\n'
  done < "$tpl"
}

# 输出：--out 模式每文件独立落盘；stdout 模式加分隔头合并
_emit_section() { # $1=文件名 $2=内容
  if [[ -n "$OUT" ]]; then
    printf '%s\n' "$2" > "$OUT/$1"
  else
    printf '# ===== %s =====\n' "$1"
    printf '%s\n' "$2"
  fi
}

core=$(_render_conf "assets/precheck.conf")
# lite profile：不含 arch/compliance 兄弟文件，剔除 core 模板里「描述兄弟文件」的纯注释行。
# 注意：保留 `[[ -f ... ]] && source ... || true` 功能行——lite 无兄弟时它是 no-op（|| true），
# 且未来手动补 arch.conf 时能自动加载（升级路径与 standard/compliance 一致）。
if [[ "$PROFILE" == "lite" ]]; then
  core=$(printf '%s\n' "$core" | grep -vE '^#.*precheck\.(arch|compliance)\.conf')
fi
# R13 批次1a（D3）：industry profile 真实加载——渲染为 precheck.industry.conf，
# 并在 precheck.conf 尾部追加 source 行（加载顺序：core→arch→compliance→industry→patch，
# 行业层后于生成层 = 行业覆盖胜出，用户 patch 层仍最末）。
if [[ -n "$INDUSTRY" ]]; then
  _ip_src="$BASE/assets/industry-profiles/${INDUSTRY}.conf"
  if [[ ! -f "$_ip_src" ]]; then
    echo "✗ 未知行业 profile: ${INDUSTRY}（可选：finance|gov|medical|telecom|automotive|energy|industrial）" >&2
    exit 1
  fi
  # 行业层头部改写：原"手工 cat >>"用法注释替换为"本文件由 conf-render --industry 生成"溯源
  _ip_content=$(sed -e '1,10s|^# 用法：.*|# 本文件由 conf-render.sh --industry '"$INDUSTRY"' 生成（R13 D3 真实加载，勿手工编辑）|' "$_ip_src")
  _emit_section "precheck.industry.conf" "$_ip_content"
  # precheck.conf 尾部挂 source（core 的 patch source 之前——行业先于用户覆盖）
  _ind_line='[[ -f "${_conf_self_dir}/precheck.industry.conf" ]] && source "${_conf_self_dir}/precheck.industry.conf" || true'
  _patch_line='[[ -f "$_conf_self_dir/precheck.patch.conf" ]] && source "$_conf_self_dir/precheck.patch.conf" || true'
  # 插到 patch source 行之前（行业先于用户覆盖；patch 仍最末胜出）
  core=$(printf '%s\n' "$core" | awk -v ind="$_ind_line" -v pat="$_patch_line" '
    $0 == pat { print ind }
    { print }
  ')
fi

_emit_section "precheck.conf" "$core"

if [[ "$PROFILE" == "standard" || "$PROFILE" == "compliance" ]]; then
  arch=$(_render_conf "assets/precheck.arch.conf")
  _emit_section "precheck.arch.conf" "$arch"
fi

if [[ "$PROFILE" == "compliance" ]]; then
  comp=$(_render_conf "assets/precheck.compliance.conf")
  _emit_section "precheck.compliance.conf" "$comp"
fi

# F3（dsh 吸收·分层 patch 最小步）：用户覆盖层骨架——纯注释零变量（不进 conf 计数）。
# 加载顺序 core→arch→compliance→patch（precheck.conf 尾部 source，后写胜出）：
# 用户在这里覆盖生成值，不直接改生成的 conf 文件 → upgrade 保留用户配置不再依赖
# "文件被手改"启发式，根治升级漂移。--dump-conf 按同一顺序输出合成视图+来源层。
patch_skel='# precheck.patch.conf —— 用户覆盖层（F3 分层 patch）
# 用法：在此覆盖任意生成变量（后 source 即胜出），例：
#   SENSITIVE_TOOL=builtin          # 覆盖 core 层的 auto
#   ACTIVE_FRAMEWORKS=("vue" "koa") # 覆盖 arch 层框架清单
# 请只写覆盖行，不要复制整份生成 conf——升级时本文件原样保留。'
_emit_section "precheck.patch.conf" "$patch_skel"

# TODO:model 清单汇总
todo="# ===== # TODO:model 清单（须模型补实值）=====
# LAYER_DEFS / SERVICE_DIRS / STORE_DIR / WRITABLE_DIRS / READONLY_DIRS / SCAN_DIRS / CONSISTENCY_DIRS / COMPONENT_DIR"
if [[ -n "$OUT" ]]; then
  printf '%s\n' "$todo" > "$OUT/TODO-model.txt"
else
  printf '%s\n' "$todo"
fi
exit 0

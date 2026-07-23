#!/usr/bin/env bash
# conf-render.sh — precheck.conf 三件套初稿渲染（WP-P4/M3）
# 把 Step 8 模型手译 158 变量的机械工作脚本化：嗅探项目 → 渲染 conf 初稿
#   每变量带溯源注释: # AUTO:detected（探测所得）/ # AUTO:default（默认值未动）/ # TODO:model（语义型，须人工）
# 模型新动作: 只处理 # TODO:model 清单 + 审 diff（从「写 158 行」变「审 + 补少数」）
# 用法:
#   bash conf-render.sh <PROJECT_DIR> [--feature-card <f>] [--profile <lite|standard|compliance>] [--out <dir>]
#     --feature-card  特征卡 md（解析结构化字段补实值，可选）
#     --profile       lite(只 core) / standard(core+arch) / compliance(三件套)，默认 standard
#     --out           落盘目录（不给则 stdout 合并三件套）
# 输出: conf 初稿（每变量行带 # AUTO:* 溯源）；末尾 # TODO:model 清单汇总。
# 退出码: 0 正常（fail-open，嗅探失败用默认）；1 arg 错误。
# 红线: LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量显式留 # TODO:model，脚本不替模型做架构判断。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; CARD=""; PROFILE="standard"; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-card) CARD="${2:?--feature-card 需要路径}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile 需要 lite|standard|compliance}"; shift 2 ;;
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
if [[ -x "$BASE/scripts/detect-frameworks.sh" ]]; then
  _frameworks=$("$BASE/scripts/detect-frameworks.sh" "$PROJ" 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p' | tr '\n' ' ' | sed 's/ *$//')
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
    PROJECT_DIR)      printf "PROJECT_DIR=%s  # AUTO:detected" "$PROJ" ;;
    BUILD_CMD)        printf "BUILD_CMD=%s  # AUTO:%s" "$_build" "$(_src_build)" ;;
    TEST_CMD)         printf "TEST_CMD=%s  # AUTO:%s" "$_test" "$(_src_test)" ;;
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
# lite profile：不含 arch/compliance 兄弟文件，剔除 core 模板里引用兄弟文件名的行
# （纯注释行 + `[[ -f ... ]] && source` no-op 行；lite 无兄弟可加载，剔除语义自洽且令 lite 输出零兄弟引用）
if [[ "$PROFILE" == "lite" ]]; then
  core=$(printf '%s\n' "$core" | grep -vE 'precheck\.(arch|compliance)\.conf')
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

# TODO:model 清单汇总
todo="# ===== # TODO:model 清单（须模型补实值）=====
# LAYER_DEFS / SERVICE_DIRS / STORE_DIR / WRITABLE_DIRS / READONLY_DIRS / SCAN_DIRS / CONSISTENCY_DIRS / COMPONENT_DIR"
if [[ -n "$OUT" ]]; then
  printf '%s\n' "$todo" > "$OUT/TODO-model.txt"
else
  printf '%s\n' "$todo"
fi
exit 0

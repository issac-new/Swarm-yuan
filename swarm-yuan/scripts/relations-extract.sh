#!/usr/bin/env bash
# relations-extract.sh — 机器可读关系边集提取（R21-D：核心链条①"结构关系认知"的索引层）
# 机械提取 import 依赖边 → <skill>/references/relations.jsonl（每行 {"from","to","kind","evidence"}），
# AI 在此初稿上补语义边（kind: call/route/message/ipc/export——调用/路由/消息/IPC/库导出）。
# 消费方：--stable-diff 1 跳下游传播（gates-warn 优先读边集）、流B ②探查查边集替代读 mermaid 图。
#
# 提取范围（确定性 grep+相对路径解析，零外部依赖全平台可用——madge/graphify 深度层由 AI
# 按 exploration-guide §C+ 工具矩阵富化，本脚本不假装接线未装工具）：
#   TS/JS/Vue: import/require/export-from 的相对说明符（./ ../），扩展名/index 解析
#   Python:    from .x / from ..x 相对导入（绝对导入按根目录+同目录 best-effort）
#   Go:        go.mod module 前缀的工程内 import → 目录
#   Java:      import a.b.C; → src/{main,test}/java/a/b/C.java
#
# 用法:
#   bash relations-extract.sh <PROJECT_DIR> [--skill-dir <dir>] [--out <file>] [--max-edges <N>]
#   bash relations-extract.sh <PROJECT_DIR> --verify [--skill-dir <dir>]   # 边抽样核验（advisory）
#     --skill-dir  目标技能根（缺省 --out 无效时默认 <skill>/references/relations.jsonl 的推导路径）
#     --out        输出路径（缺省 <skill-dir>/references/relations.jsonl；无 --skill-dir 则报错）
#     --max-edges  边数上限（默认 2000，超出截断并在 stderr 披露）
# 输出: JSONL 边行（from/to 为项目相对路径，确定性排序）；--verify 输出 RELATION_MISS 行（advisory，exit 0 fail-open）。
# 红线：机械层只出 import 边（证据=说明符原文+行号）；语义边（call/route/...）AI 补——机械不猜。
set -uo pipefail

PROJ=""; SKILL_DIR=""; OUT=""; VERIFY=0; MAXE=2000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir)  SKILL_DIR="${2:?--skill-dir 需要路径}"; shift 2 ;;
    --out)        OUT="${2:?--out 需要路径}"; shift 2 ;;
    --verify)     VERIFY=1; shift ;;
    --max-edges)  MAXE="${2:?--max-edges 需要数值}"; shift 2 ;;
    -h|--help)    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ=$(cd "$PROJ" && pwd)
if [[ -z "$OUT" ]]; then
  [[ -n "$SKILL_DIR" ]] || { echo "✗ 需 --skill-dir 或 --out 之一" >&2; exit 1; }
  OUT="$SKILL_DIR/references/relations.jsonl"
fi

# --- --verify：边抽样核验（from/to 路径存在性 + 最多 20 条抽样）---
if [[ "$VERIFY" -eq 1 ]]; then
  [[ -f "$OUT" ]] || { echo "ℹ 无 relations.jsonl（R21-D 边集未生成——探查期可选产物，跳过核验）"; exit 0; }
  _total=$(LC_ALL=C grep -c . "$OUT" 2>/dev/null || true); _total="${_total:-0}"
  [[ "$_total" -eq 0 ]] && { echo "ℹ relations.jsonl 为空（无边可核）"; exit 0; }
  _miss=0 _checked=0
  # 均匀抽样 ≤20 条（步长 = total/20 向上取整），bash 3.2 安全
  _step=$(( (_total + 19) / 20 )); [[ "$_step" -lt 1 ]] && _step=1
  _i=0
  while IFS= read -r _line; do
    [[ -z "$_line" ]] && continue
    _i=$((_i + 1))
    [[ $(( _i % _step )) -eq 0 || "$_i" -eq 1 ]] || continue
    _checked=$((_checked + 1))
    _from=$(printf '%s' "$_line" | sed -n 's/.*"from":"\([^"]*\)".*/\1/p')
    _to=$(printf '%s' "$_line" | sed -n 's/.*"to":"\([^"]*\)".*/\1/p')
    if [[ -n "$_from" && ! -f "$PROJ/$_from" ]]; then
      echo "RELATION_MISS	from 路径不存在: ${_from}（relations.jsonl 边集失锚，重跑 relations-extract.sh）"
      _miss=$((_miss + 1))
    fi
    if [[ -n "$_to" && ! -f "$PROJ/$_to" && ! -d "$PROJ/$_to" ]]; then
      echo "RELATION_MISS	to 路径不存在: ${_to}（relations.jsonl 边集失锚，重跑 relations-extract.sh）"
      _miss=$((_miss + 1))
    fi
  done < "$OUT"
  if [[ "$_miss" -eq 0 ]]; then
    echo "✓ 关系边集抽样核验通过（${_checked}/${_total} 条，0 失锚）"
  else
    echo "⚠ 关系边集抽样 ${_checked} 条中 ${_miss} 处失锚（advisory：重跑 relations-extract.sh 重建）"
  fi
  exit 0
fi

# --- 提取模式 ---
mkdir -p "$(dirname "$OUT")"
TMPF=$(mktemp /tmp/relx.XXXXXX)
trap 'rm -f "$TMPF"' EXIT

# 规范化项目相对路径（去掉 ./、解析 ../）——bash 3.2 安全的字符串处理
_norm_rel() { # $1=基准目录(相对根) $2=说明符 → stdout 相对路径（未验证存在）
  local base="$1" spec="$2"
  local dir="$base"
  local rest="$spec"
  # 逐段消化 ./ 与 ../
  while [[ "$rest" == .* ]]; do
    case "$rest" in
      ./*)  rest="${rest#./}" ;;
      ../*) dir=$(dirname "$base"); base="$dir"; rest="${rest#../}" ;;
      *)    break ;;
    esac
  done
  printf '%s/%s' "$dir" "$rest"
}

# 相对说明符解析：尝试扩展名/index 候选，存在即输出首个命中（相对项目根的规范串）
_resolve() { # $1=规范化路径前缀（无扩展名） → stdout 命中路径 或 空
  local p="$1" c cand
  for c in "" ".ts" ".tsx" ".js" ".jsx" ".mjs" ".cjs" ".vue" ".py" "/index.ts" "/index.tsx" "/index.js" "/index.jsx" "/index.vue" "/__init__.py"; do
    cand="${p}${c}"
    [[ -f "$PROJ/$cand" ]] && { printf '%s' "$cand"; return 0; }
  done
  return 1
}

_emit() { # $1=from $2=to $3=evidence → 追加到 TMPF
  printf '{"from":"%s","to":"%s","kind":"import","evidence":"%s"}\n' "$1" "$2" "$3" >> "$TMPF"
}

# Go module 名（若有）
GO_MODULE=""
if [[ -f "$PROJ/go.mod" ]]; then
  GO_MODULE=$(sed -n 's/^module[[:space:]][[:space:]]*\([^[:space:]][^[:space:]]*\).*/\1/p' "$PROJ/go.mod" | head -1)
fi

# --- 逐文件提取（bash 循环 + grep；上限保护由 find | head 承担）---
_src_files=$(find "$PROJ" -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.vue' -o -name '*.py' \) \
  -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/.swarm-yuan/*' \
  -print 2>/dev/null | LC_ALL=C sort | head -3000)

while IFS= read -r f_abs; do
  [[ -z "$f_abs" ]] && continue
  f_rel="${f_abs#"$PROJ"/}"
  f_dir=$(dirname "$f_rel")
  case "$f_rel" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.vue)
      # import ... from './x' / require('./x') / export ... from './x' / import './x'
      # 说明符提取：行内最后一个引号串（BSD sed 无交替，取通用引号串后由 case 过滤相对前缀）
      while IFS= read -r hit; do
        [[ -z "$hit" ]] && continue
        ln="${hit%%:*}"; stmt="${hit#*:}"
        # 行内最后一个引号串 = 说明符（贪婪 .* 取最右；字符类含单/双引号，BSD sed 安全）
        spec=$(printf '%s' "$stmt" | sed -n "s/.*['\"]\([^'\"]*\)['\"].*/\1/p")
        case "$spec" in
          ./*|../*) ;;
          *) continue ;;
        esac
        norm=$(_norm_rel "$f_dir" "$spec")
        resolved=$(_resolve "$norm") || continue
        [[ "$resolved" == "$f_rel" ]] && continue
        _emit "$f_rel" "$resolved" "import@${f_rel}:${ln}"
      done < <(grep -nE "(from|require|import)[[:space:]]*[\"'][.][./][^\"']*[\"']" "$f_abs" 2>/dev/null || true)
      ;;
    *.py)
      # from .x import y / from ..x import y（相对导入机械可靠；绝对导入 best-effort 根解析）
      while IFS= read -r hit; do
        [[ -z "$hit" ]] && continue
        ln="${hit%%:*}"; stmt="${hit#*:}"
        spec=$(printf '%s' "$stmt" | sed -n 's/^[[:space:]]*from[[:space:]][[:space:]]*\(\.[.A-Za-z_][.A-Za-z_0-9]*\)[[:space:]][[:space:]]*import.*/\1/p')
        [[ -z "$spec" ]] && continue
        # 点段消化：. → 本目录；.. → 上级；模块名 → <dir>/<mod>.py 或 <dir>/<mod>/__init__.py
        dir="$f_dir"; mod=""
        dots="${spec%%[!.]*}"; rest="${spec#"$dots"}"
        ndots=${#dots}
        i=1
        while [[ $i -lt $ndots ]]; do dir=$(dirname "$dir"); i=$((i+1)); done
        [[ -n "$rest" ]] && mod=$(printf '%s' "$rest" | tr '.' '/')
        base="$dir"; [[ -n "$mod" ]] && base="$dir/$mod"
        resolved=$(_resolve "$base") || continue
        [[ "$resolved" == "$f_rel" ]] && continue
        _emit "$f_rel" "$resolved" "import@${f_rel}:${ln}"
      done < <(grep -nE '^[[:space:]]*from[[:space:]]+\.[.A-Za-z_][.A-Za-z_0-9]*[[:space:]]+import' "$f_abs" 2>/dev/null || true)
      ;;
  esac
done <<< "$_src_files"

# Go 工程内 import（module 前缀剥离 → 目录存在即边）
if [[ -n "$GO_MODULE" ]]; then
  while IFS= read -r f_abs; do
    [[ -z "$f_abs" ]] && continue
    f_rel="${f_abs#"$PROJ"/}"
    while IFS= read -r hit; do
      [[ -z "$hit" ]] && continue
      ln="${hit%%:*}"; stmt="${hit#*:}"
      spec=$(printf '%s' "$stmt" | sed -n "s|.*\"${GO_MODULE}/\([^\"]*\)\".*|\\1|p")
      [[ -z "$spec" ]] && continue
      [[ -d "$PROJ/$spec" ]] || continue
      _emit "$f_rel" "$spec" "import@${f_rel}:${ln}"
    done < <(grep -nF "\"${GO_MODULE}/" "$f_abs" 2>/dev/null || true)
  done < <(find "$PROJ" -type f -name '*.go' -not -path '*/.git/*' -print 2>/dev/null | LC_ALL=C sort | head -1500)
fi

# Java 包路径映射 import（src/{main,test}/java/<pkg>/<Class>.java 存在即边）
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  f_rel="${hit%%|*}"
  rest="${hit#*|}"                       # 绝对路径:行号:内容
  ln=$(printf '%s' "$rest" | cut -d: -f2)
  imp=$(printf '%s' "$rest" | sed -n 's/.*import[[:space:]][[:space:]]*\([a-z][a-zA-Z0-9_.]*\);.*/\1/p')
  [[ -z "$imp" ]] && continue
  pkgpath=$(printf '%s' "$imp" | tr '.' '/')
  for root in src/main/java src/test/java; do
    if [[ -f "$PROJ/$root/$pkgpath.java" ]]; then
      _emit "$f_rel" "$root/$pkgpath.java" "import@${f_rel}:${ln}"
      break
    fi
  done
done < <(grep -RnE '^[[:space:]]*import[[:space:]]+[a-z][a-zA-Z0-9_.]*;' "$PROJ" --include='*.java' 2>/dev/null \
  | LC_ALL=C awk -F: -v proj="$PROJ" '{ f=substr($1, length(proj)+2); print f "|" $0 }' | LC_ALL=C sort -u | head -2000)

# 截断 + 确定性排序 + 落盘
_n=$(LC_ALL=C grep -c . "$TMPF" 2>/dev/null || true); _n="${_n:-0}"
if [[ "$_n" -gt "$MAXE" ]]; then
  echo "⚠ 边数 ${_n} 超上限 ${MAXE}，截断（大仓库建议分段提取或提高 --max-edges）" >&2
fi
LC_ALL=C sort -t'"' -k4,4 -k8,8 "$TMPF" | LC_ALL=C awk -v max="$MAXE" 'NR <= max' > "$OUT"
_n_final=$(LC_ALL=C grep -c . "$OUT" 2>/dev/null || true); _n_final="${_n_final:-0}"
echo "✓ 关系边集已生成: ${OUT}（${_n_final} 条 import 边；语义边 call/route/message/ipc/export 由 AI 补充，格式同款 kind 字段）"
echo "  消费方：--stable-diff 1 跳传播优先读本边集；流B ②探查查边集替代读 mermaid"
exit 0

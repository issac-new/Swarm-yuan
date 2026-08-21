#!/usr/bin/env bash
# ontology-verify.sh — R16-B：本体论健康检查（统一依赖完整性入口）
#
# 设计来源：docs/DESIGN-ONTOLOGY.md §五（依赖细目——六类依赖各配机器锚）。
# 此前六锚散落各命令（fingerprint/stability-audit/版本/digest/audit/last-good），用户要判断
# "本体论依赖是否完整"须跑多个命令——本脚本一站式汇总，输出六锚健康报告。
#
# 用法:
#   bash ontology-verify.sh <PROJECT_DIR> [--skill-dir <dir>]
# 退出码: 0 正常（advisory 性质，失配不阻断——本体口径是体检不是门禁）；1 arg 错误。
set -uo pipefail
PROJ=""; SKILL_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir) SKILL_DIR="${2:?--skill-dir 需要路径}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ=$(cd "$PROJ" && pwd)
BASE="$(cd "$(dirname "$0")" && pwd)"
[[ -z "$SKILL_DIR" && -f "$PROJ/../SKILL.md" ]] && SKILL_DIR="$PROJ/.."

echo "## 本体论健康检查（六锚一站式，R16）—— project=${PROJ}"
_ok()  { echo "  ✓ $1"; }
_bad() { echo "  ⚠ $1"; }

# 锚1：地图↔仓库的特定依赖（表征时效）
FP="$PROJ/.swarm-yuan/project-fingerprint"
if [[ ! -f "$FP" ]]; then
  _bad "Fingerprint 快照不存在（地图↔仓库依赖未锚定）——先跑 project-fingerprint.sh --write 落基线"
else
  out=$(bash "$BASE/project-fingerprint.sh" "$PROJ" --diff 2>&1)
  if printf '%s' "$out" | grep -q '无变化'; then
    _ok "地图↔仓库（Fingerprint）：快照与当前仓库一致（表征时效锚定）"
  else
    scope=$(printf '%s' "$out" | grep -cE '^\s+[~+-] ' || true)
    _ok "地图↔仓库（Fingerprint）：仓库已变化（${scope} 个 scope 变更）——按 SKILL.md 自成长段走更新链后 --write 落新基线"
  fi
fi

# 锚2：标注↔组件倾向（稳定性依赖）
if [[ -n "$SKILL_DIR" && -f "$SKILL_DIR/references/reference-manual.md" ]]; then
  out=$(bash "$BASE/inventory-verify.sh" "$PROJ" --skill-dir "$SKILL_DIR" --tsv --stability-audit 2>&1) || true
  sw=$(printf '%s' "$out" | grep -c '^STABILITY_WARN' || true)
  if [[ "${sw:-0}" -eq 0 ]]; then
    _ok "标注↔组件倾向（stability-audit）：稳定性标注与 churn/fan-in/测试三信号无冲突"
  else
    _bad "标注↔组件倾向：${sw} 处 STABILITY_WARN（标注与机械信号矛盾——复核稳定性标注）"
  fi
else
  _bad "stability-audit 跳过（skill-dir 或 reference-manual.md 缺失）"
fi

# 锚3：生成物↔生成器（类依赖/版本）
if [[ -n "$SKILL_DIR" && -f "$SKILL_DIR/.swarm-yuan-version" ]]; then
  _ok "生成物↔生成器（版本戳）：$(head -2 "$SKILL_DIR/.swarm-yuan-version" | tr '\n' ' ')"
else
  _bad "版本戳缺失（.swarm-yuan-version 不存在——生成物↔生成器依赖未锚定，--upgrade 溯源将失效）"
fi

# 锚4：decisions↔trace 链式依赖（digest 锚）
DEC="$PROJ/.swarm-yuan/decisions.jsonl"; TR="$PROJ/.swarm-yuan/trace.jsonl"
if [[ -f "$DEC" && -f "$TR" ]]; then
  last_dec_hash=$(tail -1 "$DEC" | sed -n 's/.*"ref_trace_hash":"\([^"]*\)".*/\1/p')
  if [[ -z "$last_dec_hash" ]]; then
    _ok "decisions↔trace（digest 链）：最近决策无 ref_trace_hash（R15 前旧行——回放兼容，非失配）"
  else
    cur_hash=$(tail -1 "$TR" | cksum | awk '{print $1}')
    if [[ "$last_dec_hash" == "$cur_hash" ]]; then
      _ok "decisions↔trace（digest 链）：末锚匹配（trace 未被篡改）"
    else
      _bad "decisions↔trace（digest 链）：末锚失配（decisions 记 ${last_dec_hash} vs trace 当前 ${cur_hash}——trace 在决策后有新行=正常追加；若怀疑篡改，比对 trace 历史）"
    fi
  fi
else
  _bad "digest 链跳过（decisions.jsonl 或 trace.jsonl 不存在）"
fi

# 锚5：账本↔过程（配对审计）
GA="$PROJ/.swarm-yuan/gate-audit.jsonl"
if [[ -f "$GA" ]]; then
  n=$(wc -l < "$GA" | tr -d ' ')
  _ok "账本↔过程（gate-audit）：${n} 行决策审计（invoked/result 单行自包含）"
else
  _ok "账本↔过程（gate-audit）：无审计文件（hooks 未启用拦截=休眠态，正常）"
fi

# 锚6：好基线反事实保护（last-good 红线状态）
if [[ -f "$FP" ]]; then
  total=$(sed -n 's/^total=\([0-9]*\).*/\1/p' "$FP" | head -1)
  _ok "last-good 红线：当前基线 total=${total}（骤降 >50% 时 --write 将拒绝并要求 --force）"
fi

echo "→ 六锚语义详见 docs/DESIGN-ONTOLOGY.md §五（每条依赖的断裂可检测点）"
exit 0

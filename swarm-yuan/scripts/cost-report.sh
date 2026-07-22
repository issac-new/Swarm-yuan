#!/usr/bin/env bash
# cost-report.sh — 全链路追踪成本遥测（WP-D：把"重不重"从感觉变成数字）
# 数据源：<项目根>/.swarm-yuan/trace.jsonl（trace-log.sh 落盘，ts/node/actor/tool/status/note）
#         可选 .gate-runs/gate-runs.jsonl 或 GATE_RUNS_DIR 证据（存在则汇总门禁 fail/warn 趋势）
# 用法: bash cost-report.sh [--dir <项目根>] [--stdout]
#   --dir     项目根（默认 $(pwd)）
#   --stdout  只打印不落盘（默认写 .swarm-yuan/cost-report.md 并打印摘要）
# 退出码：恒 0（fail-open；无数据时打印提示，不阻塞任何流程）
set -euo pipefail

DIR=""
STDOUT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:?--dir 需要项目根路径}"; shift 2 ;;
    --stdout) STDOUT=1; shift ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "未知参数: $1（--help 查看用法）" >&2; exit 1 ;;
  esac
done
DIR="${DIR:-$(pwd)}"
TRACE="$DIR/.swarm-yuan/trace.jsonl"
OUT="$DIR/.swarm-yuan/cost-report.md"

if [[ ! -f "$TRACE" ]]; then
  echo "无追踪数据: $TRACE 不存在"
  echo "（trace-log.sh 节点级落盘后才有数据；调用级细节用 SWARM_YUAN_TRACE=verbose 收集）"
  exit 0
fi

_total=$(wc -l < "$TRACE" | tr -d ' ')
_first=$(head -1 "$TRACE" | sed -E 's/.*"ts":"([^"]*)".*/\1/')
_last=$(tail -1 "$TRACE" | sed -E 's/.*"ts":"([^"]*)".*/\1/')
_fails=$(grep -c '"status":"fail"' "$TRACE" 2>/dev/null || true)
_fails="${_fails:-0}"

# 字段 Top10 聚合（bash 3.2 兼容：sed 提取 + sort|uniq -c，不用 declare -A）
_top() { # $1=字段名
  # WP-R Bug#1: sed|sort|uniq|sort|head -10 在 set -euo pipefail 下,head 截断使上游 sort/uniq 收
  # SIGPIPE(141),pipefail 传播非零 → set -e 退出。改用 sort|uniq -c|sort -rn 写临时再 head(无截断管道)。
  sed -E "s/.*\"$1\":\"([^\"]*)\".*/\1/" "$TRACE" 2>/dev/null | sort | uniq -c | sort -rn | head -10 || true
}

{
  echo "# 成本遥测报告（cost-report.sh）"
  echo ""
  echo "- 数据源: \`$TRACE\`"
  echo "- 时间跨度: $_first → $_last"
  echo "- 总调用数: ${_total}（status=fail: ${_fails}）"
  echo ""
  echo "## 按节点（node）"
  echo '```'
  _top node
  echo '```'
  echo ""
  echo "## 按执行者（actor）"
  echo '```'
  _top actor
  echo '```'
  echo ""
  echo "## 按工具（tool）"
  echo '```'
  _top tool
  echo '```'

  # 可选：门禁运行证据（precheck --format json + GATE_RUNS_DIR 落盘时存在）
  _gr="$DIR/.swarm-yuan/gate-runs/gate-runs.jsonl"
  [[ -f "$_gr" ]] || _gr="$DIR/.gate-runs/gate-runs.jsonl"
  if [[ -f "$_gr" ]]; then
    _gt=$(wc -l < "$_gr" | tr -d ' ')
    echo ""
    echo "## 门禁运行证据（gate-runs.jsonl）"
    echo "- 记录数: $_gt"
  fi

  # G1 决策治理聚合（decisions.jsonl，对齐 ISO/IEC 42001 §9.1 监视测量）
  _dec="$DIR/.swarm-yuan/decisions.jsonl"
  if [[ -f "$_dec" && -s "$_dec" ]]; then
    _dt=$(wc -l < "$_dec" | tr -d ' ')
    echo ""
    echo "## 决策治理（decisions.jsonl，ISO/IEC 42001 §9.1）"
    echo "- 决策总数: $_dt"
    echo "- 按类型:"
    echo '```'
    sed -E 's/.*"type":"([^"]*)".*/\1/' "$_dec" 2>/dev/null | sort | uniq -c | sort -rn || true
    echo '```'
    echo "- 按用户裁定:"
    echo '```'
    sed -E 's/.*"user_action":"([^"]*)".*/\1/' "$_dec" 2>/dev/null | sort | uniq -c | sort -rn || true
    echo '```'
    echo "- 按阶段:"
    echo '```'
    sed -E 's/.*"phase":"([^"]*)".*/\1/' "$_dec" 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -rn || true
    echo '```'
    # UserChallenge 裁定率（approved/rejected/revised 分布是人工监督有效性的信号）
    _uc=$(grep -c '"type":"UserChallenge"' "$_dec" 2>/dev/null || echo 0)
    _uc="${_uc:-0}"
    [[ "$_uc" -gt 0 ]] && echo "- UserChallenge 决策: ${_uc}（含五要素的方向性决策）"
  fi
  echo ""
  echo "> 生成: $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ) · 调用级细节设 SWARM_YUAN_TRACE=verbose 后数据更全"
} > "$OUT.tmp"

if [[ $STDOUT -eq 1 ]]; then
  cat "$OUT.tmp"
  rm -f "$OUT.tmp"
else
  mv "$OUT.tmp" "$OUT"
  cat "$OUT"
  echo ""
  echo "→ 已写入 $OUT"
fi

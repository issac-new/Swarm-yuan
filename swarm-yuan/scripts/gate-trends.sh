#!/usr/bin/env bash
# gate-trends.sh — 各门禁近 N 次通过率趋势表（P2 度量雏形：Q-08/Q-20 通过率趋势）
# 数据源：precheck.sh 在 conf GATE_RUNS_DIR 非空时落盘的 gate-runs.jsonl
#         （行格式契约 {"ts","gate","status","ids","duration_s"}，由 precheck.sh _gate_evidence 产出）
# 用法: bash gate-trends.sh [gate-runs.jsonl 路径] [N=10]
#   无 jsonl（或文件为空/无有效行）时提示并 exit 0——与门禁族「未配置静默跳过」姿态一致。
# 口径：每门禁取近 N 条记录（含 skip），通过率=pass/记录数；趋势串按时间旧→新（✓=pass ✗=fail ⚠=warn ·=skip）。
set -u

JSONL="${1:-gate-runs.jsonl}"
N="${2:-10}"
case "$N" in
  ''|*[!0-9]*|0) echo "用法: bash gate-trends.sh [gate-runs.jsonl] [N=10]（N 须为正整数）" >&2; exit 1 ;;
esac

if [[ ! -s "$JSONL" ]]; then
  echo "ℹ 未找到 gate-runs 证据文件（$JSONL）——请先在 precheck.conf 配置 GATE_RUNS_DIR 并运行门禁"
  exit 0
fi

# awk 聚合：逐行提取 gate/status（键序固定，与落盘契约一致），按门禁保序拼接状态首字母；
# END 截近 N 条统计分状态计数与通过率。bsd awk 兼容（无关联数组遍历顺序要求，外部 sort 定序）。
rows=$(awk -v n="$N" '
  {
    line=$0; g=""; s=""
    if (match(line, /"gate":"[^"]+"/))   g=substr(line, RSTART+8,  RLENGTH-9)
    if (match(line, /"status":"[^"]+"/)) s=substr(line, RSTART+10, RLENGTH-11)
    if (g == "" || s == "") next
    cnt[g]++; seq[g]=seq[g] substr(s,1,1)
  }
  END {
    for (g in cnt) {
      total=cnt[g]; str=seq[g]
      start=(total>n ? total-n+1 : 1)
      win=substr(str, start)
      m=length(win); p=0; f=0; w=0; k=0
      for (i=1; i<=m; i++) {
        c=substr(win,i,1)
        if (c=="p") p++; else if (c=="f") f++; else if (c=="w") w++; else k++
      }
      t=win
      gsub(/p/,"✓",t); gsub(/f/,"✗",t); gsub(/w/,"⚠",t); gsub(/s/,"·",t)
      printf "%-28s %6d %6d %6d %6d %6d %7.1f%%  %s\n", g, m, p, f, w, k, (m>0 ? 100.0*p/m : 0), t
    }
  }
' "$JSONL")

if [[ -z "$rows" ]]; then
  echo "ℹ $JSONL 中无有效门禁记录（行格式须符合 precheck.sh gate-runs JSONL 契约）"
  exit 0
fi

echo "gate-runs 趋势（数据源: $JSONL；窗口: 近 $N 次/门禁）"
printf "%-28s %6s %6s %6s %6s %6s %8s  %s\n" "gate" "样本" "pass" "fail" "warn" "skip" "通过率" "趋势(旧→新)"
printf '%s\n' "$rows" | sort
exit 0

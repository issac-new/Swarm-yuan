#!/usr/bin/env bash
# gate-trends.sh — 各门禁近 N 次通过率趋势表（P2 度量雏形：Q-08/Q-20 通过率趋势）
#                  P3 深化：--html 输出自包含可视化报告（内联 SVG，无外部依赖）
# 数据源：precheck.sh 在 conf GATE_RUNS_DIR 非空时落盘的 gate-runs.jsonl
#         （行格式契约 {"ts","gate","status","ids","duration_s"}，由 precheck.sh _gate_evidence 产出）
# 用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl 路径] [N=10]
#   无 jsonl（或文件为空/无有效行）时提示并 exit 0——与门禁族「未配置静默跳过」姿态一致。
# 口径：每门禁取近 N 条记录（含 skip），通过率=pass/记录数；趋势串按时间旧→新（✓=pass ✗=fail ⚠=warn ·=skip）。
# HTML 报告要素：时间范围统计 / 每门禁通过率折线（窗口内累计通过率）/ 状态色块 / 最近 fail id TOP 10（全量）。
#   配色低饱和暖色系；不引用任何外部 URL（SVG 不声明 xmlns，保持 grep 可核的零外链）。
set -u

# ---- 参数解析（bash 3.2 兼容：位置参数保持原语义 [jsonl] [N]，--html 可前置/后置）----
HTML_OUT=""
JSONL=""
N=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --html)
      [[ $# -ge 2 && -n "$2" ]] || { echo "用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl] [N=10]" >&2; exit 1; }
      HTML_OUT="$2"; shift 2 ;;
    --html=*)
      HTML_OUT="${1#--html=}"
      [[ -n "$HTML_OUT" ]] || { echo "用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl] [N=10]" >&2; exit 1; }
      shift ;;
    -h|--help)
      echo "用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl] [N=10]"; exit 0 ;;
    *)
      if [[ -z "$JSONL" ]]; then JSONL="$1"
      elif [[ -z "$N" ]]; then N="$1"
      else echo "用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl] [N=10]（多余参数: $1）" >&2; exit 1
      fi
      shift ;;
  esac
done
JSONL="${JSONL:-gate-runs.jsonl}"
N="${N:-10}"
case "$N" in
  ''|*[!0-9]*|0) echo "用法: bash gate-trends.sh [--html <输出.html>] [gate-runs.jsonl] [N=10]（N 须为正整数）" >&2; exit 1 ;;
esac

if [[ ! -s "$JSONL" ]]; then
  echo "ℹ 未找到 gate-runs 证据文件（${JSONL}）——请先在 precheck.conf 配置 GATE_RUNS_DIR 并运行门禁"
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

# ---- 文本模式（默认）：输出与原实现逐行一致（既有断言/人工判读契约不变）----
if [[ -z "$HTML_OUT" ]]; then
  echo "gate-runs 趋势（数据源: ${JSONL}；窗口: 近 $N 次/门禁）"
  printf "%-28s %6s %6s %6s %6s %6s %8s  %s\n" "gate" "样本" "pass" "fail" "warn" "skip" "通过率" "趋势(旧→新)"
  printf '%s\n' "$rows" | sort
  exit 0
fi

# ---- HTML 模式：自包含报告（内联 SVG；awk 生成主体，fail TOP 经外部 sort 定序后由 shell 拼装）----
TMP_TOP="$(mktemp /tmp/gate-trends-top.XXXXXX)" || { echo "✗ mktemp 失败" >&2; exit 1; }
trap 'rm -f "$TMP_TOP"' EXIT

# 主体 awk：34 门禁固定序（与 precheck.sh ALL_GATES_FULL 一致）保证输出顺序稳定；
# 未登记门禁追加于后。fail id 以「次数|最近ts|gate|id」写入 TMP_TOP（id 含 | 不支持，契约内不出现）。
awk -v n="$N" -v topfile="$TMP_TOP" -v jsonl="$JSONL" -v gen_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" '
  function esc(x){ gsub(/&/,"\\&amp;",x); gsub(/</,"\\&lt;",x); gsub(/>/,"\\&gt;",x); return x }
  function scolor(c){ if(c=="p")return "#7d9c7a"; if(c=="f")return "#bf7a5e"; if(c=="w")return "#cfa96f"; return "#b9b0a4" }
  function slabel(c){ if(c=="p")return "pass"; if(c=="f")return "fail"; if(c=="w")return "warn"; return "skip" }
  BEGIN{
    ng=split("check_branch check_scope check_build check_sensitive check_consistency check_review check_reuse check_deps check_security check_layer check_stable_diff check_link_depth check_adr check_contract check_consistency_cross check_impact check_service check_api check_state check_frontend check_cognition check_domain check_knowledge check_mermaid check_shift_left check_framework check_compliance check_docs_pack check_sbom check_privacy check_authz check_requirements check_crypto check_test", order, " ")
    for(i=1;i<=ng;i++) ord[order[i]]=i
  }
  {
    line=$0; g=""; s=""; t=""
    if (match(line, /"gate":"[^"]+"/))   g=substr(line, RSTART+8,  RLENGTH-9)
    if (match(line, /"status":"[^"]+"/)) s=substr(line, RSTART+10, RLENGTH-11)
    if (g=="" || s=="") next
    if (match(line, /"ts":"[^"]+"/)) t=substr(line, RSTART+6, RLENGTH-7)
    d=0; if (match(line, /"duration_s":[0-9]+/)) d=substr(line, RSTART+13, RLENGTH-13)+0
    cnt[g]++; seq[g]=seq[g] substr(s,1,1); lastts[g]=t; lastst[g]=substr(s,1,1)
    dursum[g]+=d
    tot++
    s1=substr(s,1,1)
    if (s1=="p") tp++; else if (s1=="f") tf++; else if (s1=="w") tw++; else ts_++
    if (tmin=="" || (t!="" && t<tmin)) tmin=t
    if (t!="" && t>tmax) tmax=t
    if (s=="fail" && match(line, /"ids":\[[^]]*\]/)) {
      ids=substr(line, RSTART+7, RLENGTH-8)
      ni=split(ids, ia, ",")
      for(i=1;i<=ni;i++){
        id=ia[i]; gsub(/^"|"$/,"",id)
        if(id=="") continue
        key=g "\034" id
        fcnt[key]++
        if(t>flast[key]) flast[key]=t
      }
    }
  }
  function emit_gate(g,   total,start,win,m,p,f,w,k,i,c,cum,cum2,pv,x,y,pts,rate,trend,rw,ls,ll){
    cum2=0
    total=cnt[g]
    start=(total>n ? total-n+1 : 1)
    win=substr(seq[g], start)
    m=length(win); p=0; f=0; w=0; k=0; cum=0; pts=""
    for(i=1;i<=m;i++){ c=substr(win,i,1); if(c=="p")p++; else if(c=="f")f++; else if(c=="w")w++; else k++ }
    rate=(m>0 ? 100.0*p/m : 0)
    trend=win; gsub(/p/,"✓",trend); gsub(/f/,"✗",trend); gsub(/w/,"⚠",trend); gsub(/s/,"·",trend)
    ls=lastst[g]; ll=slabel(ls)
    printf "<section class=\"gate\">\n"
    printf "<h3><code>%s</code><span class=\"badge b-%s\">%s</span></h3>\n", esc(g), ll, ll
    printf "<p class=\"meta\">窗口样本 %d（全量 %d）｜pass %d · fail %d · warn %d · skip %d｜通过率 <strong>%.1f%%</strong>｜全量平均耗时 %.1fs｜末次 %s</p>\n", \
      m, total, p, f, w, k, rate, dursum[g]/total, esc(lastts[g])
    # SVG：上为窗口内累计通过率折线（带点，按状态着色），下为状态色块条
    printf "<svg viewBox=\"0 0 640 96\" width=\"640\" height=\"96\" role=\"img\" aria-label=\"%s 通过率趋势\">\n", esc(g)
    printf "<line x1=\"40\" y1=\"8\"  x2=\"630\" y2=\"8\"  class=\"grid\"/><line x1=\"40\" y1=\"36\" x2=\"630\" y2=\"36\" class=\"grid\"/><line x1=\"40\" y1=\"64\" x2=\"630\" y2=\"64\" class=\"grid\"/>\n"
    printf "<text x=\"4\" y=\"12\" class=\"axis\">100%%</text><text x=\"10\" y=\"40\" class=\"axis\">50%%</text><text x=\"12\" y=\"68\" class=\"axis\">0%%</text>\n"
    for(i=1;i<=m;i++){
      c=substr(win,i,1); if(c=="p") cum++
      pv=100.0*cum/i
      x=(m==1 ? 335 : 40+(i-1)*590.0/(m-1)); y=64-pv*0.56
      pts=pts sprintf("%.1f,%.1f ", x, y)
    }
    printf "<polyline points=\"%s\" class=\"line\"/>\n", pts
    for(i=1;i<=m;i++){
      c=substr(win,i,1); cum2+=(c=="p")
      pv=100.0*cum2/i
      x=(m==1 ? 335 : 40+(i-1)*590.0/(m-1)); y=64-pv*0.56
      printf "<circle cx=\"%.1f\" cy=\"%.1f\" r=\"3\" fill=\"%s\"><title>#%d %s</title></circle>\n", x, y, scolor(c), i, slabel(c)
    }
    rw=(m>0 ? 590.0/m : 0); if(rw>22) rw=22
    for(i=1;i<=m;i++){
      c=substr(win,i,1)
      x=(m==1 ? 335-rw/2 : 40+(i-1)*590.0/(m-1)-rw/2)
      printf "<rect x=\"%.1f\" y=\"74\" width=\"%.1f\" height=\"14\" rx=\"2\" fill=\"%s\"><title>#%d %s</title></rect>\n", x, rw, scolor(c), i, slabel(c)
    }
    printf "</svg>\n"
    printf "<p class=\"trend\">趋势(旧→新)：%s</p>\n", trend
    printf "</section>\n"
  }
  END{
    if(tot==0) exit 3
    ngates=0; for(g in cnt) ngates++
    printf "<section class=\"summary\">\n<h2>时间范围与总量</h2>\n<table>\n"
    printf "<tr><th>数据源</th><td><code>%s</code></td></tr>\n", esc(jsonl)
    printf "<tr><th>生成时间(UTC)</th><td>%s</td></tr>\n", gen_ts
    printf "<tr><th>记录时间范围(UTC)</th><td>%s ～ %s</td></tr>\n", esc(tmin), esc(tmax)
    printf "<tr><th>总记录数</th><td>%d（覆盖门禁 %d 个；窗口 近 %d 次/门禁）</td></tr>\n", tot, ngates, n
    printf "<tr><th>状态分布（全量）</th><td>pass %d · fail %d · warn %d · skip %d</td></tr>\n", tp, tf, tw, ts_
    printf "<tr><th>整体通过率（全量，pass/记录数）</th><td><strong>%.1f%%</strong></td></tr>\n", (tot>0 ? 100.0*tp/tot : 0)
    printf "</table>\n<p class=\"legend\">图例：<span class=\"chip\" style=\"background:#7d9c7a\"></span>pass <span class=\"chip\" style=\"background:#bf7a5e\"></span>fail <span class=\"chip\" style=\"background:#cfa96f\"></span>warn <span class=\"chip\" style=\"background:#b9b0a4\"></span>skip</p>\n</section>\n"
    printf "<h2 class=\"sec\">各门禁通过率（近 %d 次窗口；折线为窗口内累计通过率）</h2>\n", n
    for(i=1;i<=ng;i++){ g=order[i]; if(g in cnt) emit_gate(g) }
    for(g in cnt) if(!(g in ord)) emit_gate(g)
    for(k in fcnt){
      split(k, ka, "\034")
      printf "%d|%s|%s|%s\n", fcnt[k], flast[k], esc(ka[1]), esc(ka[2]) > topfile
    }
  }
' "$JSONL" > "${TMP_TOP}.body"
_rc=$?
if [[ $_rc -eq 3 ]]; then
  rm -f "${TMP_TOP}.body"
  echo "ℹ $JSONL 中无有效门禁记录（行格式须符合 precheck.sh gate-runs JSONL 契约）"
  exit 0
fi
[[ $_rc -eq 0 ]] || { rm -f "${TMP_TOP}.body"; echo "✗ HTML 数据聚合失败（awk 退出 ${_rc}）" >&2; exit 1; }

# 拼装：头（内联 CSS，低饱和暖色系）→ 主体 → fail TOP → 尾
{
cat <<'HEAD_EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>gate-runs 门禁通过率趋势报告</title>
<style>
  body{margin:0;padding:24px;background:#faf7f2;color:#5a4f45;font-family:-apple-system,"PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;line-height:1.6}
  main{max-width:760px;margin:0 auto}
  h1{font-size:22px;border-bottom:2px solid #e5ddd2;padding-bottom:8px}
  h2.sec{font-size:17px;margin-top:32px;border-bottom:1px solid #e5ddd2;padding-bottom:6px}
  section.summary,section.gate,section.failtop{background:#fffdf9;border:1px solid #e5ddd2;border-radius:10px;padding:16px 20px;margin:14px 0}
  section.gate h3{margin:0 0 4px;font-size:15px}
  table{border-collapse:collapse}
  th,td{text-align:left;padding:4px 14px 4px 0;vertical-align:top;font-size:14px}
  th{color:#8a7f72;font-weight:normal}
  code{background:#f3ede4;border-radius:4px;padding:1px 5px;font-size:13px}
  .meta,.trend,.legend{font-size:13px;color:#8a7f72;margin:6px 0}
  .badge{font-size:11px;border-radius:8px;padding:2px 8px;margin-left:8px;vertical-align:middle;color:#fffdf9}
  .b-pass{background:#7d9c7a}.b-fail{background:#bf7a5e}.b-warn{background:#cfa96f}.b-skip{background:#b9b0a4}
  .chip{display:inline-block;width:12px;height:12px;border-radius:3px;vertical-align:-1px;margin:0 4px 0 10px}
  svg{display:block;margin:8px 0;max-width:100%}
  .grid{stroke:#e8dfd3;stroke-width:1}
  .axis{font-size:10px;fill:#b0a493}
  .line{fill:none;stroke:#a3835f;stroke-width:2}
  ol{font-size:14px}
  li{margin:4px 0}
  .ok{color:#7d9c7a}
  footer{font-size:12px;color:#b0a493;margin-top:28px;text-align:center}
</style>
</head>
<body>
<main>
<h1>门禁通过率趋势报告（gate-runs）</h1>
HEAD_EOF
cat "${TMP_TOP}.body"
echo '<section class="failtop"><h2>最近 fail id TOP 10（全量统计）</h2>'
if [[ -s "$TMP_TOP" ]]; then
  echo '<ol>'
  sort -t'|' -k1,1rn -k2,2r "$TMP_TOP" | head -10 | while IFS='|' read -r _c _t _g _id; do
    printf '<li><code>%s</code> · <code>%s</code> —— %s 次，最近 %s</li>\n' "$_g" "$_id" "$_c" "$_t"
  done
  echo '</ol>'
else
  echo '<p class="ok">✓ 无 fail 记录</p>'
fi
echo '</section>'
cat <<'FOOT_EOF'
<footer>由 scripts/gate-trends.sh --html 生成 · 数据源 precheck.sh gate-runs.jsonl · 自包含 HTML（无外部依赖）</footer>
</main>
</body>
</html>
FOOT_EOF
} > "$HTML_OUT" || { rm -f "${TMP_TOP}.body"; echo "✗ HTML 写入失败：$HTML_OUT" >&2; exit 1; }
rm -f "${TMP_TOP}.body"

echo "✓ HTML 趋势报告已生成：${HTML_OUT}（数据源: ${JSONL}；窗口: 近 $N 次/门禁）"
exit 0

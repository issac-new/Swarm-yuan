#!/usr/bin/env bash
# 用法: verify-framework-ruleset.sh <ruleset_id>  —— 范式侧四要素机械核验
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ID="$1"
FN="_fw_$(echo "$ID" | tr '-' '_')_check"
RULE="$BASE/references/frameworks/$ID.md"
GATE="$BASE/assets/framework-gates/$ID.sh"
FAIL=0
err() { echo "✗ $1"; FAIL=1; }
ok()  { echo "✓ $1"; }

[[ -f "$RULE" ]] || { err "规则文件缺失: $RULE"; exit 1; }
[[ -f "$GATE" ]] || err "门禁片段缺失: $GATE"

# 要素2: §3 规律数 >= 深度门槛（frontmatter 声明，默认 10）
TH=$(sed -n 's/^深度门槛: *//p' "$RULE" | head -1); TH=${TH:-10}
CNT=$(grep -c '^### 规律' "$RULE")
[[ "$CNT" -ge "$TH" ]] && ok "规律数 $CNT >= 门槛 $TH" || err "规律数 $CNT < 门槛 $TH"

# 要素2b: 每条规律含 对应门禁 或 人工检查
# 简历：扫描每个"### 规律"小节体内是否出现 对应门禁/人工检查 关键字。
# 状态机式 awk（避免 BSD/GNU awk 的 E1,E2 range 在 E1 行即关闭区间造成漏检）：
#   - 命中 ^### 规律 → 计数 c++，进入该规律小节体内（insec=1）
#   - 命中 下一个 ^### 或 ^## → 退出小节（insec=0）
#   - 体内命中 对应门禁|人工检查 → 记 g[c]=1
NOGATE=$(awk '
  /^### 规律/ { c++; insec=1; next }
  /^###|^## / { insec=0; next }
  insec && /对应门禁|人工检查/ { g[c]=1 }
  END { n=0; for(i=1;i<=c;i++) if(!g[i]) n++; print n+0 }
' "$RULE")
[[ "$NOGATE" -eq 0 ]] && ok "全部规律挂门禁/人工检查" || err "$NOGATE 条规律未挂门禁"

# 要素3: §4 门禁 id ⊆ 片段 gates: 头注释，且函数存在
IDS=$(awk '/^## §4/,/^## §5/' "$RULE" | grep -oE 'fw_[a-z0-9_]+' | sort -u)
for gid in $IDS; do
  grep -q "$gid" "$GATE" || err "门禁 $gid 在 $GATE 中无实现痕迹"
done
[[ -f "$GATE" ]] && { grep -q "^${FN}()" "$GATE" && ok "函数 $FN 存在" || err "函数 $FN 不存在于 $GATE"; }

# 要素3b: 片段三平台兼容语法
bash -n "$GATE" 2>/dev/null && ok "片段语法 OK" || err "片段语法错误"
grep -q 'declare -A' "$GATE" && err "片段用了 declare -A（违反三平台铁律）"

# 要素4: fixture 双态（存在 fixtures 才核验）
FX="$BASE/tests/fixtures/$ID"
if [[ -d "${FX}/violating" && -d "${FX}/compliant" ]]; then
  bash "$BASE/tests/run-framework-fixture.sh" "$ID" >/dev/null 2>&1 \
    && ok "fixture 双态通过" || err "fixture 双态失败（运行 tests/run-framework-fixture.sh $ID 查看）"
else
  echo "⚠ 无 fixture（${FX}），跳过双态核验"
fi
[[ "$FAIL" -eq 0 ]] && echo "规则集 $ID 核验通过" || { echo "规则集 $ID 核验未通过"; exit 1; }

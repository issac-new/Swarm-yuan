#!/usr/bin/env bash
# test-r68-jargon-free.sh — 黑话清零防复发锁（R68/R69 标准术语纪律）
#
# 目标"消除黑话，必须使用标准术语"的机器执法：禁用自造词在用户面零出现。
# 禁用清单 = 已被标准术语替换的自造词；机器锚（文件名/变量名/占位词/【生成器侧】）不受此锁。
# 新增文档写作时若引入禁用词，本测试即红——防复发。
# R78 执法面扩容：assets/（随技能分发的模板/脚本/conf——目标技能侧用户直接可见）纳入扫描；
# 豁免边界（历史账本/维护者面，改写=篡改登记史，不用标准词替换）：
#   - assets/facts.conf —— 数字登记账本（各键值的历史成因链原文，等同 CHANGELOG 历史条目）
#   - scripts/（生成器侧，不分发）、tests/（锁定义自身含禁用词表）、CHANGELOG.md/docs/（历史档案）
set -u
cd "$(dirname "${0}")/.." || exit 1
pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }

# 禁用自造词清单（标准术语见 docs/usage-manual.md 术语词典）
BANNED="接线|机械执法|机械式|税制|弧线表|认知面|三件套|变异锁|悬置清单|能力地图|零占位符|双态夹具|流A|流B|随发|分派零落档|随发或声明|假绿|假红|失锚|空转|承载位"

hits=$(grep -rEn "$BANNED" SKILL.md README.md references/*.md 2>/dev/null | grep -v '原.*"' | head -10)
if [[ -z "$hits" ]]; then
  ok "用户面（SKILL.md/README/references/*.md）禁用自造词零出现"
else
  bad "禁用自造词残留（用标准术语）："
  printf '%s\n' "$hits"
fi

# R78：随发资产面（目标技能侧用户直接可见：模板/门禁脚本/conf/ontology/hooks）
asset_hits=$(grep -rEn "$BANNED" assets/ 2>/dev/null | grep -v 'facts\.conf' | grep -v '\.bak' | head -10)
if [[ -z "$asset_hits" ]]; then
  ok "随发资产面（assets/，facts.conf 登记账本豁免）禁用自造词零出现"
else
  bad "随发资产面禁用自造词残留（按 docs/usage-manual.md 术语词典替换）："
  printf '%s\n' "$asset_hits"
fi

# 机器锚必须在位（防误伤——改叙事不得动机器锚）
for anchor in '调用追踪' '方法论引用' '生成器侧' '待填充' '填充指引'; do
  cnt=$(grep -rl "$anchor" scripts/*.sh references/template-spec.md 2>/dev/null | wc -l | tr -d ' ')
  [[ "$cnt" -ge 1 ]] && ok "机器锚在位: ${anchor}" || bad "机器锚丢失: ${anchor}（误伤）"
done

# --- 终态纪律锁：历史包袱禁入用户面 ---
# 终态文档 = 干净完整的方案描述；过程历史归 docs/design-evolution.md（决策全文）、
# CHANGELOG.md（轮次账）与 docs/research/（调研档案）。禁类与豁免：
#   ① 裸轮次标记（R21/R83-D1 式）——豁免：docs/research/R\d+-<slug>.md 文件名锚、UNECE/UN 法规编号（本仓引用的全部法规号为 R155/R156，新增其他法规号时先扩 sed 豁免行）
#   ② 半步编号（⓪.5/①.5 式带圈数字加点）——生成流程唯一编号口径在 references/generation-flow.md（Step 1-12 含命名子阶段）
#   ③ 轮次簿记句（补核/薄轮不开档/watch 维持/轮次台账）
#   ④ 版本注记日期戳（"（YYYY-MM-DD 核）"式）——证据分级的"核验"日期（标准/URL 访问与复核日期）不在禁类
# 决策编号（决策 N）不在禁类：它是 README 附录 C 溯源表的引用机制，指向 design-evolution.md 决策全文。
# 上游项目版本/PR 证据锚（如 v1.91.8.0 #2994）与表格"来源版本"列不在禁类。
_terminal_scan="SKILL.md README.md references/*.md ../docs/usage-manual.md .claude/commands/swarm-yuan.md"

round_hits=$(grep -rEn '[[:<:]]R[0-9]+[[:>:]]' $_terminal_scan 2>/dev/null \
  | sed -E 's#R[0-9]+-[a-zA-Z0-9_.-]+\.md#文件名锚#g; s#(UN|UNECE) R[0-9]+#REG-EXEMPT#g; s#[[:<:]]R15[56][[:>:]]#REG-EXEMPT#g' \
  | grep -E '[[:<:]]R[0-9]+[[:>:]]')
if [[ -z "$round_hits" ]]; then
  ok "终态纪律①：用户面零裸轮次标记（文件名锚与 UN 法规号豁免）"
else
  bad "终态纪律①：裸轮次标记残留（历史归 design-evolution/CHANGELOG/docs/research）："
  printf '%s\n' "$round_hits" | head -5
fi

half_hits=$(grep -rEn '[⓪①②③④⑤⑥⑦⑧⑨]\.[0-9]' $_terminal_scan 2>/dev/null)
if [[ -z "$half_hits" ]]; then
  ok "终态纪律②：用户面零半步编号（编号唯一口径在 generation-flow.md）"
else
  bad "终态纪律②：半步编号残留："
  printf '%s\n' "$half_hits" | head -5
fi

ledger_hits=$(grep -rEn '补核|薄轮不开档|watch 维持|轮次台账' $_terminal_scan 2>/dev/null)
if [[ -z "$ledger_hits" ]]; then
  ok "终态纪律③：用户面零轮次簿记句"
else
  bad "终态纪律③：轮次簿记句残留："
  printf '%s\n' "$ledger_hits" | head -5
fi

stamp_hits=$(grep -rEn '[0-9] 核[，）]' $_terminal_scan 2>/dev/null)
if [[ -z "$stamp_hits" ]]; then
  ok "终态纪律④：用户面零版本注记日期戳（证据核验日期豁免）"
else
  bad "终态纪律④：版本注记日期戳残留："
  printf '%s\n' "$stamp_hits" | head -5
fi

echo "PASS test-r68-jargon-free (${pass} ok, ${fail} fail)"
[[ $fail -eq 0 ]]

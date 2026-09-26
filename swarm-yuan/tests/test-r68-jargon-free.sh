#!/usr/bin/env bash
# test-r68-jargon-free.sh — 黑话清零防复发锁（R68/R69 标准术语纪律）
#
# 目标"消除黑话，必须使用标准术语"的机器执法：禁用自造词在用户面零出现。
# 禁用清单 = 已被标准术语替换的自造词；机器锚（文件名/变量名/占位词/【生成器侧】）不受此锁。
# 新增文档写作时若引入禁用词，本测试即红——防复发。
set -u
cd "$(dirname "${0}")/.." || exit 1
pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }

# 禁用自造词清单（标准术语见 docs/usage-manual.md 术语词典）
BANNED="接线|机械执法|机械式|税制|弧线表|认知面|三件套|变异锁|悬置清单|能力地图|零占位符|双态夹具|流A|流B|随发|分派零落档|随发或声明"

hits=$(grep -rEn "$BANNED" SKILL.md README.md references/*.md 2>/dev/null | grep -v '原.*"' | head -10)
if [[ -z "$hits" ]]; then
  ok "用户面（SKILL.md/README/references/*.md）禁用自造词零出现"
else
  bad "禁用自造词残留（用标准术语）："
  printf '%s\n' "$hits"
fi

# 机器锚必须在位（防误伤——改叙事不得动机器锚）
for anchor in '调用追踪' '方法论引用' '生成器侧' '待填充' '填充指引'; do
  cnt=$(grep -rl "$anchor" scripts/*.sh references/template-spec.md 2>/dev/null | wc -l | tr -d ' ')
  [[ "$cnt" -ge 1 ]] && ok "机器锚在位: $anchor" || bad "机器锚丢失: ${anchor}（误伤）"
done

echo "PASS test-r68-jargon-free (${pass} ok, ${fail} fail)"
[[ $fail -eq 0 ]]

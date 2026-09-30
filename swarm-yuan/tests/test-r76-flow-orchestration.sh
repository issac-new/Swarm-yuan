#!/usr/bin/env bash
# test-r76-flow-orchestration.sh — R76 支付 Flow 编排吸收轮防复发锁
#
# 锁两件事：
# ① 吸收内容在位：domain-knowledge 流程编排节（通用十维）+ industry-profile-payment
#   §3.5（支付特化）——任一节被整段删除或关键锚漂移即红；
# ② 死信号防复发（R75-F1 同族）：流程引擎类框架无规则集（frameworks/ 无
#   temporal/liteflow/camunda 等文件），故 ACTIVE_FRAMEWORKS_HINT 不得提及它们——
#   HINT 指向不存在规则集的框架=依赖桶永不命中=门禁静默空转。
set -u
cd "$(dirname "${0}")/.." || exit 1
pass=0; fail=0
ok()  { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }

DK=references/domain-knowledge.md
PAY=references/industry-profile-payment.md
CONF=assets/industry-profiles/payment.conf

# ---- L1 domain-knowledge 流程编排节在位 ----
grep -qF '### 流程编排（长事务）' "$DK" && ok "L1 domain-knowledge 流程编排节标题在位" || bad "L1 流程编排节被删"
grep -qF '硬编码顺序调用→DB 状态字段→状态机（枚举+流转表）→流程引擎（节点+边）→持久执行' "$DK" \
  && ok "L1b 编排形态五级链在位" || bad "L1b 五级形态链漂移"

# ---- L2 通用十维关键锚 ----
for anchor in '时间缝隙' '逻辑割裂' '悬空状态' '断点恢复' 'Stripe atomic phases' '重放确定性'; do
  if sed -n '/### 流程编排（长事务）/,/### 构建\/DevOps/p' "$DK" | grep -qF "$anchor"; then
    ok "L2 锚在位: ${anchor}"
  else
    bad "L2 锚缺失: ${anchor}"
  fi
done

# ---- L3 payment §3.5 在位 + 支付特化锚 ----
grep -qF '### 3.5 流程编排：长事务链路的架构选型（pay-orchestrator 内核）' "$PAY" \
  && ok "L3 payment §3.5 标题在位" || bad "L3 §3.5 被删"
for anchor in '跨境 B2B 出款 12 步' '无引擎反模式四特征' '三大阵营选型' '确定性三红线' '自研轻量 Flow 六模块' '门禁联动'; do
  if sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY" | grep -qF "$anchor"; then
    ok "L3b 锚在位: ${anchor}"
  else
    bad "L3b 锚缺失: ${anchor}"
  fi
done

# ---- L4 相反决策案例与等效方案锚（选型方法论核心）----
sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY" | grep -qF 'Coinbase' \
  && ok "L4 Coinbase 案例在位" || bad "L4 Coinbase 案例缺失"
sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY" | grep -qF 'Netflix' \
  && ok "L4b Netflix 反向案例在位" || bad "L4b Netflix 反向案例缺失"
sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY" | grep -qF 'Transactional Outbox' \
  && ok "L4c Stripe 等效方案 outbox 在位" || bad "L4c outbox 等效方案缺失"

# ---- L5 交叉引用双向在位（防单边删除留悬空指针）----
sed -n '/### 流程编排（长事务）/,/### 构建\/DevOps/p' "$DK" | grep -qF 'industry-profile-payment.md` §3.5' \
  && ok "L5 DK→PAY 交叉引用在位" || bad "L5 DK→PAY 引用断"
sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY" | grep -qF 'domain-knowledge.md` 流程编排节' \
  && ok "L5b PAY→DK 交叉引用在位" || bad "L5b PAY→DK 引用断"

# ---- L6 吸收来源 URL 锚（可溯源性）----
grep -qF 'https://mp.weixin.qq.com/s/t2_QpE-DmJ4HKFicDvsCPA' "$PAY" \
  && ok "L6 吸收来源 URL 在位" || bad "L6 来源 URL 丢失"

# ---- L7 §5-① 差额项细化三查在位 ----
grep -qF '补偿单一来源核查、悬空状态出口核查' "$PAY" \
  && ok "L7 §5-① 三查细化在位" || bad "L7 差额项细化漂移"

# ---- L8 死信号防复发（R75-F1 同族）：HINT 不得指向无规则集的框架 ----
# 前提核验：流程引擎类框架确实无规则集（若未来补建 temporal.md 规则集，本锁自动转向——
# 届时 HINT 可加，需同步改本测试）
_ENGINE_SETS=$(ls references/frameworks/ 2>/dev/null | grep -cE '^(temporal|liteflow|camunda|flowable|activiti|conductor)\.md$' || true)
_hint=$(grep -F 'ACTIVE_FRAMEWORKS_HINT=' "$CONF" 2>/dev/null | head -1)
if [[ "$_ENGINE_SETS" -eq 0 ]]; then
  if printf '%s' "$_hint" | grep -qE 'temporal|liteflow|camunda|flowable|activiti|conductor'; then
    bad "L8 HINT 引用无规则集框架（死信号，R75-F1 同族）：$_hint"
  else
    ok "L8 HINT 无流程引擎死信号"
  fi
else
  if printf '%s' "$_hint" | grep -qE 'temporal|liteflow|camunda|flowable|activiti|conductor'; then
    ok "L8 流程引擎规则集已建（${_ENGINE_SETS} 个），HINT 引用合规"
  else
    ok "L8 规则集已建但 HINT 未引用（可加，非违规）"
  fi
fi

# ---- L9 禁用词不因吸收新增（r68 清单子集：本节高风险词）----
_dk_sec=$(sed -n '/### 流程编排（长事务）/,/### 构建\/DevOps/p' "$DK")
_pay_sec=$(sed -n '/### 3.5 流程编排/,/## 4\. 条款/p' "$PAY")
for w in '接线' '三件套' '随发' '假绿' '空转'; do
  if printf '%s\n%s' "$_dk_sec" "$_pay_sec" | grep -qF "$w"; then
    bad "L9 禁用词出现: ${w}"
  else
    ok "L9 禁用词未出现: ${w}"
  fi
done

echo "—— r76 防复发锁：$pass 通过 / $fail 失败 ——"
[[ $fail -eq 0 ]] || exit 1

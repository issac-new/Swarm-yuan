# Swarm-yuan 范式减重（P0-P3）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans（本计划由主会话 inline 执行，用户已明确指令"完成 P0-P3 全部实施"）。Steps 使用 checkbox 追踪。

**Goal:** 将 swarm-yuan 从"默认全量 + 无逃逸舱 + 账面不诚实 + 无成本遥测"改造为"三档 profile + 27+9 诚实门禁 + draft 断点续传 + 成本遥测"，不改变三层运行时接线和沉睡门禁原则。

**Architecture:** 全部改动落在 `swarm-yuan/` 范式目录内：precheck.sh 门禁分桶与跳过诚实化、generate-skill.sh profile/draft 状态机、precheck.conf 物理三分、新增 cost-report.sh、文档数字一致性收口、CI 调整（Windows 降频 + 新增门禁套件验证）。

**Tech Stack:** bash 3.2 兼容（禁 `declare -A`、`sed -i.bak+rm`、`grep -E`、`date -u` 双兼容、`$(cd+pwd)` 替代 `readlink -f`）、GitHub Actions、现有 fixture 双态测试体系（tests/gate-fixtures 36 组 + tests/fixtures 61 框架）。

## Global Constraints

- **bash 3.2 兼容铁律**：不用 `declare -A`；`sed -i.bak && rm`；`grep -E`；`date -u`；`wc|xargs`；`${var}` 防 C-locale（全库 $var+CJK 崩溃教训，commit 78813e5）。
- **三平台兼容**：ubuntu/macos/windows CI 全绿；新脚本进 shellcheck 层。
- **非破坏披露原则**：门禁输出行只增不改语义（fixture expect-output 逐字节断言）；汇总行格式变化须同步改 fixture。
- **沉睡门禁原则**：不唤醒已知 `\|` 字面 bug 的 4 处 warn-only 门禁（docs/paradigm-decisions.md）。
- **零占位符铁律演化**：从"全局零占位符"演化为"profile 范围内零占位符 + status 状态门"（WP-H 正式废止决策档断点续传否决，理由记录在 paradigm-decisions.md 增补）。
- **数字单一事实源**：SKILL.md/README/USAGE/self-check.sh check_doc_consistency 的门禁数/变量数必须同步改（self-check.sh:556-574 有机器断言）。
- 每个 WP 结束跑：`bash -n` 改动脚本 + 相关 fixture 组 + commit。

## 事实锚点（探查结论，实施时以这些行号为准）

- precheck.sh：SILENT 判定 L340-342；skip_if_unconfigured L368-379；门禁注册表 L381-390；_usage L393-397；_gate_exec L642-687；check_cognition L2461-2733（0 个 fail()，大量裸 `echo "    ⚠"`）；shellcheck 锚点块 L3835-3844；MODE case 分发 L3846-3891；汇总行 L3893-3895；_emit_json L628-640；conf 加载 L143-305；头注释用法 L4-22。
- generate-skill.sh：UNIVERSAL_FILES L42-69；merge_precheck_conf L105-156；inject_frameworks conf 路径 L172/L288；verify_completeness L327-391（拦截 L393-397）；MODE 解析 L453-465；copy_universal_templates L480-518；已存在拦截 L622；骨架 here-doc L626-733（SKILL.md frontmatter L712-716）。
- ci.yml：触发 L3-7（无 schedule/dispatch）；windows-compat job L249-306；shellcheck 严格层 L188-200；self-check job L150-165。
- self-check.sh：fw_freshness_check L462-494（180/365 阈值已存在）；check_doc_consistency L542+、数字断言 L556-574。
- tests：run-gate-fixture.sh group→flag 映射 L22-31（summary→--all-full 特例）；summary/compliant fixture 断言输出含「执行汇总/跳过/调用/fail/warn」。
- offline-cache：git 索引仅 UPSTREAM.md；根 .gitignore L30-31 注释与 swarm-yuan/.gitignore 矛盾（whl/tgz 声称跟踪，实际已迁 Release）。

---

## WP-A：合规 9 门禁拆出 --all-full → --compliance-suite（P0-1）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（L340-342、L381-397、L3835-3844、L3846-3854、L4-22）
- Modify: `swarm-yuan/tests/gate-fixtures/summary/compliant/expect-output`（如汇总行不变则不动）
- Docs: `swarm-yuan/SKILL.md`、`swarm-yuan/README.md`、`swarm-yuan/docs/USAGE.md`、`swarm-yuan/references/standards-compliance.md`、`swarm-yuan/scripts/self-check.sh`（数字断言）

**Interfaces:**
- Produces: `--compliance-suite` MODE（与 --all/--all-full 平级，循环 ALL_GATES_COMPLIANCE，SILENT=1）；`--all-full` 语义变为核心 10+架构 17=27 门禁；`--fix-suggest` 保持跑全量 36（ALL_GATES_FULL 保留）。

- [ ] **Step 1: 注册表改造**（precheck.sh L381-390）

在 `ALL_GATES_COMPLIANCE` 之后插入 `ALL_GATES_STANDARD`（27 项 = FULL 去掉 9 合规），`ALL_GATES_FULL` 保留原 36 项供 --fix-suggest：

```bash
# 标准门禁（核心 10 + 架构 17 = 27）：--all-full 执行序列（WP-A：合规 9 拆出为 --compliance-suite）
ALL_GATES_STANDARD=(check_branch check_scope check_build check_sensitive check_consistency check_review check_reuse check_deps check_security check_layer check_stable_diff check_link_depth check_adr check_contract check_consistency_cross check_impact check_service check_api check_state check_frontend check_cognition check_domain check_knowledge check_mermaid check_shift_left check_framework check_test)
```

- [ ] **Step 2: SILENT 与 case 分发**

L342 改为：
```bash
[[ "$MODE" == "--all-full" || "$MODE" == "--compliance-suite" ]] && SILENT=1
```
case 中 `--all-full)` 分支循环改为 `ALL_GATES_STANDARD`；新增：
```bash
  --compliance-suite)
    # WP-A：合规 9 门禁独立套件（强监管交付场景按需执行；未配置的静默跳过）
    for _gate in "${ALL_GATES_COMPLIANCE[@]}"; do _gate_exec "$_gate" 1; done
    ;;
```
`_usage()` Usage 行加 `|--compliance-suite`。头注释 L4-22 加一行用法说明。

- [ ] **Step 3: 验证**

```bash
bash -n swarm-yuan/assets/precheck.sh
cd /tmp && mkdir -p wp-a-test/docs && cd wp-a-test
# 用最小 conf 跑三种模式，确认 --all-full 输出不含 check_compliance 等 9 个，--compliance-suite 只跑 9 个
bash tests/run-gate-fixture.sh summary   # 期望 PASS（fixture 断言行未变）
bash tests/run-gate-fixture.sh compliance
```
预期：`--all-full` 汇总行「调用 27」量级；`--compliance-suite` 汇总「调用 9」；summary fixture 仍 PASS。

- [ ] **Step 4: 文档数字收口**

SKILL.md：`36 个门禁（核心 10 + 架构 17 + 合规 9…随 --all-full 执行）` → `27 门禁随 --all-full 执行（核心 10 + 架构 17），合规 9 门禁独立为 --compliance-suite 按需执行`；description 同步。README/USAGE/standards-compliance/self-check.sh check_doc_consistency 的门禁数断言同步（27+9 表述）。

- [ ] **Step 5: Commit**
```bash
git add -A && git commit -m "feat(gates): WP-A 合规 9 门禁拆出 --all-full 为 --compliance-suite——账面 36 诚实化为 27+9"
```

---

## WP-B：check_cognition 诚实化（P0-2）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（L2461-2733）
- Docs: `docs/paradigm-decisions.md`（增补决策 12）

**Interfaces:**
- Consumes: 无。**决策**：不实装 fail 阈值（尊重作者"刻意不重设计"决策），做三点诚实化：①入口明示 warn-only 性质；②裸 echo ⚠ 统一为 warn()（计数+受 SILENT 控制）；③死变量 COGNITION_MAP 接入（配置且文件存在时纳入④映射检查输入，否则行为不变）。

- [ ] **Step 1: 函数开头加性质声明**（check_cognition 函数体第一行后插入）
```bash
  echo "  ℹ check_cognition：认知体检报告（warn-only，永不 fail，不计入门禁否决）"
```
- [ ] **Step 2: 裸 `echo "    ⚠` 全部替换为 `warn "`**（sed 范围内替换 + 逐个人工核对上下文缩进）；纯信息性 echo（无 ⚠）不动。
- [ ] **Step 3: COGNITION_MAP 接入**：④映射检查段（L2528-2568）开头加：
```bash
  if [[ -n "${COGNITION_MAP:-}" && -f "${COGNITION_MAP}" ]]; then
    pass "COGNITION_MAP 已配置：${COGNITION_MAP}（纳入映射检查）"
  fi
```
（_default_conf 补 `COGNITION_MAP=""` 声明，消除 doctor ③死变量误报。）
- [ ] **Step 4: 验证**：`bash tests/run-gate-fixture.sh cognition` PASS；`bash -n` 通过。
- [ ] **Step 5: paradigm-decisions.md 增补「决策 12：check_cognition 诚实化（不实装 fail）」**，记录理由。
- [ ] **Step 6: Commit** `fix(gates): WP-B check_cognition 诚实化——warn-only 性质明示 + 裸 echo 统一 warn() + COGNITION_MAP 接入`

---

## WP-C：trace 降级为节点级 + verbose 开关（P0-3）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（trace_tool L703-716、9 处第三方 trace_tool 调用点）
- Modify: `swarm-yuan/assets/state-machine.sh`（trace_tool L33-40、L167）
- Docs: `swarm-yuan/SKILL.md`（L61/73/90/150）、`swarm-yuan/.claude/commands/swarm-yuan.md` L88、`swarm-yuan/references/template-spec.md`（L171/193/205）、`swarm-yuan/references/ai-process-records.md`（L72-89）、`swarm-yuan/docs/USAGE.md`（L232/244）

**Interfaces:**
- Produces: `trace_tool` 第三参数（可选）`level`：`node`（默认，总是落盘）| `verbose`（仅 `SWARM_YUAN_TRACE=verbose` 时落盘+输出）。precheck.sh 9 处第三方工具调用全部改为 verbose 级；_gate_exec 门禁级保持 node 级。指令文本铁律改为「节点级落盘为默认；调用级细节设 SWARM_YUAN_TRACE=verbose」。

- [ ] **Step 1: trace_tool 升级**（precheck.sh L703-716 与 state-machine.sh L33-40 同步改）
```bash
# trace_tool <名称> [详情] [node|verbose]：节点级默认落盘；verbose 级仅 SWARM_YUAN_TRACE=verbose 时落盘
trace_tool() {
  local level="${3:-node}"
  [[ "$level" == "verbose" && "${SWARM_YUAN_TRACE:-}" != "verbose" ]] && return 0
  ...原逻辑...
}
```
- [ ] **Step 2: 9 处第三方调用点加第三参 `verbose`**（L940/954/960/980/1011/1297/1311/2058/2831/3448）；state-machine.sh L167 同。
- [ ] **Step 3: 指令文本改造**：SKILL.md ★调用追踪铁律段——「每次具体调用落盘」改为「每节点落盘为默认（stdout 公告 + trace.jsonl）；第三方工具调用级细节默认不落盘，设 `SWARM_YUAN_TRACE=verbose` 恢复全量」。template-spec §2 第⑨要素表述同步（workflow.md 的「调用追踪」要素要求不变——机器执法不动）。USAGE.md/ai-process-records.md/commands/swarm-yuan.md 同步。
- [ ] **Step 4: 验证**：
```bash
bash -n swarm-yuan/assets/precheck.sh swarm-yuan/assets/state-machine.sh
bash tests/run-gate-fixture.sh review   # 覆盖 trace_tool 调用路径
SWARM_YUAN_TRACE=verbose bash tests/run-gate-fixture.sh review
```
- [ ] **Step 5: Commit** `feat(trace): WP-C trace 分级——节点级默认落盘，SWARM_YUAN_TRACE=verbose 恢复调用级`

---

## WP-D：cost-report.sh 成本遥测（P0-4）

**Files:**
- Create: `swarm-yuan/scripts/cost-report.sh`
- Modify: `swarm-yuan/scripts/generate-skill.sh`（UNIVERSAL_FILES 加 `"scripts/cost-report.sh|gen"`）
- Modify: `.github/workflows/ci.yml`（shellcheck 严格层加 scripts/cost-report.sh）
- Docs: `swarm-yuan/docs/USAGE.md`

**Interfaces:**
- Produces: `bash scripts/cost-report.sh [--dir <项目根>] [--stdout]`——读 `<项目根>/.swarm-yuan/trace.jsonl`（trace-log.sh L52-54 格式：`ts/node/actor/tool/status/note`），输出：时间跨度、总调用数、按 node/actor/tool 聚合计数、status=fail 计数、gate-runs（若 `.swarm-yuan/gate-runs.jsonl` 存在则汇总门禁 fail/warn 趋势）。默认写 `.swarm-yuan/cost-report.md` 并 stdout 摘要；`--stdout` 只打印。trace.jsonl 不存在时打印「无追踪数据」exit 0（fail-open）。

- [ ] **Step 1: 写脚本**（bash 3.2：聚合用 `sort | uniq -c`，禁 declare -A）：
```bash
#!/usr/bin/env bash
# cost-report.sh — 全链路追踪成本遥测（WP-D）
# 数据源：.swarm-yuan/trace.jsonl（trace-log.sh 落盘）+ gate-runs.jsonl（precheck --format json 证据）
# 用法: bash cost-report.sh [--dir <项目根>] [--stdout]
set -euo pipefail
DIR=""; STDOUT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:?}"; shift 2 ;;
    --stdout) STDOUT=1; shift ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done
DIR="${DIR:-$(pwd)}"
TRACE="$DIR/.swarm-yuan/trace.jsonl"
OUT="$DIR/.swarm-yuan/cost-report.md"
if [[ ! -f "$TRACE" ]]; then echo "无追踪数据: $TRACE 不存在（trace-log.sh 落盘后才有数据）"; exit 0; fi
_total=$(wc -l < "$TRACE" | tr -d ' ')
_first=$(head -1 "$TRACE" | sed -E 's/.*"ts":"([^"]+)".*/\1/')
_last=$(tail -1 "$TRACE" | sed -E 's/.*"ts":"([^"]+)".*/\1/')
_fails=$(grep -c '"status":"fail"' "$TRACE" 2>/dev/null || echo 0)
_top() { # $1=字段名
  sed -E "s/.*\"$1\":\"([^\"]*)\".*/\1/" "$TRACE" | sort | uniq -c | sort -rn | head -10
}
{
  echo "# 成本遥测报告（cost-report.sh）"
  echo "- 数据: $TRACE"
  echo "- 时间跨度: $_first → $_last"
  echo "- 总调用数: $_total（fail: $_fails）"
  echo ""; echo "## 按节点"; _top node
  echo ""; echo "## 按执行者"; _top actor
  echo ""; echo "## 按工具"; _top tool
} > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
cat "$OUT"
[[ $STDOUT -eq 0 ]] && echo "→ 已写入 $OUT"
```
- [ ] **Step 2: 接入骨架**（generate-skill.sh UNIVERSAL_FILES 加条目）+ ci.yml shellcheck 严格层加 `swarm-yuan/scripts/cost-report.sh`。
- [ ] **Step 3: 验证**：在本仓库跑 `bash swarm-yuan/scripts/cost-report.sh --dir . --stdout`（.swarm-yuan/trace.jsonl 已存在）→ 输出聚合表 exit 0；空目录跑 → 「无追踪数据」exit 0。`shellcheck` 零新增告警。
- [ ] **Step 4: USAGE.md 加「成本遥测」小节**（何时看：评估生成/使用成本；verbose 数据更全）。
- [ ] **Step 5: Commit** `feat(cost): WP-D cost-report.sh——trace.jsonl 聚合为成本遥测报告，接入骨架与 CI`

---

## WP-E：三档 profile（lite/standard/compliance）（P1-5）

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`（L42-69 UNIVERSAL_FILES 加 profile 段、L453-465 参数解析、L480-518 过滤、L622-733 骨架条件化）
- Docs: `swarm-yuan/SKILL.md`（生成流程+使用说明）、`swarm-yuan/docs/USAGE.md`

**Interfaces:**
- Produces: `--profile lite|standard|compliance`（默认 standard）。档序 lite<standard<compliance。UNIVERSAL_FILES 条目加第三段 `|<min-profile>`（缺省=standard 语义调整为：无标记=lite 也拷——**具体标记方案**：`security-spec.md/spec-template/plan-template/precheck.sh/precheck.conf/trace-log.sh/state-machine.sh/self-check.sh` 标 `lite`；`standards-compliance.md` 标 `compliance`；其余标 `standard`）。lite 骨架：只建 `{references,assets,scripts}` 三目录（跳过 hooks/commands/settings/.mcp.json）；占位 reference 只生成 `reference-manual.md`；SKILL.md frontmatter 加 `profile: <档>`；checklist 按档裁剪（lite 无 workflow/commands 条目）。upgrade 时从既有 SKILL.md frontmatter 读 profile 保持一致。

- [ ] **Step 1: UNIVERSAL_FILES 加 profile 段**（每条 `"<dest>|<src>|<min-profile>"`，无第三段视为 standard 保持兼容——升级既有技能不受影响）。
- [ ] **Step 2: 参数解析**：L454 之后插 while 循环消费 `--profile <档>`（校验取值，非法 exit 1），`PROFILE` 变量。
- [ ] **Step 3: copy_universal_templates 过滤**：rank 函数 `lite=1 standard=2 compliance=3`，`rank(条目标记) > rank($PROFILE)` 则 skip。
- [ ] **Step 4: 骨架条件化**：L626 目录创建按档；L639-644 占位循环 lite 只留 reference-manual.md；L646-710 hooks/settings/.mcp/commands 四段包 `[[ "$PROFILE" != "lite" ]]`；SKILL.md here-doc frontmatter 加 `profile: $PROFILE` 行；checklist 按档。
- [ ] **Step 5: upgrade 读档**：upgrade 分支从 `$SKILL_DIR/SKILL.md` grep `^profile: ` 取档（缺省 standard），覆盖 $PROFILE。
- [ ] **Step 6: 验证**：
```bash
cd /tmp && bash $REPO/swarm-yuan/scripts/generate-skill.sh --profile lite demo-lite /tmp/wp-a-test
find demo-lite -type f   # 断言：无 hooks/ commands/ settings.local.json .mcp.json；无 workflow.md 占位
bash $REPO/swarm-yuan/scripts/generate-skill.sh --profile compliance demo-comp /tmp/wp-a-test
find demo-comp -name standards-compliance.md  # 存在
bash $REPO/swarm-yuan/scripts/generate-skill.sh demo-std /tmp/wp-a-test  # 默认 standard
```
- [ ] **Step 7: 文档**：SKILL.md 生成流程段加 profile 说明 + 「零占位符铁律适用范围 = 当前 profile 的文件集」；USAGE.md 加三档对照表。
- [ ] **Step 8: Commit** `feat(profile): WP-E 三档 profile——lite/standard/compliance 骨架裁剪，零占位符铁律收敛为档内适用`

---

## WP-F：SKIPPED 诚实化收口（P1-6）

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（skip_if_unconfigured L368-379、汇总行 L3893-3895、_emit_json L628-640）

**Interfaces:**
- Produces: 非静默跳过打印 `  ⊘ SKIPPED（未配置）: <原因>`（**不进** WARN_COUNT——跳过≠警告）；汇总行后追加：SKIP_COUNT>0 时打印 `—— 注意：N 个门禁未配置跳过，「通过」≠ 合规全覆盖——`；JSON 输出加 `"skipped": [...]` 数组。

- [ ] **Step 1: skip_if_unconfigured 改造**——SILENT=0 分支 `warn "$1"` 改为 `echo "  ⊘ SKIPPED（未配置）: $1"`（去掉 WARN_COUNT 虚增）。
- [ ] **Step 2: 汇总行后加披露段**（L3895 后）：
```bash
if [[ $SKIP_COUNT -gt 0 ]]; then
  echo "—— 注意：${SKIP_COUNT} 个门禁未配置跳过（${SKIP_LIST# }），「通过」≠ 全量覆盖——"
fi
```
- [ ] **Step 3: _emit_json 加 skipped 数组**（读 L628-640 现有结构后追加字段）。
- [ ] **Step 4: 验证**：先 grep fixtures 断言 `⚠` 跳过输出的 expect-output 文件（`grep -rl '未启用\|未配置' swarm-yuan/tests/gate-fixtures/*/​*/expect-output`），同步改断言；`bash tests/run-gate-fixture.sh` 全量 36 组 PASS。
- [ ] **Step 5: Commit** `feat(gates): WP-F SKIPPED 诚实化——跳过单列不计 warn，「绿≠全覆盖」显式披露`

---

## WP-G：特征卡 P0/P1 分级（P2-7）

**Files:**
- Modify: `swarm-yuan/references/exploration-guide.md`（L1029-1303）
- Modify: `swarm-yuan/references/template-spec.md`（L216-233 映射表、L503-505+ 核对清单）
- Modify: `swarm-yuan/SKILL.md`（Step 12 计数核验表述）

**Interfaces:**
- Produces: P0 六项 = {1 项目类型, 4 技术栈摘要, 5 构建发布命令, 11 可复用稳定单元, 15 编排调用关系及约束, 16 详尽构件库清单}；P1 十项 = {2,3,6,7,8,9,10,12,13,14}。**规则**：P0 全覆盖+计数核验（≥95%）= 生成完成的强制门槛；P1 可在 status: draft 期间以「（P1 待补）」占位（不触发 verify 的「待填充」命中——该字符串不在四模式内），转 active（WP-H）前必须填实。

- [ ] **Step 1: exploration-guide.md 16 项逐项加 `（P0）`/`（P1·可增量）` 标注** + §C+ 计数核验段加「仅 P0 维度强制」。
- [ ] **Step 2: template-spec.md 映射表加 P0/P1 列**；核对清单改为「P0 六项全覆盖（缺一=未完成）；P1 十项 draft 期可（P1 待补），--mark-active 前清零」。
- [ ] **Step 3: SKILL.md Step 12 表述同步**。
- [ ] **Step 4: 验证**：`grep -c '（P0）' swarm-yuan/references/exploration-guide.md` = 6；self-check doc consistency 通过。
- [ ] **Step 5: Commit** `feat(card): WP-G 特征卡 P0/P1 分级——P0 六项强制+计数核验，P1 十项可增量`

---

## WP-H：draft 断点续传 + 状态门（P2-8）

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`（L622 拦截、L327-391 verify、L712-716 frontmatter、新增 --mark-active）
- Modify: `swarm-yuan/assets/precheck.sh`（draft 守卫：MODE 判定后）
- Docs: `docs/paradigm-decisions.md`（决策 13：正式废止断点续传否决）、SKILL.md 生成流程

**Interfaces:**
- Produces: ①骨架 SKILL.md frontmatter 含 `status: draft`；②`--mark-active <skill_dir>`：verify_completeness 通过 + P0 齐备 → 翻 `status: active`；③已存在且 status: draft 的 SKILL_DIR 不再报「已存在」而是续跑（幂等补齐缺失文件，不覆盖已有内容文件）；④precheck.sh 守卫：脚本自身所属 skill（`$_CONF_DIR/../SKILL.md`）status: draft 时，`--all-full`/`--compliance-suite` 拒绝执行（exit 2 + 提示 --mark-active），单门禁与 --all 不受影响；⑤verify_completeness 对 draft skill 命中占位符时降级为报告模式（打印清单 + 末尾「draft 状态：允许残留，--mark-active 前须清零」，exit 0），active skill 保持 exit 1。

- [ ] **Step 1: frontmatter 加 `status: draft`**（generate-skill.sh L715 后）。
- [ ] **Step 2: L622 拦截改造**：
```bash
if [[ -d "$SKILL_DIR" ]]; then
  if grep -q '^status: draft' "$SKILL_DIR/SKILL.md" 2>/dev/null; then
    echo "→ draft 状态骨架检测到，断点续传（幂等补齐，不覆盖已有文件）"
    RESUME=1
  else
    echo "ERROR: 已存在: ${SKILL_DIR}（用 --upgrade 升级）"; exit 1
  fi
fi
```
copy_universal_templates 加第三参 `$RESUME`：续跑时 `[[ -f "$dst" ]] && continue`；占位 here-doc 段落包 `[[ -f ... ]] || cat > ...`。
- [ ] **Step 3: --mark-active 子命令**（拦截链加分支，模式同 --verify-completeness）：读 status，draft→跑 verify_completeness（严格模式）→通过则 sed 翻 active（`sed -i.bak 's/^status: draft/status: active/' && rm`），失败 exit 1。
- [ ] **Step 4: verify_completeness draft 降级**：函数开头读 `$skill_dir/SKILL.md` 的 status，draft 时命中清单照打但 return 0 + 提示行。
- [ ] **Step 5: precheck.sh draft 守卫**（conf 加载后、case 分发前）：
```bash
_skill_md="$_CONF_DIR/../SKILL.md"
if [[ -f "$_skill_md" ]] && grep -q '^status: draft' "$_skill_md"; then
  case "$MODE" in
    --all-full|--compliance-suite)
      echo "✗ 所属 skill 为 draft 状态（骨架未完成），--all-full/--compliance-suite 已禁用" >&2
      echo "  完成填充后运行: bash generate-skill.sh --mark-active <skill_dir>" >&2
      exit 2 ;;
  esac
fi
```
- [ ] **Step 6: 验证**：/tmp 生成 lite 骨架 → 直接跑其 scripts/precheck.sh --all-full → exit 2；--all → 正常；--mark-active 在占位符未清时 fail；手工清占位后 --mark-active 成功 → --all-full 放行。再次运行 create 同名 → 续跑提示不报错。
- [ ] **Step 7: paradigm-decisions.md 增补决策 13**（状态门替代一次性铁律：draft 产物不可交付门禁全量，与"中途停在骨架"的本质区别是机器可识别、门禁有守卫）；SKILL.md 生成流程加「中断安全」说明。
- [ ] **Step 8: Commit** `feat(draft): WP-H draft 断点续传+状态门——骨架可中断续跑，draft 态禁用全量门禁`

---

## WP-I：precheck.conf 物理三分（P2-9）

**Files:**
- Modify: `swarm-yuan/assets/precheck.conf` → 拆为 `precheck.conf`（core）+ `precheck.arch.conf` + `precheck.compliance.conf`（同目录 assets/）
- Modify: `swarm-yuan/assets/precheck.sh`（conf 加载 L263-305、doctor 死变量扫描 L488-519）
- Modify: `swarm-yuan/scripts/generate-skill.sh`（UNIVERSAL_FILES、L487 upgrade 跳过、merge_precheck_conf L108、inject_frameworks L172/L288、verify 检查目标 L337）
- Modify: `swarm-yuan/scripts/self-check.sh`（conf 变量数断言）

**Interfaces:**
- Consumes: WP-E 的 profile 段（lite 只拷 core conf）。Produces: 三分组——core=L5-14 基础 + L296-302 工具化；arch=L16-253 DDD/契约/微服务/前端/认知/左移/框架适配；compliance=L255-294 标准合规/安全深化/长期清单。core conf 末尾按存在性 source 两个兄弟（`BASH_SOURCE` 定位，被 precheck.sh set +u 包裹天然安全）。框架变量追加（inject_frameworks）落 arch conf。变量总数 179 不变（self-check 断言口径=三文件合计）。

- [ ] **Step 1: 物理拆分**（按 L5-302 分组注释切，保留全部注释与变量原顺序）；core conf 末尾：
```bash
# ---- profile 分层（WP-I）：兄弟配置存在即加载（lite 档只有本文件）----
_conf_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$_conf_self_dir/precheck.arch.conf" ]] && source "$_conf_self_dir/precheck.arch.conf"
[[ -f "$_conf_self_dir/precheck.compliance.conf" ]] && source "$_conf_self_dir/precheck.compliance.conf"
```
- [ ] **Step 2: precheck.sh loader**：L263-290 保持只 source 主 conf（兄弟由主 conf 自加载）；doctor ③死变量扫描改为 `cat precheck.conf precheck.arch.conf precheck.compliance.conf`（存在才拼）；L291-305 数组兜底不变。
- [ ] **Step 3: generate-skill.sh**：UNIVERSAL_FILES 加两条（arch 标 standard、compliance 标 compliance；core 标 lite）；upgrade 跳过判断从单名改三名单；merge_precheck_conf / inject_frameworks 变量追加落 `precheck.arch.conf`；verify L337 检查目标改主 conf。
- [ ] **Step 4: self-check.sh conf 变量数断言口径改三文件合计**。
- [ ] **Step 5: 验证**：`bash -n` 三 conf；本仓库 ci/self-precheck.conf 单文件跑 `precheck.sh --all`（generator-self-gate 等价路径）PASS；`bash tests/run-gate-fixture.sh` 全量 PASS（fixture conf 单文件不受影响）；骨架 create standard → 三文件齐备且 --doctor 零死变量。
- [ ] **Step 6: Commit** `feat(conf): WP-I precheck.conf 物理三分——core/arch/compliance 按 profile 加载，扁平 key=value 不变`

---

## WP-J：offline-cache 治理收口（P2-10）

**Files:**
- Modify: `.gitignore`（L30-31 矛盾注释重写）
- Create: `swarm-yuan/scripts/fetch-offline-cache.sh`
- Docs: `swarm-yuan/README.md`（L270 附近）、`docs/paradigm-decisions.md`（增补说明）

**Interfaces:**
- 事实基础：git 索引已只剩 UPSTREAM.md，196MB 全是本地 ignored；本 WP 是表述与工具收口。Produces: `fetch-offline-cache.sh`——从 GitHub Release v2026.07.20-offline 下载 `swarm-yuan-offline-cache.zip`（URL 与 install-offline-win.sh L18 一致）解压到 `swarm-yuan/offline-cache/`，已存在则跳过，无网络 exit 1 带手工指引。

- [ ] **Step 1: 根 .gitignore L30-31 注释重写**（删除"故意纳入 git 跟踪"旧表述，指向 swarm-yuan/.gitignore 治理说明与 Release 迁移事实）。
- [ ] **Step 2: fetch-offline-cache.sh**（curl -fSL → unzip -o → 清理；bash 3.2）。
- [ ] **Step 3: 文档**：README offline 段落加 fetch 脚本用法；paradigm-decisions.md 增补一行说明（治理收口，非新决策）。
- [ ] **Step 4: 验证**：`bash -n`；`bash fetch-offline-cache.sh --help` 形态正确（不实际下载 196MB）。
- [ ] **Step 5: Commit** `chore(cache): WP-J offline-cache 治理收口——gitignore 矛盾注释修正 + Release 拉取脚本`

---

## WP-K：框架规则集 freshness + fixture 分级（P3-11）

**Files:**
- Modify: `swarm-yuan/scripts/verify-framework-ruleset.sh`（新增要素 5 freshness + fixture 分级）
- Docs: `swarm-yuan/references/domain-knowledge.md`（规则集扩展方式段，fixture 政策）

**Interfaces:**
- Produces: ①要素5：解析 frontmatter `最后调研:` 日期（macOS/GNU date 双兼容，同 self-check.sh L474-481 模式），>365 天 warn「规则集过期，建议重核」（**warn 不 fail**——时间流逝不应破坏构建；`--strict-freshness` 可选 fail-closed）；②fixture 双态分级：内置 CORE_RULESETS 10 个（spring-boot mybatis react vue gin kafka mysql django fastapi nextjs——实施时核实存在性，不存在则换现存热门集），核心集缺 fixture=fail，非核心缺 fixture=warn「建议补 fixture」。当前 61 全有 fixture，行为不回归。

- [ ] **Step 1: verify-framework-ruleset.sh 加要素5 + 分级逻辑**。
- [ ] **Step 2: domain-knowledge.md 扩展方式段补 fixture 政策说明**（核心 10 强制、其余建议）。
- [ ] **Step 3: 验证**：61 规则集全跑 verify 全绿；临时构造一个 400 天前日期的副本规则集验证 warn 出现。
- [ ] **Step 4: Commit** `feat(ruleset): WP-K 规则集 freshness 检查 + fixture 双态核心集分级`

---

## WP-L：Windows CI 降频（P3-12）

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: 触发加 `schedule: cron '17 2 * * 1'`（每周一 UTC 02:17）+ `workflow_dispatch`；windows-compat job（L249-306 全量四步）加 `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'`；新增轻量 `windows-syntax` job（push/PR 常跑：仅 bash -n 核心脚本 + 61 片段 + .bat 冒烟，即原步骤 1+4）。

- [ ] **Step 1: ci.yml 改造**（触发器 + if 条件 + 拆 windows-syntax job）。
- [ ] **Step 2: 验证**：`python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` 语法合法；逐 job 核对 if 条件。
- [ ] **Step 3: Commit** `ci(windows): WP-L Windows 全量兼容降频为周跑+手动，PR 保留语法面+批处理冒烟`

---

## WP-M：全局一致性收口 + 终验

**Files:** 全部文档数字/表述（SKILL.md、README.md、USAGE.md、template-spec.md、standards-compliance.md、FIVE_DIMENSIONS.md、CLAUDE.md、PROMO.md）+ `docs/paradigm-decisions.md` 增补汇总

- [ ] **Step 1: 数字grep收口**：`grep -rn '36 个门禁\|36 门禁\|179 个变量\|179 变量' swarm-yuan/ CLAUDE.md --include='*.md'` 逐一核对为 27+9 / 179（三文件合计）新表述。
- [ ] **Step 2: 全量测试**：`bash tests/run-gate-fixture.sh`（36 组）+ `for f in tests/fixtures/*/; do bash tests/run-framework-fixture.sh $(basename $f); done`（61）+ `bash tests/e2e/run-e2e.sh` + `bash scripts/self-check.sh` 全绿。
- [ ] **Step 3: generator-self-gate 本地等价复跑**（ci/self-precheck.conf + sed __REPO_ROOT__ + --all）。
- [ ] **Step 4: 三 profile e2e**：lite/standard/compliance 各生成骨架 → draft 守卫 → --mark-active 流程全通。
- [ ] **Step 5: Commit** `docs(consistency): WP-M P0-P3 全局一致性收口——数字/表述/决策记录对齐`

---

## Self-Review 记录

- **Spec 覆盖**：P0(4)→WP-A/B/C/D ✓；P1(2)→WP-E/F ✓；P2(4)→WP-G/H/I/J ✓；P3(2)→WP-K/L ✓；一致性→WP-M ✓。
- **与原方案偏差**：①P0-2 采纳"诚实化"而非"实装 fail"（尊重作者刻意决策，decisions 增补记录）；②P2-10 事实修正：offline-cache git 索引仅 8KB，改造为表述+fetch 工具而非索引手术；③P3-11 采纳"机制建设"（当前无过期规则集可降级，contrib/ 物理降级延后到有实例时）。
- **类型一致性**：trace_tool 第三参 `level` 在 precheck.sh/state-machine.sh 两处同步；profile 三档取值 lite|standard|compliance 全 WP 统一；status 取值 draft|active 全 WP 统一；conf 三文件名 precheck.conf/precheck.arch.conf/precheck.compliance.conf 全 WP 统一。

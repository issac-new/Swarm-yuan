#!/usr/bin/env bash
# run-gen-e2e.sh — WP-B 生成产物 e2e 回归
# 用法: bash tests/e2e/run-gen-e2e.sh
#
# 目的：verifier 现有 e2e 只测 --inject-frameworks 注入链路（生成器自身行为），
# 本脚本测 generate-skill.sh create 模式的「生成产物」质量——断言骨架文件清单完整、
# hooks/JSON 合法、workflow.md 8 节点、precheck.conf 含真实嗅探值、commands/spec.md 含任务类型映射。
#
# 不断言零占位符：create 产物的 4 个 reference 文件（codebase/dev-guide/release/reference-manual）
# 设计即为「（待填充）」占位骨架，等 AI 填充；本脚本只断言「稳定可断言的部分」（骨架/JSON/嗅探值）。
set -uo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
PARADIGM="$(cd "${BASE}/.." && pwd)"   # swarm-yuan 范式根（含 scripts/generate-skill.sh）
DEMO="${BASE}/e2e/java-demo"            # 固定样本项目（4 文件 Maven）
TMP="$(mktemp -d /tmp/gene2e.XXXXXX)"
trap 'rm -rf "${TMP}"' EXIT

FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

echo "▶ GEN-E2E: generate-skill.sh create 产物质量回归（样本=java-demo）"

# --- 1. create 模式生成 standard profile 骨架到临时目录 ---
# java-demo 文件数<80 会被 auto 判为 lite（无 hooks/commands），显式 --profile standard 测完整产物
SKILL_DIR="${TMP}/.claude/skills/javatest"
bash "${PARADIGM}/scripts/generate-skill.sh" --profile standard javatest "${DEMO}" "${TMP}/.claude/skills" >/tmp/gene2e-create.log 2>&1
rc_create=$?
[[ $rc_create -eq 0 ]] && ok "generate-skill.sh create 成功（profile=standard）" || { bad "generate-skill.sh create 失败 rc=${rc_create}（见 /tmp/gene2e-create.log）"; cat /tmp/gene2e-create.log >&2; exit 1; }

# --- 2. 骨架文件清单完整（PROJECT_SPECIFIC + hooks + commands + UNIVERSAL 抽样）---
for f in \
  "SKILL.md" \
  "references/workflow.md" "references/codebase.md" "references/dev-guide.md" \
  "references/release.md" "references/reference-manual.md" \
  "hooks/hooks.json" "settings.local.json" ".mcp.json" \
  "commands/spec.md" "commands/precheck.md" "commands/explore.md" \
  "scripts/precheck.sh" "scripts/gates-strict.sh" "scripts/gates-warn.sh" "scripts/gates-advisory.sh" \
  "scripts/precheck.conf" "scripts/precheck.arch.conf" \
  "assets/spec-template.md" "assets/task-type-gates.conf" \
  "assets/hooks/failure-detector.sh" "assets/hooks/integrity-guard.sh" \
  "assets/hooks/fail-gate-hook.sh"
do
  [[ -f "${SKILL_DIR}/${f}" ]] && ok "骨架文件存在: ${f}" || bad "骨架文件缺失: ${f}"
done

# WP-Enforce1：fail-gate-hook 挂接双事件 + conf 白名单默认空（捕获门随产物附带）
grep -q 'fail-gate-hook' "${SKILL_DIR}/hooks/hooks.json" 2>/dev/null \
  && ok "hooks.json 挂接 fail-gate-hook.sh" || bad "hooks.json 未挂接 fail-gate-hook.sh"
grep -q '^GATE_ENFORCE_DENY=""' "${SKILL_DIR}/scripts/precheck.conf" 2>/dev/null \
  && ok "precheck.conf 含 GATE_ENFORCE_DENY 默认空（捕获门默认关闭，向后兼容）" \
  || bad "precheck.conf 缺 GATE_ENFORCE_DENY 默认空行"
# WP-R2-3：GATE_AI_JUDGMENT 入 conf 模板（Q2H-A 开关可发现性——此前只在 gates-advisory.sh 内部，用户无从发现）
grep -q '^GATE_AI_JUDGMENT=' "${SKILL_DIR}/scripts/precheck.conf" 2>/dev/null \
  && ok "precheck.conf 含 GATE_AI_JUDGMENT（AI 自觉判断开关可发现）" \
  || bad "precheck.conf 缺 GATE_AI_JUDGMENT 行"

# --- 3. hooks.json / settings.local.json / .mcp.json 是合法 JSON ---
for jf in "hooks/hooks.json" "settings.local.json" ".mcp.json"; do
  if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "${SKILL_DIR}/${jf}" >/dev/null 2>&1 && ok "合法 JSON: ${jf}" || bad "非法 JSON: ${jf}"
  else
    ok "JSON 校验跳过（无 python3）: ${jf}"
  fi
done

# --- 4. workflow.md 含 8 个节点标题 + 每节点含「调用追踪」要素 ---
wf="${SKILL_DIR}/references/workflow.md"
node_cnt=$(grep -c '^## 节点' "${wf}" 2>/dev/null || echo 0)
[[ "${node_cnt}" -eq 8 ]] && ok "workflow.md 含 8 个节点标题" || bad "workflow.md 节点数=${node_cnt}（期望 8）"
trace_cnt=$(grep -c '调用追踪' "${wf}" 2>/dev/null || echo 0)
[[ "${trace_cnt}" -ge 8 ]] && ok "workflow.md 含调用追踪要素（${trace_cnt} 处）" || bad "workflow.md 调用追踪要素不足（${trace_cnt} 处，期望≥8）"

# --- 5. precheck.conf/arch.conf 含 ACTIVE_FRAMEWORKS 非空 + 嗅探到的框架（detect-frameworks.sh 真值）+ AUTO:detected 注释 ---
# 注：ACTIVE_FRAMEWORKS 渲染到 precheck.arch.conf（架构门禁配置），非 precheck.conf（核心 10 门禁）。
# detect-frameworks.sh 对 java-demo pom.xml 探出 spring-boot/sharding/lombok——
# 但 conf-render.sh 对 pom.xml 解析较保守，可能只探出部分（如只 lombok），因 detect-frameworks.sh
# 行式 grep 对紧凑 XML 依赖名匹配有局限。此处断言 ACTIVE_FRAMEWORKS 非空 + 至少一个 AUTO:detected 框架，
# 不锁死具体框架名（嗅探深度是 detect-frameworks.sh 的实现细节，非生成器契约）。
af_conf="${SKILL_DIR}/scripts/precheck.arch.conf"
grep -q '^ACTIVE_FRAMEWORKS=(' "${af_conf}" && ok "precheck.arch.conf 含 ACTIVE_FRAMEWORKS 行" || bad "precheck.arch.conf 缺 ACTIVE_FRAMEWORKS 行"
af_line=$(grep '^ACTIVE_FRAMEWORKS=' "${af_conf}" 2>/dev/null || true)
# 非空断言：ACTIVE_FRAMEWORKS=( 不是空数组
[[ "${af_line}" == *"()"* ]] && bad "ACTIVE_FRAMEWORKS 为空数组（嗅探失败）" || ok "ACTIVE_FRAMEWORKS 非空: ${af_line}"
grep -q '# AUTO:detected' "${af_conf}" && ok "precheck.arch.conf 含 # AUTO:detected 溯源注释" || bad "precheck.arch.conf 缺 # AUTO:detected 注释"
# 核心 conf 也应有 PROJECT_DIR + BUILD_CMD（嗅探所得）
core_conf="${SKILL_DIR}/scripts/precheck.conf"
grep -q '^PROJECT_DIR=' "${core_conf}" && ok "precheck.conf 含 PROJECT_DIR 行" || bad "precheck.conf 缺 PROJECT_DIR 行"
grep -q '^BUILD_CMD=' "${core_conf}" && ok "precheck.conf 含 BUILD_CMD 行（mvn package）" || bad "precheck.conf 缺 BUILD_CMD 行"

# --- 6. commands/spec.md 含 7 类任务类型→门禁映射 ---
spec_cmd="${SKILL_DIR}/commands/spec.md"
for tt in feature fix refactor chore docs test exp; do
  grep -q "${tt}" "${spec_cmd}" && ok "commands/spec.md 含任务类型: ${tt}" || bad "commands/spec.md 缺任务类型: ${tt}"
done

# --- 7. 产物 SKILL.md frontmatter status: draft ---
grep -q '^status: draft' "${SKILL_DIR}/SKILL.md" && ok "产物 SKILL.md status: draft" || bad "产物 SKILL.md 非 draft 状态"

# --- 7.5 WP-R2-2：产物 SKILL.md 含「自成长」固定指引段 + hooks.json 指引指向目标侧真实脚本 ---
grep -q '## 自成长（项目变了，本技能跟着变）' "${SKILL_DIR}/SKILL.md" \
  && ok "产物 SKILL.md 含自成长段" || bad "产物 SKILL.md 缺自成长段"
grep -q 'project-fingerprint.sh' "${SKILL_DIR}/SKILL.md" \
  && ok "自成长段含感知命令（project-fingerprint.sh）" || bad "自成长段缺感知命令"
# SessionStart hook 的指引必须指向目标技能侧存在的脚本（generate-skill.sh 是生成器侧，不在产物里）
if grep -q 'scripts/generate-skill.sh' "${SKILL_DIR}/hooks/hooks.json" 2>/dev/null; then
  bad "hooks.json SessionStart 仍指向目标侧不存在的 scripts/generate-skill.sh"
else
  ok "hooks.json SessionStart 指引不引用生成器侧脚本"
fi

# --- 8. 产物 precheck.sh 自身可跑 --all（draft 骨架空 conf 不应崩）---
# 注：产物 precheck.sh 的 conf 是嗅探初稿，部分语义型变量=()，--all 应 fail-open 不崩
# fail-open 语义：rc=0（pass）或 rc=1（有门禁 fail 属正常）；rc>1（如 126/127/段错误）= 真崩
rc_all=0
( cd "${SKILL_DIR}" && bash scripts/precheck.sh --all >/tmp/gene2e-precheck.log 2>&1 ) || rc_all=$?
if [[ $rc_all -le 1 ]]; then
  ok "产物 precheck.sh --all 可执行（rc=${rc_all}，fail-open 语义正常）"
else
  bad "产物 precheck.sh --all 真崩（rc=${rc_all} > 1，见 /tmp/gene2e-precheck.log）"
fi

# --- 9. 产物可被 --inject-frameworks 注入（与现有 e2e inject 链路一致，验证产物可后续注入）---
bash "${PARADIGM}/scripts/generate-skill.sh" --inject-frameworks "${SKILL_DIR}" >/tmp/gene2e-inject.log 2>&1
rc_inject=$?
[[ $rc_inject -eq 0 ]] && ok "产物可被 --inject-frameworks 注入（幂等）" || bad "产物 --inject-frameworks 失败 rc=${rc_inject}（见 /tmp/gene2e-inject.log）"

# --- 10. lite / compliance 两档 create 冒烟（四轮复盘补盲区）---
# 背景：上面 1-9 段用 --profile standard（java-demo <80 文件会被 auto 判 lite），
# 导致 lite/compliance 两档的 create 路径长期零覆盖——四轮复盘在该盲区发现真 bug：
# chmod +x "$dir/assets/"*.sh 在 lite 档 glob 无匹配 → set -e 中断 → 产物残缺不可用。
# 本段对两档各跑一次 create，断言 rc=0 + 骨架关键文件存在（lite 无 workflow/commands 属设计，不断言）。
for _prof in lite compliance; do
  _pdir="${TMP}/prof-${_prof}"
  mkdir -p "${_pdir}"
  if bash "${PARADIGM}/scripts/generate-skill.sh" --profile "${_prof}" "p-${_prof}" "${DEMO}" "${_pdir}" \
       >"/tmp/gene2e-prof-${_prof}.log" 2>&1; then
    ok "${_prof} 档 create rc=0"
  else
    bad "${_prof} 档 create 失败（见 /tmp/gene2e-prof-${_prof}.log）"
    continue
  fi
  # 三档共有的骨架核心：SKILL.md + scripts/precheck.sh（lite 也必须有，否则门禁不可用）
  for _pf in SKILL.md scripts/precheck.sh; do
    if [[ -f "${_pdir}/p-${_prof}/${_pf}" ]]; then
      ok "${_prof} 档产物含 ${_pf}"
    else
      bad "${_prof} 档产物缺 ${_pf}（骨架残缺）"
    fi
  done
  # R13 批次3（§4.5.4 适配性差异化断言）：lite 档无 hooks.json（无 hooks 生命周期），
  # compliance 档有 hooks.json 且含 industry 注入接线（conf-render --industry 独立冒烟见下）
  if [[ "${_prof}" == "lite" ]]; then
    [[ ! -f "${_pdir}/p-${_prof}/hooks/hooks.json" ]]       && ok "lite 档无 hooks.json（差异化正确）" || bad "lite 档含 hooks.json（差异化错误）"
  else
    [[ -f "${_pdir}/p-${_prof}/hooks/hooks.json" ]]       && ok "${_prof} 档有 hooks.json" || bad "${_prof} 档缺 hooks.json"
  fi
done

# --- 10.5 R13 批次3：industry profile 加载冒烟（conf-render --industry 真实接线）---
_indir="${TMP}/industry-out"
mkdir -p "${_indir}"
if bash "${PARADIGM}/scripts/conf-render.sh" "${DEMO}" --profile compliance --industry finance --out "${_indir}"      >/tmp/gene2e-industry.log 2>&1; then
  [[ -f "${_indir}/precheck.industry.conf" ]]     && ok "industry profile 渲染出 precheck.industry.conf" || bad "industry conf 未生成"
  grep -q 'precheck.industry.conf' "${_indir}/precheck.conf"     && ok "precheck.conf 挂 industry source 链" || bad "precheck.conf 缺 industry source 链"
else
  bad "conf-render --industry 失败（见 /tmp/gene2e-industry.log）"
fi

# --- 11. --upgrade 路径回归（五轮复盘补盲区）---
# 背景：--upgrade 是用户长期使用的升级路径（覆盖通用模板/保留项目特定文件），
# 但两个 e2e 都不覆盖它——二轮复盘即指出该盲区。本段固化「升级不吃掉用户改动」这一核心契约：
# create → 加 3 类用户改动（填充内容/自定义 conf 变量/自定义文件）→ upgrade → 断言三者都还在。
# 另测跨档升级（lite→standard 应补齐文件，文档承诺的升档路径）。
_updir="${TMP}/upgrade-test"
mkdir -p "${_updir}"
if bash "${PARADIGM}/scripts/generate-skill.sh" --profile standard u-dev "${DEMO}" "${_updir}" \
     >/tmp/gene2e-up-create.log 2>&1; then
  _uskill="${_updir}/u-dev"
  # 模拟用户改动三类
  echo "# USER-CONTENT-MARKER" >> "${_uskill}/SKILL.md"
  echo 'USER_CUSTOM_VAR="keep-me"' >> "${_uskill}/scripts/precheck.conf"
  echo "user note" > "${_uskill}/references/user-custom.md"
  if bash "${PARADIGM}/scripts/generate-skill.sh" --upgrade u-dev "${DEMO}" "${_updir}" \
       >/tmp/gene2e-up.log 2>&1; then
    ok "--upgrade rc=0"
    grep -q 'USER-CONTENT-MARKER' "${_uskill}/SKILL.md" 2>/dev/null \
      && ok "--upgrade 保留 SKILL.md 用户填充内容" \
      || bad "--upgrade 吃掉了 SKILL.md 用户内容（升级不应覆盖已填充产物）"
    grep -q 'USER_CUSTOM_VAR' "${_uskill}/scripts/precheck.conf" 2>/dev/null \
      && ok "--upgrade 保留 precheck.conf 用户变量" \
      || bad "--upgrade 吃掉了 precheck.conf 用户变量（conf 是项目特定文件，应保留）"
    [[ -f "${_uskill}/references/user-custom.md" ]] \
      && ok "--upgrade 保留用户自定义文件" \
      || bad "--upgrade 删除了用户自定义文件"
  else
    bad "--upgrade 失败（见 /tmp/gene2e-up.log）"
  fi
else
  bad "upgrade 前置 create 失败（见 /tmp/gene2e-up-create.log）"
fi

# --- 11b. upgrade 门禁注入触发回归（第 17 轮复盘补盲区）---
# 背景（BUG-1，2026-08-15 回归发现）：upgrade 的注入触发曾只 grep 主 precheck.conf，
# 而 ACTIVE_FRAMEWORKS 物理上定义在 precheck.arch.conf（WP-I 三分）——standard/compliance
# 档 upgrade 从不触发门禁注入（区块空/sha 无/快照无），且"已重置 sha 由重注入写入"
# 的提示照打印（误导）。本段固化核心契约：arch.conf 配了 ACTIVE_FRAMEWORKS 的 skill，
# upgrade 后门禁区块必须真的重建 + 记账 + 快照（三件套齐全才算注入发生）。
# 反向验证构造：create 后模拟 AI Step 5 在 arch.conf 写 ACTIVE_FRAMEWORKS（非主 conf）。
echo 'ACTIVE_FRAMEWORKS=("spring-boot")' >> "${_uskill}/scripts/precheck.arch.conf"
if bash "${PARADIGM}/scripts/generate-skill.sh" --upgrade u-dev "${DEMO}" "${_updir}" \
     >/tmp/gene2e-up-inject.log 2>&1; then
  grep -q '_fw_spring_boot_check()' "${_uskill}/scripts/precheck.sh" 2>/dev/null \
    && ok "upgrade 触发门禁注入（arch.conf 的 ACTIVE_FRAMEWORKS 被识别）" \
    || bad "upgrade 未注入门禁区块（BUG-1 回归：arch.conf 触发判定失效）"
  grep -q '^framework_gates_sha=' "${_uskill}/.swarm-yuan-version" 2>/dev/null \
    && ok "upgrade 注入后写入 framework_gates_sha 记账" \
    || bad "upgrade 注入后无 sha 记账"
  ls "${_uskill}/.swarm-yuan/effects/"*/precheck.sh >/dev/null 2>&1 \
    && ok "upgrade 注入前产生快照（.swarm-yuan/effects/）" \
    || bad "upgrade 注入无快照（F4 契约：注入必可回滚）"
else
  bad "upgrade（注入段）失败（见 /tmp/gene2e-up-inject.log）"
fi

# 跨档升级：lite → standard 应补齐文件（文档承诺的升档路径）
_xdir="${TMP}/cross-test"
mkdir -p "${_xdir}"
if bash "${PARADIGM}/scripts/generate-skill.sh" --profile lite x-dev "${DEMO}" "${_xdir}" \
     >/tmp/gene2e-x-lite.log 2>&1; then
  _n_lite=$(find "${_xdir}/x-dev" -type f | wc -l | tr -d ' ')
  if bash "${PARADIGM}/scripts/generate-skill.sh" --upgrade --profile standard x-dev "${DEMO}" "${_xdir}" \
       >/tmp/gene2e-x-std.log 2>&1; then
    _n_std=$(find "${_xdir}/x-dev" -type f | wc -l | tr -d ' ')
    if [[ "${_n_std}" -gt "${_n_lite}" ]]; then
      ok "跨档升级 lite→standard 补齐文件（${_n_lite}→${_n_std}）"
    else
      bad "跨档升级未补齐文件（lite ${_n_lite} → standard ${_n_std}，应增加）"
    fi
  else
    bad "跨档升级 lite→standard 失败（见 /tmp/gene2e-x-std.log）"
  fi
else
  bad "跨档升级前置 lite create 失败"
fi

# --- 12. --mark-active 闭环（九轮复盘：E2E 主路径 Step ⑧ 死锁回归锁）---
# 背景：verify_completeness 的 - [ ] 扫描原未排除 ``` 代码块——gsd-patterns.md /
# cognitive-bias.md 这两个 UNIVERSAL_FILES 模板里的 ```markdown 示例被误判为待清零占位符，
# 导致 --mark-active 永远拒绝，所有 standard/compliance 档产物卡在 draft（E2E 主路径断裂）。
# 本段锁的是"填充完整 → --mark-active 必须成功"这一 E2E 闭环。
# 反向验证：修复前本段必然失败（死锁），修复后通过。
_mdir="${TMP}/mark-active-test"
mkdir -p "${_mdir}"
if bash "${PARADIGM}/scripts/generate-skill.sh" --profile standard m-dev "${DEMO}" "${_mdir}" \
     >/tmp/gene2e-ma-create.log 2>&1; then
  _mskill="${_mdir}/m-dev"
  # 模拟 AI Step ④：填充占位符（reference/SKILL.md/workflow.md/decisions.jsonl）
  # 4 个待填充 reference 用最小真实内容覆盖
  for rf in codebase dev-guide release reference-manual; do
    printf '# %s.md\n真实内容（E2E 填充样本）\n' "$rf" > "${_mskill}/references/${rf}.md"
  done
  # SKILL.md 的 description/标题占位符替换 + 删填充指引段
  sed -i.bak -e 's|（填充指引：触发条件 + 项目关键词）|m-dev 开发技能（E2E 样本）|' \
             -e 's|（填充指引：项目名 + 需求交付全流程技能）|m-dev 需求交付技能|' \
             "${_mskill}/SKILL.md" && rm -f "${_mskill}/SKILL.md.bak"
  # 删 SKILL.md 的"## 填充指引"整段（到下一个 ## 或 EOF）
  awk '/^## 填充指引/{skip=1; next} /^## /{skip=0} !skip' "${_mskill}/SKILL.md" > "${_mskill}/SKILL.md.tmp" \
    && mv "${_mskill}/SKILL.md.tmp" "${_mskill}/SKILL.md"
  # workflow.md 删填充指引注释（> 开头的两行）
  grep -v '^> 填充指引\|^> 节点名对齐\|（流程图，标注' "${_mskill}/references/workflow.md" > "${_mskill}/references/workflow.md.tmp" \
    && mv "${_mskill}/references/workflow.md.tmp" "${_mskill}/references/workflow.md"
  # decisions.jsonl 填 1 条（--mark-active 须 ≥1 条，SKILL.md 契约）
  mkdir -p "${_mskill}/.swarm-yuan"
  printf '{"type":"Taste","decision":"E2E 样本决策","ts":"2026-08-04T00:00:00Z"}\n' > "${_mskill}/.swarm-yuan/decisions.jsonl"
  # Step ⑧：--mark-active 必须成功（死锁修复后 gsd/cognitive-bias 的代码块示例不再误伤）
  if bash "${PARADIGM}/scripts/generate-skill.sh" --mark-active "${_mskill}" >/tmp/gene2e-ma.log 2>&1; then
    ok "--mark-active 成功（E2E Step ⑧ 闭环，代码块示例未误伤）"
    grep -q '^status: active' "${_mskill}/SKILL.md" 2>/dev/null \
      && ok "status 已翻 active" \
      || bad "--mark-active 声称成功但 status 未翻 active"
  else
    bad "--mark-active 失败（E2E 死锁回归；见 /tmp/gene2e-ma.log）"
  fi
else
  bad "mark-active 前置 create 失败（见 /tmp/gene2e-ma-create.log）"
fi

# --- 结果 ---
if [[ $FAIL -eq 0 ]]; then
  echo "GEN_E2E_RC 0"
  echo "GEN-E2E OK：生成产物质量回归通过"
  exit 0
else
  echo "GEN_E2E_RC 1"
  echo "GEN-E2E FAIL：生成产物质量回归未通过（见上方 ✗）"
  exit 1
fi

# G7：兼容层诚实化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` syntax.

**Goal:** 把"7 工具兼容"诚实化为三档显式声明（runnable/cli/deep），tool-adapters TA_TIER 机器可读元数据，README/install.sh/generate-skill.sh 表述与实现对齐。

**Architecture:** tool-adapters/common.sh 新增 TA_TIER 元数据 + ta_tier_of 查询；7 适配器头部加 TA_TIER 声明；README 加三档表；install.sh 输出按档位 + 死重标注；self-check 新增 check_compat_tier 对账。

**Tech Stack:** Bash 3.2 兼容 + Markdown。

**Spec:** `docs/superpowers/specs/2026-07-22-g7-compat-honesty-design.md`

## Global Constraints

- bash 3.2 兼容（无 `declare -A`，TA_TIER 用间接展开 eval）
- 不触碰 install.sh 复制逻辑（C 档骨架裁剪留验证稳定后）
- commit 风格：`feat(g7):`

---

### Task 1: tool-adapters TA_TIER 元数据 + facts.conf

**Files:**
- Modify: `swarm-yuan/assets/tool-adapters/common.sh`
- Modify: `swarm-yuan/assets/tool-adapters/{claude,cursor,windsurf,codex,opencode,gemini,kimi}.sh`（头部注释）
- Modify: `swarm-yuan/assets/facts.conf`

- [ ] **Step 1: common.sh 新增 TA_TIER 元数据 + ta_tier_of**

在 common.sh 调度器段前新增：

```bash
# G7：AI 工具兼容三档机器可读元数据
# runnable（目录复制）/ cli（+规则派生）/ deep（+hooks/commands/MCP）
TA_TIER_claude=deep
TA_TIER_cursor=cli
TA_TIER_windsurf=cli
TA_TIER_codex=cli
TA_TIER_opencode=cli
TA_TIER_gemini=cli
TA_TIER_kimi=cli

# 按工具查 tier（bash 3.2 兼容：间接展开，不用 declare -A）；未声明默认 runnable
ta_tier_of() {
  local tool="$1"
  eval "echo \"\${TA_TIER_${tool}:-runnable}\""
}
```

- [ ] **Step 2: 7 适配器头部加 TA_TIER 声明注释**

每个适配器文件头部注释追加一行（claude 改原 no-op 注释）：
- `claude.sh`：`# TA_TIER=deep（hooks/commands/MCP 深度集成，no-op 因已深度集成）`
- 其余 6 个：`# TA_TIER=cli（目录复制 + --render-tools 规则派生）`

- [ ] **Step 3: facts.conf 新增口径**

```bash

# ===== AI 工具兼容三档（G7）=====
FACT_COMPAT_TIERS=3    # runnable / cli / deep
FACT_COMPAT_DEEP=1     # Claude Code
FACT_COMPAT_CLI=6      # Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi
```

- [ ] **Step 4: 语法检查 + ta_tier_of 单元验证**

Run:
```bash
bash -n swarm-yuan/assets/tool-adapters/common.sh
bash -c 'source swarm-yuan/assets/tool-adapters/common.sh; for t in claude cursor windsurf codex opencode gemini kimi; do echo "$t=$(ta_tier_of $t)"; done'
```
Expected: claude=deep，其余=cli

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/assets/tool-adapters/ swarm-yuan/assets/facts.conf
git commit -m "feat(g7): tool-adapters TA_TIER 三档元数据 + facts.conf 口径

- common.sh 新增 TA_TIER_<tool> 声明 + ta_tier_of 查询（bash 3.2 间接展开）
- 7 适配器头部加 TA_TIER 声明（claude=deep，其余=cli）
- facts.conf 新增 FACT_COMPAT_TIERS=3/DEEP=1/CLI=6"
```

---

### Task 2: README 三档表 + install.sh 输出按档位 + 死重标注

**Files:**
- Modify: `README.md`
- Modify: `swarm-yuan/install.sh`

- [ ] **Step 1: README 加三档表**

在 README"11 个运行时"三层接线表（L224-234）附近，平行新增"AI 工具兼容三档"表：

```markdown
## AI 工具兼容三档（诚实分层，不假装全深接）

| 档 | 名称 | 能力 | 工具 |
|---|------|------|------|
| runnable | 可运行 | 目录复制（该工具自身加载 skills 目录约定） | 全部 7 个 |
| cli | 集成 | runnable + `--render-tools` 派生原生规则（.mdc/.windsurf/AGENTS.md/GEMINI.md） | Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi（6 个） |
| deep | 深度集成 | cli + slash command 注册 + hooks/commands/MCP | Claude Code（1 个） |

> 非 Claude 工具的骨架中 hooks/commands 目录为 deep 档专属，cli 档不消费（死重，不影响功能）。
```

并更新 L173/L310 的"7 个"表述指向三档表。

- [ ] **Step 2: install.sh install_to 输出按档位 + 死重标注**

在 install_to 复制完成后（L108-111 附近），对非 Claude 环境追加死重标注：

```bash
    # G7：按档位输出 + 非 Claude 死重标注
    if [[ -z "$cmd_dir" ]]; then
      echo "  ℹ $name 为 cli 档（目录复制 + --render-tools 规则派生）；hooks/commands 目录为 deep 档（Claude Code）专属，不消费（死重）"
    fi
```

- [ ] **Step 3: 语法检查 + README 验证**

Run:
```bash
bash -n swarm-yuan/install.sh
grep -c '兼容三档' README.md
```
Expected: 语法无输出；grep ≥1

- [ ] **Step 4: Commit**

```bash
git add README.md swarm-yuan/install.sh
git commit -m "feat(g7): README AI 工具兼容三档表 + install.sh 输出按档位 + 死重标注

- README 平行 11 运行时三层接线范式新增三档表
- install_to 非 Claude 环境标注 hooks/commands 死重
- L173/L310 的 7 个表述指向三档表"
```

---

### Task 3: generate-skill.sh 注释对齐 + self-check check_compat_tier

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`
- Modify: `swarm-yuan/scripts/self-check.sh`

- [ ] **Step 1: generate-skill.sh --render-tools 头部注释对齐**

L484-493 头部注释补三档说明：

```bash
# --render-tools：派生各 AI 工具原生规则文件（G7 三档：cli 档 6 工具派生，deep 档 Claude no-op）
# runnable（全部）/ cli（Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi 派生）/ deep（Claude 已深度集成）
```

- [ ] **Step 2: self-check.sh 新增 check_compat_tier**

```bash
# check_compat_tier：AI 工具兼容三档对账（G7）
# 对账 tool-adapters TA_TIER 声明 vs facts.conf FACT_COMPAT_DEEP/CLI
check_compat_tier() {
  local base="$1"
  echo "--- AI 工具兼容三档对账（G7）---"
  local adapters="$base/assets/tool-adapters"
  [[ -f "$adapters/common.sh" ]] || { warn "tool-adapters/common.sh 不存在"; FAIL=1; return; }
  local deep_cnt cli_cnt
  deep_cnt=$(grep -c '^TA_TIER_.*=deep' "$adapters/common.sh" 2>/dev/null || echo 0)
  cli_cnt=$(grep -c '^TA_TIER_.*=cli' "$adapters/common.sh" 2>/dev/null || echo 0)
  [[ "${FACT_COMPAT_DEEP:-1}" == "$deep_cnt" ]] || { warn "deep 档声明数=$deep_cnt ≠ facts.conf=${FACT_COMPAT_DEEP}"; FAIL=1; }
  [[ "${FACT_COMPAT_CLI:-6}" == "$cli_cnt" ]] || { warn "cli 档声明数=$cli_cnt ≠ facts.conf=${FACT_COMPAT_CLI}"; FAIL=1; }
  echo "  ✓ 三档声明（deep=$deep_cnt cli=$cli_cnt）与 facts.conf 一致"
}
```

并在主流程调用。

- [ ] **Step 3: 语法检查 + 手动验证**

Run:
```bash
bash -n swarm-yuan/scripts/self-check.sh
bash -n swarm-yuan/scripts/generate-skill.sh
bash swarm-yuan/scripts/self-check.sh --check-only 2>&1 | grep -A2 '兼容三档'
```
Expected: 语法无输出；三档对账输出

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/scripts/generate-skill.sh swarm-yuan/scripts/self-check.sh
git commit -m "feat(g7): generate-skill 注释对齐 + self-check check_compat_tier 三档对账

- --render-tools 头部注释补三档说明
- self-check 对账 TA_TIER 声明 vs facts.conf（FAIL=1 漂移执法）"
```

---

## Self-Review

**Spec coverage:** §2.2 组件 #1→Task2、#2/3→Task1、#4→Task2、#5→Task3、#6→Task3、#7→Task1 ✓；§2.3 TA_TIER 设计→Task1 ✓；§3 映射表→Task2 README ✓。无 gap。

**Placeholder scan:** 无 TBD，所有步骤含具体代码。

**Type consistency:** TA_TIER_<tool>（Task1 定义，Task3 grep 校验）✓；FACT_COMPAT_DEEP/CLI（Task1 定义，Task3 对账）✓；ta_tier_of（Task1 定义）✓。

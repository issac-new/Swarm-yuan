# G7：兼容层诚实化设计

> 日期：2026-07-22 ｜ 分支：`feat/g7-compat-honesty`
> 范围：自身理念重构（C 方向第二批）—— G7 兼容层诚实化
> 理念：分层整合，诚实降级——不假装全深接
> 口径权威源：`swarm-yuan/assets/facts.conf`

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（调研确认）

**断点 1 —"7 工具兼容"实为两档，但宣称未分档。** 调研确认 7 个 AI 工具的实际兼容深度只有两档：

| 档 | 工具 | 能力 |
|---|------|------|
| **深度集成** | Claude Code（1 个） | 目录复制 + slash command 注册 + hooks/commands/MCP（骨架生成时硬编码 hooks.json/.mcp.json/commands/*.md） |
| **目录复制+规则派生** | Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi（6 个） | 目录复制 + `--render-tools` 派生原生规则文件（.mdc/.windsurf/AGENTS.md/GEMINI.md 标记区块） |

但 README（L173、L310）只说"兼容 AI 工具 7 个"，无分档说明——外部观察者会误以为 7 个工具都有 hooks/commands/MCP 深度集成。

**断点 2 — 复制的骨架在非 Claude 工具里是 Claude 形态死重。** `install.sh install_to`（L86-127）对所有工具做同一件事：整目录 `cp -R` 复制。非 Claude 环境拿到的是 Claude 形态的完整副本（含 `hooks/`、`commands/`、`.claude/commands/swarm-yuan.md`），但这些在非 Claude 工具里不被消费——是死重。

**断点 3 — tool-adapters 无档位元数据。** `assets/tool-adapters/` 8 个文件是纯实现（`render_tool_<tool>` 函数 + 公共库），无"兼容等级"机器可读声明。档位概念只存在于注释叙事（claude.sh:3 引用 R1 "三层同心圆"），不存在于代码结构。

### 1.2 目标

把"7 工具兼容"诚实化为**三档显式声明**（可运行 / CLI 集成 / 深度集成），档位元数据机器可读（tool-adapters 声明 TA_TIER），README/install.sh/generate-skill.sh 的表述与实现对齐——不假装全深接。

### 1.3 方案选型

| 档 | 内容 | 风险 | 选择 |
|---|---|---|---|
| A 只改文档 | README 加三档表，不动代码 | 无 | ✗ 档位仍无机器可读声明，死重未处理 |
| **B 三档声明 + 元数据（选）** | README 三档表 + tool-adapters TA_TIER 元数据 + install.sh 输出按档位 + 非 Claude 骨架死重标注 | 低（主要是声明层，不改派生逻辑） | ✓ |
| C B + 非 Claude 骨架裁剪 | B + install.sh 对非 Claude 环境跳过复制 hooks/commands | 中（改复制逻辑，可能破坏既有用户） | 留验证稳定后 |

**选 B 的理由**：B 把档位显式化（文档 + 机器可读元数据）且不触碰复制逻辑（低风险）。C 档的骨架裁剪改 install.sh 复制行为，可能影响既有用户的升级路径，留验证稳定后作为增量。

### 1.4 三档定义（与 R1 "三层同心圆" 对齐）

| 档 | 名称 | 能力 | 工具 |
|---|------|------|------|
| **runnable 可运行** | 目录复制即被该工具加载 | 目录复制（该工具自身对 skills 目录的加载约定） | 全部 7 个 |
| **cli 集成** | runnable + 派生该工具原生规则文件 | 目录复制 + `--render-tools` 派生（.mdc/.windsurf/AGENTS.md/GEMINI.md） | Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi（6 个） |
| **deep 深度集成** | cli + hooks/commands/MCP | 目录复制 + slash command 注册 + hooks.json/.mcp.json/commands/*.md | Claude Code（1 个） |

---

## 2. 架构与组件

### 2.1 总体架构

```
README.md                        tool-adapters/common.sh + <tool>.sh
（三档表：runnable/cli/deep）      （TA_TIER 机器可读元数据）
        │                                 │
        │  引用                            │  声明
        ▼                                 ▼
install.sh（install_to 输出按档位 + 死重标注）
        │
        ▼
generate-skill.sh（--render-tools 头部注释与三档对齐）
        │
        ▼
self-check.sh check_compat_tier（新断言：TA_TIER 声明 vs README 表一致）
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 |
|---|------|------|---------|
| 1 | `README.md` | 改 | L173/L310 区域加"AI 工具兼容三档"表（复用 11 运行时三层接线范式） |
| 2 | `swarm-yuan/assets/tool-adapters/common.sh` | 改 | 新增每工具 TA_TIER 声明（关联数组或平行数组）+ `ta_render_tools` 输出按档位分组 |
| 3 | `swarm-yuan/assets/tool-adapters/<tool>.sh`（7 个） | 改 | 每个适配器头部注释加 TA_TIER 声明行（claude=deep, 其余 6=cli） |
| 4 | `swarm-yuan/install.sh` | 改 | install_to 输出按档位措辞 + 非 Claude 死重标注（hooks/commands 目录注明"仅 deep 档消费"） |
| 5 | `swarm-yuan/scripts/generate-skill.sh` | 改 | --render-tools 头部注释（L484-493）与三档对齐 |
| 6 | `swarm-yuan/scripts/self-check.sh` | 改 | 新增 check_compat_tier 断言：tool-adapters TA_TIER 声明 vs README 表一致 |
| 7 | `swarm-yuan/assets/facts.conf` | 改 | 新增 FACT_COMPAT_TIERS=3 + FACT_COMPAT_DEEP=1 + FACT_COMPAT_CLI=6 |

### 2.3 TA_TIER 元数据设计（tool-adapters/common.sh）

```bash
# G7：AI 工具兼容三档机器可读元数据
# runnable（可运行，目录复制）/ cli（集成，+规则派生）/ deep（深度集成，+hooks/commands/MCP）
# 声明式，ta_render_tools 输出按档位分组；self-check 对账 README 表。
TA_TIER_claude=deep
TA_TIER_cursor=cli
TA_TIER_windsurf=cli
TA_TIER_codex=cli
TA_TIER_opencode=cli
TA_TIER_gemini=cli
TA_TIER_kimi=cli

# 按档位查 tier（bash 3.2 兼容：间接展开，不用 declare -A）
ta_tier_of() {
  local tool="$1" var="TA_TIER_${tool}"
  eval "echo \"\${${var}:-runnable}\""
}
```

---

## 3. 数据流与三档映射

### 3.1 7 工具 → 三档映射表

| 工具 | 档 | 目录复制 | slash command | 规则派生 | hooks/commands/MCP |
|------|---|---------|--------------|---------|-------------------|
| Claude Code | **deep** | ✓ | ✓（唯一） | no-op（不需要） | ✓ |
| Cursor | cli | ✓ | ✗ | ✓ `.cursor/rules/<skill>.mdc` | ✗ |
| Windsurf | cli | ✓ | ✗ | ✓ `.windsurf/rules/*.md` 或 global_rules.md | ✗ |
| Codex | cli | ✓ | ✗ | ✓ AGENTS.md 标记区块 | ✗ |
| OpenCode | cli | ✓ | ✗ | ✓ AGENTS.md 标记区块 | ✗ |
| Gemini CLI | cli | ✓ | ✗ | ✓ GEMINI.md 标记区块 | ✗ |
| Kimi | cli | ✓ | ✗ | ✓ 仅项目级 AGENTS.md | ✗ |

### 3.2 非 Claude 骨架死重标注

install.sh install_to 对非 Claude 环境，复制后输出：

```
✓ <skill> 已安装到 <dest>（cli 档：目录复制 + --render-tools 规则派生）
  ℹ hooks/ commands/ 目录为 deep 档（Claude Code）专属，cli 档不消费（死重，不影响功能）
```

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理

| 故障 | 行为 | 理由 |
|------|------|------|
| TA_TIER 声明缺失 | `ta_tier_of` 返回 `runnable`（默认） | 未声明工具按最低档处理，不阻塞 |
| README 表 vs TA_TIER 不符 | self-check warn + FAIL=1 | 口径漂移机器执法 |
| --render-tools 派生失败 | install.sh 现有行为：仅警告（render_native_rules L52-71） | 不改变既有降级策略 |

### 4.2 测试策略

| 验证手段 | 覆盖什么 |
|---------|---------|
| `bash -n` 语法检查 | common.sh / install.sh / generate-skill.sh / self-check.sh 改动后语法不崩 |
| `ta_tier_of` 单元验证 | 7 工具各返回正确档位 |
| self-check check_compat_tier | TA_TIER 声明 vs README 表一致 |
| install.sh --list | 输出含三档标注 |

### 4.3 对齐标准

| 标准/理念 | G7 落地 |
|----------|---------|
| 理念：分层整合，诚实降级 | 7 工具兼容从"7 个"笼统宣称变三档显式声明 |
| R1 §六.6 兼容层分级声明 | 按"可运行/CLI 集成/深度集成"三档宣称，避免对 6 个非 Claude 工具过度承诺 |
| facts.conf 单一事实源 | FACT_COMPAT_TIERS/DEEP/CLI 口径机器执法 |

---

## 5. 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-G7-1 | tool-adapters TA_TIER 元数据（common.sh + 7 适配器）+ facts.conf | 无 | 8 改 + 1 改 |
| WP-G7-2 | README 三档表 + install.sh 输出按档位 + 死重标注 | WP-G7-1 | 2 改 |
| WP-G7-3 | generate-skill.sh --render-tools 注释对齐 + self-check check_compat_tier | WP-G7-1 | 2 改 |

---

## 6. 关键证据索引

- install.sh 7 工具检测：`swarm-yuan/install.sh:33-48`（Claude 唯一有 cmd_dir）
- install_to 复制+注册：`swarm-yuan/install.sh:86-127`（非 Claude cmd_dir 空）
- render_native_rules：`swarm-yuan/install.sh:52-71`（--render-tools 派生）
- --render-tools 头部注释：`swarm-yuan/scripts/generate-skill.sh:484-493`
- tool-adapters 调度列表：`swarm-yuan/assets/tool-adapters/common.sh:164`（cursor windsurf gemini codex opencode kimi claude）
- claude.sh no-op 注释：`swarm-yuan/assets/tool-adapters/claude.sh:3`（引用 R1 三层同心圆）
- README 7 工具宣称：`README.md:173,310`
- README Claude 深度集成表：`README.md:240-249`
- README 11 运行时三层接线范式：`README.md:224-234`（可复用）
- R1 §六.6 兼容层分级声明建议：`docs/research/R1-self-design.md` §六.6
- R1 §五 G7 兼容层过度承诺：`docs/research/R1-self-design.md` §五 G7

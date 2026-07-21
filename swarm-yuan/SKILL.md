---
name: swarm-yuan
description: "Meta-skill generator: produces a project-specific dev skill for ANY code repo. Integrates 11 runtimes (OpenSpec/superpowers/comet/GitNexus/graphify/gsd-core/claude-mem/ocr/gstack/Ruflo/ECC), 36 quality gates (core 10 + architecture 17 + compliance 9; incl. shift-left: test-design/change-impact/observability in spec/plan stage; rtm requirement-traceability; release-sign SLSA L2 signing), 5-layer cognition framework, 32-domain knowledge. Core capability: exhaustive component inventory (mechanical enumeration + signature extraction + count verification) and call-chain analysis (shape-adaptive by project form: registration assembly / request pipeline / message flow / cross-service chain) → orchestration constraints derivation. Use when user says '为某项目生成开发技能', 'create a dev skill', '六段式 skill'."
---

# swarm-yuan — 项目需求交付技能生成器

元技能（生成器）：针对任意代码仓库，按六段式模板生成项目专属开发技能（下称"目标技能"）。跨项目复用，不依赖任何具体项目内容。

**★核心能力（v2 增强）**：基于代码结构与调用链路分析，产出**详尽的组件库清单**（全量穷举，非代表性样本）与**编排调用关系及约束**（导入方向/注册顺序/路由挂载/状态所有权/测试边界，每条含代码证据），完善目标技能的研发 skill。方法论见 `references/exploration-guide.md` §C+。

**★核心能力（v3 左移）**：测试、变更影响、运维监控不等到测试/发布阶段才考虑，在 spec/plan 阶段就嵌入约束（spec §19 测试设计 + §20 变更影响 + §21 可观测性约束），编码阶段先测试后实现，合入前确认回滚预案，发布前确认灰度+告警+runbook。门禁 `--shift-left` 校验各阶段左移产出物。详见 `references/template-spec.md` §左移要求。

## 何时使用

- 用户输入 `/swarm-yuan <项目路径>`（slash command，详见 `.claude/commands/swarm-yuan.md`）
- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"
- 用户给了一个代码仓库，要求产出研发用 skill

**安装**：`bash install.sh`（自动检测运行环境 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi，安装到对应 skill 目录。详见 `install.sh --list`）

**不适用**：用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 三条铁律

1. **版本锁定**：不允许随意升级核心依赖版本（除非用户要求/安全漏洞/性能隐患/功能缺失）。`--deps` 检测。
2. **安全规范**：目标技能须遵守 OWASP Top 10 / STRIDE / CWE。`--security` 检测。详见 `references/security-spec.md`。
3. **三平台兼容（swarm-yuan 自身）**：swarm-yuan 生成器自身的脚本必须兼容 Windows/macOS/Linux（CI 全覆盖：ubuntu-latest + macos-latest + windows-latest）。Windows 上提供 `.bat` 包装器（`install.bat` / `generate-skill.bat` / `self-check.bat`）自动查找 Git Bash/WSL/MSYS2 运行对应 `.sh` 脚本（WSL 路径用 `/mnt/c/`，Git Bash 用 `/c/`）。bash 脚本兼容：不用 `declare -A`；`sed -i.bak+rm`；`grep -E`；`date -u`；`$(cd+pwd)` 替代 `readlink -f`；`wc|xargs`；`${var}` 防 C-locale。详见 `references/security-spec.md` §六。

## 五层认知基底 + 执行准则

swarm-yuan 的 36 个门禁服务于一条认知递进链。核心理念：**呈现递进的关系，而非仅关注计算**。

| 层 | 解决什么 | 落点 |
|----|---------|------|
| 第一层 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） | 探查 + `--cognition` |
| 第二层 思维语言 | 如何思考（三元演化+三导向+七推理+7×7） | workflow + spec §14/§15 |
| 第三层 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） | workflow + check |
| 第四层 偏差防范 | 如何纠偏（五维偏差+思维模型 8 类） | spec §16 |
| 第五层 辩证认知 | 如何统一前四层（7 对辩证范畴） | spec §17 |
| 领域知识（贯穿五层） | 识别技术+业务领域，推导客观规律（防达克效应） | spec §18 + `--domain` |

**执行准则**：价值/目标/问题/结果四导向；质量优先>确保安全>兼顾效率>减少打扰>因地制宜；疑虑必确认（改只读/升级依赖/删稳定单元/多方案/安全冲突→暂停确认）。

**AI 主导 + 用户决策原则**：在目标 skill 的完整生命周期中，特征卡提取、门禁配置、spec 填充、代码实现、问题排查等所有环节均**优先以 AI 为主导生成建议项**——AI 探查项目后主动提出特征卡建议、主动推导门禁配置、主动填充 spec 模板、主动给出代码方案、主动诊断门禁 fail 原因并给出修复建议。用户的角色是**评估决策或修订后批准执行**，而非手动编写。具体：
- 特征卡 16 项：AI 探查后**主动生成建议值**，用户评估修订后确认
- 门禁 precheck.conf 179 变量：AI 从特征卡**主动推导建议配置**，用户评估后确认
- spec 模板填充：AI **主动预填**（含 §5.5 复用约束从第 11 项检索预填），用户评估修订后确认
- 门禁 fail：AI **主动诊断原因 + 给出修复建议**，用户评估后批准执行
- 编码实现：AI **主动给出代码方案**（含复用了哪些稳定单元），用户评估后确认
- 多方案选择：AI **主动提出 2+ 方案权衡 + 推荐**，用户决策
- 问题排查：AI **主动分析 + 给出解决方案**，用户评估后批准

> 完整框架详见 `references/cognition-framework.md`；逻辑剃刀+谬误图谱见 `references/logic-razor.md`；认知偏差+思维模型见 `references/cognitive-bias.md`；领域知识速查见 `references/domain-knowledge.md`。

## 生成流程（AI 自动执行，用户只需提供项目路径）

**铁律：AI 必须执行完整流程（Step 0-10）后才算生成完成。不允许中途停止在骨架阶段——骨架中的占位符必须全部被真实内容替换。生成完成时检查：目标 skill 中不得残留任何"待填充"/"填充指引"/占位符。**

**★核心铁律（详尽构件库清单 + 编排约束，按项目形态动态适配）：swarm-yuan 不预设项目是前端/后端/全栈/移动/桌面/库。** 必须先做 §C+.0 项目形态判定（探查文件类型/框架特征 → 判定含哪些维度），再按判定结果选择的维度做全量穷举 + 签名提取 + 计数核验（清单计数 ≥ 枚举计数 × 0.95）。特征卡第 15 项（编排调用关系及约束）必须从 §C+.2 按形态选择的链路模型（前端注册装配/后端请求管道/异步消息流/微服务跨服务链）推导得出，每条约束须有代码证据。两者配套：只列构件不推约束 = 未完成；维度错配（纯后端项目填 UI 组件表）= 未完成。

```
用户："为 /path/to/project 生成 skill"
  ↓ AI 自动执行（零手动配置，不可中途停止）
⓪自检(11运行时) → ⓪.5读取项目知识(AGENTS.md/CLAUDE.md/记忆/agent运行时) → ①探查仓库(三路并行+图谱工具) → ①.5项目形态判定(§C+.0)+详尽构件库清单+调用链路分析(§C+.1-C+.5按维度动态适配) → ②提取16项特征卡 → ③create骨架 → ④AI填充全部文件(消除全部占位符) → ④.5框架深化(逐激活框架:按 references/frameworks/<fw>.md §1-§6 枚举+规律实例化+门禁清单对齐) → ⑤AI配置precheck.conf(消除全部占位符) → ⑤.5 AI生成hooks/commands/MCP集成 → ⑥AI运行门禁验证 → ⑦.5门禁注入(`scripts/generate-skill.sh --inject-frameworks` 将 assets/framework-gates/<fw>.sh 写入 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块；`--upgrade` 触发自动重注入) → ⑦AI写回项目记忆(闭环) → ⑧AI最终检查(零占位符+按维度计数核验+框架适配四要素核验)
```

1. **自检**：`bash scripts/self-check.sh`（11 个运行时检测+自动安装）
2. **读取项目知识**：AGENTS.md/CLAUDE.md/记忆/agent 运行时（若有） → 提取规则写入特征卡（不读=重复造轮子）
3. **探查仓库**：三路并行子代理（结构/规范/代码组织），优先用 gitnexus/graphify/claude-mem/LSP，大型项目用 Dynamic Workflow 并行扇出。工具矩阵+降级策略见 `references/exploration-guide.md`
4. **★项目形态判定 + 详尽构件库清单 + 调用链路分析**（探查的深化，不可跳过）：
   - **项目形态判定（§C+.0）**：探查文件类型/框架特征 → 判定含哪些维度（前端UI/后端API/异步消费/桌面IPC/移动端/库导出）→ 后续只枚举存在的维度
   - **全量穷举（§C+.1 按维度动态）**：按判定结果选择的维度（C+.1-F前端/C+.1-B后端/C+.1-A异步/C+.1-D桌面移动/C+.1-L库/C+.1-T通用）做 `find`+`grep` 机械枚举 → 提取导出签名 → 每维度独立计数核验
   - **调用链路分析（§C+.2 按形态选模型）**：前端(注册装配+模块矩阵+挂载树+store依赖) / 后端(请求处理管道+分层矩阵+数据流+外部依赖) / 异步(消息流转) / 微服务(跨服务调用链) / 桌面(IPC链路) / 库(导出依赖图)
   - **编排约束推导（§C+.3 按形态选约束类别）**：前端约束 / 后端约束 / 异步约束 / 微服务约束 / 通用约束，每条标注代码证据
   - **接口全量枚举（§C+.4 按接口形态适配）**：REST(逐端点) / GraphQL(逐resolver) / gRPC(逐method) / MQ(逐queue+handler) / 库(逐导出)，无通配符占位
   - 优先用 `gitnexus context/trace` 或 `graphify path/explain` 系统性提取签名与依赖链，而非随机 grep
5. **特征卡**：16 项（项目类型→…→可复用稳定单元→…→编排约束→详尽构件库清单），每项落到具体值不用占位符。映射表见 `references/template-spec.md` §3
6. **创建骨架**：`bash scripts/generate-skill.sh <name> <project-dir>`（含 hooks/ + commands/ + precheck.conf）。默认生成到 `<project-dir>/.claude/skills/`（"为目标项目生成"名副其实）；可用第 3 参数 `target-dir` 显式指定其他目录，如 `--upgrade <name> <project-dir> <target-dir>`。全局安装到 `~/.claude/skills/` 等运行时目录走 `install.sh`。
7. **AI 填充全部文件**：SKILL.md/codebase/dev-guide/release/reference-manual/workflow/snippets/mcp-tools——**每个文件必须用探查到的真实内容替换占位符**。填充指引见 `references/template-spec.md`。**reference-manual.md §4 构件表/§6 接口表/§9 store+类型表按形态动态填充（维度错配=未完成），§5 链路按形态选模型 + §5.1 约束注释，dev-guide.md §8 按形态选约束类别**
8. **AI 配置 precheck.conf**：从特征卡推导 179 个变量（PROJECT_DIR/WRITABLE_DIRS/LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等）——**所有 `<占位符>` 必须替换为真实值**
9. **AI 集成 Claude Code**：生成 hooks/hooks.json + commands/ + settings.local.json + .mcp.json + workflow.md 节点标注。详见 `references/claude-code-capabilities.md`
10. **AI 运行门禁**：`precheck.sh --all`（核心 10）→ fail 自动修复重跑 → `--all-full`（全 36：核心 10+架构 17+合规 9）
11. **AI 写回记忆**：claude-mem/.zcode/memories/.project-knowledge.md 三路写回，形成"记忆→生成→开发→记忆"闭环
12. **AI 最终检查**：运行 `bash scripts/generate-skill.sh --verify-completeness <skill_dir>` 做零占位符机器执法（命中即列 file:line 并 exit 1，零命中打印「✓ 零占位符确认」），确认零"待填充"/零"填充指引"/零"<占位符>"残留；**按维度计数核验：对 §C+.0 判定的每个维度，用对应的 `find`/`grep` 命令计数，对比 reference-manual.md 对应章节行数，偏差 >5% → 回到 Step 4 补全该维度**；**维度适配核验：纯后端项目不应有 UI 组件表，纯前端项目不应有 controller 表（维度错配 → 回 Step 4 重判）**；**框架适配四要素核验：对 ACTIVE_FRAMEWORKS 每个框架——① 构件枚举计数 ≥ 实际 × 0.95（依 `references/frameworks/<fw>.md` §2 的计数基准）② `framework-knowledge.md` 规律数 ≥ 规则文件声明的深度门槛且 100% 含"证据:"字段 ③ `precheck.sh` 含 `_fw_<id>_check` 动态分发器且 `--framework <id>` 实跑 exit 0（门禁片段位于 `assets/framework-gates/<fw>.sh`，已注入到 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块）④ `dev-guide.md` §10 含该框架约束段 ≥ 3 条。任一不过 → 回 Step 4.5**。**如有残留，回到 Step 7 继续填充，直到零残留。**

> **铁律**：用户不编辑任何配置文件，不手动复制模板。开始新需求时对 AI 说"开始新需求 xxx"，AI 自动创建 spec 文件 + 引导填写 + 运行门禁。门禁误报 AI 自动调 conf 后重跑。每节点须有降级策略（联网/云端不可用→降级本地工具）。节点工具表+降级表见 `references/claude-code-capabilities.md` §十五。

## 六段式模板

生成的目标技能结构（六段式）：

| 段 | 文件 | 作用 |
|----|------|------|
| meta | `SKILL.md` | 元信息、铁律、流程总览、命令速查 |
| workflow | `references/workflow.md` | 节点化流程（9 要素/节点 + 4-Phase SOP）——生成时填充 |
| reference | `references/*.md` | 参考手册（目录/安全/编译/**全量组件库**/**依赖链路+约束（按形态选模型）**/**全量接口端点**/**全量store+类型** + 数据 + 方法论 + 认知 + 领域知识） |
| reference | `references/framework-knowledge.md` | **按激活框架实例化的规律与门禁依据**（骨架由 AI 在 Step 4.5 框架深化阶段依据 `references/frameworks/<fw>.md` §3+§4 构建，逐条用项目代码验证实例化；`--inject-frameworks` 只注入门禁片段到 precheck.sh，不生成此文件骨架） |
| assets | `assets/*` | 模板（spec/plan/分支/环境/库表/状态机） |
| check | `scripts/precheck.sh` | 36 个门禁子命令（核心 10 + 架构 17 + 合规 9：`--compliance` 标准合规矩阵核验 / `--docs-pack` 文档包清单 / `--sbom` SBOM 生成+许可证块名单 / `--privacy` 个人信息扫描 / `--authz` 授权类弱点 / `--requirements` 需求质量（29148）/ `--crypto` 密码算法合规（GB/T 39786）/ `--rtm` 需求追溯矩阵（29148 RTM）/ `--release-sign` 发布签名+provenance（SLSA L2 / SSDF PS.2），随 `--all-full` 执行，未配置静默跳过；另含 `--shift-left` 左移：测试设计/变更影响/可观测性） + **框架门禁片段注入区**（`# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块，由 `--inject-frameworks` 写入） |
| scripts | `scripts/*` | 工具箱（门禁+状态机+图谱+MCP+self-check） |

## 它整合的方法论（只引用调用，不重新实现）

swarm-yuan 整合 11 个外部运行时，按**接线深度分三层**（每层有自带降级载体，不假装全深接）：

| 层 | 运行时 | 真实接线方式 | 降级载体 |
|----|--------|-------------|---------|
| **深度接线（4）** | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用（`gitnexus query`/`graphify explain`/`claude-mem search`/`ocr review`），带 `has_*` 守卫 + 多级降级链 | grep+madge / progress ledger / 5 维度手动清单 |
| **CLI 接线（3）** | OpenSpec / comet / gsd-core | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`），带 `has_*` 守卫，未装或项目未用时降级 | 自带文档检查 / 自带 state-machine.sh / ocr+手动清单 |
| **方法论引用（4）** | superpowers / gstack / ECC / Ruflo | 作为方法论参考，AI 按 workflow 节点引用其模式（slash command 或文档指引）；swarm-yuan 自带等价降级载体 | 自带 subagent-orchestration.md / review-methodology.md / state-machine.sh |

OpenSpec（spec-driven）/ superpowers（subagent-driven）/ comet（state machine）/ gstack+OCR（review）/ graphify+GitNexus（code-graph）/ gsd-core（phase-loop+goal-backward）/ claude-mem（memory persistence）/ Ruflo（multi-agent swarm 编排）/ ECC（council 多声音认知扩展）。

> 工具引用铁律：深度+CLI 接线层（7 个）允许真实命令调用（`graphify`/`gitnexus`/`ocr`/`claude-mem`/`gsd-tools`/`openspec`/`comet`），不重新实现、不复制源码；方法论引用层（4 个）只引用模式不调 CLI。**GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（MIT）提为默认代码图谱工具**（详见 `references/code-graph-tools.md` §许可证与选型）。

**reference 文件清单（按需读取）**：

| 用途 | 文件 |
|------|------|
| 探查指南（16 项特征卡 + 图谱工具 + **§C+ 详尽组件库清单与调用链路分析**） | `references/exploration-guide.md` |
| 六段式填充规范（生成后核对清单 + **§4/§5/§6 全量要求 + 编排约束核对**） | `references/template-spec.md` |
| 五层认知基底总览 | `references/cognition-framework.md` |
| 逻辑剃刀 + 谬误图谱 | `references/logic-razor.md` |
| 认知偏差 + 思维模型 | `references/cognitive-bias.md` |
| 领域知识速查（32 领域） | `references/domain-knowledge.md` |
| Claude Code 官方能力全量清单 | `references/claude-code-capabilities.md` |
| 安全规范（OWASP/STRIDE/CWE） | `references/security-spec.md` |
| subagent 编排模式 | `references/subagent-orchestration.md` |
| 代码审查方法论（5 维度） | `references/review-methodology.md` |
| 代码图谱工具引用 | `references/code-graph-tools.md` |
| 标准合规矩阵（GB/T 25000.51/8566/8567/9386 + 安全标准 × 36 门禁映射 + 豁免登记） | `references/standards-compliance.md` |
| gsd-core phase-loop/goal-backward | `references/gsd-patterns.md` |
| 跨会话记忆持久化 | `references/memory-persistence.md` |
| MCP 治理（默认最小化政策 + connector 书面理由） | `references/mcp-governance.md` |
| AI 过程信息项制度（8566 附录 A/B 扩展：prompt/diff/人工复核留痕） | `references/ai-process-records.md` |
| 金融行业 profile（法规/监管办法/JR/T 标准 ↔ 门禁映射 + finance.conf 配套） | `references/industry-profile-finance.md` |
| 医疗行业 profile（法规/卫健委办法/GB/T 39725 ↔ 门禁映射 + medical.conf 配套） | `references/industry-profile-medical.md` |
| 框架规则库（生成时按 ACTIVE_FRAMEWORKS 读取对应 `<fw>.md`） | `references/frameworks/` |

## 使用说明

1. 确认目标项目路径与 skill 名称
2. `bash scripts/self-check.sh` 自检 11 项目运行时
3. 按需读 reference（探查→exploration-guide；填充→template-spec；方法论→各 reference 文件）
4. `scripts/generate-skill.sh <name> <project-dir>` 创建骨架（或 `--upgrade` 升级已有）
5. 按 5 步流程执行，每段落盘后用 `template-spec.md` 末尾核对表验证

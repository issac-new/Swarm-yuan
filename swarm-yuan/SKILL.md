---
name: swarm-yuan
description: "Meta-skill generator: produces a project-specific dev skill for ANY code repo. Integrates 11 runtimes (OpenSpec/superpowers/comet/GitNexus/graphify/gsd-core/claude-mem/ocr/gstack/Ruflo/ECC), 49 quality gates (standard 27 via --all-full: core 10 + architecture 17; compliance 17 via --compliance-suite on-demand; incl. shift-left: test-design/change-impact/observability in spec/plan stage; rtm requirement-traceability; release-sign SLSA L2 signing), 5-layer cognition framework, 32-domain knowledge. Core capability: exhaustive component inventory (mechanical enumeration + signature extraction + count verification) and call-chain analysis (shape-adaptive by project form: registration assembly / request pipeline / message flow / cross-service chain) → orchestration constraints derivation. Use when user says '为某项目生成开发技能', 'create a dev skill', '六段式 skill'."
---

# swarm-yuan — 项目需求交付技能生成器

元技能（生成器）：针对任意代码仓库，按六段式模板生成项目专属开发技能（下称"目标技能"）。跨项目复用，不依赖任何具体项目内容。

> **口径权威源**：`assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

**★核心能力（v2 增强）**：基于代码结构与调用链路分析，产出**详尽的组件库清单**（全量穷举，非代表性样本）与**编排调用关系及约束**（导入方向/注册顺序/路由挂载/状态所有权/测试边界，每条含代码证据），完善目标技能的研发 skill。方法论见 `references/exploration-guide.md` §C+。

**★核心能力（v3 左移）**：测试、变更影响、运维监控不等到测试/发布阶段才考虑，在 spec/plan 阶段就嵌入约束（spec §19 测试设计 + §20 变更影响 + §21 可观测性约束），编码阶段先测试后实现，合入前确认回滚预案，发布前确认灰度+告警+runbook。门禁 `--shift-left` 校验各阶段左移产出物。详见 `references/template-spec.md` §左移要求。

## 何时使用

- 用户输入 `/swarm-yuan <项目路径>`（slash command，详见 `.claude/commands/swarm-yuan.md`）
- 用户说"为某项目生成开发技能"、"create a dev skill for this repo"、"按模板生成 skill"
- 用户提到"六段式 skill"、"需求交付全流程 skill"、"spec-driven skill"
- 用户给了一个代码仓库，要求产出研发用 skill

**安装**：`bash install.sh`（自动检测运行环境 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi，安装到对应 skill 目录。详见 `install.sh --list`）

**不适用场景**（WP-P10 范式定位，详见 `docs/paradigm-positioning.md`）：
- 个人脚本/一次性原型/学习用 demo——建议直接用 AI 裸写，不套范式
- 极小改动（改 typo/调样式）——直接改，不走 spec 流程
- 无 AI 辅助的纯人工开发——范式设计为 AI 驱动，纯人工无法消费
- 替代方案：单文件 `precheck.sh` 做门禁不套生成器；或传统 lint/test 工具链

**不适用**：用户只是要在某项目里做具体开发任务（那应该用该项目的目标技能）。

## 三条铁律

1. **版本锁定**：不允许随意升级核心依赖版本（除非用户要求/安全漏洞/性能隐患/功能缺失）。`--deps` 检测。
2. **安全规范**：目标技能须遵守 OWASP Top 10 / STRIDE / CWE。`--security` 检测。详见 `references/security-spec.md`。
3. **三平台兼容（swarm-yuan 自身）**：swarm-yuan 生成器自身的脚本必须兼容 Windows/macOS/Linux（CI 全覆盖：ubuntu-latest + macos-latest + windows-latest）。Windows 上提供 `.bat` 包装器（`install.bat` / `generate-skill.bat` / `self-check.bat`）自动查找 Git Bash/WSL/MSYS2 运行对应 `.sh` 脚本（WSL 路径用 `/mnt/c/`，Git Bash 用 `/c/`）。bash 脚本兼容：不用 `declare -A`；`sed -i.bak+rm`；`grep -E`；`date -u`；`$(cd+pwd)` 替代 `readlink -f`；`wc|xargs`；`${var}` 防 C-locale。详见 `references/security-spec.md` §六。

## 五层认知基底 + 执行准则

swarm-yuan 的 49 个门禁服务于一条认知递进链。核心理念：**呈现递进的关系，而非仅关注计算**。

| 层 | 解决什么 | 落点 |
|----|---------|------|
| 第一层 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） | 探查 + `--cognition` |
| 第二层 思维语言 | 如何思考（三元演化+三导向+七推理+7×7） | workflow + spec §14/§15 |
| 第三层 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） | workflow + check |
| 第四层 偏差防范 | 如何纠偏（五维偏差+思维模型 8 类） | spec §16 |
| 第五层 辩证认知 | 如何统一前四层（7 对辩证范畴） | spec §17 |
| 领域知识（贯穿五层） | 识别技术+业务领域，推导客观规律（防达克效应） | spec §18 + `--domain` |

**执行准则**：价值/目标/问题/结果四导向；质量优先>确保安全>兼顾效率>减少打扰>因地制宜；疑虑必确认（改只读/升级依赖/删稳定单元/多方案/安全冲突→暂停确认）。

**AI 主导 + 用户决策原则**（G1 决策治理，对齐 ISO/IEC 42001 人工监督留痕）：在目标 skill 的完整生命周期中，特征卡提取、门禁配置、spec 填充、代码实现、问题排查等所有环节均**优先以 AI 为主导生成建议项**，但决策按**三级分类**治理——什么能自动做、什么必须停下问、每条决策有审计轨迹落盘。用户的角色是**评估决策或修订后批准执行**，而非手动编写。详见 `references/decision-governance.md`。具体：
- 特征卡 17 项：AI 探查后**主动生成建议值**（Mechanical 类，直接做），用户评估修订后确认
- 门禁 precheck.conf 158 变量：AI 从特征卡**主动推导建议配置**（Mechanical 类；涉及安全规则如 SENSITIVE_WHITELIST/CRYPTO_PROFILE 升 Taste），用户评估后确认
- spec 模板填充：AI **主动预填**（Taste 类；§5.6 版本约束/§5.7 安全约束升 UserChallenge；含 §5.5 复用约束从第 11 项检索预填），用户评估修订后确认
- 门禁 fail：AI **主动诊断原因 + 给出修复建议**（Taste 类；涉及依赖升级/安全冲突/删稳定单元升 UserChallenge），用户评估后批准执行
- 编码实现：AI **主动给出代码方案**（Taste 类；含复用了哪些稳定单元；多方案/改只读/删稳定单元升 UserChallenge），用户评估后确认
- 多方案选择：AI **主动提出 2+ 方案权衡 + 推荐**（**UserChallenge 类，永不自动决定**，须输出五要素等用户裁定），用户决策
- 问题排查：AI **主动分析 + 给出解决方案**（Taste 类；涉及架构变更/安全冲突升 UserChallenge），用户评估后批准

> **决策留痕**：每条决策通过 `scripts/trace-log.sh --decision` 追加到 `.swarm-yuan/decisions.jsonl`（永不 fail 阻塞主流程）；UserChallenge 类须含五要素（alternatives/missing_context/cost_if_wrong）。阶段流转由 `scripts/state-machine.sh` transition 自动记录。`--mark-active` 前须有至少 1 条决策记录（`--verify-completeness --strict` 校验）。

> 完整框架详见 `references/cognition-framework.md`；逻辑剃刀+谬误图谱见 `references/logic-razor.md`；认知偏差+思维模型见 `references/cognitive-bias.md`；领域知识速查见 `references/domain-knowledge.md`；决策治理（三级分类+五要素）见 `references/decision-governance.md`。

## 生成流程（AI 自动执行，用户只需提供项目路径）

**铁律：AI 必须执行完整流程（Step 0-10）后才算生成完成。不允许以 draft 骨架交付——骨架中的占位符必须全部被真实内容替换。生成完成时检查：目标 skill 中不得残留任何"待填充"/"填充指引"/占位符。**

**中断安全（状态门，决策 13）：流程可中断，但 draft ≠ 交付。** 骨架 frontmatter `status: draft` 期间，目标 skill 的 `--all-full`/`--compliance-suite` 被 precheck 机器禁用（exit 2）；中断后重跑 `generate-skill.sh` 同命令自动**断点续传**（幂等补齐缺失文件，不覆盖已有内容）；填充完成后 `bash scripts/generate-skill.sh --mark-active <skill_dir>`（零占位符核验通过才翻 `status: active`）才算生成完成。P1 特征卡项可「（P1 待补）」占位（WP-G），P0 六项必须填实。

**★调用追踪铁律（设计理念 2：全链路追踪）：生成流程与目标 skill 的使用流程中，每一步具体调用都必须有信息提示（无需用户确认），显示调用了何种工具及技能。** 双通道：① stdout 结构化公告——每 Step/节点开始时输出 `→ [Step N/节点X] 调用 <技能/子代理/工具> · <目的>`；② 落盘——**节点级默认**：每 Step/节点开始/结束时执行 `bash scripts/trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令>`，追加到 `<项目>/.swarm-yuan/trace.jsonl`；**调用级细节**（每个 CLI 工具/第三方调用的逐次落盘）仅在 `SWARM_YUAN_TRACE=verbose` 时启用（聚合分析见 `scripts/cost-report.sh`）。机器执法：`--verify-completeness` 校验目标 skill 的 workflow.md 每节点含「调用追踪」要素（template-spec §2 第 ⑨ 要素），缺则 exit 1。

**★核心铁律（详尽构件库清单 + 编排约束，按项目形态动态适配）：swarm-yuan 不预设项目是前端/后端/全栈/移动/桌面/库。** 必须先做 §C+.0 项目形态判定（探查文件类型/框架特征 → 判定含哪些维度），再按判定结果选择的维度做全量穷举 + 签名提取 + 计数核验（清单计数 ≥ 枚举计数 × 0.95）。特征卡第 15 项（编排调用关系及约束）必须从 §C+.2 按形态选择的链路模型（前端注册装配/后端请求管道/异步消息流/微服务跨服务链）推导得出，每条约束须有代码证据。两者配套：只列构件不推约束 = 未完成；维度错配（纯后端项目填 UI 组件表）= 未完成。

```
用户："为 /path/to/project 生成 skill"
  ↓ AI 自动执行（零手动配置，不可中途停止）
⓪自检(11运行时) → ⓪.5读取项目知识(AGENTS.md/CLAUDE.md/记忆/agent运行时) → ①探查仓库(三路并行+图谱工具) → ①.5项目形态判定(§C+.0)+详尽构件库清单+调用链路分析(§C+.1-C+.5按维度动态适配) → ②提取17项特征卡 → ③create骨架 → ④AI填充全部文件(消除全部占位符) → ④.5框架深化(逐激活框架:按 references/frameworks/<fw>.md §1-§6 枚举+规律实例化+门禁清单对齐) → ⑤AI配置precheck.conf(消除全部占位符) → ⑤.5 AI生成hooks/commands/MCP集成 → ⑥AI运行门禁验证 → ⑦.5门禁注入(`scripts/generate-skill.sh --inject-frameworks` 将 assets/framework-gates/<fw>.sh 写入 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块；`--upgrade` 触发自动重注入) → ⑦AI写回项目记忆(闭环) → ⑧AI最终检查(零占位符+按维度计数核验+框架适配四要素核验)
```

1. **自检**：`bash scripts/self-check.sh`（11 个运行时检测+自动安装）
2. **读取项目知识**：AGENTS.md/CLAUDE.md/记忆/agent 运行时（若有） → 提取规则写入特征卡（不读=重复造轮子）
3. **探查仓库**：三路并行子代理（结构/规范/代码组织），优先用 gitnexus/graphify/claude-mem/LSP，大型项目用 Dynamic Workflow 并行扇出。工具矩阵+降级策略见 `references/exploration-guide.md`。**★WP-P8 per-phase profile 探查分级**：按 `auto_detect_profile` 的规模信号分级——lite（<80 文件）单路探查不用图谱；standard（80-500）三路并行图谱可选；compliance（合规信号或 >500）三路并行 + 强制图谱工具。规模边界不确定按更重档处理（质量优先）。**★全链路追踪（设计理念 2）**：每路子代理启动前 AI 调 `bash scripts/trace-log.sh --node "探查" --actor "结构子代理" --tool "gitnexus context" --status started`（规范/代码组织子代理同理），完成后 `--status done`——用户可见每步调用何种工具，无需确认（trace 输出 stderr + 落盘 trace.jsonl，不阻塞主流程）
4. **★项目形态判定 + 详尽构件库清单 + 调用链路分析**（探查的深化，不可跳过）：
   - **项目形态判定（§C+.0）**：探查文件类型/框架特征 → 判定含哪些维度（前端UI/后端API/异步消费/桌面IPC/移动端/库导出）→ 后续只枚举存在的维度
   - **全量穷举（§C+.1 按维度动态）**：按判定结果选择的维度（C+.1-F前端/C+.1-B后端/C+.1-A异步/C+.1-D桌面移动/C+.1-L库/C+.1-T通用）做 `find`+`grep` 机械枚举 → 提取导出签名 → 每维度独立计数核验
   - **调用链路分析（§C+.2 按形态选模型）**：前端(注册装配+模块矩阵+挂载树+store依赖) / 后端(请求处理管道+分层矩阵+数据流+外部依赖) / 异步(消息流转) / 微服务(跨服务调用链) / 桌面(IPC链路) / 库(导出依赖图)
   - **编排约束推导（§C+.3 按形态选约束类别）**：前端约束 / 后端约束 / 异步约束 / 微服务约束 / 通用约束，每条标注代码证据
   - **接口全量枚举（§C+.4 按接口形态适配）**：REST(逐端点) / GraphQL(逐resolver) / gRPC(逐method) / MQ(逐queue+handler) / 库(逐导出)，无通配符占位
   - 优先用 `gitnexus context/trace` 或 `graphify path/explain` 系统性提取签名与依赖链，而非随机 grep
5. **特征卡**：16 项（项目类型→…→可复用稳定单元→…→编排约束→详尽构件库清单），P0 六项（1/4/5/11/15/16）每项落到具体值不用占位符；P1 十项 draft 期可「（P1 待补）」，`--mark-active` 前清零。映射表见 `references/template-spec.md` §3
6. **创建骨架**：`bash scripts/generate-skill.sh <name> <project-dir>`（含 hooks/ + commands/ + precheck.conf）。`--profile auto|lite|standard|compliance` 四档，**默认 auto 项目级自适应**（合规关键词 → compliance；文件数 <80 → lite；其余 standard；**WP-Q2 偏置修正：信号明确才升档，模糊走默认 standard**，auto 会打印判定依据供用户评估）：**lite**（认知档）= 特征卡 + reference-manual + 核心门禁脚本最小集（无 hooks/commands/settings/.mcp.json）；**standard** = 全量骨架；**compliance** = standard + 标准合规矩阵参考（references/standards-compliance.md）。**零占位符铁律适用范围 = 当前 profile 的文件集**（profile 是显式声明不启用，与"未配置静默跳过"本质不同）。默认生成到 `<project-dir>/.claude/skills/`（"为目标项目生成"名副其实）；可用第 3 参数 `target-dir` 显式指定其他目录，如 `--upgrade <name> <project-dir> <target-dir>`。全局安装到 `~/.claude/skills/` 等运行时目录走 `install.sh`。
7. **AI 填充全部文件**：SKILL.md/codebase/dev-guide/release/reference-manual/workflow/snippets/mcp-tools——**每个文件必须用探查到的真实内容替换占位符**。填充指引见 `references/template-spec.md`。**reference-manual.md §4 构件表/§6 接口表/§9 store+类型表按形态动态填充（维度错配=未完成），§5 链路按形态选模型 + §5.1 约束注释，dev-guide.md §8 按形态选约束类别**
8. **AI 配置 precheck.conf**：从特征卡推导 158 个变量（PROJECT_DIR/WRITABLE_DIRS/LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等）——**所有 `<占位符>` 必须替换为真实值**
9. **AI 集成 Claude Code**：生成 hooks/hooks.json + commands/ + settings.local.json + .mcp.json + workflow.md 节点标注。详见 `references/claude-code-capabilities.md`
10. **AI 运行门禁**：`precheck.sh --all`（核心 10）→ fail 自动修复重跑 → `--mark-active` 翻 active 后 `--all-full`（标准 27：核心 10+架构 17）；强监管交付按需追加 `--compliance-suite`（合规 17）
11. **AI 写回记忆**：claude-mem/.zcode/memories/.project-knowledge.md 三路写回，形成"记忆→生成→开发→记忆"闭环
12. **AI 最终检查**：运行 `bash scripts/generate-skill.sh --verify-completeness <skill_dir>` 做零占位符 + workflow 调用追踪要素机器执法（命中即列 file:line 并 exit 1，零命中打印「✓ 零占位符确认」），确认零"待填充"/零"填充指引"/零"<占位符>"残留；**按维度计数核验（仅 P0 维度强制）：对 §C+.0 判定的每个维度，用对应的 `find`/`grep` 命令计数，对比 reference-manual.md 对应章节行数，偏差 >5% → 回到 Step 4 补全该维度**；**维度适配核验：纯后端项目不应有 UI 组件表，纯前端项目不应有 controller 表（维度错配 → 回 Step 4 重判）**；**框架适配四要素核验：对 ACTIVE_FRAMEWORKS 每个框架——① 构件枚举计数 ≥ 实际 × 0.95（依 `references/frameworks/<fw>.md` §2 的计数基准）② `framework-knowledge.md` 规律数 ≥ 规则文件声明的深度门槛且 100% 含"证据:"字段 ③ `precheck.sh` 含 `_fw_<id>_check` 动态分发器且 `--framework <id>` 实跑 exit 0（门禁片段位于 `assets/framework-gates/<fw>.sh`，已注入到 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块）④ `dev-guide.md` §10 含该框架约束段 ≥ 3 条。任一不过 → 回 Step 4.5**。**如有残留，回到 Step 7 继续填充，直到零残留。**

> **铁律**：用户不编辑任何配置文件，不手动复制模板。开始新需求时对 AI 说"开始新需求 xxx"，AI 自动创建 spec 文件 + 引导填写 + 运行门禁。门禁误报 AI 自动调 conf 后重跑。每节点须有降级策略（联网/云端不可用→降级本地工具）。节点工具表+降级表见 `references/claude-code-capabilities.md` §十五。**全链路追踪：AI 每进入一节点先公告（`→ [节点X] 调用 …`）并用 `scripts/trace-log.sh` 节点级落盘 `.swarm-yuan/trace.jsonl`（`SWARM_YUAN_TRACE=verbose` 时含每次具体调用）——用户全程可见调用了何种工具及技能，无需任何确认。**

## 六段式模板

生成的目标技能结构（六段式）：

| 段 | 文件 | 作用 |
|----|------|------|
| meta | `SKILL.md` | 元信息、铁律、流程总览、命令速查 |
| workflow | `references/workflow.md` | 节点化流程（10 要素/节点，含★调用追踪 + 4-Phase SOP）——生成时填充 |
| reference | `references/*.md` | 参考手册（目录/安全/编译/**全量组件库**/**依赖链路+约束（按形态选模型）**/**全量接口端点**/**全量store+类型** + 数据 + 方法论 + 认知 + 领域知识） |
| reference | `references/framework-knowledge.md` | **按激活框架实例化的规律与门禁依据**（骨架由 AI 在 Step 4.5 框架深化阶段依据 `references/frameworks/<fw>.md` §3+§4 构建，逐条用项目代码验证实例化；`--inject-frameworks` 只注入门禁片段到 precheck.sh，不生成此文件骨架） |
| assets | `assets/*` | 模板（spec/plan/分支/环境/库表/状态机） |
| check | `scripts/precheck.sh` | 49 个门禁子命令（核心 10 + 架构 17 + 合规 17 + advisory-only 4：`--compliance` 标准合规矩阵核验 / `--docs-pack` 文档包清单 / `--sbom` SBOM 生成+许可证块名单 / `--privacy` 个人信息扫描 / `--authz` 授权类弱点 / `--requirements` 需求质量（29148）/ `--crypto` 密码算法合规（GB/T 39786）/ `--rtm` 需求追溯矩阵（29148 RTM）/ `--release-sign` 发布签名+provenance（SLSA L2 / SSDF PS.2）/ `--dengbao` 等保 2.0 控制点（GB/T 22239，fail-closed+豁免留痕）/ `--pia` 隐私影响评估（个保法 55-56，fail-closed）/ `--sast-deep` 深度 SAST（semgrep→opengrep→内置降级链）/ `--oss-eval` 开源代码安全评价（GB/T 43848，复用 --sbom 产物），随 `--all-full` 执行（标准 27：核心 10+架构 17）；合规 17 独立 `--compliance-suite` 按需执行，未配置静默跳过；另含 `--shift-left` 左移：测试设计/变更影响/可观测性） + **框架门禁片段注入区**（`# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块，由 `--inject-frameworks` 写入）。**门禁分层（决策 19，横切维度）**：strict 17（真 fail）/ warn 21（混合）/ advisory 10（永不 fail，子shell 内重定义 fail/warn 为纯 echo）；`--list-gates` 列三档分层；`scripts/gen-enforce-level.sh` 按 fail() 数自动归类（幂等）。 |
| scripts | `scripts/*` | 工具箱（门禁+状态机+**调用追踪 trace-log.sh**+图谱+MCP+self-check） |

## 它整合的方法论（只引用调用，不重新实现）

swarm-yuan 整合 11 个外部运行时，按**接线深度分三层**（每层有自带降级载体，不假装全深接）：

| 层 | 运行时 | 真实接线方式 | 降级载体 |
|----|--------|-------------|---------|
| **深度接线（4）** | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用（`gitnexus query`/`graphify explain`/`claude-mem search`/`ocr review`），带 `has_*` 守卫 + 多级降级链 | grep+madge / progress ledger / 5 维度手动清单 |
| **CLI 接线（3）** | OpenSpec / comet / gsd-core | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`），带 `has_*` 守卫，未装或项目未用时降级 | 自带文档检查 / 自带 state-machine.sh / ocr+手动清单 |
| **方法论引用（4）** | superpowers / gstack / ECC / Ruflo | 作为方法论参考，AI 按 workflow 节点引用其模式（slash command 或文档指引）；swarm-yuan 自带等价降级载体 | 自带 subagent-orchestration.md / review-methodology.md / state-machine.sh |

OpenSpec（spec-driven）/ superpowers（subagent-driven）/ comet（state machine）/ gstack+OCR（review）/ graphify+GitNexus（code-graph）/ gsd-core（phase-loop+goal-backward）/ claude-mem（memory persistence）/ Ruflo（multi-agent swarm 编排）/ ECC（council 多声音认知扩展）。

> 工具引用铁律：深度+CLI 接线层（7 个）允许真实命令调用（`graphify`/`gitnexus`/`ocr`/`claude-mem`/`gsd-tools`/`openspec`/`comet`），不重新实现、不复制源码；方法论引用层（4 个）只引用模式不调 CLI。**代码图谱工具按技术能力选型（GitNexus 深度调用图 / graphify 广谱知识图，平权可按项目并用），不做授权驱动的降级**（决策 18，详见 `references/code-graph-tools.md` §选型）。

**reference 文件清单（按需读取）**：

| 用途 | 文件 |
|------|------|
| 探查指南（17 项特征卡 + 图谱工具 + **§C+ 详尽组件库清单与调用链路分析**） | `references/exploration-guide.md` |
| 六段式填充规范（生成后核对清单 + **§4/§5/§6 全量要求 + 编排约束核对**） | `references/template-spec.md` |
| 五层认知基底总览 | `references/cognition-framework.md` |
| 逻辑剃刀 + 谬误图谱 | `references/logic-razor.md` |
| 认知偏差 + 思维模型 | `references/cognitive-bias.md` |
| 领域知识速查（32 领域） | `references/domain-knowledge.md` |
| Claude Code 官方能力全量清单 | `references/claude-code-capabilities.md` |
| 安全规范（OWASP/STRIDE/CWE） | `references/security-spec.md` |
| 决策治理（三级分类+五要素+decisions.jsonl，对齐 ISO/IEC 42001） | `references/decision-governance.md` |
| subagent 编排模式 | `references/subagent-orchestration.md` |
| 代码审查方法论（5 维度） | `references/review-methodology.md` |
| 代码图谱工具引用 | `references/code-graph-tools.md` |
| 标准合规矩阵（GB/T 25000.51/8566/8567/9386 + 安全标准 × 49 门禁映射 + 豁免登记） | `references/standards-compliance.md` |
| gsd-core phase-loop/goal-backward | `references/gsd-patterns.md` |
| 跨会话记忆持久化 | `references/memory-persistence.md` |
| MCP 治理（默认最小化政策 + connector 书面理由） | `references/mcp-governance.md` |
| AI 过程信息项制度（8566 附录 A/B 扩展：prompt/diff/人工复核留痕） | `references/ai-process-records.md` |
| 金融行业 profile（法规/监管办法/JR/T 标准 ↔ 门禁映射 + finance.conf 配套） | `references/industry-profile-finance.md` |
| 医疗行业 profile（法规/卫健委办法/GB/T 39725 ↔ 门禁映射 + medical.conf 配套） | `references/industry-profile-medical.md` |
| 政务行业 profile（网安法 21 条/密评/个保法 55-56/GB/T 22239/39786/43848 ↔ 门禁映射 + gov.conf 配套） | `references/industry-profile-gov.md` |
| 汽车行业 profile（ISO 26262/UNECE R155-R156/GB/T 40855 ↔ 门禁映射 + automotive.conf 配套） | `references/industry-profile-automotive.md` |
| 能源行业 profile（GB/T 36572 十六字方针/IEC 62443 SL1-SL4/密评 ↔ 门禁映射 + energy.conf 配套） | `references/industry-profile-energy.md` |
| 框架规则库（生成时按 ACTIVE_FRAMEWORKS 读取对应 `<fw>.md`） | `references/frameworks/` |

## 使用说明

1. 确认目标项目路径与 skill 名称
2. `bash scripts/self-check.sh` 自检 11 项目运行时
3. 按需读 reference（探查→exploration-guide；填充→template-spec；方法论→各 reference 文件）
4. `scripts/generate-skill.sh <name> <project-dir>` 创建骨架（或 `--upgrade` 升级已有）
5. 按上方「生成流程」Step 0-12 全量执行（铁律：不可中途停在骨架；每步先公告调用 + trace-log 落盘），每段落盘后用 `template-spec.md` 末尾核对表验证

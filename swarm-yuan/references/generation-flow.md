# 生成流程 Step 详解（Step 0-8，13 节点）

> 本文件从 `SKILL.md` 折叠而出（上下文窗口自适应压缩，决策 32）。SKILL.md 正文只保留 ASCII 节点总览流程图 + 铁律散文；本文件是 Step 1-12 的逐节点详解，**按需读取**——AI 执行到对应 Step 时再读，不全量常驻上下文。
>
> 节点总览（SKILL.md 正文常驻）：
> ```
> ⓪自检(13运行时) → ⓪.5读取项目知识 → ①探查仓库 → ①.5项目形态判定+组件库+调用链 → ②提取17项特征卡 → ③create骨架 → ④AI填充全部文件 → ④.5框架深化 → ⑤AI配置precheck.conf → ⑤.5 AI生成hooks/commands/MCP → ⑥AI运行门禁 → ⑦.5门禁注入 → ⑦AI写回记忆 → ⑧AI最终检查
> ```

## Step 1. 自检

`bash scripts/self-check.sh`（13 个运行时检测+自动安装）

## Step 2. 读取项目知识

AGENTS.md/CLAUDE.md/记忆/agent 运行时（若有） → 提取规则写入特征卡（不读=重复造轮子）

## Step 3. 探查仓库

三路并行子代理（结构/规范/代码组织），优先用 gitnexus/graphify/claude-mem/LSP，大型项目用 Dynamic Workflow 并行扇出。工具矩阵+降级策略见 `references/exploration-guide.md`。**★WP-P8 per-phase profile 探查分级**：按 `auto_detect_profile` 的判定结果分级——lite（文件数 <80 且无合规信号）单路探查不用图谱；standard（其余默认档）三路并行图谱可选；compliance（合规关键词命中）三路并行 + 强制图谱工具。规模边界不确定按更重档处理（质量优先）。**★全链路追踪（设计理念 2）**：每路子代理启动前 AI 调 `bash scripts/trace-log.sh --node "探查" --actor "结构子代理" --tool "gitnexus context" --status started`（规范/代码组织子代理同理），完成后 `--status done`——用户可见每步调用何种工具，无需确认（trace 输出 stderr + 落盘 trace.jsonl，不阻塞主流程）

## Step 4. ★项目形态判定 + 详尽组件库清单 + 调用链路分析（探查的深化，不可跳过）

- **项目形态判定（§C+.0）**：探查文件类型/框架特征 → 判定含哪些维度（前端UI/后端API/异步消费/桌面IPC/移动端/库导出）→ 后续只枚举存在的维度
- **全量穷举（§C+.1 按维度动态）**：按判定结果选择的维度（C+.1-F前端/C+.1-B后端/C+.1-A异步/C+.1-D桌面移动/C+.1-L库/C+.1-T通用）做 `find`+`grep` 机械枚举 → 提取导出签名 → 每维度独立计数核验
- **调用链路分析（§C+.2 按形态选模型）**：前端(注册装配+模块矩阵+挂载树+store依赖) / 后端(请求处理管道+分层矩阵+数据流+外部依赖) / 异步(消息流转) / 微服务(跨服务调用链) / 桌面(IPC链路) / 库(导出依赖图)
- **编排约束推导（§C+.3 按形态选约束类别）**：前端约束 / 后端约束 / 异步约束 / 微服务约束 / 通用约束，每条标注代码证据
- **接口全量枚举（§C+.4 按接口形态适配）**：REST(逐端点) / GraphQL(逐resolver) / gRPC(逐method) / MQ(逐queue+handler) / 库(逐导出)，无通配符占位
- 优先用 `gitnexus context/trace` 或 `graphify path/explain` 系统性提取签名与依赖链，而非随机 grep

## Step 5. 特征卡

17 项（项目类型→…→可复用稳定单元→…→编排约束→详尽组件库清单），P0 六项（1/4/5/11/15/16）每项落到具体值不用占位符；P1 十一项 draft 期可「（P1 待补）」，`--mark-active` 前清零。映射表见 `references/template-spec.md` §3

## Step 6. 创建骨架

`bash scripts/generate-skill.sh <name> <project-dir>`（含 hooks/ + commands/ + precheck.conf）。`--profile auto|lite|standard|compliance` 四档，**默认 auto 项目级自适应**（合规关键词 → compliance；文件数 <80 → lite；其余 standard；**WP-Q2 偏置修正：信号明确才升档，模糊走默认 standard**，auto 会打印判定依据供用户评估）：**lite**（认知档）= 特征卡 + reference-manual + 核心门禁脚本最小集（无 hooks/commands/settings/.mcp.json）；**standard** = 全量骨架；**compliance** = standard + 标准合规矩阵参考（references/standards-compliance.md）。**零占位符铁律适用范围 = 当前 profile 的文件集**（profile 是显式声明不启用，与"未配置静默跳过"本质不同）。默认生成到 `<project-dir>/.claude/skills/`（"为目标项目生成"名副其实）；可用第 3 参数 `target-dir` 显式指定其他目录，如 `--upgrade <name> <project-dir> <target-dir>`。全局安装到 `~/.claude/skills/` 等运行时目录走 `install.sh`。

## Step 7. AI 填充全部文件

SKILL.md/codebase/dev-guide/release/reference-manual/workflow/snippets/mcp-tools——**每个文件必须用探查到的真实内容替换占位符**。填充指引见 `references/template-spec.md`。**reference-manual.md §4 构件表/§6 接口表/§9 store+类型表按形态动态填充（维度错配=未完成），§5 链路按形态选模型 + §5.1 约束注释，dev-guide.md §8 按形态选约束类别**

## Step 8. AI 配置 precheck.conf

**★WP-P4 脚本化初稿**——`generate-skill.sh create` 已调 `scripts/conf-render.sh` 渲染三件套初稿（每变量带 `# AUTO:detected`（嗅探所得）/ `# AUTO:default`（默认值）/ `# TODO:model`（语义型须人工）溯源注释）。模型只处理 `# TODO:model` 清单（LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量，须从特征卡推导）+ 审 diff 是否符合特征卡意图——从「写 171 行」变成「审 + 补少数」。审完后所有 `<占位符>`/`TODO:model` 必须替换为真实值

## Step 9. AI 集成 Claude Code

定制 generate-skill.sh 已生成的 hooks/hooks.json + commands/ + settings.local.json + .mcp.json 模板（脚本骨架已建，AI 补项目特定配置）+ workflow.md 节点标注。hooks 含 PostToolUse(Bash) failure-detector（失败模式机械检测：SPINNING/EXPLORING/MIXED 三态 + L1-L4 压力升级，借鉴 tanweai/pua 改写）+ PreToolUse 防作弊门（integrity-guard：受保护治理资产 deny/advisory 两档，借鉴 tanweai/pua 改写为 swarm-yuan 资产清单）。详见 `references/claude-code-capabilities.md`

## Step 10. AI 运行门禁

`precheck.sh --all`（核心 10）→ fail 自动修复重跑 → `--mark-active` 翻 active 后 `--all-full`（标准 27：核心 10+架构 17）；强监管交付按需追加 `--compliance-suite`（合规 17）。**★compliance 档 / 改治理资产 / 发布链路：强制走四权分离 agent 拓扑**（policy-guardian → action-executor → self-reviewer → verifier，借鉴 tanweai/pua 改写为立法/执法/司法三权隐喻，详见 `references/governance-agents.md`）——action-executor 只给 candidate_pass，最终 verifier_status 由 external harness/hook/human 定，防「自己改自己验收」。**★compaction 状态续传（借鉴 tanweai/pua builder-journal）**：PreCompact hook 自动 `bash scripts/state-machine.sh dump-journal` 把 phase/failure_count/peak_level dump 到 `.swarm-yuan/builder-journal.md`；SessionStart 自动 `restore-journal` 检测 <2h 的 journal 并恢复压力状态——压力不因 compaction 重置

## Step 11. AI 写回记忆

`bash scripts/memory-writeback.sh`（S9 实装，脚本兜底）三路写回 .swarm-yuan/project-knowledge.md / .zcode/memories/ / claude-mem，形成"记忆→生成→开发→记忆"闭环（best-effort，不阻塞主流程）

## Step 12. AI 最终检查

运行 `bash scripts/generate-skill.sh --verify-completeness <skill_dir>` 做零占位符 + workflow 调用追踪要素机器执法（命中即列 file:line 并 exit 1，零命中打印「✓ 零占位符确认」），确认零"待填充"/零"填充指引"/零"<占位符>"残留；**维度计数核验（WP-P2 脚本化）**：跑 `bash scripts/inventory-verify.sh <项目根> --skill-dir <skill目录> --form <§C+.0形态>`，全 PASS → 直接引用报告结论；FAIL（清单计数 < 枚举计数 × 0.95）→ 只针对失败维度回 Step 4 补漏；DIM_MISMATCH（声明形态与枚举结果矛盾）→ 回 §C+.0 重判形态。维度注册表见 `assets/inventory-dimensions.conf`（数据驱动，新增维度改注册表不改脚本）；**框架适配四要素核验**：对 ACTIVE_FRAMEWORKS 每个框架——① 构件枚举计数 ≥ 实际 × 0.95（依 `references/frameworks/<fw>.md` §2 的计数基准）② `framework-knowledge.md` 规律数 ≥ 规则文件声明的深度门槛且 100% 含"证据:"字段 ③ `precheck.sh` 含 `_fw_<id>_check` 动态分发器且 `--framework <id>` 实跑 exit 0（门禁片段位于 `assets/framework-gates/<fw>.sh`，已注入到 `# >>> swarm-yuan:framework-gates >>>` ... `# <<< swarm-yuan:framework-gates <<<` 标记区块）④ `dev-guide.md` §10 含该框架约束段 ≥ 3 条。任一不过 → 回 Step 4.5。**★Oracle Gate 循环（可选，借鉴 autoresearch + tanweai/pua pua-loop）**：self-check/precheck 持续 fail 时，用户可 `bash scripts/setup-loop.sh "修复任务" --verify 'bash scripts/self-check.sh --check-only'` 启动无限迭代模式——AI 输出 `<promise>SWARM_YUAN_DONE</promise>` 后，Stop hook 独立跑 verify_command，拒绝则 loop 继续 + 错误输出喂回，Stall Detection（5+ 次拒绝强制退回需求本身）。详见 `assets/hooks/setup-loop.sh --help`。**如有残留，回到 Step 7 继续填充，直到零残留。**

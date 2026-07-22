# swarm-yuan 范式定位（Paradigm Positioning）

> 版本：v1（2026-07-21，WP-P10）
> 目的：显式声明 swarm-yuan 的适用/不适用场景，把"过重"从缺陷转为显式适用域。

## 范式定位一句话

**swarm-yuan 是重量级范式，重量是设计选择不是缺陷——通过 profile 自适应让重量显式可选。**

## 适用场景

| 场景 | 为什么适用 | 推荐 profile |
|------|-----------|-------------|
| **团队协作项目（≥2 人）** | 16 项特征卡让多人共享项目认知；40 门禁守护分支质量；门禁是机器执法不依赖人自觉 | standard |
| **中大型项目（≥80 文件或 ≥3 形态）** | 详尽构件库清单 + 调用链路分析让 AI 懂项目结构；框架规则引擎覆盖 62 框架 | standard |
| **强监管交付（合规要求）** | 标准合规矩阵（GB/T 25000.51/8566/8567/9386 + 安全标准）；--compliance-suite 9 门禁；行业 profile（金融/医疗） | compliance |
| **长期维护项目（需沉淀记忆）** | claude-mem 三路写回形成"记忆→生成→开发→记忆"闭环；trace.jsonl 全链路追踪；cost-report 成本遥测 | standard |
| **多技术栈混合项目（微服务/全栈）** | §C+.0 形态判定动态适配；ACTIVE_FRAMEWORKS 按需激活；技术栈复杂度反作用 profile（WP-P9） | standard/compliance |

## 不适用场景

| 场景 | 为什么不适用 | 替代方案 |
|------|------------|---------|
| **个人脚本/一次性原型** | 40 门禁 + 16 特征卡的认知负担远超脚本本身的复杂度；ROI 为负 | 直接用 AI 裸写，不套范式 |
| **学习用 demo/教学示例** | 范式的价值在于"沉淀项目规则"，demo 无规则可沉淀 | 直接用 AI 裸写 |
| **极小改动（改 typo/调样式）** | spec 三级映射虽能判"简单"，但建 spec + 跑门禁仍比改动本身重 | 直接改，不走 spec 流程 |
| **无 AI 辅助的纯人工开发** | 范式设计为 AI 驱动（AI 主导 + 用户决策），纯人工无法消费 | 用传统 lint/test 工具 |

## 轻量替代方案

### 范式内轻量档（lite profile）

`--profile lite` 是 swarm-yuan 范式内的轻量档：
- 只建 `{references,assets,scripts}` 三目录（无 hooks/commands/settings/.mcp.json）
- 只拷核心门禁脚本最小集
- 只加载 core conf（不加载 arch/compliance）
- 任务门禁默认 `--all`（核心 10）

适合：个人项目但希望有基础门禁守护、或作为 standard/compliance 的起点（可后续 `--upgrade --profile standard` 升档）。

### 范式外轻量方案

1. **单文件 precheck.sh**：直接拷贝 `swarm-yuan/assets/precheck.sh` 到项目，配 `precheck.conf`，跑 `--all` 核心门禁——不套生成器、不建 skill 目录、不要特征卡。适合只要门禁不要认知基础设施的项目。
2. **传统工具链**：ESLint/Prettier（前端）、golangci-lint（Go）、pylint/black（Python）+ Git hooks——不依赖 AI，适合无 AI 辅助场景。
3. **AI 原生开发**：直接对 AI 说"帮我改这个 bug"——不套任何范式，适合一次性任务。

## "过重"的诚实评估

swarm-yuan 确实重（20k 行文档 + 22k 行脚本 + 40 门禁 + 151 变量 + 62 框架规则），这是设计选择：

- **重量的来源**：16 项特征卡（认知 DNA）+ 40 门禁（执法）+ 62 框架规则（领域知识）+ 11 运行时整合（工具链）——每个子系统都有明确职责，非冗余堆砌。
- **减重的努力**：WP-A 到 WP-P 系列（15+ 批次）持续减重——三档 profile 让重量显式可选、arch.conf 懒生成移除 38 空占位、catchphrase 单一事实源消除手抄漂移、任务类型/spec 规模/profile 漂移/技术栈复杂度多维自适应让范式按项目实际调整重量。
- **自适应的边界**：范式能按项目/任务/阶段自适应调整重量，但不能消除"认识项目"本身的开销——这是"AI 懂项目再写代码"理念的固有成本。

**结论**：如果你的项目值得 AI 先懂再写（团队协作/中大型/长期维护/强监管），swarm-yuan 的重量是合理投资；如果是一次性小任务，直接用 AI 裸写更高效。

## 决策记录

本定位声明记录在 `docs/paradigm-decisions.md` 决策 25。

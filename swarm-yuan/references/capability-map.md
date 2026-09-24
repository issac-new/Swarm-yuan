> **何时读我**：任何"该读哪个档 / 这能力从哪来 / 这运行时在哪被消费"的路由与对账问题。首行：# 能力地图（Capability Map）

# 能力地图（Capability Map）——references 吸收层接线台账

> **定位**：本表是 swarm-yuan 吸收层（46 档 references + 19 上游运行时）的**接线单一事实源**：每档标 来源→证据分级→消费节点→触发，self-check G25 双向对账（孤儿零容忍）。分工：**弧线表（SKILL.md 第四层）管核心概念的诞生步/消费方/回流点；本表管吸收层的档级接线**——两表粒度互补，纪律同一条：无悬空。**本表是生成器侧台账，不入 UNIVERSAL_FILES 随发**（目标技能只收到随发子集，台账描述的是生成器全量吸收面）。
> **证据分级**（R37 口径）：A=本机实测；B=官方一手直查；C=二手转述（未核验不进基线）。

## 一、整合视图：吸收物如何构成一个整体

吸收不是收藏——每档能力都归位在总闭环（探查→生成→执勤→指纹反馈）的某一环，缺了它那一环就弱。五族即五个闭环段：

| 族 | 回答的问题 | 闭环段 |
|----|-----------|--------|
| ① 生成主干 | 流A 怎么把仓库变成技能 | 探查/填充/生成（流A ⓪-⑫） |
| ② 拼装与知识消费 | 流B ②⑤怎么先查再写、知识怎么读 | 执勤生产段 |
| ③ 编排与治理 | 多 agent 怎么协作、纪律怎么守 | 执勤全程 + hooks |
| ④ 验证与过程资产 | ⑥⑦怎么证、审计留什么痕 | 验证司法段 |
| ⑤ 安全合规与行业 | 门禁依据什么标准、行业怎么立法 | 门禁执法段 |

族内档位互补关系在表中"触发"列可辨（如 memory-persistence 管跨会话记忆工具族 / knowledge-lifecycle 管项目知识四段协议 / context-engineering-layering 管规则放哪层——三者都关"知识"，粒度不同不重叠）。

## 二、references 接线总表（46 档，self-check G25 对账面）

### 族① 生成主干（流A）

| 档 | 来源（证据） | 消费节点 | 触发 |
|----|-------------|---------|------|
| exploration-guide | 内生 + semantica/graphify 借鉴（A） | 流A ⓪.5/①.5 探查（含 §C+.0.6/矛盾裁决） | 执行任何探查 |
| generation-flow | 内生（决策 32 折叠） | 流A Step 1-12 详解 | 生成流程逐步执行 |
| template-spec | 内生 + agent-skills 联动（A） | 流A ④ 填充六文件 | 填 spec/六文件 |
| agent-skills-methodology | addyosmani/agent-skills（B） | 流A ④ + 流B ⑤ | 反借口/假设前置/Prove-It |
| context-engineering-layering | Vibe编码文章 + Anthropic 文档（B/C） | 生成器自身配置分层 | 决定规则放哪层 |
| task-methodology-router | tanweai/pua 改写（A） | 流B 任务类型路由 | 任务类型判定 |
| cost-estimation-methodology | 人行科技司培训 + GB/T 42588（B） | spec §25 填充 | 规模/工作量估算 |
| domain-knowledge | 内生速查（A） | 流A ①.5 + --domain 门禁 | 领域规律推导 |
| code-graph-tools | GitNexus/graphify/codegraph 调研（A） | 流A ① 图谱优先 | 图谱工具选型 |
| togaf-metamodel-methodology | TOGAF BDAT（B） | §C+.0.6 四层视角 | 架构类变更探查 |
| frontend-design-methodology | pbakaus/impeccable（B） | 流A ④ + 流B ⑤ 前端 | 前端设计任务 |

### 族② 拼装与知识消费（流B ②⑤）

| 档 | 来源（证据） | 消费节点 | 触发 |
|----|-------------|---------|------|
| lazy-generation-methodology | ponytail 蒸馏 + 行者明灵文章（B） | 流B ⑤ 编码七层下探 | 写新代码前找零件 |
| cordis-composability-methodology | DeepSeek Harness（B） | 机制设计参考 | 设计可组合机制 |
| knowledge-lifecycle-methodology | 京东海博文章 + OKF 核验（B） | 流B ② 读法 + 反馈回路三态 | 知识读取/更新处置 |
| memory-persistence | claude-mem/ruflo/ECC 工具族（A） | ⑧ 记忆写回 + 溯源标记 | 跨会话记忆/蒸馏 |
| cognition-framework | 内生五层认知（A） | 流A ① 认知六阶链 | 探查建模 |
| cognitive-bias | 内生 + Kahneman 框架（B） | spec §16 自检 | 方案偏差自检 |
| logic-razor | 内生（A） | 方案删冗余假设 | 思维语言推演 |
| four-theories-methodology | 工程控制论等四源（B） | 生成器自身设计决策 | 划边界/评估门禁/认知面 |
| mea-loop-methodology | AMAP LongHorizon-Harness（B） | 长任务规划 + 审计引用 | 长任务拆解 |

### 族③ 编排与治理（流B 全程）

| 档 | 来源（证据） | 消费节点 | 触发 |
|----|-------------|---------|------|
| governance-agents | pua 四权分离 + §Z 五协议（A） | hooks/loop 治理拓扑 | 治理架构/交付纪律 |
| subagent-orchestration | superpowers/comet（A/B） | 流B ⑤ 复杂变更扇出 | subagent 编排 |
| gsd-patterns | gsd-core（A） | 计划验证/状态戳 | 计划/状态管理 |
| decision-governance | gsd-core + gstack（A/B） | UserChallenge 决策留痕 | 用户决策点 |
| dsh-engineering-methodology | DeepSeek Harness rc.8（B） | 审计/状态韧性设计 | 机制设计参考 |
| codex-methodology | openai/codex（B） | 执行纪律（缓存/截断） | 省 token/执行纪律 |
| claude-code-capabilities | claude-code releases 全量（B） | 宿主能力选型 | 查宿主原生能力 |
| mcp-governance | 内生（A） | .mcp.json 配置审计 | MCP 服务接入 |
| codex-security-methodology | openai/codex-security（A） | 安全扫描门禁接线 | 威胁建模/安全扫描 |

### 族④ 验证与过程资产（流B ⑥⑦⑧）

| 档 | 来源（证据） | 消费节点 | 触发 |
|----|-------------|---------|------|
| review-methodology | gstack review + cso（A） | ⑦ 独立审查 rubric | 代码审查执行 |
| canary-monitoring | check_canary 降档保留（A） | ⑨ 发布后监控（setup-loop --verify） | 发布后基线对比 |
| ai-process-records | GB/T 8566 扩展（B） | trace/decisions 留痕口径 | 审计/复盘/交接 |
| quality-management-standards | ISO 9001/CMMI 映射（B） | 认证过程资产引用 | 组织级标准对齐 |

### 族⑤ 安全合规与行业立法（门禁）

| 档 | 来源（证据） | 消费节点 | 触发 |
|----|-------------|---------|------|
| security-spec | OWASP/STRIDE/CWE 综合（B） | --security 门禁依据 | 应用安全规范 |
| crypto-spec | GB/T 39786 等国标（B） | check_crypto 判定依据 | 密码学选型/密评 |
| cwe-database | CWE 视图 799（B） | cwe_audit 门禁 | 弱点分级查询 |
| security-certification-profiles | 等保/PCI-DSS 等（B） | cert_audit 门禁 | 认证合规映射 |
| standards-compliance | GB/T 25000 系列映射（B） | compliance 档核验 | 标准合规矩阵 |
| industry-profile-finance | 金融法规调研（B） | --industry 真实加载 | 金融项目立法 |
| industry-profile-gov | 政务法规调研（B） | --industry 真实加载 | 政务项目立法 |
| industry-profile-medical | 医疗法规调研（B） | --industry 真实加载 | 医疗项目立法 |
| industry-profile-telecom | 电信法规调研（B） | --industry 真实加载 | 电信项目立法 |
| industry-profile-automotive | 汽车法规调研（B） | --industry 真实加载 | 汽车项目立法 |
| industry-profile-energy | 能源法规调研（B） | --industry 真实加载 | 能源项目立法 |
| industry-profile-industrial | 工控法规调研（B） | --industry 真实加载 | 工控项目立法 |
| industry-profile-payment | 支付法规 + hermes pay-team（B/A） | --industry 真实加载 | 支付项目立法 |

## 三、运行时接线表（供给侧见 upstream-baseline 19 行；此为消费侧）

| 接线深度 | 运行时 | 消费点 | 降级链 |
|---------|--------|--------|--------|
| 深度×4 | GitNexus / graphify | 探查图谱优先（code-graph-tools 三选型，codegraph 为 watch 备选） | 未装→静态扫描清单 |
| 深度×4 | claude-mem | ⑧ 记忆写回 sink 之一 | 未装→.zcode/project-knowledge 本地落盘 |
| 深度×4 | ocr | ⑥ 测试验证 5 审查维度 | 未装→4 维 |
| CLI×4 | OpenSpec | 节点②③ spec proposal/tasks 格式 | 未装→自有 spec-template |
| CLI×4 | comet | 工作流骨架仪式/resume-probe | 未装→state-machine.sh |
| CLI×4 | gsd-core | 计划验证/STATE 戳模式 | 未装→tasks.md checkbox |
| CLI×4 | codex-security | 安全扫描门禁子进程 | 未装→grep 级安全模式 |
| 方法论×5 | superpowers / gstack / ECC / Ruflo / impeccable | 编排/审查/记忆蒸馏/前端设计方法论引用 | 无运行时依赖（纯文档） |
| 机制源×6 | dsh / pua / semantica / ponytail / codegraph / 文章源 | 已蒸馏为 references 各档（见上表来源列） | 同上 |

## 四、对账纪律（self-check G25 机器执法）

1. references/*.md（不含 frameworks/ 与本表自身）每个 basename 必须出现在本表——吸收必接线，孤儿零容忍；
2. 本表提及的每个档名必须实存——台账不登记幽灵；
3. SKILL.md 第六层必须引用本表——路由表与台账两级互指。

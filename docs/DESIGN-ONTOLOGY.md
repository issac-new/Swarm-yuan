# swarm-yuan 的本体论（Ontology）——用正式本体论工具把系统讲清楚

> **文档性质**：swarm-yuan 的正式本体论刻画——不是借用"本体论"一词的日常含义（"本质是什么"），而是使用本体论学科（哲学传统 + 本体论工程传统）的严格工具：范畴（category）、实体（entity）、实例化（instantiation）、部分学（mereology/parthood）、依赖（dependence）、表征/关于性（representation/aboutness）、本体论承诺（ontological commitment）。
> **与 DESIGN-LOGIC.md 的关系**：那份文档给的是**动力学刻画**（闭环流 + 坐标系）；本文给的是**范畴刻画**（存在什么、什么依赖什么、什么关于什么）——两者正交互补，共同构成完整刻画。
> **调研来源**：BFO（Basic Formal Ontology，continuant/occurrent/依赖 Continuant 分类）、DOLCE（descriptive ontology，particulars/qualities/modes）、部分学（Stanford Encyclopedia of Philosophy, Varzi）、Quine 本体论承诺（"to be is to be the value of a bound variable"）、Palantir 本体论工程（Objects/Links/Actions 二分原语，R11 调研一手引用）。来源链接见文末。

---

## 一、本体论承诺（这个理论承诺什么存在）

Quine 的准则：一个理论的本体论承诺 = 其量化变量所遍历的实体（[SEP: Ontological Commitment](https://plato.stanford.edu/entries/ontological-commitment/)）。

swarm-yuan 的理论（SKILL.md/DESIGN.md/脚本全部断言）量化遍历这些实体类型——**这就是它的本体论承诺清单**：

| 承诺的实体类型 | 例证 | 证据（量化出现处） |
|---------------|------|-------------------|
| 代码仓库（project） | 任意目标仓库 | `PROJECT_DIR` 变量、探查的一切命令 |
| 项目组件（component） | `src/main.ts`、导出函数、store | 地图行、inventory 枚举、计数核验 |
| 目标技能（skill） | SKILL.md + 地图 + rules.d + hooks | 生成器一切产出 |
| 规则（rule） | `rules.d/*.rules` 行 | gate-rules 求值器遍历 |
| 门禁（gate） | check_* 函数族 | ALL_GATES_* 序列遍历 |
| 决策（decision） | decisions.jsonl 行 | decision-audit 遍历 |
| 追踪事件（trace event） | trace.jsonl 行 | cost-report/gate-trends 遍历 |
| 会话（session） | 开发会话 | hooks 生命周期 |
| 目标（goal） | goal_id | audit-closure 遍历 |
| 框架（framework） | vue/koa/... | ACTIVE_FRAMEWORKS 数组 |

**刻意不承诺的**（重要——本体论节俭）：AI 的"理解"或"认知状态"（不可观测，只承诺其行为证据）；"项目的心智模型"（只承诺表征它的地图制品）；"分数化的认知能力"（R13 已退役）。

## 二、两大基本范畴（BFO 的 continuant / occurrent 划分）

BFO（[Basic Formal Ontology](https://en.wikipedia.org/wiki/Basic_Formal_Ontology)，[IEEE/MIT Press 教程](http://ieeexplore.ieee.org/document/7288715/)）把一切实体分为两个顶级范畴，这个划分恰好消解了 swarm-yuan 叙事里"静态结构 vs 动态流程"的长期张力：

### 2.1 Continuant（持续体——在时间中持存，任意时刻整体在场）

| 子类（BFO 细分） | swarm-yuan 实例 |
|------------------|-----------------|
| **独立持续体**（independent continuant，不需要其他实体承载即可存在） | 代码仓库、生成器、目标技能、rules.d、hooks、conf 文件、宿主 CLI |
| **特定依赖持续体**（specifically dependent continuant，系于单一承载者——如性质、倾向、功能） | **项目的稳定性**（"禁止改"标注——系于具体组件路径）；**技能的 draft/active 状态**（系于该技能）；**组件的 fan-in/churn 倾向**（stability-audit 的三信号） |
| **类依赖持续体**（generically dependent continuant，可多承载者复制——如文本、文件内容） | **探查方法论**（references/ 中的知识，可拷贝进任意生成物）；**框架规则**（74 份规则可注入任意技能）；**规则模式**（rules 行格式本身） |

### 2.2 Occurrent（发生体——在时间中展开，有时间部分）

| swarm-yuan 实例 | 时间部分结构 |
|-----------------|-------------|
| 生成过程 | Step 0-8 的时间部分 |
| 开发会话 | turn 的时间部分 |
| 单次门禁执行 | check 调用的起止 |
| 审计闭环 | goal 从 open 到 closed 的展开 |
| 自成长周期 | 感知→判断→更新→落基线 |

**关键洞察**：此前"两体系统 vs 闭环流"的表述张力，正是 continuant/occurrent 的范畴区分——两体系统是**持续体的分布描述**（哪些实体住在哪），闭环流是**发生体的过程描述**（过程如何展开）。它们不是两种设计，是同一本体在两个顶级范畴上的投影。BFO 为此提供两种独立的 parthood 关系（continuant part of / occurrent part of），本设计恰好也需要两种"部分"语言。

## 三、部分学（Mereology——部分与整体）

部分学是关于 parthood 关系的形式研究（[SEP: Mereology](https://plato.stanford.edu/entries/mereology/)，Varzi）。swarm-yuan 的部分-整体结构：

### 3.1 Continuant 部分（结构性部分）

```
目标技能（整体）
 ├─ SKILL.md（部分：入口）
 ├─ 地图 reference-manual.md（部分：表征性部分，见 §四）
 ├─ rules.d/*.rules（部分：规范性部分）
 ├─ scripts/*（部分：工具性部分）
 ├─ hooks/hooks.json（部分：挂载性部分——挂到宿主而非自含）
 └─ settings.local.json（部分：权限性部分）
```

生成器的部分学：探查知识库 / 渲染脚本 / 自检 / 决策史文档——注意 docs/research/ 是生成器的**历史部分**（记录性部分），不是功能性部分。

### 3.2 Occurrent 部分（过程性部分）

```
审计闭环（整体过程）
 ├─ 感知阶段（时间部分）
 ├─ 判断阶段
 ├─ 更新阶段
 └─ 落基线阶段（过程边界）
```

生成过程的 13 节点是 occurrent 的**时间部分**；workflow 的 8 节点是使用过程的模板化时间部分。

### 3.3 部分 ≠ 成分（constitution，借鉴 [Baker](https://people.umass.edu/lrb/files/bak02onmS.pdf) / [Evnine](https://kathrin-koslicki.squarespace.com/s/Simon-Evnine-Constitution-and-Composition.pdf) 的区分）

- 目标技能的**部分**是 SKILL.md/地图/rules（移除即残缺）
- 目标技能的**构成材料**（constitution）是 Markdown 文本 + bash 脚本字节（换一种 markup 语法不改变技能这个整体——正如大理石构成雕像但不是雕像的部分）
- 这个区分有工程后果：税制预算约束的是**构成材料的认知负载**（字节/概念），不是部分数量（部分数由功能决定）

## 四、核心关系目录（实体间的关系类型）

这是本体刻画的核心——比实体清单更重要，因为 swarm-yuan 的设计本质全在关系上：

| 关系 | 含义 | 实例 | 设计机制承载 |
|------|------|------|--------------|
| **表征 / 关于**（represents / is-about） | 一物以另一物为内容 | 地图 **关于** 代码仓库 | 这是全系统最核心的关系：地图是仓库的**部分表征**（组件/接口/约束维度），path-check 验证表征的**指向完整性**（反引号路径必须实存），计数核验 0.95 验证表征的**覆盖度**，stability-audit 验证表征的**时效一致性**（标注 vs churn 信号） |
| **生成**（generates） | 过程产出持续体 | 生成过程 generates 目标技能 | 生成器是**倾向性实体**（disposition）：它"能够"生成，每次生成过程实现（realize）这个倾向——BFO 的 realizable entity 框架 |
| **依赖**（dependence，BFO rigid distinction） | 一物的存在需要另一物 | 见 §五（依赖细目，系统最精妙处） | fingerprint/digest 链都是**依赖的机器化锚定** |
| **约束 / 治理**（governs） | 规范性关系：规则约束行为 | rules.d **governs** AI 的命令行为；门禁 **governs** 合入 | 规范性关系不是描述性的（说"仓库里有 vue"）而是规定性的（"vue 项目必须 scoped CSS"）——这是 Hume 是/应当区分在设计中的体现 |
| **记录**（records） | 账本行记录发生体 | decisions.jsonl 行 records 一次决策 | 账本是 **occurrent 的 continuuant 化**：把流逝的过程固化为可审计的持久记录——这是审计层的本体论基础 |
| **实例化**（instantiates） | 个例落类型 | 某次 `git push` 命中 `git push *` 规则 | gate-rules 求值即模式匹配的实例化判定 |
| **挂载**（mounted-in） | 部分寄宿于外部整体 | hooks **mounted-in** 宿主 CLI | 宿主下沉关系：技能的部分挂到 Claude Code/Codex 的生命周期上 |

## 五、依赖细目（系统的本体论粘合剂）

BFO 的依赖区分（[specifically/generically dependent continuant](https://www.virtualflylybrain.org/term/specifically-dependent-continuant-bfo_0000020/)）在 swarm-yuan 有精确对应，且**每条依赖都有机器化锚定**——这是本设计区别于一般文档系统的关键：

| 依赖类型 | 陈述 | 机器锚定（依赖断裂的可检测点） |
|----------|------|-------------------------------|
| **特定依赖**：地图 depends on 仓库的特定状态 | 地图表征的是**那个时刻**的仓库 | `project-fingerprint`（骨架 cksum 快照）——仓库变了，旧地图的特定依赖断裂，--diff 报告变化 scope |
| **特定依赖**：标注 depends on 组件的特定行为倾向 | "禁止改"标注系于该组件的稳定性 | `--stability-audit`（churn/fan-in/测试三信号与标注矛盾 → STABILITY_WARN）——组件行为变了，标注的依赖断裂 |
| **类依赖**：生成物中的方法论 depends on 生成器版本（类型级） | references 拷贝是生成器知识的**一个拷贝** | `.swarm-yuan-version` 的 `source_repo` + `--upgrade` 机制——生成器升级后旧拷贝过时 |
| **链式依赖**：decisions 依赖 trace 的特定末态 | R15 的 digest 链 | `ref_trace_hash`——trace 被篡改，decisions 的锚失配，全链 stale 可检出 |
| **时序依赖**：账本行依赖其记录的过程真实发生 | 留痕的诚实性 | gate-audit 全量决策审计（invoked/result 配对）——没有配对过程的行是可疑的 |
| **反事实保护**：好基线不依赖当前（可能坏的）扫描 | last-good 原则 | 骤降 >50% 拒绝 --write（保留 last-good）——**本体论表述：拒绝让坏状态的特定依赖覆盖好状态的特定依赖** |

**这一节是全系统的本体论粘合剂**：五轮"过重"诊断期间的多数漂移 bug（12 vs 13、fact 6355 vs 6393），本质都是**某条依赖失去了机器锚定**——文档声称的与代码实存的之间没有断裂检测。R13-R15 的机制建设（fingerprint/audit/digest/版本戳）可以统一理解为：**为每条本体论依赖配置机器可检测的锚**。

## 六、语义/动能二分（Palantir 本体论工程对照）

R11 调研发现 swarm-yuan 与 Palantir Foundry 本体论（[官方文档](https://palantir.com/docs/foundry/ontology/overview/)）结构性同构——用其语义/动能原语二分来对照（[R11 报告](../docs/research/R11-palantir-mapping.md) §1.1 一手直引）：

| Palantir 原语 | 定义 | swarm-yuan 对应物 |
|---------------|------|-------------------|
| **Objects/Properties/Links**（语义原语：名词） | 类型化实体+属性+关系 | 地图条目（组件对象）/ 标注（属性）/ 调用链（Links——类型化关系免 ad-hoc join） |
| **Actions**（动能原语：受治理/留痕的状态变换） | 可回写、必审计 | 门禁拦截/rules 判定/hooks deny——每次状态变换留 gate-audit 行 |
| **Functions**（版本化业务逻辑） | 可复用可版本 | check_* 函数族 + facts.conf 版本锚 |
| **标记沿谱系传播** | security 是数据本身的属性 | 决策 28 的 stable-diff 下游传播（R11 吸收的谱系传播 warn） |
| **AI 经本体论行动**（非自由形式） | AI 的动作空间被类型化对象约束 | **这正是 rules.d 三值的哲学**：AI 的命令空间被规则类型约束，FORBID 消息带替代方案 = 在受约束空间内指路 |
| **数字孪生 / "世界不是软件"** | 本体连接现实对应物 | 地图是仓库的数字孪生；§C+.0 形态判定承认"项目世界先于范式" |

**最重要的对照**：Palantir "你建不出绕过安全的看板，因为看板读的是受治理的对象" ↔ swarm-yuan "AI 做不出绕过门禁的合入，因为命令过的是受治理的 rules.d"——**治理内建于对象/关系，而非外挂检查**。这是把安全/质量从"边缘检查"（RBAC 式）转为"属性随行"（标记随数据传播）的本体论决策。

## 七、完整刻画（一段话，本体论版）

> swarm-yuan 承诺一个由**代码仓库、组件、目标技能、规则、门禁、账本行、目标**构成的世界（§一本体论承诺）。世界分两个顶级范畴：**持续体**（仓库/技能/rules——含系于单一承载者的特定依赖持续体如稳定性标注，与可多承载的类依赖持续体如方法论拷贝）与**发生体**（生成/会话/审计/成长过程）（§二）。目标技能是一个整体，其部分包括入口、表征性部分（地图）、规范性部分（rules）、挂载性部分（hooks 挂宿主）；构成材料是 Markdown+bash 字节，税制约束的是构成材料的认知负载而非部分数（§三）。实体间核心关系是**表征**（地图关于仓库——path-check 验证指向、计数验证覆盖、stability 验证时效）、**生成**（生成器作为可实现的倾向，每次生成实现之）、**规范性治理**（rules 治理命令空间——是/应当区分的工程化）、**记录**（账本把发生体固化为持续体——审计的本体论基础）、**挂载**（hooks 挂宿主）（§四）。系统的粘合剂是**依赖**——六类依赖每类配机器锚（fingerprint/audit/digest/版本戳/last-good），使一切"声称的关联"都有"断裂可检测性"（§五）。与 Palantir 本体论同构：治理内建于对象与关系（标记随行而非边缘检查），AI 经类型化约束行动而非自由形式（§六）。

## 八、自检问题（本体论版，补进 DESIGN-LOGIC.md 四问之后）

5. 新机制承诺了**什么新实体类型**？（进入 §一清单需谨慎——本体论节俭）
6. 它是**描述性的还是规范性的**？（描述=地图式表征；规范=rules 式治理——混写会产生"地图里藏规则"的层次混乱）
7. 它引入的**依赖**有没有机器锚？（无锚的依赖 = 未来漂移 bug 的预定位置）
8. 它是让**发生体固化为持续体**（记账），还是让**持续体参与新发生**（用账本驱动改进）？

## 调研来源

- BFO：[bfo-ontology.github.io](https://bfo-ontology.github.io/) / [Wikipedia: Basic Formal Ontology](https://en.wikipedia.org/wiki/Basic_Formal_Ontology) / [Introduction to BFO I: Continuants (IEEE)](http://ieeexplore.ieee.org/document/7288715/) / [BFO:0000020 specifically dependent continuant](https://www.virtualflybrain.org/term/specifically-dependent-continuant-bfo_0000020/)
- 部分学与构成：[SEP: Mereology (Varzi)](https://plato.stanford.edu/entries/mereology/) / [Wikipedia: Mereology](https://en.wikipedia.org/wiki/Mereology) / [Baker, On Making Things Up](https://people.umass.edu/lrb/files/bak02onmS.pdf) / [Evnine, Constitution and Composition](https://kathrin-koslicki.squarespace.com/s/Simon-Evnine-Constitution-and-Composition.pdf) / [Canavotto, Extensional Mereology for Structured Entities](https://link.springer.com/article/10.1007/s10670-020-00305-5) / [Guizzardi et al.](https://nemo.inf.ufes.br/wp-content/papercite-data/pdf/ontological_foundations_for_conceptual_part_whole_relations__the_case_of_collectives_and_their_parts_2011.pdf)
- 本体论承诺：[SEP: Ontological Commitment](https://plato.stanford.edu/entries/ontological-commitment/) / [Britannica: Quine's Criterion](https://www.britannica.com/topic/Quines-criterion-of-ontological-commitment)
- DOLCE 与基础本体：[Foundational ontologies in biomedical research (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10712036/) / [UCGIS Foundational Ontologies](https://gistbok-ltb.ucgis.org/current/print/concept/FC-03-001)
- Palantir 本体论工程：[Ontology Overview](https://palantir.com/docs/foundry/ontology/overview/) / [Why create an Ontology?](https://palantir.com/docs/foundry/ontology/why-ontology/) / [Ontology Architecture](https://palantir.com/docs/foundry/object-backend/overview/) / 本仓 R11 报告（一手直引）
- 关于性：[Berto, Aboutness in Imagination](https://link.springer.com/article/10.1007/s11098-017-0937-y) / [Sandgren](https://journals.publishing.umich.edu/ergo/article/id/2918/print/)

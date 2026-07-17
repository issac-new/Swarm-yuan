# swarm-yuan 框架规则引擎设计（Framework Rules Engine）

> 日期：2026-07-17 ｜ 分支：`feat/framework-rules-engine` ｜ 状态：待评审
> 解决问题：实测中 swarm-yuan 生成的目标 skill 对特定开发框架（lombok、spring-batch、mybatis、sharding-jdbc 等）适应性不足——框架知识是否产出、产出多深、门禁有无实现，全凭生成时 AI 临场发挥，质量不可控。

## 1. 背景与根因诊断

swarm-yuan 在 commit `6114ad8` 已建立 v1 框架适配（§C+.0.5 框架探查 + 20 个框架规则集 + precheck.conf 框架变量段），但存在 5 个断层：

| # | 断层 | 证据 |
|---|------|------|
| 1 | **门禁断层**：precheck.conf 定义了 ACTIVE_FRAMEWORKS 等 8 个框架变量，但模板 `assets/precheck.sh` 完全未消费（0 处 framework 匹配） | 生成时门禁全靠 AI 即兴手写。ncwk-dev 碰巧手写了 28 项检查（`_fw_vue_check` 等），Java 项目生成时无章可循 |
| 2 | **产物断层**：`framework-knowledge.md` 不在六段式模板内（template-spec.md / generate-skill.sh / SKILL.md 均未提及） | ncwk-dev 的该文件是生成时即兴发明，是否产出、多深全凭运气 |
| 3 | **深度断层**：domain-knowledge.md 每框架仅 5-6 条"分析起点"规律 | 无最低深度标准（枚举/约束/门禁/领域知识四要素不齐）、无 §C+.1 式计数核验 |
| 4 | **覆盖断层**：仅 20 个框架规则集，偏 Java 后端 + 少量前端 UI 库 | 缺 NestJS/Express/Fastify/Django/Flask/FastAPI/Gin/Gorm/Angular/Next.js 等；Java 侧缺 Spring Cloud/Security/JPA/MapStruct/XXL-Job/Seata/Sentinel；数据侧缺 Kettle/Flink/Paimon |
| 5 | **验证闭环断层**：生成流程 Step 12 最终检查不含框架适配验证；`--domain` 门禁只 grep"因为/证据"关键字 | 框架维度错配/浅填充无法被自动发现 |

**根因一句话**：ncwk-dev 的高质量框架适配是"那次生成时 AI 认真即兴手写"的产物，范式本身没有把它制度化。

## 2. 设计目标与验收标准

### 2.1 目标（用户已确认）

- **落点**：改 swarm-yuan 范式仓库（本分支），并用增强后的范式 `--upgrade` 回灌已生成的 ncwk-dev（作为升级路径的实测验证）
- **深度标准**：每个激活框架**四要素齐备 + 量化门槛**——①特定构件枚举（带计数核验）②开发约束（写入 dev-guide §10）③门禁实现（precheck.sh 真实代码，非占位）④领域规律（≥10 条带代码证据）。缺一项 = 生成未完成
- **覆盖**：全栈均衡 ~56 框架（见 §6）
- **调研方式**：联网调研官方文档 + 版本区间标注；规律标注适用版本；无法确认的标"待验证"而非臆造

### 2.2 非目标

- 不改动 swarm-yuan 的 26 门禁总体结构与五层认知框架
- 不追求框架数量凑整；质量门槛（≥10 规律/框架）优先于数量
- 不在生成时联网（规则库全内置，离线可用）；联网调研只发生在范式自身维护时

## 3. 总体架构与数据流（方案 A）

新增两个库 + 改造七个既有文件：

```
swarm-yuan/
├── references/frameworks/          ★新增：框架规则库（~56 个 .md，每框架 1 文件）
│   ├── _template.md                   规则文件模板（六段式，见 §4.1）
│   ├── mybatis.md / spring-batch.md / lombok.md / sharding.md / ...
├── assets/framework-gates/         ★新增：门禁片段库（~56 个 .sh，每框架 1 片段）
│   ├── mybatis.sh                   含 _fw_mybatis_check() 真实实现
│   └── ...
├── assets/precheck.sh              改造：内置 check_framework() 调度器 +
│                                    _fw_resolve_globs/_fw_grep_count 公共函数
│                                    （从 ncwk-dev 反哺的已验证实现）
├── assets/precheck.conf            改造：框架变量段通用化（约定式命名，见 §5.4）
├── scripts/generate-skill.sh       改造：新增 --inject-frameworks 注入逻辑
├── references/exploration-guide.md 改造：§C+.0.5 信号表迁移为索引，指向规则库
├── references/domain-knowledge.md  改造：20 框架段瘦身→索引，指向 frameworks/
└── references/template-spec.md     改造：framework-knowledge.md 正式入六段式模板
    SKILL.md                        改造：六段式表格 reference 行补 framework-knowledge.md
```

生成时数据流：

```
§C+.0.5 框架探查 → ACTIVE_FRAMEWORKS=[mybatis, lombok, sharding, ...] + 各框架版本号
   ↓
逐框架读 references/frameworks/<fw>.md（Step 4.5 框架深化）
  ①信号确认 ②执行构件枚举命令(计数核验) ③规律种子→项目代码验证→实例化(附证据)
   ↓
generate-skill.sh --inject-frameworks（Step 7.5，生成/--upgrade 共用，幂等）
  → assets/framework-gates/<fw>.sh 片段注入目标 precheck.sh 标记区块
  → 生成 references/framework-knowledge.md 骨架（规律种子，AI 实例化后填充）
  → precheck.conf 填充框架变量
   ↓
Step 12 验收闭环（四要素量化核验，不过 → 回 Step 4.5）
```

**ncwk-dev 反哺**：ncwk-dev 手写的 7 个框架检查函数（vue/naiveui/pinia/koa/socketio/vite/vitest）是已实战验证的实现，先反向收割进 `assets/framework-gates/` 作为片段库种子（仅补契约头注释），再经注入机制回灌 ncwk-dev——回灌零回归，片段库起步即有 7 个高质量样本。

## 4. 格式契约

### 4.1 规则文件 `references/frameworks/<fw>.md` —— 六段式结构

```markdown
---
ruleset_id: mybatis
适用版本: MyBatis 3.5.x / MyBatis-Plus 3.5+（差异单独标注）
最后调研: 2026-07-17（来源：官方文档 3.5.19 / MP 3.5.12）
---

# <Framework> 规则集

## §1 探查信号（→ §C+.0.5 激活依据，含置信度）
| 信号类型 | 模式 | 置信度 |
| 依赖 | mybatis-spring-boot-starter / mybatis-plus-boot-starter | 高 |
| 注解 | @Mapper / @MapperScan / @TableName | 高 |
| 文件 | **/*Mapper.xml | 中（需排除他用） |
| 配置 | mybatis.mapper-locations / configuration: 节点 | 高 |

## §2 特定构件枚举（命令 + 计数核验方式）
- Mapper 接口 / XML 映射（计数核验基准）/ TypeHandler / 拦截器 / 分页插件 ...

## §3 领域规律（≥10 条，每条五要素）
### 规律：<标题>
- **适用版本**: 如"全版本"或"MP 3.5.7+"
- **规律**: ……
- **违反后果**: ……（尽量挂 CWE/官方 issue 依据）
- **验证方法**: 具体 grep/read 命令（即"代码证据"的采集方式）
- **对应门禁**: fw_<ruleset_id>_<rule>（fail/warn 级）或"人工检查"

## §4 门禁清单（id / 级别 / 实现逻辑 / 依赖 conf 变量）
| 门禁 id | 级别 | 实现逻辑 | 依赖变量 |
（门禁 id 命名规范：fw_<ruleset_id>_<rule>）

## §5 跨框架交互规则
| 交互对 | 规则 | 理由 |
（如 mybatis × sharding：DML WHERE 须含分片键；lombok × jpa：@Data 排除懒加载关联字段）

## §6 版本陷阱速查
| 版本 | 变化 | 影响 |
```

三条硬约束：

1. §3 每条规律**必须挂门禁 id 或标注"人工检查"**——不允许"写了规律但没有执法"
2. §4 每个门禁 id 必须在 `assets/framework-gates/<fw>.sh` 中有**同名实现**（命名一一对应，可被脚本机械核验）
3. §3 规律数 **≥10**；部分框架规律更成熟，门槛更高（如 spring-boot/mybatis/vue/react ≥15）。具体门槛由各规则文件头部 `深度门槛` 字段显式声明，未声明时默认 ≥10，避免歧义

### 4.2 门禁片段 `assets/framework-gates/<fw>.sh` —— 注入契约

```bash
# ruleset: mybatis  requires_conf: MYBATIS_MAPPER_DIRS SQL_INJECTION_WHITELIST
# gates: fw_mybatis_dollar(fail) fw_mybatis_binding(fail) fw_mybatis_foreach(warn)
_fw_mybatis_check() {
  echo "  [mybatis] MyBatis 框架规律"
  # 实现只准使用：precheck.sh 公共函数（pass/fail/warn/
  # _fw_resolve_globs/_fw_grep_count）+ bash 3.2 兼容语法（三平台铁律）
  # 每条检查与规则文件 §4 的门禁 id 一一对应
}
```

**函数命名约定**：`_fw_<ruleset_id>_check`，其中 ruleset_id 的连字符转下划线（如 `spring-boot` → `_fw_spring_boot_check`）；片段文件名保留连字符（`spring-boot.sh`）。

注入机制（`generate-skill.sh --inject-frameworks`，生成/--upgrade 共用）：

- 目标 `precheck.sh` 内设标记区块 `# >>> swarm-yuan:framework-gates >>> ... # <<< swarm-yuan:framework-gates <<<`（仅目标文件有区块标记，片段文件自身不带嵌套标记），注入 = 幂等替换区块内容
- `check_framework()` 采用**动态分发**：遍历 ACTIVE_FRAMEWORKS，函数名经 `tr '-' '_'` 转换后用 `declare -f` 探测——存在则调用，**缺失则 fail**（探查到但没实现 = 范式缺陷，必须暴露）。无需重生成 case 分支，天然幂等
- 片段头部 `requires_conf` 注释被解析，自动核对 precheck.conf 是否声明对应变量，缺失则注入占位 + warn

### 4.3 反哺与回灌的零回归保障

ncwk-dev 现有 `_fw_vue_check` 等 7 个函数**原样收割**为片段库种子（仅补契约头注释）；回灌 ncwk-dev 时其手写实现被同名片段**等价替换**（内容相同，仅位置迁入标记区块）。回灌后 `--all-full` 26 门禁 + `--framework` 检查项逐项比对，**只允许增多不允许减少**。

## 5. 流程改造与验收闭环

### 5.1 生成流程 Step 增量改造

| 环节 | 现状 | 改造 |
|------|------|------|
| Step 4 §C+.0.5 框架探查 | 信号表 20 框架硬编码在 exploration-guide | 信号表迁移至各 `frameworks/<fw>.md §1`，exploration-guide 只留**信号汇总索引**（由脚本机械生成）；探查时**额外记录各框架版本号**（pom.xml/package.json/go.mod），用于规律版本区间匹配 |
| **Step 4.5（新增）框架深化** | 无 | 逐激活框架：读规则文件 §2 执行构件枚举+计数核验 → §3 规律种子逐条用项目代码验证（成立→实例化附证据；不成立→剔除并记录原因；区间外→标"待验证"）→ 产出填入 framework-knowledge.md |
| Step 7 填充 | framework-knowledge.md 不在模板 | template-spec.md 正式定义该文件：`--inject-frameworks` 生成骨架（规律种子），AI 在 Step 4.5 实例化后填充；**残留未实例化种子 = 占位符，零容忍** |
| **Step 7.5（新增）门禁注入** | 无（靠 AI 手写） | `generate-skill.sh --inject-frameworks`：片段注入标记区块 + 重生成 case 调度 + 校验 precheck.conf 变量声明 |
| Step 12 最终检查 | 无框架适配核验 | 新增**四要素量化核验**（见 §5.2） |

### 5.2 验收闭环——四要素量化核验

对 ACTIVE_FRAMEWORKS 中每个框架逐项核验，任一不过 = 生成未完成（回 Step 4.5）：

| # | 要素 | 核验规则 | 核验方式 |
|---|------|---------|---------|
| 1 | **枚举** | 框架特定构件枚举计数 ≥ 实际计数 × 0.95（沿用 §C+.1 系数） | 重跑规则文件 §2 枚举命令 vs framework-knowledge/reference-manual 清单行数 |
| 2 | **领域知识** | framework-knowledge.md 该框架节规律数 ≥ 规则文件头部声明的 `深度门槛`（默认 10），100% 含"证据:"字段；0 条残留"待验证"种子 | grep 计数比对 |
| 3 | **门禁** | precheck.sh 含 `_fw_<id>_check` 函数；函数内检查项数 = 规则文件 §4 门禁清单条数；`--framework` 实跑该框架分支 exit 0 | grep 存在性 + 条数比对 + 实跑 |
| 4 | **约束** | dev-guide.md §10 含该框架约束段（≥3 条，每条标注来源规律 id） | grep 段标题 + 条数 |

`--framework` 门禁自身两处收紧：已激活框架但 `_fw_<id>_check` 函数缺失 → **fail**（动态分发，declare -f 探测）；ACTIVE_FRAMEWORKS 未配置但探查信号明显（如存在 `*Mapper.xml`）→ warn 提示"疑似漏配 <规则集>"。

### 5.3 错误处理与边界

| 场景 | 处理 |
|------|------|
| 探查到框架但范式无对应规则文件（长尾框架） | 生成时 warn 明确列出"未覆盖框架清单"，写入目标 skill framework-knowledge.md §待补；**不静默跳过**；引导用户按 `_template.md` 贡献新规则集（扩展机制正式化） |
| 框架版本超出规律标注区间 | 该规律标"待验证"而非直接实例化；`--framework` 对"待验证"规律 warn（提示人工确认），不 fail |
| 片段注入冲突（用户手改了标记区块内代码） | 检测区块哈希与上次注入不符 → 暂停并要求用户裁决（遵守"疑虑必确认"），裁决结果记入 `.swarm-yuan-version` |
| 跨框架规则冲突 | 以规则文件 §5 交互段为准；framework-knowledge.md 中冲突规律须互相引用说明取舍 |
| 离线环境生成 | 规则库/片段库全内置，不依赖联网；联网调研只发生在范式自身维护时 |

### 5.4 precheck.conf 变量段通用化

现有 8 个框架变量（MYBATIS_MAPPER_DIRS 等 mybatis/lombok/sharding/spring-batch 专用硬编码）改造为**约定式命名**：`<RULESET_ID>_<VAR>`（如 `MYBATIS_MAPPER_DIRS`、`VUE_FILE_GLOBS`、`KAFKA_TOPIC_PATTERNS`）。片段头部 `requires_conf` 声明依赖，注入时自动核对。既有 8 个变量保留兼容。

## 6. 框架清单（~56 个，按生态分组）

| 组 | 框架（ruleset_id） | 数量 |
|----|-------------------|------|
| **Java 核心** | spring-boot, spring-cloud, spring-security, spring-batch, spring-data-jpa, mybatis（含 MyBatis-Plus）, lombok, mapstruct, validation（hibernate-validator）, jackson, junit5-mockito | 11 |
| **Java 分布式/中间件** | sharding, dubbo, seata, sentinel, nacos, xxl-job, elasticsearch, netty | 8 |
| **数据集成/流计算**（新增组） | kettle（PDI ETL）, flink（含 flink-sql / flink-cdc 差异标注）, paimon（Apache Paimon 流式数据湖） | 3 |
| **MQ/缓存/调度**（已有，深化） | rocketmq, kafka, rabbitmq, redis, quartz, elasticjob | 6 |
| **数据库**（已有，深化） | mysql, postgresql, sqlserver | 3 |
| **Node 后端** | express, koa, nestjs, fastify, typeorm, prisma | 6 |
| **Python** | django, flask, fastapi, sqlalchemy, celery, pytest | 6 |
| **Go** | gin, gorm | 2 |
| **前端核心** | vue, react, angular, nextjs, nuxt | 5 |
| **前端 UI/工程** | element, antd, naiveui, vite, webpack, tailwind | 6 |
| **前端测试** | jest-vitest | 1 |
| **合计** | | **57** |

说明：

- 7 个（vue/naiveui/pinia/koa/socketio/vite/vitest）门禁实现从 ncwk-dev 反哺；socketio 可归入 Node 组，pinia 随 vue、vitest 随 jest-vitest 合并管理，最终数量以 **56±4** 浮动，不重凑数而重质量门槛（每框架 ≥10 规律）
- 现有 20 个规则集全部按新六段式模板重写深化
- kettle/flink/paimon 为用户指定补充（2026-07-17）：kettle 覆盖 ETL 作业/转换工程规律（kettle 已停止活跃演进，重点标注 Pentaho CE 9.x 与 Hop 分叉）；flink 覆盖 checkpoint/savepoint 状态语义、watermark、exactly-once 两阶段提交、Table API/SQL 与 DataStream 选型；paimon 覆盖主键表 Changelog 语义、Compaction、与 Flink 读写协同

## 7. 调研分批计划

每批：联网调研（官方文档/changelog 现行版本，2026-07 时点，来源 URL 记入规则文件头部）→ 写规则文件 + 门禁片段 → 自核验（四要素 + 片段双态测试）。

| 批次 | 内容 | 验收 |
|------|------|------|
| P0 | 基建：`_template.md` + precheck.sh 调度器/公共函数 + 注入机制 + conf 通用化 + **收割 ncwk-dev 7 片段** + 信号索引生成脚本 | 收割后 ncwk-dev 回灌零回归（26 门禁全 pass、`--framework` ≥28 项） |
| P1 | 实测踩坑组：mybatis, lombok, spring-batch, sharding（最高优先） | 每个过四要素核验 + 双态测试 |
| P2 | Java 核心其余 7 个 | 同上 |
| P3 | Java 分布式 8 + 数据集成/流计算 3（kettle/flink/paimon）+ MQ/缓存/调度深化 6 | 同上 |
| P4 | 数据库 3 + Node 6 + Python 6 | 同上 |
| P5 | Go 2 + 前端 12 + 流程/文档收尾（exploration-guide/domain-knowledge/template-spec/SKILL.md 改造） | 全量回归 |

## 8. 验证策略

### 8.1 ncwk-dev 回灌验证（P0 后即做，范式首个实测）

1. 用新范式对 `/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev` 执行 `--upgrade`
2. **零回归断言**：`--all-full` 26 门禁全 pass；`--framework` 检查项 ≥ 原 28 项；手写 `_fw_*_check` 内容等价迁入标记区块
3. **新能力断言**：framework-knowledge.md 转为新模板结构；`.swarm-yuan-version` 记录升级

### 8.2 测试策略

- **门禁片段双态测试**：每片段配 fixture（1 个违例 + 1 个合规样本），断言 fail/pass 两态——P1 起每批附带
- **端到端 fixture**：构造迷你 Java 项目（pom.xml 含 mybatis+lombok 依赖 + 故意违例的 `*Mapper.xml` / `@Data @Entity`），跑完整生成流程，断言四要素核验全部触发且 `--framework` 按预期 fail
- **范式自兼容**：全部脚本遵守三平台兼容铁律（无 `declare -A`、`sed -i.bak+rm`、`grep -E` 等现有约定）
- 全程在本仓库 `feat/framework-rules-engine` 分支开发；**不自动推送 GitHub**，推送前做敏感信息脱敏检查

### 8.3 风险与缓解

| 风险 | 缓解 |
|------|------|
| 56 框架调研量大，单批质量滑坡 | 每批独立验收（四要素 + 双态测试），不达标不进入下一批；P1 四框架先行验证模板合理性后再放量 |
| 规律版本区间过时 | 文件头"最后调研"日期 + 来源 URL；范式发布流程增加"规则库时效检查"（>6 个月 warn） |
| precheck.sh 注入后体积膨胀 | 片段仅在激活时注入目标 skill；范式自身的片段库不影响运行时性能 |
| ncwk-dev 回灌回归 | P0 验收硬门禁：检查项只增不减，26 门禁全 pass |

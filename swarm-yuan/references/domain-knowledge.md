# 领域知识速查表 (Domain Knowledge Quick Reference)

本文件是 swarm-yuan `--domain` 门禁的分析起点参考。**不是直接复制到 reference-manual 的清单**——而是提供"该领域有哪些客观规律值得在项目中验证"的速查。

> **使用方式**：探查时识别项目涉及的领域 → 从本表找到该领域的分析维度 → 用代码证据验证每条规律是否在项目中成立 → 推导出项目具体的客观规律写入 reference-manual。

## 技术领域速查

### 数据库（关系型：SQLite/PostgreSQL/MySQL）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 事务边界 | 事务须 ACID；跨服务不应 2PC | grep BEGIN/COMMIT/TRANSACTION，看事务范围 |
| 外键约束 | 外键不可绕过（删除须级联或限制） | 读 migration/schema，看 FK 定义 |
| 索引策略 | 索引加速读但拖慢写；查询须走索引 | grep EXPLAIN 或看 ORM 的 index 配置 |
| N+1 查询 | 循环内查 DB = N+1，须 batch/preload | grep 循环体内的 find/SELECT |
| 连接数 | 连接池有上限，长连接须归还 | 看 DB 配置的 pool size |
| 大事务 | 大事务锁表，须拆分 | 看事务内操作数量 |
| 读写分离 | 读多写少可读写分离 | 看 DB 配置是否多实例 |

### 数据库（文档型：MongoDB）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 一致性 | 默认最终一致；强一致须 readConcern=majority | 读连接配置 |
| 嵌套 vs 引用 | 深嵌套难查询；高频联合查询须引用 | 看 schema 设计 |
| 索引 | 复合索引顺序须匹配查询排序 | 读 createIndex 调用 |

### 缓存（Redis/Memcached）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 缓存穿透 | 不存在的 key 须空值缓存或布隆过滤 | grep 查询逻辑 |
| 缓存击穿 | 热 key 过期须互斥锁或永不过期 | 看 TTL 设置 + 过期处理 |
| 缓存雪崩 | 大量 key 同时过期须随机 TTL | 看 TTL 是否有 jitter |
| 一致性 | 缓存与 DB 一致性：先更 DB 再删缓存 | grep 更新逻辑顺序 |

### 网络（HTTP/REST）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 无状态 | HTTP 无状态，会话靠 Cookie/Token | grep session/cookie/jwt |
| CORS | CORS 是浏览器策略非服务端；预检请求 OPTIONS | 看 CORS 中间件配置 |
| 超时 | 请求须设超时 + 重试上限 | grep timeout/retry 配置 |
| 幂等 | GET 幂等；POST 非幂等须显式设计 | 看 POST handler |
| 分页 | 大数据量须分页，不可全量返回 | 看 list API 的 limit/offset |

### 网络（WebSocket/长连接）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 心跳 | 须心跳保活，否则连接被中间设备断开 | grep ping/pong/heartbeat |
| 重连 | 断线须自动重连 + 退避 | grep reconnect/backoff |
| 消息序 | 消息须有序（序号/timestamp） | 看消息结构有无 seq/ts |
| 背压 | 消费慢于生产须背压（丢旧/队列限长） | 看消息队列处理 |

### 安全

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 密码 | 须哈希（bcrypt/argon2），不可明文/MD5 | grep password + hash |
| SQL | 须参数化，不可字符串拼接 | grep SELECT + 字符串拼接 |
| XSS | 须输出编码，v-html/innerHTML 须消毒 | grep v-html/innerHTML |
| CSRF | 须 Token 或 SameSite Cookie | 看 CSRF 中间件 |
| 密钥 | 不入代码库，用环境变量/KMS | grep 硬编码密钥模式 |
| 越权 | 须水平+垂直越权检查 | 看 authz 中间件 |
| 输入验证 | 须在边界验证（schema/DTO），非信任前端 | 看 input validation |

### 并发

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 共享状态 | 共享可变状态须同步（锁/CAS/actor） | grep global/shared mutable |
| 锁顺序 | 多锁须固定顺序加锁，防死锁 | 看锁获取顺序 |
| 锁粒度 | 锁粒度越小越好，粗锁拖慢并发 | 看锁范围 |
| 竞态 | check-then-act 须原子（乐观锁/CAS） | 看条件检查+操作是否原子 |
| 线程池 | 有上限 + 拒绝策略 | 看 pool 配置 |

### 前端（Vue/React）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 渲染 | DOM 操作昂贵，须批量/虚拟 DOM diff | 看是否有直接 DOM 操作 |
| key | 列表 key 须稳定唯一，不可用 index | grep v-for/key/map key |
| 虚拟滚动 | 大列表（>100 项）须虚拟滚动 | 看列表组件 |
| 首屏 | 须懒加载/代码分割 | 看 import() / lazy |
| 状态 | 派生状态不可存 useState（用 useMemo/computed） | grep useState(.map/.filter) |
| 响应式 | 须正确声明响应式（ref/reactive/useState），不可直接赋值 | 看状态管理 |

### 前端（CSS/样式）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 作用域 | 全局 CSS 易冲突，须 scoped/modules | 看 .css 文件是否 .module.css |
| 选择器 | CSS 从右向左匹配，深嵌套选择器慢 | grep 嵌套选择器 |
| 布局 | 须 flex/grid 布局，避免 float/table | grep float/table 布局 |

### 分布式

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| CAP | 三选二，须明确选择 | 看一致性模型配置 |
| 幂等 | 写操作须显式幂等设计 | 看 POST/PUT handler |
| 一致性 | 最终一致须容忍临时不一致 | 看补偿/对账机制 |
| 分区 | 网络分区必然发生，须容错 | 看重试/降级/熔断 |
| Outbox | 写库+发消息须 outbox 保证原子 | grep outbox/event-relay |

### 构建/DevOps

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 可重复 | 构建须可重复（锁定依赖版本） | 看 lockfile |
| 可回滚 | 部署须可回滚（版本化+回滚脚本） | 看回滚机制 |
| 配置分离 | 配置须环境分离（env/config），不入代码 | 看 .env/config 管理 |
| 日志 | 须结构化（JSON），含时间戳/级别/traceId | 看日志格式 |
| 监控 | 须覆盖黄金信号（延迟/流量/错误/饱和） | 看监控配置 |

---

## 业务领域速查

### IM/即时通讯

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 消息序 | 消息须有序（seq/timestamp），乱序=显示错乱 | 看消息结构有无序号 |
| 已读 | 已读状态须幂等（多端同步不重复通知） | 看已读更新逻辑 |
| 离线 | 离线消息须缓存/拉取，上线后补发 | 看离线消息存储 |
| 去重 | 消息推送须去重（idempotency-key/msgId） | 看推送逻辑 |
| 状态同步 | 多端状态须同步（已读/输入中/在线状态） | 看状态广播机制 |

### 电商

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 库存 | 须原子扣减（不可超卖），并发须锁/CAS | 看库存扣减逻辑 |
| 价格 | 价格变更须版本化（历史价格可追溯） | 看价格表结构 |
| 订单状态机 | 状态须有序不可逆跳转（不可从"已发货"回"待支付"） | 看状态转换定义 |
| 支付 | 须幂等 + 对账（重复支付不重复扣款） | 看支付+回调逻辑 |
| 优惠 | 优惠叠加须规则引擎（不可手动 if-else） | 看优惠计算逻辑 |

### CRM/用户管理

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 数据归属 | 用户数据须有归属（tenant/org） | 看 tenant_id 字段 |
| 软删除 | 用户删除须软删除（保留审计追溯） | 看 deleted_at 字段 |
| 权限 | 须 RBAC/ABAC，数据级权限隔离 | 看 authz 逻辑 |
| 去重 | 用户须唯一标识（手机/邮箱不可重复） | 看 unique 约束 |

### 监控/可观测

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 采样 | 高频指标须采样（不可全量存储） | 看采样配置 |
| 告警 | 须有阈值+降噪（防告警风暴） | 看告警规则 |
| 追踪 | 须 traceId 跨服务透传 | grep traceId/traceparent |
| 时序 | 指标须时间序列存储（不可关系型存大量时序） | 看 TSDB 配置 |

### DevOps/CI-CD

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 流水线 | 须自动化（构建→测试→部署），非手动 | 看 CI 配置 |
| 环境 | 须多环境隔离（dev/staging/prod） | 看环境配置 |
| 秘钥 | 须 Secret 管理（不入 CI 配置） | 看 secrets 管理 |
| 蓝绿/灰度 | 须渐进发布（非全量替换） | 看部署策略 |

### 教育

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 内容版本 | 课程/题目须版本化（改题不影响已答记录） | 看内容表结构 |
| 防作弊 | 须随机题序/选项/时间限制 | 看考试逻辑 |
| 进度 | 学习进度须幂等（重试不重复计） | 看进度更新 |

### 金融

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 精度 | 金额须 Decimal 不可 float（精度丢失） | grep float/double 用于金额 |
| 双记 | 须借贷双记（复式记账） | 看记账逻辑 |
| 对账 | 须定期对账（日终/月终） | 看对账机制 |
| 审计 | 须不可篡改审计日志 | 看审计日志设计 |
| 合规 | 须合规检查（KYC/AML/PCI-DSS） | 看合规逻辑 |

---

## 支付清算领域速查

### 银行卡转接清算（境内）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 交易类型 | 金融交易（消费/取现/转账）与非金融交易（查询/冲正）须分流处理 | 看交易类型枚举与处理路由 |
| 报文标准 | 须遵循 ISO 8583 报文格式；字段位置/长度/类型不可错位 | 看报文解析/组包代码 |
| 冲正机制 | 金融交易失败须自动冲正；冲正须幂等；冲正不可被冲正 | grep 冲正逻辑 + 状态机 |
| 清算批次 | 批次须闭环（开批→扎差→清算→关批）；批内交易不可跨批 | 看批处理逻辑 |
| 差错处理 | 差错交易须长款/短款分类处理；差错不可自动清分 | 看差错处理流程 |
| 对账 | 须双边对账（发卡侧 vs 收单侧）；T+1 对账不可跳过 | 看对账文件生成与比对 |
| 风控 | 须实时风控（限额/频次/黑名单）；风控拦截须留痕 | 看风控规则引擎 |
| 状态机 | 交易状态须有序不可逆（受理→授权→清算→完成；不可回退） | 看状态转换定义 |
| 时序 | 交易时间戳须统一（UTC+8）；跨系统时间戳不可错位 | 看时间处理 |

### 跨境转接清算

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 币种转换 | 须汇率快照（交易时锁定汇率）；清算汇率 vs 结算汇率须区分 | 看汇率处理逻辑 |
| 多币种 | 须支持多币种清算；金额精度须支持小数位差异（JPY=0位，USD=2位） | 看币种配置 |
| 时区 | 跨时区清算日须统一（通常 UTC）；跨日交易须归入正确清算日 | 看清算日切换逻辑 |
| 合规 | 须制裁名单筛查（OFAC/UN sanctions）；筛查须实时且留痕 | 看合规筛查逻辑 |
| 报文 | 国际卡组织报文（Visa BASEI/MasterCard MIP）须按规范解析 | 看报文适配层 |
| 路由 | 须按卡 BIN 路由到正确卡组织；路由规则须可配置 | 看路由逻辑 |
| 外汇风险 | 须外汇敞口管理（买入/卖出汇率差）；须对冲机制 | 看外汇管理 |

### 网络支付（互联网支付）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 支付订单 | 须独立于商品订单（支付订单=支付凭证，商品订单=业务凭证） | 看订单模型设计 |
| 回调 | 须异步回调通知商户；回调须幂等（商户重复收到不重复发货） | 看回调逻辑 + 幂等键 |
| 超时 | 须支付超时关单（防挂单）；关单后不可再支付 | 看超时逻辑 |
| 退款 | 须原路退回；退款金额 ≤ 原支付金额；退款须幂等 | 看退款逻辑 |
| 分账 | 须支持分账（多商户分润）；分账比例须可配置 | 看分账逻辑 |
| 对账 | 须 T+1 对账（支付平台 vs 商户系统）；差错须分类处理 | 看对账逻辑 |

---

## 安全合规领域速查

### 网络安全等级保护（等保2.0）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 定级 | 须确定系统安全保护等级（1-5级）；定级须备案 | 看等保定级文档 |
| 物理安全 | 须物理访问控制（机房）；防雷/防火/防水/防静电 | 看物理安全措施 |
| 网络安全 | 须边界防护（防火墙/IPS）；须网络隔离（DMZ/内网/核心）；入侵检测 | 看网络拓扑 + 防火墙规则 |
| 主机安全 | 须身份鉴别（强口令/双因素）；须访问控制（最小权限）；须安全审计 | 看主机加固配置 |
| 应用安全 | 须身份认证；须访问控制；须安全审计；须通信加密 | 看应用安全机制 |
| 数据安全 | 须数据完整性（校验/签名）；须数据保密性（加密传输/存储）；须备份恢复 | 看数据加密 + 备份策略 |
| 安全审计 | 须审计日志（用户行为/系统事件）；日志须保存 ≥6 个月；日志不可篡改 | 看审计日志系统 |
| 安全管理 | 须安全管理制度；须人员安全管理；须系统建设管理；须系统运维管理 | 看安全管理制度文档 |
| 测评 | 三级以上须每年测评；测评须由有资质机构执行 | 看测评报告 |

### ATT&CK 框架（攻击行为知识库）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 侦察 | 攻击者搜集目标信息（被动扫描/主动扫描） | 看是否有暴露面管理 |
| 初始访问 | 鱼叉钓鱼/有效账户/外部远程服务 | 看是否有钓鱼防护 + 账户监控 |
| 执行 | 命令行/脚本/计划任务/用户工具执行 | 看是否有命令审计 + EDR |
| 持久化 | 计划任务/注册表/服务/引导项 | 看是否有持久化检测 |
| 防御规避 | 混淆/签名代码/进程注入 | 看是否有防规避检测 |
| 凭证访问 | 暴力破解/凭证转储/Kerberoasting | 看是否有凭证保护 + 异常检测 |
| 发现 | 账户发现/网络发现/文件目录发现 | 看是否有行为基线检测 |
| 横向移动 | 远程服务/横向工具传输/中间人 | 看是否有网络分段 + 横向检测 |
| 收集 | 数据压缩/数据加密/自动收集 | 看是否有数据外泄检测 |
| 命令与控制 | 加密通道/Web服务/DNS 隧道 | 看是否有 C2 检测 + DNS 监控 |
| 渗出 | 通过网络/物理介质/替代协议渗出 | 看是否有 DLP + 流量分析 |
| 影响 | 加密数据/数据销毁/拒绝服务 | 看是否有备份 + 容灾 + DDoS 防护 |

> ATT&CK 使用提示：识别项目系统类型（终端/网络/云/容器）→ 确定适用的 ATT&CK 矩阵 → 从上表中验证对应检测/防护措施是否存在 → 缺失项写入 reference-manual 安全知识段

---

## 架构领域速查

### DDD（领域驱动设计）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 通用语言 | 代码命名须与业务术语一致（Customer 不叫 User/Member） | 对照术语表 vs 代码标识符 |
| 限界上下文 | 每个上下文有独立模型；上下文间不共享领域模型 | 看上下文边界划分 |
| 聚合根 | 聚合内一致性由聚合根保证；外部只引用聚合根 ID | 看聚合设计 + 引用方式 |
| 领域层纯净 | 领域层不依赖框架/ORM/Web（纯业务逻辑） | grep 领域层的 import |
| 值对象 | 不可变、无身份、可替换 | 看值对象设计 |
| 领域事件 | 状态变更须发领域事件；事件须幂等消费 | grep DomainEvent |
| 防腐层 | 跨上下文/遗留系统集成须经 ACL | 看 ACL 目录 |
| 上下文映射 | 上下文间关系须显式（合作/客户-供应商/跟随/共享内核） | 看上下文映射图 |

### TOGAF（企业架构框架）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 架构契约 | 架构决策须可追溯（ADR）；契约须版本化 | 看 ADR 目录 + 契约 version |
| BDAT 一致性 | 业务-数据-应用-技术四域命名/模型须一致 | 对照四域模型 |
| 数据所有权 | 每个数据实体须有唯一权威源（SoR） | 看 SoR 表 |
| 架构原则 | 须有架构原则文档且代码遵循 | 看原则文档 + 代码合规检查 |
| 变更影响 | 架构变更须做影响分析（消费方清单） | 看 spec 影响范围段 |
| 过渡架构 | 须有过渡架构（非大爆炸式重构） | 看迁移路径设计 |

### C4 模型（架构可视化）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| Context | 系统上下文图须含外部系统 + 用户角色 | 看 context 图 |
| Container | 容器图须含每个部署单元（服务/DB/前端） | 看 container 图 |
| Component | 组件图须含每个容器的主要组件 | 看 component 图 |
| Code | 代码级图（可选，仅关键组件） | 看是否有 UML/class 图 |
| 层级一致 | 上下文→容器→组件→代码，逐层细化无跳跃 | 对照各层图一致性 |
| Mermaid | 架构图须用 Mermaid 可视化 | grep mermaid 架构图 |

### 常用架构模式

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 分层架构 | 上层依赖下层，不可倒置/穿透 | 看依赖方向 |
| 六边形架构 | 业务核心不依赖外部（端口-适配器） | 看核心层是否依赖 IO |
| 事件驱动 | 事件须幂等消费；事件须有序（按聚合 ID 分区） | 看事件处理逻辑 |
| 微服务 | 每服务独立 DB；服务间通过 API/事件通信 | 看 DB 配置 + 通信方式 |
| CQRS | 读模型与写模型分离；写侧须领域模型 | 看读写分离设计 |
| Saga | 分布式事务用 Saga 非二阶段提交；须补偿事务 | 看事务管理 |

---

## 管理领域速查

### 大规模敏捷（SAFe/LeSS/Spotify）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| PI 规划 | 须 PI Planning（8-12 周增量规划）；PI 须有明确目标 | 看 PI 计划文档 |
| 特性团队 | 须跨职能特性团队（非按职能分工）；团队 5-9 人 | 看团队组织结构 |
| 用户故事 | 须用户故事格式（As a... I want... so that...）；须 INVEST 合规 | 看 backlog 格式 |
| 迭代 | 须 2 周迭代 + 迭代评审 + 回顾 | 看迭代节奏 |
| 系统演示 | 须每迭代系统集成演示（非各团队独立演示） | 看演示机制 |
| Architectural Runway | 须预留架构跑道（支持未来特性的技术基础设施） | 看技术债务管理 |
| 发布火车 | 须敏捷发布火车（ART）对齐多团队节奏 | 看 ART 配置 |
| 依赖管理 | 须跨团队依赖管理（看板/Scrum of Scrums） | 看依赖跟踪 |
| 度量 | 须敏捷度量（速率/周期时间/前置时间/逃逸缺陷） | 看度量看板 |

### 敏捷工程实践

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| TDD | 须测试先行（红-绿-重构）；测试覆盖率须达标 | 看测试 + 覆盖率 |
| CI/CD | 须持续集成（每次提交构建+测试）；须持续交付 | 看 CI pipeline |
| 结对编程 | 高复杂度任务须结对（知识共享 + 质量） | 看团队实践 |
| 重构 | 须持续重构（不让技术债累积）；重构须有测试保护 | 看重构记录 |
| Code Review | 须所有代码经审查合并；审查须有标准 | 看 review 流程 |
| 定义完成 | 须 DoD（Definition of Done）清单；每个故事须满足 DoD | 看 DoD 文档 |

---

## 运维领域速查

### SRE/可观测性

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| SLI/SLO | 须定义 SLI（指标）+ SLO（目标）；须错误预算 | 看 SLO 文档 |
| 黄金信号 | 须监控四信号（延迟/流量/错误/饱和度） | 看监控配置 |
| 日志 | 须结构化（JSON）；须含 traceId/service/level/timestamp | 看日志格式 |
| 告警 | 须分级（P0-P3）；须降噪（告警合并/抑制）；须值班（on-call） | 看告警规则 |
| 链路追踪 | 须分布式追踪（traceId 跨服务透传） | grep traceId |
| 仪表盘 | 须有系统全景仪表盘 + 服务级仪表盘 | 看监控面板 |

### 容器编排（Kubernetes）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 资源限制 | 须设 requests + limits（防资源争抢/雪崩） | 看 K8s manifests |
| 健康检查 | 须 liveness + readiness probe | 看 probe 配置 |
| 滚动更新 | 须 RollingUpdate 策略（非 Recreate）；须就绪探针 | 看部署策略 |
| 弹性伸缩 | 须 HPA（CPU/内存/自定义指标触发） | 看 HPA 配置 |
| 配置分离 | 须 ConfigMap/Secret（非镜像内置配置） | 看配置管理 |
| 网络策略 | 须 NetworkPolicy（Pod 间网络隔离） | 看网络策略 |
| 持久化 | 有状态服务须 PV/PVC；须数据备份 | 看存储配置 |

### 容灾/高可用

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 多副本 | 无状态服务须多副本（≥2）；有状态须主从/集群 | 看副本数 |
| 故障域 | 须跨故障域分布（多 AZ/多节点） | 看拓扑分布 |
| 故障注入 | 须混沌工程（主动注入故障验证韧性） | 看混沌测试 |
| 降级 | 须降级策略（非核心服务不可用时保核心） | 看降级逻辑 |
| 熔断 | 须熔断器（下游不可用时快速失败不堆积请求） | 看熔断配置 |
| 限流 | 须限流（入口/服务级）；须多级限流 | 看限流配置 |
| 回滚 | 须一键回滚 + 回滚演练 | 看回滚机制 |
| RTO/RPO | 须定义 RTO（恢复时间目标）+ RPO（恢复点目标） | 看容灾文档 |

> **前序方法论**（4-Phase SOP、逻辑剃刀 6 步、认知偏差五维、思维模型 8 类、辩证 7 对）不在此重复——已融入 swarm-yuan 五层认知基底，详见 `references/cognition-framework.md`（总览）+ `references/logic-razor.md`（剃刀+谬误图谱）+ `references/cognitive-bias.md`（偏差+思维模型）。

---

## 框架特定领域规则集（由 §C+.0.5 框架探查结果激活）

> 以下框架规则集**仅当 §C+.0.5 探查到对应框架信号时引用**，非套用清单——须结合项目代码验证后写入 reference-manual.md 领域知识段。每个框架的规则须标注代码证据。

### Spring Boot（当规则集 spring-boot 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| @Transactional 代理自调用 | 同类内方法间调用绕过 Spring AOP 代理→事务不生效 | grep @Transactional 类内方法互调 |
| @Transactional 回滚 | 默认只回滚 RuntimeException/Error，checked 异常不回滚 | 看 rollbackFor 属性配置 |
| @Autowired 注入 | 构造器注入优于字段注入（不可变+可测试+无循环依赖隐患） | grep @Autowired 字段 vs 构造器 |
| @Configuration 代理 | CGLIB 代理子类化，@Bean 方法间调用不重复创建（非 @Component） | 看 @Configuration vs @Component |
| Profile 隔离 | 不同 profile 的 @Bean 须 @Profile 标注，application-{profile}.yml 须对应 | 看 application-*.yml + @Profile |
| @Conditional | @ConditionalOnMissingBean/@ConditionalOnProperty 顺序依赖 | 看 @Conditional 链 |

### MyBatis / MyBatis-Plus（当规则集 mybatis 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| #{} vs ${} | #{} 参数化安全；${} 字符串拼接危险，仅 ORDER BY/表名可用且须白名单 | grep '\${' *Mapper.xml |
| Mapper↔XML 绑定 | 每个 @Mapper 接口须有匹配 XML namespace 或注解 SQL | 对比 @Mapper 接口 vs XML namespace |
| resultMap N+1 | 嵌套 association/collection 须用 JOIN 或 lazy loading，否则 N+1 查询 | 看 resultMap 嵌套 + 查询次数 |
| foreach OOM | `<foreach>` 生成 IN 列表须有 size 上限防 OOM | 看 foreach 无 size 限制 |
| MyBatis-Plus 分页 | 须用 Page 对象分页，不可全量查询 | grep selectList 无 Page |
| 自定义 TypeHandler | 须注册到 SqlSessionFactory/MybatisConfiguration | 看 mybatis-config + TypeHandler |

### Lombok（当规则集 lombok 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| @Data + JPA 冲突 | @Entity + @Data 生成的 equals/hashCode 可能触发懒加载递归/StackOverflow | grep @Entity + @Data 同类 |
| @Slf4j 字段名 | @Slf4j 生成字段名 log，不可再手动声明 Logger | grep @Slf4j + LoggerFactory 同类 |
| @Builder + 反序列化 | @Builder 无 @AllArgsConstructor/allArgsConstructor 导致 Jackson 反序列化失败 | grep @Builder 无 @AllArgsConstructor |
| @RequiredArgsConstructor | final 字段须有初始值或经构造器注入 | grep final 字段 + @RequiredArgsConstructor |
| @EqualsAndHashCode 排除 | 实体 @EqualsAndHashCode 须排除 lazy 关联字段（callSuper=false） | 看 @EqualsAndHashCode 字段 |

### ShardingSphere（当规则集 sharding 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 分片键必含 | 分片表 INSERT/UPDATE/DELETE 须含分片键，否则全分片扫描/笛卡尔更新 | 看 SQL WHERE 是否含分片键列 |
| 广播表只读 | 广播表（字典表）只应读不应写 | 看广播表 DML |
| 绑定表 JOIN | 绑定表的 JOIN 须含分片键，否则跨分片 JOIN | 看绑定表 JOIN 条件 |
| SQL 兼容性 | ShardingSphere 不支持部分 SQL（如跨库子查询含分片键） | 看 ShardingSphere 版本不支持语法 |
| 分布式事务 | 跨分片事务须用 XA/Seata，不可用本地事务 | 看事务管理器配置 |

### Spring Batch（当规则集 spring-batch 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| Step 三件套 | 每个 Step 须声明 ItemReader/ItemProcessor/ItemWriter | grep Step 定义 |
| @StepScope late binding | @Value 注入参数须加 @StepScope/@JobScope | grep @Value + Step |
| JobRepository 事务 | JobRepository 事务不可与业务 @Transactional 共用 | 看 JobRepository 配置 |
| 重启策略 | Step 须声明 allowStartIfComplete/restartable | 看 Step 配置 |
| chunk 大小 | chunk-oriented 须设 commit-interval，不可单条提交 | 看 chunk 配置 |
| 读写幂等 | ItemReader 须支持重读（restartable），ItemWriter 须幂等 | 看 Reader/Writer 实现 |

### Dubbo（当规则集 dubbo 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 超时重试幂等 | 超时重试须保证消费端幂等（重复请求不产生副作用） | 看 retries 配置 + 消费端幂等 |
| 注册中心兼容 | 注册中心版本与 Dubbo 版本须兼容 | 看 dubbo.yml 版本 |
| 泛化调用安全 | 泛化调用（Telnet/通用接口）须限制来源，防 RCE | 看 telnet/qos 端口暴露 |
| 序列化兼容 | 序列化协议（hessian2/dubbo）须两端版本一致 | 看 serialization 配置 |
| 服务降级 | 须配置 mock 降级策略 | 看 mock 配置 |

### RocketMQ（当规则集 rocketmq 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 消费幂等 | 消费者须按 msgKey 去重（Redis/DB 唯一键），防重复消费 | 看消费端幂等逻辑 |
| 顺序消息 | 顺序消息须单队列+单消费者串行消费 | 看 MessageQueueSelector + 消费线程 |
| 事务消息 | 事务消息须实现半消息回查（checkLocalTransaction） | 看 TransactionListener |
| 消费失败 | 消费失败须设重试次数+死信队列 | 看 retry + DLQ 配置 |
| 消息堆积 | 消费速率须 ≥ 生产速率，防消息堆积 | 看消费者并发线程数 |

### Kafka（当规则集 kafka 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 消费者 offset | offset 提交语义（auto/手动）须与业务幂等匹配 | 看 enable.auto.commit |
| 分区 vs 消费者 | 消费者数 ≤ 分区数，超出的消费者空闲 | 看 partition vs consumer 数 |
| 幂等生产者 | 须启用 enable.idempotence 防重复消息 | 看生产者配置 |
| exactly-once | 须用事务（transactional.id）实现 exactly-once | 看事务配置 |
| rebalance | 消费者 rebalance 须用 cooperative 策略减少抖动 | 看 partition.assignment.strategy |

### RabbitMQ（当规则集 rabbitmq 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 消费幂等 | 消费者须幂等处理（message-id 去重） | 看消费端幂等 |
| 死信队列 | 失败消息须路由到 DLQ，不可静默丢弃 | 看 x-dead-letter-exchange |
| 消息确认 | 须手动 ACK（autoAck=false），消费成功才确认 | 看 acknowledge-mode |
| 队列持久化 | 队列+消息须 durable=true，防重启丢失 | 看 durable 配置 |
| 连接复用 | 须用 Connection 复用 Channel，不可每次新建 Connection | 看连接管理 |

### Redis / Spring Data Redis（当规则集 redis 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 缓存穿透 | 不存在的 key 须缓存空值或布隆过滤器 | 看空值缓存逻辑 |
| 缓存击穿 | 热点 key 须加分布式锁或永不过期+异步刷新 | 看热点 key 处理 |
| 缓存雪崩 | 缓存过期时间须加随机抖动，防同时失效 | 看过期时间设置 |
| 分布式锁 | 须 SETNX+过期时间+owner 校验（不可简单 SETNX） | 看锁实现（Redisson/自实现） |
| 序列化兼容 | RedisTemplate 序列化器须与多端一致（Jackson/GenericJackson） | 看 Serializer 配置 |
| pipeline | 批量操作须用 pipeline，不可逐条往返 | 看批量操作 |

### Quartz / @Scheduled（当规则集 quartz 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 分布式调度锁 | 多实例部署须用 Quartz 集群（DB 锁），否则任务重复执行 | 看 quartz.properties 集群配置 |
| 幂等执行 | 任务执行体须幂等（重复执行不产生副作用） | 看任务逻辑 |
| cron 表达式 | cron 表达式须校验时区+语义正确 | 看 cron |
| 线程池 | 调度线程池须有上限，防任务积压 | 看 threadPool 配置 |
| @Scheduled 分布式 | @Scheduled 多实例须加分布式锁或 @SchedulerLock | 看 @SchedulerLock/ShedLock |

### ElasticJob（当规则集 elasticjob 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 分片调度 | 分片项须与实例数匹配，分片逻辑须确定性 | 看分片策略 |
| 失效转移 | 须开启 failover，故障实例任务转移 | 看 failover 配置 |
| 幂等执行 | 作业执行体须幂等 | 看作业逻辑 |
| 作业监控 | 须配置作业监控/告警 | 看 monitor 配置 |

### MySQL（当规则集 mysql 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 索引覆盖 | 高频查询字段须建索引，EXPLAIN 须走索引 | EXPLAIN 高频查询 |
| 大表分页 | LIMIT offset 须用游标/子查询，不可深分页（offset > 10万） | 看分页 SQL |
| 事务隔离 | 须明确隔离级别（RC/RR），RR 须防幻读（next-key lock） | 看 transaction-isolation |
| 字符集 | 须用 utf8mb4（支持 emoji/4 字节），不可 utf8（3 字节） | 看 charset |
| 死锁 | 死锁检测须开启（innodb_deadlock_detect=ON），加锁顺序一致 | 看 deadlock 配置 + 锁顺序 |
| 慢查询 | 须开启 slow_query_log，long_query_time 须设阈值 | 看 slow_query 配置 |

### SQL Server（当规则集 sqlserver 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| NOLOCK 脏读 | WITH(NOLOCK) 须显式声明脏读风险，不可用于事务一致性场景 | grep NOLOCK |
| 锁升级 | 大批量操作须防锁升级（行锁→表锁），分批提交 | 看批大小 + 锁提示 |
| 事务隔离 | 默认 RC（读已提交），须明确是否需 SERIALIZABLE/SNAPSHOT | 看 isolation level |
| 链接服务器 | 链接服务器（Linked Server）须限制权限，防注入 | 看 linked server 配置 |
| 索引覆盖 | 查询须走索引（含 INCLUDE 列），防 Key Lookup | 看 Execution Plan |
| 死锁 | 须开启死锁追踪（trace flag 1222/1204），加锁顺序一致 | 看 trace flag |

### PostgreSQL（当规则集 postgresql 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| VACUUM | 须定期 VACUUM/autovacuum，防死膨胀 | 看 autovacuum 配置 |
| 序列 | 须用 IDENTITY/SERIAL/序列，不可 max(id)+1 | 看主键策略 |
| JSONB vs JSON | 须优先 JSONB（索引/快），JSON（文本解析）慢 | 看 JSON 列类型 |
| 事务隔离 | 默认 RC，MVCC 须明确是否需 RR/SERIALIZABLE | 看 isolation |
| 索引 | 须用合适索引类型（B-Tree/GIN/GiST/BRIN），不可全用 B-Tree | 看索引类型 |
| 连接池 | 须用 PgBouncer/连接池，不可每次新建连接 | 看连接管理 |

### Element / Element Plus（当规则集 element 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 组件按需引入 | 须用 babel-plugin-component/unplugin-vue-components 按需引入，不可全量 import | 看 import 方式 |
| 表单校验 | el-form 须用 rules 校验，不可手动校验 | 看 form rules |
| el-table 大数据 | 大数据量须用虚拟滚动（virtual-scroll），不可全量渲染 | 看 table 行数 + 虚拟滚动 |
| 国际化 | 须用 ElementLocale + i18n，不可硬编码中文 | 看 i18n 配置 |
| 主题 | 须用 CSS Variables/SCSS 变量覆盖，不可直接改组件样式 | 看主题配置 |

### Ant Design / ant-design-vue（当规则集 antd 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 组件按需引入 | 须用 babel-plugin-import/unplugin 按需引入 | 看 import 方式 |
| Form | React 须用 useForm（非 Form.create 废弃 API），Vue 用 a-form + rules | 看 Form API 版本 |
| Table 大数据 | 须用虚拟滚动（react-window/vxe-table），不可全量渲染 | 看 table 行数 |
| ConfigProvider | 主题/国际化须用 ConfigProvider 包裹，不可全局修改 | 看 ConfigProvider |
| message/notification | 须用 App.useApp()（React 18+），不可静态调用（context 丢失） | 看 message 调用方式 |

### Vue 3（当规则集 vue 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 响应式 | 须用 ref/reactive，不可直接赋值给非响应式变量 | 看响应式用法 |
| 生命周期 | 须用 onMounted/onUnmounted，不可用 Vue 2 的 beforeCreate/destroyed | 看 hooks |
| defineProps/Emits | 须用 `<script setup>` 的宏（defineProps/defineEmits），不可用 options API 混用 | 看 script setup |
| Teleport/Suspense | 弹窗须考虑 Teleport（防父级 overflow 裁切），异步组件用 Suspense | 看 Teleport/Suspense |
| shallowRef | 大对象须用 shallowRef（避免深响应式性能损耗） | 看 ref vs shallowRef |
| key | v-for 的 key 须稳定唯一，不可用 index | 看 v-for key |

### React（当规则集 react 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| Hooks 规则 | 须在顶层调用（不条件/循环调用），否则 hooks 顺序乱 | 看 hooks 调用位置 |
| useEffect 依赖 | useEffect 依赖数组须完整，否则闭包陷阱 | 看 deps 数组 |
| useMemo/useCallback | 须有明确收益（昂贵计算/引用相等依赖），不可滥用 | 看 memo 用法 |
| key | map 的 key 须稳定唯一，不可用 index（影响 reconciliation） | 看 key |
| 不可变更新 | 须不可变更新 state（spread/immer），不可直接 mutate | 看 setState |
| React.memo | 跨层 props 不常变须 memo，防止全树 re-render | 看 memo |

### NaiveUI（当规则集 naiveui 激活时）

| 分析维度 | 须验证的客观规律 | 验证方法 |
|---------|----------------|---------|
| 组件按需引入 | 须用 unplugin-vue-components/unplugin-auto-import 按需引入 | 看 vite.config + import |
| 主题 | 须用 n-config-provider + themeOverrides，不可直接改组件 CSS | 看 ConfigProvider |
| 表单校验 | n-form 须用 rules 校验，不可手动校验 | 看 form rules |
| 数据表格 | 大数据量 n-data-table 须用 virtual-scroll（virtual 模式） | 看 table virtual |
| 暗色模式 | 须用 darkTheme + n-config-provider 切换，不可手动改 CSS | 看 darkTheme |

---

## 使用方式（重要）

1. **识别领域**：从特征卡第 14 项的识别结果，确定项目涉及哪些领域
2. **查速查表**：从本表找到该领域的"分析维度"和"须验证的客观规律"
3. **代码验证**：用"验证方法"列的 grep/读代码方式，验证每条规律在项目中是否成立
4. **推导写入**：将验证通过的规律写入 reference-manual.md"领域知识"段，格式："因为 [代码证据]，所以 [规律]，违反则 [后果]"
5. **不可直接复制**：本表是分析起点，不是最终产出。直接复制本表到 reference-manual = 未做深入分析 = 达克效应

> precheck `--domain` 检查 reference-manual 领域知识段是否有代码依据（grep "因为/依据/证据/@/src/"），无依据→warn"非套用通用清单"。

# swarm-yuan 使用说明

> 对 AI 说"为这个项目生成 skill"，AI 全自动探查 → 生成 → 配置 → 验证，你拿到一套零占位符的项目专属开发技能。

---

## 1. 核心设计理念

swarm-yuan 的设计基于三个关键理念：

### 理念一：先认识，再行动（认知递进）

AI 写代码前必须先认识项目——概念→结构→空间→映射→规律→处理。不认识就写 = 盲动。swarm-yuan 用 **16 项特征卡** 完成认知，用 **34 个质量门禁** 守护行动。

### 理念二：拼装式开发（复用优先）

新功能 = 既有稳定单元的拼装 + 最小新增胶水代码。禁止重复造轮子、禁止侵入式重构、禁止破坏性改造。特征卡第 11 项盘点全部可复用单元，门禁 `--reuse` 验证复用合规。

### 理念三：呈现递进的关系，而非仅关注计算

门禁不是"数 import 数"——每个计数背后指向一条关系规律。`--layer` 数 import 是为了验证"结构是否遵循依赖单向"；`--reuse` 数新增导出是为了验证"概念是否复用了既存稳定单元"。

---

## 2. 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

| 选项 | 安装到 |
|------|--------|
| `--claude` | `~/.claude/skills/` |
| `--codex` | `~/.codex/skills/` |
| `--cursor` | `~/.cursor/skills/` |
| `--windsurf` | `~/.codeium/windsurf/skills/` |
| `--opencode` | `~/.config/opencode/skills/` |
| `--gemini` | `~/.gemini/skills/` |
| `--kimi` | `~/.kimi/skills/` |
| `--all` | 所有已检测到的环境 |
| `--list` | 仅列出检测到的环境 |

---

## 3. 特征卡：项目的「认知 DNA」

### 什么是特征卡

特征卡是 AI 探查项目后提取的 **16 项项目特征**，每项落到真实路径和版本号，不用占位符。它不是独立文件，而是**分散承接进目标 skill 的各个文件中**，是门禁配置和文件填充的「数据源」。

**没有特征卡，门禁就是无源之水——不知道项目边界在哪、哪些单元稳定、什么领域规律不能违反。**

### 16 项特征卡详解

| # | 特征项 | AI 提取什么 | 为什么重要 |
|---|--------|-----------|-----------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务/库 | 决定后续探查策略和门禁配置方向 |
| 2 | **可改范围** | 可改目录列表 + 只读目录列表 + 只读区修改机制 | **安全铁律的依据**——改了只读区 = 违规 |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) 或 core/plugin 或 src/lib | **决定代码怎么写**——A类放 custom/，B类放 patches/ |
| 4 | 技术栈摘要 | 语言+主框架+构建+测试（含版本基线） | 版本锁定铁律的依据，`--deps` 门禁的对比基线 |
| 5 | **构建发布命令** | dev/build/test/release 真实命令 + 端口 | **门禁执行的基础**——`--build` 和 `--test` 跑这些命令 |
| 6 | 分支规范 | 命名格式/合入策略/保护分支/推送规则 | `--branch` 门禁的校验规则 |
| 7 | 安全规则 | 脱敏规则/密钥管理/网络白名单 | `--sensitive` `--security` 门禁的扫描范围 |
| 8 | 文档约定 | spec/plan 位置和命名格式 | spec 文件创建时的路径和命名 |
| 9 | 测试体系 | 框架/目录/运行命令 | `--test` 门禁的执行命令 |
| 10 | 环境与外部资源 | 运行时版本/DB/缓存/MQ/MCP 工具 | `--service` 门禁的微服务配置 |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（每个含签名/路径/用途/复用方式/稳定性标注） | **拼装式开发的核心依据**——`--reuse` 门禁的重名检测源 |
| 12 | 数据规范 | schema 位置/样例数据/业务规则/勾稽关系 | `--consistency` 门禁的勾稽核对项 |
| 13 | 认知基底 | 认知映射表 + 六维动力学基线（速度/聚散/趋势/强度/能耗/累积量） | `--cognition` 门禁的对比基线 |
| 14 | **领域知识** | 技术+业务领域识别 → 推导客观规律 | **防达克效应**——`--domain` 门禁的违规检测依据 |

### 特征卡如何驱动一切

**特征卡 → 文件填充（Step 4）：** SKILL.md 的铁律来自第 2/6 项 → codebase.md 的技术栈来自第 4 项 → dev-guide.md 的改造分类来自第 3 项 → reference-manual.md 的组件库来自第 11 项 → release.md 的命令来自第 5 项……16 项特征卡是目标 skill 所有文件的「数据源」。

**特征卡 → 门禁配置（Step 5）：** precheck.conf 的 171 个变量从特征卡推导：

| 配置变量 | 来自特征卡第几项 |
|---------|----------------|
| PROJECT_DIR / WRITABLE_DIRS / READONLY_DIRS | 第 2 项（可改范围） |
| TEST_CMD / BUILD_CMD | 第 5 项（构建命令） |
| LAYER_DEFS / LAYER_ORDER / DOMAIN_LAYER | 第 3 项（改造分类） |
| STABLE_GLOBS | 第 11 项（可复用单元） |
| SERVICE_DIRS / DB_CONFIG_FILES | 第 10 项（环境资源） |
| STORE_DIR / COMPONENT_DIR | 第 11 项（可复用单元） |
| ADR_DIR / GLOSSARY_FILE | 第 7/8 项（安全/文档） |
| SCAN_DIRS / CONSISTENCY_DIRS | 第 7/12 项（安全/数据） |
| COG_SPEED_FILES / COG_CUMULATIVE_TODO | 第 13 项（认知基底） |

**特征卡 → 开发流程（日常使用）：** 开始新需求时，AI 从特征卡第 11 项检索可复用单元，预填 spec §5.5 复用约束。编码时 AI 查特征卡第 11 项的组件库清单，拼装优先。提交前 34 个门禁按特征卡配置的规则检查。

### 特征卡探查工具矩阵

每项探查优先用运行时工具，无则降级到内置 grep：

| # | 特征项 | 优先工具 | 降级 |
|---|--------|---------|------|
| 1 | 项目类型 | gitnexus `query "architecture"` + graphify `explain` | Read package.json |
| 2 | 可改范围 | claude-mem `search "project rules"` + Read AGENTS.md | Glob + Grep |
| 4 | 技术栈 | gitnexus `query "tech stack"` + graphify `explain` | Read package.json |
| 9 | 测试体系 | gitnexus `query "test files"` | Glob `**/*.test.*` |
| 10 | 环境资源 | gitnexus `route_map` + `tool_map` | Grep "host/port" |
| 11 | 可复用单元 | **gitnexus `context <symbol>`**（360 度上下文） | Grep `export` |
| 12 | 数据规范 | gitnexus `query "data models"` | Grep `CREATE TABLE` |
| 14 | 领域知识 | gitnexus `query "domain"` + claude-mem + WebSearch | Read 领域模型 |

> 注：GitNexus（PolyForm Noncommercial 禁商用）降级为非默认；graphify（MIT）提为默认代码图谱工具——商用场景请把上表 gitnexus 优先位替换为 graphify（依据见 `references/code-graph-tools.md` §许可证与选型）。

大型项目（>100 文件）可用 Dynamic Workflow 并行扇出三路子代理，交叉验证特征卡。

### 落地示例（SwarmStudio overlay 项目）

| # | 特征项 | 真实值 |
|---|--------|--------|
| 1 | 项目类型 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改范围 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | 改造分类 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 4 | 技术栈 | Vue 3 + TypeScript + Vite + NaiveUI + Vitest + SQLite + Koa |
| 5 | 构建命令 | `npm run dev`(:8649) / `npm run build` / `npm test` / `npm run inject` |
| 11 | 可复用单元 | CockpitWorkspace / CockpitKanban / GatewayNoticeBanner 等 15+ 组件 |
| 14 | 领域知识 | IM 通讯（Matrix 协议）+ DevOps 监控（cockpit 看板） |

---

## 4. 质量门禁：特征卡的守卫者

### 门禁与特征卡的关系

特征卡定义了「项目应该是什么样的」，34 个门禁验证「代码是否符合特征卡定义的规则」。

**特征卡是立法，门禁是执法。**

| 特征卡项 | 立法定义 | 门禁执法 |
|---------|---------|---------|
| 第 2 项 可改范围 | overlay/ 可改，upstream/ 只读 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项 构建命令 | `npm run build` | `--build` 运行此命令，非零 = fail |
| 第 6 项 分支规范 | feat/fix/refactor | `--branch` 校验分支名是否匹配正则 |
| 第 7 项 安全规则 | 密钥不入代码库 | `--sensitive` `--security` grep 扫描密钥模式 |
| 第 11 项 可复用单元 | CockpitWorkspace 等稳定单元 | `--reuse` 检测新增单元是否与既有重名 |
| 第 11 项 稳定层 | STABLE_GLOBS 指定的文件 | `--stable-diff` 检测稳定层是否被改而未声明 |
| 第 14 项 领域知识 | 密码必须哈希 | `--domain` grep 检测密码明文存储 |

### 核心门禁（`--all` 跑 10 个，~5 秒）

| 门禁 | 检查什么 | fail 条件 | 特征卡依据 |
|------|---------|----------|-----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 | 第 6 项 |
| `--scope` | 改动范围（可改 vs 只读） | 只读目录有改动 | 第 2 项 |
| `--build` | 构建通过 | 构建失败 | 第 5 项 |
| `--sensitive` | 敏感信息脱敏 | 密码/密钥/token 明文 | 第 7 项 |
| `--consistency` | 业务规则 + 数据勾稽 | 人工核对项（提示性） | 第 12 项 |
| `--review` | 代码审查（5 维度） | ocr 检测到 High 级问题 | — |
| `--reuse` | 复用合规（拼装式开发） | spec 缺 §5.5 / 新增单元与既有重名 | **第 11 项** |
| `--deps` | 依赖版本锁定 | 依赖版本变更但 spec 未声明 | 第 4 项 |
| `--security` | 安全规范（OWASP Top 10） | 注入/eval/XSS/硬编码密钥/TLS 关闭 | 第 7 项 |
| `--test` | 测试通过 | 测试失败 | 第 5/9 项 |

### 架构门禁（`--all-full` 额外跑 17 个，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | 第 3 项 |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | **第 11 项** |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | 第 13 项 |
| `--adr` | 架构决策记录（ADR + 技术债登记） | 第 8 项 |
| `--contract` | 接口契约（version + ACL 防腐层） | 第 10 项 |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | 第 12 项 |
| `--impact` | 变更影响分析（消费方反查） | — |
| `--service` | 微服务架构（共享 DB/同步链/网关/trace） | 第 10 项 |
| `--api` | API 契约与幂等 | 第 10 项 |
| `--state` | 前端状态管理（巨型 store/prop drilling） | **第 11 项** |
| `--frontend` | 前端组件架构（层级/props/循环依赖/CSS 污染） | **第 11 项** |
| `--cognition` | 认知递进体检（六阶+六维+五层总分） | 第 13 项 |
| `--domain` | 领域知识违规检测 | **第 14 项** |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 引用） | — |
| `--mermaid` | Mermaid 可视化 | — |

### 合规门禁（7 个，随 `--all-full` 执行，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--compliance` | 标准合规矩阵核验（六锚点 + 零占位符 + spec §22 标准合规段） | 第 8 项 |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档 + TBD 扫描） | 第 8 项 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（启用后 fail-closed） | 第 4 项 |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 第 7 项 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | 第 7 项 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式 fail-closed） | 第 8 项 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 → fail，国密白名单 SM2/SM3/SM4） | 第 7 项 |

### 门禁工具优先级 + 降级策略

每个门禁优先用已安装的运行时工具，无则降级：

| 门禁 | 优先（运行时） | 降级（内置） |
|------|--------------|-------------|
| `--link-depth` | graphify path → gitnexus trace（仅非商用场景）→ madge | 转发函数统计 |
| `--impact` | gitnexus detect_changes | git diff + grep |
| `--layer` | gitnexus query | grep import |
| `--review` | ocr review / `claude ultrareview` | AI 5 维度审查 |
| `--knowledge` | claude-mem search | 文件检测 |
| `--frontend` 循环 | madge --circular | grep 互引 |

---

## 5. 生成流程

对 AI 说："为 /path/to/my-project 生成 skill"

或用 slash 命令：`/swarm-yuan /path/to/my-project`

| 步骤 | 做什么 |
|------|--------|
| 0 | 自检 11 个运行时工具 |
| 0.5 | 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / hermes-agent） |
| 1 | 三路并行探查代码库（结构 / 规范 / 代码组织） |
| 2 | **提取 16 项特征卡**（每项落到真实路径，不用占位符） |
| 3 | 创建骨架（含 hooks / commands / precheck.conf） |
| 4 | AI 填充全部文件——**特征卡驱动，消除全部占位符** |
| 5 | AI 配置 precheck.conf——**171 个变量从特征卡推导** |
| 5.5 | AI 生成 hooks / commands / MCP 集成 |
| 6 | AI 运行 34 个门禁——**特征卡定义规则，门禁验证合规** |
| 7 | AI 写回项目记忆（闭环） |
| 8 | AI 最终检查——运行 `generate-skill.sh --verify-completeness` 脚本确认**零占位符残留**（命中即列 file:line 并 exit 1，零命中才通过） |

---

## 6. 日常使用

### 开始新需求

对 AI 说："开始新需求：给 cockpit 添加通知面板"

AI 自动：创建 spec → 判断规模 → **从特征卡第 11 项检索可复用单元，预填 §5.5 复用约束** → 验证。

| 规模 | 填哪些段 | 典型场景 |
|------|---------|---------|
| 简单 | §1-§4 + §5.5 复用约束 + §12 风险回滚 | 改 bug / 加字段 |
| 标准 | §1-§13 + §5.5/§5.6/§5.7 约束段 | 新功能 / 改接口 |
| 完整 | 全部 18 段（含 §14-§18 认知/辩证/领域） | 架构变更 / 跨服务 |

### 提交前自检

```bash
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 全部 34 门禁
```

**结果**：`✓` 通过 / `✗` 必须修复 / `⚠` 人工评估

### 门禁输出与证据（--doctor / --format json / GATE_RUNS_DIR）

```bash
bash scripts/precheck.sh --doctor              # conf 诊断 lint：路径/glob 可达/死变量/框架 requires_conf（非门禁，可带病启动）
bash scripts/precheck.sh --all --format json   # 门禁结果以 SARIF 2.1.0 子集 json 追加输出（GATE_JSON_OUT=<path> 可落盘）
GATE_RUNS_DIR=.gate-runs bash scripts/precheck.sh --all-full
# 证据落盘：gate-runs.jsonl（ts/门禁名/状态/fail id 数组/耗时）逐行写入 .gate-runs/
```

默认 text 模式输出与旧版逐字节一致；`--format json` 或 `GATE_RUNS_DIR` 仅在显式开启时生效。

---

## 7. 升级

对 AI 说："升级 my-project-dev skill"

或直接运行：

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板 / 保留项目特定文件 / 自动备份 / AI 重新探查填充 precheck.conf。

---

## 8. FAQ

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"。AI 分析原因 → 调整 precheck.conf（特征卡配置）→ 重跑。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。核心约束：先声明复用了特征卡第 11 项的哪些单元，再写代码。

**Q: 不需要微服务/前端/TOGAF？** → 特征卡第 10/11 项留空 = 对应门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。AI 重新探查 → **更新特征卡** → 更新 precheck.conf。

---

## 9. 流程

```
首次：
  bash install.sh --claude
  对 AI 说 "为 /path/to/project 生成 skill"
    → AI 探查 → 提取 16 项特征卡 → 填充文件 → 配置门禁 → 验证 → 零占位符

日常：
  对 AI 说 "开始新需求：xxx"
    → AI 从特征卡第 11 项检索可复用单元 → 预填 §5.5
    → 编码（拼装优先，查特征卡第 11 项组件库清单）
      → 对 AI 说 "跑门禁"
        ├→ 全 ✓ → 提交
        ├→ 有 ✗ → 修复重跑
        └→ 有 ⚠ → 评估

架构审查：
  对 AI 说 "跑全量门禁"（34 个门禁全跑）

升级：
  对 AI 说 "升级 skill"（AI 重新探查 → 更新特征卡 → 更新门禁配置）
```

## 10. 数字一览

| 维度 | 数值 |
|------|------|
| **特征卡** | **16 项（驱动全部文件 + 171 个门禁变量 + 开发流程）** |
| **质量门禁** | **34 个（核心 10 + 架构 17 + 合规 7，特征卡立法 + 门禁执法）** |
| 运行时工具 | 11 |
| spec 模板 | 22 主段（§22=标准合规） |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |

## 框架规则引擎

swarm-yuan 内置 61 个框架规则集（references/frameworks/*.md + assets/framework-gates/*.sh），覆盖 Java/Node/Python/Go/前端全栈。

### 生成时激活

1. **框架探查**（§C+.0.5）：从 pom.xml/package.json/go.mod/pyproject.toml 提取依赖，识别 ACTIVE_FRAMEWORKS
2. **门禁注入**（--inject-frameworks）：按 ACTIVE_FRAMEWORKS 把对应门禁片段注入目标 skill 的 precheck.sh 标记区块
3. **四要素核验**（verify-framework-ruleset.sh）：每框架须通过 枚举+领域知识+门禁+约束 四要素
4. **fixture 双态**（run-framework-fixture.sh）：每框架含 violating→FAIL / compliant→PASS 测试

### 扩展新框架

1. 复制 `references/frameworks/_template.md` 为 `<fw>.md`（六段式：§1 探查信号 + §2 构件枚举 + §3 领域规律≥10 + §4 门禁清单 + §5 跨框架交互 + §6 版本陷阱）
2. 创建 `assets/framework-gates/<fw>.sh`（`_fw_<id>_check()` 函数 + 头注释 `# ruleset:` + `# gates:`）
3. 创建 `tests/fixtures/<fw>/{violating,compliant}/`
4. 跑 `bash scripts/verify-framework-ruleset.sh <fw>` 核验
5. 跑 `bash scripts/gen-framework-index.sh` 更新索引

### 门禁运行

```bash
bash scripts/precheck.sh --framework    # 运行所有激活框架门禁
bash scripts/precheck.sh --all-full     # 全量 34 门禁（含 --framework 与合规族）
```

### 时效检查

`bash scripts/self-check.sh` 末尾自动检查规则库时效（>180 天 warn，>365 天 warn 强烈建议重新核实）。

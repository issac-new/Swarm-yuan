# 我花了一个周末，让 AI 学会了"懂项目再写代码"——swarm-yuan 研发纪实

> 你有没有想过：为什么 AI 写代码时总是不懂你的项目规则？
>
> 不是 AI 不够聪明——是没人告诉它。你的 AGENTS.md、CLAUDE.md、分支策略、安全规则、可复用组件清单……AI 一个都没读到。
>
> swarm-yuan 做的事很简单：让 AI 在写代码之前，先花 5 分钟把你的项目从头到脚探查一遍，生成一套专属开发技能——然后每次写代码都遵守这套规则。

---

## 研发动机：三个痛点

### 痛点 1：每个项目都要重新摸索

接手新项目，你花一周才搞清楚：哪些目录能改？哪些只读？分支怎么命名？构建命令是什么？哪些组件可以复用？安全规则是什么？

### 痛点 2：AI 编码不知道项目规则

AI 帮你写代码，但不知道：这个项目不允许随意升级依赖、稳定层不能改签名、有特定的改造分类（A 类纯新增 / B 类骨架修改）、领域有什么客观规律不能违反。

### 痛点 3：代码审查靠人工，漏检率高

提交前你手动检查：有没有硬编码密钥？有没有 SQL 注入？有没有改到不该改的文件？有没有重复造轮子？

---

## 研发过程：15 轮迭代，从 0 到 7600 行

swarm-yuan 不是一次性写出来的。它经历了 15 轮迭代，每轮解决一个真实问题：

### 第一阶段：基础能力（迭代 1-4）

| 迭代 | 做了什么 |
|------|---------|
| 1 | 基础 skill 生成器：六段式模板 + 特征卡 12 项 + 基础门禁 |
| 2 | DDD 分层门禁：层穿透 / 依赖倒置 / 领域污染 / 聚合跨引用 |
| 3 | TOGAF 架构契约门禁：ADR / 接口契约 / BDAT 一致性 / 变更影响 |
| 4 | 微服务 + 前端门禁：共享 DB / 同步链 / 前端状态 / 组件架构 |

**关键决策**：门禁不是"数数量"——每个计数背后指向一条关系规律。`--layer` 数 import 是为了验证"结构是否遵循依赖单向"。

### 第二阶段：认知方法论（迭代 5-7）

| 迭代 | 做了什么 |
|------|---------|
| 5 | 认知递进门禁：六阶认知链 + 六维动力学（速度/聚散/趋势/强度/能耗/累积量） |
| 6 | 五层认知基底：认知递进 → 思维语言 → 认知辩证 → 偏差防范 → 辩证认知 |
| 7 | 领域知识门禁：动态识别技术 + 业务领域，推导客观规律，检测违规 |

**关键突破**：从"门禁堆砌"升级为"认知方法论"。五层认知基底让 swarm-yuan 不只是检查工具——它是一套从"看见"到"想对"到"证伪"到"纠偏"的完整认知框架。

### 第三阶段：深度集成（迭代 8-11）

| 迭代 | 做了什么 |
|------|---------|
| 8 | Claude Code 深度集成：hooks / commands / MCP / Dynamic Workflows / LSP |
| 9 | 项目知识复用：读取 AGENTS.md / CLAUDE.md / 记忆 → skill 引用 |
| 10 | install.sh：自动检测 7 个 AI 工具运行环境 |
| 11 | 零占位符强制：AI 执行完整流程后 grep 确认零残留 |

**关键修正**：研发过程中发现 generate-skill.sh 只生成骨架就停了——用户拿到的是含占位符的半成品。修正为：AI 必须执行完整 11 步流程，最终 grep 确认零占位符才算完成。

### 第四阶段：工程化（迭代 12-15）

| 迭代 | 做了什么 |
|------|---------|
| 12 | 三平台兼容修复：bash 3.2 / C-locale / BSD+GNU（踩了 `declare -A` 和 `$var中文` 两个坑） |
| 13 | 自举验证：用自身 25 个门禁检查自身 |
| 14 | 渐进式披露：SKILL.md 从 699 行精简到 111 行 |
| 15 | 运行时工具调用：gitnexus 19 处 + graphify 7 处 + ocr 11 处 + claude-mem 5 处 |

**关键教训**：在 macOS bash 3.2 上踩了 `declare -A`（不支持关联数组）和 `$var中文`（C-locale 下 bash 把变量名和多字节字符混在一起）两个坑。修复后建立了 C-locale 零残留的自动化检查。

---

## 落地产出：7600 行代码，25 个门禁，零占位符

### 生成器本体

| 文件 | 行数 | 作用 |
|------|------|------|
| SKILL.md | 111 | AI 入口（渐进式披露，只放触发+骨架+指针） |
| precheck.sh | 2255 | 25 个门禁（含运行时工具调用+降级策略） |
| generate-skill.sh | 212 | 骨架生成 + 升级模式 + 运行时自动检测 |
| install.sh | 197 | 7 个 AI 工具环境检测 + 一键安装 |
| self-check.sh | 377 | 10 个运行时自检 + 自动安装 |
| 13 个 reference | 3145 | 方法论 + 认知框架 + 领域知识 + Claude Code 能力 |
| spec-template.md | 302 | 22 段 spec 模板（分级填写） |
| precheck.conf | 62 | 45 个配置变量（AI 自动填充） |
| **总计** | **7627** | |

### 真实项目落地（SwarmStudio overlay 项目）

用 swarm-yuan 对一个 Vue 3 + Electron 桌面应用（overlay 注入式二次开发）生成项目专属技能：

| 文件 | 行数 | 内容 |
|------|------|------|
| SKILL.md | 79 | 项目定位 + 10 铁律 + 命令速查 + 门禁 + 检查表 |
| workflow.md | 50 | 八节点开发流程（含 4-Phase SOP） |
| codebase.md | 59 | 目录树 + 技术栈版本表 + 端口 + Vite alias + 构建机制 |
| dev-guide.md | 45 | A 类/B 类改造分类 + 拼装原则 + 安全规范 |
| release.md | 25 | 编译规则 + 发布规则（仅 arm64.dmg + x64.zip） |
| reference-manual.md | 91 | 安全清单 + 组件库 + 依赖链 + 接口 + 数据字典 + 谬误图谱 |
| snippets.md | 44 | A 类注册 + B 类 patch + alias + 测试命令 |
| mcp-tools.md | 5 | 无外部 MCP 资源 |
| precheck.conf | 45 | 全部真实值，零占位符 |

**门禁测试结果**：`--all` 8✓ + 2✗（reuse 缺 spec + test 1 个失败，均正确）。`--all-full` 19✓ + 3✗ + 3⚠。**零误报。**

---

## 25 个门禁：从分支到认知到领域

### 核心门禁（10 个，`--all`，~5 秒）

分支 / 范围 / 构建 / 敏感信息 / 审查 / 复用 / 依赖 / 安全 / 测试 / 勾稽

### 架构门禁（15 个，`--all-full`，~30 秒）

DDD 分层 / 稳定单元篡改 / 调用链深度 / 架构决策 / 接口契约 / BDAT 一致性 / 变更影响 / 微服务 / API 幂等 / 前端状态 / 组件架构 / 认知体检 / 领域知识 / 项目知识复用 / Mermaid 可视化

### 降级策略

每个门禁优先用运行时工具，无则降级：

```
gitnexus trace（代码图谱）→ graphify explain（知识图）→ madge（依赖树）→ 纯转发统计
ocr review（diff 审查）→ ocr scan（全文件）→ AI 5 维度审查
claude-mem search（记忆库）→ 文件检测
```

**核心理念：有能力就用，无能力降级。不浪费已安装工具，也不因工具缺失崩溃。**

---

## 五层认知基底：不只是门禁

| 层 | 解决什么 | 核心构造 |
|----|---------|---------|
| 认知递进 | 如何认识项目 | 概念→结构→空间→映射→规律→处理 + 六维动力学 |
| 思维语言 | 如何思考 | 三元演化 + 四导向 + 七推理 + 7×7 双循环 |
| 认知辩证 | 如何推演+自证伪 | 4-Phase SOP + 逻辑剃刀 6 步对抗审查 |
| 偏差防范 | 如何纠偏 | 五维偏差扫描 + 思维模型 8 类 |
| 辩证认知 | 如何统一前四层 | 7 对辩证范畴（内容↔形式 / 原因↔结果 / 必然↔偶然…） |

> 门禁不是"数 import 数"——`--layer` 数 import 是为了验证"结构是否遵循依赖单向规律"；`--reuse` 数新增导出是为了验证"概念是否复用了既存稳定单元"。每个计数背后指向一条关系规律。

---

## 10 个运行时 + 32 个领域

### 运行时工具（只引用调用，不重新实现）

OpenSpec / superpowers / comet / GitNexus / graphify / gsd-core / claude-mem / open-code-review / gstack / Ruflo

### 领域知识速查

技术 11 个（数据库 / 缓存 / 网络 / 安全 / 并发 / 前端 / 分布式 / 构建）+ 业务 7 个（IM / 电商 / CRM / 监控 / 金融）+ 专业 14 个（银行卡清算 / 等保 2.0 / ATT&CK / DDD / TOGAF / C4 / 大规模敏捷 / SRE / Kubernetes / 容灾 / 逻辑剃刀）

---

## Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| Hooks | SessionStart 注入状态 + PreToolUse(Write) 范围检查 |
| Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| MCP | 自动注册 gitnexus / claude-mem / graphify |
| Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| LSP | go-to-definition / find-references |
| Subagent | 每任务新 subagent + 两阶段审查 |
| ultrareview | 云端多 agent 审查（可选） |

---

## 研发过程中踩的坑

| 坑 | 原因 | 修复 |
|----|------|------|
| `declare -A` 崩溃 | macOS bash 3.2 不支持关联数组 | 改用 `mktemp` + `awk` 查询 |
| `$var中文` 报错 | C-locale 下 bash 把变量名和多字节字符混在一起 | 全文 `${var}` + 自动化检查零残留 |
| `check_scope` 误报 | `cd node_modules && git status` 获取的是 upstream 状态 | 改为 `git diff --name-only` 路径前缀检查 |
| `RegExp.exec()` 误报为命令注入 | `exec\(` 正则匹配了 `.exec()` | 排除 `.exec(`/`RegExp`/`regex` |
| `v-html` 误报为 XSS | 检测 `v-html` 但未排除已消毒场景 | 排除含 `sanitize`/`renderMarkdown` 的行 |
| install.sh 自我复制 | `SRC_DIR == dest` 时 `mv` 备份把源目录移走 | 加自我复制保护，跳过复制只注册 slash command |
| generate-skill.sh 被清空 | 自我复制 bug 导致 `cp -r` 复制了空目录 | 修复 + 从 GitHub 恢复 |

**每个坑都变成了自动化检查**——C-locale 零残留检查、误报排除模式、自我复制保护。

---

## 自举能力

swarm-yuan 能用自身的 25 个门禁检查自身：

- `--branch`：非 git 仓库时跳过（不崩溃）
- `--security`：通过（无硬性违规）
- `--knowledge`：通过（AGENTS.md/CLAUDE.md 已引用）
- `--cognition`：总分 0/19（预期——swarm-yuan 是生成器不是目标技能）

---

## 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

兼容 7 个 AI 工具：Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi。

---

## 数字一览

| 维度 | 数值 |
|------|------|
| 总代码量 | 7627 行 |
| 质量门禁 | 25 个 |
| 运行时工具 | 10 个 |
| 认知基底 | 5 层 |
| 领域知识 | 32 个领域 |
| Claude Code 能力 | 16 大类 |
| 降级策略 | 33 处 |
| 研发迭代 | 15 轮 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 自举 | ✅ |
| 零占位符 | ✅ |

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**使用说明**：`docs/USAGE.md`

**示例项目**：`Swarm-studio/`（SwarmStudio overlay 零占位符生成物）

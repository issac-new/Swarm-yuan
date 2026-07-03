# 代码审查方法论 (Code Review Methodology)

> 整合自 [gstack](https://github.com/garrytan/gstack) 的审查清单/specialist 模式与 [open-code-review](https://github.com/alibaba/open-code-review) 的 5 维度/规则链/严重度分级。
> 本文件指导目标技能的 check 段如何集成代码审查。
> **仅引用方法与 `ocr` 命令，不复制源码。**

## 五个审查维度（open-code-review 基线）

每个变更审查时覆盖这 5 维度（引自 open-code-review `default.md`）：

| 维度 | 审查问题 |
|------|---------|
| **正确性 Correctness** | 逻辑是否正确？边界条件是否完整？异常处理是否得当？并发场景是否线程安全？ |
| **安全 Security** | 是否有 SQL 注入/XSS 等漏洞？敏感信息处理是否正确？权限校验是否完整？ |
| **性能 Performance** | 是否有明显性能问题（N+1 查询、不必要循环）？资源是否正确释放？ |
| **可维护性 Maintainability** | 代码是否清晰易懂？命名是否准确表达意图？是否遵循项目既有风格与架构？ |
| **测试覆盖 Test Coverage** | 关键逻辑路径是否有测试？测试是否覆盖边界条件？ |

> 目标技能生成时，可按项目语言追加 open-code-review 的语言专项规则（java/ts/rust/c 等），通过 `ocr review --rule <file>` 引用。

## 两遍清单结构（gstack 模式）

审查分两遍，每遍聚焦不同严重度：

### 第一遍：CRITICAL（阻塞性）
- SQL 安全（注入、参数化）
- 竞态条件（check-then-act、非原子复合操作）
- LLM 信任边界（AI 生成代码的注入点）
- Shell 注入 / 命令注入
- 枚举完备性（switch/default 覆盖）
- 认证/授权绕过
- 路径穿越

### 第二遍：INFORMATIONAL（非阻塞）
- 命名一致性
- 注释完整性
- 风格规范
- 小幅性能优化建议

## AUTO-FIX vs ASK 启发式（gstack Fix-First Heuristic）

每个审查发现的处置决策：

> **若修复是机械的、资深工程师会不加讨论地应用 → AUTO-FIX（自动修复）**
> **若合理的工程师可能意见不一 → ASK（询问用户）**

| 发现类型 | 处置 |
|---------|------|
| 明显 bug（空指针、越界、逻辑错误） | AUTO-FIX |
| 安全漏洞（注入、越权） | AUTO-FIX |
| 清晰的拼写错误/死代码 | AUTO-FIX |
| 合理但依赖上下文的风格/性能 | ASK |
| 架构层面的重构 | ASK |
| 可能是误报 | 丢弃（silent discard） |

## 严重度分级（open-code-review 模式）

| 级别 | 含义 | 处置 |
|------|------|------|
| **High** | 明显 bug/安全/清晰错误 | 必须修复 |
| **Medium** | 合理但依赖上下文的风格/性能 | 评估后修复 |
| **Low** | 可能误报 | 静默丢弃 |

## 严格聚焦规则（open-code-review Strict Focus）

> "Context tools are for understanding purposes only. Findings from other files must NOT become the subject of your comments. If you discover a potential issue in another file while gathering context, ignore it — your task is limited to the current diffs."

审查只针对**变更文件**（diff 中 `+` 行）。用上下文工具理解周边代码，但不在其他文件提评论。

## Specialist 并行审查（gstack 模式）

复杂变更可派发并行 specialist subagent，各带专项清单：

| Specialist | 清单 |
|-----------|------|
| Testing | 测试覆盖、边界、mock 正确性 |
| Maintainability | 可读性、命名、DRY、复杂度 |
| Security | OWASP Top 10、STRIDE、注入、越权 |
| Performance | N+1、热路径、资源泄漏 |
| Data Migration | schema 变更、数据迁移、回滚 |
| API Contract | 接口签名、兼容性、版本 |

每个 finding 标 AUTO-FIX 或 ASK。

## 自动化审查工具引用（ocr）

目标技能可引用 [open-code-review](https://github.com/alibaba/open-code-review) CLI 自动审查：

```bash
# 安装（Go 二进制，或 npm 包装）
# 见 https://github.com/alibaba/open-code-review 安装说明

# 审查当前 diff
ocr review --from <base> --to <head> --audience agent

# 审查时附带需求上下文（审查是否正确实现了需求）
ocr review --background "需求描述"

# 全文件扫描（非 diff）
ocr scan --path <dir>

# 指定规则文件
ocr review --rule <project>/.opencodereview/rule.json

# 检查哪个规则会应用
ocr rules check <file>
```

**规则解析链（4 层，first-match-wins）：**
1. `--rule` CLI flag
2. 项目 `<repo>/.opencodereview/rule.json`
3. 全局 `~/.opencodereview/rule.json`
4. 内置 `system_rules.json`

目标技能生成时，可在项目根放 `.opencodereview/rule.json` 定制规则（path glob + rule 内容/文件 + merge_system_rule）。

## 审查与 spec 的关联（gstack plan-completion audit）

审查不只是看代码质量，还要核对**是否完成了 spec/tasks.md 的要求**：

| 验证类型 | 含义 | 判定 |
|---------|------|------|
| DIFF-VERIFIABLE | 可从 diff 直接验证 | DONE / NOT DONE |
| CROSS-REPO | 跨仓库影响 | DONE / PARTIAL / UNVERIFIABLE |
| EXTERNAL-STATE | 外部状态（DB/缓存） | DONE / CHANGED / UNVERIFIABLE |
| CONTENT-SHAPE | 内容形态（输出格式/字段） | DONE / PARTIAL / NOT DONE |

对照 tasks.md 的每个 checkbox，按类型验证完成度。

## 与目标技能的整合

目标技能的 check 段应：
1. 在 `reference-manual.md` 加"代码审查"章节，列 5 维度 + 两遍清单 + AUTO-FIX/ASK
2. 在 `precheck.sh` 加 `--review` 子命令（调用 `ocr review` 若可用，否则提示手动审查清单）
3. 在 workflow 节点⑥（测试验证）引用本审查方法论
4. 在 `dev-guide.md` 引用 subagent 编排时的两阶段审查（spec合规 + 质量）

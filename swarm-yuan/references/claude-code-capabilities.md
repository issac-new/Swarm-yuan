# Claude Code 官方能力全量清单（基于 GitHub releases v2.0.73→v2.1.201 全 159 版 + `claude --help` CLI 调研）

> 本文件基于 https://github.com/anthropics/claude-code/releases **全量 159 个版本**发布说明 + `claude --help` / `claude mcp --help` / `claude agents --help` / `claude plugin --help` / `claude project --help` / `claude ultrareview --help` / `claude install --help` / `claude gateway --help` CLI 调研整理。
> 生成目标技能时，AI 须把以下能力编织进 SKILL.md / workflow.md / reference-manual.md / hooks / commands / settings。

## 一、核心工具（Tools）

| 工具 | 能力 | 目标技能落点 |
|------|------|-------------|
| **Read** | 读文件/目录/图片，支持 offset/limit | 探查阶段读源码 + 按需读 references/ |
| **Write** | 创建/覆盖文件 | 落盘 spec/plan/codebase/reference-manual |
| **Edit** | 精确字符串替换（唯一性校验） | 代码修改 + 模板填充 |
| **Glob** | 文件模式匹配 | 探查目录结构 |
| **Grep** | 正则内容搜索（支持 -o/-c/-l 模式） | 稳定单元盘点 + 敏感信息扫描 |
| **Bash** | 执行 shell 命令（cwd 持久，timeout≤600s，run_in_background） | 运行 precheck.sh / state-machine.sh / npm 命令 |
| **Task**（Subagent） | 派发隔离上下文子代理（不继承主会话，可并行，可选模型） | workflow 节点⑤每任务新 subagent + 两阶段审查 |
| **TodoWrite** | 结构化任务清单（一次一个 in_progress） | workflow 节点清单 + 完成检查表 |
| **AskUserQuestion** | 结构化多选问题（v2.1.200 起不再自动继续，需 /config 开启 idle timeout） | 疑虑确认（7 个必须暂停场景） |
| **WebSearch** | 网络搜索 | 4-Phase SOP Phase 2 强制联网检索 |
| **WebFetch** | 抓取 URL → markdown → 回答问题（15min 缓存，auth URL 失败） | 联网检索上游文档/规范 |
| **SendMessage** | 向运行中的子代理发消息（v2.1.199 修复名称重用路由问题） | subagent 编排中的协调通信 |
| **LSP** | 语言服务器协议工具：go-to-definition / find-references / hover 文档（v2.0.74 引入，v2.1.50 `startupTimeout` 配置） | 代码导航（比 grep 更精确） |
| **Skill** | 发现并调用内置/自定义 skill（v2.1.108 起可发现 `/init`/`/review`/`/security-review` 等内置命令） | 目标技能间互调 |
| **SendUserMessage** | agent→用户通信（`--brief` 启用，v2.1.198） | subagent 向用户汇报 |

## 二、Slash Commands（`/command`）

| 命令 | 能力 | 来源版本 |
|------|------|---------|
| `/config key=value` | 从 prompt 设置任意配置（如 `/config thinking=false`） | v2.1.181 |
| `/model` | 切换模型 | 早期 |
| `/fast` | 快速模式 | 早期 |
| `/effort` | 努力等级（含 `ultracode` xhigh） | v2.1.160 |
| `/mcp` | MCP server 管理（list/reconnect） | 早期 |
| `/plugin` | 插件管理（list/enable/disable，`--enabled`/`--disabled` 过滤） | v2.1.163 |
| `/branch` | 从当前会话派生分支 | 早期 |
| `/diff` | 查看差异面板（切换分支/commit 后自动刷新） | v2.1.198 |
| `/btw` | 附带"c to copy"快捷键复制原始 markdown | v2.1.163 |
| `/dataviz` | 图表/仪表盘设计指导 + 可运行调色板验证器 | v2.1.198 |
| `/background` | 后台化会话 | v2.1.199 |
| `/loop` | 循环调度（v2.1.140 修复冗余唤醒） | v2.1.140 |
| `/goal` | 目标导向（v2.1.140 修复 hook 禁用时静挂） | v2.1.140 |
| `/remote-control` | 远程控制 | v2.1.181 |
| `/desktop` | 桌面模式 | v2.1.198 |
| `/clear` | 清除会话 | 早期 |
| `/compact` | 压缩对话 | 早期 |
| `/code-review [effort]` | 代码审查（原 `/simplify`，v2.1.146 重命名，支持 effort 等级） | v2.1.146 |
| `/recap` | 会话回顾（v2.1.108 引入，可 `/config` 配置或 `CLAUDE_CODE_ENABLE_AWAY_SUMMARY` 强制） | v2.1.108 |
| `/undo` / `/rewind` | 撤销操作（v2.1.108 `/undo` 作为 `/rewind` 别名） | v2.1.108 |
| `/powerup` | 交互式 Claude Code 功能教程 + 动画演示 | v2.1.90 |
| `/context` | 上下文可视化（按来源分组 skills/agents/commands + token 计数，v2.0.74 改进） | v2.0.74 |
| `/terminal-setup` | 终端配置（支持 Kitty/Alacritty/Zed/Warp，v2.0.74 新增） | v2.0.74 |
| `/theme` | 主题选择器（v2.0.73 直接打开，v2.0.74 `Ctrl+T` 切换语法高亮） | v2.0.73 |
| `/doctor` | 健康检查（v2.1.116 起可在 Claude 响应时打开） | 早期 |
| `/permissions` | 权限管理（v2.1.80 Tab 切换改进） | 早期 |
| `/reload-plugins` | 重载插件（v2.1.116 起自动安装缺失依赖） | v2.1.116 |
| `/sandbox` | 沙箱模式 | 早期 |
| **自定义命令** | `.claude/commands/*.md`（frontmatter: name/description/allowed-tools/argument-hint） | 早期 |

> **目标技能可附带 `commands/` 目录**，暴露 `/my-skill:spec`、`/my-skill:precheck`、`/my-skill:explore` 等入口。支持 `$ARGUMENTS` 参数 + `@path` 文件引用。v2.1.199 起支持堆叠调用 `/skill-a /skill-b do XYZ`（最多 5 个）。

## 三、Skills（SKILL.md 自动加载）

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| 描述触发 | `description: "Use when [触发词]"` → AI 自动匹配加载 | 早期 |
| 按需加载 | references/ assets/ scripts/ 只在需要时 Read | 早期 |
| `allowed-tools` | frontmatter 限制技能可用工具 | 早期 |
| `\$` 转义 | 命令体中 `\$` 包含字面 `$`（在数字前） | v2.1.163 |
| `effort` frontmatter | skill/command 的 frontmatter 中 `effort` 覆盖模型努力等级 | v2.1.80 |
| `hooks:` frontmatter | agent 定义中 `hooks:` 在 `--agent` 运行时触发 | v2.1.116 |
| `${CLAUDE_SESSION_ID}` | skill 命令体中替换为当前会话 ID | v2.1.9 |
| `plansDirectory` | 设置项自定义 plan 文件存储位置 | v2.1.9 |
| 条件规则 | `.claude/rules/` 条件规则（v2.1.198 修复符号链接路径不加载） | v2.1.198 |
| 堆叠调用 | `/skill-a /skill-b do XYZ` 加载多个 skill（最多 5） | v2.1.199 |
| slash=skill 合并 | v2.1.3 起合并 slash commands 和 skills（统一心智模型） | v2.1.3 |
| 内置命令可被 Skill 调用 | `/init`/`/review`/`/security-review` 等内置命令可通过 Skill 工具发现调用 | v2.1.108 |
| 内置 Skills | `/dataviz`（图表设计）等内置 skill | v2.1.198 |

## 四、Hooks（生命周期钩子）

| Hook 事件 | 触发时机 | 关键特性 | 来源版本 |
|-----------|---------|---------|---------|
| `SessionStart` | startup/clear/compact | 注入上下文（`hookSpecificOutput.additionalContext`） | 早期 |
| `PreToolUse` | 工具调用前（matcher: `Write\|Edit`/`Bash`/`Read`） | 可阻断/修改工具调用；v2.1.9 起可返回 `additionalContext` 注入模型 | v2.1.9 |
| `PostToolUse` | 工具调用后（matcher: `*`） | 观察工具 I/O | 早期 |
| `Stop` | 会话结束 | v2.1.163 起可返回 `additionalContext` 给 Claude 反馈，保持会话继续 | v2.1.163 |
| `SubagentStop` | 子代理结束 | v2.1.163 起可返回 `additionalContext` | v2.1.163 |
| `SubagentStart` | 子代理启动 | v2.1.199 修复 stderr 隐藏 | v2.1.199 |
| `UserPromptSubmit` | 用户提交 prompt | 语义注入 | 早期 |
| `Notification` | 通知事件 | v2.1.198 起 background agent 完成/需输入时触发（`agent_needs_input`/`agent_completed`） | v2.1.198 |
| `FileChanged` | 文件变更 | 文件监控 | 早期 |
| `PreCompact` | 压缩前 | 压缩前注入 | 早期 |
| `WorktreeCreate` | worktree 创建 | 自定义 VCS 设置 | v2.1.50 |
| `WorktreeRemove` | worktree 移除 | 自定义 VCS 清理 | v2.1.50 |
| `Setup` | 安装时 | 版本检查 | 早期 |
| `ConfigChange` | 配置变更 | v2.1.140 修复符号链接误触 | v2.1.140 |

### Hook 关键特性

- **matcher 精确匹配**：v2.1.195 修复连字符标识符（`code-reviewer`/`mcp__brave-search`）子串误匹配——现在精确匹配，用 `mcp__brave-search__.*` 匹配 MCP server 全部工具
- **if 条件**：`if: "Bash(...)"` 条件匹配（v2.1.163 修复 `$()`/`$VAR` 子 shell 误触）
- **additionalContext 反馈**：Stop/SubagentStop 可返回反馈让 Claude 继续（v2.1.163）
- **stderr 可见**：v2.1.199 修复 SessionStart/Setup/SubagentStart 的 stderr 被隐藏

> **目标技能应附带 `hooks/hooks.json`**：
> - SessionStart → `bash scripts/state-machine.sh get current-phase` 注入当前阶段
> - PreToolUse(Write|Edit) → `bash scripts/precheck.sh --scope --quiet` 检查写入范围
> - WorktreeCreate/Remove → 自定义 VCS 设置/清理

### Hook Runtime Governance（ECC v2.0.0）

ECC 的 hook 系统有 4 层治理——生成的目标技能的 hooks.json 可参考：

| 层 | 机制 | 说明 |
|----|------|------|
| **Stable hook IDs** | `pre:bash:dispatcher` | 每个 hook 有稳定 ID，重装时 dedupe（不重复注册） |
| **Runtime profiles** | `ECC_HOOK_PROFILE=minimal\|standard\|strict` | 按 profile 启用不同 hook 集合 |
| **Env gating** | `ECC_DISABLED_HOOKS` | 环境变量禁用特定 hook，不编辑文件 |
| **Consolidated dispatchers** | 一个 `PreToolUse(Bash)` 入口 fan-out 到多个检查 | 减少 hook 数量，降低开销 |

**目标技能可参考的 hooks.json 结构：**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "id": "pre:bash:dispatcher",
        "matcher": "Bash",
        "command": "bash scripts/hook-dispatcher.sh",
        "profile": "standard"
      }
    ]
  },
  "profiles": {
    "minimal": ["pre:bash:dispatcher"],
    "standard": ["pre:bash:dispatcher", "pre:write:gateguard"],
    "strict": ["pre:bash:dispatcher", "pre:write:gateguard", "pre:write:config-protection"]
  }
}
```

### MCP Health Check（ECC v2.0.0）

ECC 的 `mcp-health-check.js` hook 在 MCP 调用前检查 server 健康：
- 阻断：MCP server 不健康（unreachable / error）
- 放行：MCP server 健康

**目标技能可参考：**
- PreToolUse(mcp__*) hook 中加健康检查
- 防止调用不健康的 MCP server（避免超时/错误）

## 五、Subagent / Background Agents

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| **后台 subagent** | v2.1.198 起 subagent 默认后台运行，Claude 继续工作，完成时通知 | v2.1.198 |
| **并行派发** | 一个响应中多个 Task 调用并行执行 | 早期 |
| **模型选择** | 按任务复杂度选模型（Explore agent 继承主会话模型，上限 opus） | v2.1.198 |
| **文件交接** | 子代理通过文件交接（非粘贴） | 早期 |
| **深度限制** | 前台/后台 subagent 均限制 5 层嵌套 | v2.1.181 |
| **部分结果保留** | v2.1.199 修复 rate limit 截断的 subagent 静默失败——现在返回部分结果 | v2.1.199 |
| **错误报告** | v2.1.199 修复 subagent 把 API 错误报为成功——现在向父代理报告错误 | v2.1.199 |
| **extended thinking 继承** | v2.1.198 起 subagent 和 compaction 继承会话的 extended thinking 配置 | v2.1.198 |
| **isolation: worktree** | agent 定义中声明 `isolation: worktree` 在隔离 git worktree 中运行 | v2.1.50 |
| **`claude agents` CLI** | 列出所有配置的 agent + 会话管理 | v2.1.50 |
| **background agent PR** | v2.1.198 起 background agent 完成代码工作后自动 commit/push/开 draft PR | v2.1.198 |
| **agent teams** | 多代理协作（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`） | v2.1.50 |
| **idle subagent 折叠** | v2.1.199 空闲 subagent 折叠为可展开摘要行 | v2.1.199 |
| **SendMessage 修复** | v2.1.199 修复重用名称时消息误路由 | v2.1.199 |

## 六、Settings（`settings.json` / `settings.local.json`）

| 配置 | 描述 | 来源版本 |
|------|------|---------|
| `permissions.allow/deny` | 工具调用预授权/禁止 | 早期 |
| `hooks` | 注册生命周期钩子 | 早期 |
| `env` | 环境变量 | 早期 |
| `model` | 默认模型 | 早期 |
| `defaultMode` | 权限模式（v2.1.200 起默认 `manual`） | v2.1.200 |
| `availableModels` | 模型白名单 | v2.1.175 |
| `enforceAvailableModels` | 模型白名单强制约束 Default | v2.1.175 |
| `requiredMinimumVersion` / `requiredMaximumVersion` | 版本范围限制 | v2.1.163 |
| `sandbox.allowAppleEvents` | macOS sandbox 内允许 Apple Events | v2.1.181 |
| `disabledMcpServers` / `enabledMcpServers` | MCP server 禁用/启用 | v2.1.200 |
| `disableAllHooks` / `allowManagedHooksOnly` | 禁用全部 hook / 仅允许托管 hook | v2.1.140 |
| `extraKnownMarketplaces` | 额外插件市场 | v2.1.140 |
| `CLAUDE_CODE_SIMPLE` | 极简模式（禁用 MCP/附件/hooks/CLAUDE.md） | v2.1.50 |
| `CLAUDE_CODE_DISABLE_MOUSE_CLICKS` | 禁用鼠标点击/拖拽/悬停（保留滚轮） | v2.1.195 |
| `CLAUDE_CODE_TMPDIR` | 覆盖内部临时文件目录 | v2.1.5 |
| `ENABLE_PROMPT_CACHING_1H` | 启用 1 小时 prompt cache TTL（API key/Bedrock/Vertex/Foundry） | v2.1.108 |
| `FORCE_PROMPT_CACHING_5M` | 强制 5 分钟 TTL | v2.1.108 |
| `plansDirectory` | 自定义 plan 文件存储位置 | v2.1.9 |
| `settings.autoMode.hard_deny` | auto mode 无条件阻断规则 | v2.1.136 |
| `source: 'settings'` | 插件市场来源——在 settings.json 内联声明插件 | v2.1.80 |
| `--channels` | MCP server 主动推送消息到会话（research preview） | v2.1.80 |
| `rate_limits` | statusline 脚本可显示 Claude.ai 速率限制用量 | v2.1.80 |
| `CLAUDE_CLIENT_PRESENCE_FILE` | 在场标记文件（抑制移动推送） | v2.1.181 |

### Settings 优先级
enterprise → `~/.claude/settings.json` → project `.claude/settings.json` → `.claude/settings.local.json`（gitignored）

## 七、MCP（Model Context Protocol）

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| stdio transport | 标准输入输出传输 | 早期 |
| HTTP transport | HTTP 传输 | 早期 |
| OAuth 认证 | MCP OAuth 浏览器认证（v2.1.181 改进 UI） | v2.1.181 |
| `CLAUDE_CODE_SESSION_ID` | stdio MCP server 接收会话 ID（`--resume` 时一致） | v2.1.163 |
| `auto:N` 工具搜索阈值 | MCP 工具搜索自动启用阈值（N=上下文窗口百分比 0-100） | v2.1.9 |
| `--channels` | MCP server 主动推送消息到会话（research preview） | v2.1.80 |
| `add-from-claude-desktop` | 从 Claude Desktop 导入 MCP server（Mac/WSL） | CLI |
| `mcp serve` | Claude Code 自身作为 MCP server 启动 | CLI |
| 分页修复 | `resources/list`/`resources/templates/list`/`prompts/list` 分页服务器不再丢项 | v2.1.146 |
| 工具发现 | tool search 启用时自动发现 MCP 工具 | v2.1.50 |
| `claude mcp get/list` | MCP server 状态检查（v2.1.181 修复 tools/list 失败误报已连接） | v2.1.181 |
| `disabledMcpServers` / `enabledMcpServers` | 按 server 禁用/启用 | v2.1.200 |

## 八、Plugin 系统

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| `.claude-plugin/plugin.json` | 插件元数据（name/version/author） | 早期 |
| `marketplace.json` | 插件市场注册 | 早期 |
| `/plugin list` | 列出已安装插件（`--enabled`/`--disabled`） | v2.1.163 |
| `/plugin enable/disable` | 启用/禁用插件 | 早期 |
| 项目级插件 | `.claude/settings.json` 启用的项目插件 | v2.1.195 |
| worktree 插件 | v2.1.198 修复 worktree 中项目插件不加载 | v2.1.198 |
| `${CLAUDE_PLUGIN_ROOT}` | 插件根目录环境变量 | 早期 |
| 默认组件目录 | `commands/`/`skills/`/`hooks/` 等（v2.1.140 起 `plugin.json` 覆盖时警告） | v2.1.140 |

## 九、Worktree Isolation

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| `isolation: worktree` | agent 定义中声明 worktree 隔离 | v2.1.50 |
| `WorktreeCreate`/`WorktreeRemove` hooks | worktree 创建/移除时触发自定义 VCS 逻辑 | v2.1.50 |
| `EnterWorktree`/`ExitWorktree` | 原生 worktree 管理 | 早期 |
| worktree PR 自动化 | background agent 在 worktree 中完成后自动 commit/push/开 PR | v2.1.198 |

## 十、Context Management

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| `/compact` | 压缩对话释放上下文 | 早期 |
| `/clear` | 清除会话 | 早期 |
| SessionStart(compact) | 压缩后重新注入 | 早期 |
| extended thinking 继承 | v2.1.198 起 compaction 继承 extended thinking 配置 | v2.1.198 |
| 内存优化 | v2.1.50 起长会话清理内部缓存 + compaction 后清理大工具结果 | v2.1.50 |
| transcript 清理 | 30 天 transcript 自动清理 | v2.1.181 |

## 十一、Memory（CLAUDE.md / `/remember`）

| 能力 | 描述 |
|------|------|
| CLAUDE.md | 项目根 / `~/.claude/` / 子目录自动加载为持久指令 |
| `/remember` / `#` | 追加到 CLAUDE.md |
| 优先级 | 用户指令 > skills > 默认 |
| `CLAUDE_CODE_SIMPLE` | 禁用 CLAUDE.md 加载 | v2.1.50 |

## 十二、其他能力

| 能力 | 描述 | 来源版本 |
|------|------|---------|
| **voice dictation** | 语音输入（macOS/Linux，v2.1.195 修复中文/日文无空格语言自动提交） | v2.1.195 |
| **screen reader** | 屏幕阅读器支持（v2.1.200 改进装饰字符隐藏 + 表格读法） | v2.1.200 |
| **plan mode** | 计划模式（只读，v2.1.198 修复浏览器工具调用处理） | v2.1.198 |
| **background sessions** | `claude --bg` 后台会话 + `claude agents` 管理 | v2.1.198 |
| **Claude in Chrome** | Chrome 浏览器集成（v2.1.198 GA） | v2.1.198 |
| **Remote Control** | 远程控制 | v2.1.181 |
| **LSP 集成** | 语言服务器协议（v2.1.50 `startupTimeout` 配置） | v2.1.50 |
| **auto-retry** | API 连接中断自动重试（v2.1.181 改进 mid-thinking 重试） | v2.1.181 |
| **prompt caching** | 提示缓存（v2.1.181 修复自定义 base URL 不读缓存） | v2.1.181 |
| **sandbox** | 沙箱模式（v2.1.181 `allowAppleEvents`） | v2.1.181 |
| **agent teams** | 多代理协作（实验性，`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`） | v2.1.50 |
| **tool search** | 工具搜索（`ENABLE_TOOL_SEARCH=true`） | v2.1.50 |
| **multi-model routing** | 网关多模型路由（anthropicAws/Foundry 等） | v2.1.198 |

---

## 十三、Dynamic Workflows（动态工作流——Claude Code 最强大的编排能力）

> 来源：https://claude.com/blog/introducing-dynamic-workflows-in-claude-code
> 这是 Claude Code v2.1.x 引入的核心编排能力，**让 Claude 自己写 JavaScript 脚本在后台并行调度数十到数百个 subagent**。

### 核心原理

```
用户描述任务 → Claude 生成 JS 编排脚本 → 后台运行时执行 → 并行扇出 N 个 subagent → 交叉验证/自我纠错 → 汇总结果
```

Claude 根据任务描述自动生成一个 JS 脚本，把大任务拆成多个阶段，分配给不同子代理**并行执行**。代理之间可以互相"挑刺"（adversarial review），结果不一致就重新验证。整个过程在后台运行，会话界面保持响应，支持中途暂停和恢复。

### 它能做到但传统方式做不到的 4 件事

| 能力 | 描述 | 传统方式对比 |
|------|------|-------------|
| **并行扇出（Fan Out）** | 一个任务拆成 10-100+ 个子任务同时跑 | 传统 Task 工具只能手动派几个 subagent |
| **自我验证机制** | 代理互相交叉验证，大幅降低幻觉和错误 | 传统方式靠单次 review，无交叉验证 |
| **可恢复（Resumable）** | 长任务（几小时甚至几天）可暂停后继续 | 传统方式 compaction 后状态丢失 |
| **可复用编排** | 优秀 workflow 可保存成 `/your-command`，下次直接调用 | 传统方式每次重新描述 |

### 三种启动方式

| 方式 | 操作 | 适用场景 |
|------|------|---------|
| **手动触发** | prompt 中含 "workflow" / "use a workflow for this" / "create a workflow" | 最灵活，推荐新手 |
| **`/deep-research`** | `/deep-research [研究问题]` | 自动并行搜索+交叉验证+结构化报告 |
| **`/effort ultracode`** | 开启后每个实质性任务自动规划并执行 workflow + xhigh 推理 | 最强大，token 消耗高 |

### 实时监控与保存复用

| 操作 | 快捷键/命令 | 描述 |
|------|------------|------|
| 打开进度面板 | `/workflows` | 查看阶段/代理数/token 消耗/已用时间 |
| 暂停/恢复 | `p` | 暂停或恢复 workflow |
| 停止 | `x` | 停止选中代理或整个 workflow |
| 重启代理 | `r` | 重启某个代理 |
| **保存为命令** | `s` | **保存当前脚本为可复用 `/saved-workflow-name` 命令** |
| 深入查看 | `Enter` | 查看某代理的 prompt/工具调用/结果 |

### 与 Skills / MCP 的本质区别

| 概念 | 定位 | 类比 |
|------|------|------|
| **Skills** | 教 Claude「怎么做」它已经会的事（SOP 化） | 个人技能 |
| **MCP / Connectors** | 给 Claude 接入外部工具和实时数据 | 工具箱 |
| **Dynamic Workflows** | **协调整个团队**去完成单次对话搞不定的大规模复杂任务 | 团队编排 |

### 目标技能如何使用 Dynamic Workflows

生成目标技能时，须在以下位置集成 Dynamic Workflows：

1. **workflow.md 节点⑤（编码实现）**：复杂变更（>3 文件/跨模块/架构变更）时，AI 优先用 Dynamic Workflow 并行执行：
   - prompt 含 "workflow" 关键词触发
   - 拆分任务 → 并行 subagent → 交叉验证
   - 降级策略：简单变更（≤3 文件）用传统 Task(subagent) 单任务派发

2. **workflow.md 节点⑥（测试审查）**：大规模代码审计/安全扫描用 Dynamic Workflow：
   - 多代理并行扫描不同模块 → 交叉验证发现
   - 降级策略：小范围用 `ocr review` / 手动 5 维度清单

3. **spec 模板**：spec §4 tasks 拆分时，如任务数 >5，标注"建议用 Dynamic Workflow 并行执行"

4. **reference-manual.md**：含"Dynamic Workflows 使用指引"段，记录项目适用的 workflow 场景

5. **保存复用**：项目重复的高价值 workflow（如"全量安全审计""跨模块重构验证"）用 `s` 保存为 `/project-workflow-name` 命令

### 降级策略（不可联网/云端时）

| 能力 | 降级方案 |
|------|---------|
| `/deep-research`（需联网搜索） | 降级为本地代码图谱分析（gitnexus query / graphify explain）+ claude-mem search 历史决策 |
| Dynamic Workflow（需后台运行时） | 降级为 Task(subagent) 手动并行派发 + state-machine.sh 管理阶段 |
| 交叉验证（需多代理） | 降级为 superpowers 两阶段审查（spec 合规 + 代码质量） |
| 可恢复（需后台持久化） | 降级为 state-machine.sh `.swarm-yuan/state.yaml` + progress ledger |
| 保存复用（需 `/workflows` 面板） | 降级为手动将 workflow prompt 保存到 `commands/` 目录为 slash command |

---

## 目标技能集成清单

生成目标技能时，AI 须在以下位置集成 Claude Code 能力：

### 1. SKILL.md frontmatter
```yaml
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebSearch, WebFetch, Task, TodoWrite, AskUserQuestion
```

### 2. hooks/hooks.json
- SessionStart → 注入 state-machine 状态 + 项目最新知识
- PreToolUse(Write|Edit) → precheck --scope 范围检查
- WorktreeCreate/Remove → 自定义 VCS 设置

### 3. commands/ 目录
- `/my-skill:spec` → 复制 spec-template + 注入 codebase 上下文
- `/my-skill:precheck` → 运行 precheck.sh $ARGUMENTS
- `/my-skill:explore` → 用 gitnexus/graphify 探查项目

### 4. settings.local.json 推荐
- `permissions.allow`: `Bash(bash scripts/*)`, `Bash(npm test)`, `Bash(gitnexus *)`, `Bash(graphify *)`, `Bash(ocr *)`
- `permissions.deny`: `Bash(rm -rf upstream/*)`, `Bash(git push --force)`

### 5. .mcp.json 推荐
- gitnexus MCP server（`gitnexus mcp`）
- claude-mem MCP server（`npx claude-mem mcp`）
- graphify MCP server（`python -m graphify.serve graph.json`）

### 6. workflow.md 每节点标注
- Claude Code 能力（Task/Read/Write/Edit/Bash/TodoWrite/AskUserQuestion/WebSearch）
- 运行时工具（gitnexus context/graphify path/ocr review/claude-mem search）

### 7. reference-manual.md 含"Claude Code 能力清单"段
- MCP 工具（gitnexus 17 / graphify 7 / claude-mem 3 / 项目自定义）
- Slash 命令（目标技能自带 + 全局已安装）
- Hooks（目标技能注册 + 全局已安装）
- 权限配置（allow/deny）

### 8. 运行时工具贯穿特征卡和开发过程

| 阶段 | 运行时使用 | Claude Code 能力 |
|------|----------|-----------------|
| 特征卡·稳定单元 | gitnexus `context` + graphify `query` | Read/Grep/Glob |
| 特征卡·领域知识 | gitnexus `query` + claude-mem `search` | Read + WebSearch |
| 开发·需求理解 | claude-mem `search` | AskUserQuestion |
| 开发·设计 spec | gitnexus `impact` | Write + WebSearch |
| 开发·编码 | gitnexus `context` + graphify `path` | Task(subagent) + Read/Write/Edit |
| 开发·测试审查 | ocr `review` + gitnexus `detect_changes` | Bash(npm test) |
| 开发·合入发布 | graphify `prs --triage` | Bash(git merge) |
| 门禁·全链路 | 见 precheck.sh 降级链路 | Bash(precheck.sh) |

---

## 十四、CLI 命令全量（`claude --help`）

> 以下来自 `claude --help` 实际输出，是 releases 中未详述的 CLI 级能力。

### 启动选项

| 选项 | 描述 | 目标技能落点 |
|------|------|-------------|
| `--agent <agent>` | 指定当前会话的 agent | 目标技能可定义自定义 agent |
| `--agents <json>` | JSON 定义自定义 agent | 运行时动态注入 agent |
| `--allowedTools <tools...>` | 允许的工具列表 | 限制目标技能可用工具 |
| `--disallowedTools <tools...>` | 禁止的工具列表 | 禁止危险工具 |
| `--append-system-prompt <prompt>` | 追加系统 prompt | 注入项目特定指令 |
| `--system-prompt <prompt>` | 替换系统 prompt | 完全自定义行为 |
| `--bare` | 极简模式：跳过 hooks/LSP/plugin/CLAUDE.md/auto-memory | 纯净环境排查 |
| `--bg` / `--background` | 后台启动会话 | 长任务后台运行 |
| `--brief` | 启用 SendUserMessage 工具（agent→用户通信） | subagent 向用户汇报 |
| `--chrome` / `--no-chrome` | Claude in Chrome 集成开关 | 浏览器集成 |
| `--effort <level>` | 努力等级（low/medium/high/xhigh/max） | 按任务复杂度调整 |
| `--fallback-model <model>` | 主模型过载时降级模型 | 可靠性保障 |
| `--fork-session` | 恢复时创建新 session ID | 分叉实验 |
| `--from-pr [value]` | 从 PR 恢复会话 | PR 关联会话 |
| `--include-hook-events` | 输出流包含 hook 生命周期事件 | 调试 hooks |
| `--include-partial-messages` | 包含部分消息块 | 实时流式 |
| `--input-format <format>` | 输入格式（text/stream-json） | 管道集成 |
| `--json-schema <schema>` | 结构化输出 JSON Schema 校验 | 确保输出格式 |
| `--max-budget-usd <amount>` | API 花费上限 | 成本控制 |
| `--mcp-config <configs...>` | 从 JSON 文件/字符串加载 MCP server | 运行时 MCP 注入 |
| `--model <model>` | 指定模型（别名如 fable/opus/sonnet 或全名） | 模型选择 |
| `--name <name>` | 会话显示名称 | 会话管理 |
| `--output-format <format>` | 输出格式（text/json/stream-json） | 管道集成 |
| `--permission-mode <mode>` | 权限模式（acceptEdits/auto/bypassPermissions/default/dontAsk/plan） | 自动化场景 |
| `--plugin-dir <path>` | 从目录/zip 加载插件 | 临时插件测试 |
| `--plugin-url <url>` | 从 URL 获取插件 zip | 远程插件 |
| `--safe-mode` | 禁用所有自定义（CLAUDE.md/skills/plugins/hooks/MCP/commands/agents） | 排查 |
| `--setting-sources <sources>` | 设置来源（user/project/local） | 配置控制 |
| `--settings <file-or-json>` | 额外设置文件/JSON | 运行时配置注入 |
| `--strict-mcp-config` | 仅用 --mcp-config 的 MCP server | MCP 严格模式 |
| `--tools <tools...>` | 指定内置工具列表 | 工具粒度控制 |
| `--worktree [name]` | 创建 git worktree | 隔离工作空间 |
| `--tmux` | 为 worktree 创建 tmux 会话 | 终端复用 |
| `--add-dir <dirs...>` | 额外允许工具访问的目录 | 跨目录访问 |

### 子命令

| 命令 | 描述 | 目标技能落点 |
|------|------|-------------|
| `claude agents` | 管理后台 agent（`--json` 输出、`--model`/`--effort`/`--permission-mode` 设置） | 多 agent 编排 |
| `claude auth` | 管理认证 | — |
| `claude auto-mode` | 查看 auto mode 分类器配置 | — |
| `claude doctor` | 检查 auto-updater 健康 | 安装排查 |
| `claude gateway` | 运行企业认证/遥测网关 | 企业部署 |
| `claude install [target]` | 安装原生构建（stable/latest/版本号） | 版本管理 |
| `claude mcp` | 配置管理 MCP server | MCP 生命周期 |
| `claude plugin` | 管理插件 | 插件生命周期 |
| `claude project` | 管理项目状态 | 项目状态清理 |
| `claude setup-token` | 设置长期认证 token | 订阅认证 |
| `claude ultrareview [target]` | 云端多 agent 代码审查（当前分支/PR 号/基线分支） | **高级审查能力** |
| `claude update` | 检查+安装更新 | 版本升级 |

### `claude mcp` 子命令

| 子命令 | 描述 | 目标技能落点 |
|--------|------|-------------|
| `mcp add <name> <cmd> [args]` | 添加 MCP server（`--transport http/stdio`、`-e ENV=val`、`--header`） | 注册 gitnexus/graphify/claude-mem |
| `mcp add-from-claude-desktop` | 从 Claude Desktop 导入 MCP server | 迁移 |
| `mcp add-json <name> <json>` | JSON 字符串添加 MCP server | 脚本化注册 |
| `mcp get <name>` | 查看 MCP server 详情（含 pending approval 状态） | 排查 |
| `mcp list` | 列出 MCP server（含健康检查） | 审计 |
| `mcp login <name>` | MCP server OAuth 认证 | 认证 |
| `mcp logout <name>` | 清除 OAuth 凭证 | 清理 |
| `mcp remove <name>` | 移除 MCP server | 清理 |
| `mcp reset-project-choices` | 重置项目级 MCP server 审批 | 重新审批 |
| `mcp serve` | 启动 Claude Code 自身作为 MCP server | **Claude Code 自身可被其他工具调用** |

### `claude plugin` 子命令

| 子命令 | 描述 | 目标技能落点 |
|--------|------|-------------|
| `plugin init\|new <name>` | 脚手架新插件到 `~/.claude/skills/<name>/` | **创建目标技能插件** |
| `plugin install <plugin>` | 从市场安装插件 | 安装依赖技能 |
| `plugin list` | 列出已安装插件（`--enabled`/`--disabled`） | 审计 |
| `plugin enable\|disable` | 启用/禁用插件 | 管理 |
| `plugin details <name>` | 查看插件组件清单 + 预估 token 成本 | **评估插件开销** |
| `plugin eval [target]` | 对插件运行 eval 测试 | **插件质量验证** |
| `plugin tag [path]` | 创建插件发布 git tag | 发布 |
| `plugin uninstall <plugin>` | 卸载插件 | 清理 |
| `plugin update <plugin>` | 更新插件到最新版 | 升级 |
| `plugin validate <path>` | 验证插件/市场清单 | 发布前检查 |
| `plugin prune` | 移除不再需要的自动安装依赖 | 清理 |
| `plugin marketplace` | 管理插件市场 | 市场管理 |

### `claude agents` 选项

| 选项 | 描述 | 目标技能落点 |
|------|------|-------------|
| `--json` | 输出 JSON 数组（含 `--all` 含已完成会话） | 脚本化 agent 管理 |
| `--agent <agent>` | 默认 agent | 指定编排 agent |
| `--model <model>` | 默认模型 | 模型选择 |
| `--effort <level>` | 默认努力等级 | 按需调整 |
| `--permission-mode <mode>` | 默认权限模式 | 自动化 |
| `--cwd <path>` | 按目录过滤会话 | 项目隔离 |
| `--add-dir <dir>` | 额外目录访问 | 跨目录 |
| `--mcp-config <config>` | MCP 配置 | agent 专属 MCP |
| `--settings <file>` | 设置文件 | agent 专属配置 |
| `--plugin-dir <path>` | 插件目录 | agent 专属插件 |

### `claude ultrareview` — 云端多 agent 审查

| 能力 | 描述 | 目标技能落点 |
|------|------|-------------|
| 云端多 agent 审查 | 审查当前分支/PR 号/基线分支 | **`--review` 门禁的增强版** |
| `--json` | 输出原始 bugs.json | 结构化审查结果 |
| `--timeout <minutes>` | 最大等待时间（默认 30 分钟） | 长审查控制 |

> **目标技能的 `--review` 门禁可在 ultrareview 可用时调用它**：`claude ultrareview --json` 获取云端多 agent 审查结果，比本地 ocr review 更全面。

### `claude project purge` — 项目状态清理

| 能力 | 描述 | 目标技能落点 |
|------|------|-------------|
| 清理项目状态 | 删除 transcript/tasks/file history/config entry | 卸载目标技能时清理 |

---

## 十五、目标技能可用的全部能力速查（按开发阶段）

| 阶段 | Claude Code 原生 | CLI 命令 | 运行时工具 | MCP 工具 |
|------|-----------------|---------|-----------|---------|
| **探查** | Read/Glob/Grep/WebSearch | `claude mcp list`（查 MCP） | gitnexus analyze / graphify . | gitnexus query/context |
| **特征卡** | Read/Write | — | gitnexus context / graphify explain / claude-mem search | gitnexus context |
| **spec 设计** | Write/WebSearch/AskUserQuestion | — | gitnexus impact / ocr scan | gitnexus impact |
| **编码** | Task(subagent)/Read/Write/Edit/Bash | — | gitnexus context / graphify path | gitnexus context |
| **审查** | Bash/Read | `claude ultrareview` | ocr review / ocr scan | — |
| **测试** | Bash | — | gitnexus detect_changes | — |
| **门禁** | Bash | — | 见 precheck.sh 降级链路 | — |
| **发布** | Bash | `claude agents`（后台 PR） | graphify prs --triage | — |
| **记忆** | Write/Read | — | claude-mem search/timeline/get_observations | claude-mem search |
| **状态管理** | Bash/Read/Write | — | state-machine.sh init/get/set/transition | — |
| **调用追踪（贯穿全程）** | 每步 stdout 公告 `→ [节点X] 调用 …` | — | trace-log.sh --node/--actor/--tool（落盘 `.swarm-yuan/trace.jsonl`） | — |
| **插件管理** | — | `claude plugin init/list/eval` | — | — |
| **MCP 管理** | — | `claude mcp add/list/get/serve` | — | — |

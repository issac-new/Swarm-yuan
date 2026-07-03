# reference-manual.md — SwarmStudio 参考手册（reference §2/4/5/6/7/8 + check §1/2/3/4 + goal-backward）

> 本文件是 Swarm-studio 技能的详细参考手册。安全/组件/依赖链/API/UI/数据段 + 检查段（测试/业务规则/勾稽/UI核对/对抗验证）。

## §2 安全

### 敏感信息检查清单（precheck.sh --sensitive）

扫描 `custom/` `patches/` `packages/` 下：
- API key 模式（`sk-...`、`AKIA...`、`api_key=...`、`secret=...`、`token=...`）
- 连接串含密码（`mongodb://user:pass@`、`redis://`、`postgres://`）
- 私有 IP（排除 url-guard.ts 已处理的合法白名单）
- LLM API keys：用户自配（OPENROUTER/GOOGLE/GLM），**非本地基础设施**——禁止硬编码

### SSRF 防护：url-guard.ts

`url-guard.ts`（187 行）提供出站 URL 安全校验：
- `assertSafeOutboundUrl(url)` — 校验出站 URL
- `safeMatrixOrigin(url)` — Matrix homeserver origin 校验
- 协议白名单：https 默认；`allowHttp` 仅 loopback / Matrix
- 私有 IP 黑名单：含 `169.254.169.254`（云元数据端点）
- DNS rebinding 检查

### Electron 安全（patch 119-122）

| patch | 标识 | 内容 |
|-------|------|------|
| 119 | `119-desktop-preload-no-strip-credential` `[SecPreloadNoStrip]` | preload 不剥离凭证 |
| 120 | `120-server-restrict-query-token` `[SecNoQueryToken]` | `?token` query JWT 白名单：仅 `/api/hermes/media/apikey-image-generate` + `grok-image-to-video` |
| 121 | `121-desktop-electron-sandbox` `[SecElectronSandbox]` | `sandbox: true` |
| 122 | `122-groupchat-sidebar-logout` | 群聊侧边栏登出 |

### trace.ts 沙箱

`trace.ts`：
- sessionId 正则 `^[A-Za-z0-9._-]+$`
- `isPathWithin()` 路径穿越防护 `[SecTraceSandbox]`

### agent-health 认证（patch 107）

- `ctx.state.user` 认证 `[SecAgentHealthAuth]`
- 路径白名单 `[SecAgentHealthPath]`
- 代理到 `:8650`，`Authorization: Bearer $API_SERVER_KEY`

## §4 组件

### cockpit（33 .vue）

核心：`CockpitView`, `CockpitWorkspace`, `CockpitTopBar`, `CockpitKanban`, `CockpitChatPane`, `CockpitFilePanel`, `CockpitTimeline`, `CockpitGraphNode`, `CockpitRunTraceModal`。
RunTrace 系列（8）：`RunTraceGraph`/`Inspector`/`NodeDetail`/`Overview`/`Scrubber`/`SkillDrilldown`/`TimeBand`/`TimelinePanel`/`Topology`。
Store：`cockpit.ts`（1452 行）+ `cockpit-kv.ts`（105 行，localStorage）。

### matrix-chat（50 .vue）

核心：`MatrixChatView`, `MatrixRoomView`, `MatrixMessageList`, `MatrixMessageInput`, `MatrixRoomList`, `MatrixRoomHeader`。13 Dialogs。
Store：`matrix-room.ts`（1302 行）+ `matrix-composer.ts`（432 行）+ `matrix-thread`/`client`/`right-panel`/`events`。

### kanban（15 .vue）

核心：`SwarmKanbanView`, `KanbanBoard`, `KanbanColumn`, `KanbanTaskCard`, `KanbanTaskDrawer`, `KanbanToolbar`, `KanbanOrchestrationPanel`。

### chat（1 .vue）

`GatewayNoticeBanner`。

### branding（0 .vue）

`index.ts` stub（无组件）。

### UI 栈

NaiveUI ^2.44 + **"Pure Ink" 主题**（黑白灰，状态色仅 3 色）+ ECharts + Mermaid + Monaco + xterm + vue-flow。

## §5 依赖链

```
App.vue(upstream) → router(patch 071 → /hermes/cockpit nested) → CockpitView(custom)
  → {CockpitWorkspace→sub, CockpitRunTraceModal→RunTrace*,
     MatrixChatView→sub, SwarmKanbanView→sub}
```

**注册链**：`entry.mts`（shim，复刻 upstream main.ts，在 `app.use(router)` 与 `app.mount()` 间插入）→ `bootstrap.ts`（动态 import + `isFeatureEnabled` flag 守卫）→ `registerRoute`/`registerNavEntry`/`registerComponent`（`@registries/client`）→ `router.addRoute`（before mount）。

**依赖查询**：用 `graphify path "ComponentA" "ComponentB"` 或 GitNexus MCP（`shortest_path`）替代 grep。见 references/code-graph-tools.md。

## §6 API

### A 类 API（custom/）

| API | 说明 |
|-----|------|
| trace | `GET /api/hermes/sessions/:id/trace`（读 JSONL，检测 OTel/legacy） |
| matrix admin-service | 用户 CRUD（经 `safeMatrixOrigin`） |
| matrix/routes.ts | stub |
| kanban/index.ts | stub |

### B 类 API（patch）

| patch | 路由 | 内容 |
|-------|------|------|
| 012 | `POST /api/auth/matrix-login` | public + IP 限流 + SSRF；matrix-users CRUD |
| 035 | `/api/hermes/kanban/*` | orchestration / dispatch / attachments / decompose / patchTask / deleteTask |
| 107 | `/agent-health/*` | 代理→:8650 |
| 114 | mount traceRoutes | 挂载 trace 路由 |

### OpenAPI

`generate-openapi.mjs`（993 行，正则扫描 `routes/**`）→ `docs/openapi.json`（OpenAPI 3.0.3，BearerAuth）。

### MCP

**hermes-studio-mcp.mjs**：stdio MCP，toolsets `api`/`devices`/`use`（~25 use tools + ~15 lan tools）。自动注入 3 个 managed servers。
**hermes mcp serve**：conversations/messages/events。
**无 MCP DB tool**（embedded SQLite，无外部 DB）。

## §7 UI/UX

- **设计文档**：`docs/superpowers/specs/`（29 files，`YYYY-MM-DD-<topic>-design.md`）
- **Pure Ink 主题**：黑白灰，状态色仅 3 色
- **branding**：patch 032；`logo.png`；`cockpit.scss`
- **rebrand**：patch 041-043
- **i18n**：patch 044-053；`node scripts/add-i18n-keys.mjs`

## §8 数据

### SQLite schema

- 位置：`packages/server/src/db/hermes/schemas.ts`（834 行，26 张表）
- 引擎：`node:sqlite` `DatabaseSync`（embedded）
- prod：WAL + `foreign_keys=ON`
- **无 seed/fixture 数据**

### users 表 patch 001

patch 001 为 users 表新增 5 列：
- `matrix_user_id TEXT UNIQUE`
- `matrix_display_name TEXT`
- `matrix_avatar_url TEXT`
- `matrix_homeserver_url TEXT`
- `auth_source TEXT NOT NULL DEFAULT 'local'`

> SQLite `ADD COLUMN UNIQUE` 限制：先 strip `UNIQUE` 加列，再 `CREATE UNIQUE INDEX`（允许多个 NULL）。

### RunTrace 流

```
hermes-agent-plugins/run-trace/(Python OTel)
  → JSONL ~/.hermes/traces/<session_id>.jsonl
  → trace.ts(read, detect OTel/legacy)
  → GET /api/hermes/sessions/:id/trace
  → run-trace-adapter.ts(normalizeRunEvent)
  → trace-middlewares.ts
  → RunTrace*.vue
  → cockpit-kv.ts(localStorage)
```

evidence L1/L2/L3。

---

# check 段

## check §1 测试

- **vitest**：`overlay/vitest.config.ts`（手维护），pattern `custom/**/*.test.ts`，**37 files**（34 cockpit + 2 chat + 1 server security），setup `custom/client/test/setup.ts`（ResizeObserver/localStorage/matchMedia/i18n）
- **gsd 6 测试契约**：
  1. 练习真实代码，非源码文本（禁 `readFileSync`+`.includes`）
  2. 无空真断言（LHS 须 SUT 计算）
  3. 无 pass-always 测试（特性缺失须失败）
  4. 测试声称路径（别 mock 整个 SUT）
  5. 完整 mock（只 mock I/O，非 SUT 业务逻辑）
  6. 负空间反测（12 例 QA 矩阵）

## check §2 业务规则

| 规则 | 影响 |
|------|------|
| A 类注册须在 mount 前 | `router.addRoute` 在 `app.mount()` 前 |
| off-means-off | flag off 时不注册（by construction） |
| overlay-only 修改 | `upstream/` 只读 |
| patch 路由前缀 | hermes_cli/plugins/agent/apps/assets/acp_ → hermes-agent（容错）；其余 → hermes-studio（fatal） |
| dev server 期间禁 upstream checkout/clean | 破坏注入态 |
| release 仅 arm64.dmg + x64.zip | 不产其他 |
| 后端 CJS | `custom/server` 无 `type:module` |
| SQLite ADD COLUMN UNIQUE | strip UNIQUE 后 CREATE UNIQUE INDEX |
| ?token query JWT 白名单 | 仅 patch 120 两端点 |

## check §3 勾稽（无多漏错重，6 项）

- [ ] **无遗漏**：关联记录无缺失（如 session→messages 无孤儿）
- [ ] **无多余**：无冗余/重复记录
- [ ] **记录正确**：字段值符合业务规则（如 auth_source 默认 'local'）
- [ ] **勾稽正确**：外键/聚合/关联关系正确（foreign_keys=ON）
- [ ] **一致性**：同源数据多处一致（如 matrix_user_id 与 users 表）
- [ ] **幂等性**：重复请求不产生副作用（inject ensure-injected 幂等）

## check §4 UI 核对 + goal-backward 对抗验证

### UI 核对

- Pure Ink 主题：黑白灰，状态色仅 3 色
- 组件依赖链与 spec 一致（graphify path 验证）
- feature flag 守卫生效（off 时不渲染）
- i18n key 齐全（add-i18n-keys.mjs）

### goal-backward 对抗验证（gsd 模式）

**核心口号**：「Task completion ≠ Goal achievement」

验证流程：
1. **读 spec/tasks**——「阶段应交付什么」
2. **FORCE 立场**——假设阶段目标未达成，直到代码库证据证明。起始假设：任务完成了，目标没达成。证伪 SUMMARY 叙事。
3. **不信任 SUMMARY**——SUMMARY 记录的是 Claude 说了什么。验证代码里实际存在什么。两者经常不同。
4. **发现分类严格**——只有 **BLOCKER** / **WARNING**。没有分类的发现不是有效输出。
5. **记录「审查者如何变软」**——例如对实际是 blocker 的发 warning 以避免冲突——这是要避免的失败模式。

**5 维度审查**（gstack/OCR）：

| 维度 | 审查问题 |
|------|---------|
| 正确性 Correctness | 逻辑正确？边界条件？异常处理？并发安全？ |
| 安全 Security | SQL 注入/XSS？敏感信息？权限校验？ |
| 性能 Performance | N+1 查询？资源释放？ |
| 可维护性 Maintainability | 清晰易懂？命名准确？遵循既有风格？ |
| 测试覆盖 Test Coverage | 关键路径有测试？覆盖边界？ |

**处置**：AUTO-FIX（机械修复，资深工程师不加讨论应用）vs ASK（可能意见不一，询问用户）。

**严重度**：High（必修）/ Medium（评估）/ Low（丢弃）。

**两遍清单**：第一遍 CRITICAL（SQL/竞态/LLM 信任边界/Shell 注入/枚举完备/认证授权/路径穿越）；第二遍 INFORMATIONAL（命名/注释/风格）。

**严格聚焦**：审查只针对变更文件（diff `+` 行）。用上下文工具理解周边，但不在其他文件提评论。

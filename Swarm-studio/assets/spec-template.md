# 设计文档：<feature 名称>

> 日期: YYYY-MM-DD
> 状态: 草案 / 已评审 / 已实施
> 归档到: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`（现有 29 files 规范）
> 关联: （引用相关需求、上游 issue、已有 spec）

## 1. 背景与目标

### 1.1 现状
（描述当前状态、痛点、为什么做这个。涉及 upstream hermes-studio v0.6.23 / overlay hermes-overlay v0.6.22-overlay）

### 1.2 目标
1. （明确、可验证的目标）

### 1.3 非目标
- （明确不做什么，防止范围蔓延）

## 2. 决策记录

| 决策 | 选择 | 备选 | 理由 |
|------|------|------|------|
| 改造类型 | A类 / B类 / 混合 | — | A类优先（overlay/custom），B类仅当须改 upstream |
| feature flag | （如 cockpit / matrixChat / kanbanEnhancements） | — | off-means-off 守卫 |
| （其他决策） | | | |

> **改造类型决策树**：新增组件/store/路由/API（upstream 无）→ A类；修改 upstream 既有文件 → B类；混合 → A类为主 + B类补丁。

## 3. 改造类型与侵入点

### 3.1 A类（overlay/custom/，优先）

- 新增/修改文件清单：
  - `custom/client/<feature>/<Name>.vue` — 组件
  - `custom/client/<feature>/stores/<name>.ts` — Pinia store
  - `registries/client/bootstrap.ts` — 动态 import + `isFeatureEnabled` flag 守卫
  - `custom/server/src/...` — Koa 后端（package.json CJS 无 type:module）

注册方式：`registerRoute` / `registerNavEntry` / `registerComponent`（`@registries/client`），经 bootstrap.ts 动态 import + flag 守卫，`router.addRoute` 在 `app.mount()` 前。

依赖链示例：`App.vue(upstream) → router → CockpitView(custom) → sub`（用 `graphify path` 查询）

### 3.2 B类（overlay/patches/，HERMES_CUSTOM 路由前缀）

- 侵入点清单：

| 目标文件 | patch 号 | 改动内容 | 标识 | 路由前缀 |
|----------|----------|----------|------|----------|
| `upstream/hermes-studio/...` | NNN-<tag>-<desc> | | `HERMES_CUSTOM[Tag] BEGIN/END` | hermes-studio（fatal） |
| `upstream/hermes-agent/...` | NNN-<tag>-<desc> | | `HERMES_CUSTOM[Tag] BEGIN/END` | hermes_cli/plugins/agent/apps/assets/acp_ → hermes-agent（容错跳过） |

patch 末尾追加 `patches/series`（当前 83 个活跃）。

## 4. Spec Delta（OpenSpec 格式，specs as source of truth）

> 采用 OpenSpec delta spec 格式。每个 capability 一个 `specs/<name>/spec.md`。
> Requirement 用 SHALL/MUST；Scenario 用 WHEN/THEN；#### 4 个 hashtag。

### ADDED Requirements

### Requirement: <需求名>
<需求描述，用 SHALL/MUST>

#### Scenario: <场景名>
- **WHEN** <条件>
- **THEN** <预期>

### MODIFIED Requirements
> 必须包含完整更新内容（从主 spec 复制）

### REMOVED Requirements
> 必须包含 **Reason** 和 **Migration**

## 5. 详细设计（design.md，可选——复杂变更才写）

### 5.1 Context
### 5.2 Goals / Non-Goals
### 5.3 Decisions（含 Rationale + Alternative considered）
### 5.4 Risks / Trade-offs（[Risk] → Mitigation）

## 6. 前端/UI
（组件结构、路由、状态、交互流程。依赖链从代码图谱查询：`graphify path "A" "B"` 或 GitNexus MCP）

UI 栈：NaiveUI ^2.44 + Pure Ink 主题（黑白灰，状态色仅 3 色）+ ECharts + Mermaid + Monaco + xterm + vue-flow

## 7. 后端/逻辑
（接口、数据模型、业务逻辑。后端在 custom/server/，Koa ^2.15.3，CJS 无 type:module）

## 8. 接口
（新增/修改的 API，方法/路径/入参/出参）

A类 API：trace `GET /api/hermes/sessions/:id/trace` / matrix admin-service / kanban stub
B类 API：patch 012(`POST /api/auth/matrix-login`) / 035(`/api/hermes/kanban/*`) / 107(`/agent-health/*`) / 114(mount traceRoutes)

OpenAPI：`generate-openapi.mjs` 扫描 `routes/**` → `docs/openapi.json`（OpenAPI 3.0.3 BearerAuth）。`?token` query JWT 白名单仅 patch 120 两端点。

## 9. 静态资源与页面元素填充（assets §5）
- 需下载/新增的静态资源：（图片/字体/配置文件，路径与来源。如 logo.png → overlay/assets/）
- 页面元素填充：（占位元素 → 真实数据的映射方式）
- 资源引用方式：（import / public 目录 / CDN）

## 10. 数据设计
（schema 变更、数据流、勾稽关系。样例数据见 assets/data-sample-template.md）

DB：embedded SQLite（node:sqlite DatabaseSync），`<DB_DIR>/hermes-web-ui.db`。schema 在 `packages/server/src/db/hermes/schemas.ts`（834 行，26 表）。prod WAL + foreign_keys=ON。无 seed/fixture。

SQLite ADD COLUMN UNIQUE 限制：strip UNIQUE 后 CREATE UNIQUE INDEX（允许多个 NULL）。

## 11. 测试策略
- 单测覆盖：`custom/**/*.test.ts`（vitest，37 files 基线），setup `custom/client/test/setup.ts`
- 手动验证步骤：`npm run dev`（8649 前端 + 8647 后端）
- 回归边界：`npm run clean && npm run inject && npm test`
- 业务规则案例：（check §2，列出案例数据与预期）
- 数据勾稽核对：（check §3，无多漏错重 6 项：无遗漏/无多余/记录正确/勾稽正确/一致性/幂等性）
- gsd 6 测试契约：练习真实代码/无空真断言/无 pass-always/测试声称路径/完整 mock/负空间反测

## 12. 风险与回滚
- 风险：
- 回滚方式：A类删除 custom 文件+注册；B类从 patches/series 移除后 `npm run clean && npm run inject`

## 13. 参考资料
- 相关 spec：`docs/superpowers/specs/`
- 上游文档：upstream hermes-studio v0.6.23
- 安全：url-guard.ts（SSRF）、patch 119-122（Electron）、trace.ts（沙箱）、patch 107（agent-health）

# dev-guide.md — ncwk 开发指南（reference §7）

> 本文件指导 A 类/B 类改造的具体开发流程。配套：codebase.md（结构）、workflow.md（流程）、snippets.md（模板）。

## A 类 / B 类 决策树

```
需求
 ├─ 新增组件/store/路由/API（upstream 无对应物）？ → A 类（overlay/custom，优先）
 ├─ 修改 upstream 既有文件逻辑？ → B 类（overlay/patches）
 └─ 两者混合？ → A 类为主 + B 类补丁（如改 App.vue 路由挂载需 patch 071）
```

**优先 A 类**。A 类无法覆盖（必须改 upstream 源文件）才用 B 类。

## A 类开发（overlay/custom）

### 目录约定

| 内容 | 位置 |
|------|------|
| Vue 组件 | `custom/client/<feature>/<Name>.vue` |
| Pinia store | `custom/client/<feature>/stores/<name>.ts` |
| composables | `custom/client/<feature>/composables/` |
| 路由/导航/组件注册 | `registries/client/` |
| Koa 后端 | `custom/server/src/` |
| Agent 插件 | `custom/hermes-agent-plugins/` |
| 测试 | `custom/client/test/`（pattern `custom/**/*.test.ts`） |

### 注册机制（关键）

通过 `registries/client/` 的三个注册函数接入：

| 函数 | 作用 |
|------|------|
| `registerRoute(routeConfig)` | 注册路由（router.addRoute，在 app.mount 前） |
| `registerNavEntry(entry)` | 注册导航菜单项 |
| `registerComponent(name, comp)` | 注册全局组件 |

**注册链**：`entry.mts`（入口 shim，复刻 upstream main.ts，在 `app.use(router)` 与 `app.mount()` 之间插入注册）→ `bootstrap.ts`（动态 import 组件 + `isFeatureEnabled` flag 守卫）→ `registerRoute/registerNavEntry/registerComponent`（写入 `@registries/client` 注册表）→ `router.addRoute`（在 mount 前）。

**动态 import + flag 守卫**：bootstrap.ts 用 `isFeatureEnabled('cockpit')` 等守卫，flag off 则不注册（off-means-off，by construction）。

**依赖链示例**（cockpit）：`App.vue`(upstream) → router(patch 071 → `/hermes/cockpit` nested) → `CockpitView`(custom) → `{CockpitWorkspace→sub, CockpitRunTraceModal→RunTrace*, MatrixChatView→sub, SwarmKanbanView→sub}`。

### A 类后端

- `custom/server/package.json` 用 **CJS**（不设 `type:module`），避免 ERR_REQUIRE_ESM
- inject 时 symlink `server/src/custom` 到 upstream
- 改后端需**重启** `bash scripts/serve-server.sh`（无 HMR）
- API 路由放 `controllers/` 或 `patch routes`，OpenAPI 经 `generate-openapi.mjs` 扫描 `routes/**`

### A 类开发流程

1. `npm run ensure-injected`（确保注入态）
2. 在 `custom/client/` 新建组件/store
3. 在 `registries/client/bootstrap.ts` 加动态 import + flag 守卫
4. 调用 `registerRoute`/`registerNavEntry`/`registerComponent`
5. `npm run dev`（HMR，端口 8649 前端 + 8647 后端）
6. `npm test` 验证

## 组件代码填充顺序

新增一个功能组件时，按此顺序填充：

1. **Domain/Entity TS 类型** — 先定义数据模型（`custom/client/<feature>/types.ts` 或 `entities/`）
2. **Interface/API** — 定义 params/controllers；patch routes 用 `@/api`；OpenAPI 由 `generate-openapi.mjs` 扫描 `routes/**` 生成 `docs/openapi.json`（OpenAPI 3.0.3 BearerAuth）；`?token` query JWT 白名单见 patch 120（仅 `/api/hermes/media/apikey-image-generate` + `grok-image-to-video`）
3. **Task flow** — `registerRoute` → `bootstrap.ts` → `router.addRoute`（before mount）；数据流：API → adapter → store → component
4. **依赖查询** — 用 graphify path / GitNexus MCP 查依赖链（替代 grep），见 references/code-graph-tools.md

## B 类开发（overlay/patches）

### 流程

1. `npm run verify` — 确认注入态干净
2. 临时编辑 upstream 文件（**仅在非 dev server 运行时**）
3. `git diff > patches/NNN-<tag>-<desc>.patch`（NNN 接现有最大号 +1）
4. **dev server 运行期间禁止 `git checkout` 还原 upstream**（会破坏注入态）
5. 末尾追加 `patches/series`
6. `npm run clean && npm run inject` — 重新注入验证
7. `npm test`

### patch 格式

- unified diff
- 用 `HERMES_CUSTOM[Tag] BEGIN/END` 标识块（Tag 如 `[SecPreloadNoStrip]`、`[SecNoQueryToken]`）
- 路由前缀决定目标：`hermes_cli/` `plugins/` `agent/` `apps/` `assets/` `acp_` → hermes-agent（容错跳过）；其余 → hermes-studio（fatal）

### i18n

```bash
node scripts/add-i18n-keys.mjs        # 通用
node scripts/add-matrixchat-i18n.mjs  # matrix-chat 专用
```

### 冲突处理

`git apply --reject` — 查看被拒绝的 hunk，手动调整 patch。

## dev server 约束

- `npm run dev` 启动前端（8649）+ 后端（8647），`predev=ensure-injected`
- **运行期间禁止**：`git checkout`/`git clean` upstream（破坏注入态）；改后端需重启 `serve-server.sh`
- 前端 HMR 生效；后端无 HMR
- `--strictPort`：8649 占用即失败，不自动换端口

## sync upstream

```bash
npm run sync   # bash scripts/sync-upstream.sh
```

同步后需 `npm run clean && npm run inject` 重新注入（patch 可能需更新以适配 upstream 变更）。

## 首次启动

1. `cd /Volumes/nvme2230/lab/ncwk/overlay`
2. `bash .agents/skills/ncwk-dev/assets/env-setup.sh` — 检测 Node>=23 / Python>=3.11 / git/gh/docker
3. `npm run ensure-injected` — 确保注入态（首次会 inject）
4. `npm run verify` — 校验干净
5. `npm run dev` — 启动开发

## 同版本缓存

- overlay node_modules 是指向 upstream 的符号链接（overlay 无自有 deps）
- inject 后若 upstream 版本未变，重复 `npm run inject` 是幂等的（ensure-injected 跳过已完成步骤）
- 切换 upstream 版本（sync）后必须 `clean && inject` 重建

## desktop prepare:runtime（发布前）

`packages/desktop` 的 `prepare:runtime` 脚本（build:dmg 前置）：
- `fetch:node` — 从 nodejs.org/dist 拉取 Node 运行时
- `fetch:python` — python-build-standalone（`PBS_TAG=20260510`，`PBS_PY=3.12.13`）
- `fetch:git` — 仅 Windows
- `install:hermes` + `patch:hermes` — 安装并 patch hermes-agent

详见 references/release.md。

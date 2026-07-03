# release.md — ncwk 构建与发布（reference §3）

> 本文件指导 build:full 与 build:dmg 流程。规则引用 AGENTS.md / 项目记忆，不硬编码敏感策略。

## 前置条件

- 已合入 main（`merge: <branch>`，`--no-ff`）
- `npm run verify` 注入态干净
- `precheck.sh --sensitive` 通过（敏感信息检查）
- `precheck.sh --test` 全绿（37 files）
- RELEASE-NOTES.md 已更新
- **需用户明确确认方可发布**

## 编译规则

| 规则 | 说明 |
|------|------|
| 必须用 overlay 的 `build:full` | **禁止用 upstream 的 `npm run build`**（overlay build 含 openapi/tsc/build-server） |
| build:dmg 绕过 upstream dist | `electron-builder --publish never`，不走 upstream `npm run dist` |
| release 产物仅 arm64.dmg + x64.zip | 不产其他架构/格式 |
| push 前敏感检查 | `precheck.sh --sensitive` |
| 不自动 push | 除非用户明确确认 |

## build:full（4 步）

`npm run build:full` = `node scripts/build.mjs`：

1. **openapi:generate** — `node scripts/generate-openapi.mjs`（993 行，正则扫描 `routes/**`）→ `docs/openapi.json`（OpenAPI 3.0.3 BearerAuth）
2. **vite build** — `vite build --config vite.config.overlay.ts`（prebuild=ensure-injected）
3. **tsc --noEmit** — 类型检查
4. **build-server** — 构建后端

**产物**：`upstream/dist/`

> ⚠️ 必须用 overlay `build:full`，非 upstream `npm run build`——后者缺少 openapi/tsc/build-server 步骤。

## build:dmg（5 步）

`npm run build:dmg:mac` / `:win` = `node scripts/build-dmg.mjs --mac` / `--win`：

1. **inject** — `npm run inject`（确保注入态）
2. **build:full** — 上述 4 步
3. **npm ci desktop** — `cd packages/desktop && npm ci`
4. **tsc main** — 编译 Electron main 进程
5. **electron-builder --publish never** — 打包（不发布）

**绕过 upstream `npm run dist`**——直接调 electron-builder。

### prepare:runtime（build:dmg 前置）

`packages/desktop` 的 `prepare:runtime`：
- `fetch:node` — 从 `nodejs.org/dist` 拉取 Node 运行时
- `fetch:python` — python-build-standalone（`PBS_TAG=20260510`，`PBS_PY=3.12.13`）
- `fetch:git` — 仅 Windows
- `install:hermes` + `patch:hermes` — 安装并 patch hermes-agent

## 命令与产物

| 命令 | 产物 |
|------|------|
| `npm run build:full` | `upstream/dist/`（Web 构建产物） |
| `npm run build:dmg:mac` | `packages/desktop/release/SwarmStudio-0.6.23-arm64.dmg` + `.zip` |
| `npm run build:dmg:win` | `packages/desktop/release/` 下 `x64.exe` + `.zip` + `.msi` |

desktop 版本：swarmstudio v0.6.23（electron ^42.3.0, electron-builder ^25.1.8, electron-updater ^6.3.9）。

## 发布规则（引用 AGENTS.md / 项目记忆，不硬编码）

- **release 产物仅 arm64.dmg + x64.zip**（mac arm64 / win x64）
- **push 前敏感信息检查**（`precheck.sh --sensitive`）
- **不自动 push 远端**（除非用户明确确认）
- **绝不删除 backup/pre-squash 分支**
- commit 风格：`merge: <branch>`；`feat:`/`fix:`/`refactor:`/`chore:` 前缀

## 发布流程

1. 确认已合入 main + verify 干净 + sensitive 通过
2. **用户确认发布**
3. `npm run build:dmg:mac`（或 `:win`）
4. 校验产物存在（arm64.dmg + .zip / x64.exe + .zip + .msi）
5. 更新 RELEASE-NOTES.md
6. **不自动 push**（除非用户要求）

## 失败处理

| 失败点 | 原因 | 处理 |
|--------|------|------|
| inject 失败 | patch 与 upstream 不兼容（hermes-studio fatal） | 检查 patch 是否需更新；`npm run clean` 后重试 |
| openapi:generate 失败 | `routes/**` 扫描异常 | 检查新增路由格式 |
| vite build 失败 | 类型/导入错误 | 看 tsc 输出 |
| tsc --noEmit 失败 | 类型错误 | 修复类型 |
| electron-builder 失败 | prepare:runtime 未完成 / 签名问题 | 先跑 `prepare:runtime`；检查 electron-builder 配置 |
| prepare:runtime 失败 | 网络（fetch:node/python） | 重试；检查 PBS_TAG/PBS_PY |

## sync + rebuild

同步 upstream 后必须重建：

```bash
npm run sync              # bash scripts/sync-upstream.sh
npm run clean && npm run inject   # 重建注入态
npm run verify            # 校验
npm test                  # 回归
# 若发布：npm run build:dmg:mac
```

patch 可能需更新以适配 upstream 新版本——检查 `git apply` 是否报错。

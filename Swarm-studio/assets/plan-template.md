# 实施计划：<feature 名称>

> **For agentic workers:** 按 Task 逐个推进，每个 Task 完成即 commit。步骤用 checkbox (`- [ ]`) 跟踪。
> **执行方式：** subagent-driven 推荐（每 Task 派发 fresh subagent，见 references/subagent-orchestration.md）；inline 备选。

**Goal:** （一句话目标）

**Architecture:** （架构摘要：A类/B类改造、模块、依赖关系）

**Tech Stack:** Vue 3 ^3.5.32 + Pinia ^3.0.4 + vue-router ^4.6.4 + vue-i18n ^11.3.2 + Vite ^8.0.4 + TypeScript ~6.0.2 + naive-ui ^2.44.1 + Koa ^2.15.3 + embedded SQLite (node:sqlite) + Vitest ^3.2.4 + Electron ^42.3.0

**Spec:** `docs/superpowers/specs/YYYY-MM-DD-<feature>-design.md`（归档到 specs/，现有 29 files 规范）

**工作目录:** `cd /Volumes/nvme2230/lab/ncwk/overlay`

---

## 前置准备

**分支（遵循项目规范）：** 基于 main 建 feature 分支。

**起点核验：**
```bash
cd /Volumes/nvme2230/lab/ncwk/overlay
git branch --show-current          # 应为 main
git rev-parse HEAD
git rev-parse main                 # 应与 HEAD 相等
git status --porcelain             # 应为空或只有文档
```

**测试基线：** `npm test` = 37 files passed（34 cockpit + 2 chat + 1 server security）

**关键边界（来自 spec §非目标）：**
- （列出不做的事）

---

## 文件结构

| 文件 | 动作 | 类型 | 职责 |
|------|------|------|------|
| `custom/client/<feature>/<Name>.vue` | 新建 | A类 | 组件 |
| `custom/client/<feature>/stores/<name>.ts` | 新建 | A类 | Pinia store |
| `registries/client/bootstrap.ts` | 修改 | A类 | 动态 import + flag 守卫 |
| `patches/NNN-<tag>-<desc>.patch` | 新建 | B类 | upstream 修改（仅当必须） |
| `patches/series` | 修改 | B类 | 追加 patch 号 |
| `custom/server/src/...` | 新建 | A类 | Koa 后端（CJS） |

---

### Task 1: 建 feature 分支（含起点核验）

**Files:** 无文件改动

- [ ] **Step 1: 核验起点**
  ```bash
  cd /Volumes/nvme2230/lab/ncwk/overlay
  git branch --show-current
  git rev-parse HEAD && git rev-parse main
  git status --porcelain
  npm run verify            # 校验注入态干净
  ```
- [ ] **Step 2: 建分支**
  ```bash
  git checkout main
  git checkout -b feat/<feature-name>   # 或 fix/ refactor/ chore/
  ```
- [ ] **Step 3: 记录测试基线**
  ```bash
  npm test 2>&1 | tail -5   # 应为 37 files passed
  ```

---

### Task 2: <具体任务>

**Files:** `custom/client/<feature>/<Name>.vue`

- [ ] **Step 1: ...** （A类：新建组件 + store + types）
- [ ] **Step 2: ...** （注册：bootstrap.ts 动态 import + isFeatureEnabled 守卫 + registerRoute/registerNavEntry/registerComponent）
- [ ] **Step 3: 验证**
  ```bash
  npm run dev    # 手动验证（8649 前端 HMR + 8647 后端）
  npm test       # 37 files 不退化
  ```
- [ ] **Step 4: Commit**
  ```bash
  git add -A
  git commit -m "feat(<scope>): <描述>"
  ```

> **B类任务**（若涉及 patches）：先 `npm run verify` → 临时改 upstream → `git diff > patches/NNN-<tag>-<desc>.patch` → 追加 series → `npm run clean && npm run inject` → `npm test`。**dev server 运行期间禁止 git checkout upstream。**

---

### Task N: 合入 main（需用户确认）

- [ ] **Step 1: rebase main**
  ```bash
  git fetch origin
  git rebase origin/main
  npm test   # rebase 后重跑（37 files）
  ```
- [ ] **Step 2: 合并（需用户确认）**
  ```bash
  git checkout main
  git merge --no-ff feat/<feature-name> -m "merge: feat/<feature-name>"
  ```
- [ ] **Step 3: 不自动推送**（除非用户明确要求）

---

## 完成检查表

- [ ] 改动仅在 `overlay/`（custom 或 patches），`precheck.sh --scope` 通过
- [ ] A类已接入注册（registerRoute/registerNavEntry/registerComponent → bootstrap.ts + flag 守卫）；B类 patch 入 series 且 `npm run clean && npm run inject` 成功
- [ ] `npm test` 全绿（37 files），不退化于基线
- [ ] `precheck.sh --sensitive` 无敏感信息泄漏
- [ ] `precheck.sh --consistency` 业务规则 + 勾稽核对通过（无多漏错重 6 项）
- [ ] `precheck.sh --review` 审查通过（ocr 若装自动，否则手动 5 维度 + goal-backward）
- [ ] spec/plan 已归档到 `docs/superpowers/specs/` + `plans/`
- [ ] 已合入 main（`--no-ff`，`merge: <branch>`），未自动推送远端（除非用户明确要求）
- [ ] `backup/pre-squash` 未被删除

# 库表及数据结构、样例数据模版 (Data Schema & Sample Data Template)

> 对应材料 assets §6。SwarmStudio 使用 embedded SQLite（node:sqlite DatabaseSync），无外部 DB。

## 数据库引擎

- **引擎**：`node:sqlite` 的 `DatabaseSync`（Node 内置，需 Node>=22.5，本项目要求 >=23）
- **DB 文件**：`<DB_DIR>/hermes-web-ui.db`
- **DB_DIR**：
  - test → `packages/server/data/test-runtime`
  - dev → `packages/server/data`
  - prod → `~/.hermes-web-ui`（环境变量 `HERMES_WEB_UI_HOME`）
- **prod 配置**：WAL 模式 + `foreign_keys=ON`
- **Node<22.5 回退**：JSON 文件存储
- **schema 位置**：`packages/server/src/db/hermes/schemas.ts`（834 行）
- **无外部 DB / Redis / MQ / ELK**：全部 embedded

## 数据库表结构（26 张表）

| 表 | 说明 |
|----|------|
| sessions | 会话 |
| messages | 消息 |
| session_usage | 会话用量 |
| users | 用户（patch 001 扩展，见下） |
| user_profiles | 用户资料 |
| workflows | 工作流 |
| workflow_runs | 工作流运行 |
| workflow_run_node_sessions | 工作流运行节点会话 |
| chat_compression_snapshots | 聊天压缩快照 |
| model_context | 模型上下文 |
| devices | 设备 |
| stt_* (4) | 语音转文字（4 表） |
| tts_* (4) | 文字转语音（4 表） |
| gc_rooms | 群聊房间 |
| gc_messages | 群聊消息 |
| gc_room_agents | 群聊房间 agent |
| gc_context_snapshots | 群聊上下文快照 |
| gc_room_members | 群聊房间成员 |
| gc_pending_session_deletes | 待删除会话 |
| gc_session_profiles | 群聊会话资料 |

### 表：users（patch 001 扩展）

patch 001 为 users 表新增 5 列：

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| matrix_user_id | TEXT | UNIQUE（CREATE UNIQUE INDEX） | Matrix 用户 ID |
| matrix_display_name | TEXT | | Matrix 显示名 |
| matrix_avatar_url | TEXT | | Matrix 头像 URL |
| matrix_homeserver_url | TEXT | | Matrix homeserver |
| auth_source | TEXT | NOT NULL DEFAULT 'local' | 认证来源 |

> **SQLite ADD COLUMN UNIQUE 限制**：SQLite 不支持 `ADD COLUMN ... UNIQUE`。做法：先 strip `UNIQUE` 加列，再 `CREATE UNIQUE INDEX`（允许多个 NULL 值）。

**索引：**
- `idx_users_matrix_user_id` — matrix_user_id 唯一索引（多 NULL 允许）

**外键关系：**
- `user_profiles.user_id` → `users.id`

## 样例数据

> SwarmStudio **无内置 seed/fixture 数据**。测试 stub 在 `custom/client/test/setup.ts`（ResizeObserver/localStorage/matchMedia/i18n）。

无 seed/fixture。开发/测试数据由测试用例运行时生成。

## 数据流说明

### RunTrace 流（核心数据流）

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

### 通用数据流

```
API → adapter → store(Pinia) → component(Vue)
```

## 业务规则与数据约束

- **auth_source 默认 'local'** — 新用户未指定认证来源时为 local → 影响：users 表
- **foreign_keys=ON（prod）** — 外键约束强制 → 影响：所有外键关系
- **WAL 模式（prod）** — 并发读写 → 影响：DB 文件含 -wal/-shm
- **matrix_user_id UNIQUE（多 NULL 允许）** — 非 Matrix 用户可为 NULL → 影响：users 表
- **patch 路由前缀** — hermes_cli/plugins/agent/apps/assets/acp_ → hermes-agent（容错）；其余 → hermes-studio（fatal）→ 影响：inject 数据
- **inject 幂等** — ensure-injected 重复执行不产生副作用 → 影响：.overlay-injected.json manifest

## 勾稽关系（无多漏错重）

- [ ] **无遗漏**：关联记录无缺失（如 session→messages 无孤儿；workflow_runs→workflow_run_node_sessions）
- [ ] **无多余**：无冗余/重复记录（如 gc_room_members 不重复）
- [ ] **记录正确**：字段值符合业务规则（如 auth_source 默认 'local'）
- [ ] **勾稽正确**：外键/聚合/关联关系正确（foreign_keys=ON；user_profiles.user_id → users.id）
- [ ] **一致性**：同源数据多处一致（如 matrix_user_id 与 Matrix homeserver 状态一致）
- [ ] **幂等性**：重复请求不产生副作用（inject ensure-injected 幂等；API 写入幂等）

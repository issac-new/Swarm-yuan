# 参考手册

## §2 安全检查清单

| 检查项 | 规则 |
|--------|------|
| 密码 | 必须哈希（bcrypt/argon2），不可明文/MD5 |
| SQL | 必须参数化，不可字符串拼接 |
| XSS | 须输出编码，v-html/innerHTML 须 sanitize |
| CSRF | 须 Token 或 SameSite Cookie |
| 密钥 | 不入代码库，用环境变量 |
| 越权 | 须水平+垂直越权检查 |
| 输入验证 | 须在边界验证（schema/DTO） |

## §4 组件库清单

| 组件 | 路径 | 用途 |
|------|------|------|
| CockpitWorkspace | custom/client/cockpit/components/ | 主工作区 |
| CockpitKanban | custom/client/cockpit/components/ | 看板 |
| CockpitChatPane | custom/client/cockpit/components/ | 聊天面板 |
| CockpitFilePanel | custom/client/cockpit/components/ | 文件面板 |
| CockpitFileTree | custom/client/cockpit/components/ | 文件树 |
| CockpitGraphNode | custom/client/cockpit/components/ | 图节点 |
| CockpitHistoryModal | custom/client/cockpit/components/ | 历史弹窗 |
| GatewayNoticeBanner | custom/client/chat/components/ | 网关通知 |
| KanbanMarkdown | custom/client/kanban/components/ | 看板 Markdown |
| MatrixMessageBody | custom/client/matrix-chat/components/ | Matrix 消息体 |

## §5 组件依赖链路

```
registries/client/entry.mts（入口 shim）
  → bootstrap.ts（动态 import custom 模块）
    → cockpit/（CockpitWorkspace 主容器）
      → CockpitKanban / CockpitChatPane / CockpitFilePanel
    → chat/（GatewayNoticeBanner）
    → matrix-chat/（MatrixMessageBody / MatrixRoomSearchView）
    → kanban/（KanbanMarkdown）
    → branding/（品牌定制）
```

## §6 接口清单

| 接口 | 方法 | 路径 | 认证 |
|------|------|------|------|
| kanban API | GET/POST | /api/kanban/* | Session |
| matrix auth | POST | /api/auth/matrix | JWT |
| files API | GET | /api/hermes/files | Session |
| sessions API | GET | /api/hermes/sessions | Session |
| profiles API | GET | /api/hermes/profiles | Session |

## §8 数据字典

| 表 | 字段 | 说明 |
|----|------|------|
| sessions | id, name, created_at | 会话 |
| users | id, name, matrix_id | 用户 |
| kanban_tasks | id, title, status, assignee | 看板任务 |
| files | id, path, session_id | 文件 |

## 逻辑谬误图谱

| 类别 | 常见谬误 |
|------|---------|
| 形式与语言 | 肯定后件、偷换概念、套套逻辑 |
| 来源与人身 | 稻草人、红鲱鱼、诉诸权威 |
| 情感与归纳 | 诉诸恐惧、偏差样本、不当类比 |
| 因果与预设 | 相关不蕴涵因果、滑坡谬误、假两难 |

## 认知映射表

| 认知阶 | 落点 |
|--------|------|
| ①概念 | reference-manual §4/5/6 |
| ②结构 | dev-guide 改造分类 |
| ③空间 | codebase.md 目录树 |
| ④映射 | 术语↔代码↔目录 |
| ⑤规律 | dev-guide 拼装原则 |
| ⑥处理 | precheck + spec |

## 六维动力学基线

| 维度 | 基线值 |
|------|--------|
| 速度 | 单次变更 ~5 文件 |
| 聚散 | 1 个 overlay 仓库 |
| 趋势 | 依赖深度 ~6 |
| 强度 | 同步调用 ~3 处 |
| 能耗 | store ~200 行 |
| 累积量 | TODO ~10 处 |

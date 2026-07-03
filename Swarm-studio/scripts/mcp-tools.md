# MCP 工具 (MCP Tools)

## hermes-studio-mcp
入口 `upstream/hermes-studio/bin/hermes-studio-mcp.mjs`（stdio MCP）。工具集：api(openapi_get/request)、use(chat_run/sessions/models/workflows ~25)、lan/devices(peer/terminal/file ~15)。自动注入 3 托管 server。

## hermes-agent MCP
`hermes mcp serve`（conversations/messages/events/permissions）。

## 数据库
嵌入式 SQLite，无外部 DB。手动：`sqlite3 ~/.hermes-web-ui/hermes-web-ui.db "SELECT * FROM sessions LIMIT 5;"`

## 外部资源
无外部 DB/Redis/MQ/ELK。LLM API 密钥用户配置（OPENROUTER/GOOGLE/GLM 等）。

## 记忆（claude-mem 可选）
`npx claude-mem install` → SessionStart(compact) hook 注入历史。详见 references/memory-persistence.md。

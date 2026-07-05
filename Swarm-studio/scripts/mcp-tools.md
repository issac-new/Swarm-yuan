# MCP 工具接入

本项目无外部 MCP 资源。主要数据存储为 SQLite（node:sqlite），通过 Koa 后端 API 访问。

如需接入 MCP 工具（DB 查询/ELK/Redis），在 precheck.conf 的 MCP 相关配置中添加。

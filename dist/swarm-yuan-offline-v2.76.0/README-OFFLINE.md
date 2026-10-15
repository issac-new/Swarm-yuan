# swarm-yuan 离线安装包（Windows）

## 前置条件（目标机）
- **Git for Windows**（提供 bash 与 git；技能脚本与门禁均为 bash——仓库三平台铁律：Windows 走 Git Bash）
- AI 编码工具任一：Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi / ZCode
- 可选：node+npm、python+pip（仅当用 --with-npm/--with-pip 装 vendor 运行时，或经内部镜像源补装）

## 安装
1. 解压本包到任意目录（路径不含空格更稳）。
2. 双击 `install-offline.bat`（或在其目录开 Git Bash 跑 `bash install-offline.sh`）——自动检测已装 AI 工具并安装技能。
3. 指定目标：`install-offline.bat --claude`；连 vendor 运行时一起装：`install-offline.bat --all --with-npm --with-pip`。

## vendor 与镜像源说明
- `vendor/npm/*.tgz`、`vendor/pip/`：构建机预拉的本地产物包，安装免网络（npm i -g ./xxx.tgz；pip --no-index --find-links）。
- 包不在 vendor 时（拉包失败或 github 通道），目标机可用内部 npm/pip 镜像源自行补装；装不上不影响技能运行。

## 外部运行时的离线语义（诚实降级）
技能的深度运行时（代码图谱/记忆插件等）未安装时**不阻塞**：相关门禁与能力按「未装披露」降级运行。
核心能力（生成技能、门禁检查、spec-first 四层拦截、提交时 pre-commit）零外部依赖，离线完备。
GitHub 通道运行时空白清单见 scripts/offline-manifest.conf（channel=github 行）。

## 首次使用
对 AI 说：「为 /path/to/project 生成开发技能」。之后每个需求按 SKILL.md 九节点工作流协作。

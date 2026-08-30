# Swarm-yuan

> 让 AI 懂你的项目，再写代码——从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。

[![Release](https://img.shields.io/badge/release-v2.6.1-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6.1)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()
[![CI](https://github.com/issac-new/Swarm-yuan/actions/workflows/ci.yml/badge.svg)](https://github.com/issac-new/Swarm-yuan/actions/workflows/ci.yml)

**本仓库的完整文档只有一份：[`swarm-yuan/README.md`](swarm-yuan/README.md)**——按五层递进组织（理念 → 设计 → 架构 → 实现 → 使用 + 引用层收录设计规格/决策史/上游基线/使用手册全文），安装包 standalone 时亦随技能自包含。

快速上手：

```bash
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash swarm-yuan/install.sh   # macOS / Linux / Git Bash（Windows 先装 Git for Windows，或用 swarm-yuan/install.bat）
```

仓库布局：`swarm-yuan/` = 生成器与范式本体（技能/门禁/验证器）；`verifier/` = 独立验证器；`docs/research/` = 决策史引用的调研证据链；`swarm-yuan/research/` = 上游运行时调研克隆（本地缓存，不入 git）。

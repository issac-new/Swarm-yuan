# vendor-knowledge — 领域知识实体镜像（本地/内部远端分发，勿推公开仓）

> 本目录镜像依赖本机 hermes 运行时（非 npm/pip 可装）的领域知识实体，供迁移到其它机器后 swarm-yuan 引用可达。
> **分发约束**：`standards/` `books/` `fulltext/` 为第三方规范全文与版权材料（EMVCo/银联规范、《支付之门》、付费专栏），走 git LFS 管理；含版权材料，**不推公开仓 issac-new/Swarm-yuan**，迁移分发仅经内部远端或本地拷贝。`.gitattributes` 的 LFS 跟踪规则已入库（可安全 push 公开仓），实体内容仅在私有分支流转。

## 目录

| 路径 | 来源 | 体量 | 性质 |
|---|---|---|---|
| `pay-team/references/` | `~/.hermes/profiles/pay-orchestrator/references/` | 32M / 657 文件 | 支付领域知识库（pay-team 四人格深读材料） |
| `pay-team/references/standards/` | 同上 standards/ | 20M | 银联/EMV/PBOC/ISO 规范全文（**LFS，版权**） |
| `pay-team/references/books/` | 同上 books/ | 2.1M | 《支付之门》14 章 +《跨境支付及金融服务》7 章（**LFS，版权**） |
| `pay-team/references/fulltext/` | 同上 fulltext/ | 1.8M | 陈天宇宙支付专栏 50 篇（**LFS，版权**） |
| `pay-team/references/*.md/json`（顶层） | 同上 | ~150K | 自研索引/内核框架/known-conflicts 裁决（普通 git） |
| `_shared/` | `~/.hermes/profiles/_shared/`（裁剪） | 3 文件 | 四论四问/语言规范/输出契约（SOUL.md 实际引用项） |

## 引用方

- `references/industry-profile-payment.md` §7 —— 领域知识库锚点路由（已改为指向本目录的仓内相对路径）。

## 引用纪律

引用任何限额/阈值/费率/版本数据前，先查 `pay-team/references/standards/known-conflicts.md` 的冲突裁决。

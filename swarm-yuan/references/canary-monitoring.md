> **何时读我**：任务命中本文档主题时按需读取（路由表见 SKILL.md）。首行：# 发布后基线对比监控（canary，文档化）

# 发布后基线对比监控（canary，文档化）

> 此文档原为 `check_canary` 门禁（advisory 档），于 2026-07-27 决策 26.1 等价替换为
> `check_loop_oracle`（strict 档），以腾出门禁预算（决策 26 冻结 54 上限）。
> canary 监控能力以本文档 + `scripts/setup-loop.sh --verify` 形式保留——
> 用户可 `bash scripts/setup-loop.sh "发布后监控" --verify '<canary 验证命令>'`
> 启动 Oracle Gate 循环做发布后基线对比。

## 监控指标

| 指标 | 变量 | 说明 |
|------|------|------|
| 当前响应时间（ms）| `CANARY_LATENCY_MS` | 发布后实际响应延迟 |
| 当前错误率（0-1）| `CANARY_ERROR_RATE` | 发布后错误比例 |
| 变化阈值（%）| `CANARY_THRESHOLD` | 默认 50，超过则告警 |

## 基线文件

`.swarm-yuan/canary-baseline.jsonl`（每行一条 JSON）：

```json
{"ts":"2026-07-27T00:00:00Z","latency_ms":120,"error_rate":0.01}
{"ts":"2026-07-27T01:00:00Z","latency_ms":180,"error_rate":0.02}
```

## 对比逻辑

- 变化 = |当前 - 上次| / 上次 × 100%
- 变化 > 阈值 → 异常告警（warn）
- 连续 2 次异常 → 人工复核趋势（don't cry wolf）
- 首次运行 → 建立基线（pass）

## 与 Oracle Gate（E1）的关系

canary 监控现以 Oracle Gate 循环形式落地：

```bash
bash scripts/setup-loop.sh "发布后 canary 监控" \
 --verify 'test "$(jq -r .latency_ms .swarm-yuan/canary-baseline.jsonl | tail -1)" -lt 500' \
 --completion-promise 'CANARY_OK'
```

AI 输出 `<promise>CANARY_OK</promise>` 后，hook 独立跑 verify（canary 基线 latency<500ms），
拒绝则 loop 继续——比原 advisory 门禁的 warn 强制力更强。

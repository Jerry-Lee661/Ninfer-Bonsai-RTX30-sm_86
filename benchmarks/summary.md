# 数据一览（含测试口径）

## 测试口径（复现必读）

- 硬件：RTX 3080 Ti 12GB，功耗墙 400W，`clocks.sm` 1950 MHz 档。
- 条件：单请求、贪心（temperature 0）、无并发、GPU 空闲（利用率 < 10%）。
- 工件：Ternary-Bonsai-2-27B-NInfer-v3（2.125 bit/权重，含投机头与视觉塔）。
- 测量：服务端 `decode tok/s`（首 token 之后的平均生成速率）；每条数字为一次请求的读数，
  同档重复 2 到 3 次取一致值。

## serve 矩阵（2026-09-29）

| 配置 | 中文 256 token | 英文 512 token | 验收率（中 / 英） |
|---|---|---|---|
| nospec | ~74 | 73.8 | |
| MTP d2 | 103.8 | 163.5 | 38.3% / 72.6% |
| MTP d3 | | 175.8 | / 61.3% |
| MTP d5 | 97.6 | 198.8 | 20.1% / 58.3% |
| DFlash2 d5 | | 65.8 | / 71.0% |

## CLI 矩阵（同工件）

| 配置 | 中文 | 英文 | 代码 |
|---|---|---|---|
| nospec | 71.7 到 74.0 | 74.1 | 73.8 |
| DFlash2 d5 | 88.1 到 96.3 | 233.3 到 233.9 | 233.9 |

验收（token/轮）：中文 1.65 到 1.91；英文与代码 4.25 到 4.81。

## 解析器修复前后的判定指标

| 项 | 修复前 | 修复后 |
|---|---|---|
| `loading weights` | 6.70 GiB | 7.99 GiB（DFlash2）/ 7.12 GiB（MTP） |
| `counters.decode_rounds / committed_decode_tokens` | 1.00 | 1 / 4.85（d5 英文） |
| 请求日志投机统计 | 无 | `mixed speculation accepted 406/572 (71.0%)` |

## 第三方标尺（带来源）

| 来源 | 卡 | decode | 口径 |
|---|---|---|---|
| Ninfer+Kvmem 交付包 | RTX 4080 SUPER | 226.0 t/s | 贪心、ctx 16384、400 token、5.48 token/轮 |
| paicat1/Bonsai-27B-NInfer | RTX 5080 | DFlash2 K7 均值 225 / 峰值 355 | 其自述日常档 |
| iamwavecut/ninfer-all README | RTX 3090 | 202 t/s（单请求） | 同表另有 8 并发聚合 551 t/s |

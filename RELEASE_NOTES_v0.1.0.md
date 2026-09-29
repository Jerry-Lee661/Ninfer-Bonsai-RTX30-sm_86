# v0.1.0 首个可运行版本

## 这个版本解决什么

上游 ninfer-all 的参数解析器在部分修订中被改坏（解析链被包进 for 循环、`return` 留在循环内），
导致 serve **只解析命令行第一个旗标**：`--spec`、`--draft-tokens` 等 60 多个旗标被静默忽略，
投机完全失效。本版本修复该缺陷，并附上在 RTX 3080 Ti 上的完整实测。

## 内容

- `patches/serve_options.cpp`：修复后的参数解析器（drop-in）
- `patches/README.md`：缺陷机制、修复方式、三条验证方法
- `scripts/`：Windows 构建脚本（configure/build）与四个档位的起服脚本
- `docs/`：部署过程与踩坑记录、性能实测、已知问题
- `benchmarks/summary.md`：数据一览（含测试口径）
- `patches/ternary_t2v2.cuh`：可选，上游小 T 张量核向自有引擎线的移植件

## 实测摘要（RTX 3080 Ti 12GB，400W，单请求贪心）

| 配置 | 中文 256 token | 英文 512 token |
|---|---|---|
| 修复前（旗标失效，实为无投机） | ~74 t/s | 73.8 t/s |
| 修复后 MTP 2 drafts | **103.8 t/s** | 163.5 t/s |
| 修复后 MTP 5 drafts | 97.6 t/s | **198.8 t/s** |

## 已知问题

DFlash2 在 serve 路径的每轮开销异常偏高（命令行界面 233 t/s，serve 65.8 t/s），投机用 MTP
即可绕过；详见 `docs/03-已知问题.md`。

## 附件

- `ninfer-serve-sm86-v0.1.0.zip`（1369 MB）：预编译 ninfer-serve（sm_86）+ 运行库 + 起服脚本 + 校验和。
  SHA256 `3c7d4c8ef9cd6ecfd5fb5bd9e048c0bfa7871e7ef1ea6d2cd90a0c1c7c636878`
- 模型不在附件内（9.52 GB），地址与校验见 `docs/04-下载与校验.md`。

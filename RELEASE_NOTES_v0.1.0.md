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

- `ninfer-serve-sm86-v0.1.0.zip`（812 MB）：预编译 ninfer-serve（sm_86）+ 运行库 + 起服脚本 + 校验和。
  SHA256 `717612c2ff0789b224ce6617b17306d9c778164be598bfda0f18819c05803c87`
- 模型不在附件内（9.52 GB），地址与校验见 `docs/04-下载与校验.md`。

## 预编译包下载（分卷，公网链路较慢时更稳）

Release 附件是 6 个分卷（共 812 MB），下载后合并再校验：

```bat
copy /b ninfer-serve-sm86-v0.1.0.zip.000+ninfer-serve-sm86-v0.1.0.zip.001+ninfer-serve-sm86-v0.1.0.zip.002+ninfer-serve-sm86-v0.1.0.zip.003+ninfer-serve-sm86-v0.1.0.zip.004+ninfer-serve-sm86-v0.1.0.zip.005 ninfer-serve-sm86-v0.1.0.zip
certutil -hashfile ninfer-serve-sm86-v0.1.0.zip SHA256
```
（Linux/macOS：`cat ninfer-serve-sm86-v0.1.0.zip.0* > ninfer-serve-sm86-v0.1.0.zip`）

合并后大小 812 MB，SHA256 应为 `717612c2ff0789b224ce6617b17306d9c778164be598bfda0f18819c05803c87`。

单卷校验和：

```
6347665c5b6bfef49cc0f105ad29f5a48035391446f2b6e976f3207393d64bc1 *ninfer-serve-sm86-v0.1.0.zip.000
3af6b8feef5177c2c885dc6b7214f7659e57aabf334c35300f1b93c6b24631ad *ninfer-serve-sm86-v0.1.0.zip.001
ff0aa8e5e27c81bdf89332be849babdb22686d0574797ad76b7c6af7e0235f9b *ninfer-serve-sm86-v0.1.0.zip.002
4ba68532e71bab2cd20982918150b7956f2064fa5ed5f1e9f924d1847c05f3a2 *ninfer-serve-sm86-v0.1.0.zip.003
a0b75de88432a9516f621819cd3b69c9e44eff1b406ff048ace40a23c3e77cfb *ninfer-serve-sm86-v0.1.0.zip.004
c40204a1fcfd5748af8973d78e9e70ffe64af38622386b4f41273884c43a0a00 *ninfer-serve-sm86-v0.1.0.zip.005
```

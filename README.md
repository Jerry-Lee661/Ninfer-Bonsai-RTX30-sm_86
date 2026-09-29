# Ninfer-Bonsai-RTX30-sm_86

在 **RTX 30 系（sm_86）** 上跑 **Ternary-Bonsai-2-27B 三元量化模型**的部署工程：引擎来自
[iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all)（Apache-2.0），本仓提供
**一个关键修复**、**Windows 构建脚本**、**可直接双击的起服脚本**与**实测数据**。

本仓的起点与过程参考了 [paicat1/Bonsai-27B-NInfer](https://github.com/paicat1/Bonsai-27B-NInfer)
（RTX 5080 线）与 Ninfer+Kvmem 交付包的公开资料，具体致谢见 [ATTRIBUTION.md](ATTRIBUTION.md)。

## 实测（RTX 3080 Ti 12GB，400W，单请求，贪心）

| 配置 | 中文 256 token | 英文 512 token |
|---|---|---|
| 无投机 | ~74 t/s | 73.8 t/s |
| **MTP 2 drafts（推荐起步）** | **103.8 t/s** | 163.5 t/s |
| MTP 3 drafts | | 175.8 t/s |
| MTP 5 drafts（英文最优） | 97.6 t/s | **198.8 t/s** |
| DFlash2 5 drafts | | 65.8 t/s（见"已知问题"） |

同一模型在 RTX 4080 SUPER 上第三方实测 226 t/s（投机 5.48 token/轮），以上数字与之同量级。

## 关键修复（本仓存在的主要理由）

上游 `src/serve/serve_options.cpp` 的参数解析链在部分 fork/合并中被改坏：整条 123 分支的
解析链被包进 `for` 循环体内，且 `return options;` 留在循环里，导致 **serve 只解析第一个命令行
旗标**。表现是 `--spec`、`--draft-tokens` 等 60 多个旗标被静默忽略，投机完全失效，吞吐被压在
无投机水平（本次实测 74 对比修复后 103.8 到 198.8）。

修复文件在 [patches/serve_options.cpp](patches/serve_options.cpp)，说明见
[patches/README.md](patches/README.md)。**如果你的 ninfer-serve 加了 `--spec` 却看不到任何
投机统计，基本就是这个坑。**

## 下载

- **预编译包**：`ninfer-serve-sm86-v0.1.0.zip`（812 MB，免构建，见 Releases）
  SHA256 `717612c2ff0789b224ce6617b17306d9c778164be598bfda0f18819c05803c87`
- **模型工件**（ninfer 专用，9.52 GB）：
  镜像 `https://hf-mirror.com/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3/resolve/main/Ternary-Bonsai-2-27B-ninfer-v3.ninfer`
  SHA256 `cdc4810b0ff17c40d0f62cf214b6e0bcd08346e9eb05ca53371507037793c14a`
- 全部地址、校验方法与运行环境要求见 [docs/04-下载与校验.md](docs/04-下载与校验.md)。

## 快速开始

### 0. 准备

- Windows 10/11，NVIDIA 驱动 ≥ 550，CUDA Toolkit 12.8，Visual Studio 2022 Build Tools（C++ 工作负载）
- 显存：12 GB 可跑（权重 7.99 GiB，纯文本+投机头）
- 模型工件：`Ternary-Bonsai-2-27B-NInfer-v3`（9.52 GB，来自 WaveCut，见 [docs/01-部署过程.md](docs/01-部署过程.md) 的下载说明）

### 1. 取引擎源码并打补丁

```bat
git clone https://github.com/iamwavecut/ninfer-all
:: 用本仓 patches/serve_options.cpp 覆盖 src\serve\serve_options.cpp
copy /Y patches\serve_options.cpp  ninfer-all\src\serve\serve_options.cpp
```

### 2. 构建（约 30 到 60 分钟）

```bat
scripts\configure_serve.bat   :: 改脚本里的路径为你的 ninfer-all 目录
scripts\build_serve.bat
```

产物：`ninfer-all\build\apps\ninfer-serve.exe`

### 3. 起服

双击 `scripts\起服-MTP-英文档.bat`（按注释改两处路径：引擎与工件），然后在浏览器或客户端里
把 API 指向 `http://127.0.0.1:8299/v1`。

## 目录

| 路径 | 内容 |
|---|---|
| `patches/serve_options.cpp` | 修复后的解析器（drop-in） |
| `patches/README.md` | 缺陷机制、修复方式、验证方法 |
| `patches/ternary_t2v2.cuh` | 可选：上游 t2_v2 小 T 内核向自有三元引擎的移植件 |
| `scripts/` | 构建脚本与起服脚本 |
| `docs/01-部署过程.md` | 完整部署过程与踩坑记录 |
| `docs/02-性能实测.md` | 本机矩阵与第三方基线对照 |
| `docs/03-已知问题.md` | 已知问题与规避 |
| `benchmarks/summary.md` | 数据一览（含测试口径） |

## 许可

本仓文档与脚本：Apache-2.0（与上游一致）。引擎源码版权归上游作者，详见
[ATTRIBUTION.md](ATTRIBUTION.md)。模型权重版权归其发布方（Prism ML / WaveCut 等），本仓不
分发权重，仅提供获取路径。

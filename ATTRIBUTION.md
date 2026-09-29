# 上游引用与致谢

本仓是部署工程，不包含引擎源码。引擎与模型的版权归各自作者，引用如下。

## 引擎（Apache-2.0）

- [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all)：本仓使用的引擎主体，sm_86/89/120a。
  该仓自述：自 [Don-Chad/ninfer-3090](https://github.com/Don-Chad/ninfer-3090) 起步（后者源自
  Neroued 的 NInfer），并合入
  [TertiumOrganum1/ninfer-3090](https://github.com/TertiumOrganum1/ninfer-3090) 的补丁、
  [UDPSendToFailed/ninfer-4090](https://github.com/UDPSendToFailed/ninfer-4090) 的思路，以及
  [IMGillusion](https://github.com/IMGillusion/ninfer-disk-kv)、
  [Mirko Covizzi](https://github.com/MirkoCovizzi/ninfer-rtx5090-mobile)、
  Ian Ranson（[Wallawalla47](https://github.com/Wallawalla47/ninfer-custom)）、
  tmark00、David Oelfke（[gzenz/ninfer](https://github.com/gzenz/ninfer)）等人的工作。
- 上游源头：[Neroued/ninfer](https://github.com/Neroued/ninfer)。

## 模型与工件

- Prism ML：`Ternary-Bonsai-2-27B` 系列三元量化（PTQ1_0 / PQ2_0_G128 两种打包档位）。
- [WaveCut/Ternary-Bonsai-2-27B-NInfer-v3](https://huggingface.co/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3)：
  本仓使用的 v3 工件（含 DFlash2 drafter、MTP 头、proposal head、视觉塔）。权重版权归其发布方，
  本仓不分发权重。
- DFlash2 drafter 权重来源：ProCreations 的相关发布（工程内记为 pc-dflash2）。

## 部署方法与数据参考

- [paicat1/Bonsai-27B-NInfer](https://github.com/paicat1/Bonsai-27B-NInfer)：RTX 5080 线上的
  完整部署工程（启动器、档位、报告），本仓的组织方式参考了它。
- Ninfer+Kvmem 交付包：提供 4080 SUPER 同口径实测（226 t/s 等），本仓用作标尺。

## 引用的第三方数字

本仓 `docs/02-性能实测.md` 中的第三方数字均标注来源与口径。引用时请保留来源标注。

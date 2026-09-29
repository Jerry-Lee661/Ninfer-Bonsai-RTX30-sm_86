# Upstream credit

This repository is a deployment project and does not contain engine source code. Engine and model
rights belong to their respective authors.

## Engine (Apache-2.0)

- [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all): the engine used here, covering
  sm_86, sm_89 and sm_120a. Its own README credits
  [Don-Chad/ninfer-3090](https://github.com/Don-Chad/ninfer-3090) as the starting point (itself
  derived from Neroued's NInfer), patches from
  [TertiumOrganum1/ninfer-3090](https://github.com/TertiumOrganum1/ninfer-3090), ideas from
  [UDPSendToFailed/ninfer-4090](https://github.com/UDPSendToFailed/ninfer-4090) and its
  contributors, and work by [IMGillusion](https://github.com/IMGillusion/ninfer-disk-kv),
  [Mirko Covizzi](https://github.com/MirkoCovizzi/ninfer-rtx5090-mobile), Ian Ranson
  ([Wallawalla47](https://github.com/Wallawalla47/ninfer-custom)), tmark00 and David Oelfke
  ([gzenz/ninfer](https://github.com/gzenz/ninfer)).
- Upstream origin: [Neroued/ninfer](https://github.com/Neroued/ninfer).

## Models and artifacts

- Prism ML: the `Ternary-Bonsai-2-27B` ternary quantization family (PTQ1_0 and PQ2_0_G128 packing
  tiers).
- [WaveCut/Ternary-Bonsai-2-27B-NInfer-v3](https://huggingface.co/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3):
  the v3 artifact used here, including the DFlash2 drafter, MTP head, proposal head and vision
  tower. Weights belong to their publishers; this repository does not redistribute them.
- DFlash2 drafter weights: ProCreations releases (recorded as `pc-dflash2` in the artifact
  provenance).

## Deployment references

- [paicat1/Bonsai-27B-NInfer](https://github.com/paicat1/Bonsai-27B-NInfer): a full deployment
  project for the RTX 5080 line (launcher, tiers, reports). The organization of this repository
  follows its example.
- The Ninfer+Kvmem delivery package: source of the same-protocol RTX 4080 SUPER numbers used here
  as a yardstick.

## Quoted third-party numbers

Numbers from third parties in `docs/02-benchmarks.md` carry their source and protocol. Keep the
attribution when quoting them.

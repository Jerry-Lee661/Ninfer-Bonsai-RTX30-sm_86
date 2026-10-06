# Ninfer-Bonsai-RTX30-sm_86

Running **Ternary-Bonsai-2-27B** (2-bit ternary quantization) on **RTX 30 series (sm_86)** with the
[NInfer](https://github.com/Neroued/ninfer) engine line. This repository ships one **critical fix**,
Windows build scripts, ready-to-run launcher scripts, and measured numbers.

The engine comes from [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all)
(Apache-2.0). Credit and lineage are in [ATTRIBUTION.md](ATTRIBUTION.md).

## What is new in v0.2.0: the KVMem ring

The engine now integrates the **KVMem ring**: the device KV pool may be smaller than
`--max-context` because pages are retrieved from a pinned host pool on demand, ranked by a
query-conditioned content score. On a 12 GB card this puts long context in the same binary
as the speculative stack, and the DFlash2 tier now starts on 12 GB. First real sm_86
validation of that ring (the fusion authors had no sm_86 card on their build box).
Provenance: [NOTICE-fusion.md](NOTICE-fusion.md), release notes in
[RELEASE_NOTES_v0.2.0.md](RELEASE_NOTES_v0.2.0.md), upstream contribution plan in
[docs/upstream-contributions.md](docs/upstream-contributions.md).

| English prompts, greedy, idle RTX 3080 Ti | counting (1133 in / 400 out) | prose (46 in / 500 out) |
|---|---|---|
| MTP d4 | 231.6 t/s (91.3% accepted) | 158.6 t/s (52.9%) |
| DFlash2 d5 + lm-head-draft | 317.7 t/s (99.7%) | 205.7 t/s (52.3%) |

## What this repository is for

The flags `--spec`, `--draft-tokens` and 60 or so others are **silently ignored** by some builds of
`ninfer-serve`: the argument parsing chain sits inside the `for` loop and `return options;` never
leaves it, so only the first command line flag is ever parsed. Speculative decoding then never runs
and throughput stays at the no-spec level. This repository carries the fixed `serve_options.cpp`
plus the steps to verify it.

| | no-spec | MTP 2 drafts | MTP 5 drafts |
|---|---|---|---|
| Chinese, 256 tokens | about 74 t/s | **103.8 t/s** | 97.6 t/s |
| English, 512 tokens | 73.8 t/s | 163.5 t/s | **198.8 t/s** |

RTX 3080 Ti 12GB, 400W, single request, greedy sampling. The full matrix and third-party baselines
are in [docs/02-benchmarks.md](docs/02-benchmarks.md).

## Download

- **Prebuilt package**: attached to the
  [v0.2.0 release](https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86/releases/tag/v0.2.0)
  (KVMem build; 10 parts, 1.46 GiB total zip (sha256 b46c1050...)). Merge and verify as described in
  [docs/04-downloads.md](docs/04-downloads.md). The v0.1.0 release
  ([six parts, 812 MB](https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86/releases/tag/v0.1.0))
  stays available.
- **Model artifact** (what the engine loads, 9.52 GB):
  `https://hf-mirror.com/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3/resolve/main/Ternary-Bonsai-2-27B-ninfer-v3.ninfer`
  SHA256 `cdc4810b0ff17c40d0f62cf214b6e0bcd08346e9eb05ca53371507037793c14a`
- **Model artifact** (what the engine loads, 9.52 GB):
  `https://hf-mirror.com/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3/resolve/main/Ternary-Bonsai-2-27B-ninfer-v3.ninfer`
  SHA256 `cdc4810b0ff17c40d0f62cf214b6e0bcd08346e9eb05ca53371507037793c14a`

## Quick start

### 0. Requirements

- Windows 10 or 11, NVIDIA driver 550 or newer, CUDA Toolkit 12.8, Visual Studio 2022 Build Tools
  with the C++ workload
- 12 GB VRAM is enough for this artifact (weights 7.99 GiB including the speculative heads)
- The model artifact listed above

### 1. Get the engine sources and apply the fix

```bat
git clone https://github.com/iamwavecut/ninfer-all
copy /Y patches\serve_options.cpp ninfer-all\src\serve\serve_options.cpp
```

### 2. Build (30 to 60 minutes)

Edit the two paths at the top of `scripts\configure_serve.bat`, run it, then run
`scripts\build_serve.bat`. The binary lands at `ninfer-all\build\apps\ninfer-serve.exe`.

### 3. Serve

Use one of the launcher scripts under `scripts\` (edit the engine and model paths inside), then
point your client at `http://127.0.0.1:8299/v1`.

## Repository layout

| Path | Content |
|---|---|
| `patches/serve_options.cpp` | Fixed argument parser, drop-in replacement |
| `patches/README.md` | The defect, the fix, and three ways to verify it |
| `patches/ternary_t2v2.cuh` | Optional: upstream t2_v2 small-T kernels ported to the self-hosted ternary engine |
| `scripts/` | Build scripts and launcher scripts |
| `docs/01-deployment.md` | Deployment walkthrough and pitfalls |
| `docs/02-benchmarks.md` | Measured numbers with protocols and third-party baselines |
| `docs/03-known-issues.md` | Known issues and workarounds |
| `docs/04-downloads.md` | Download links, checksums, runtime prerequisites |
| `docs/05-launch-guide.md` | Fully tuned launch guide plus a llama-server flag mapping |
| `benchmarks/summary.md` | All numbers in one place |

## License

Documents and scripts in this repository: Apache-2.0, matching upstream. Engine source code
belongs to its upstream authors; see [ATTRIBUTION.md](ATTRIBUTION.md). Model weights belong to
their publishers. This repository does not redistribute weights, only download locations.

# Ninfer-Bonsai-RTX30-sm_86

Running **Ternary-Bonsai-2-27B** (2-bit ternary quantization) on **RTX 30 series (sm_86)** with the
[NInfer](https://github.com/Neroued/ninfer) engine line. This repository ships one **critical fix**,
Windows build scripts, ready-to-run launcher scripts, and measured numbers.

The engine comes from [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all)
(Apache-2.0). Credit and lineage are in [ATTRIBUTION.md](ATTRIBUTION.md).

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

- **Prebuilt package**: six parts attached to the
  [v0.1.0 release](https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86/releases/tag/v0.1.0),
  812 MB total. Merge and verify as described in [docs/04-downloads.md](docs/04-downloads.md).
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
| `benchmarks/summary.md` | All numbers in one place |

## License

Documents and scripts in this repository: Apache-2.0, matching upstream. Engine source code
belongs to its upstream authors; see [ATTRIBUTION.md](ATTRIBUTION.md). Model weights belong to
their publishers. This repository does not redistribute weights, only download locations.

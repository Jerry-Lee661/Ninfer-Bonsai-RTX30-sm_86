# v0.1.0, first runnable release

## What this release fixes

The NInfer argument parser in some builds of `serve_options.cpp` is damaged: the whole chain of
123 flag branches sits inside the `for` loop, and `return options;` never leaves it. The server
therefore parses **only the first command line flag**, silently ignoring `--spec`,
`--draft-tokens` and 60 or so others. Speculative decoding never runs and throughput stays at the
no-spec level. This release carries the fix and the measurements taken on an RTX 3080 Ti.

## Contents

- `patches/serve_options.cpp`: the fixed argument parser, a drop-in replacement
- `patches/README.md`: the defect, the fix, and three ways to verify it
- `scripts/`: Windows build scripts (configure and build) plus launcher scripts for four tiers
- `docs/`: deployment walkthrough, benchmark numbers, known issues, downloads and checksums
- `benchmarks/summary.md`: every number in one place, with protocols
- `patches/ternary_t2v2.cuh`: optional, upstream small-T tensor core kernels ported to the
  self-hosted ternary engine line

## Measured summary (RTX 3080 Ti 12GB, 400W, single request, greedy)

| Configuration | Chinese 256 tokens | English 512 tokens |
|---|---|---|
| Before the fix (flags ignored, effectively no-spec) | about 74 t/s | 73.8 t/s |
| After the fix, MTP 2 drafts | **103.8 t/s** | 163.5 t/s |
| After the fix, MTP 5 drafts | 97.6 t/s | **198.8 t/s** |

## Known issue

DFlash2 has an unusually high per-round cost under the server (about 233 t/s on the command line
against 65.8 t/s under the server). MTP avoids it; details in `docs/03-known-issues.md`.

## Archive revision (2026-09-30 00:0x)

- Fixed a second defect in the same file: the derived KV sizing overwrote an explicit
  `--kv-capacity`, so `--kv-capacity auto --kv-headroom-mib N` failed with
  `--kv-headroom-mib requires --kv-capacity auto`. The guard is restored in `patches/serve_options.cpp`.
- The archive now ships the complete DLL closure (`swresample-7.dll` was missing, a dependency of
  `avformat-63.dll`).
- Rebuild hint for packagers: the generated `device_profiles_builtin.cpp` exceeds MSVC's 16380 byte
  string literal limit, so the JSON is now emitted as adjacent raw string chunks by
  `src/runtime/CMakeLists.txt`.

## Attachments

Six parts forming a single 812 MB archive:

```
copy /b ninfer-serve-sm86-v0.1.0.zip.000+ninfer-serve-sm86-v0.1.0.zip.001+ninfer-serve-sm86-v0.1.0.zip.002+ninfer-serve-sm86-v0.1.0.zip.003+ninfer-serve-sm86-v0.1.0.zip.004+ninfer-serve-sm86-v0.1.0.zip.005 ninfer-serve-sm86-v0.1.0.zip
```

Merged archive SHA256:
`a905306cfe9ed9bef7e986fefcb531c875c12d1bed5447726ee79517491072e1`

The model is not attached (9.52 GB). Links and checksums are in `docs/04-downloads.md`.

Note: the launcher scripts bundled in the archive have Chinese file names and comments. The
command lines inside are plain flags and work regardless of locale.

## Why the package is larger than other NInfer distributions

We compared the package against Don-Chad/ninfer-3090 v0.6.1-rtx3090 for Windows (545 MB):

| Item | This package (ninfer-all merged line plus ternary port) | Don-Chad v0.6.1-rtx3090 |
|---|---|---|
| Main binary | ninfer-serve.exe 1228 MB | ninfer-serve.exe 184 MB |
| Embedded GPU code | **276 cubins, 14165 kernels**, about 1.2 GB of SASS (`.nv_fatbin`) | `.nv_fatbin` 63 MB plus `__nv_relfatbin` 114 MB |
| Ternary (t2) kernels | Present (`t2_small_t`, `t2_rowsplit`, `t2_g128_fp16`) | **None**, so it cannot run Bonsai ternary artifacts |
| DFlash2, ngram, disk KV | Present | Absent |
| ffmpeg runtime | Self-built 63 series with all codecs, 141 MB | Lean 62 series, 19 MB |

The size follows from the feature surface: running a ternary model requires the whole ternary
kernel family compiled in, plus everything the merged line carries (media and vision, MoE, all
quant families, DFlash2 and so on). The v0.6.1 line targets Qwen3.8 W8/INT8/nvfp4 artifacts, which
is a much smaller kernel set.

There is no padding to remove. The binary has no debug symbol table, only one architecture (sm_86
cubins throughout), and PTX makes up a negligible share (extracted SASS totals 1231 MB against a
1195 MB `.nv_fatbin`). If you only need text inference and not vision or video, you can rebuild
with `-DNINFER_DISABLE_MEDIA=ON` and save about 141 MB of runtime libraries.

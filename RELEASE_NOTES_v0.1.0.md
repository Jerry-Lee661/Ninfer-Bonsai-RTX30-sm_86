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
`c3cdb5687cf04a36053c6d0709969d7f81bc95297339eefe0499dd20d925ad93`

The model is not attached (9.52 GB). Links and checksums are in `docs/04-downloads.md`.

Note: the launcher scripts bundled in the archive have Chinese file names and comments. The
command lines inside are plain flags and work regardless of locale.

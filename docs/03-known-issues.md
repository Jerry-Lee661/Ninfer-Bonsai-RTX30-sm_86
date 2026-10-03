# Known issues and workarounds

## 1. DFlash2 round cost under the server (resolved 2026-10-03)

The original report on this page said the server reached 65.8 t/s with DFlash2 while the command
line reached 233 t/s, with round latency of about 73.7 ms against 18 to 20 ms. That reading does
not reproduce on the released binary and is withdrawn.

Re-measured on 2026-10-03 with the exact v0.1.0 release binary (md5 `cba4a0d2cfde`, verified
against the published asset) on an idle RTX 3080 Ti, `--spec dflash2 --lm-head-draft
--max-concurrency 1`:

| Corpus | drafts | decode | acceptance | round latency |
|---|---|---|---|---|
| English prose, 46 in / 500 out | 5 | **241.6 t/s** | 52.3% | about 15 ms |
| Counting, 1133 in / 400 out | 5 | **374.8 t/s** | 99.1% | about 14 ms |
| Counting, 1133 in / 400 out | 12 | **578.1 t/s** | 89.5% | about 12 ms |

Root cause of the wrong reading: the 09-29 measurements were taken while another inference server
was decoding on the same GPU, which inflated every round. Any throughput number captured on a busy
GPU is invalid; re-measure on an idle card before filing a performance issue.

Deeper drafts still behave as upstream documents: they pay off on predictable text (counting) and
cost on open-ended text. Section 2 (Chinese acceptance) is unaffected by this fix.

## 2. Speculation helps less on Chinese text

The DFlash2 and MTP heads are more effective on English and code. Measured acceptance is 20 to 38
percent on Chinese against 58 to 73 percent on English. Use `--draft-tokens 2` for Chinese to keep
the round cost low.

## 3. KV quantization combinations were not re-measured

Earlier readings for the `--kv-dtype rk4v4` plus `--gdn-state-fp16` combination (about 15 percent
below default) were taken while the parser defect was present, so they only describe a binary that
parses the first flag alone. Re-measure them after the fix. Context beyond roughly 8K still needs a
quantized KV type such as rk4v4 to control memory.

## 4. Memory and context

On a 12 GB card: weights are 7.99 GiB including the speculative heads, and the default 8K token KV
pool costs about 1 GiB at run time. Check free VRAM before raising `--max-context`, or quantize
the KV cache.

## 5. Upstream differences worth knowing

- The upstream README highlights table is single request greedy unless the row says otherwise. The
  eight-request rows are aggregate throughput.
- This repository targets the PQ2/t2 artifact lineage. Prism's PTQ1_0 artifact carries the same
  weight values (we verified element by element) but different packing and kernel paths, so do not
  mix their numbers.

## 6. Why the prebuilt package is larger than other NInfer distributions (812 MB against about 545 MB)

We compared the package contents against Don-Chad/ninfer-3090 v0.6.1-rtx3090 for Windows (545 MB):

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

## 7. Packaging note: the runtime DLL set is a transitive closure

The first build of the 0.1.0 archive shipped only the DLLs that `ninfer-serve.exe` imports
directly, which missed `swresample-7.dll` (a dependency of `avformat-63.dll`). The archive has
been rebuilt with the full closure, so just download the current files. If you assemble a package
yourself, walk the import tables of every DLL as well, not only the executable's. The closure that
matters is: `avcodec-63`, `avformat-63`, `avutil-61`, `swresample-7`, `swscale-10`, `libcurl`.
`avdevice-63` and `avfilter-12` are not needed.

## 8. Multi-GPU status (dual GPUs)

The engine's official multi-GPU design is **pipeline parallelism**: `--devices A,B` puts one
pipeline stage per listed device and `--stage-layers A,B` splits the layers between them (not
tensor parallelism).

On Windows this is gated in code: `src/runtime/engine/engine.cpp` (`initialize_device`) throws
`multi-GPU execution is supported on Linux only` for mixed device ids inside `#ifdef _WIN32`.
Repeating one device id (`--devices 0,0`) is allowed and exercises the whole stage path on a
single card; we verified this path on Windows with the Bonsai ternary artifact
(`--devices 0,0 --stage-layers 32,32`, 2 stages x 32 layers): startup, KV pool and a full
256-token Chinese completion all worked.

Path to real dual-GPU on Windows:

1. Remove or relax the `#ifdef _WIN32` gate in `engine.cpp` (one line).
2. Verify the multi-device path on Windows: cross-device activation transfer between stages
   (CUDA peer access or staged copies; WDDM scheduling may add latency), per-device allocators
   and KV pools, CUDA graph interaction with multiple devices.
3. Both cards must be sm_86 for the single build (no rebuild needed for two Ampere 30-series).

What dual-GPU buys: roughly doubled weight and KV capacity (context length is the real win;
a 131K-token KV pool at rk4v4 is about 2.1 GB per stage on split layers). Decode throughput
gains are limited: pipeline decode is bounded by the slowest stage plus the inter-stage
transfer, so for a 27B model that already fits one 12 GB card, expect little to no speedup.
Two independent serve instances (one per card) remain the throughput option.

## 9. Needle retrieval miss at the 32K pool edge (rk4v4, open)

In the prefill ladder above, the needle was answered correctly at 1.4K, 5.4K and 22.3K prompt
tokens but missed at 32,612 tokens (the model replied that the data was absent, while the needle
was the sentence right before the question). The prompt fit the 32,768-token pool
(`prompt_tokens 32,612`), so it is not truncation.

Suspects, unverified: rk4v4 quantized-KV quality at the far edge of the pool, or a quality cliff
of the hybrid (GDN plus full attention) stack near 32K. bf16 KV at 32K cannot be loaded on a
12 GB card (the pool alone would be about 4 GB, weights 8.6 GB), so the A/B has to wait for a
larger card or a narrower pool.

Practical mitigation: keep working context at or below about 22 to 24K tokens with rk4v4, or
switch to `rk8v4`/`int8` KV (better fidelity, double the bytes) when retrieval quality matters
more than capacity.

# Known issues and workarounds

## 1. DFlash2 has a very high per-round cost under the server (open)

Command line binary (`ninfer.exe`) with DFlash2 5 drafts reaches about 233 t/s on English text.
The same artifact under `ninfer-serve` reaches 65.8 t/s, while acceptance stays at 71 percent
(4.85 tokens per round).

Where it comes from: speculation does run under the server (the request log shows
`mixed speculation accepted`, and `/stats` reports `decode_rounds` over
`committed_decode_tokens` of 4.85). The problem is round latency: about 73.7 ms per round under
the server against about 18 to 20 ms on the command line. MTP does not show this behaviour (MTP
with 2 drafts already gives 103.8 t/s).

Workaround: deploy with MTP (`--spec mtp --draft-tokens 2` up to 5). It covers the target
throughput. Verify DFlash2 numbers on the command line first if you need that backend.

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

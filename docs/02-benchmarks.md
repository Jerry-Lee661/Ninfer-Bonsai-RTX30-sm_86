# Measured numbers and third-party baselines

## This machine (RTX 3080 Ti 12GB, 400W, single request, greedy, idle GPU)

Engine: ninfer-all with the parser fix from this repository. Artifact:
Ternary-Bonsai-2-27B-NInfer-v3. KV cache and state at defaults (bf16 KV).

| Configuration | Chinese, 256 tokens | English, 512 tokens | Acceptance |
|---|---|---|---|
| no speculation | about 74 t/s | 73.8 t/s | |
| MTP 2 drafts | **103.8** | 163.5 | 38.3% / 72.6% |
| MTP 3 drafts | | 175.8 | 61.3% |
| MTP 5 drafts | 97.6 | **198.8** | 20.1% / 58.3% |
| DFlash2 5 drafts | | 241.6 | 52.3% (re-measured 2026-10-03 on an idle GPU, see known issues #1) |

Same artifact through the command line binary (`ninfer.exe`):

| Configuration | Chinese | English | Code |
|---|---|---|---|
| no speculation | 71.7 to 74.0 | 74.1 | 73.8 |
| DFlash2 5 drafts | 88.1 to 96.3 | 233.3 to 233.9 | 233.9 |

## Third-party baselines (same model, used as a yardstick)

| Source | Card (bandwidth) | Decode | Notes |
|---|---|---|---|
| Ninfer+Kvmem delivery package, first-hand | RTX 4080 SUPER (736 GB/s) | 226.0 t/s | greedy, ctx 16384, 400 tokens, 5.48 tokens per round |
| paicat1/Bonsai-27B-NInfer, first-hand | RTX 5080 (960 GB/s) | DFlash2 K7 average 225, peak 355 | their engine adds an s8 prefill kernel and more |
| iamwavecut/ninfer-all README | RTX 3090 | 202 t/s (single request) | the same table also lists an eight-request aggregate of 551 t/s |

Read the protocols carefully:

- The `eight requests at once (MTP, 3 drafts), total` row upstream is **aggregate** throughput.
  On the 3090 that is 551 divided by 8, about 69 t/s per stream, and it is not comparable to a
  single-request number.
- Every number in this repository is single request.
- Numbers do not transfer across cards, and within one card they do not transfer across KV
  precision or context length. Quote them with the protocol attached.

## What this means

- After the parser fix, a 27B ternary model reaches 198.8 t/s on English text and 103.8 t/s on
  Chinese text on an RTX 3080 Ti, in the same range as the first-hand RTX 4080 SUPER measurement.
  The gap to that card was mostly software path, not bandwidth (912 against 736 GB/s).
- Speculative gains are far larger on English and code than on Chinese. That is the applicability
  domain of the speculative heads; pick the draft count per workload.

## Long-context prefill and multi-turn (measured 2026-10-01)

Server: ninfer-serve from this repository, artifact v3, `--max-context 32768 --kv-capacity 32768
--kv-dtype rk4v4 --fast-prefill-kernel`, MTP 3 drafts, single request, greedy.

### Prefill ladder (cold cache, needle-in-haystack prompts)

| Prompt | TTFT | Prefill rate | Needle found |
|---|---|---|---|
| 1,359 tokens | 0.83 s | 1.63k tok/s | yes |
| 5,384 tokens | 2.3 s | 2.33k tok/s | yes |
| 22,304 tokens | 10.4 s | 2.15k tok/s | yes |
| 32,612 tokens | 15.6 s | 2.09k tok/s | **no** (see known issues) |

Prefill holds 2.1 to 2.3k tok/s at long context and is not flat, so the long-prompt path is
properly adapted. For reference, the same-protocol RTX 4080 SUPER first-hand measurement is
2,230 tok/s prefill: this card matches it.

### Multi-turn (8-turn conversation, growing history)

Decode stays 100 to 124 t/s from the first to the eighth turn; per-turn total 0.5 to 1.7 s.
Prefix reuse engages from the third request and reaches 97 to 98 percent
(`cache 1,053 (98.2%, private endpoint)`), TTFT drops to about 78 ms, so history is not
re-prefilled per turn.

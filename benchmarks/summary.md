# All measured numbers with protocols

## Protocol (needed to reproduce)

- Hardware: RTX 3080 Ti 12GB, 400W power limit, `clocks.sm` around 1950 MHz.
- Conditions: single request, greedy sampling (temperature 0), no concurrency, idle GPU
  (utilization below 10 percent).
- Artifact: Ternary-Bonsai-2-27B-NInfer-v3 (2.125 bit per weight, speculative heads included).
- Measurement: server reported `decode tok/s` (average generation rate after the first token).
  Each cell is one request; repeated two or three times per configuration where the numbers are
  quoted as ranges.

## Server matrix (2026-09-29)

| Configuration | Chinese 256 tokens | English 512 tokens | Acceptance (zh / en) |
|---|---|---|---|
| no-spec | about 74 | 73.8 | |
| MTP 2 drafts | 103.8 | 163.5 | 38.3% / 72.6% |
| MTP 3 drafts | | 175.8 | / 61.3% |
| MTP 5 drafts | 97.6 | 198.8 | 20.1% / 58.3% |
| DFlash2 5 drafts | | 241.6 | / 52.3% |

The DFlash2 row was re-measured on 2026-10-03 with the same release binary (md5 `cba4a0d2cfde`)
on an idle GPU; the originally published 65.8 t/s was taken while another inference server was
decoding on the same card and is withdrawn (see known issues #1). Counting corpus with the same
setup: 374.8 t/s at 5 drafts (acceptance 99.1%), 578.1 t/s at 12 drafts (acceptance 89.5%).

## Command line matrix (same artifact)

| Configuration | Chinese | English | Code |
|---|---|---|---|
| no-spec | 71.7 to 74.0 | 74.1 | 73.8 |
| DFlash2 5 drafts | 88.1 to 96.3 | 233.3 to 233.9 | 233.9 |

Acceptance in tokens per round: 1.65 to 1.91 for Chinese, 4.25 to 4.81 for English and code.

## Indicators of the parser fix

| Item | Before fix | After fix |
|---|---|---|
| `loading weights` | 6.70 GiB | 7.99 GiB (DFlash2) / 7.12 GiB (MTP) |
| `counters.decode_rounds / committed_decode_tokens` | 1.00 | 1 / 4.85 (DFlash2 5 drafts, English) |
| Speculation statistics in the request log | absent | `mixed speculation accepted 406/572 (71.0%)` |

## Third-party yardsticks (with sources)

| Source | Card | Decode | Protocol |
|---|---|---|---|
| Ninfer+Kvmem delivery package | RTX 4080 SUPER | 226.0 t/s | greedy, ctx 16384, 400 tokens, 5.48 tokens per round |
| paicat1/Bonsai-27B-NInfer | RTX 5080 | DFlash2 K7 average 225, peak 355 | their stated daily configuration |
| iamwavecut/ninfer-all README | RTX 3090 | 202 t/s single request | the same table also lists 8-request aggregate 551 t/s |

# Launch guide: the equivalent of a fully tuned llama-server command

This page gives a `ninfer-serve` command line at the same level of detail as a tuned
`llama-server` invocation, plus a flag by flag mapping so you can port an existing setup.

## The command

```bat
ninfer-serve.exe D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer ^
  --port 8299 --host 127.0.0.1 --model-id bonsai2-27b ^
  --device 0 ^
  --max-context 32768 --kv-capacity auto --kv-headroom-mib 1024 ^
  --kv-dtype rk4v4 ^
  --fast-prefill-kernel --prefill-chunk 2048 ^
  --max-concurrency 1 ^
  --host-kv-mib 4096 --host-state-slots 8 --device-state-slots 2 ^
  --context-cache-policy default ^
  --spec mtp --draft-tokens 3 --lm-head-draft --adaptive-mtp ^
  --ngram-draft-tokens 15 --ngram-min-match 8 ^
  --default-thinking-budget 4096 --default-reasoning-effort low --preserve-thinking ^
  --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 ^
  --presence-penalty 0 --frequency-penalty 0 --seed 0 ^
  --log-level info
```

Notes on the choices above:

- `--kv-dtype rk4v4` is the 4-bit KV quantization, the closest analogue of llama.cpp's
  `--cache-type-k q4_0 --cache-type-v q4_0`. It costs about 15 percent of decode speed at short
  context on a 12 GB card (we measure 87 t/s with bf16 KV against 74 t/s with rk4v4 at 8K
  context), so use it when you need the context, and leave the default (`bf16`) when you do not.
- `--spec mtp --draft-tokens 3` mirrors `--spec-type ngram-map-k4v,draft-mtp --spec-draft-n-max 3`.
  Tuned values: 2 drafts for Chinese, 5 for English and code. `--adaptive-mtp` lets each round
  choose between 3 and the maximum, which is what the llama.cpp combination approximates.
- ninfer enables copy style ngram drafting by default (width 15) whenever `--spec` is set,
  matching `ngram-map-k4v`; `--ngram-draft-tokens 0` turns it off, `--lookup-ngram N` adds the
  context lookup variant.
- `--temperature 0.6 --top-p 0.95 --top-k 20` are the same numbers llama.cpp users pass. Delete
  them and add `--greedy` when you want deterministic argmax decoding; all our published numbers
  are greedy.

## llama-server to ninfer-serve mapping

| llama-server | ninfer-serve | Notes |
|---|---|---|
| `-m model.gguf` | positional argument `model.ninfer` | ninfer reads `.ninfer` containers only, not GGUF |
| `--host`, `--port` | `--host`, `--port` | flag order does not matter on this build; it did on unpatched builds, see `patches/README.md` |
| `-ngl 99` | `--device 0` | weights are always fully resident on one GPU; there is no layer offload |
| `-c 131072` | `--max-context 131072` | plus `--kv-capacity` to size the pool |
| `-np 1` | `--max-concurrency 1` | default is already 1 |
| `--cache-type-k q4_0 --cache-type-v q4_0` | `--kv-dtype rk4v4` | other options: `int8`, `fp8`, `k8v4`, `rk8v4`, `rk4v4-e8`, `rk2v4-e8`, `nvfp4` |
| `--flash-attn on` | nothing to pass | attention kernels are fixed per card; add `--fast-prefill-kernel` for an int8 or rk* KV cache |
| `-b 2048 -ub 512` | `--prefill-chunk 2048` | must be a multiple of 128; default 1024 |
| `--no-kv-unified` | (no equivalent) | ninfer keeps one shared pool plus a checkpoint catalog; see the cache flags below |
| `--ctx-checkpoints 2` | `--device-state-slots 2` | device side checkpoint states kept beyond the active lane |
| `--cache-ram 4096` | `--host-cache-mib 4096` | pinned host RAM ceiling for checkpoints plus host KV |
| `--spec-type ngram-map-k4v,draft-mtp` | `--spec mtp --lm-head-draft --ngram-draft-tokens 15` | MTP head drafting plus copy style ngram drafting |
| `--spec-draft-n-max 3` | `--draft-tokens 3` | range 1 to 15, see the tuned values above |
| `--reasoning on` | (default) | the artifact's chat template decides; `--no-thinking` disables it |
| `--reasoning-format deepseek` | nothing to pass | the OpenAI compatible API returns reasoning in a separate field, so clients read that field instead of parsing text |
| `--reasoning-budget 4096` | `--default-thinking-budget 4096` | cap on model-origin thinking tokens |
| `--reasoning-effort low` | `--default-reasoning-effort low` | accepted values: none, minimal, low, medium, high, xhigh, max |
| `--temp 0.6`, `--top-p 0.95`, `--top-k 20` | same names and units | `--top-k` range is 0 to 20 |
| `--repeat-penalty 1.0 --repeat-last-n 256` | nothing to pass | 1.0 means no penalty; use `--presence-penalty` or `--frequency-penalty` for actual penalties |
| `-lv 3` | `--log-level info` | levels: trace, debug, info, warning, error, critical, off |

## Sizing context on a 12 GB card

Measured on a 12 GB card with this artifact (weights 7.28 GiB with MTP and the proposal head):

| KV pool | Type | Runtime | Notes |
|---|---|---|---|
| 8,192 tokens | bf16 | 997 MiB | default, fastest per token |
| 32,768 tokens | rk4v4 | 1.98 GiB | measured, `free 1.87 GiB` after load |

That works out to roughly 122 KB per token at bf16 and 63 KB per token at rk4v4, which is about
twice the raw attention KV (16 full-attention layers, 4 key/value heads, head dimension 256), so
the pool also carries the draft head and the state overheads. Extrapolating:

| Context | rk4v4 pool | Total with weights and runtime |
|---|---|---|
| 32,768 | 2.0 GiB | about 10 GiB, fits |
| 65,536 | 3.9 GiB | about 11.9 GiB, at the edge |
| 131,072 | 7.9 GiB | about 15.9 GiB, does not fit on 12 GB |

Two rules follow:

1. **`--kv-capacity` must be at least `--max-context`** (`--kv-capacity must be at least
   --max-context`). The device pool holds the active window, so a smaller pool caps the usable
   context rather than spilling an active request to the host.
2. On 12 GB, 32K at rk4v4 is the comfortable point. If you need more, lower the KV width further
   (`--kv-dtype rk2v4-e8`, 2 bits) or use a larger card. `--kv-capacity auto` sizes the pool from
   free memory, which avoids an out-of-memory failure but does not make a longer context fit.
3. Verified: with `--kv-headroom-mib 512` the 65,536-token configuration starts and serves
   (`KV 65,536 tokens, rk4v4, auto | runtime 2.56 GiB | free 694.6 MiB`). At the default 1 GiB
   headroom the same configuration fails the startup reservation check, so lower the headroom
   when you raise the context.

`--host-kv-mib` sizes the pinned host tier, which holds checkpointed and evicted KV between turns;
it is not a spill path for the active window.

## Verify that the flags are live

1. The `loading weights` line: 7.12 GiB for MTP, 7.99 GiB for DFlash2, 6.70 GiB without
   speculation.
2. After one request, `GET http://127.0.0.1:8299/stats` and read
   `counters.decode_rounds` against `counters.committed_decode_tokens`. A ratio of 1.0 means one
   token per round and no speculation; we measure about 4.85 with DFlash2 5 drafts on English.
3. The request log line `mixed speculation accepted 406/572 (71.0%)` appears once speculation is
   running.

## PowerShell variant

PowerShell does not use `^` for line continuation, and it will not run an executable from the
current directory unless you prefix it with `.\`. Single line form (paste as is):

```powershell
.
infer-serve.exe D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer --port 8299 --host 127.0.0.1 --model-id bonsai2-27b --device 0 --max-context 32768 --kv-capacity 32768 --kv-dtype rk4v4 --fast-prefill-kernel --prefill-chunk 2048 --max-concurrency 1 --host-kv-mib 4096 --host-state-slots 8 --device-state-slots 2 --spec mtp --draft-tokens 3 --lm-head-draft --adaptive-mtp --ngram-draft-tokens 15 --ngram-min-match 8 --default-thinking-budget 4096 --default-reasoning-effort low --preserve-thinking --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 --log-level info
```

Multi line form uses a backtick as the last character of each continued line:

```powershell
.
infer-serve.exe D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer `
  --port 8299 --host 127.0.0.1 --model-id bonsai2-27b `
  --device 0 `
  --max-context 32768 --kv-capacity 32768 `
  --kv-dtype rk4v4 `
  --fast-prefill-kernel --prefill-chunk 2048 `
  --max-concurrency 1 `
  --host-kv-mib 4096 --host-state-slots 8 --device-state-slots 2 `
  --spec mtp --draft-tokens 3 --lm-head-draft --adaptive-mtp `
  --ngram-draft-tokens 15 --ngram-min-match 8 `
  --default-thinking-budget 4096 --default-reasoning-effort low --preserve-thinking `
  --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 `
  --log-level info
```

In `cmd.exe` use `^` as the last character instead, and no `.\` prefix is needed.

### Note on --kv-capacity

Builds made from the damaged `serve_options.cpp` (including the first 0.1.0 archive) drop the
`kv_capacity_explicit` guard, so an explicit `--kv-capacity` is overwritten by the derived default
and `--kv-headroom-mib` then fails with `--kv-headroom-mib requires --kv-capacity auto`. On such a
build, pass a number instead of `auto` and omit `--kv-headroom-mib` (equivalently, size the pool
yourself). The fixed parser in `patches/` restores the guard.

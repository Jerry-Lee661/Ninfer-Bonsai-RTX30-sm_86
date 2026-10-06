# Release notes v0.2.0 -- KVMem ring build

## What is new

The **KVMem ring** is integrated into the engine: the device KV pool may be smaller than
`--max-context` because pages are retrieved from a pinned host pool on demand, ranked by a
query-conditioned content score. On a 12 GB card this puts long context (32K and beyond with
a 2,048-token device pool) in the same binary as the speculative stack, and the DFlash2 tier
now starts on 12 GB where it previously could not reserve its fixed budget.

This is also the **first real sm_86 validation** of that ring: the fusion authors shipped
sm_86 binaries without ever running one (their build box has no sm_86 card); we ran it on a
RTX 3080 Ti, verified the retrieval behaviour over the pool limit, and fixed a build failure
the CUDA 13.3 toolchain does not hit.

Provenance and license inventory: [NOTICE-fusion.md](NOTICE-fusion.md) (Apache-2.0
throughout: tancau/ninfer-kvmem-ring, kvmem-qw3 by Di Chai, the ninfer-fusion-kvmem
integration, this tree's fixes).

## Measured (RTX 3080 Ti 12 GB, idle GPU, greedy, English prompts, v3 artifact)

| tier | counting (1133 in / 400 out) | prose (46 in / 500 out) |
|---|---|---|
| MTP d4 | 231.6 t/s (91.3% accepted) | 158.6 t/s (52.9%) |
| DFlash2 d5 + lm-head-draft | 317.7 t/s (99.7%) | 205.7 t/s (52.3%) |

Ring behaviour: 4,104-token prompt over a 2,048-token pool answered a mid-prompt needle
correctly; control requests without the document refuse; per-request `cache 0.0%` shows no
cross-request leakage. dflash2 acceptance counts are byte-identical to the pre-integration
tree, so the resident-pool path is numerically unchanged.

## Package changes versus v0.1.0

- `ninfer-serve.exe` grows from 1228 MB to 1431 MB (KVMem module + upstream unified
  templates).
- New DLL requirements: **cublas64_12.dll, cublasLt64_12.dll (660 MB), cudart64_12.dll**
  alongside the previous six. The closure is walk-tested (every DLL's imports checked, not
  only the exe's). CUDA Toolkit 12.8 runtime DLLs are redistributable per the NVIDIA EULA.
- New launchers: `start-kvmem-mtp.bat` (port 8097) and `start-kvmem-dflash2.bat` (port 8098),
  both with the five `NINFER_*` ring variables and a 12 GB-sized pool/host budget.
- The v0.1.0 parser fix and all v0.1.0 documentation corrections remain in.

## Known limits of the ring (carried from the fusion ledger, disclosed up front)

- Retrieval visibility is approximate at small pools: one mid-prompt secret in a needle
  paragraph was retrieved while a companion code in the same paragraph was not echoed
  (page-seam truncation class, upstream-known).
- Fused rmsnorm+rope prefill chunks cannot expose pre-RoPE keys, so those chunks stay out of
  the retrieval index (logged at startup).
- The host KV pool is pinned RAM mapped into the GPU address space on Windows; it competes
  with VRAM. Keep `--host-kv-mib` small on 12 GB cards (the launchers ship 2048).
- FP8 KV dtype is not available on sm_86 (hardware); the launchers use `k8v4`.

## Verification checklist for the packager

Start from the package directory (not from a build tree), watch for:

```
[ring] content scoring ON by default (the ring is configured): ...
2026-10-06  INFO  engine ready | total ~4s | weights 7.12 GiB
2026-10-06  INFO  capacity | KV 2,048 tokens, k8v4, explicit | pages 32/512 | runtime 1.33 GiB
kvmem_score: ARMED capacity_blocks=512 layers_total=16 heads=4 head_dim=256
```

then per request `kvmem_score: SELECT ... oracle_ok=1`.

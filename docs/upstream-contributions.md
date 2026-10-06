# Upstream contribution plan for iamwavecut/ninfer-all

> Prepared 2026-10-06. Nothing submitted yet: this page drafts what we can open,
> in the shape the upstream PR_POLICY asks for (small, focused, evidence-backed,
> experimental features opt-in and default-off, Draft PRs for large work).

## 0. Status of our local fixes against upstream HEAD (checked 2026-10-06)

| Fix we carry | Upstream HEAD | Action |
|---|---|---|
| `std::countr_zero` in sparse_moe prefill (MSVC has no `__builtin_ctz`) | already fixed (`std::countr_zero` at line 1407) | none |
| kv-capacity-explicit guard in serve_options | present (3 hits) | none |
| C2326 captured-kernel launch in unified sliced-K launchers | fixed differently: `[&, kernel]` explicit value capture at line 111 | none; our direct-naming variant is an equivalent alternative |
| upgrade_ninfer_v2_to_v3.py count gate + PQ2 support | **still open** (KNOWN_COUNTS has only 1124/1190/940/1307; FORMATS lacks `PQ2_0_G128`) | issue + small PR (see 2) |

## 1. Issue (flagship): KVMem ring integration proposal + Draft PR offer

Content:

- What: family-A KVMem ring (content-scored retrieval, pinned-host KV pool,
  lazy materialization, startup guard) making "device pool < --max-context" a
  legal configuration. Already gated behind `NINFER_KV_WINDOW` and friends,
  i.e. opt-in and default-off, which matches the PR policy for risky memory
  behaviour.
- Provenance: Apache-2.0 chain only. Ring mechanism ported from
  tancau/ninfer-kvmem-ring; policy-layer semantics from kvmem-qw3 (Di Chai);
  integration work by the ninfer-fusion-kvmem authors (1314521gjy); our tree
  adds the first real sm_86 validation and a build fix. Full inventory in our
  NOTICE-fusion.md.
- Independent evidence (RTX 3080 Ti 12 GB, idle GPU, greedy, PQ2 v3 artifact):
  - ring evidence lines fire (`content scoring ON`, `kvmem_score: ARMED`,
    `kvmem_score: SELECT ... oracle_ok=1`);
  - 4,104-token prompt against a 2,048-token device pool (2x over pool)
    answered a mid-prompt needle's secret correctly; a control request without
    the document refuses, and per-request `cache 0.0%` shows no leakage;
  - dflash2 tier: byte-identical acceptance counts before/after integration
    (366/700 prose, 332/335 counting) and this tier now starts on 12 GB
    (the fusion authors' own sm_86 binary cannot reserve it there);
  - counting corpus, mtp d4: 231.6-263.5 t/s on sm_86 depending on window.
- Known limitations to disclose up front (from the fusion ledger): approximate
  visibility at small pools (page-seam truncation class), fused rmsnorm+rope
  prefill chunks not indexed for pre-RoPE keys, fp8 KV mask path only.
- Offer: as a Draft PR series per the policy (core primitive: kvmem module +
  paged_kv_cache/context wiring; feature: transactions/planning; cleanup), or
  as guidance if upstream prefers to wait for the fusion implementation to
  settle (PR_POLICY "Upstream work" clause).

## 2. Issue + small PR: upgrade tool rejects the PQ2 G128 artifact family

- Repro: `python tools/upgrade_ninfer_v2_to_v3.py bonsai2_27b_pq2.ninfer out.ninfer`
  raises `unsupported v2 input ('qwen3.8-27b', 'groupwise-int') with 1126 objects`;
  with the count gate widened it then raises `KeyError: 'PQ2_0_G128'`.
- Root causes: (a) KNOWN_COUNTS lacks the 1126-object repack; (b) FORMATS lacks
  `PQ2_0_G128 -> t2_g128_fp16`; (c) object names use fused GDN projections
  (`gdn/query_key`, `gdn/value_z`), so the binding layer needs row-range split
  shims. Geometry verified against real tensors:
  `bytes = align(n * groups * 32, 256) + n * groups * 2`, groups = align(k,128)/128.
- Offer: (a) is a one-line PR; (b) a small PR; (c) needs design review on where
  the split belongs. We hold a verified 1126-object artifact locally for testing.

## 3. Issue: RTX 3080 Ti 12 GB / Windows deployment findings

Knowledge share (no code), matching what the maintainer asks people to report:

- Pinned host KV (`--host-kv-mib`) is mapped into the GPU address space on
  Windows and competes with VRAM; on a 12 GB card with desktop apps alive the
  practical budget is ~2 GiB, and large defaults fail with
  `cudaErrorAlreadyMapped` at startup.
- The dflash2 tier (lm-head-draft + vision) carries roughly 2.0-2.3 GiB of
  fixed startup reservation on sm_86; the mtp tier starts in ~1.3 GiB. On
  12 GB, pool 2048 + host 2048 + ctx 32K fits mtp with room to spare.
- Measurement discipline data point: the same binary on the same card measured
  65.8 t/s per-round under GPU contention versus 241.6-317.7 t/s idle; we
  withdrew our own published 65.8 number for this reason.
- Device profile `nvidia-geforce-rtx-3080-ti-sm86` (40 routed keys) validated
  on the real card; CUDA graphs under desktop pressure can print a benign
  `CUDA graphs used ... but the KV sizing allowed ...` warning.

## 4. Not upstreamed

- Our 12 GB launcher profiles and packaging (repository-specific).
- The t2v2/sched3 kernel experiments from the 4090w-lineage work tree: the
  upstream unified stack measures faster on every axis on this card, so there
  is nothing to contribute there.

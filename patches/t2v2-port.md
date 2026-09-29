# Optional: upstream t2_v2 small-T kernels ported to the self-hosted ternary engine

`ternary_t2v2.cuh` in this directory ports `src/ops/linear/t2/t2_small_t_v2.cuh` from ninfer-all
(the small-T tensor core kernel) to the self-hosted ternary86 engine (PTQ1/PQ2 row-split line),
for decode and verification at T = 2 to 8.

What changed compared to upstream (everything else is copied verbatim):

1. **LUT tables follow this line's code convention.** Upstream t2 codes are two's complement
   style (field 1 means +1, field 3 means -1); this line's PQ2 codes are biased, `c = w + 1`. The
   tables were derived with a numpy emulation of `__byte_perm` and verified:
   `kLutLow = 0x00800080`, `kLutHigh = 0x003F00BF`.
2. Storage constants use this line's `PQ2RowSplitStorage` (same values as upstream: group 128,
   32 B codes, 2 B scale).
3. The dispatch adds a shape guard: `tokens <= 8 && rows % 16 == 0 && k % 512 == 0`, otherwise it
   falls back to the previous geometry.

Verification (this line, PQ2 artifact):

- Smoke output identical word for word; the easy workload bit-identical; hard and chat differ only
  through a different K reduction order, so the drift is benign.
- Perplexity at the 512/256 protocol: **bit-identical** between both paths
  (1.125169058908091).
- Chinese workloads move from 82.0, 82.6 and 72.8 t/s to 126.2, 127.7 and 106.2 t/s (+46 to +55
  percent).
- English and code move from 81.6 and 81.5 t/s to 126.8 and 127.5 t/s. MTP with 3 and 5 drafts
  benefits the same way.

Upstream design points worth noting: activations are read straight from global memory through L1
(no shared tile, no ldmatrix), the A fragment comes from a two-register PRMT table, eight warps
split K by KWarps, and codes plus scales are prefetched with cp.async in a stage ring.

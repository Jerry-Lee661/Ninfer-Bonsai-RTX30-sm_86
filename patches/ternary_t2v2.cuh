#pragma once

// Port of iamwavecut/ninfer-all's t2_small_t_v2 (src/ops/linear/t2/t2_small_t_v2.cuh, read
// 2026-09-29) into the ternary86 tree's PQ2_0_G128 path. This is the "four eliminations"
// design the user selected as the kernel goal:
//   * no x smem tile and no ldmatrix: activations are read straight from global through L1
//     (load_ldg<uint4>), where the CTAs resident on one SM share them -- per-CTA staging
//     fetches them from L2 once per CTA, which at T=8 moves more bytes than the codes do;
//   * no decode chain and no smem LUT: the A fragment is one AND + one SHF per code word and
//     two __byte_perm table lookups (a two-register {0,+1,-1} byte table);
//   * eight warps per CTA, KWarps of them splitting every K slab (64 k per warp), the CTA
//     covering (8/KWarps)*TilesPerWarp sixteen-row tiles over the same K -- 128 rows per CTA
//     at KWarps=8,TilesPerWarp=1, with MinBlocks pinning occupancy through launch bounds;
//   * only codes and scales go through shared, a stage ring Stages deep.
//
// WHAT CHANGED IN THE PORT (everything else is verbatim upstream):
//   * LUT tables: upstream decodes the t2 code convention (field 1 -> +1, 3 -> -1, 0/2 -> 0);
//     this tree's PQ2_0_G128 codes are c = w + 1 (0 -> -1, 2 -> +1, 3 unused). The tables
//     below were derived and verified against a numpy __byte_perm emulation
//     (selector nibble = code value; first = pair(nibble0, nibble1), second = pair(nibble2,
//     nibble3)); see bench86/REPORT.md round 55.
//   * storage constants come from PQ2RowSplitStorage (identical values: group 128, 32 B codes,
//     2 B scale per group).
//   * namespace/includes/launch wiring are this tree's.
//
// Requires rows % kRows == 0, k % kSlabK == 0, cols <= kColumns (checked by the launcher).

#include "ops/common/memory.cuh"
#include "ops/common/mma.cuh"
#include "ops/linear/ternary/ternary_rowsplit_storage.cuh"

#include <cuda_bf16.h>
#include <cuda_fp16.h>
#include <cuda_runtime.h>

#include <cstdint>

namespace ninfer::ops::detail {

template <int KWarps_, int TilesPerWarp_, int ColumnTiles_, int Stages_, int MinBlocks_>
struct TernaryT2v2Schedule {
    static constexpr int kWarps               = 8;
    static constexpr int kThreads             = kWarps * 32;
    static constexpr int kKWarps              = KWarps_;
    static constexpr int kTilesPerWarp        = TilesPerWarp_;
    static constexpr int kRowTiles            = kWarps / kKWarps * kTilesPerWarp;
    static constexpr int kRows                = 16 * kRowTiles;
    static constexpr int kColumnTiles         = ColumnTiles_;
    static constexpr int kColumns             = 8 * kColumnTiles;
    static constexpr int kSlabK               = 64 * kKWarps;
    static constexpr int kGroupsPerSlab       = kSlabK / PQ2RowSplitStorage::kGroupK;
    static constexpr int kCodeBytesPerRowSlab = kSlabK / 4;
    // A 16-byte pad staggers the rows' code words across the banks for the k_split x lid reads.
    static constexpr int kCodeRowStride = kCodeBytesPerRowSlab + 16;
    static constexpr int kScaleBytesPerRowSlab =
        kGroupsPerSlab * PQ2RowSplitStorage::kScaleBytesPerGroup;
    static constexpr int kStages    = Stages_;
    static constexpr int kMinBlocks = MinBlocks_;

    static_assert(kKWarps == 4 || kKWarps == 8, "splits K over four or eight warps");
    static_assert(kTilesPerWarp == 1 || kTilesPerWarp == 2, "one or two tiles per warp");
    static_assert(kColumnTiles == 1 || kColumnTiles == 2, "one or two n8 tiles");
    static_assert(kStages >= 1 && kStages <= 4, "pipeline depth must fit cp_wait");
    static_assert(kMinBlocks >= 1, "launch-bounds occupancy must be positive");

    struct Stage {
        __align__(16) std::uint8_t codes[kRows][kCodeRowStride];
        __align__(16) std::uint8_t scales[kRows][kScaleBytesPerRowSlab];
    };

    // The K reduction reuses the stage ring once every slab has been consumed.
    static constexpr int kPartialFloats = kWarps * kTilesPerWarp * kColumnTiles * 32 * 4;

    union Shared {
        Stage stages[kStages];
        float partial[kPartialFloats];
    };

    static constexpr int kSharedBytes = static_cast<int>(sizeof(Shared));
    static_assert(kSharedBytes <= 48 * 1024, "stages exceed the static shared budget");
};

// {0, +1, -1} as bf16 (0x0000, 0x3F80, 0xBF80) for THIS tree's PQ2 convention c = w + 1:
// byte c of each table is the byte of bf16(c - 1). Derived and verified by numpy emulation of
// __byte_perm (bench86/REPORT.md round 55): c=0 -> -1, c=1 -> 0, c=2 -> +1, c=3 -> 0.
constexpr std::uint32_t kTernV2LutLow  = 0x00800080u; // low bytes: c0=80 c1=00 c2=80 c3=00
constexpr std::uint32_t kTernV2LutHigh = 0x003F00BFu; // high bytes: c0=BF c1=00 c2=3F c3=00

// Four selector nibbles (codes) -> two bf16x2 fragment registers: codes 0, 1 of the selector in
// `first`, codes 2, 3 in `second`.
__device__ __forceinline__ void tern_v2_a_fragment(std::uint32_t selector, unsigned& first,
                                                   unsigned& second) {
    const std::uint32_t low  = __byte_perm(kTernV2LutLow, 0u, selector);
    const std::uint32_t high = __byte_perm(kTernV2LutHigh, 0u, selector);
    first                    = __byte_perm(low, high, 0x5140);
    second                   = __byte_perm(low, high, 0x7362);
}

// The selector of k16 step `step` from the even/odd masks of a lane's code word.
__device__ __forceinline__ std::uint32_t tern_v2_step_selector(std::uint32_t even,
                                                               std::uint32_t odd, int step) {
    const std::uint32_t base = (step & 1) ? odd : even;
    return (step & 2) ? (base >> 16) : base;
}

// B fragments of k16 step `step` from the lane's sixteen activations (xa = j 0..7, xb = j 8..15).
__device__ __forceinline__ void tern_v2_b_fragment(const uint4& xa, const uint4& xb, int step,
                                                   unsigned& b0, unsigned& b1) {
    const uint4& source     = (step & 2) ? xb : xa;
    const std::uint32_t sel = (step & 1) ? 0x7632u : 0x5410u;
    b0                      = __byte_perm(source.x, source.y, sel);
    b1                      = __byte_perm(source.z, source.w, sel);
}

template <class Schedule>
__global__ __launch_bounds__(Schedule::kThreads, Schedule::kMinBlocks) void tern_t2v2_kernel(
    const __nv_bfloat16* __restrict__ x, const std::uint8_t* __restrict__ codes,
    const std::uint8_t* __restrict__ scales, __nv_bfloat16* __restrict__ out, std::int32_t rows,
    std::int32_t k, std::int32_t cols, std::int32_t out_row_stride) {
    constexpr int kTpw    = Schedule::kTilesPerWarp;
    constexpr int kNt     = Schedule::kColumnTiles;
    constexpr int kKW     = Schedule::kKWarps;
    constexpr int kStages = Schedule::kStages;
    using Stage           = typename Schedule::Stage;

    __shared__ __align__(16) typename Schedule::Shared shared;

    const int tid        = static_cast<int>(threadIdx.x);
    const int warp       = tid >> 5;
    const int lane       = tid & 31;
    const int gid        = lane >> 2;
    const int lid        = lane & 3;
    const int k_split    = warp % kKW;
    const int first_tile = warp / kKW * kTpw;
    const int row0       = static_cast<int>(blockIdx.x) * Schedule::kRows;

    const int groups_per_row = k / PQ2RowSplitStorage::kGroupK;
    const int slabs          = k / Schedule::kSlabK;
    const std::int64_t code_row_bytes =
        static_cast<std::int64_t>(groups_per_row) * PQ2RowSplitStorage::kCodeBytesPerGroup;
    const std::int64_t scale_row_bytes =
        static_cast<std::int64_t>(groups_per_row) * PQ2RowSplitStorage::kScaleBytesPerGroup;
    const int code_byte     = k_split * 16 + 4 * lid; // the lane's code word inside the row's slab
    const int group_in_slab = k_split >> 1;
    const int slice_k       = k_split * 64 + 16 * lid; // the lane's first k inside the slab

    const auto issue = [&](int stage_index, int slab) {
        Stage& stage                   = shared.stages[stage_index];
        constexpr int kChunksPerRow    = Schedule::kCodeBytesPerRowSlab / 16;
        constexpr int kChunks          = Schedule::kRows * kChunksPerRow;
        constexpr int kChunksPerThread = (kChunks + Schedule::kThreads - 1) / Schedule::kThreads;
#pragma unroll
        for (int i = 0; i < kChunksPerThread; ++i) {
            const int item = tid + i * Schedule::kThreads;
            if (item < kChunks) {
                const int r = item / kChunksPerRow;
                const int c = item - r * kChunksPerRow;
                cp_async<16, Cache::cg>(
                    &stage.codes[r][c * 16],
                    codes + static_cast<std::int64_t>(row0 + r) * code_row_bytes +
                        static_cast<std::int64_t>(slab) * Schedule::kCodeBytesPerRowSlab + c * 16);
            }
        }
        if (tid < Schedule::kRows) {
            cp_async<Schedule::kScaleBytesPerRowSlab>(
                &stage.scales[tid][0],
                scales + static_cast<std::int64_t>(row0 + tid) * scale_row_bytes +
                    static_cast<std::int64_t>(slab) * Schedule::kScaleBytesPerRowSlab);
        }
    };

    float acc[kTpw][kNt][4] = {};

#pragma unroll
    for (int prefetch = 0; prefetch < kStages - 1; ++prefetch) {
        if (prefetch < slabs) { issue(prefetch, prefetch); }
        cp_commit(); // empty commits keep cp_wait<kStages - 1> exact through the tail
    }

#pragma unroll 1
    for (int slab = 0; slab < slabs; ++slab) {
        {
            const int next = slab + kStages - 1;
            if (next < slabs) { issue(next % kStages, next); }
            cp_commit();
        }
        cp_wait<kStages - 1>();
        __syncthreads();
        const Stage& stage = shared.stages[slab % kStages];

        // B: the lane's sixteen activations of each live column of its tiles, straight from global.
        uint4 xa[kNt];
        uint4 xb[kNt];
#pragma unroll
        for (int nt = 0; nt < kNt; ++nt) {
            const int col = nt * 8 + gid;
            xa[nt]        = make_uint4(0u, 0u, 0u, 0u);
            xb[nt]        = make_uint4(0u, 0u, 0u, 0u);
            if (col < cols) {
                const __nv_bfloat16* column = x + static_cast<std::int64_t>(col) * k +
                                              static_cast<std::int64_t>(slab) * Schedule::kSlabK +
                                              slice_k;
                xa[nt]                      = load_ldg<uint4>(column);
                xb[nt]                      = load_ldg<uint4>(column + 8);
            }
        }

        // A: the even/odd selector masks of the top and bottom row of each tile.
        std::uint32_t even[kTpw][2];
        std::uint32_t odd[kTpw][2];
#pragma unroll
        for (int t = 0; t < kTpw; ++t) {
            const int tile_row = (first_tile + t) * 16 + gid;
            const std::uint32_t top =
                *reinterpret_cast<const std::uint32_t*>(&stage.codes[tile_row][code_byte]);
            const std::uint32_t bottom =
                *reinterpret_cast<const std::uint32_t*>(&stage.codes[tile_row + 8][code_byte]);
            even[t][0] = top & 0x33333333u;
            odd[t][0]  = (top >> 2) & 0x33333333u;
            even[t][1] = bottom & 0x33333333u;
            odd[t][1]  = (bottom >> 2) & 0x33333333u;
        }

        float slab_acc[kTpw][kNt][4] = {};
#pragma unroll
        for (int step = 0; step < 4; ++step) {
            unsigned a[kTpw][4];
#pragma unroll
            for (int t = 0; t < kTpw; ++t) {
                tern_v2_a_fragment(tern_v2_step_selector(even[t][0], odd[t][0], step), a[t][0],
                                   a[t][2]);
                tern_v2_a_fragment(tern_v2_step_selector(even[t][1], odd[t][1], step), a[t][1],
                                   a[t][3]);
            }
#pragma unroll
            for (int nt = 0; nt < kNt; ++nt) {
                unsigned b0;
                unsigned b1;
                tern_v2_b_fragment(xa[nt], xb[nt], step, b0, b1);
#pragma unroll
                for (int t = 0; t < kTpw; ++t) {
                    float (&c)[4] = slab_acc[t][nt];
                    mma_bf16(c[0], c[1], c[2], c[3], a[t][0], a[t][1], a[t][2], a[t][3], b0, b1);
                }
            }
        }

#pragma unroll
        for (int t = 0; t < kTpw; ++t) {
            const int tile_row = (first_tile + t) * 16 + gid;
            const float top_scale =
                __half2float(__ushort_as_half(*reinterpret_cast<const std::uint16_t*>(
                    &stage.scales[tile_row][2 * group_in_slab])));
            const float bottom_scale =
                __half2float(__ushort_as_half(*reinterpret_cast<const std::uint16_t*>(
                    &stage.scales[tile_row + 8][2 * group_in_slab])));
#pragma unroll
            for (int nt = 0; nt < kNt; ++nt) {
                acc[t][nt][0] = fmaf(slab_acc[t][nt][0], top_scale, acc[t][nt][0]);
                acc[t][nt][1] = fmaf(slab_acc[t][nt][1], top_scale, acc[t][nt][1]);
                acc[t][nt][2] = fmaf(slab_acc[t][nt][2], bottom_scale, acc[t][nt][2]);
                acc[t][nt][3] = fmaf(slab_acc[t][nt][3], bottom_scale, acc[t][nt][3]);
            }
        }
        // The next iteration's issue writes the stage this one just read.
        __syncthreads();
    }
    cp_wait<0>();
    __syncthreads();

    // Reduce the K partials of each tile in a fixed order: odd K warps publish, even ones fold
    // their neighbour, then K warp 0 sums the even ones.
    float* partial  = shared.partial;
    const auto slot = [&](int w, int t, int nt) {
        return partial + (((w * kTpw + t) * kNt + nt) * 32 + lane) * 4;
    };
    if ((k_split & 1) != 0) {
#pragma unroll
        for (int t = 0; t < kTpw; ++t) {
#pragma unroll
            for (int nt = 0; nt < kNt; ++nt) {
                const float (&c)[4] = acc[t][nt];
                store_vec(slot(warp, t, nt), make_float4(c[0], c[1], c[2], c[3]));
            }
        }
    }
    __syncthreads();
    if ((k_split & 1) == 0) {
#pragma unroll
        for (int t = 0; t < kTpw; ++t) {
#pragma unroll
            for (int nt = 0; nt < kNt; ++nt) {
                float (&c)[4]        = acc[t][nt];
                const float4 partner = load_vec<float4>(slot(warp + 1, t, nt));
                c[0] += partner.x;
                c[1] += partner.y;
                c[2] += partner.z;
                c[3] += partner.w;
                if (k_split != 0) {
                    store_vec(slot(warp, t, nt), make_float4(c[0], c[1], c[2], c[3]));
                }
            }
        }
    }
    if constexpr (kKW > 2) { __syncthreads(); }

    if (k_split == 0) {
#pragma unroll
        for (int t = 0; t < kTpw; ++t) {
            const int row = row0 + (first_tile + t) * 16 + gid;
#pragma unroll
            for (int nt = 0; nt < kNt; ++nt) {
                float4 sum =
                    make_float4(acc[t][nt][0], acc[t][nt][1], acc[t][nt][2], acc[t][nt][3]);
#pragma unroll
                for (int split = 2; split < kKW; split += 2) {
                    const float4 value = load_vec<float4>(slot(warp + split, t, nt));
                    sum.x += value.x;
                    sum.y += value.y;
                    sum.z += value.z;
                    sum.w += value.w;
                }
                const int col = nt * 8 + 2 * lid;
                if (col < cols) {
                    out[static_cast<std::int64_t>(col) * out_row_stride + row] =
                        __float2bfloat16_rn(sum.x);
                    out[static_cast<std::int64_t>(col) * out_row_stride + row + 8] =
                        __float2bfloat16_rn(sum.z);
                }
                if (col + 1 < cols) {
                    out[static_cast<std::int64_t>(col + 1) * out_row_stride + row] =
                        __float2bfloat16_rn(sum.y);
                    out[static_cast<std::int64_t>(col + 1) * out_row_stride + row + 8] =
                        __float2bfloat16_rn(sum.w);
                }
            }
        }
    }
}

} // namespace ninfer::ops::detail

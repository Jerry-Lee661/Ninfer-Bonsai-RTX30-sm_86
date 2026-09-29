# Deployment walkthrough and pitfalls (RTX 3080 Ti, sm_86)

Chronological notes from getting this stack running, with the numbers we measured (400W power
limit, single request, greedy sampling).

## 1. Choosing the pieces

- Engine: [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all). It is the consolidated
  line that grew out of Don-Chad/ninfer-3090 and supports sm_86, sm_89 and sm_120a. It carries the
  ternary kernels and the speculative heads.
- Artifact: `WaveCut/Ternary-Bonsai-2-27B-NInfer-v3` (9.52 GB). It re-encodes Prism's
  `Ternary-Bonsai-2-27B-PQ2_0.gguf` into the `t2_g128_fp16` container (2.125 bit per weight) and
  bundles the DFlash2 drafter, the MTP head, the proposal head and the vision tower.
- Use the mirror host (`hf-mirror.com`) if huggingface.co is not reachable from your network.

## 2. Build (Windows, MSVC, CUDA 12.8)

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set CUDA_DIR=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release ^
      -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_CUDA_COMPILER="%CUDA_DIR%\bin\nvcc.exe" ^
      -DNINFER_BUILD_APPS=ON -DNINFER_DISABLE_MEDIA=ON
cmake --build build -j 24
```

Pitfalls:

- **MSVC C1061 (blocks nested too deeply)**: the long `else if` chain in `serve_options.cpp`
  triggers it. Flattening the chain into independent `if` statements is the right move, but keep
  the `for` loop closing brace after the whole chain. See
  [patches/README.md](../patches/README.md) for what went wrong when that was missed.
- `-DNINFER_DISABLE_MEDIA=ON` removes the ffmpeg and curl dependencies. Text inference does not
  need them; vision and video input do.
- The build produces large executables (about 1.2 GB), so leave enough disk space.

## 3. Serve

```bat
ninfer-serve.exe Ternary-Bonsai-2-27B-ninfer-v3.ninfer ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec mtp --draft-tokens 2 --host 127.0.0.1
```

Things to check:

- **Flag order**: on unpatched binaries the flags after `--host` are dropped, because only the very
  first flag is parsed at all. After applying our fix the order no longer matters, but keep this in
  mind when debugging an older binary.
- **Did the speculative components load?** The `loading weights` line is a hard indicator:
  6.70 GiB without speculation, 7.12 GiB with MTP, 7.99 GiB with DFlash2.
- **Is speculation actually running?** After a request, `GET /stats` on the main port returns
  `counters.decode_rounds` and `counters.committed_decode_tokens`. A ratio of 1.0 means one token
  per round, so speculation is not running. We measured 4.85 with DFlash2 5 drafts on English text.

## 4. Pitfall list

| Symptom | Cause | Fix |
|---|---|---|
| `--spec` and friends have no effect | Parsing chain trapped inside the `for` loop, `return` inside the loop | Use `patches/serve_options.cpp` and rebuild |
| Running with `--spec` matches no-spec speed | Same as above | Same as above |
| `/v1/chat/completions` returns `model_not_found` | The `model` field of the request does not match `--model-id` | Use the value passed to `--model-id` |
| Speculation helps far less on Chinese text | The speculative heads are tuned for English and code | Lower `--draft-tokens` to 2, or accept the smaller gain |
| Absolute throughput is low and jittery | Another inference process on the same GPU is competing | Keep the GPU idle while benchmarking, and record clocks and power |
| `curl` fails on paths under Git Bash | MSYS path conversion rewrites the URL (`/stats` becomes a Windows path) | Set `MSYS_NO_PATHCONV=1` or use Windows style paths |

## 5. Conditions for reproducing our numbers

- Single request, greedy sampling (`temperature=0`), no concurrency.
- Idle GPU (`nvidia-smi` utilization below 10 percent), 400W power limit, and record
  `clocks.sm` together with `power.draw`.
- Same artifact and same engine revision. Pick the draft count for the workload: 5 drafts for
  English and code, 2 drafts for Chinese.

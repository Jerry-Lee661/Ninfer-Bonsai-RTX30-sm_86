# Downloads and verification

## 1. Prebuilt package (no build required)

Six parts attached to the
[v0.1.0 release](https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86/releases/tag/v0.1.0),
812 MB in total. Download all six and merge them:

```bat
copy /b ninfer-serve-sm86-v0.1.0.zip.000+ninfer-serve-sm86-v0.1.0.zip.001+ninfer-serve-sm86-v0.1.0.zip.002+ninfer-serve-sm86-v0.1.0.zip.003+ninfer-serve-sm86-v0.1.0.zip.004+ninfer-serve-sm86-v0.1.0.zip.005 ninfer-serve-sm86-v0.1.0.zip
certutil -hashfile ninfer-serve-sm86-v0.1.0.zip SHA256
```

On Linux or macOS: `cat ninfer-serve-sm86-v0.1.0.zip.0* > ninfer-serve-sm86-v0.1.0.zip`

The merged file is 812 MB. Expected SHA256:
`704560911e5feedd20c2dd70ce12c352691325da9d0fce070ee7bd570b7b0416`

Per-part SHA256 (from our local build):

```
6347665c5b6b... ninfer-serve-sm86-v0.1.0.zip.000
3af6b8feef51... ninfer-serve-sm86-v0.1.0.zip.001
ff0aa8e5e27c... ninfer-serve-sm86-v0.1.0.zip.002
4ba68532e71b... ninfer-serve-sm86-v0.1.0.zip.003
a0b75de88432... ninfer-serve-sm86-v0.1.0.zip.004
0fd6a60ef5f0... ninfer-serve-sm86-v0.1.0.zip.005
```

Full values are in `parts_sha256.txt` inside our working tree; after merging, the file level
checksum above is the one that matters.

Package contents: `ninfer-serve.exe` (ninfer-all plus the parser fix, sm_86), the ffmpeg and curl
runtime libraries, launcher scripts, upstream LICENSE and NOTICE, and an inner `SHA256SUMS.txt`.
The bundled launcher scripts have Chinese file names and comments; the command lines inside are
what matter.

Runtime requirements:

1. NVIDIA driver 550 or newer.
2. CUDA 12.8 runtime: put `cudart64_12.dll` and `cublas64_12.dll` next to the executable or on
   PATH. Installing CUDA Toolkit 12.8 provides them under
   `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin`.
3. Microsoft Visual C++ 2015 to 2022 x64 runtime (`MSVCP140.dll` and friends).

## 2. Model artifact

### Directly loadable by ninfer (recommended)

| Field | Value |
|---|---|
| Repository | `WaveCut/Ternary-Bonsai-2-27B-NInfer-v3` |
| File | `Ternary-Bonsai-2-27B-ninfer-v3.ninfer` (9.52 GB) |
| Mirror | `https://hf-mirror.com/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3/resolve/main/Ternary-Bonsai-2-27B-ninfer-v3.ninfer` |
| Original | `https://huggingface.co/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3` |
| SHA256 | `cdc4810b0ff17c40d0f62cf214b6e0bcd08346e9eb05ca53371507037793c14a` |

This is the artifact used for every number in this repository. It contains the DFlash2 drafter,
the MTP head, the proposal head and the vision tower.

### Original ternary GGUF (for llama.cpp style engines, not loadable by ninfer)

| File | Notes |
|---|---|
| `Ternary-Bonsai-2-27B-PTQ1_0.gguf` | 1.75 bit per weight, balanced tier |
| `Ternary-Bonsai-2-27B-PQ2_0.gguf` | 2.125 bit per weight, speed tier |
| `Ternary-Bonsai-2-27B-F16.gguf` | F16 source weights |
| `Ternary-Bonsai-2-27B-mmproj-BF16.gguf` | Vision projection |

Repository `prism-ml/Ternary-Bonsai-2-27B-gguf`, mirror
`https://hf-mirror.com/prism-ml/Ternary-Bonsai-2-27B-gguf`.

Note that GGUF and `.ninfer` are two different containers. ninfer reads `.ninfer` only; GGUF files
are for Prism's llama.cpp fork and similar engines. The two GGUF tiers carry the same weight
values (we compared them element by element), but perplexity numbers are not comparable across
engines.

### Base model

`Qwen/Qwen3.8-27B` (`https://huggingface.co/Qwen/Qwen3.8-27B`).

## 3. Verifying the downloads

```bat
certutil -hashfile ninfer-serve-sm86-v0.1.0.zip SHA256
:: expect 704560911e5feedd20c2dd70ce12c352691325da9d0fce070ee7bd570b7b0416

certutil -hashfile Ternary-Bonsai-2-27B-ninfer-v3.ninfer SHA256
:: expect cdc4810b0ff17c40d0f62cf214b6e0bcd08346e9eb05ca53371507037793c14a
```

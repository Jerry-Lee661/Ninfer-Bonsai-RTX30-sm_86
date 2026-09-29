# serve_options.cpp parser fix

## Symptoms

- `ninfer-serve` is started with `--spec dflash2 --draft-tokens 5` and the log shows **no
  speculation statistics at all**; throughput is identical to running without `--spec`.
- Even a bogus value is accepted: `ninfer-serve.exe <artifact> --spec banana` starts normally.
- Only the **first** command line flag has any effect. Put `--kv-dtype rk4v4` first and it applies;
  put `--spec`, `--max-context` and the rest after it and they are all ignored.

## Mechanism

The argument parsing loop in `src/serve/serve_options.cpp` is damaged: the whole chain of 123 flag
branches sits inside the `for (int i = 2; i < argc; ++i)` body, and `return options;` never leaves
the loop:

```cpp
for (int i = 2; i < argc; ++i) {
    const std::string arg = argv[i];
    ...
    if (arg == "--host")      { ... }
    if (arg == "--port")      { ... }
    ...                        // all 123 branches
    if (arg == "--spec")      { options.speculative.backend = parse_speculative_backend(...); }
    ...
    return options;            // stays inside the loop, so argv[2] is the only flag parsed
}
```

The function therefore returns after the first argument and silently discards the rest. The
damage came from an attempt to work around MSVC C1061 (blocks nested too deeply): flattening the
`else if` chain into independent `if` statements is the correct direction (the original chain
really does hit C1061), but the braces were misplaced and the result was never verified at run
time.

## Fix

Keep the flattened style (MSVC friendly) and move the `for` loop closing brace to after the whole
parsing chain, so the KV capacity derivation, the option validation and `return` sit at function
level again. The net brace count is unchanged.

The fixed `serve_options.cpp` in this directory is a drop-in replacement for the
`iamwavecut/ninfer-all` master revision of September 2026. If upstream has moved on, check the same
two things: where the loop closes, and where `return` sits.

## Verification (worth repeating after any rebuild)

```bat
:: 1) A bogus value must be rejected
ninfer-serve.exe <artifact> --spec banana
::    expect: ninfer-serve: invalid speculative backend: banana

:: 2) The speculative components must load (the load size grows)
ninfer-serve.exe <artifact> --spec mtp --draft-tokens 3 --host 127.0.0.1
::    expect the log to say: loading weights | 7.99 GiB  (6.70 GiB without speculation)

:: 3) Check that speculation actually runs
::    After one request, GET http://127.0.0.1:<port>/stats
::    expect counters.decode_rounds to be clearly below committed_decode_tokens
::    (we measure 4.85 tokens per round, against 1.0)
```

## Measured before and after

| Item | Before fix | After fix |
|---|---|---|
| Speculative backend seen by the engine | None | MTP or DFlash2 |
| Weight load | 6.70 GiB | 7.99 GiB (drafter included) |
| Request log | no speculation statistics | `mtp accepted 110/287 (38.3%)` and similar |
| decode_rounds over tokens | 1.00 | 4.85 |
| Chinese, 256 tokens | about 74 t/s | **103.8 t/s** (MTP 2 drafts) |
| English, 512 tokens | 73.8 t/s | **198.8 t/s** (MTP 5 drafts) |

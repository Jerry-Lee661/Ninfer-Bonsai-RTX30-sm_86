# serve_options.cpp 解析器修复

## 症状

- `ninfer-serve` 加了 `--spec dflash2 --draft-tokens 5`，日志里**没有任何投机统计**，吞吐与
  不加 `--spec` 完全相同。
- 用非法值试探也**不报错**：`ninfer-serve.exe <artifact> --spec banana` 能正常起服。
- 只有命令行里**第一个**旗标起作用：例如把 `--kv-dtype rk4v4` 放在最前时确实生效，放在后面的
  `--spec`、`--max-context` 等则全部被忽略。

## 机制

`src/serve/serve_options.cpp` 的参数解析循环被改坏：整条 123 分支的旗标解析链被包进了
`for (int i = 2; i < argc; ++i)` 的循环体内，而 `return options;` 也留在循环体里：

```cpp
for (int i = 2; i < argc; ++i) {
    const std::string arg = argv[i];
    ...
    if (arg == "--host")      { ... }
    if (arg == "--port")      { ... }
    ...                        // 全部 123 个分支
    if (arg == "--spec")      { options.speculative.backend = parse_speculative_backend(...); }
    ...
    return options;            // <== 留在循环里，处理完 argv[2] 就返回
}
```

结果：函数只解析第一个参数就返回，其余旗标全部丢弃。这个改动来自一次「MSVC C1061 编译器限制」
的规避：把 `else if` 链摊平成独立 `if` 是正确方向（原版链在 MSVC 上确实报 C1061），但摊平时
花括号错位，且从未做过行为验证。

## 修复

保留摊平风格（MSVC 友好），把 `for` 循环的闭合括号移到整条解析链之后，让 KV 容量推导、
参数校验与 `return` 回到函数层。净花括号数不变。

修复后的 `serve_options.cpp` 已放在本目录，直接覆盖同名文件即可（对应
`iamwavecut/ninfer-all` master 的 2026-09 修订；若上游已更新，请按同样原则检查
「循环闭合位置」与「return 位置」）。

## 验证（建议照做）

```bat
:: 1) 非法值必须报错
ninfer-serve.exe <artifact> --spec banana
::    期望：ninfer-serve: invalid speculative backend: banana

:: 2) 投机组件必须加载（有 drafter 时体积变大）
ninfer-serve.exe <artifact> --spec mtp --draft-tokens 3 --host 127.0.0.1
::    期望日志：loading weights | 7.99 GiB（无投机时为 6.70 GiB）

:: 3) 请求后查轮数比（判定投机是否真的在跑）
::    起服后发一个请求，再 GET http://127.0.0.1:<port>/stats
::    期望 counters.decode_rounds 明显小于 committed_decode_tokens（实测 4.85 比 1）
```

## 我们的实测（修复前后）

| 项 | 修复前 | 修复后 |
|---|---|---|
| 引擎解析到的投机后端 | None | MTP / DFlash2 |
| 权重加载 | 6.70 GiB | 7.99 GiB（含 drafter） |
| 请求日志 | 无投机统计 | `mtp accepted 110/287 (38.3%)` 等 |
| decode_rounds / tokens | 1.00 | 4.85 |
| 中文 256 token 吞吐 | ~74 t/s | **103.8 t/s**（MTP 2 drafts） |
| 英文 512 token 吞吐 | 73.8 t/s | **198.8 t/s**（MTP 5 drafts） |

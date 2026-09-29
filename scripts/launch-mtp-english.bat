@echo off
chcp 65001 >nul
REM MTP 5 drafts: best for English and code (measured 198.8 t/s on a 3080 Ti)
REM Edit the engine and model paths below, then run this file.

set "ENGINE=D:\ninfer-all\build\apps\ninfer-serve.exe"
set "ARTIFACT=D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer"
"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --host 127.0.0.1 --model-id bonsai2-27b --no-thinking ^
  --max-context 32768 --kv-capacity 32768 --kv-dtype rk4v4 ^
  --fast-prefill-kernel --prefill-chunk 2048 ^
  --spec mtp --draft-tokens 5 --lm-head-draft ^
  --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 ^
  --log-level info
pause

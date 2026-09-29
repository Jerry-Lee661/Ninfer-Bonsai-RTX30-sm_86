@echo off
chcp 65001 >nul
REM ============================================================
REM  MTP 2 drafts（中文负载推荐）
REM  实测：中文 256 token 103.8 t/s。
REM  改下面两处路径后双击即可。
REM ============================================================
set "ENGINE=D:\path	o
infer-alluildpps
infer-serve.exe"
set "ARTIFACT=D:\path	o\Ternary-Bonsai-2-27B.ninfer"

"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec mtp --draft-tokens 2 ^
  --host 127.0.0.1
pause

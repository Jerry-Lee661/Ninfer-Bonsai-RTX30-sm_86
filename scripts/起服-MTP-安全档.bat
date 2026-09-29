@echo off
chcp 65001 >nul
REM ============================================================
REM  MTP 3 drafts（通用）
REM  实测：英文 512 token 175.8 t/s。
REM  改下面两处路径后双击即可。
REM ============================================================
set "ENGINE=D:\path	o
infer-alluildpps
infer-serve.exe"
set "ARTIFACT=D:\path	o\Ternary-Bonsai-2-27B.ninfer"

"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec mtp --draft-tokens 3 --lm-head-draft ^
  --host 127.0.0.1
pause

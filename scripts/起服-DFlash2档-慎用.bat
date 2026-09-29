@echo off
chcp 65001 >nul
REM ============================================================
REM  DFlash2 5 drafts（serve 下轮开销异常，见 docs/03）
REM  实测：serve 下 65.8 t/s；命令行界面约 233 t/s。
REM  改下面两处路径后双击即可。
REM ============================================================
set "ENGINE=D:\path	o
infer-alluildpps
infer-serve.exe"
set "ARTIFACT=D:\path	o\Ternary-Bonsai-2-27B.ninfer"

"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec dflash2 --draft-tokens 5 ^
  --host 127.0.0.1
pause

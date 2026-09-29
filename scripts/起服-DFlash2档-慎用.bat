@echo off
chcp 65001 >nul
REM DFlash2 5 drafts（serve 下轮开销异常，见 docs/03）
REM 改下面两处路径后双击运行。

set "ENGINE=D:\ninfer-all\build\apps\ninfer-serve.exe"
set "ARTIFACT=D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer"
"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec dflash2 --draft-tokens 5 ^
  --host 127.0.0.1
pause

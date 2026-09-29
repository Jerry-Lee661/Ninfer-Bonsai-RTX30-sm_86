@echo off
chcp 65001 >nul
REM MTP 2 drafts，中文负载推荐（实测 103.8 t/s @3080Ti）
REM 改下面两处路径后双击运行。

set "ENGINE=D:\ninfer-all\build\apps\ninfer-serve.exe"
set "ARTIFACT=D:\models\Ternary-Bonsai-2-27B-ninfer-v3.ninfer"
"%ENGINE%" "%ARTIFACT%" ^
  --port 8299 --model-id bonsai2-27b --no-thinking ^
  --spec mtp --draft-tokens 2 ^
  --host 127.0.0.1
pause

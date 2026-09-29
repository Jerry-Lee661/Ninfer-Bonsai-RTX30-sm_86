@echo off
REM ============================================================
REM  ninfer-all 构建（Ninja 增量）。先跑 configure_serve.bat。
REM  产物：%NINFER_SRC%\build\apps\ninfer-serve.exe
REM ============================================================
set "NINFER_SRC=D:\path\to\ninfer-all"
set "CUDA_DIR=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

call "%VCVARS%"
set PATH=%CUDA_DIR%\bin;%PATH%
set CUDACXX=%CUDA_DIR%\bin\nvcc.exe

cd /d "%NINFER_SRC%\build"
ninja ninfer-serve
echo BUILD_EXIT=%ERRORLEVEL%
pause

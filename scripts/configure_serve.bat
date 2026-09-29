@echo off
REM ============================================================
REM  ninfer-all 构建配置（RTX 30 系 / sm_86，Windows + MSVC + CUDA 12.8）
REM  用法：把下面两个路径改成你自己的，然后双击本脚本。
REM ============================================================
set "NINFER_SRC=D:\path\to\ninfer-all"
set "CUDA_DIR=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

call "%VCVARS%"
if errorlevel 1 ( echo [ERROR] vcvars64 not found: %VCVARS% & pause & exit /b 1 )
set PATH=%CUDA_DIR%\bin;%PATH%
set CUDACXX=%CUDA_DIR%\bin\nvcc.exe

cd /d "%NINFER_SRC%"
cmake -B build -S . -G Ninja -DCMAKE_BUILD_TYPE=Release ^
      -DCMAKE_CUDA_ARCHITECTURES=86 -DCMAKE_CUDA_COMPILER="%CUDA_DIR%\bin\nvcc.exe" ^
      -DNINFER_BUILD_APPS=ON -DNINFER_DISABLE_MEDIA=ON
echo CONFIGURE_EXIT=%ERRORLEVEL%
pause

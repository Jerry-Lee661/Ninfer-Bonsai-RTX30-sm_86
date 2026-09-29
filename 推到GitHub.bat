@echo off
chcp 65001 >nul
REM ============================================================
REM  一键推送到 https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86
REM  第一次推送会要求登录：用户名填 Jerry-Lee661，
REM  密码处粘贴 Personal Access Token（GitHub 设置里生成，勾 repo 权限）。
REM  也可以先用 GitHub Desktop / git credential manager 登录一次。
REM ============================================================
cd /d "%~dp0"
git remote remove origin 2>nul
git remote add origin https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86.git
git branch -M main
git push -u origin main
if errorlevel 1 (
  echo.
  echo [提示] 推送失败。若提示认证失败，请在 GitHub 生成 PAT 后重试本脚本。
) else (
  echo.
  echo [完成] 已推送。仓库地址：https://github.com/Jerry-Lee661/Ninfer-Bonsai-RTX30-sm_86
)
pause

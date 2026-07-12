@echo off
REM branch-setup.bat — Windows 包装器，自动查找 bash 并运行 branch-setup.sh
REM 用法:
REM   branch-setup.bat <branch-name>    核验起点 + 建分支 + 记录基线

setlocal enabledelayedexpansion

set "BASH_CMD="
where bash >nul 2>&1 && ( set "BASH_CMD=bash" & goto :found )
if exist "C:\Program Files\Git\bin\bash.exe" ( set "BASH_CMD=C:\Program Files\Git\bin\bash.exe" & goto :found )
if exist "C:\Program Files (x86)\Git\bin\bash.exe" ( set "BASH_CMD=C:\Program Files (x86)\Git\bin\bash.exe" & goto :found )
where wsl >nul 2>&1 && ( set "BASH_CMD=wsl bash" & goto :found )
if exist "C:\msys64\usr\bin\bash.exe" ( set "BASH_CMD=C:\msys64\usr\bin\bash.exe" & goto :found )

echo ERROR: 未找到 bash。请安装 Git for Windows 或 WSL。
exit /b 1

:found
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "BASH_DIR=%SCRIPT_DIR%"
set "BASH_DIR=!BASH_DIR:\=/!"
set "BASH_DIR=!BASH_DIR:C:=/c!"
set "BASH_DIR=!BASH_DIR:D:=/d!"
set "BASH_DIR=!BASH_DIR:E:=/e!"

!BASH_CMD! "!BASH_DIR!/branch-setup.sh" %*

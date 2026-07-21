@echo off
REM install.bat — Windows 包装器，自动查找 bash 并运行 install.sh
REM 用法:
REM   install.bat                  自动检测环境 + 安装
REM   install.bat --claude         强制安装到 ~/.claude/skills/
REM   install.bat --list           仅列出检测到的环境
REM   install.bat --all            安装到所有已检测到的环境

setlocal enabledelayedexpansion

REM 查找 bash（优先级：Git Bash > WSL > MSYS2）
set "BASH_CMD="

REM 1. Git Bash（最常见）
where bash >nul 2>&1 && (
    set "BASH_CMD=bash"
    goto :found
)

REM 2. Git for Windows 默认路径
if exist "C:\Program Files\Git\bin\bash.exe" (
    set "BASH_CMD=C:\Program Files\Git\bin\bash.exe"
    goto :found
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    set "BASH_CMD=C:\Program Files (x86)\Git\bin\bash.exe"
    goto :found
)

REM 3. WSL
where wsl >nul 2>&1 && (
    set "BASH_CMD=wsl bash"
    goto :found
)

REM 4. MSYS2
if exist "C:\msys64\usr\bin\bash.exe" (
    set "BASH_CMD=C:\msys64\usr\bin\bash.exe"
    goto :found
)

echo ERROR: 未找到 bash。请安装 Git for Windows（https://git-scm.com/download/win）或 WSL。
exit /b 1

:found
echo 检测到 bash: !BASH_CMD!

REM 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
REM 去掉末尾反斜杠
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM 将 Windows 路径转换为 bash 路径（WP2.2: WSL 用 /mnt/c/，Git Bash/MSYS2 用 /c/）
set "BASH_DIR=%SCRIPT_DIR%"
set "BASH_DIR=!BASH_DIR:\=/!"
echo !BASH_CMD! | findstr /i "wsl" >nul 2>&1 && (
    set "BASH_DIR=!BASH_DIR:C:=/mnt/c!"
    set "BASH_DIR=!BASH_DIR:D:=/mnt/d!"
    set "BASH_DIR=!BASH_DIR:E:=/mnt/e!"
) || (
    set "BASH_DIR=!BASH_DIR:C:=/c!"
    set "BASH_DIR=!BASH_DIR:D:=/d!"
    set "BASH_DIR=!BASH_DIR:E:=/e!"
)

REM 运行 install.sh
!BASH_CMD! "!BASH_DIR!/install.sh" %*

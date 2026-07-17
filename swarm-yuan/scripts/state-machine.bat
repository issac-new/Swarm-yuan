@echo off
REM state-machine.bat — Windows 包装器，自动查找 bash 并运行 state-machine.sh
REM 用法:
REM   state-machine.bat init <change>    初始化阶段状态
REM   state-machine.bat get <field>      读取字段
REM   state-machine.bat set <field> <val> 设置字段
REM   state-machine.bat transition <phase> 阶段转换（带门禁）
REM   state-machine.bat guard <phase>    检查阶段准入
REM   state-machine.bat next             下一阶段
REM   state-machine.bat status           当前状态

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

!BASH_CMD! "!BASH_DIR!/state-machine.sh" %*

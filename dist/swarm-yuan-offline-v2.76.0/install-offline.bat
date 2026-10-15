@echo off
rem swarm-yuan 离线安装入口（Windows）：经 Git Bash 运行 install-offline.sh
rem 前置：安装 Git for Windows（含 bash/git），且 bash 在 PATH
where bash >nul 2>nul || (echo [ERROR] 未找到 bash——请先安装 Git for Windows 并将其加入 PATH & exit /b 1)
bash "%~dp0install-offline.sh" %*

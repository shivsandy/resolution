@echo off
title Fixing Resolutions Please Wait
cd /d "%~dp0"
start "" "configuration.exe"
start "" "resolution.exe"
timeout /t 10 /nobreak >nul
exit

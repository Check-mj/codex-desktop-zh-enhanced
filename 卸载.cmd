@echo off
chcp 65001 >nul
title Codex Zh Launcher Uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
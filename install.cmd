@echo off
chcp 65001 >nul
title Codex Zh Launcher Setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
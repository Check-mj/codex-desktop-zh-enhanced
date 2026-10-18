@echo off
chcp 65001 >nul
title Codex 汉化工具 - 重新构建
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0重新构建.ps1" %*
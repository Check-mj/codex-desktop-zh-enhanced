@echo off
chcp 65001 >nul
title Codex 中文启动器 - 卸载
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0卸载.ps1"
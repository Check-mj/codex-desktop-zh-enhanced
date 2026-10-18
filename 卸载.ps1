# ============================================================
#  Codex 中文启动器 —— 卸载
#  作用：清除开机自启、快捷方式、日志与配置，不碰 Codex 本体
#  用法：右键 -> 使用 PowerShell 运行，或双击 卸载.cmd
# ============================================================
$ErrorActionPreference = 'SilentlyContinue'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "== 正在卸载 Codex 中文启动器 ==" -ForegroundColor Cyan

# 1) 结束守护与界面进程
Get-Process -Name "Codex-Zh-Launcher*" | Stop-Process -Force
Start-Sleep -Milliseconds 800
Write-Host "  已结束启动器进程"

# 2) 删除开机自启项
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'CodexZhLauncherZh'
Write-Host "  已删除开机自启项"

# 3) 删除快捷方式
$desk = [Environment]::GetFolderPath('Desktop')
$progs = [Environment]::GetFolderPath('Programs')
foreach ($p in @((Join-Path $desk 'Codex 中文版.lnk'), (Join-Path $progs 'Codex 中文版.lnk'))) {
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  已删除快捷方式: $p" }
}

# 4) 删除本地数据（日志/首启标记/归属文件）
$data = Join-Path $env:LOCALAPPDATA 'CodexZhLauncher'
if (Test-Path $data) { Remove-Item $data -Recurse -Force; Write-Host "  已删除本地数据: $data" }

Write-Host ""
Write-Host "卸载完成。" -ForegroundColor Green
Write-Host "程序目录仍在: $base" -ForegroundColor DarkGray
Write-Host "如需彻底删除，请手动删除该文件夹（先关闭本窗口）。" -ForegroundColor DarkGray
Write-Host "Codex 本体及其界面不受影响。" -ForegroundColor DarkGray
Read-Host "按回车关闭"

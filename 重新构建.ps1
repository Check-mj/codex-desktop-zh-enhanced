# ============================================================
#  Codex 汉化增强工具 —— 一键重建
#  用法：右键 -> 使用 PowerShell 运行，或双击 重新构建.cmd
#  作用：把当前源码重新编译，并替换 D:\Codex汉化 下的主程序
# ============================================================
param(
    [switch]$Update,    # 加 -Update 会先下载上游最新源码，再套用我们的修改
    [switch]$NoPause,   # 加 -NoPause 结束后不等待回车（界面按钮调用时用）
    [switch]$NoDeploy   # 加 -NoDeploy 只构建+签名，不替换正在运行的主程序
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcRoot = Join-Path $base 'source\codex-desktop-zh-main'
$overlay = Join-Path $base 'overlay'
$dist = Join-Path $srcRoot 'dist\Codex-Zh-Launcher-Windows-x64.exe'
$target = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe'

Write-Host "== Codex 汉化工具 重建 ==" -ForegroundColor Cyan

# ---------- 可选：拉取上游最新源码 ----------
if ($Update) {
    Write-Host "[1/5] 下载上游最新源码..." -ForegroundColor Yellow
    $zip = Join-Path $env:TEMP 'codex-desktop-zh-latest.zip'
    $tmp = Join-Path $env:TEMP 'codex-desktop-zh-latest'
    Invoke-WebRequest 'https://codeload.github.com/shibaweidu/codex-desktop-zh/zip/refs/heads/main' -OutFile $zip -UseBasicParsing -TimeoutSec 180
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip -DestinationPath $tmp -Force
    $newSrc = Join-Path $tmp 'codex-desktop-zh-main'

    # 记录上游版本号（用于启动器的“上游更新提醒”）
    $upstreamVersion = ''
    $upstreamAppInfo = Join-Path $newSrc 'src\AppInfo.cs'
    if (Test-Path $upstreamAppInfo) {
        $m = Select-String -Path $upstreamAppInfo -Pattern 'Version\s*=\s*"([0-9][^"]*)"' | Select-Object -First 1
        if ($m) { $upstreamVersion = $m.Matches[0].Groups[1].Value }
    }

    # 替换源码目录，但保留 overlay
    if (Test-Path $srcRoot) { Remove-Item $srcRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $base 'source') | Out-Null
    Copy-Item $newSrc $srcRoot -Recurse -Force

    # 套用我们的修改（开机自启/守护/版本检测/日志清理/路径修复/上游提醒）
    Write-Host "      套用本地修改（AutoStart.cs / MainWindow.cs / Program.cs / AppInfo.cs 等）..."
    foreach ($f in Get-ChildItem $overlay -Filter *.cs) {
        Copy-Item $f.FullName (Join-Path $srcRoot "src\$($f.Name)") -Force
    }
    if ($upstreamVersion) {
        $ours = Join-Path $srcRoot 'src\AppInfo.cs'
        $content = [System.IO.File]::ReadAllText($ours)
        $content = [regex]::Replace($content, 'UpstreamBaseVersion\s*=\s*"[^"]*"', ('UpstreamBaseVersion = "' + $upstreamVersion + '"'))
        [System.IO.File]::WriteAllText($ours, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "      上游版本基线更新为 v$upstreamVersion"
    }
    Write-Host "      已套用 $((Get-ChildItem $overlay -Filter *.cs | Measure-Object).Count) 个本地改动文件（含开机自启/守护/版本检测/日志清理/路径修复）"
} else {
    Write-Host "[1/5] 使用现有源码（加 -Update 可拉取上游最新）" -ForegroundColor DarkGray
}

# ---------- 构建 ----------
Write-Host "[2/5] 编译..." -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $srcRoot 'build.ps1')
if (-not (Test-Path $dist)) { throw "构建失败：没有生成 $dist" }

# ---------- 替换主程序 ----------
if ($NoDeploy) {
    Write-Host "[3/5] 跳过替换（-NoDeploy：由调用方负责重启并替换）" -ForegroundColor DarkGray
} else {
    Write-Host "[3/5] 替换主程序..." -ForegroundColor Yellow
    if (Test-Path $target) {
        Copy-Item $target "$target.bak" -Force
    }
    Copy-Item $dist $target -Force
    Copy-Item (Join-Path $srcRoot 'dist\SHA256SUMS.txt') (Join-Path $base 'SHA256SUMS.txt') -Force
}

# ---------- 签名 ----------
$signScript = Join-Path $base 'sign.ps1'
if (Test-Path $signScript) {
    Write-Host "[5/5] 签名..." -ForegroundColor Yellow
    if ($NoDeploy) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $signScript -Path $dist
    } else {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $signScript -Path $target
    }
} else {
    Write-Host "[5/5] 跳过签名（找不到 sign.ps1）" -ForegroundColor DarkGray
}

# ---------- 结果 ----------
Write-Host "[4/5] 完成" -ForegroundColor Green
$resultFile = if ($NoDeploy) { $dist } else { $target }
$v = (Get-Item $resultFile).VersionInfo.FileVersion
$h = (Get-FileHash $resultFile -Algorithm SHA256).Hash
Write-Host "  文件: $resultFile"
Write-Host "  版本: $v"
Write-Host "  SHA256: $h"
Write-Host ""
Write-Host "提示：正在运行旧版本的话，需要先退出工具再打开新版本。" -ForegroundColor DarkGray
if (-not $NoPause) { Read-Host "按回车关闭" }

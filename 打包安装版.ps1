# ============================================================
#  Codex 中文启动器 —— 打包安装版
#  用法：右键用 PowerShell 运行，或双击 打包安装版.cmd
#  产物（输出到 发布\）：
#    Codex中文启动器-安装包-vX.Y.Z.zip   解压后双击 安装.cmd
#    Codex中文启动器-安装包-vX.Y.Z.exe   单文件安装程序（自解压）
# ============================================================
param(
    [string]$Version = '',
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $base '发布'
$stage = Join-Path $outDir '_stage'
$payload = Join-Path $stage 'payload'

# 未指定版本时，从源码 AppInfo.cs 自动读取
if (-not $Version) {
    $appInfoFile = Join-Path $base 'source\codex-desktop-zh-main\src\AppInfo.cs'
    if (Test-Path $appInfoFile) {
        $appInfoContent = Get-Content $appInfoFile -Raw -Encoding utf8
        $versionMatch = [regex]::Match($appInfoContent, 'public const string Version = "([0-9]+\.[0-9]+\.[0-9]+)"')
        if ($versionMatch.Success) { $Version = $versionMatch.Groups[1].Value }
    }
    if (-not $Version) { $Version = '0.8.0' }
}

Write-Host "== 打包 Codex 中文启动器 v$Version ==" -ForegroundColor Cyan

# ---------- 兼容 CI：根目录没有 exe 时从 dist 取 ----------
$builtExe = Join-Path $base 'source\codex-desktop-zh-main\dist\Codex-Zh-Launcher-Windows-x64.exe'
$rootExe = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe'
if (-not (Test-Path $rootExe) -and (Test-Path $builtExe)) { Copy-Item $builtExe $rootExe -Force }
$builtSum = Join-Path $base 'source\codex-desktop-zh-main\dist\SHA256SUMS.txt'
$rootSum = Join-Path $base 'SHA256SUMS.txt'
if (-not (Test-Path $rootSum) -and (Test-Path $builtSum)) { Copy-Item $builtSum $rootSum -Force }

# ---------- 清理 ----------
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $payload | Out-Null

# ---------- 复制程序文件 ----------
$files = @(
    'Codex-Zh-Launcher-Windows-x64.exe',
    'CodexZhLauncher.cer',
    'sign.ps1',
    '重新构建.cmd', '重新构建.ps1',
    '卸载.cmd', '卸载.ps1', 'uninstall.ps1', 'uninstall.cmd',
    '导入证书.cmd', '导入证书.ps1',
    'install.cmd', 'install.ps1', '安装.cmd',
    'SHA256SUMS.txt'
)
foreach ($file in $files) {
    $src = Join-Path $base $file
    if (Test-Path $src) { Copy-Item $src $payload -Force } else { Write-Warning "缺少文件: $file" }
}
foreach ($dir in @('overlay', 'source')) {
    $src = Join-Path $base $dir
    if (Test-Path $src) {
        Copy-Item $src $payload -Recurse -Force
        # 精简源码目录里的构建中间产物
        foreach ($sub in @('dist', 'obj')) {
            $del = Join-Path (Join-Path $payload $dir) "codex-desktop-zh-main\$sub"
            if (Test-Path $del) { Remove-Item $del -Recurse -Force }
        }
    }
}

# 安装入口放到包根目录（解压后直接双击 安装.cmd）
foreach ($entry in @('install.cmd', 'install.ps1', '安装.cmd')) {
    $src = Join-Path $base $entry
    if (Test-Path $src) { Copy-Item $src $stage -Force }
}

# 说明文件
$readme = @"
Codex 中文启动器 v$Version —— 安装说明
=====================================

一、安装
  方式 A：双击 安装.cmd（本目录下）
  方式 B：解压 zip 后双击 安装.cmd
  默认安装到 %LOCALAPPDATA%\Programs\Codex中文启动器（无需管理员权限）

二、安装后
  · 桌面/开始菜单出现「Codex 中文版」快捷方式，点它即中文启动
  · 已自动设置开机自启：开机后后台守护，点原版 Codex 图标也是中文
  · 首次启动会显示《使用说明》，主界面上方也有说明横幅

三、更新
  · 界面里的「一键重建」按钮：自动同步上游、重建、签名并重启
  · 或运行 重新构建.cmd（加 -Update 参数会拉取上游最新源码）

四、卸载
  · 运行 卸载.cmd：清除开机自启、快捷方式、日志与配置
  · 程序目录需手动删除（不会碰 Codex 本体）

五、换电脑注意
  · 程序使用自签名证书。换电脑首次使用请先运行 导入证书.cmd
"@
[System.IO.File]::WriteAllText((Join-Path $stage '安装说明.txt'), $readme, (New-Object System.Text.UTF8Encoding($true)))

# ---------- ZIP 安装包 ----------
Write-Host "[1/4] 生成 ZIP 安装包..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$zipPath = Join-Path $outDir "Codex中文启动器-安装包-v$Version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host ("      " + [math]::Round((Get-Item $zipPath).Length / 1KB, 0) + " KB -> " + $zipPath)

# ---------- 自解压 EXE（iexpress）----------
Write-Host "[2/4] 生成单文件安装程序..." -ForegroundColor Yellow
$tmp = Join-Path $env:TEMP 'codex-zh-installer-pack'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$payloadZip = Join-Path $tmp 'payload.zip'
Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $payloadZip -CompressionLevel Optimal

$setupCmd = @'
@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "EXTRA=%CZL_ARGS%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%~dp0payload.zip' -DestinationPath '%~dp0payload' -Force; & '%~dp0payload\install.ps1' %EXTRA%"
'@
[System.IO.File]::WriteAllText((Join-Path $tmp 'setup.cmd'), $setupCmd, (New-Object System.Text.ASCIIEncoding))

$sedPath = Join-Path $tmp 'package.sed'
$exeTmp = Join-Path $tmp 'installer.exe'
$sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$exeTmp
FriendlyName=Codex Zh Launcher Setup
AppLaunched=setup.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[Strings]
FILE0=payload.zip
FILE1=setup.cmd
[SourceFiles]
SourceFiles0=$tmp\
[SourceFiles0]
%FILE0%=
%FILE1%=
"@
[System.IO.File]::WriteAllText($sedPath, $sed, (New-Object System.Text.ASCIIEncoding))

$iexpress = Join-Path $env:WINDIR 'System32\iexpress.exe'
if (Test-Path $iexpress) {
    $proc = Start-Process -FilePath $iexpress -ArgumentList @('/N', '/Q', $sedPath) -PassThru -WindowStyle Hidden
    if (-not $proc.WaitForExit(120000)) {
        try { $proc.Kill() } catch { }
        Write-Warning "iexpress 超时（可能弹出了隐藏对话框），已跳过单文件安装包；ZIP 安装包仍可用"
    }
} else {
    Write-Warning "找不到 iexpress，已跳过单文件安装包；ZIP 安装包仍可用"
}
Start-Sleep -Seconds 1

$exePath = Join-Path $outDir "Codex中文启动器-安装包-v$Version.exe"
if (Test-Path $exeTmp) {
    if (Test-Path $exePath) { Remove-Item $exePath -Force }
    Copy-Item $exeTmp $exePath -Force
    Write-Host ("      " + [math]::Round((Get-Item $exePath).Length / 1KB, 0) + " KB -> " + $exePath)
} else {
    Write-Warning "iexpress 未能生成单文件安装程序（ZIP 包仍可用）"
}

# ---------- 签名安装程序 ----------
Write-Host "[3/4] 签名安装程序..." -ForegroundColor Yellow
$signScript = Join-Path $base 'sign.ps1'
if ((Test-Path $signScript) -and (Test-Path $exePath)) {
    $signArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $signScript, '-Path', $exePath)
    $cerPath = Join-Path $base 'CodexZhLauncher.cer'
    $expectedTp = ''
    if ((-not $env:CI) -and (Test-Path $cerPath)) {
        try {
            $expectedTp = (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cerPath)).Thumbprint
            if ($expectedTp) { $signArgs += @('-ExpectedThumbprint', $expectedTp) }
        } catch {
        }
    }
    if ($env:CI) { $signArgs += '-AllowUntrusted' }
    & powershell.exe @signArgs
    if ($LASTEXITCODE -ne 0) { throw "安装包签名失败（退出码 $LASTEXITCODE），已中止打包。" }
    $sigCheck = Get-AuthenticodeSignature $exePath
    if (-not $sigCheck.SignerCertificate) { throw "安装包签名校验失败：无签名证书，已中止打包。" }
    if ($sigCheck.Status -notin @('Valid', 'UntrustedRoot', 'UnknownError')) {
        throw "安装包签名状态异常：$($sigCheck.Status)，已中止打包。"
    }
    if ((-not $env:CI) -and $sigCheck.Status -ne 'Valid') {
        throw "本机打包要求签名状态为 Valid，实际为 $($sigCheck.Status)，已中止打包。"
    }
    if ($expectedTp -and $sigCheck.SignerCertificate.Thumbprint -ne $expectedTp) {
        throw "安装包签名指纹与预期不一致，已中止打包。"
    }
    Write-Host "      已签名并通过校验：$($sigCheck.Status)"
}

# ---------- 汇总 ----------
Write-Host "[4/4] 完成" -ForegroundColor Green
Get-ChildItem $outDir -File | Select-Object Name, @{n = '大小'; e = { [math]::Round($_.Length / 1KB, 0).ToString() + ' KB' } } | Format-Table -AutoSize

if (-not $NoPause) { Read-Host "按回车关闭" }

# ============================================================
#  Codex 汉化增强工具 —— 一键重建（固定上游版本 + 失败回滚）
#  用法：右键 -> 使用 PowerShell 运行，或双击 重新构建.cmd
#  参数：
#    -Update    同步上游源码（默认使用 tools\upstream-pin.json 固定的版本）
#    -Repin     重新查询上游最新 Release 并更新固定版本
#    -NoPause   结束后不等待回车（界面/CI 调用）
#    -NoDeploy  只构建+签名，不替换主程序（由调用方负责重启替换）
# ============================================================
param(
    [switch]$Update,
    [switch]$Repin,
    [switch]$NoPause,
    [switch]$NoDeploy
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcRoot = Join-Path $base 'source\codex-desktop-zh-main'
$overlay = Join-Path $base 'overlay'
$dist = Join-Path $srcRoot 'dist\Codex-Zh-Launcher-Windows-x64.exe'
$target = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe'
$pinFile = Join-Path $base 'tools\upstream-pin.json'
$buildInfoFile = Join-Path $base 'build-info.json'
$upstreamRepo = 'shibaweidu/codex-desktop-zh'

Write-Host "== Codex 汉化工具 重建 ==" -ForegroundColor Cyan

function Get-GitTagCommit {
    param($repo, $tag)
    $h = @{ 'User-Agent' = 'codex-zh-rebuild' }
    $ref = Invoke-RestMethod "https://api.github.com/repos/$repo/git/ref/tags/$tag" -Headers $h -TimeoutSec 30
    if ($ref.object.type -eq 'tag') {
        $tagObj = Invoke-RestMethod "https://api.github.com/repos/$repo/git/tags/$($ref.object.sha)" -Headers $h -TimeoutSec 30
        return $tagObj.object.sha
    }
    return $ref.object.sha
}

$buildInfo = [ordered]@{
    built_at = (Get-Date).ToString('o')
    upstream_version = ''
    upstream_commit = ''
    upstream_archive_sha256 = ''
    overlay_files = 0
    mode = if ($Update) { 'update' } else { 'local-source' }
}

# ---------- 1) 准备源码 ----------
if ($Update) {
    Write-Host "[1/5] 准备上游源码（固定版本）..." -ForegroundColor Yellow

    $pin = $null
    if (Test-Path $pinFile) {
        try { $pin = Get-Content $pinFile -Raw -Encoding utf8 | ConvertFrom-Json } catch { $pin = $null }
    }
    if (-not $pin -or -not $pin.commit -or $Repin) {
        Write-Host "      未找到固定版本或指定了 -Repin，查询上游最新 Release..."
        $h = @{ 'User-Agent' = 'codex-zh-rebuild' }
        $rel = Invoke-RestMethod "https://api.github.com/repos/$upstreamRepo/releases/latest" -Headers $h -TimeoutSec 30
        $version = ($rel.tag_name -replace '^v', '')
        $commit = Get-GitTagCommit -repo $upstreamRepo -tag $rel.tag_name
        $pin = [pscustomobject]@{
            repo = $upstreamRepo
            version = $version
            commit = $commit
            archive_sha256 = ''
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $pinFile) | Out-Null
        ($pin | ConvertTo-Json) | Set-Content $pinFile -Encoding UTF8
        Write-Host "      已固定上游版本: v$version @ $commit" -ForegroundColor Green
    }

    Write-Host "      上游固定版本: v$($pin.version) @ $($pin.commit)"
    $buildInfo.upstream_version = $pin.version
    $buildInfo.upstream_commit = $pin.commit

    $zip = Join-Path $env:TEMP ("upstream-" + $pin.commit + ".zip")
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Invoke-WebRequest "https://codeload.github.com/$($pin.repo)/zip/$($pin.commit)" -OutFile $zip -UseBasicParsing -TimeoutSec 300
    $sha = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($pin.archive_sha256 -and $pin.archive_sha256 -ne $sha) {
        throw "上游源码包哈希不匹配：固定值 $($pin.archive_sha256)，实际 $sha。已中止更新。"
    }
    if (-not $pin.archive_sha256) {
        $pin.archive_sha256 = $sha
        ($pin | ConvertTo-Json) | Set-Content $pinFile -Encoding UTF8
        Write-Host "      已记录上游源码包 SHA256: $sha"
    }
    $buildInfo.upstream_archive_sha256 = $sha

    $tmp = Join-Path $env:TEMP ("upstream-extract-" + $pin.commit)
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive $zip -DestinationPath $tmp -Force
    $newSrc = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    if (-not (Test-Path (Join-Path $newSrc 'build.ps1'))) { throw "上游源码结构异常：缺少 build.ps1" }

    # overlay 兼容性检查
    $overlayFiles = Get-ChildItem $overlay -Filter *.cs
    $newFiles = @()
    foreach ($f in $overlayFiles) {
        if (-not (Test-Path (Join-Path $newSrc "src\$($f.Name)"))) { $newFiles += $f.Name }
    }
    if ($newFiles.Count -gt 0) {
        Write-Warning ("上游中不存在、将作为新增文件套用: " + ($newFiles -join ', '))
    }

    # 替换源码目录并套用 overlay
    if (Test-Path $srcRoot) { Remove-Item $srcRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $base 'source') | Out-Null
    Copy-Item $newSrc $srcRoot -Recurse -Force
    foreach ($f in $overlayFiles) {
        Copy-Item $f.FullName (Join-Path $srcRoot "src\$($f.Name)") -Force
    }
    $buildInfo.overlay_files = $overlayFiles.Count

    # 更新“上游版本基线”（用于启动器的上游更新提醒）
    $ours = Join-Path $srcRoot 'src\AppInfo.cs'
    $content = [System.IO.File]::ReadAllText($ours)
    $content = [regex]::Replace($content, 'UpstreamBaseVersion\s*=\s*"[^"]*"', ('UpstreamBaseVersion = "' + $pin.version + '"'))
    [System.IO.File]::WriteAllText($ours, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "      已套用 $($overlayFiles.Count) 个本地改动文件；上游版本基线更新为 v$($pin.version)"
}
else {
    Write-Host "[1/5] 使用现有源码（加 -Update 可同步固定的上游版本）" -ForegroundColor DarkGray
    if (Test-Path $pinFile) {
        try {
            $pin = Get-Content $pinFile -Raw -Encoding utf8 | ConvertFrom-Json
            $buildInfo.upstream_version = $pin.version
            $buildInfo.upstream_commit = $pin.commit
            $buildInfo.upstream_archive_sha256 = $pin.archive_sha256
        } catch { }
    }
}

# ---------- 2) 编译 ----------
Write-Host "[2/5] 编译..." -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $srcRoot 'build.ps1')
if (-not (Test-Path $dist)) { throw "构建失败：没有生成 $dist（旧版本未改动）" }

# ---------- 3) 签名（先签 dist，成功后再部署，避免签失败污染现网） ----------
$signScript = Join-Path $base 'sign.ps1'
if (Test-Path $signScript) {
    Write-Host "[3/5] 签名构建产物..." -ForegroundColor Yellow
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $signScript -Path $dist
    if (-not (Test-Path $dist)) { throw "签名后产物丢失" }
} else {
    Write-Host "[3/5] 跳过签名（找不到 sign.ps1）" -ForegroundColor DarkGray
}

# ---------- 4) 备份并部署 ----------
if ($NoDeploy) {
    Write-Host "[4/5] 跳过部署（-NoDeploy：由调用方负责替换）" -ForegroundColor DarkGray
} else {
    Write-Host "[4/5] 备份旧版本并替换主程序..." -ForegroundColor Yellow
    $backupDir = ''
    if (Test-Path $target) {
        $backupDir = Join-Path $base ("backups\pre-update-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item $target (Join-Path $backupDir 'Codex-Zh-Launcher-Windows-x64.exe') -Force
        if (Test-Path (Join-Path $base 'SHA256SUMS.txt')) {
            Copy-Item (Join-Path $base 'SHA256SUMS.txt') $backupDir -Force -ErrorAction SilentlyContinue
        }
        Write-Host "      旧版本已备份: $backupDir"
    }
    Copy-Item $dist $target -Force
    Copy-Item (Join-Path $srcRoot 'dist\SHA256SUMS.txt') (Join-Path $base 'SHA256SUMS.txt') -Force
}

# ---------- 5) 结果 ----------
$resultFile = if ($NoDeploy) { $dist } else { $target }
$buildInfo.artifact = $resultFile
$buildInfo.artifact_version = (Get-Item $resultFile).VersionInfo.FileVersion
$buildInfo.artifact_sha256 = (Get-FileHash $resultFile -Algorithm SHA256).Hash
try {
    $sig = Get-AuthenticodeSignature $resultFile
    $buildInfo.signature_status = [string]$sig.Status
    $buildInfo.signer = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { '' }
    $buildInfo.signer_thumbprint = if ($sig.SignerCertificate) { $sig.SignerCertificate.Thumbprint } else { '' }
} catch { }
($buildInfo | ConvertTo-Json -Depth 4) | Set-Content $buildInfoFile -Encoding UTF8
Write-Host "[5/5] 完成" -ForegroundColor Green
Write-Host "  文件: $resultFile"
Write-Host "  版本: $($buildInfo.artifact_version)"
Write-Host "  SHA256: $($buildInfo.artifact_sha256)"
Write-Host "  构建信息: $buildInfoFile"
Write-Host ""
Write-Host "提示：正在运行旧版本的话，需要先退出工具再打开新版本。" -ForegroundColor DarkGray
if (-not $NoPause) { Read-Host "按回车关闭" }

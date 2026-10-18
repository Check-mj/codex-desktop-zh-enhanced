# ============================================================
#  Codex 汉化增强工具 —— 一键重建（安全流程）
#  安全约定：
#    - 上游源码先下载/解压/套用 overlay/构建/签名到临时目录
#    - 任何前置步骤失败 → 现有源码与主程序均不受影响
#    - 签名失败/指纹不符 → 拒绝部署
#    - 部署前备份旧 exe；源码替换使用目录交换，失败自动回滚
#  参数：
#    -Update    同步上游源码（默认使用 tools\upstream-pin.json 固定的版本）
#    -Repin     重新查询上游最新 Release 并更新固定版本
#    -NoPause   结束后不等待回车（界面/CI 调用）
#    -NoDeploy  只构建+签名（并更新源码），不替换主程序（由调用方负责）
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
$target = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe'
$pinFile = Join-Path $base 'tools\upstream-pin.json'
$buildInfoFile = Join-Path $base 'build-info.json'
$upstreamRepo = 'shibaweidu/codex-desktop-zh'

$stagingRoot = ''
$buildSourceRoot = $srcRoot
$buildInfo = [ordered]@{
    built_at = (Get-Date).ToString('o')
    mode = if ($Update) { 'update' } else { 'local-source' }
    upstream_version = ''
    upstream_commit = ''
    upstream_archive_sha256 = ''
    overlay_files = 0
    artifact = ''
    artifact_version = ''
    artifact_sha256 = ''
    signature_status = ''
    signer = ''
    signer_thumbprint = ''
}

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

function Get-CerThumbprint {
    $cerPath = Join-Path $base 'CodexZhLauncher.cer'
    if (-not (Test-Path $cerPath)) { return '' }
    try {
        return (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cerPath)).Thumbprint
    } catch {
        return ''
    }
}

try {
    Write-Host "== Codex 汉化工具 重建 ==" -ForegroundColor Cyan
    Write-Host "   模式: $(if ($Update) { '同步上游（临时目录构建）' } else { '使用现有源码' })"

    # ================= 1) 准备构建用的源码（临时目录，不动现有源码） =================
    if ($Update) {
        Write-Host "[1/6] 下载并准备上游源码（临时目录）..." -ForegroundColor Yellow

        $pin = $null
        if (Test-Path $pinFile) {
            try { $pin = Get-Content $pinFile -Raw -Encoding utf8 | ConvertFrom-Json } catch { $pin = $null }
        }
        if (-not $pin -or -not $pin.commit -or $Repin) {
            Write-Host "      查询上游最新 Release 并固定版本..."
            $h = @{ 'User-Agent' = 'codex-zh-rebuild' }
            $rel = Invoke-RestMethod "https://api.github.com/repos/$upstreamRepo/releases/latest" -Headers $h -TimeoutSec 30
            $version = ($rel.tag_name -replace '^v', '')
            $commit = Get-GitTagCommit -repo $upstreamRepo -tag $rel.tag_name
            $pin = [pscustomobject]@{ repo = $upstreamRepo; version = $version; commit = $commit; archive_sha256 = '' }
            New-Item -ItemType Directory -Force -Path (Split-Path $pinFile) | Out-Null
            ($pin | ConvertTo-Json) | Set-Content $pinFile -Encoding UTF8
            Write-Host "      已固定上游版本: v$version @ $commit" -ForegroundColor Green
        }
        $buildInfo.upstream_version = $pin.version
        $buildInfo.upstream_commit = $pin.commit
        Write-Host "      上游版本: v$($pin.version) @ $($pin.commit)"

        # 下载到独立临时 zip（失败：现有源码/主程序不受影响）
        $zip = Join-Path $env:TEMP ("upstream-" + $pin.commit + ".zip")
        if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
        try {
            Invoke-WebRequest "https://codeload.github.com/$($pin.repo)/zip/$($pin.commit)" -OutFile $zip -UseBasicParsing -TimeoutSec 300
        } catch {
            throw "下载上游源码失败：$($_.Exception.Message)。现有源码与主程序未改动。"
        }
        if (-not (Test-Path $zip)) { throw "下载上游源码失败：未生成 zip。现有源码与主程序未改动。" }

        $sha = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($pin.archive_sha256 -and $pin.archive_sha256 -ne $sha) {
            throw "上游源码包哈希不匹配：固定值 $($pin.archive_sha256)，实际 $sha。现有源码与主程序未改动。"
        }
        if (-not $pin.archive_sha256) {
            $pin.archive_sha256 = $sha
            ($pin | ConvertTo-Json) | Set-Content $pinFile -Encoding UTF8
            Write-Host "      已记录上游源码包 SHA256: $sha"
        }
        $buildInfo.upstream_archive_sha256 = $sha

        # 解压到独立临时目录
        $stagingRoot = Join-Path $env:TEMP ("czl-build-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null
        try {
            Expand-Archive $zip -DestinationPath $stagingRoot -Force
        } catch {
            throw "解压上游源码失败：$($_.Exception.Message)。现有源码与主程序未改动。"
        }
        $newSrc = @(Get-ChildItem $stagingRoot -Directory | Select-Object -First 1)
        if (-not $newSrc -or -not $newSrc[0]) { throw "解压结果异常：未找到源码目录。现有源码与主程序未改动。" }
        $buildSourceRoot = $newSrc[0].FullName

        # 结构校验
        foreach ($required in @('build.ps1', 'src', 'shared')) {
            if (-not (Test-Path (Join-Path $buildSourceRoot $required))) {
                throw "上游源码结构异常：缺少 $required。现有源码与主程序未改动。"
            }
        }

        # 在临时目录套用 overlay
        $overlayFiles = @(Get-ChildItem $overlay -Filter *.cs -ErrorAction SilentlyContinue)
        $newFiles = @()
        foreach ($f in $overlayFiles) {
            if (-not (Test-Path (Join-Path $buildSourceRoot "src\$($f.Name)"))) { $newFiles += $f.Name }
        }
        if ($newFiles.Count -gt 0) { Write-Warning ("上游中不存在、将作为新增文件套用: " + ($newFiles -join ', ')) }
        foreach ($f in $overlayFiles) {
            Copy-Item $f.FullName (Join-Path $buildSourceRoot "src\$($f.Name)") -Force
        }
        $buildInfo.overlay_files = $overlayFiles.Count

        # 更新上游版本基线
        $appInfoPath = Join-Path $buildSourceRoot 'src\AppInfo.cs'
        if (Test-Path $appInfoPath) {
            $content = [System.IO.File]::ReadAllText($appInfoPath)
            $content = [regex]::Replace($content, 'UpstreamBaseVersion\s*=\s*"[^"]*"', ('UpstreamBaseVersion = "' + $pin.version + '"'))
            [System.IO.File]::WriteAllText($appInfoPath, $content, (New-Object System.Text.UTF8Encoding($false)))
        }
        Write-Host "      临时源码已就绪（套用 $($overlayFiles.Count) 个本地改动文件）"
    } else {
        Write-Host "[1/6] 使用现有源码（加 -Update 可同步固定的上游版本）" -ForegroundColor DarkGray
        if (Test-Path $pinFile) {
            try {
                $pin = Get-Content $pinFile -Raw -Encoding utf8 | ConvertFrom-Json
                $buildInfo.upstream_version = $pin.version
                $buildInfo.upstream_commit = $pin.commit
                $buildInfo.upstream_archive_sha256 = $pin.archive_sha256
            } catch { }
        }
    }

    # ================= 2) 编译（在临时/现有源码中，不触碰主程序） =================
    Write-Host "[2/6] 编译..." -ForegroundColor Yellow
    $buildScript = Join-Path $buildSourceRoot 'build.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript
    if ($LASTEXITCODE -ne 0) { throw "构建失败（退出码 $LASTEXITCODE）。现有源码与主程序未改动。" }
    $dist = Join-Path $buildSourceRoot 'dist\Codex-Zh-Launcher-Windows-x64.exe'
    if (-not (Test-Path $dist)) { throw "构建失败：未生成 $dist。现有源码与主程序未改动。" }

    # ================= 3) 签名并独立复核 =================
    $signScript = Join-Path $base 'sign.ps1'
    if (-not (Test-Path $signScript)) { throw "找不到 sign.ps1：拒绝在未签名的情况下部署。" }
    Write-Host "[3/6] 签名构建产物并校验..." -ForegroundColor Yellow
    $expectedTp = Get-CerThumbprint
    $signArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $signScript, '-Path', $dist)
    if ($expectedTp) { $signArgs += @('-ExpectedThumbprint', $expectedTp) }
    & powershell.exe @signArgs
    if ($LASTEXITCODE -ne 0) { throw "签名脚本失败（退出码 $LASTEXITCODE），已中止部署。现有源码与主程序未改动。" }
    if (-not (Test-Path $dist)) { throw "签名后产物丢失，已中止部署。现有源码与主程序未改动。" }

    $sigCheck = Get-AuthenticodeSignature $dist
    if (-not $sigCheck.SignerCertificate) { throw "签名校验失败：无签名证书，已中止部署。现有源码与主程序未改动。" }
    if ($sigCheck.Status -ne 'Valid') { throw "签名校验失败：状态 $($sigCheck.Status)，已中止部署。现有源码与主程序未改动。" }
    if ($expectedTp -and $sigCheck.SignerCertificate.Thumbprint -ne $expectedTp) {
        throw "签名校验失败：证书指纹与预期不一致，已中止部署。现有源码与主程序未改动。"
    }
    Write-Host "      签名校验通过：$($sigCheck.Status) / $($sigCheck.SignerCertificate.Thumbprint)"

    # ================= 4) 备份并部署（先替换 exe，再交换源码，失败回滚） =================
    if ($NoDeploy) {
        Write-Host "[4/6] 跳过替换主程序（-NoDeploy）" -ForegroundColor DarkGray
    } else {
        Write-Host "[4/6] 备份旧版本并部署..." -ForegroundColor Yellow
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

        try {
            Copy-Item $dist $target -Force
        } catch {
            throw "替换主程序失败（可能正在运行）：$($_.Exception.Message)。旧版本未改动。"
        }
        if (Test-Path (Join-Path $buildSourceRoot 'dist\SHA256SUMS.txt')) {
            Copy-Item (Join-Path $buildSourceRoot 'dist\SHA256SUMS.txt') (Join-Path $base 'SHA256SUMS.txt') -Force
        }
        Write-Host "      主程序已更新"
    }

    # ================= 5) 交换源码目录（仅 -Update 且临时构建成功） =================
    if ($Update) {
        Write-Host "[5/6] 更新本地源码目录..." -ForegroundColor Yellow
        $sourceBackup = Join-Path $base ("backups\source-pre-update-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $oldMoved = $false
        try {
            if (Test-Path $srcRoot) {
                New-Item -ItemType Directory -Force -Path (Split-Path $sourceBackup) | Out-Null
                Move-Item $srcRoot $sourceBackup -Force
                $oldMoved = $true
            }
            New-Item -ItemType Directory -Force -Path (Split-Path $srcRoot) | Out-Null
            Move-Item $buildSourceRoot $srcRoot -Force
            Write-Host "      源码已更新（旧源码备份: $sourceBackup）"
            $stagingRoot = ''
        } catch {
            if ($oldMoved -and (Test-Path $sourceBackup)) {
                Move-Item $sourceBackup $srcRoot -Force -ErrorAction SilentlyContinue
            }
            throw "更新源码目录失败：$($_.Exception.Message)。已尝试恢复旧源码；主程序已更新为已签名的新版本。"
        }
    } else {
        Write-Host "[5/6] 源码目录未变更（非 -Update 模式）" -ForegroundColor DarkGray
    }

    # ================= 6) 结果 =================
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
    Write-Host "[6/6] 完成" -ForegroundColor Green
    Write-Host "  文件: $resultFile"
    Write-Host "  版本: $($buildInfo.artifact_version)"
    Write-Host "  SHA256: $($buildInfo.artifact_sha256)"
    Write-Host "  构建信息: $buildInfoFile"
    Write-Host ""
    Write-Host "提示：正在运行旧版本的话，需要先退出工具再打开新版本。" -ForegroundColor DarkGray
}
finally {
    if ($stagingRoot -and (Test-Path $stagingRoot)) {
        Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $NoPause) { Read-Host "按回车关闭" }
}

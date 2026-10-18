# 生成发布清单（RELEASE MANIFEST）
# 用法示例：
#   powershell -File tools\make-release-manifest.ps1 `
#     -Version 0.8.0 `
#     -SourceCommit 283ea6b1e7201987f81f0e75bc890133971d2e58 `
#     -UpstreamVersion 0.7.7 `
#     -UpstreamCommit 82136f547a9bca582fc6d9ed9f37b6600de7e13a `
#     -Launcher .\Codex-Zh-Launcher-Windows-x64.exe `
#     -InstallerExe .\发布\Codex中文启动器-安装包-v0.8.0.exe `
#     -InstallerZip .\发布\Codex中文启动器-安装包-v0.8.0.zip `
#     -OutFile .\docs\RELEASE_MANIFEST-v0.8.0.md
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$SourceCommit,
    [string]$UpstreamVersion = '',
    [string]$UpstreamCommit = '',
    [string]$WorkflowUrl = '',
    [string]$Launcher = '',
    [string]$InstallerExe = '',
    [string]$InstallerZip = '',
    [string]$OutFile = '',
    [string]$ExpectedThumbprint = '76134CBD2706FD88D9FAD973CED58B3E32AC1DED',
    [string]$BuildMode = '本机运行 重新构建.ps1 / 打包安装版.ps1（正式签名证书）',
    [string]$SourceTreeHash = '',
    [string]$ImplementationCommits = '',
    [string]$ReleaseChoreCommits = '',
    [string]$CiRuns = '',
    [string]$RepoUrl = 'https://github.com/Check-mj/codex-desktop-zh-enhanced'
)

$ErrorActionPreference = 'Stop'

function Get-HashLine($path, $name) {
    if (-not $path -or -not (Test-Path $path)) { return "| $name | （未提供） |" }
    $h = (Get-FileHash $path -Algorithm SHA256).Hash
    return "| $name | ``$h`` |"
}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$os = (Get-CimInstance Win32_OperatingSystem)
$sig = $null
if ($InstallerExe -and (Test-Path $InstallerExe)) { $sig = Get-AuthenticodeSignature $InstallerExe }

$lines = @()
$lines += "# 发布清单 v$Version"
$lines += ""
$lines += "> 由 tools/make-release-manifest.ps1 生成。用于核对发布物的来源、哈希与签名。"
$lines += ">"
$lines += "> 发布物由**维护者本机**构建并签名；CI 运行仅用于验证同一源码 commit 的构建与签名流程，"
$lines += "> CI 产物使用开发验证签名，**不作为发布物**。"
$lines += ""
$lines += "## 版本信息"
$lines += ""
$lines += "| 项目 | 值 |"
$lines += "|---|---|"
$lines += "| 项目版本 | v$Version |"
$lines += "| 发布源码提交（发布物构建所用） | ``$SourceCommit`` |"
if ($UpstreamVersion) { $lines += "| 上游项目 | shibaweidu/codex-desktop-zh v$UpstreamVersion |" }
if ($UpstreamCommit) { $lines += "| 上游 commit | ``$UpstreamCommit`` |" }
$lines += "| 产物构建方式 | $BuildMode |"
if ($SourceTreeHash) { $lines += "| 本地源码树 SHA-256（与仓库 commit 内容一致） | ``$SourceTreeHash`` |" }
if ($WorkflowUrl) { $lines += "| CI 验证运行（校验源码 commit 的构建/签名流程，非发布物构建） | $WorkflowUrl |" }
$lines += "| 清单生成时间 | $now |"
$lines += "| 本地构建系统 | $($os.Caption) $($os.Version) |"
$lines += ""
$lines += "## 提交记录"
$lines += ""
$lines += "| 类型 | 提交 | 说明 |"
$lines += "|---|---|---|"
$lines += "| 发布源码提交 | [``$($SourceCommit.Substring(0, 8))``]($RepoUrl/commit/$SourceCommit) | 发布物由该提交的源码构建 |"
$implList = @()
if ($ImplementationCommits) { $implList = $ImplementationCommits -split '[,\s]+' | Where-Object { $_ } }
foreach ($c in $implList) {
    $short = if ($c.Length -gt 8) { $c.Substring(0, 8) } else { $c }
    $lines += "| 实现改动提交 | [``$short``]($RepoUrl/commit/$c) | 该版本包含的功能/可靠性改动 |"
}
$choreList = @()
if ($ReleaseChoreCommits) { $choreList = $ReleaseChoreCommits -split '[,\s]+' | Where-Object { $_ } }
foreach ($c in $choreList) {
    $short = if ($c.Length -gt 8) { $c.Substring(0, 8) } else { $c }
    $lines += "| 构建/发布配套提交 | [``$short``]($RepoUrl/commit/$c) | 源码对齐、版本号、清单等收尾改动，不含功能变化 |"
}
$lines += ""
$lines += "> 发布源码提交 = 构建发布物所用的仓库提交；实现改动提交 = 该版本实际包含的功能/可靠性改动；"
$lines += "> 构建/发布配套提交 = 源码对齐、版本号、清单等非功能性收尾改动；仅文档提交不列入。"
$lines += ""
$lines += "## CI 验证记录"
$lines += ""
if ($CiRuns) {
    $lines += "| 运行 | head SHA | 结论 | 用途/说明 |"
    $lines += "|---|---|---|---|"
    foreach ($entry in ($CiRuns -split ';')) {
        if (-not $entry.Trim()) { continue }
        $parts = $entry -split '\|'
        if ($parts.Count -ge 4) {
            $num = $parts[0].Trim(); $sha = $parts[1].Trim(); $concl = $parts[2].Trim(); $purpose = $parts[3].Trim()
            $url = if ($parts.Count -ge 5) { $parts[4].Trim() } else { '' }
            $numText = if ($url) { "[$num]($url)" } else { $num }
            $lines += "| $numText | ``$sha`` | $concl | $purpose |"
        }
    }
} else {
    $lines += "未提供 CI 验证记录。"
}
$lines += ""
$lines += "> CI 运行仅用于验证同一源码 commit 的构建/签名流程；CI 产物使用开发验证签名，不作为发布物。"
$lines += ""
$lines += "## 文件哈希（SHA-256）"
$lines += ""
$lines += "| 文件 | SHA-256 |"
$lines += "|---|---|"
$lines += (Get-HashLine $Launcher '启动器 Codex-Zh-Launcher-Windows-x64.exe')
$lines += (Get-HashLine $InstallerExe '安装包 .exe')
$lines += (Get-HashLine $InstallerZip '安装包 .zip')
$lines += ""
$lines += "## 签名信息"
$lines += ""
if ($sig -and $sig.SignerCertificate) {
    $lines += "| 项目 | 值 |"
    $lines += "|---|---|"
    $lines += "| 签名状态 | $($sig.Status) |"
    $lines += "| 签名者 | ``$($sig.SignerCertificate.Subject)`` |"
    $lines += "| 证书指纹 | ``$($sig.SignerCertificate.Thumbprint)`` |"
    $lines += "| 证书有效期 | $($sig.SignerCertificate.NotBefore.ToString('yyyy-MM-dd')) → $($sig.SignerCertificate.NotAfter.ToString('yyyy-MM-dd')) |"
    if ($ExpectedThumbprint) {
        $ok = ($sig.SignerCertificate.Thumbprint -eq $ExpectedThumbprint)
        $lines += "| 指纹是否符合官方发布身份 | $(if ($ok) { '是' } else { '否（请调查）' }) |"
    }
} else {
    $lines += "未提供安装包或无法读取签名。"
}
$lines += ""
$lines += "## 验证方式"
$lines += ""
$lines += '```powershell'
$lines += ('Get-FileHash .\Codex-Zh-Launcher-Installer-v' + $Version + '.exe -Algorithm SHA256')
$lines += ('Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v' + $Version + '.exe | Format-List Status, SignerCertificate')
$lines += '```'
$lines += ""
$lines += "详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。"
if ($SourceTreeHash) {
    $lines += ""
    $lines += "本地构建所用源码树哈希：``$SourceTreeHash``（与仓库 ``$SourceCommit`` 的源码内容一致，由发布脚本在构建前核对）。"
}
$lines += ""
$lines += "> 说明：哈希与签名可证明文件与发布时一致、且由预期身份签名，"
$lines += "> 但不构成对程序行为的独立安全审计。"

$content = $lines -join "`r`n"
if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "发布清单已生成: $OutFile"
} else {
    Write-Host $content
}

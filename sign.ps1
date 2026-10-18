# ============================================================
#  Codex 中文启动器 —— 代码签名
#  首次运行会创建自签名代码签名证书（当前用户），本机使用时
#  同时导入“受信任根”和“受信任发布者”。
#  行为约定：
#    - 签名失败/状态异常/指纹不符 → 抛出异常（退出码非 0）
#    - 让父脚本能通过退出码与返回状态判断是否允许部署
#  参数：
#    -Path               要签名的文件
#    -ExpectedThumbprint 期望的证书指纹（可选；提供则校验）
#    -AllowUntrusted     允许未受信任状态（CI 用；仍要求签名者正确）
# ============================================================
param(
    [string]$Path = "",
    [string]$ExpectedThumbprint = "",
    [switch]$AllowUntrusted
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Path) { $Path = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe' }
if (-not (Test-Path $Path)) { throw "找不到要签名的文件: $Path" }

$isCi = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
if ($isCi) { $AllowUntrusted = $true }

$subject = 'CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua'
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -eq $subject } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (-not $cert) {
    Write-Host "首次运行：正在创建自签名代码签名证书..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $subject `
        -CertStoreLocation Cert:\CurrentUser\My `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -KeyUsage DigitalSignature `
        -NotAfter (Get-Date).AddYears(10)

    $cerPath = Join-Path $base 'CodexZhLauncher.cer'
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    if (-not $isCi) {
        certutil -user -addstore Root $cerPath | Out-Null
        certutil -user -addstore TrustedPublisher $cerPath | Out-Null
        Write-Host "已创建证书并导入本机信任存储：" -ForegroundColor Green
    } else {
        Write-Host "CI 环境：跳过证书信任导入，仅对文件签名"
    }
    Write-Host "  证书文件: $cerPath"
    Write-Host "  （换电脑使用时，先运行 导入证书.cmd 导入到“受信任的根证书颁发机构”和“受信任的发布者”）"
}

if (-not $cert.HasPrivateKey) {
    throw "签名证书没有私钥，无法签名。请删除旧证书后重试。"
}

# 期望指纹：显式参数优先；否则若存在公钥文件则用它核对身份一致性
if (-not $ExpectedThumbprint) {
    $cerPath = Join-Path $base 'CodexZhLauncher.cer'
    if ((Test-Path $cerPath) -and -not $isCi) {
        try {
            $cerCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cerPath)
            if ($cerCert.Thumbprint -eq $cert.Thumbprint) {
                $ExpectedThumbprint = $cerCert.Thumbprint
            } else {
                Write-Warning "公钥文件与私钥证书指纹不一致（公钥: $($cerCert.Thumbprint) / 私钥: $($cert.Thumbprint)），将使用当前私钥证书。"
            }
        } catch {
        }
    }
}

if ($isCi) {
    # CI 无人值守：不加时间戳，避免网络/证书链导致 UnknownError
    $signature = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -HashAlgorithm SHA256
} else {
    try {
        $signature = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -HashAlgorithm SHA256 -TimestampServer 'http://timestamp.digicert.com'
    } catch {
        $signature = Set-AuthenticodeSignature -FilePath $Path -Certificate $cert -HashAlgorithm SHA256
    }
}

if (-not $signature.SignerCertificate) {
    throw "签名失败：文件未产生签名证书（Status=$($signature.Status)）。"
}

$allowed = @('Valid')
if ($AllowUntrusted) { $allowed += @('UntrustedRoot', 'UnknownError') }
if ($allowed -notcontains $signature.Status) {
    throw "签名失败：状态为 $($signature.Status) - $($signature.StatusMessage)"
}
if ($signature.SignerCertificate.Subject -notlike '*Codex Zh Launcher*') {
    throw "签名失败：签名者不符合预期（$($signature.SignerCertificate.Subject)）。"
}
if ($ExpectedThumbprint -and $signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint) {
    throw "签名失败：证书指纹与预期不一致（预期 $ExpectedThumbprint，实际 $($signature.SignerCertificate.Thumbprint)）。"
}

Write-Host "签名成功: $Path" -ForegroundColor Green
Write-Host "  状态: $($signature.Status)"
Write-Host "  签名者: $($signature.SignerCertificate.Subject)"
Write-Host "  证书指纹: $($signature.SignerCertificate.Thumbprint)"
if ($signature.Status -ne 'Valid') {
    Write-Warning "当前为未受信任状态（$($signature.Status)），仅允许用于 CI 开发验证产物，不应作为官方发布。"
}

# ============================================================
#  Codex 中文启动器 —— 代码签名
#  首次运行会创建自签名代码签名证书，并导入当前用户的
#  “受信任根”和“受信任发布者”，然后给主程序签名。
#  以后重建会自动调用本脚本重新签名。
# ============================================================
param(
    [string]$Path = ""
)

$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Path) { $Path = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe' }
if (-not (Test-Path $Path)) { throw "找不到要签名的文件: $Path" }

$isCi = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
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
    Write-Host "  （换电脑使用时，先双击导入这个 .cer 到“受信任的根证书颁发机构”和“受信任的发布者”）"
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

if ($signature.Status -eq 'Valid') {
    Write-Host "签名成功: $Path" -ForegroundColor Green
    Write-Host "  签名者: $($signature.SignerCertificate.Subject)"
} else {
    Write-Warning "签名状态: $($signature.Status) - $($signature.StatusMessage)"
}

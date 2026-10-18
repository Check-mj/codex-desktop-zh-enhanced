# 发布文件验证脚本
# 用法：
#   powershell -File tools\verify-release.ps1 -Path .\xxx.exe
#   powershell -File tools\verify-release.ps1 -Path .\xxx.exe -ExpectedThumbprint <指纹>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$ExpectedThumbprint = '',

    [string]$ExpectedSha256 = ''
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Path)) { throw "文件不存在: $Path" }

$file = Get-Item $Path
$hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash

Write-Host "== 发布文件验证 =="
Write-Host "文件:   $($file.FullName)"
Write-Host "大小:   $([math]::Round($file.Length / 1KB, 1)) KB"
Write-Host "SHA256: $hash"

$failed = $false

if ($ExpectedSha256) {
    if ($hash -ne $ExpectedSha256.ToUpperInvariant()) {
        Write-Host "哈希校验: 不匹配 ❌（预期 $($ExpectedSha256.ToUpperInvariant())）" -ForegroundColor Red
        $failed = $true
    } else {
        Write-Host "哈希校验: 通过 ✅" -ForegroundColor Green
    }
}

try {
    $sig = Get-AuthenticodeSignature $file.FullName
    Write-Host "签名状态: $($sig.Status)"
    if ($sig.SignerCertificate) {
        Write-Host "签名者:   $($sig.SignerCertificate.Subject)"
        Write-Host "证书指纹: $($sig.SignerCertificate.Thumbprint)"
        if ($ExpectedThumbprint) {
            if ($sig.SignerCertificate.Thumbprint -ne $ExpectedThumbprint) {
                Write-Host "指纹校验: 不匹配 ❌（预期 $ExpectedThumbprint）" -ForegroundColor Red
                $failed = $true
            } else {
                Write-Host "指纹校验: 通过 ✅" -ForegroundColor Green
            }
        }
        if ($sig.Status -ne 'Valid') {
            Write-Host "提示: 签名状态不是 Valid。若是未导入项目证书的机器，可能是 UntrustedRoot；" -ForegroundColor Yellow
            Write-Host "      请核对签名者与指纹，并自行判断是否继续。" -ForegroundColor Yellow
        }
    } else {
        Write-Host "签名: 未找到签名证书" -ForegroundColor Yellow
        if ($file.Extension -ieq '.exe') { $failed = $true }
    }
} catch {
    Write-Host "签名检查失败: $($_.Exception.Message)" -ForegroundColor Red
    $failed = $true
}

if ($failed) {
    Write-Host ""
    Write-Host "验证未通过，请勿直接运行该文件。" -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "验证完成。" -ForegroundColor Green
exit 0

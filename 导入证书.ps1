# ============================================================
#  导入 Codex 中文启动器 的签名证书（换电脑时使用）
#  作用：把同目录下的 CodexZhLauncher.cer 导入当前用户的
#        “受信任的根证书颁发机构”和“受信任的发布者”，
#        这样本机就会信任启动器的签名。
#  用法：右键 -> 使用 PowerShell 运行
# ============================================================
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$cer = Join-Path $base 'CodexZhLauncher.cer'

if (-not (Test-Path $cer)) {
    Write-Warning "找不到证书文件：$cer"
    Read-Host "按回车关闭"
    exit 1
}

certutil -user -addstore Root $cer | Out-Null
certutil -user -addstore TrustedPublisher $cer | Out-Null

$exe = Join-Path $base 'Codex-Zh-Launcher-Windows-x64.exe'
if (Test-Path $exe) {
    $sig = Get-AuthenticodeSignature $exe
    Write-Host "证书已导入当前用户信任存储。" -ForegroundColor Green
    Write-Host "主程序签名状态：$($sig.Status)"
    Write-Host "签名者：$($sig.SignerCertificate.Subject)"
} else {
    Write-Host "证书已导入当前用户信任存储。" -ForegroundColor Green
}

Read-Host "按回车关闭"

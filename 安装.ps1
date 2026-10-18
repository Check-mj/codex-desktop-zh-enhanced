# ============================================================
#  Codex 中文启动器 —— 安装程序
#  用法：双击 安装.cmd，或 powershell -File 安装.ps1
#  默认安装到 %LOCALAPPDATA%\Programs\Codex中文启动器（无需管理员）
# ============================================================
param(
    [string]$Target = (Join-Path $env:LOCALAPPDATA 'Programs\Codex中文启动器'),
    [switch]$NoCert,        # 不导入签名证书
    [switch]$NoAutostart,   # 不设置开机自启
    [switch]$NoShortcuts,   # 不创建快捷方式
    [switch]$NoLaunch,      # 安装后不启动
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $root 'payload'
if (-not (Test-Path $payload)) { $payload = $root }

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Codex 中文启动器  安装程序" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  安装目录: $Target"

New-Item -ItemType Directory -Force -Path $Target | Out-Null

# ---------- 复制程序文件 ----------
$items = @(
    'Codex-Zh-Launcher-Windows-x64.exe',
    'CodexZhLauncher.cer',
    'sign.ps1',
    '重新构建.cmd', '重新构建.ps1',
    '卸载.cmd', '卸载.ps1', 'uninstall.ps1', 'uninstall.cmd',
    '导入证书.cmd', '导入证书.ps1',
    'SHA256SUMS.txt'
)
foreach ($item in $items) {
    $src = Join-Path $payload $item
    if (Test-Path $src) { Copy-Item $src $Target -Force }
}
foreach ($dir in @('overlay', 'source')) {
    $src = Join-Path $payload $dir
    if (Test-Path $src) { Copy-Item $src $Target -Recurse -Force }
}
Write-Host "  [1/4] 程序文件已复制"

# ---------- 导入证书 ----------
$cer = Join-Path $Target 'CodexZhLauncher.cer'
if (-not $NoCert -and (Test-Path $cer)) {
    certutil -user -addstore Root $cer | Out-Null
    certutil -user -addstore TrustedPublisher $cer | Out-Null
    Write-Host "  [2/4] 签名证书已导入当前用户信任存储"
} else {
    Write-Host "  [2/4] 跳过证书导入" -ForegroundColor DarkGray
}

$exe = Join-Path $Target 'Codex-Zh-Launcher-Windows-x64.exe'

# ---------- 快捷方式 ----------
if (-not $NoShortcuts -and (Test-Path $exe)) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        $lnkPath = Join-Path $dir 'Codex 中文版.lnk'
        $lnk = $shell.CreateShortcut($lnkPath)
        $lnk.TargetPath = $exe
        $lnk.Arguments = '--launch-zh'
        $lnk.WorkingDirectory = $Target
        $lnk.IconLocation = "$exe,0"
        $lnk.Description = '以中文界面启动 Codex Desktop'
        $lnk.Save()
    }
    Write-Host "  [3/4] 已创建桌面 / 开始菜单快捷方式"
} else {
    Write-Host "  [3/4] 跳过快捷方式" -ForegroundColor DarkGray
}

# ---------- 开机自启 ----------
if (-not $NoAutostart -and (Test-Path $exe)) {
    & $exe --autostart-on | Out-Null
    Write-Host "  [4/4] 已设置开机自启动（后台守护）"
} else {
    Write-Host "  [4/4] 跳过开机自启" -ForegroundColor DarkGray
}

# ---------- 启动 ----------
if (-not $NoLaunch -and (Test-Path $exe)) {
    Start-Process -FilePath $exe
    Write-Host "  已启动 Codex 中文启动器（首次启动会显示使用说明）" -ForegroundColor Green
}

Write-Host ""
Write-Host "安装完成！常用文件都在: $Target" -ForegroundColor Green
Write-Host "  · 重新构建.cmd   重建启动器（也可用界面里的「一键重建」）"
Write-Host "  · 卸载.cmd       卸载（保留程序目录，可手动删除）"
Write-Host ""
if (-not $NoPause) { Read-Host "按回车关闭" }

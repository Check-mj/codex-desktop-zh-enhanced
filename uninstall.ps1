# ============================================================
#  Codex 中文启动器 —— 卸载
#  模式：
#    普通卸载（默认）  ：停止进程、清理自启项/快捷方式/日志与配置；保留证书与程序目录
#    彻底卸载（-Thorough）：在普通卸载基础上，按指纹移除项目证书，并删除程序目录
#  参数：
#    -Thorough          彻底卸载（会二次确认）
#    -KeepLogs          普通卸载时保留日志目录
#    -DryRun            只显示将要执行的操作，不实际修改
#    -NoPause           结束不等待回车
#  用法：双击 卸载.cmd，或 powershell -File 卸载.ps1 [-Thorough] [-DryRun]
# ============================================================
param(
    [switch]$Thorough,
    [switch]$KeepLogs,
    [switch]$KeepProgramDir,
    [switch]$DryRun,
    [switch]$NoPause
)

$ErrorActionPreference = 'SilentlyContinue'
$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataDir = Join-Path $env:LOCALAPPDATA 'CodexZhLauncher'
$cerPath = Join-Path $base 'CodexZhLauncher.cer'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$valueName = 'CodexZhLauncherZh'

$result = [ordered]@{
    '启动器进程' = '未处理'
    '开机自启项' = '未处理'
    '快捷方式'   = '未处理'
    '日志目录'   = '未处理'
    '其他配置'   = '未处理'
    '项目证书'   = '未处理'
    '程序目录'   = '未处理'
}

function Do-Or-Dry($desc, [scriptblock]$action) {
    if ($DryRun) { Write-Host "  [DryRun] $desc" -ForegroundColor DarkGray; return }
    & $action
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Codex 中文启动器  卸载" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  （DryRun：不会做任何修改）" -ForegroundColor Yellow }
if ($Thorough) { Write-Host "  模式：彻底卸载（含证书与程序目录）" -ForegroundColor Yellow }
Write-Host "==============================================" -ForegroundColor Cyan

if ($Thorough -and -not $DryRun -and -not $NoPause) {
    $confirm = Read-Host "彻底卸载将移除项目证书并删除程序目录，确认继续？(yes/N)"
    if ($confirm -notmatch '^(yes|y)$') {
        Write-Host "已取消。" -ForegroundColor DarkGray
        if (-not $NoPause) { Read-Host "按回车关闭" }
        exit 0
    }
}

# 1) 结束进程
$procs = Get-Process -Name 'Codex-Zh-Launcher*' -ErrorAction SilentlyContinue
if ($procs) {
    Do-Or-Dry "结束 $($procs.Count) 个启动器进程" { $procs | Stop-Process -Force; Start-Sleep -Milliseconds 800 }
    $result['启动器进程'] = '已停止'
} else {
    $result['启动器进程'] = '未发现'
}

# 2) 开机自启项
$runValue = (Get-ItemProperty -Path $runKey -Name $valueName -ErrorAction SilentlyContinue).$valueName
if ($runValue) {
    Do-Or-Dry "删除开机自启项 $valueName" { Remove-ItemProperty -Path $runKey -Name $valueName }
    $result['开机自启项'] = '已清理'
} else {
    $result['开机自启项'] = '未发现'
}

# 3) 快捷方式
$desk = [Environment]::GetFolderPath('Desktop')
$progs = [Environment]::GetFolderPath('Programs')
$linkCount = 0
foreach ($p in @((Join-Path $desk 'Codex 中文版.lnk'), (Join-Path $progs 'Codex 中文版.lnk'))) {
    if (Test-Path $p) {
        Do-Or-Dry "删除快捷方式 $p" { Remove-Item $p -Force }
        $linkCount++
    }
}
$result['快捷方式'] = if ($linkCount -gt 0) { "已清理（$linkCount 个）" } else { '未发现' }

# 4) 日志与配置
$logs = Join-Path $dataDir 'logs'
if (-not $KeepLogs -and (Test-Path $logs)) {
    Do-Or-Dry "删除日志目录 $logs" { Remove-Item $logs -Recurse -Force }
    $result['日志目录'] = '已清理'
} elseif (Test-Path $logs) {
    $result['日志目录'] = '保留（-KeepLogs）'
} else {
    $result['日志目录'] = '未发现'
}
if (Test-Path $dataDir) {
    Do-Or-Dry "删除配置/状态文件 $dataDir" { Remove-Item $dataDir -Recurse -Force -ErrorAction SilentlyContinue }
    if ($DryRun) { $result['其他配置'] = '将清理（DryRun）' }
    elseif (Test-Path $dataDir) { $result['其他配置'] = '部分保留（文件占用）' }
    else { $result['其他配置'] = '已清理' }
} else {
    $result['其他配置'] = '未发现'
}

# 5) 证书（仅彻底卸载；按指纹精确删除，不清空存储区）
if (-not $Thorough) {
    $result['项目证书'] = '保留（普通卸载不删证书）'
} elseif (-not (Test-Path $cerPath)) {
    $result['项目证书'] = '未找到公钥证书文件，已跳过'
} else {
    $thumbprint = (Get-PfxCertificate -FilePath $cerPath 2>$null).Thumbprint
    if (-not $thumbprint) {
        $thumbprint = (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cerPath)).Thumbprint
    }
    if (-not $thumbprint) {
        $result['项目证书'] = '无法读取证书指纹，已跳过'
    } else {
        Write-Host "  目标证书指纹: $thumbprint"
        $removed = 0
        foreach ($store in @('My', 'Root', 'TrustedPublisher')) {
            $path = "Cert:\CurrentUser\$store"
            $matches = Get-ChildItem $path -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $thumbprint }
            foreach ($c in $matches) {
                Do-Or-Dry "从 $store 删除证书（指纹匹配）" { Remove-Item -LiteralPath $c.PSPath -Force }
                $removed++
            }
        }
        if ($DryRun) {
            $result['项目证书'] = '将按指纹删除（DryRun）'
        } elseif ($removed -gt 0) {
            $result['项目证书'] = "已移除（$removed 处）"
        } else {
            $result['项目证书'] = '未发现（可能已被移除）'
        }
    }
}

# 6) 程序目录（仅彻底卸载；延迟删除，避免删除正在运行的脚本）
if (-not $Thorough) {
    $result['程序目录'] = "保留: $base"
} elseif ($KeepProgramDir) {
    $result['程序目录'] = "保留（-KeepProgramDir）: $base"
} elseif ($DryRun) {
    $result['程序目录'] = "将删除: $base（DryRun）"
} else {
    $cleanup = Join-Path $env:TEMP 'codex-zh-uninstall.cmd'
    $content = "@echo off`r`ntimeout /t 2 /nobreak >nul`r`nrmdir /s /q `"$base`"`r`ndel `"%~f0`"`r`n"
    [System.IO.File]::WriteAllText($cleanup, $content, (New-Object System.Text.ASCIIEncoding))
    Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c "' + $cleanup + '"') -WindowStyle Hidden
    $result['程序目录'] = '已安排删除（窗口关闭后生效）'
}

# 7) 结果汇总
Write-Host ""
Write-Host "== 卸载结果 ==" -ForegroundColor Cyan
foreach ($key in $result.Keys) {
    Write-Host ("  {0,-10} {1}" -f $key, $result[$key])
}
Write-Host ""
Write-Host "说明：" -ForegroundColor DarkGray
Write-Host "  · 普通卸载不会删除证书与程序目录，可随时重新运行安装程序恢复。" -ForegroundColor DarkGray
Write-Host "  · 彻底卸载按证书指纹精确删除，不会清空整个证书存储区。" -ForegroundColor DarkGray
Write-Host "  · Codex 本体及其数据不受影响。" -ForegroundColor DarkGray

if (-not $NoPause) { Read-Host "按回车关闭" }

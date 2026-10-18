# 卸载与证书清理（UNINSTALL）

> 目标：让用户明确选择卸载范围，并清楚系统状态会发生什么变化（阶段 5）。
> 卸载脚本：`卸载.cmd` / `卸载.ps1`（程序目录内）

## 两种模式

### 普通卸载（默认）

```
卸载.cmd
```

| 项目 | 行为 |
|---|---|
| 启动器进程 | 停止 |
| 开机自启项 | 删除 `HKCU\...\Run\CodexZhLauncherZh` |
| 快捷方式 | 删除桌面 / 开始菜单「Codex 中文版.lnk」 |
| 日志目录 | 删除 `%LOCALAPPDATA%\CodexZhLauncher\logs`（可用 `-KeepLogs` 保留） |
| 配置/状态文件 | 删除 `%LOCALAPPDATA%\CodexZhLauncher` 下其余文件 |
| 项目证书 | **保留**（不影响其他程序） |
| 程序目录 | **保留**（可手动删除或重新安装复用） |
| Codex 本体 | 不受影响 |

### 彻底卸载

```
卸载.cmd -Thorough
```

在普通卸载基础上：

1. 二次确认（输入 `yes`）
2. 读取 `CodexZhLauncher.cer` 的证书**指纹**，仅按该指纹从当前用户的
   `My` / `Root` / `TrustedPublisher` 三个存储中精确删除对应证书；
   **不会**按 Subject 模糊匹配，**不会**清空任何证书存储区。
3. 安排延迟删除程序目录（脚本自身在目录内运行，需等窗口关闭后删除）

## 演练模式（不修改任何内容）

```
卸载.cmd -DryRun
卸载.cmd -Thorough -DryRun
```

会打印将要执行的操作与最终状态，不会真正删除/修改。

## 卸载结果输出

脚本结束时会输出汇总表：

```
启动器进程   已停止 / 未发现
开机自启项   已清理 / 未发现
快捷方式     已清理（N 个）/ 未发现
日志目录     已清理 / 保留（-KeepLogs）/ 未发现
其他配置     已清理 / 部分保留（文件占用）
项目证书     保留（普通卸载）/ 已移除（N 处）/ 未发现
程序目录     保留: <路径> / 已安排删除
```

## 如果脚本无法运行（手动清理）

```powershell
# 1) 停止进程
Get-Process -Name 'Codex-Zh-Launcher*' | Stop-Process -Force
# 2) 删除自启项
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'CodexZhLauncherZh'
# 3) 删除快捷方式（桌面/开始菜单的「Codex 中文版.lnk」）
# 4) 删除数据目录
Remove-Item "$env:LOCALAPPDATA\CodexZhLauncher" -Recurse -Force
# 5) 删除证书（可选，按指纹）
$tp = (New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('.\CodexZhLauncher.cer')).Thumbprint
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
Get-ChildItem Cert:\CurrentUser\TrustedPublisher | Where-Object { $_.Thumbprint -eq $tp } | Remove-Item -Force
```

## 注意事项

- 卸载**不会**删除或修改 Codex 本体、Codex 账号数据与对话记录。
- 普通卸载后重新运行安装程序即可恢复；证书仍在，签名仍显示可信。
- 彻底卸载会移除证书信任，若之后再次使用，需要重新运行安装程序/`导入证书.cmd`。

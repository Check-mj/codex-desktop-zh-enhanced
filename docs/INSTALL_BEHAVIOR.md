# 安装行为说明（INSTALL BEHAVIOR）

> 目标：安装前就能知道它到底改了什么。本文件描述安装程序的**实际行为**。

## 1. 默认安装位置

```
%LOCALAPPDATA%\Programs\Codex中文启动器
```

- **当前用户**安装，**不需要管理员权限**。
- 可用 `-Target <目录>` 指定其他位置（例如 D 盘）。

## 2. 安装程序做了什么（按顺序）

| 步骤 | 行为 | 可关闭参数 |
|---|---|---|
| 1 | 把程序文件复制到目标目录（主程序、脚本、证书、源码、overlay） | — |
| 2 | 把 `CodexZhLauncher.cer` 导入当前用户 `Root` 与 `TrustedPublisher` | `-NoCert` |
| 3 | 创建桌面 / 开始菜单快捷方式「Codex 中文版.lnk」 | `-NoShortcuts` |
| 4 | 写入开机自启项（后台守护） | `-NoAutostart` |
| 5 | 启动启动器（首次显示使用说明） | `-NoLaunch` |

参数示例：

```powershell
安装.cmd -NoAutostart -NoLaunch
```

## 3. 写入的系统位置

| 位置 | 内容 | 是否可撤销 |
|---|---|---|
| `%LOCALAPPDATA%\Programs\Codex中文启动器` | 程序文件 | 删除目录 |
| `%LOCALAPPDATA%\CodexZhLauncher` | 运行日志与状态文件 | `卸载.cmd` |
| `HKCU\...\Run\CodexZhLauncherZh` | 开机自启命令 | `卸载.cmd` |
| 桌面 / 开始菜单 `Codex 中文版.lnk` | 快捷方式 | `卸载.cmd` |
| `Cert:\CurrentUser\{My,Root,TrustedPublisher}` | 项目证书 | `卸载.cmd -Thorough` |

## 4. 不会做的事情

- 不修改 Codex 安装目录、不替换 `app.asar`；
- 不修改系统级证书存储、组策略、Defender 设置；
- 不修改 Codex 账号、对话数据；
- 不静默安装其他软件、不添加计划任务。

## 5. 运行时会做什么

- 启动 Codex 时带 `--remote-debugging-address=127.0.0.1 --remote-debugging-port=<随机> --inspect=127.0.0.1:<随机>`，
  用于注入中文补丁（原因与风险见 `docs/RUNTIME_BEHAVIOR.md`）。
- 后台守护（`--supervise`）在开机自启中运行，用于在 Codex 裸启动时接管，
  以及守护进程退出后自动恢复。
- 网络访问仅限 GitHub 版本检查与一键重建时下载上游源码（见 `docs/PRIVACY_AND_NETWORK.md`）。

## 6. 卸载对应关系

| 安装时写入 | 普通卸载 | 彻底卸载（`-Thorough`） |
|---|---|---|
| 程序目录 | 保留 | 删除 |
| 运行数据 / 自启项 / 快捷方式 | 删除 | 删除 |
| 项目证书 | 保留 | 按指纹删除 |

详见 `docs/UNINSTALL.md`。

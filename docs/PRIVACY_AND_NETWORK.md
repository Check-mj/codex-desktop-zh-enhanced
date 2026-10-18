# 隐私与网络行为说明（PRIVACY & NETWORK）

> 本文说明本项目的网络访问、日志内容与本地数据存储。
> 结论以实际测试与源码为依据；未验证的内容会明确标注。

## 1. 网络访问清单

| 目标 | 请求方式 | 目的 | 触发时机 | 传输内容 |
|---|---|---|---|---|
| `api.github.com` | GET | 检查上游启动器新版本 | 登录后 15 秒 / 打开工具 5 秒后（后台） | 仅 User-Agent，无用户数据 |
| `codeload.github.com` | GET | 下载固定 commit 的上游源码 zip | 用户点击「一键重建」或运行 `重新构建 -Update` | 仅 User-Agent，无用户数据 |
| `api.github.com`（维护者） | GET/POST/PUT | 维护者发布 Release | 维护者本机发布脚本 | 发布文件、仓库元数据 |
| `uploads.github.com`（维护者） | POST | 上传 Release 资产 | 同上 | 发布文件 |

- 不使用遥测 SDK、不上报使用统计、不上传日志或配置。
- 无代理行为：不转发 Codex 的模型请求，不改写 Codex 的网络流量。
- 离线/断网时：版本检查失败会被静默忽略（`upstream.check.failed` 仅写本地日志）。

## 2. 本地数据存储

| 位置 | 内容 | 是否含个人数据 |
|---|---|---|
| `%LOCALAPPDATA%\CodexZhLauncher\logs\launcher.log` | 运行日志（+ `.old` 轮转） | 路径已脱敏，见下文 |
| `%LOCALAPPDATA%\CodexZhLauncher\owned-pid.txt` | 当前由启动器拉起的 Codex PID | 否 |
| `%LOCALAPPDATA%\CodexZhLauncher\owned-applied.txt` | 已确认汉化的 Codex PID | 否 |
| `%LOCALAPPDATA%\CodexZhLauncher\launching.flag` | 启动中标记 | 否 |
| `%LOCALAPPDATA%\CodexZhLauncher\first-run.done` | 首次启动标记 | 否 |
| `%LOCALAPPDATA%\CodexZhLauncher\install-path.txt` | 程序安装路径 | 含本机路径（用于路径变化提示） |
| `%LOCALAPPDATA%\CodexZhLauncher\codex-version.txt` | 上次检测到的 Codex 版本 | 否 |
| `%LOCALAPPDATA%\CodexZhLauncher\upstream-notified.txt` | 已提示过的上游版本 | 否 |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\CodexZhLauncherZh` | 开机自启命令 | 含本机程序路径 |
| 桌面 / 开始菜单 `Codex 中文版.lnk` | 快捷方式 | 含本机程序路径 |
| 当前用户证书存储 `My` / `Root` / `TrustedPublisher` | 自签名证书 | 否 |

## 3. 日志内容与脱敏

日志包含：运行事件、版本检测结果、注入流程细节、异常堆栈。

**脱敏处理（v0.8.0 起）**：

- 写入前将当前用户的用户目录替换为 `%USERPROFILE%`；
- 同时把形如 `C:\Users\<用户名>` 的路径替换为 `%USERPROFILE%`。

因此日志中不应出现 Windows 用户名。仍可能包含：
- 程序安装路径（如 `D:\Codex汉化`）；
- 调试端口号；
- 进程 ID。

> 分享日志前仍建议自行检查并删除不需要的路径信息。

## 4. 调试端口（隐私/安全提示）

由启动器启动的 Codex 会在运行期间监听一个**回环**调试端口（详见
[`RUNTIME_BEHAVIOR.md`](RUNTIME_BEHAVIOR.md) 第 1 节）。
本机同用户进程理论上可连接该端口，这是当前注入架构的固有代价；
本项目不通过该端口传输任何数据到外部网络。

## 5. 未验证 / 待补充

- [ ] 用抓包工具对完整生命周期做网络抓包（当前结论基于源码审计与日志）；
- [ ] 确认 Electron/Chromium 自身是否有背景网络请求（属于 Codex 应用行为，不在本项目控制范围）。

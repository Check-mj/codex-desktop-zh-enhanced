# 依赖与构建环境记录（DEPENDENCIES）

> 目的：让构建与发布可复现、可追溯。本文记录运行/构建依赖及 CI 第三方 Actions 的固定版本。

## 运行时依赖

| 依赖 | 版本/来源 | 说明 |
|---|---|---|
| Windows | 10 / 11 x64 | 目标平台 |
| .NET Framework | 4.0（系统自带） | 源码通过 `csc.exe` 直接编译，不引入额外运行时 |
| Codex Desktop | Microsoft Store（MSIX）版 | 被汉化/启动的目标应用（非本项目分发） |

## 构建依赖

| 依赖 | 版本/来源 | 说明 |
|---|---|---|
| `csc.exe` | `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319` | Windows 自带 C# 编译器 |
| WPF 程序集 | .NET Framework 4.0 | UI 框架 |
| `iexpress.exe` | Windows 自带 | 生成单文件安装程序（可选，失败时回退 ZIP） |

## 上游源码

| 项目 | 版本 | commit |
|---|---|---|
| `shibaweidu/codex-desktop-zh` | v0.7.7 | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |

> 固定信息见 `tools/upstream-pin.json`（版本 / commit / 源码包 SHA-256）。
> `重新构建.ps1 -Update` 只使用固定 commit，需显式 `-Repin` 才会升级上游。

## CI 第三方 Actions（固定到 commit SHA）

| Action | 固定 SHA | 对应版本 |
|---|---|---|
| `actions/checkout` | `11bd71901bbe5b1630ceea73d27597364c9af683` | v4.2.2 |
| `actions/upload-artifact` | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4 |

> 固定 SHA 可防止 Actions 标签被移动导致构建行为变化。
> 升级方式：确认新版本 commit 后，同时更新本文件与工作流。

## 权限

CI 工作流声明 `permissions: contents: read`，仅需读取仓库内容；
不申请发布、Secrets 或其他写权限。

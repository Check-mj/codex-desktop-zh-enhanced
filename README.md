# Codex 中文启动器 · 完美功能增强版

把 **Codex Desktop（ChatGPT 桌面版）** 的界面变成中文，并在上游 [shibaweidu/codex-desktop-zh](https://github.com/shibaweidu/codex-desktop-zh)（MIT）的基础上，
做了一整套**功能增强**，目标是做到“装完即完美、日常零操作”：

> **开机自动以中文启动 Codex；点原版图标也是中文；版本更新有提醒；界面里一键重建。**

本项目**完全保留上游能力**（运行时注入汉化、不改 Codex 安装文件、不改 `app.asar`），
在此之上补齐了上游没有的“日常使用闭环”。上游源码与构建脚本完整保留，
执行 `重新构建.cmd -Update` 可随时同步上游最新代码并自动重新套用本项目的全部增强。

> ⚠️ 非官方项目，与 OpenAI 无关。仅做本地界面语言增强，不修改 Codex 本体、不代理、不收集账号数据。

---

## 💎 基于上游的完美功能增强

| 增强项 | 上游原版 | 本增强版 |
|---|---|---|
| 中文界面 / 原生菜单 | ✅ 运行时注入 | ✅ 完整保留并验证 |
| 开机自动中文启动 | ❌ 需要手动打开工具、点按钮 | ✅ 登录后约 2 秒自动拉起，进桌面即是中文 |
| 点「原版」图标 | ❌ 英文界面 | ✅ 后台守护静默接管，自动切换中文 |
| 后台常驻与自恢复 | ❌ 无 | ✅ 监督进程 + 守护进程，崩溃 3 秒自动拉起 |
| 草稿安全 | ❌ 接管时会强杀 | ✅ 超过 30 秒的会话不杀（长会话保护） |
| Codex 版本更新 | ❌ 更新后汉化静默失效 | ✅ 版本变化弹窗提醒 |
| 上游启动器更新 | ❌ 无感知 | ✅ 自动检测上游版本并提醒 |
| 更新操作 | ❌ 去文件夹找脚本 | ✅ 界面「一键重建」自动同步+编译+签名+重启 |
| 安装 / 卸载 | ❌ 手动拷贝 | ✅ 安装包（EXE/ZIP）+ 干净的卸载脚本 |
| 代码签名 | ❌ 无 | ✅ 自签名证书（仓库仅含公钥） |
| 路径变化 | ❌ 失效 | ✅ 自动修正开机自启项与快捷方式 |
| 日志 | ❌ 无限增长 | ✅ 超 1MB 自动轮转 |
| 多用户 | ❌ 可能互相干扰 | ✅ 仅处理当前 Windows 会话 |
| 自我保护 | ❌ 守护与界面可能互相抢占 | ✅ 启动标记 + 归属 PID 协同 |

## ✨ 完整功能特性

| 功能 | 说明 |
|---|---|
| 中文界面 | 运行时注入 i18n 开关，**不修改 Codex 的 app.asar**，商店更新不会弄坏 |
| 中文原生菜单 | 文件 / 编辑 / 视图 / 帮助 等菜单一并中文化 |
| 开机自动中文启动 | 登录 Windows 后约 2 秒开始拉起 Codex，进桌面时通常已是中文窗口 |
| 点原版图标也是中文 | 后台守护会静默接管“裸启动”的 Codex 并切换为中文 |
| 长会话保护 | 已运行超过 30 秒的实例不会被强杀，避免丢草稿 |
| 守护自恢复 | 监督进程发现守护退出后 3 秒自动拉起 |
| Codex 版本检测 | Codex 更新后弹窗提醒，引导点「一键重建」 |
| 上游版本检测 | 上游启动器发新版时弹窗提醒 |
| 一键重建 | 界面按钮：自动同步上游、套用本地改动、编译、签名、重启 |
| 路径自修复 | 程序被移动后，自动修正开机自启项与快捷方式 |
| 日志自动清理 | 超过 1MB 自动轮转，只保留一份 .old |
| 安装包 | 提供 ZIP 与单文件 EXE 安装程序，自动导入证书、建快捷方式、设自启 |

### 功能状态（已实现 / 已测试 / 尚未验证）

- **已实现**：代码路径存在（如中文注入、守护、签名校验、卸载证书清理）。
- **已测试**：在测试环境实际执行并记录结果（见 [`docs/FUNCTIONAL_TESTS.md`](docs/FUNCTIONAL_TESTS.md)）。
- **尚未验证**：代码具备能力但未完成对应实测（如真实整机重启、安装版/便携版 Codex 兼容）。

> 文档中出现“已实现”不等于“已测试”；两者在测试记录里分开标注。
## 📋 环境要求

- Windows 10 / 11 x64
- 已安装 **Microsoft Store 版** Codex Desktop（MSIX）
  - 仅识别 MSIX 安装方式；安装版 / 便携版不会识别
- 无需管理员权限；无需安装 .NET SDK（使用系统自带 .NET Framework 4.0 的 `csc.exe` 编译）

## 🚀 安装

### 方式一：安装包（推荐）

到 [Releases](../../releases) 下载：

- `Codex-Zh-Launcher-Installer-vX.Y.Z.exe` —— 单文件安装程序
- 或 `...zip` —— 解压后双击 `安装.cmd`

安装程序会：

1. 安装到 `%LOCALAPPDATA%\Programs\Codex中文启动器`
2. 导入自签名证书到当前用户信任存储
3. 创建桌面 / 开始菜单「Codex 中文版」快捷方式
4. 设置开机自启（后台守护）
5. 启动启动器（首次显示使用说明）

> **关于 Windows 安全提示（请先阅读）**：
>
> - 本项目是非官方开源项目，安装包使用**自签名证书**，不是公共 CA 颁发的代码签名证书。
> - 导入证书**不保证** SmartScreen 警告消失；SmartScreen 使用独立于签名验证的信誉机制。
> - 建议先核对发布来源、文件 SHA-256 与签名信息（见
>   [`docs/RELEASE_VERIFICATION.md`](docs/RELEASE_VERIFICATION.md)），
>   再自行决定是否运行。是否忽略安全提示由你判断，本指南不把“忽略提示”写成必然正确的做法。

### 方式二：从源码构建

```powershell
# 编译（需要 Windows 自带 .NET Framework 4.0）
powershell -ExecutionPolicy Bypass -File source/codex-desktop-zh-main/build.ps1

# 生成安装包（可选）
powershell -ExecutionPolicy Bypass -File 打包安装版.ps1 -NoPause
```

## 🔍 验证发布文件

```powershell
# 1. 核对哈希（与 Release 说明里的 SHA-256 对比）
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.0.exe -Algorithm SHA256

# 2. 检查签名与签名者
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.0.exe |
    Format-List Status, SignerCertificate

# 3. 或用仓库自带脚本
powershell -File tools\verify-release.ps1 -Path .\xxx.exe `
  -ExpectedThumbprint 76134CBD2706FD88D9FAD973CED58B3E32AC1DED
```

详细步骤与局限性见 [`docs/RELEASE_VERIFICATION.md`](docs/RELEASE_VERIFICATION.md)。

> 官方发布签名身份指纹：`76134CBD2706FD88D9FAD973CED58B3E32AC1DED`。
> CI 自动构建产物由临时证书签名，仅用于开发验证，**不是官方发布物**。
## 🎯 使用方式

安装后有两条路，任选：

1. **中文启动器**（推荐，零延迟）
   双击桌面/开始菜单的 **「Codex 中文版」**，直接以中文界面启动。

2. **开机后台守护**
   保持主界面「开机自启动（后台守护）」勾选，之后：
   - 开机后自动以中文启动 Codex
   - 你照常点**原版 Codex 图标**，只是把已打开的中文窗口调到前台
   - 若中途关掉 Codex 再点原版图标，守护会接管并切成中文（约 20～40 秒）

主界面上方的**说明横幅**可随时打开完整《使用说明》。

## 🔄 更新（自动检测 + 一键同步）

- 自动检测 **Codex 版本变化** 和 **上游启动器新版本**，弹窗提醒
- 提醒后打开工具，点 **「一键重建」**：
  自动下载上游最新源码 → 套用本地改动 → 编译 → 签名 → 重启
- 也可以命令行：`重新构建.cmd -Update`

## 🗑 卸载

运行安装目录下的 `卸载.cmd`，有两种模式：

- **普通卸载（默认）**：停止进程、删除开机自启/快捷方式/日志与配置；**保留证书与程序目录**。
- **彻底卸载（`-Thorough`）**：额外按证书指纹精确移除项目证书，并删除程序目录。

支持 `-DryRun` 演练（只显示将执行的操作，不做修改）。
详细清理项、结果说明与手动清理步骤见 [`docs/UNINSTALL.md`](docs/UNINSTALL.md)。
不会触碰 Codex 本体与账号数据。

## 🛠 技术原理

1. Codex 网页界面的翻译由 Statsig 开关 `72216192 / enable_i18n` 控制，默认关闭；
   `localeOverride` 只决定语言，不负责开启翻译。
2. 启动器用 `--remote-debugging-port` 启动 Codex，通过 CDP 在页面加载前注入补丁，
   强制 `enable_i18n = true`、`locale_source = SYSTEM`，并设置 `localeOverride = zh-CN`。
3. 原生菜单通过主进程 inspector 端口打补丁。
4. 因为运行中的 Codex 无法被“热注入”，裸启动的实例需要重启一次——守护模式就是自动完成这一步。

## 📁 目录结构

```
├─ source/codex-desktop-zh-main/   完整源码（含 build.ps1，保留上游结构）
├─ overlay/                         本项目的本地改动文件（重建 -Update 时套用）
├─ install.ps1 / 安装.cmd           安装程序
├─ 卸载.cmd                         卸载
├─ 导入证书.cmd                     导入自签名证书（换电脑用）
├─ 重新构建.cmd                     重建启动器（-Update 同步上游）
├─ 打包安装版.cmd                   重新生成发布安装包
├─ sign.ps1                         代码签名（自签名证书）
├─ tools/verify-release.ps1         发布文件验证脚本
├─ docs/SECURITY_DESIGN.md          安全设计说明
├─ docs/SECURITY_BASELINE.md        安全基线记录
├─ docs/RELEASE_VERIFICATION.md     发布验证指南
└─ CodexZhLauncher.cer              公钥证书（无私钥）
```

## 🔐 安全与信任（运行前请先读）

**证书是什么**：本项目用一张**自签名代码签名证书**给程序和安装包签名
（Subject `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua`，
官方发布身份指纹 `76134CBD2706FD88D9FAD973CED58B3E32AC1DED`）。
仓库只包含**公钥** `CodexZhLauncher.cer`，**不包含私钥**。

**为什么安装时要导入证书**：安装程序会把这张证书导入**当前用户**的
`Root`（信任锚）和 `TrustedPublisher`（可信发布者），
目的是让 Windows 把签名显示为有效/可信。它只影响当前 Windows 用户，
不修改系统级证书存储、组策略或 Defender 设置。

**它不能做什么（请勿误解）**：

- 不是公共 CA 证书；**导入证书不能保证消除 SmartScreen 警告**
  （SmartScreen 使用独立于 Authenticode 的信誉机制）。
- 不会让 Codex 或第三方软件获得任何额外权限；
- 不会修改 Codex 安装文件（不替换 `app.asar`）；
- 网络行为：**主要功能在本地运行**。版本检查会访问 `api.github.com`；
  你主动执行「一键重建/上游同步」时会访问 `codeload.github.com` 下载源码。
  除此之外，本项目不声明“绝对没有任何其他网络访问”（Codex/Electron 自身的网络行为不在本项目控制范围内）。

**如何核对**：

```powershell
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Windows-x64.exe |
    Format-List Status, SignerCertificate
```

**如何撤销**：普通卸载**保留**证书；`卸载.cmd -Thorough` 会按证书指纹
精确移除 `My`/`Root`/`TrustedPublisher` 中的对应证书，不会清空存储区。

详细说明见 [证书与信任配置](docs/CERTIFICATE.md)、
[安装行为](docs/INSTALL_BEHAVIOR.md)、
[安全设计](docs/SECURITY_DESIGN.md)。

## 📚 安全与信任文档

- [安全设计与信任边界](docs/SECURITY_DESIGN.md)
- [安全基线（版本 / 哈希 / 证书 / 测试记录）](docs/SECURITY_BASELINE.md)
- [发布文件验证指南](docs/RELEASE_VERIFICATION.md)
- [发布清单 v0.8.4（哈希 / 签名 / 源码 commit）](docs/RELEASE_MANIFEST-v0.8.4.md)
- [发布清单 v0.8.3](docs/RELEASE_MANIFEST-v0.8.3.md)
- [发布清单 v0.8.2](docs/RELEASE_MANIFEST-v0.8.2.md)
- [发布清单 v0.8.1](docs/RELEASE_MANIFEST-v0.8.1.md)
- [发布清单 v0.8.0](docs/RELEASE_MANIFEST-v0.8.0.md)
- [发布前检查清单](docs/RELEASE_CHECKLIST.md)
- [依赖与构建环境（含 Actions 固定 SHA）](docs/DEPENDENCIES.md)
- [更新与回滚说明](docs/UPDATE_AND_ROLLBACK.md)
- [运行时行为与测试记录](docs/RUNTIME_BEHAVIOR.md)
- [隐私与网络行为说明](docs/PRIVACY_AND_NETWORK.md)
- [卸载与证书清理](docs/UNINSTALL.md)
- [第三方审查范围与已知问题](docs/AUDIT_SCOPE.md)
- [证书与信任配置说明](docs/CERTIFICATE.md)
- [安装行为说明](docs/INSTALL_BEHAVIOR.md)
- [核心功能回归测试记录](docs/FUNCTIONAL_TESTS.md)

## 🙏 致谢与许可

- 核心汉化注入来自 [shibaweidu/codex-desktop-zh](https://github.com/shibaweidu/codex-desktop-zh)（MIT）
- 本项目在其基础上做了完整的功能增强，修改部分同样以 **MIT License** 发布，
  详见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- 非官方项目，与 OpenAI 无关联

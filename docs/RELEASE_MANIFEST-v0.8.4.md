# 发布清单 v0.8.4

> 由 tools/make-release-manifest.ps1 生成。用于核对发布物的来源、哈希与签名。
>
> 发布物由**维护者本机**构建并签名；CI 运行仅用于验证同一源码 commit 的构建与签名流程，
> CI 产物使用开发验证签名，**不作为发布物**。

## 版本信息

| 项目 | 值 |
|---|---|
| 项目版本 | v0.8.4 |
| 源码 commit | `202a0455e05e45a83a68eb79bcd161bf81874280` |
| 上游项目 | shibaweidu/codex-desktop-zh v0.7.7 |
| 上游 commit | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |
| 产物构建方式 | 本机运行 重新构建.ps1 / 打包安装版.ps1（正式签名证书） |
| 本地源码树 SHA-256（与仓库 commit 内容一致） | `46FE15DDCFF8F0910459138D9F99421853C35D4172841B0FA40D5ED94086041B` |
| CI 验证运行（校验源码 commit 的构建/签名流程，非发布物构建） | https://github.com/Check-mj/codex-desktop-zh-enhanced/actions/runs/39150742081 |
| 清单生成时间 | 2026-10-19 01:42:54 +08:00 |
| 本地构建系统 | Microsoft Windows 11 专业版 10.0.26300 |

## 文件哈希（SHA-256）

| 文件 | SHA-256 |
|---|---|
| 启动器 Codex-Zh-Launcher-Windows-x64.exe | `789A7B1ED6FCABEAE2A81D276526DADAE7A641A260D3252040C736E7C1B03AFA` |
| 安装包 .exe | `C568CE57194C5327EA1ACB4A0D3D50A44E5502E0EC62F725001098E0102CE189` |
| 安装包 .zip | `C494E10561CC65FDDAE235E26D7F8EA4BF6F650BBF8441157B93AE2C8B818E0A` |

## 签名信息

| 项目 | 值 |
|---|---|
| 签名状态 | Valid |
| 签名者 | `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua` |
| 证书指纹 | `76134CBD2706FD88D9FAD973CED58B3E32AC1DED` |
| 证书有效期 | 2026-10-18 → 2036-10-18 |
| 指纹是否符合官方发布身份 | 是 |

## 验证方式

```powershell
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.4.exe -Algorithm SHA256
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.4.exe | Format-List Status, SignerCertificate
```

详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。

本地构建所用源码树哈希：`46FE15DDCFF8F0910459138D9F99421853C35D4172841B0FA40D5ED94086041B`（与仓库 `202a0455e05e45a83a68eb79bcd161bf81874280` 的源码内容一致，由发布脚本在构建前核对）。

> 说明：哈希与签名可证明文件与发布时一致、且由预期身份签名，
> 但不构成对程序行为的独立安全审计。
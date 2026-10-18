# 发布清单 v0.8.2

> 由 tools/make-release-manifest.ps1 生成。用于核对发布物的来源、哈希与签名。

## 版本信息

| 项目 | 值 |
|---|---|
| 项目版本 | v0.8.2 |
| 源码 commit | `d117678520225df8f7f2abe7a3da96c7261e7edc` |
| 上游项目 | shibaweidu/codex-desktop-zh v0.7.7 |
| 上游 commit | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |
| 构建工作流 | https://github.com/Check-mj/codex-desktop-zh-enhanced/actions/runs/39148979727 |
| 生成时间 | 2026-10-19 01:20:09 +08:00 |
| 构建系统 | Microsoft Windows 11 专业版 10.0.26300 |

## 文件哈希（SHA-256）

| 文件 | SHA-256 |
|---|---|
| 启动器 Codex-Zh-Launcher-Windows-x64.exe | `419AB168D7CCD5D74E456A021E5742F34C6702375804FF0B9308EFC5EF027D9E` |
| 安装包 .exe | `85CCCD0C5DEE0F8C65AE6D0C1DEBD09650B5C788FA5ACC76FDD0EDFE0A984FE6` |
| 安装包 .zip | `791104038940A4C296B90612EAB0B12A0A3FD4AF3C8A8CD5CE95667B66A15DFF` |

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
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.2.exe -Algorithm SHA256
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.2.exe | Format-List Status, SignerCertificate
```

详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。

> 说明：哈希与签名可证明文件与发布时一致、且由预期身份签名，
> 但不构成对程序行为的独立安全审计。
# 发布清单 v0.8.3

> 由 tools/make-release-manifest.ps1 生成。用于核对发布物的来源、哈希与签名。

## 版本信息

| 项目 | 值 |
|---|---|
| 项目版本 | v0.8.3 |
| 源码 commit | `9dcf5478771dd8bf2562c82c6695bd10e4ca307b` |
| 上游项目 | shibaweidu/codex-desktop-zh v0.7.7 |
| 上游 commit | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |
| 构建工作流 | https://github.com/Check-mj/codex-desktop-zh-enhanced/actions/runs/39149656561 |
| 生成时间 | 2026-10-19 01:28:19 +08:00 |
| 构建系统 | Microsoft Windows 11 专业版 10.0.26300 |

## 文件哈希（SHA-256）

| 文件 | SHA-256 |
|---|---|
| 启动器 Codex-Zh-Launcher-Windows-x64.exe | `6A63D0B9C758D226168D88C5ACE37CCD8DCD540593B54A18D0CF19BFF0F4D7B5` |
| 安装包 .exe | `D92974DE731304CFFDC140B5F76B506DA4DF18E0BEC6A047B93AB475708E5925` |
| 安装包 .zip | `4668069E746BFE6DA25039B3297005141B5B15A9BE8B8893D9A8122A3E05E579` |

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
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.3.exe -Algorithm SHA256
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.3.exe | Format-List Status, SignerCertificate
```

详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。

> 说明：哈希与签名可证明文件与发布时一致、且由预期身份签名，
> 但不构成对程序行为的独立安全审计。
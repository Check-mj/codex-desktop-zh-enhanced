# 发布清单 v0.8.1

> 由 tools/make-release-manifest.ps1 生成。用于核对发布物的来源、哈希与签名。

## 版本信息

| 项目 | 值 |
|---|---|
| 项目版本 | v0.8.1 |
| 源码 commit | `2395e4dcf54ee64203794af6354f66807ed212da` |
| 上游项目 | shibaweidu/codex-desktop-zh v0.7.7 |
| 上游 commit | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |
| 构建工作流 | https://github.com/Check-mj/codex-desktop-zh-enhanced/actions/runs/39147042050 |
| 生成时间 | 2026-10-19 01:06:52 +08:00 |
| 构建系统 | Microsoft Windows 11 专业版 10.0.26300 |

## 文件哈希（SHA-256）

| 文件 | SHA-256 |
|---|---|
| 启动器 Codex-Zh-Launcher-Windows-x64.exe | `BA8E5B8958D9DF9D649AA5CB86B1E36F6491ECB998296951D5AB4D09041981AA` |
| 安装包 .exe | `59A5CBD711982CE52353D8DB927312E60B953DAB1F6FE006B4370DF391FAE318` |
| 安装包 .zip | `DD04F7A663C7F1448842488DEF1B2257247B0DC5D96658B2A4865A7CC788923F` |

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
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.1.exe -Algorithm SHA256
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.1.exe | Format-List Status, SignerCertificate
```

详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。

> 说明：哈希与签名可证明文件与发布时一致、且由预期身份签名，
> 但不构成对程序行为的独立安全审计。
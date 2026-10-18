# 发布清单 v0.8.0

> 本清单用于核对 v0.8.0 发布物的来源、哈希与签名。
> 后续发布应使用 `tools/make-release-manifest.ps1` 生成同类清单。

## 版本信息

| 项目 | 值 |
|---|---|
| 项目版本 | v0.8.0 |
| 源码 commit | `283ea6b1e7201987f81f0e75bc890133971d2e58`（tag `v0.8.0`） |
| 上游项目 | shibaweidu/codex-desktop-zh v0.7.7 |
| 上游 commit | `82136f547a9bca582fc6d9ed9f37b6600de7e13a` |
| 构建方式 | 维护者本机构建（Windows 11 10.0.26300），随后手动上传 Release |
| 构建日期 | 2026-10-18 |
| 安全基线 | tag `v0.8.0-baseline`（`bf92c768`，用于回滚与对比） |

> 说明：`v0.8.0` 标签之后的文档/CI 提交（如安全文档、工作流修复）不改变已发布的二进制文件。

## 文件哈希（SHA-256）

| 文件 | SHA-256 |
|---|---|
| 启动器 `Codex-Zh-Launcher-Windows-x64.exe` | `DB46F28AD43E123F73373DC8CE7CE92C3BB76A81BEDF2917024976C6AEFB2338` |
| 安装包 `Codex-Zh-Launcher-Installer-v0.8.0.exe` | `B58820045C2565CDD9B5F4CD706F22C7561228293513056B66DDD1B3CE4197F7` |
| 安装包 `Codex-Zh-Launcher-Installer-v0.8.0.zip` | `762D438E1443766B7190D6FFE4FBDAE57CAE273526592B8555D5F57D5EB3B777` |

## 签名信息

| 项目 | 值 |
|---|---|
| 签名状态 | Valid（本机已导入项目证书） |
| 签名者 | `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua` |
| 证书指纹 | `76134CBD2706FD88D9FAD973CED58B3E32AC1DED` |
| 证书有效期 | 2026-10-18 → 2036-10-18 |
| 备注 | 自签名证书；其他电脑未导入证书时状态可能显示 `UntrustedRoot` |

## 已知限制

- 仅支持 Microsoft Store（MSIX）版 Codex Desktop。
- 接管裸启动实例需要重启 Codex，约 20～40 秒。
- 自签名证书不等同公共 CA 证书，SmartScreen 仍可能警告。
- 上游更新流程尚未固定 commit（阶段 3 处理）。

## 验证方式

```powershell
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.0.exe -Algorithm SHA256
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.0.exe |
    Format-List Status, SignerCertificate
```

详见 [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md)。

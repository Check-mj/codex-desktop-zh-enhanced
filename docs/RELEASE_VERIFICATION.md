# 发布文件验证指南（RELEASE VERIFICATION）

本文件说明如何独立验证下载到的文件，不依赖对本项目作者的信任。

## 步骤 1：确认来源

- 只从官方仓库的 Releases 页面下载：
  <https://github.com/Check-mj/codex-desktop-zh-enhanced/releases>
- 不要从第三方转载链接下载。

## 步骤 2：核对 SHA-256

```powershell
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.0.exe -Algorithm SHA256
Get-FileHash .\Codex-Zh-Launcher-Installer-v0.8.0.zip -Algorithm SHA256
```

把结果与 Release 说明里列出的哈希对比。
（哈希能证明“文件与发布时一致”，但不能单独证明程序没有恶意行为。）

## 步骤 3：检查 Authenticode 签名

```powershell
Get-AuthenticodeSignature .\Codex-Zh-Launcher-Installer-v0.8.0.exe |
    Format-List Status, StatusMessage, SignerCertificate
```

预期：

- 官方发布物（维护者本机签名）：
  - `Status` = `Valid`（在已导入项目证书的机器上）
  - 签名者 Subject = `CN=Codex Zh Launcher (Self-Signed), O=Codex Hanhua`
  - 证书指纹 = `76134CBD2706FD88D9FAD973CED58B3E32AC1DED`
- CI 构建产物：由**每次构建的临时证书**签名，指纹会变化，
  仅用于开发验证，**不是官方签名发布物**。

## 步骤 4：核对证书

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object { $_.Subject -like '*Codex Zh Launcher*' } |
    Format-List Subject, Thumbprint, NotBefore, NotAfter, HasPrivateKey
```

也可以直接双击 `CodexZhLauncher.cer` 查看公钥证书信息。

## 步骤 5：确认源码来源

发布物的源码 commit 记录在 Release 说明中（例如 `v0.8.0` 对应某个 commit SHA）。
可以到仓库对应 commit 查看完整源码与构建脚本。

## 自动化验证（可选）

仓库提供脚本：

```powershell
powershell -File tools\verify-release.ps1 `
  -Path .\Codex-Zh-Launcher-Installer-v0.8.0.exe `
  -ExpectedThumbprint 76134CBD2706FD88D9FAD973CED58B3E32AC1DED
```

脚本会输出：文件哈希、签名状态、签名者、证书指纹，并按预期值校验。

## 局限性说明

- 自签名证书不等于公共 CA 证书；其他电脑未导入证书时签名状态为 `UntrustedRoot`。
- 导入证书**不能保证**消除 SmartScreen 警告。
- 本验证流程不等同于独立安全审计。已测试的范围与结论见
  [`SECURITY_DESIGN.md`](SECURITY_DESIGN.md) 与 [`SECURITY_BASELINE.md`](SECURITY_BASELINE.md)。
## 构建来源与发布一致性

正式发布物由**维护者本机**运行 `重新构建.ps1`（构建+签名）与 `打包安装版.ps1`（打包+签名）生成。
GitHub Actions 运行用于**验证同一源码 commit 的构建/签名流程**，其产物使用开发验证证书，
**不作为发布物上传**。

发布清单（`docs/RELEASE_MANIFEST-vX.Y.Z.md`）中：

- `源码 commit`：发布物对应的仓库提交；
- `本地源码树 SHA-256`：构建前逐文件比对本地构建源码与仓库该 commit 的 git blob SHA-1（全部一致）后记录的树哈希；
- `CI 验证运行`：`head_sha` 等于该源码 commit 的成功运行（仅流程验证，非发布物构建）；
- 文件哈希与签名信息：与实际发布资产逐个对应。

Release 说明页同时列出上述映射，三者（Release / 清单 / 实际构建记录）指向同一源码 commit。
